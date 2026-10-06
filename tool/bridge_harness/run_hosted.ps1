#requires -Version 7.0
param([Parameter(Mandatory)][string]$Serial,
 [Parameter(Mandatory)][string]$AppApk,[Parameter(Mandatory)][string]$TestApk,
 [Parameter(Mandatory)][string]$Aapt,[Parameter(Mandatory)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'runner_report.ps1')
if($env:GITHUB_ACTIONS -cne 'true' -or $Serial -cne 'emulator-5554'){throw 'Only the explicitly created hosted emulator-5554 is supported'}
if(Test-Path $EvidenceDirectory){throw 'Fresh hosted evidence required'}
New-Item -ItemType Directory $EvidenceDirectory|Out-Null
$evidence=(Resolve-Path $EvidenceDirectory).Path
$package='tr.com.soundconnect.app.warmtest';$testPackage="$package.test"
$owned=@();$passed=$false
function Device([string]$Name,[string[]]$Arguments,[int]$Timeout=60){
 $result=Invoke-BridgeProcess 'adb' (@('-s',$Serial)+$Arguments) $Timeout
 $result.output|Set-Content "$evidence/$Name.log"
 if($result.timedOut -or $result.exitCode -ne 0){throw "$Name failed or timed out"}
 return $result.output.Trim()
}
try {
 if((Device 'serial' @('get-serialno')) -cne $Serial -or (Device 'qemu' @('shell','getprop','ro.kernel.qemu')) -cne '1'){throw 'Exact hosted emulator identity required'}
 if((Device 'user' @('shell','am','get-current-user')) -cne '0'){throw 'User 0 required'}
 if((Device 'abi' @('shell','getprop','ro.product.cpu.abi')) -cne 'x86_64' -or
    (Device 'api' @('shell','getprop','ro.build.version.sdk')) -cne '35'){throw 'Exact hosted API/ABI required'}
 [void](Device 'fingerprint' @('shell','getprop','ro.build.fingerprint'))
 foreach($view in @('installed','retained')){
  $args=@('shell','pm','list','packages','--user','0')
  if($view -eq 'retained'){$args+='-u'}
  $packages=Device $view ($args+@('tr.com.soundconnect.app'))
  if($packages){throw 'Fresh emulator has unexpected product or retained packages'}
 }
 & (Join-Path $PSScriptRoot 'verify_apks.ps1') -AppApk $AppApk -TestApk $TestApk -Aapt $Aapt -EvidenceDirectory "$evidence/apk-gate" | Out-Null
 $repo=(Resolve-Path "$PSScriptRoot/../..").Path
 & python3 "$repo/tool/native_gate.py" inventory --output "$evidence/inventory.json"
 if($LASTEXITCODE -ne 0){throw 'Native source inventory rejected'}
 $inventory=Get-Content "$evidence/inventory.json" -Raw|ConvertFrom-Json
 foreach($pair in @(@($AppApk,$package),@($TestApk,$testPackage))){
  $result=Device ('install-'+$pair[1]) @('install','-t',$pair[0]) 180
  if($result -cnotmatch '(?m)^Success$' -or $result -match 'Failure|Error'){throw 'Install did not succeed'}
  $owned+= $pair[1]
 }
 [void](Device 'grant-owned-warmtest' @('shell','pm','grant','--user','0',$package,'android.permission.POST_NOTIFICATIONS'))
 # Explicit method inventory excludes product acceptance and the normal-manifest-only method.
 $runner=Device 'instrumentation' @('shell','am','instrument','--user','0','-w','-r','-e','class',($inventory.tests -join ','),'-e','bridgeMode','emulator',"$testPackage/androidx.test.runner.AndroidJUnitRunner") 1200
 $report=Read-BridgeRunner $runner $inventory.tests 'emulator'
 $report|ConvertTo-Json -Depth 8|Set-Content "$evidence/native-result.json"
 if(-not $report.valid){throw 'Incomplete/failed/skipped native suite or missing cleanup'}
 $passed=$true
} finally {
 # Only packages successfully installed by this invocation, on this throwaway hosted emulator.
 $cleanup=@()
 $cleanupErrors=@()
 foreach($pkg in $owned){
  try {
   $result=Device ('remove-owned-'+$pkg) @('uninstall',$pkg)
   if($result -cne 'Success'){throw "Owned hosted package cleanup failed: $pkg"}
   $cleanup+=$pkg
  } catch {$cleanupErrors+=$_.Exception.Message}
 }
 $remaining=$null
 if($owned.Count -gt 0){
  try {
   $remaining=Device 'cleanup-retained-inventory' @('shell','pm','list','packages','--user','0','-u','tr.com.soundconnect.app')
   if($remaining){throw 'Owned hosted package retained after cleanup'}
  } catch {$cleanupErrors+=$_.Exception.Message}
 }
 @{passed=($passed -and $cleanupErrors.Count -eq 0);cleaned=$cleanup;remaining=$remaining;serial=$Serial;errors=$cleanupErrors}|ConvertTo-Json|Set-Content "$evidence/cleanup.json"
 if($cleanupErrors.Count -gt 0){throw ($cleanupErrors -join '; ')}
}

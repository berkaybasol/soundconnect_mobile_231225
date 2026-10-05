#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$EvidenceDirectory,
 [string]$HostScript=(Join-Path $PSScriptRoot 'run_vivo.ps1'), [switch]$Bil007)
$ErrorActionPreference='Stop'
$requestedEvidence=$EvidenceDirectory
$hostRoot=Split-Path (Resolve-Path -LiteralPath $HostScript).Path
. $HostScript
$EvidenceDirectory=$requestedEvidence
if(Test-Path -LiteralPath $EvidenceDirectory){throw 'Use a new evidence directory'}
[void](New-Item -ItemType Directory -Path $EvidenceDirectory)
$root=(Resolve-Path -LiteralPath $EvidenceDirectory).Path
# Synthetic files exercise the same fixed BIL-003 provenance path contract.
$fixtureRoot=Join-Path $root $(if($Bil007){'tasks/BIL-007/evidence/01-developer-01'}else{'tasks/BIL-003/evidence/01-synthetic-fixtures'})
[void](New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'apks'))
$package='tr.com.soundconnect.app.warmtest';$runner='androidx.test.runner.AndroidJUnitRunner'
$classes=@('com.berkayb.soundconnect.soundconnect_23_12_25codx.NativePushBridgeLifecycleTest','com.berkayb.soundconnect.soundconnect_23_12_25codx.NativeBridgeFixtureTest')
$nativeRoot=Join-Path $PSScriptRoot '../../android/app/src'
$testSources=@((Join-Path $nativeRoot 'androidTest/kotlin/com/berkayb/soundconnect/soundconnect_23_12_25codx/NativePushBridgeLifecycleTest.kt'),
 (Join-Path $nativeRoot 'bridgeTest/kotlin/com/berkayb/soundconnect/soundconnect_23_12_25codx/NativeBridgeFixtureTest.kt'))
if($Bil007){
 $classes+= 'com.berkayb.soundconnect.soundconnect_23_12_25codx.OverthinkingNotificationInstrumentationTest'
 $testSources+=Join-Path $nativeRoot 'androidTest/kotlin/com/berkayb/soundconnect/soundconnect_23_12_25codx/OverthinkingNotificationInstrumentationTest.kt'
}
$tests=@(for($i=0;$i -lt $classes.Count;$i++){
 foreach($method in [regex]::Matches((Get-Content -LiteralPath $testSources[$i] -Raw),'(?m)^ {4}@Test[ \t]+fun\s+(\w+)\s*\(')){$classes[$i]+'#'+$method.Groups[1].Value}
})
$app=Join-Path $fixtureRoot 'apks/fixture-app.apk';$test=Join-Path $fixtureRoot 'apks/fixture-test.apk'
'SYNTHETIC, NOT APK'|Set-Content -LiteralPath $app
'SYNTHETIC TEST, NOT APK'|Set-Content -LiteralPath $test
$appHash=(Get-FileHash -LiteralPath $app).Hash;$testHash=(Get-FileHash -LiteralPath $test).Hash
$sources=@(1..6|ForEach-Object {$path=Join-Path $root "source$_.txt";'SYNTHETIC SOURCE'|Set-Content -LiteralPath $path;@{path=$path;sha256=(Get-FileHash -LiteralPath $path).Hash}})
$sources+=@($testSources|ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash}})
$base=@{package=$package;testPackage="$package.test";runner=$runner;classes=$classes;tests=$tests;sources=$sources;app=@{path=$app;sha256=$appHash};test=@{path=$test;sha256=$testHash}}
$identity=@{manufacturer='vivo';model='Fixture Model';fingerprint='vivo/fixture/device:13/build:user/release-keys';android='13';abi='arm64-v8a'}
$approval=@{approved=$true;readyNow=$true;userMessage='Synthetic test authorization, never real consent';source='synthetic';recordedAt='synthetic';serial='fixture-serial';androidUser=0;runId='fixture-run';appSha256=$appHash;testSha256=$testHash}
foreach($key in $identity.Keys){$approval[$key]=$identity[$key]}
$lines=[Collections.Generic.List[string]]::new()
foreach($id in $tests){
 $parts=$id.Split('#')
 $lines.Add("INSTRUMENTATION_STATUS: class=$($parts[0])");$lines.Add("INSTRUMENTATION_STATUS: test=$($parts[1])")
 $lines.Add("INSTRUMENTATION_STATUS: numtests=$($tests.Count)");$lines.Add('INSTRUMENTATION_STATUS_CODE: 1')
 if($parts[0] -ceq $classes[0] -or $parts[0].EndsWith('.OverthinkingNotificationInstrumentationTest')){$lines.Add("INSTRUMENTATION_STATUS: bridgeCleanup=fixture-run:$($parts[1]):empty");$lines.Add('INSTRUMENTATION_STATUS_CODE: 2')}
 $lines.Add("INSTRUMENTATION_STATUS: class=$($parts[0])");$lines.Add("INSTRUMENTATION_STATUS: test=$($parts[1])")
 $lines.Add("INSTRUMENTATION_STATUS: numtests=$($tests.Count)");$lines.Add('INSTRUMENTATION_STATUS_CODE: 0')
}
$lines.Add("OK ($($tests.Count) tests)");$lines.Add('INSTRUMENTATION_CODE: -1')
$success=$lines -join "`n"
$cases=@('prepare-default','correct-run','existing-exact','serial-empty','serial-whitespace','serial-emulator','serial-wrong-device',
 'user-missing','user-profile','authorization-missing','authorization-denied','readiness-missing','authorization-wrong-hash','changed-apk',
 'wrong-runner','wrong-target','verifier-rejected','gate-wrong-runner','gate-wrong-target','source-changed','verifier-timeout',
 'identity-missing','identity-case','identity-suffix','current-user-wrong',
 'abi-missing','inventory-unreadable','partial-install','foreign-installed-apk','shared-uid','dirty-recipient','dirty-reset','atomic-residue',
 'state-unreadable','existing-process','existing-cards','existing-activity','device-timeout','install-failure','instrumentation-timeout',
 'crash-exit-zero','zero-tests','skip','missing-final','missing-cleanup','duplicate-test','post-state-dirty',
 'installed-wrong-runner','installed-wrong-target','absent-state-control','extra-final-code')
$inventoryErrors=[ordered]@{
 'retained-app'='Retained/uninstalled test package'
 'retained-test'='Retained/uninstalled test package'
 'retained-both'='Retained/uninstalled test package'
 'visible-app-retained-test'='Retained/uninstalled test package'
 'visible-test-retained-app'='Retained/uninstalled test package'
 'retained-query-error'='before-including-uninstalled-packages failed: exit 1'
 'retained-query-timeout'='Timed out: before-including-uninstalled-packages'
 'retained-query-unreadable'='Unreadable package inventory'
 'retained-query-missing-uid'='Unreadable package inventory'
 'retained-query-unexpected-package'='Unreadable package inventory'
 'retained-query-duplicate'='Duplicate package entry'
 'installed-query-duplicate'='Duplicate package entry'
 'retained-query-missing-installed'='Inconsistent package views'
 'retained-query-uid-conflict'='Mismatch: package views UID'
 'retained-query-version-conflict'='Mismatch: package views version'
 'retained-query-case-mismatch'='Inconsistent package views'
}
$cases+=@($inventoryErrors.Keys)+@('inventory-prefix-control','inventory-empty-control')
$cases+=@('signer-missing','signer-failure','signer-multiple','signer-pair-mismatch','inventory-missing-test','mutable-apk',
 'upgrade-success','upgrade-without-selection','upgrade-authorization-manifest-mismatch','upgrade-signer-mismatch','upgrade-wrong-old-hash',
 'upgrade-dirty','upgrade-first-install-failure','upgrade-second-install-failure','upgrade-mixed-pair-rejected','upgrade-uid-changed','upgrade-retained')
$oldRoot=Join-Path $root 'tasks/BIL-001/evidence/03-synthetic-old'
[void](New-Item -ItemType Directory -Path (Join-Path $oldRoot 'apks'))
$oldApp=Join-Path $oldRoot 'apks/old-app.apk'; $oldTest=Join-Path $oldRoot 'apks/old-test.apk'
'OLD SYNTHETIC APP'|Set-Content -LiteralPath $oldApp; 'OLD SYNTHETIC TEST'|Set-Content -LiteralPath $oldTest
$oldAppHash=(Get-FileHash -LiteralPath $oldApp).Hash; $oldTestHash=(Get-FileHash -LiteralPath $oldTest).Hash
$oldDesc=$base|ConvertTo-Json -Depth 8|ConvertFrom-Json -AsHashtable
$oldDesc.classes=@($classes[0..1]);$oldDesc.tests=@($tests|Where-Object { -not $_.Contains('.OverthinkingNotificationInstrumentationTest#') })
$oldDesc.app=@{path=$oldApp;sha256=$oldAppHash};$oldDesc.test=@{path=$oldTest;sha256=$oldTestHash}
$oldDesc.buildCommand=Join-Path $oldRoot 'build-command.json'
@{exitCode=0;arguments=@(':app:assembleDebug',':app:assembleDebugAndroidTest','-PsoundconnectBridgeHarness=true')}|ConvertTo-Json|Set-Content -LiteralPath $oldDesc.buildCommand
$oldDesc.sources=@($sources|ForEach-Object {@{path=$_.path;sha256=$_.sha256}})
foreach($stage in @('before','after')){
 @($sources|ForEach-Object {@{path=[IO.Path]::GetFileName($_.path);hash=$_.sha256}})|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $oldRoot "build-sources-$stage.json")
}
$oldDelivery=Join-Path $oldRoot 'delivery.json'
$oldDesc|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $oldDelivery
$provenanceErrors=[ordered]@{
 'provenance-inventory-missing'='Previous delivery inventory must be unique'
 'provenance-inventory-duplicate'='Previous delivery inventory must be unique'
 'provenance-inventory-new-suite'='Previous delivery inventory must be unique'
 'provenance-inventory-missing-class'='Previous delivery inventory must be unique'
 'provenance-result-missing'='Previous build result unreadable'
 'provenance-result-broken'='Previous build result unreadable'
 'provenance-result-failed'='Previous successful build result required'
 'provenance-result-null'='Previous successful build result required'
 'provenance-result-string'='Previous successful build result required'
 'provenance-result-contradictory'='Previous successful build result required'
 'provenance-result-timeout'='Previous successful build result required'
 'provenance-command-timeout'='Previous successful build result required'
 'provenance-reference-partial'='Incomplete previous provenance references'
 'provenance-reference-outside'='Previous provenance reference outside delivery root'
 'provenance-snapshot-missing'='Previous source snapshot unreadable'
 'provenance-snapshot-broken'='Previous source snapshot unreadable'
 'provenance-snapshot-shape'='Invalid previous snapshot entries'
 'provenance-snapshot-duplicate'='Duplicate previous snapshot path'
 'provenance-snapshot-conflicting-duplicate'='Duplicate previous snapshot path'
 'provenance-snapshot-invalid-hash'='Invalid previous snapshot entry'
 'provenance-snapshot-missing-source'='Previous source/build provenance mismatch'
 'provenance-snapshot-changed-source'='Previous source/build provenance mismatch'
 'provenance-snapshot-ambiguous-source'='Previous source/build provenance mismatch'
 'provenance-sources-duplicate'='Duplicate previous source path'
 'provenance-sources-alias-duplicate'='Duplicate previous source path'
 'provenance-sources-empty'='Missing previous source provenance'
 'provenance-build-arguments'='Previous isolated build arguments required'
 'provenance-build-conflicting-flag'='Previous isolated build arguments required'
 'provenance-legacy-result-missing'='Previous successful build result required'
 'provenance-legacy-snapshot-duplicate'='Duplicate previous snapshot path'
}
$cases+=@('provenance-new-relative','provenance-new-absolute','provenance-legacy-prepare')+@($provenanceErrors.Keys)
$results=[Collections.Generic.List[object]]::new()
foreach($case in $cases){
 $caseRoot=Join-Path $root $case;[void](New-Item -ItemType Directory -Path $caseRoot)
 $desc=$base|ConvertTo-Json -Depth 8|ConvertFrom-Json -AsHashtable
 $auth=$approval.Clone();$device=$identity.Clone()
 $config=@{mode='Run';delivery=(Join-Path $caseRoot 'delivery.json');evidence=(Join-Path $caseRoot 'run');adb='FAKE_ADB';aapt='FAKE_AAPT';serial='fixture-serial';user=0;runId='fixture-run';identity=(Join-Path $caseRoot 'identity.json');authorization=(Join-Path $caseRoot 'authorization.json')}
 $config.apksigner='FAKE_APKSIGNER'
 if($case.StartsWith('provenance-')){
  $config.mode='Prepare'
  $previousCase=$oldDesc|ConvertTo-Json -Depth 8|ConvertFrom-Json -AsHashtable
  $legacyCase=$case.StartsWith('provenance-legacy-')
  $command=@{arguments=@(':app:assembleDebug',':app:assembleDebugAndroidTest','-PsoundconnectBridgeHarness=true')}
  $buildResult=@{exitCode=0}
  $rows=@($sources|ForEach-Object {@{path=[IO.Path]::GetFileName($_.path);sha256=$_.sha256}})
  $beforeRows=$rows|ConvertTo-Json -Depth 5|ConvertFrom-Json -AsHashtable
  $afterRows=$rows|ConvertTo-Json -Depth 5|ConvertFrom-Json -AsHashtable
  $previousCase.buildCommand='build-command.json'
  if($legacyCase){$command.exitCode=0}else{
   $previousCase.buildExit='build-exit.json';$previousCase.before='source-before.json';$previousCase.after='source-after.json'
  }
  switch($case){
   'provenance-inventory-missing' {$previousCase.tests=@()}
   'provenance-inventory-duplicate' {$previousCase.tests+=@($previousCase.tests[0])}
   'provenance-inventory-new-suite' {$previousCase.tests+=@('com.berkayb.soundconnect.soundconnect_23_12_25codx.OverthinkingNotificationInstrumentationTest#renderedCards')}
   'provenance-inventory-missing-class' {$previousCase.tests=@($previousCase.tests|Where-Object {$_.Contains('.NativePushBridgeLifecycleTest#')})}
   'provenance-result-failed' {$buildResult.exitCode=1}
   'provenance-result-null' {$buildResult.exitCode=$null}
   'provenance-result-string' {$buildResult.exitCode='0'}
   'provenance-result-contradictory' {$command.exitCode=1}
   'provenance-result-timeout' {$buildResult.timedOut=$true}
   'provenance-command-timeout' {$command.timedOut=$true}
   'provenance-reference-partial' {$previousCase.Remove('after')}
   'provenance-reference-outside' {$previousCase.buildExit='../outside.json'}
   'provenance-snapshot-duplicate' {$afterRows+=@($afterRows[0])}
   'provenance-snapshot-conflicting-duplicate' {$afterRows+=@(@{path=$afterRows[0].path;sha256=('0'*64)})}
   'provenance-snapshot-invalid-hash' {$afterRows[0].sha256='invalid'}
   'provenance-snapshot-missing-source' {$afterRows=$afterRows[1..($afterRows.Count-1)]}
   'provenance-snapshot-changed-source' {$afterRows[0].sha256='0'*64}
   'provenance-snapshot-ambiguous-source' {$afterRows+=@(@{path=($sources[0].path.Replace('\','/').Split('/')[-2..-1] -join '/');sha256=$sources[0].sha256})}
   'provenance-sources-duplicate' {$previousCase.sources+=@($previousCase.sources[0])}
   'provenance-sources-alias-duplicate' {$previousCase.sources+=@(@{path=(Join-Path (Split-Path $previousCase.sources[0].path) ('alias/../'+[IO.Path]::GetFileName($previousCase.sources[0].path)));sha256=$previousCase.sources[0].sha256})}
   'provenance-sources-empty' {$previousCase.sources=@()}
   'provenance-build-arguments' {$command.arguments=@(':app:assembleDebug','-PsoundconnectBridgeHarness=true')}
   'provenance-build-conflicting-flag' {$command.arguments+=@('-PsoundconnectBridgeHarness=false')}
   'provenance-legacy-result-missing' {$command.Remove('exitCode')}
   'provenance-legacy-snapshot-duplicate' {$afterRows+=@($afterRows[0])}
  }
  $command|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $caseRoot 'build-command.json')
  if($case -cne 'provenance-result-missing'){$buildResult|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $caseRoot 'build-exit.json')}
  if($case -ceq 'provenance-result-broken'){'not-json'|Set-Content -LiteralPath (Join-Path $caseRoot 'build-exit.json')}
  foreach($stage in @('before','after')){
   $entries=if($stage -ceq 'before'){$beforeRows}else{$afterRows}
   if($legacyCase){$data=@($entries|ForEach-Object {@{path=$_.path;hash=$_.sha256}});$file="build-sources-$stage.json"}
   else{$data=@{inputs=@($entries)};$file="source-$stage.json"}
   if($stage -ceq 'after' -and $case -ceq 'provenance-snapshot-missing'){continue}
   $data|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $caseRoot $file)
  }
  if($case -ceq 'provenance-snapshot-broken'){'not-json'|Set-Content -LiteralPath (Join-Path $caseRoot 'source-after.json')}
  if($case -ceq 'provenance-snapshot-shape'){'{}'|Set-Content -LiteralPath (Join-Path $caseRoot 'source-after.json')}
  if($case -ceq 'provenance-new-absolute'){
   foreach($key in @('buildCommand','buildExit','before','after')){$previousCase[$key]=Join-Path $caseRoot $previousCase[$key]}
  }
  # Old host also receives an absolute command path, so RED is schema behavior,
  # not an incidental inability to resolve this positive fixture's command path.
  if($case -ceq 'provenance-new-relative'){$previousCase.buildCommand=Join-Path $caseRoot $previousCase.buildCommand}
  if($legacyCase){$previousCase.buildCommand=Join-Path $caseRoot $previousCase.buildCommand}
  $config.upgradeFrom=Join-Path $caseRoot 'previous-delivery.json'
  $previousCase|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $config.upgradeFrom
 }
 if($case.StartsWith('upgrade-')){
  $config.upgradeFrom=$oldDelivery
  $auth.dataPreservingUpgrade=$true; $auth.previousDeliverySha256=(Get-FileHash -LiteralPath $oldDelivery).Hash
 }
 switch($case){
  'prepare-default' {$config.mode='Prepare';$config.serial='';$config.user=$null;$config.authorization='not-present'}
  'serial-empty' {$config.serial=''} 'serial-whitespace' {$config.serial=' '}
  'serial-emulator' {$config.serial='emulator-5582'} 'user-missing' {$config.user=$null} 'user-profile' {$config.user=10}
  'authorization-missing' {$config.authorization=Join-Path $caseRoot 'absent.json'}
  'authorization-denied' {$auth.approved=$false} 'readiness-missing' {$auth.readyNow=$false}
  'authorization-wrong-hash' {$auth.appSha256='A'*64}
  'changed-apk' {$desc.app.sha256='B'*64}
  'wrong-runner' {$desc.runner='wrong.Runner'} 'wrong-target' {$desc.package='tr.com.soundconnect.app'}
  'source-changed' {$desc.sources[0].sha256='D'*64}
  'identity-missing' {$device.model=''}
  'signer-missing' {$config.apksigner=''}
  'inventory-missing-test' {$desc.tests=$desc.tests[1..($desc.tests.Count-1)]}
  'mutable-apk' {$mutable=Join-Path $caseRoot 'build';[void](New-Item -ItemType Directory -Path $mutable);Copy-Item -LiteralPath $app -Destination $mutable;$desc.app.path=Join-Path $mutable 'fixture-app.apk'}
  'upgrade-without-selection' {$auth.dataPreservingUpgrade=$false}
  'upgrade-authorization-manifest-mismatch' {$auth.previousDeliverySha256='0'*64}
 }
 $desc|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $config.delivery -Encoding utf8
 $auth|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $caseRoot 'authorization.json') -Encoding utf8
 $device|ConvertTo-Json|Set-Content -LiteralPath $config.identity -Encoding utf8
 $state=@{install=0;instrument=0;device=0;inventory=0;includingUninstalled=0;stateReads=0;stateReadsAtFirstInstall=$null;mutations=@();calls=@()}
 $executor={param($file,$arguments,$timeout)
  $state.calls+=,@($file,$arguments)
  if($file -cne 'FAKE_ADB'){
   if($arguments -contains 'FAKE_APKSIGNER'){
    $signer='A'*64
    if($case -ceq 'signer-pair-mismatch' -and $arguments[-1] -ceq $test){$signer='B'*64}
    if($case -ceq 'upgrade-signer-mismatch' -and $arguments[-1] -cin @($oldApp,$oldTest)){$signer='B'*64}
    $signed="Signer #1 certificate SHA-256 digest: $signer"
    if($case -ceq 'signer-multiple'){$signed+="`nSigner #2 certificate SHA-256 digest: $signer"}
    return @{exitCode=$(if($case -ceq 'signer-failure'){1}else{0});timedOut=$false;output=$signed}
   }
   if($arguments -notcontains (Join-Path $hostRoot 'verify_apks.ps1')){throw 'Actual verifier path was not invoked'}
   $dir=$arguments[-1];[void](New-Item -ItemType Directory -Path $dir)
   $oldGate=$arguments -contains $oldApp
   @{status=$(if($case -ceq 'verifier-rejected'){'REJECTED'}else{'VERIFIED'});appSha256=$(if($oldGate){$oldAppHash}else{$appHash});testSha256=$(if($oldGate){$oldTestHash}else{$testHash});runner=$(if($case -ceq 'gate-wrong-runner'){'wrong.Runner'}else{$runner});targetPackage=$(if($case -ceq 'gate-wrong-target'){'tr.com.soundconnect.app'}else{$package})}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $dir 'apk-gate.json')
   $(if($case -ceq 'abi-missing'){'lib/x86_64/libflutter.so'}else{'lib/arm64-v8a/libflutter.so'})|Set-Content -LiteralPath (Join-Path $dir 'app-assets.log')
   return @{exitCode=0;timedOut=($case -ceq 'verifier-timeout');output='Synthetic verifier output'}
  }
  $state.device++
  if($arguments[0] -cne '-s' -or $arguments[1] -cne 'fixture-serial'){throw 'Missing/wrong exact serial in device command'}
  $output='';$exitCode=0;$timedOut=$false
  $joined=$arguments -join ' '
  if($arguments[2] -ceq 'get-serialno'){$output=$(if($case -ceq 'serial-wrong-device'){'other-serial'}else{'fixture-serial'})}
  elseif($arguments[2] -ceq 'get-state'){$output='device';if($case -ceq 'device-timeout'){$timedOut=$true}}
  elseif($arguments[2] -ceq 'install'){
   $state.install++;$state.mutations+='install'
   if($null -eq $state.stateReadsAtFirstInstall){$state.stateReadsAtFirstInstall=$state.stateReads}
   $output=$(if($case -ceq 'install-failure'){'Failure [SYNTHETIC]'}else{'Success'})
   if($case.StartsWith('upgrade-')){
    if(($arguments[2..6] -join ' ') -cne 'install --user 0 -r -t'){throw 'Upgrade must use exact data-preserving install arguments'}
    if(($case -ceq 'upgrade-first-install-failure' -and $state.install -eq 1) -or ($case -ceq 'upgrade-second-install-failure' -and $state.install -eq 2)){$output='Failure [SYNTHETIC_UPDATE]';$exitCode=1}
   }elseif($arguments -contains '-r'){throw 'Unexpected replacement'}
   # A regressed host must stop at its first attempted mutation in these probes.
   if($inventoryErrors.Contains($case)){$output='Failure [SYNTHETIC_PREINSTALL_BOUNDARY]';$exitCode=1}
  }
  elseif($joined.Contains("'am' 'get-current-user'")){$output=$(if($case -ceq 'current-user-wrong'){'10'}else{'0'})}
  elseif($joined.Contains("'getprop'")){
   $props=@{'ro.product.manufacturer'='vivo';'ro.product.model'='Fixture Model';'ro.build.fingerprint'=$identity.fingerprint;'ro.build.version.release'='13';'ro.product.cpu.abi'='arm64-v8a';'ro.kernel.qemu'='';'ro.hardware'='fixture-hardware'}
   foreach($key in $props.Keys){if($joined.Contains("'$key'")){$output=$props[$key]}}
   if($joined.Contains("'ro.product.model'")){
    if($case -ceq 'identity-case'){$output='FIXTURE MODEL'}
    if($case -ceq 'identity-suffix'){$output='Fixture Model.extra'}
   }
  }
  elseif($joined.Contains("'pm' 'list' 'packages'")){
   $state.inventory++
   # Match the actual remote argument string, including distinct -u and -U.
   $installedQuery="'pm' 'list' 'packages' '--user' '0' '-U' '--show-versioncode' 'tr.com.soundconnect.app'"
   $retainedQuery="'pm' 'list' 'packages' '--user' '0' '-U' '--show-versioncode' '-u' 'tr.com.soundconnect.app'"
   if($arguments.Count -ne 4 -or $arguments[2] -cne 'shell' -or $arguments[3] -cnotin @($installedQuery,$retainedQuery)){throw 'Unexpected package query arguments'}
   $includeUninstalled=$arguments[3] -ceq $retainedQuery
   if($includeUninstalled){$state.includingUninstalled++}
   $output="package:tr.com.soundconnect.app versionCode:1 uid:10111`npackage:tr.com.soundconnect.app.preview versionCode:1 uid:10112"
   $preexisting=$case -cin @('existing-exact','partial-install','foreign-installed-apk','shared-uid','dirty-recipient','dirty-reset','atomic-residue','state-unreadable','existing-process','existing-cards','existing-activity')
   $preexisting=$preexisting -or $case.StartsWith('upgrade-')
   if($preexisting -or $state.install -ge 2){
    $uid=$(if($case -ceq 'shared-uid'){'10111'}else{'10113'})
    $output+="`npackage:$package versionCode:1 uid:$uid"
    if($case -cne 'partial-install'){$output+="`npackage:$package.test versionCode:1 uid:10114"}
   }
   if($case -ceq 'inventory-unreadable'){$output='SecurityException'}
   $appLine="package:$package versionCode:1 uid:10113"
   $testLine="package:$package.test versionCode:1 uid:10114"
   if($case -ceq 'upgrade-retained' -and -not $includeUninstalled){$output=$output.Replace("`n$testLine",'')}
   if($case -ceq 'upgrade-uid-changed' -and $state.install -eq 2){$output=$output.Replace('uid:10114','uid:10116')}
   switch($case){
    'retained-app' {if($includeUninstalled){$output+="`n$appLine"}}
    'retained-test' {if($includeUninstalled){$output+="`n$testLine"}}
    'retained-both' {if($includeUninstalled){$output+="`n$appLine`n$testLine"}}
    'visible-app-retained-test' {$output+="`n$appLine";if($includeUninstalled){$output+="`n$testLine"}}
    'visible-test-retained-app' {$output+="`n$testLine";if($includeUninstalled){$output+="`n$appLine"}}
    'retained-query-error' {if($includeUninstalled){$output='Error: synthetic package service failure';$exitCode=1}}
    'retained-query-timeout' {if($includeUninstalled){$timedOut=$true}}
    'retained-query-unreadable' {if($includeUninstalled){$output='SecurityException'}}
    'retained-query-missing-uid' {if($includeUninstalled){$output+="`npackage:$package versionCode:1"}}
    'retained-query-unexpected-package' {if($includeUninstalled){$output+="`npackage:other.app versionCode:1 uid:10115"}}
    'retained-query-duplicate' {if($includeUninstalled){$output+="`n$appLine`n$appLine"}}
    'installed-query-duplicate' {if(-not $includeUninstalled){$output+="`n$appLine`n$appLine"}}
    'retained-query-missing-installed' {if(-not $includeUninstalled){$output+="`n$appLine`n$testLine"}}
    'retained-query-uid-conflict' {$output+="`n$appLine`n$testLine";if($includeUninstalled){$output=$output.Replace('uid:10114','uid:10115')}}
    'retained-query-version-conflict' {$output+="`n$appLine`n$testLine";if($includeUninstalled){$output=$output.Replace("$package.test versionCode:1","$package.test versionCode:2")}}
    'retained-query-case-mismatch' {$output+="`n$appLine`n$testLine";if($includeUninstalled){$output=$output.Replace('.warmtest.test ','.warmtest.TEST ')}}
    'inventory-prefix-control' {
     # Valid unrelated/suffix/case siblings must never stand in for the exact pair.
     $output+="`npackage:$package.extra versionCode:1 uid:10115`npackage:$package.test.extra versionCode:1 uid:10116"
     if($includeUninstalled){$output+="`npackage:tr.com.soundconnect.app.WARMTEST versionCode:1 uid:10117"}
    }
    'inventory-empty-control' {if($state.install -eq 0){$output=''}else{$output="$appLine`n$testLine"}}
   }
  }
  elseif($joined.Contains("'pm' 'path'")){$output=$(if($joined.Contains("'$package.test'")){'package:/data/app/test/base.apk'}else{'package:/data/app/app/base.apk'})}
  elseif($joined.Contains("'sha256sum'")){
   $hash=$(if($joined.Contains("'/data/app/test/base.apk'")){$testHash}else{$appHash})
   if($case.StartsWith('upgrade-') -and $state.install -eq 0){$hash=$(if($joined.Contains("'/data/app/test/base.apk'")){$oldTestHash}else{$oldAppHash})}
   if($case -ceq 'upgrade-mixed-pair-rejected' -and $joined.Contains("'/data/app/app/base.apk'")){$hash=$appHash}
   if($case -ceq 'upgrade-wrong-old-hash'){$hash='C'*64}
   if($case -ceq 'foreign-installed-apk'){$hash='C'*64};$output="$hash  /data/app/fixture/base.apk"
  }
  elseif($joined.Contains("'pidof'")){
   if($case -ceq 'existing-process'){$output='1234'}else{$exitCode=1}
  }
  elseif($joined.Contains('dumpsys notification')){$output=$(if($case -ceq 'existing-cards'){'1'}else{'0'})}
  elseif($joined.Contains('dumpsys activity')){$output=$(if($case -ceq 'existing-activity'){'1'}else{'0'})}
  elseif($joined.Contains('logcat -d')){$output='NO_MATCHING_WARMTEST_CRASH_IN_BOUNDED_LOG'}
  elseif($joined.Contains("'run-as'")){
   $state.stateReads++
   $binding='{"epoch":"00000000-0000-0000-0000-000000000001","recipientId":""}';$reset='{"required":false}'
   if($case -cin @('dirty-recipient','upgrade-dirty') -or ($case -ceq 'post-state-dirty' -and $state.instrument -gt 0)){$binding='{"epoch":"00000000-0000-0000-0000-000000000001","recipientId":"retained"}'}
   if($case -ceq 'dirty-reset'){$reset='{"required":true}'}
   $output="soundconnect-push-rendering`n$binding`nsoundconnect-push-reset`n$reset`n"
   if($case -ceq 'absent-state-control'){$output="soundconnect-push-rendering`nABSENT`nsoundconnect-push-reset`nABSENT`n"}
   if($case -ceq 'atomic-residue'){$output='ATOMIC_RESIDUE';$exitCode=63}
   if($case -ceq 'state-unreadable'){$output='Permission denied';$exitCode=1}
  }
  elseif($joined.Contains("'pm' 'list' 'instrumentation'")){
   $output="instrumentation:$package.test/$runner (target=$package)"
   if($case -ceq 'installed-wrong-runner'){$output=$output.Replace($runner,'wrong.Runner')}
   if($case -ceq 'installed-wrong-target'){$output="instrumentation:$package.test/$runner (target=tr.com.soundconnect.app)"}
  }
  elseif($joined.Contains("'am' 'instrument'")){
   $state.instrument++;$state.mutations+='instrument';$output=$success
   if(-not $joined.Contains("'class' '$($classes -join ',')'") -or -not $joined.Contains("'bridgeMode' 'isolated-vivo'")){throw 'Wrong class/physical selection command'}
   switch($case){
    'instrumentation-timeout' {$timedOut=$true}
    'crash-exit-zero' {$output="INSTRUMENTATION_STATUS: class=$($classes[0])`nINSTRUMENTATION_STATUS: test=lifecycle1`nINSTRUMENTATION_STATUS: numtests=36`nINSTRUMENTATION_STATUS_CODE: 1`nINSTRUMENTATION_RESULT: shortMsg=Process crashed.`nINSTRUMENTATION_CODE: 0"}
    'zero-tests' {$output="OK (0 tests)`nINSTRUMENTATION_CODE: -1"}
    'skip' {$output=$output.Replace('INSTRUMENTATION_STATUS_CODE: 0','INSTRUMENTATION_STATUS_CODE: -3')}
    'missing-final' {$output=$output.Replace('INSTRUMENTATION_CODE: -1','')}
    'extra-final-code' {$output+="`nINSTRUMENTATION_CODE: 0"}
    'missing-cleanup' {$output=$output.Replace('bridgeCleanup=fixture-run:','bridgeCleanup=wrong-run:')}
    'duplicate-test' {$output=$output.Replace('test='+$tests[-1].Split('#')[1],'test='+$tests[-2].Split('#')[1])}
   }
  }
  else {throw "Unexpected fake command: $joined"}
  return @{exitCode=$exitCode;timedOut=$timedOut;output=$output}
 }.GetNewClosure()
 $errorText=$null
 try{[void](Invoke-BridgeVivo $config $executor)}catch{$errorText=$_.Exception.Message}
 $report=Get-Content -LiteralPath (Join-Path $config.evidence 'result.json') -Raw|ConvertFrom-Json
 $expectedSuccess=$case -cin @('prepare-default','correct-run','existing-exact','absent-state-control','inventory-prefix-control','inventory-empty-control','upgrade-success','provenance-new-relative','provenance-new-absolute','provenance-legacy-prepare')
 $postInstall=$case -cin @('install-failure','instrumentation-timeout','crash-exit-zero','zero-tests','skip','missing-final','missing-cleanup','duplicate-test','post-state-dirty','installed-wrong-runner','installed-wrong-target','extra-final-code')
 $postInstall=$postInstall -or $case -cin @('upgrade-first-install-failure','upgrade-second-install-failure','upgrade-uid-changed')
 $ok=if($expectedSuccess){$null -eq $errorText -and $report.status -cin @('PREPARED_NO_DEVICE_ACTION','PASSED_ISOLATED_NATIVE_ONLY')}else{$null -ne $errorText -and $report.status -ceq 'REJECTED'}
 if(-not $expectedSuccess -and -not $postInstall){$ok=$ok -and $state.install -eq 0 -and $state.instrument -eq 0}
 if($case -ceq 'prepare-default'){$ok=$ok -and $state.device -eq 0}
 if($case -ceq 'correct-run'){$ok=$ok -and $state.install -eq 2 -and $state.instrument -eq 1}
 if($case -ceq 'existing-exact'){$ok=$ok -and $state.install -eq 0 -and $state.instrument -eq 1}
 if($expectedSuccess -and $config.mode -cne 'Prepare'){$ok=$ok -and $state.includingUninstalled -eq 1}
 if($case.StartsWith('provenance-')){
  $ok=$ok -and $state.device -eq 0 -and -not $report.deviceMutationsStarted
  if($provenanceErrors.Contains($case)){$ok=$ok -and $errorText -clike "*$($provenanceErrors[$case])*"}
 }
 if($case -cin @('inventory-prefix-control','inventory-empty-control')){$ok=$ok -and $state.install -eq 2 -and $state.instrument -eq 1}
 if($inventoryErrors.Contains($case)){
  $ok=$ok -and $errorText -clike "*$($inventoryErrors[$case])*" -and -not $report.deviceMutationsStarted
  if($case -cne 'installed-query-duplicate'){$ok=$ok -and $state.includingUninstalled -eq 1}
  $ok=$ok -and $state.stateReads -eq 0
 }
 if($postInstall){$ok=$ok -and $state.install -le 2 -and $state.instrument -le 1}
 if($case -ceq 'upgrade-success'){$ok=$ok -and $state.install -eq 2 -and $state.instrument -eq 1 -and $state.stateReadsAtFirstInstall -eq 1}
 if($case -ceq 'upgrade-first-install-failure'){$ok=$ok -and $state.install -eq 1 -and $state.instrument -eq 0}
 if($case -cin @('upgrade-second-install-failure','upgrade-uid-changed')){$ok=$ok -and $state.install -eq 2 -and $state.instrument -eq 0}
 $results.Add(@{name=$case;passed=[bool]$ok;error=$errorText;status=$report.status;install=$state.install;instrument=$state.instrument;deviceCalls=$state.device;
  includingUninstalledQueries=$state.includingUninstalled;stateReads=$state.stateReads;stateReadsAtFirstInstall=$state.stateReadsAtFirstInstall})
}
# Exercise actual process timeout handling against an inert local PowerShell child.
$timeoutResult=Invoke-BridgeProcess (Get-Process -Id $PID).Path @('-NoProfile','-Command','Start-Sleep -Seconds 5') 1
$results.Add(@{name='real-local-process-timeout';passed=[bool]$timeoutResult.timedOut;kind='no device'})
$quoted=ConvertTo-BridgeShell @('sh','-c',"for n in a; do`r`n echo '`$n'`r`ndone")
$results.Add(@{name='posix-script-crlf-normalization';passed=(-not $quoted.Contains("`r") -and $quoted.Contains("`n"));kind='real shell serializer'})
$failed=@($results|Where-Object {-not $_.passed}).Count
@{kind='SYNTHETIC_EXECUTOR_NO_DEVICE';tests=$results.Count;failures=$failed;cases=$results}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $root 'results.json') -Encoding utf8
Write-Output "Host regressions: $($results.Count) tests, $failed failures. No device used."
if($failed){$results|Where-Object {-not $_.passed}|ConvertTo-Json -Depth 6;exit 1}

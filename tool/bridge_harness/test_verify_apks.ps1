[CmdletBinding()]
param([Parameter(Mandatory)][string]$EvidenceDirectory)

# Synthetic aapt text through the REAL verifier in a child PowerShell process.
# No Android SDK, APK build, device, Pester installation or copied parser needed.
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $EvidenceDirectory) { throw 'Use a new evidence directory; prior results are preserved.' }
[void](New-Item -ItemType Directory -Path $EvidenceDirectory)
$OutputRoot = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
$Gate = Join-Path $PSScriptRoot 'verify_apks.ps1'
$Shell = (Get-Process -Id $PID).Path
$Package = 'tr.com.soundconnect.app.warmtest'
$Runner = 'androidx.test.runner.AndroidJUnitRunner'
$Harness = 'integration_test/native_push_bridge_harness.dart'
$Marker = @'
    E: meta-data (line=4)
      A: android:name(0x01010003)="com.soundconnect.bridge_harness" (Raw: "com.soundconnect.bridge_harness")
      A: android:value(0x01010024)="integration_test/native_push_bridge_harness.dart" (Raw: "integration_test/native_push_bridge_harness.dart")
'@
$Instrument = @'
  E: instrumentation (line=6)
    A: android:name(0x01010003)="androidx.test.runner.AndroidJUnitRunner" (Raw: "androidx.test.runner.AndroidJUnitRunner")
    A: android:targetPackage(0x01010021)="tr.com.soundconnect.app.warmtest" (Raw: "tr.com.soundconnect.app.warmtest")
'@
$Isolation = @'
    E: activity
      A: android:name(0x01010003)="com.berkayb.soundconnect.soundconnect_23_12_25codx.MainActivity"
      A: android:exported(0x01010010)=(type 0x12)0x0
    E: provider
      A: android:name(0x01010003)="androidx.core.content.FileProvider"
      A: android:authorities(0x01010018)="tr.com.soundconnect.app.warmtest.collab_share_files"
    E: meta-data
      A: android:name(0x01010003)="firebase_messaging_auto_init_enabled"
      A: android:value(0x01010024)=(type 0x12)0x0
    E: meta-data
      A: android:name(0x01010003)="firebase_analytics_collection_enabled"
      A: android:value(0x01010024)=(type 0x12)0x0
'@
$Base = @{
    'app-badging'="package: name='$Package' versionCode='1'`napplication-debuggable`n"
    'test-badging'="package: name='$Package.test' versionCode='1'`n"
    'app-manifest'="E: manifest`n  E: application`n    A: android:allowBackup(0x01010280)=(type 0x12)0x0`n$Marker`n$Isolation`n"
    'test-manifest'="E: manifest`n$Instrument`n"
    'app-resources'="  resource 0x7f040001 ${Package}:bool/soundconnect_push_enabled: t=0x12 d=0xffffffff (s=0x0008 r=0x00)`n"
    'app-assets'="assets/flutter_assets/kernel_blob.bin`n"
}
$Shim = @'
$ErrorActionPreference = 'Stop'
$InputData = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'input.json') -Raw | ConvertFrom-Json
if ($InputData.failAapt) { Write-Error 'Synthetic aapt failure'; exit 7 }
if ($args[0] -ceq 'list') { $Name='app-assets' }
elseif ($args[1] -ceq '--values') { $Name='app-resources' }
else {
    $Prefix=if ([IO.Path]::GetFileName($args[2]) -ceq 'fixture-test.apk') {'test'} else {'app'}
    $Kind=if ($args[1] -ceq 'badging') {'badging'} else {'manifest'}
    $Name="$Prefix-$Kind"
}
Write-Output $InputData.text.$Name
exit 0
'@
$Cases = @(
    @{name='control';expected='VERIFIED'},
    @{name='app-case';log='app-badging';from=$Package;to='tr.com.soundconnect.app.Warmtest';field='package'},
    @{name='test-case';log='test-badging';from="$Package.test";to="$Package.Test";field='testPackage'},
    @{name='target-case';log='test-manifest';from=$Package;to='tr.com.soundconnect.app.Warmtest';field='targetPackage'},
    @{name='runner-case';log='test-manifest';from=$Runner;to='androidx.test.runner.AndroidJunitRunner';field='runner'},
    @{name='harness-case';log='app-manifest';from=$Harness;to='integration_test/Native_push_bridge_harness.dart';field='harnessTarget'},
    @{name='app-product';log='app-badging';from=$Package;to='tr.com.soundconnect.app';field='package'},
    @{name='app-preview';log='app-badging';from=$Package;to='tr.com.soundconnect.app.preview';field='package'},
    @{name='app-other';log='app-badging';from=$Package;to='other.warmtest';field='package'},
    @{name='app-suffix';log='app-badging';from=$Package;to="$Package.extra";field='package'},
    @{name='app-ignorable-character';log='app-badging';from=$Package;to=($Package+[char]0x200B);field='package'},
    @{name='test-suffix';log='test-badging';from="$Package.test";to="$Package.test.extra";field='testPackage'},
    @{name='target-product';log='test-manifest';from=$Package;to='tr.com.soundconnect.app';field='targetPackage'},
    @{name='runner-suffix';log='test-manifest';from=$Runner;to="$Runner.Extra";field='runner'},
    @{name='harness-suffix';log='app-manifest';from=$Harness;to="$Harness.extra";field='harnessTarget'},
    @{name='marker-name-case';log='app-manifest';from='com.soundconnect.bridge_harness';to='com.soundconnect.Bridge_harness'},
    @{name='marker-name-suffix';log='app-manifest';from='com.soundconnect.bridge_harness';to='com.soundconnect.bridge_harness.extra'},
    @{name='missing-instrumentation';log='test-manifest';from=$Instrument;to=''},
    @{name='duplicate-instrumentation';log='test-manifest';from=$Instrument;to="$Instrument`n$Instrument"},
    @{name='duplicate-runner-attribute';log='test-manifest';from=$Instrument;to=($Instrument+"`n    A: android:name(0x01010003)=`"$Runner`"")},
    @{name='missing-marker';log='app-manifest';from=$Marker;to=''},
    @{name='duplicate-marker';log='app-manifest';from=$Marker;to="$Marker`n$Marker"},
    @{name='duplicate-package';log='app-badging';from="package: name='$Package' versionCode='1'";to="package: name='$Package' versionCode='1'`npackage: name='$Package' versionCode='1'"},
    @{name='shared-app-uid';log='app-manifest';from='E: manifest';to="E: manifest`n  A: android:sharedUserId(0x0101000b)=`"shared`""},
    @{name='shared-test-uid';log='test-manifest';from='E: manifest';to="E: manifest`n  A: android:sharedUserId(0x0101000b)=`"shared`""},
    @{name='push-false';log='app-resources';from='d=0xffffffff';to='d=0x00000000'},
    @{name='push-missing';log='app-resources';from='soundconnect_push_enabled';to='unrelated'},
    @{name='push-mixed';log='app-resources';from=$Base['app-resources'];to=($Base['app-resources']+$Base['app-resources'].Replace('d=0xffffffff','d=0x00000000'))},
    @{name='not-debuggable';log='app-badging';from='application-debuggable';to='application-label'},
    @{name='backup-enabled';log='app-manifest';from='(type 0x12)0x0';to='(type 0x12)0xffffffff'},
    @{name='firebase-provider';log='app-manifest';from='E: application';to="E: application`n    E: provider`n      A: android:name(0x01010003)=`"com.google.firebase.provider.FirebaseInitProvider`""},
    @{name='kernel-missing';log='app-assets';from='kernel_blob.bin';to='other.bin'},
    @{name='aapt-failure';failAapt=$true},
    # Expected text only in Raw must not disguise a different primary value.
    @{name='runner-raw-decoy';log='test-manifest';from=('="'+$Runner+'"');to='="wrong.Runner"';field='runner';observed='wrong.Runner'},
    @{name='harness-raw-decoy';log='app-manifest';from=('="'+$Harness+'"');to='="wrong.dart"';field='harnessTarget';observed='wrong.dart'},
    @{name='missing-isolation';log='app-manifest';from=$Isolation;to=''},
    @{name='exported-main';log='app-manifest';from='android:exported(0x01010010)=(type 0x12)0x0';to='android:exported(0x01010010)=(type 0x12)0xffffffff'},
    @{name='product-authority';log='app-manifest';from="$Package.collab_share_files";to='tr.com.soundconnect.app.collab_share_files'},
    @{name='preview-authority';log='app-manifest';from="$Package.collab_share_files";to='tr.com.soundconnect.app.preview.collab_share_files'},
    @{name='authority-case';log='app-manifest';from="$Package.collab_share_files";to='tr.com.soundconnect.app.Warmtest.collab_share_files'},
    @{name='firebase-auto-init-missing';log='app-manifest';from='firebase_messaging_auto_init_enabled';to='wrong_metadata'},
    @{name='firebase-analytics-missing';log='app-manifest';from='firebase_analytics_collection_enabled';to='wrong_metadata'},
    @{name='firebase-plugin-provider';log='app-manifest';from='androidx.core.content.FileProvider';to='io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingInitProvider'}
)
foreach ($Entry in @(
    @{name='launcher';text='android.intent.category.LAUNCHER'},
    @{name='product-view';text='android.intent.action.VIEW'},
    @{name='product-main';text='android.intent.action.MAIN'},
    @{name='browsable';text='android.intent.category.BROWSABLE'},
    @{name='fcm-intent';text='com.google.firebase.MESSAGING_EVENT'})) {
    $Cases += @{name=$Entry.name;log='app-manifest';from=$Isolation;to=($Isolation+"`n    E: intent-filter`n      E: action`n        A: android:name(0x01010003)=`"$($Entry.text)`"")}
}
foreach ($Entry in @(
    @{name='https-link';attr='android:scheme';text='https'},
    @{name='custom-link';attr='android:scheme';text='soundconnect'},
    @{name='link-host';attr='android:host';text='soundconnect.com.tr'})) {
    $Cases += @{name=$Entry.name;log='app-manifest';from=$Isolation;to=($Isolation+"`n    E: intent-filter`n      E: data`n        A: $($Entry.attr)(0x01010027)=`"$($Entry.text)`"")}
}
foreach ($Component in @('com.google.firebase.messaging.FirebaseMessagingService',
    'com.berkayb.soundconnect.soundconnect_23_12_25codx.SoundconnectMessagingService',
    'io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundService',
    'com.google.firebase.components.ComponentDiscoveryService')) {
    $Cases += @{name=$Component.Split('.')[-1];log='app-manifest';from=$Isolation;to=($Isolation+"`n    E: service`n      A: android:name(0x01010003)=`"$Component`"")}
}
$Results = [Collections.Generic.List[object]]::new()
foreach ($Case in $Cases) {
    $Dir=Join-Path $OutputRoot $Case.name
    [void](New-Item -ItemType Directory -Path $Dir)
    $Texts=$Base.Clone()
    if ($Case.log) {
        if (-not $Texts[$Case.log].Contains($Case.from)) { throw "Bad regression input: $($Case.name)" }
        $Texts[$Case.log]=$Texts[$Case.log].Replace($Case.from,$Case.to)
    }
    @{kind='SYNTHETIC_AAPT_TEXT_NOT_APK_ACCEPTANCE';text=$Texts;failAapt=[bool]$Case.failAapt}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $Dir 'input.json') -Encoding utf8
    $Shim|Set-Content -LiteralPath (Join-Path $Dir 'aapt.ps1') -Encoding utf8
    foreach ($File in @('fixture-app.apk','fixture-test.apk')) { 'Synthetic placeholder; not an APK.'|Set-Content -LiteralPath (Join-Path $Dir $File) }
    $ArgsList=@('-NoProfile','-File',$Gate,'-AppApk',(Join-Path $Dir 'fixture-app.apk'),'-TestApk',(Join-Path $Dir 'fixture-test.apk'),'-Aapt',(Join-Path $Dir 'aapt.ps1'),'-EvidenceDirectory',(Join-Path $Dir 'gate'))
    $Log=Join-Path $Dir 'console.log'
    & $Shell @ArgsList *> $Log
    $Code=$LASTEXITCODE
    $Report=Get-Content -LiteralPath (Join-Path $Dir 'gate/apk-gate.json') -Raw|ConvertFrom-Json
    $Expected=if($Case.expected){$Case.expected}else{'REJECTED'}
    $Pass=$Report.status -ceq $Expected -and (($Expected -ceq 'VERIFIED' -and $Code -eq 0) -or ($Expected -ceq 'REJECTED' -and $Code -ne 0 -and $Report.error))
    if ($Case.field) {
        $Observed=if($Case.ContainsKey('observed')){$Case.observed}else{$Case.to}
        $Pass=$Pass -and [string]::Equals($Report.observed.($Case.field),$Observed,[StringComparison]::Ordinal)
        # REJECTED must never publish a constant expected identity as verified fact.
        $Pass=$Pass -and $null -eq $Report.($Case.field)
    }
    if ($Expected -ceq 'VERIFIED') {
        foreach($Field in @('package','testPackage','targetPackage','runner','harnessTarget')) {
            $Pass=$Pass -and [string]::Equals($Report.$Field,$Report.observed.$Field,[StringComparison]::Ordinal)
        }
    }
    $Results.Add(@{name=$Case.name;expected=$Expected;actual=$Report.status;passed=[bool]$Pass;exitCode=$Code;cwd=(Get-Location).Path;command=$Shell;arguments=$ArgsList;log=$Log;report=(Join-Path $Dir 'gate/apk-gate.json')})
}
$Failed=@($Results|Where-Object {-not $_.passed}).Count
@{kind='SYNTHETIC_AAPT_TEXT_NOT_APK_ACCEPTANCE';gate=$Gate;gateSha256=(Get-FileHash -LiteralPath $Gate).Hash;tests=$Results.Count;failures=$Failed;skipped=0;cases=$Results}|ConvertTo-Json -Depth 9|Set-Content -LiteralPath (Join-Path $OutputRoot 'results.json') -Encoding utf8
Write-Output "APK gate regressions: $($Results.Count) tests, $Failed failures, 0 skipped. Synthetic text only."
if ($Failed) { $Results|Where-Object {-not $_.passed}|ConvertTo-Json -Depth 5; exit 1 }

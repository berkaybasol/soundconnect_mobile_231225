[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AppApk,
    [Parameter(Mandatory)][string]$TestApk,
    [Parameter(Mandatory)][string]$Aapt,
    [Parameter(Mandatory)][string]$EvidenceDirectory
)

# Read-only APK/runner gate. Does not install, clear data, start ADB or run tests.
$ErrorActionPreference = 'Stop'
$Package = 'tr.com.soundconnect.app.warmtest'
$Runner = 'androidx.test.runner.AndroidJUnitRunner'
$Harness = 'integration_test/native_push_bridge_harness.dart'
$AppPath = (Resolve-Path -LiteralPath $AppApk).Path
$TestPath = (Resolve-Path -LiteralPath $TestApk).Path
$AaptPath = (Resolve-Path -LiteralPath $Aapt).Path
[void](New-Item -ItemType Directory -Path $EvidenceDirectory -Force)
$EvidencePath = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
$Commands = [Collections.Generic.List[object]]::new()

function Read-Apk([string]$Name, [string[]]$Arguments) {
    $Log = Join-Path $EvidencePath "$Name.log"
    $Output = & $AaptPath @Arguments 2>&1 | Out-String
    $Code = $LASTEXITCODE
    $Output | Set-Content -LiteralPath $Log -Encoding utf8
    $Commands.Add(@{ cwd=(Get-Location).Path; command=$AaptPath; arguments=$Arguments; exitCode=$Code; log=$Log })
    if ($Code -ne 0) { throw "aapt inspection failed: $Name (exit $Code)" }
    return $Output
}

# Parse the primary aapt value, not a matching substring in its optional Raw text.
# Regex.Matches is case-sensitive; identities use ordinal equality without normalization.
function Read-Package([string]$Badging) {
    $Values = [regex]::Matches($Badging, "(?m)^package: name='(?<value>[^'\r\n]*)'(?:[ \t]|\r?$)")
    if ($Values.Count -ne 1) { throw 'Exactly one package identity is required.' }
    return $Values[0].Groups['value'].Value
}

function Read-Attribute([string]$Body, [string]$Name) {
    $Pattern = '(?m)^[ \t]*A: ' + [regex]::Escape($Name) + '(?:\(0x[0-9a-fA-F]+\))?="(?<value>[^"\r\n]*)"(?:[ \t]|\r?$)'
    $Values = [regex]::Matches($Body, $Pattern)
    if ($Values.Count -ne 1) { throw "Exactly one string attribute required: $Name" }
    return $Values[0].Groups['value'].Value
}

$Observed = @{}
$Result = @{ status='REJECTED'; app=$AppPath; test=$TestPath; observed=$Observed }
try {
    $AppBadge = Read-Apk 'app-badging' @('dump', 'badging', $AppPath)
    $Observed.package = Read-Package $AppBadge
    if (-not [string]::Equals($Observed.package, $Package, [StringComparison]::Ordinal)) {
        throw 'App APK is not the exact isolated warmtest package.'
    }
    if ($AppBadge -notmatch '(?m)^application-debuggable') { throw 'Harness must be debuggable.' }
    $AppManifest = Read-Apk 'app-manifest' @('dump', 'xmltree', $AppPath, 'AndroidManifest.xml')
    $TestBadge = Read-Apk 'test-badging' @('dump', 'badging', $TestPath)
    $TestManifest = Read-Apk 'test-manifest' @('dump', 'xmltree', $TestPath, 'AndroidManifest.xml')
    $Observed.testPackage = Read-Package $TestBadge
    if (-not [string]::Equals($Observed.testPackage, ($Package + '.test'), [StringComparison]::Ordinal)) {
        throw 'Test APK package is not the exact harness test identity.'
    }
    foreach ($Manifest in @($AppManifest, $TestManifest)) {
        if ($Manifest -match 'android:sharedUserId') { throw 'Shared Android UID is forbidden.' }
    }
    $Instruments = [regex]::Matches($TestManifest, '(?m)^\s*E: instrumentation[^\r\n]*\r?\n(?<body>(?:\s*A:[^\r\n]*(?:\r?\n|$))*)')
    if ($Instruments.Count -ne 1) { throw 'Exactly one instrumentation runner is required.' }
    $Instrument = $Instruments[0].Groups['body'].Value
    $Observed.runner = Read-Attribute $Instrument 'android:name'
    $Observed.targetPackage = Read-Attribute $Instrument 'android:targetPackage'
    if (-not [string]::Equals($Observed.runner, $Runner, [StringComparison]::Ordinal) -or
        -not [string]::Equals($Observed.targetPackage, $Package, [StringComparison]::Ordinal)) {
        throw 'Unexpected instrumentation runner or targetPackage.'
    }
    $Markers = @([regex]::Matches($AppManifest, '(?m)^\s*E: meta-data[^\r\n]*\r?\n(?<body>(?:\s*A:[^\r\n]*(?:\r?\n|$))*)') |
        Where-Object { [string]::Equals((Read-Attribute $_.Groups['body'].Value 'android:name'), 'com.soundconnect.bridge_harness', [StringComparison]::Ordinal) })
    if ($Markers.Count -ne 1) {
        throw 'Exact immutable Dart harness target marker is required.'
    }
    $Observed.harnessTarget = Read-Attribute $Markers[0].Groups['body'].Value 'android:value'
    if (-not [string]::Equals($Observed.harnessTarget, $Harness, [StringComparison]::Ordinal)) { throw 'Unexpected Dart harness target.' }
    if ($AppManifest.Contains('com.google.firebase.provider.FirebaseInitProvider')) {
        throw 'Synthetic harness must not auto-initialize a Firebase project.'
    }
    # Fail closed on real product routing or Firebase entry points, including plugin providers.
    foreach ($Manifest in @($AppManifest, $TestManifest)) {
        if ($Manifest -cmatch 'android.intent.(?:action.(?:MAIN|VIEW)|category.(?:LAUNCHER|BROWSABLE))"' -or
            $Manifest -cmatch 'android:(?:scheme|host)\(' -or
            $Manifest -cmatch 'com.google.(?:firebase.MESSAGING_EVENT|android.c2dm.intent.RECEIVE)') {
            throw 'Product links, launcher and FCM intent routes are forbidden in harness APKs.'
        }
        $Components = [regex]::Matches($Manifest, '(?m)^\s*E: (?:provider|service|receiver)[^\r\n]*\r?\n(?<body>(?:\s*A:[^\r\n]*(?:\r?\n|$))*)')
        foreach ($Component in $Components) {
            $Name = Read-Attribute $Component.Groups['body'].Value 'android:name'
            if ($Name -match 'firebase' -or $Name.EndsWith('.SoundconnectMessagingService', [StringComparison]::Ordinal)) {
                throw "Firebase entry component forbidden: $Name"
            }
        }
    }
    $Activities = @([regex]::Matches($AppManifest, '(?m)^\s*E: activity[^\r\n]*\r?\n(?<body>(?:\s*A:[^\r\n]*(?:\r?\n|$))*)') |
        Where-Object { (Read-Attribute $_.Groups['body'].Value 'android:name') -ceq 'com.berkayb.soundconnect.soundconnect_23_12_25codx.MainActivity' })
    if ($Activities.Count -ne 1 -or $Activities[0].Groups['body'].Value -cnotmatch 'android:exported[^\r\n]*=\(type 0x12\)0x0(?:\s|$)') {
        throw 'Exactly one non-exported real MainActivity is required.'
    }
    foreach ($MetaName in @('firebase_messaging_auto_init_enabled', 'firebase_analytics_collection_enabled')) {
        $Values = @([regex]::Matches($AppManifest, '(?m)^\s*E: meta-data[^\r\n]*\r?\n(?<body>(?:\s*A:[^\r\n]*(?:\r?\n|$))*)') |
            Where-Object { (Read-Attribute $_.Groups['body'].Value 'android:name') -ceq $MetaName })
        if ($Values.Count -ne 1 -or $Values[0].Groups['body'].Value -cnotmatch 'android:value[^\r\n]*=\(type 0x12\)0x0(?:\s|$)') {
            throw "Explicit disabled metadata required: $MetaName"
        }
    }
    $Observed.providerAuthorities = @()
    foreach ($Pair in @(@{text=$AppManifest;package=$Package}, @{text=$TestManifest;package="$Package.test"})) {
        $Providers = [regex]::Matches($Pair.text, '(?m)^\s*E: provider[^\r\n]*\r?\n(?<body>(?:\s*A:[^\r\n]*(?:\r?\n|$))*)')
        foreach ($Provider in $Providers) {
            $Authority = Read-Attribute $Provider.Groups['body'].Value 'android:authorities'
            $Observed.providerAuthorities += $Authority
            foreach ($Value in $Authority.Split(';')) {
                if (-not $Value.StartsWith($Pair.package + '.', [StringComparison]::Ordinal) -or $Value.Length -le $Pair.package.Length + 1) {
                    throw 'Provider authority must belong to its exact isolated applicationId.'
                }
            }
        }
    }
    if ($AppManifest -notmatch 'android:allowBackup[^\r\n]*=\(type 0x12\)0x0(?:\s|$)') {
        throw 'Harness backup must be disabled.'
    }
    $Resources = Read-Apk 'app-resources' @('dump', '--values', 'resources', $AppPath)
    $PushValues = [regex]::Matches($Resources, '(?m)^\s*resource[^\r\n]*:bool/soundconnect_push_enabled:[^\r\n]*')
    if ($PushValues.Count -eq 0 -or @($PushValues | Where-Object {
        $_.Value -notmatch 't=0x12 d=0xffffffff(?:\s|$)'
    }).Count -ne 0) { throw 'Every packaged push gate configuration must be true.' }
    $Entries = Read-Apk 'app-assets' @('list', $AppPath)
    if ($Entries -cnotmatch '(?m)^assets/flutter_assets/kernel_blob\.bin\r?$') {
        throw 'Debug Dart kernel is missing.'
    }
    $Result = @{
        status='VERIFIED'; app=$AppPath; test=$TestPath; observed=$Observed
        package=$Observed.package; testPackage=$Observed.testPackage; targetPackage=$Observed.targetPackage
        runner=$Observed.runner; harnessTarget=$Observed.harnessTarget; pushEnabled=$true; sharedUid=$false
        appSha256=(Get-FileHash -LiteralPath $AppPath -Algorithm SHA256).Hash
        testSha256=(Get-FileHash -LiteralPath $TestPath -Algorithm SHA256).Hash
        classes=@('com.berkayb.soundconnect.soundconnect_23_12_25codx.NativePushBridgeLifecycleTest',
            'com.berkayb.soundconnect.soundconnect_23_12_25codx.NativeBridgeFixtureTest')
    }
    $Result | ConvertTo-Json -Depth 5
} catch {
    $Result.error = $_.Exception.Message
    throw
} finally {
    $Commands | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $EvidencePath 'commands.json') -Encoding utf8
    $Result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $EvidencePath 'apk-gate.json') -Encoding utf8
}

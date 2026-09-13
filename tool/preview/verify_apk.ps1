[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Apk,
    [Parameter(Mandatory)][string]$Aapt,
    [switch]$Qa
)

$ErrorActionPreference = 'Stop'
$PreviewPackage = 'com.berkayb.soundconnect.soundconnect_23_12_25codx.preview'
$PreviewActivity = 'com.berkayb.soundconnect.soundconnect_23_12_25codx.PreviewActivity'
$ResolvedApk = (Resolve-Path -LiteralPath $Apk).Path
if (-not (Test-Path -LiteralPath $ResolvedApk -PathType Leaf)) { throw 'APK file is required.' }

$Badging = (& $Aapt dump badging $ResolvedApk 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw "aapt could not inspect APK: $Badging" }
$Manifest = (& $Aapt dump xmltree $ResolvedApk AndroidManifest.xml 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw "aapt could not inspect manifest: $Manifest" }
if ($Badging -notmatch "(?m)^package: name='$([regex]::Escape($PreviewPackage))'") {
    throw 'Refusing APK: applicationId is not the isolated preview package.'
}
if ($Badging -notmatch "(?m)^application-label:'SoundConnect Önizleme'") {
    throw 'Refusing APK: preview label is missing.'
}
if ($Badging -notmatch "(?m)^launchable-activity: name='$([regex]::Escape($PreviewActivity))'") {
    throw 'Refusing APK: launcher is not PreviewActivity.'
}

$HasInternet = $Badging -match "uses-permission(?:-sdk-\d+)?: name='android\.permission\.INTERNET'"
if ($HasInternet -ne $Qa.IsPresent) {
    throw 'Refusing APK: INTERNET permission does not match user-preview versus explicit QA mode.'
}
if ($Qa -and $Badging -notmatch '(?m)^application-debuggable') {
    throw 'Refusing QA APK: only debug builds may carry the QA network permission.'
}
foreach ($Permission in @(
    'ACCESS_NETWORK_STATE', 'ACCESS_WIFI_STATE', 'CHANGE_NETWORK_STATE', 'CHANGE_WIFI_STATE',
    'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_MEDIA_PLAYBACK', 'WAKE_LOCK',
    'POST_NOTIFICATIONS', 'RECEIVE_BOOT_COMPLETED'
)) {
    if ($Badging -match "uses-permission(?:-sdk-\d+)?: name='android\.permission\.$Permission'") {
        throw "Refusing APK: unexpected permission $Permission."
    }
}
foreach ($Forbidden in @(
    'android.intent.action.VIEW', 'android.intent.category.BROWSABLE',
    'com.ryanheise.audioservice.AudioService', 'com.ryanheise.audioservice.MediaButtonReceiver',
    'androidx.core.content.FileProvider', 'dev.fluttercommunity.plus.share.ShareFileProvider',
    'io.flutter.plugins.imagepicker.ImagePickerFileProvider',
    'com.google.android.gms.metadata.ModuleDependencies',
    'io.flutter.plugins.urllauncher.WebViewActivity', 'com.yalantis.ucrop.UCropActivity',
    'dev.fluttercommunity.plus.share.SharePlusPendingIntent',
    'com.berkayb.soundconnect.soundconnect_23_12_25codx.MainActivity', 'collab_share_files'
)) {
    if ($Manifest.Contains($Forbidden)) { throw "Refusing APK: unexpected manifest capability $Forbidden." }
}
if ($Manifest -match 'android:sharedUserId') { throw 'Refusing APK: shared Android UID is forbidden.' }
if ($Manifest -notmatch 'android:allowBackup[^\r\n]*=\(type 0x12\)0x0') {
    throw 'Refusing APK: preview backup must be disabled.'
}

$QaMetadata = [regex]::Matches($Manifest, '(?m)^[ \t]*E: meta-data[^\r\n]*\r?\n(?<body>(?:[ \t]*A:[^\r\n]*(?:\r?\n|$))*)') |
    Where-Object { $_.Groups['body'].Value.Contains('com.soundconnect.preview.QA') }
if (@($QaMetadata).Count -ne 1) { throw 'Refusing APK: exactly one immutable QA marker is required.' }
$ExpectedValue = if ($Qa) { '0xffffffff' } else { '0x0' }
if (@($QaMetadata)[0].Groups['body'].Value -notmatch "android:value[^\r\n]*=\(type 0x12\)$ExpectedValue(?:\s|$)") {
    throw 'Refusing APK: QA metadata does not match the selected verification mode.'
}

$Entries = (& $Aapt list $ResolvedApk 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw 'aapt could not inspect preview assets.' }
if ($Entries -notmatch '(?m)^assets/preview/[^/\r\n]+') {
    throw 'Refusing APK: isolated native preview fixtures are missing.'
}
Write-Output "Verified preview APK: $PreviewPackage; QA=$($Qa.IsPresent); INTERNET=$HasInternet"

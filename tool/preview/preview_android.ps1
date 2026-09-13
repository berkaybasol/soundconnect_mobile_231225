[CmdletBinding()]
param(
    [ValidateSet('Build', 'Install', 'Verify')][string]$Action = 'Build',
    [ValidateSet('profile', 'debug')][string]$Mode = 'profile',
    [Parameter(Mandatory)][string]$Aapt,
    [string]$Flutter = 'flutter',
    [string]$Adb = 'adb',
    [string]$DeviceSerial,
    [string]$Apk,
    [switch]$Launch
)

$ErrorActionPreference = 'Stop'
$FrontendRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$PreviewPackage = 'com.berkayb.soundconnect.soundconnect_23_12_25codx.preview'
$PreviewActivity = 'com.berkayb.soundconnect.soundconnect_23_12_25codx.PreviewActivity'
if ($Action -eq 'Install' -and [string]::IsNullOrWhiteSpace($DeviceSerial)) {
    throw 'Install requires an explicit -DeviceSerial.'
}
if ($Launch -and $Action -ne 'Install') { throw '-Launch is supported only with Install.' }
if ($Apk -and $Action -ne 'Verify') { throw '-Apk is accepted only by Verify; installs always build fresh.' }

Push-Location $FrontendRoot
try {
    if ($Action -ne 'Verify') {
        & $Flutter build apk "--$Mode" --target=lib/main_preview.dart `
            --dart-define=SOUNDCONNECT_PREVIEW=true `
            --dart-define=SOUNDCONNECT_BASE_URL=https://preview.soundconnect.invalid
        if ($LASTEXITCODE -ne 0) { throw 'Preview Flutter build failed.' }
        $BuiltApk = Join-Path $FrontendRoot "build/app/outputs/flutter-apk/app-$Mode.apk"
        & (Join-Path $PSScriptRoot 'verify_apk.ps1') -Apk $BuiltApk -Aapt $Aapt
        $OutputDirectory = Join-Path $FrontendRoot 'build/preview'
        [void](New-Item -ItemType Directory -Path $OutputDirectory -Force)
        $Apk = Join-Path $OutputDirectory "soundconnect-preview-$Mode.apk"
        Copy-Item -LiteralPath $BuiltApk -Destination $Apk -Force
    } elseif (-not $Apk) {
        $Apk = Join-Path $FrontendRoot "build/preview/soundconnect-preview-$Mode.apk"
    }
    & (Join-Path $PSScriptRoot 'verify_apk.ps1') -Apk $Apk -Aapt $Aapt
    if ($Action -eq 'Install') {
        & $Adb -s $DeviceSerial install -r $Apk
        if ($LASTEXITCODE -ne 0) { throw 'Preview APK installation failed.' }
        if ($Launch) {
            & $Adb -s $DeviceSerial shell am start -n "$PreviewPackage/$PreviewActivity"
            if ($LASTEXITCODE -ne 0) { throw 'Preview launch failed.' }
        }
    }
    Write-Output "Preview artifact: $Apk"
} finally {
    Pop-Location
}

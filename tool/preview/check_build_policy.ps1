[CmdletBinding()]
param()

# Explicit configuration-only checks. No SDK installation, APK build, emulator or device use.
$ErrorActionPreference = 'Stop'
$FrontendRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$AndroidRoot = Join-Path $FrontendRoot 'android'
$Gradle = Join-Path $AndroidRoot 'gradlew.bat'
$PolicyLogDirectory = Join-Path $FrontendRoot 'build/preview/policy-checks'
[void](New-Item -ItemType Directory -Path $PolicyLogDirectory -Force)
function Encode-Define([string]$Value) {
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
}
$Enabled = Encode-Define 'SOUNDCONNECT_PREVIEW=true'
$Disabled = Encode-Define 'SOUNDCONNECT_PREVIEW=false'
$Invalid = Encode-Define 'SOUNDCONNECT_PREVIEW=TRUE'
$Cases = @(
    @{ Name='ordinary default'; Task='help'; Target='lib/main.dart'; Define=$null; Expected=$null },
    @{ Name='ordinary explicit false'; Task='help'; Target='lib/main.dart'; Define=$Disabled; Expected=$null },
    @{ Name='preview main'; Task='help'; Target='lib/main_preview.dart'; Define=$Enabled; Expected=$null },
    @{ Name='preview QA'; Task='help'; Target='integration_test/feed_preview_device_test.dart'; Define=$Enabled; Expected=$null },
    @{ Name='preview target missing flag'; Task='help'; Target='lib/main_preview.dart'; Define=$null; Expected='Preview requires both' },
    @{ Name='preview target false flag'; Task='help'; Target='lib/main_preview.dart'; Define=$Disabled; Expected='Preview requires both' },
    @{ Name='preview flag ordinary target'; Task='help'; Target='lib/main.dart'; Define=$Enabled; Expected='Preview requires both' },
    @{ Name='QA missing flag'; Task='help'; Target='integration_test/feed_preview_device_test.dart'; Define=$null; Expected='Preview requires both' },
    @{ Name='unsupported target'; Task='help'; Target='integration_test/musician_feed_device_test.dart'; Define=$Enabled; Expected='Preview requires both' },
    @{ Name='invalid flag'; Task='help'; Target='lib/main_preview.dart'; Define=$Invalid; Expected='accepts only true or false' },
    @{ Name='duplicate flags'; Task='help'; Target='lib/main_preview.dart'; Define="$Enabled,$Enabled"; Expected='specified exactly once' },
    @{ Name='preview release'; Task=':app:assembleRelease'; Target='lib/main_preview.dart'; Define=$Enabled; Expected='preview release builds are forbidden' },
    @{ Name='QA profile'; Task=':app:assembleProfile'; Target='integration_test/feed_preview_device_test.dart'; Define=$Enabled; Expected='QA target is debug-only' }
)
Push-Location $AndroidRoot
try {
    foreach ($Case in $Cases) {
        $Arguments = @('--offline', '--no-daemon', '--console=plain', $Case.Task, "-Ptarget=$($Case.Target)")
        if ($null -ne $Case.Define) { $Arguments += "-Pdart-defines=$($Case.Define)" }
        $CaseLog = Join-Path $PolicyLogDirectory (($Case.Name -replace '[^A-Za-z0-9_-]', '-') + '.log')
        & $Gradle @Arguments *> $CaseLog
        $Code = $LASTEXITCODE
        $Output = Get-Content -LiteralPath $CaseLog -Raw
        if ($null -eq $Case.Expected) {
            if ($Code -ne 0) { throw "Policy check '$($Case.Name)' failed to configure (exit $Code; log $CaseLog): $Output" }
        } elseif ($Code -eq 0 -or -not $Output.Contains($Case.Expected)) {
            throw "Policy check '$($Case.Name)' did not fail for the expected reason (exit $Code; log $CaseLog): $Output"
        }
        Write-Output "PASS: $($Case.Name)"
    }
} finally {
    Pop-Location
}

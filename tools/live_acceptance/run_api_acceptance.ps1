[CmdletBinding()]
param(
    [string]$PythonCommand = 'python',
    [string]$BaseUrl = 'http://127.0.0.1:8080',
    [string]$OutputDirectory = '',
    [string]$VenueId = '',
    [ValidateRange(1, 20)]
    [int]$ConcurrencyRepetitions = 1
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# This wrapper runs HTTP checks only. Emulator UI must not be changing the same
# accounts while profile values are temporarily edited and restored.
$origin = $null
if (-not [Uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$origin) -or
    $origin.Scheme -ne 'http' -or
    $origin.Host -notin @('localhost', '127.0.0.1', '[::1]', '::1') -or
    $origin.UserInfo -or $origin.Query -or $origin.Fragment -or
    $origin.AbsolutePath -ne '/') {
    throw 'BaseUrl must be a loopback HTTP origin without credentials, path, query, or fragment.'
}
$BaseUrl = $BaseUrl.TrimEnd('/')
Get-Command -Name $PythonCommand -ErrorAction Stop | Out-Null

foreach ($role in @('MUSICIAN', 'LISTENER', 'VENUE')) {
    $username = [Environment]::GetEnvironmentVariable('SC_TEST_' + $role + '_USERNAME')
    $rolePassword = [Environment]::GetEnvironmentVariable('SC_TEST_' + $role + '_PASSWORD')
    $sharedPassword = [Environment]::GetEnvironmentVariable('SC_TEST_PASSWORD')
    if ([string]::IsNullOrWhiteSpace($username) -or
        ([string]::IsNullOrEmpty($rolePassword) -and [string]::IsNullOrEmpty($sharedPassword))) {
        throw ('Missing credential environment variables for ' + $role + '.')
    }
}
Remove-Variable username, rolePassword, sharedPassword

$profileScript = Join-Path $PSScriptRoot 'live_api_acceptance.py'
$bandScript = Join-Path $PSScriptRoot 'live_band_acceptance.py'
foreach ($scriptPath in @($profileScript, $bandScript)) {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw ('Missing acceptance runner: ' + [IO.Path]::GetFileName($scriptPath))
    }
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $PSScriptRoot '../../../.local-verification/live-acceptance'
}
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
$runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$runDirectory = Join-Path $outputRoot $runId
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null

$common = @('--base-url', $BaseUrl)
$venueArgs = @()
if (-not [string]::IsNullOrWhiteSpace($VenueId)) {
    $venueArgs = @('--venue-id', $VenueId)
}
$stages = @(
    @{
        Name = 'profiles'; Script = $profileScript
        Arguments = $common + @('--accounts', 'musician', 'listener', 'venue', '--mutate-profiles',
            '--concurrency-repetitions', [string]$ConcurrencyRepetitions) + $venueArgs
        Pattern = '*-results.json'
    },
    @{
        Name = 'event'; Script = $profileScript
        # Never pass --keep-event: the fixture, likes and comments are cleaned
        # by the runner's finally block, including when a check fails.
        Arguments = $common + @('--accounts', 'venue', 'listener', '--disposable-event') + $venueArgs
        Pattern = '*-results.json'
    },
    @{
        Name = 'band'; Script = $bandScript
        Arguments = $common
        Pattern = '*-band-results.json'
    }
)

$suite = [ordered]@{
    run_id = $runId
    started_at = [DateTime]::UtcNow.ToString('o')
    base_url = $BaseUrl
    evidence_kind = 'Real HTTP against running local backend; no device UI or mocked responses'
    status = 'RUNNING'
    stages = @()
    limitations = @(
        'API contracts only: does not close all manual acceptance scenarios.',
        'No Flutter rendering, dialog, keyboard, navigation or physical audio proof.',
        'Sequential stages may repeat prerequisite checks; totals count assertions, not unique user scenarios.'
    )
}
$summaryPath = Join-Path $runDirectory 'suite-results.json'
function Save-SuiteReport {
    $suite | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
}
Save-SuiteReport

foreach ($stage in $stages) {
    $stageDirectory = Join-Path $runDirectory $stage.Name
    New-Item -ItemType Directory -Path $stageDirectory -Force | Out-Null
    $entry = [ordered]@{
        name = $stage.Name; status = 'FAIL'; exit_code = $null
        pass = 0; fail = 0; skip = 0; report = $null
    }
    try {
        $stageArguments = @($stage.Script) + $stage.Arguments + @('--output-dir', $stageDirectory)
        Write-Host ('Running live API stage: ' + $stage.Name)
        & $PythonCommand @stageArguments 2>&1 | Tee-Object -FilePath (Join-Path $stageDirectory 'runner.log') | Out-Host
        $entry.exit_code = $LASTEXITCODE
        $reports = @(Get-ChildItem -LiteralPath $stageDirectory -Filter $stage.Pattern -File)
        if ($reports.Count -ne 1) {
            throw 'Stage did not produce exactly one result report.'
        }
        $entry.report = $stage.Name + '/' + $reports[0].Name
        $report = Get-Content -LiteralPath $reports[0].FullName -Raw | ConvertFrom-Json
        $properties = @($report.PSObject.Properties.Name)
        if ($properties -notcontains 'finished_at' -or $properties -notcontains 'checks' -or
            [string]::IsNullOrWhiteSpace([string]$report.finished_at) -or @($report.checks).Count -eq 0) {
            throw 'Stage report is incomplete.'
        }
        $entry.pass = @($report.checks | Where-Object { $_.status -eq 'PASS' }).Count
        $entry.fail = @($report.checks | Where-Object { $_.status -eq 'FAIL' }).Count
        $entry.skip = @($report.checks | Where-Object { $_.status -eq 'SKIP' }).Count
        $unknownStatus = @($report.checks | Where-Object { $_.status -notin @('PASS', 'FAIL', 'SKIP') }).Count
        $cleanupFailed = $false
        if ($properties -contains 'cleanup') {
            $cleanupFailed = $report.cleanup.status -notin @('PASS', 'NOT_NEEDED')
        }
        if ($properties -contains 'restoration') {
            $cleanupFailed = $cleanupFailed -or @($report.restoration | Where-Object { $_.status -ne 'PASS' }).Count -gt 0
        }
        if ($stage.Name -eq 'event') {
            $cleanupChecks = @($report.checks | Where-Object { $_.name -eq 'event.cleanup_disposable_fixture' -and $_.status -eq 'PASS' })
            $cleanupFailed = $cleanupFailed -or $cleanupChecks.Count -ne 1
        }
        if ($entry.exit_code -eq 0 -and $entry.fail -eq 0 -and $unknownStatus -eq 0 -and -not $cleanupFailed) {
            $entry.status = if ($entry.skip -eq 0) { 'PASS' } else { 'INCOMPLETE' }
        }
        $entry.cleanup_verified = -not $cleanupFailed
    }
    catch {
        # Error classes and our own diagnostic text cannot contain credentials.
        $entry.error_type = $_.Exception.GetType().Name
        Write-Host ('Stage could not complete: ' + $stage.Name + '; see its result/log files.')
    }
    $suite.stages += $entry
    Save-SuiteReport
    Write-Host ($stage.Name + ': ' + $entry.status + ' (pass=' + $entry.pass + ', fail=' + $entry.fail + ', skip=' + $entry.skip + ')')
}

$suite.status = if (@($suite.stages | Where-Object { $_.status -ne 'PASS' }).Count -eq 0) { 'PASS' } else { 'FAIL_OR_INCOMPLETE' }
$suite.finished_at = [DateTime]::UtcNow.ToString('o')
$suite.total_pass = 0
$suite.total_fail = 0
$suite.total_skip = 0
foreach ($completedStage in $suite.stages) {
    # Entries are OrderedDictionary values, not PSObjects with properties for
    # Measure-Object. Index the recorded counters explicitly on PowerShell 5/7.
    $suite.total_pass += [int]$completedStage['pass']
    $suite.total_fail += [int]$completedStage['fail']
    $suite.total_skip += [int]$completedStage['skip']
}
Save-SuiteReport
Write-Host ('Suite: ' + $suite.status + ' | Report: ' + $summaryPath)
if ($suite.status -ne 'PASS') { exit 1 }
exit 0

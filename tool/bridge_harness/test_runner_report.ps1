#requires -Version 7.0
param([Parameter(Mandatory)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'runner_report.ps1')
if(Test-Path $EvidenceDirectory){throw 'Fresh parser evidence required'}
New-Item -ItemType Directory $EvidenceDirectory|Out-Null
$classes=@('NativePushBridgeLifecycleTest','OverthinkingNotificationInstrumentationTest','NativeBridgeFixtureTest')
$expected=@($classes|ForEach-Object {'com.berkayb.soundconnect.soundconnect_23_12_25codx.'+$_+'#test'+$_})
$lines=@()
foreach($id in $expected){
 $parts=$id.Split('#')
 $fields="INSTRUMENTATION_STATUS: class=$($parts[0])`nINSTRUMENTATION_STATUS: test=$($parts[1])`nINSTRUMENTATION_STATUS: numtests=3`n"
 $lines+=$fields+'INSTRUMENTATION_STATUS_CODE: 1'
 if($parts[0] -notlike '*.NativeBridgeFixtureTest'){$lines+="INSTRUMENTATION_STATUS: bridgeCleanup=emulator:$($parts[1]):empty`nINSTRUMENTATION_STATUS_CODE: 2"}
 $lines+=$fields+'INSTRUMENTATION_STATUS_CODE: 0'
}
$success=($lines+@('OK (3 tests)','INSTRUMENTATION_CODE: -1')) -join "`n"
$mutations=[ordered]@{
 valid=$success
 empty=''
 zero="OK (0 tests)`nINSTRUMENTATION_CODE: -1"
 skip=$success.Replace('INSTRUMENTATION_STATUS_CODE: 0','INSTRUMENTATION_STATUS_CODE: -3')
 crash=$success+"`nINSTRUMENTATION_RESULT: shortMsg=Process crashed"
 missingFinal=$success.Replace('OK (3 tests)','')
 missingStart=$success.Replace('INSTRUMENTATION_STATUS_CODE: 1','INSTRUMENTATION_STATUS_CODE: 0')
 duplicate=$success+"`n"+$lines[0]
 missingNewCleanup=$success.Replace('bridgeCleanup=emulator:testOverthinkingNotificationInstrumentationTest:empty','bridgeCleanup=wrong')
 missingOldCleanup=$success.Replace('bridgeCleanup=emulator:testNativePushBridgeLifecycleTest:empty','bridgeCleanup=wrong')
 wrongCount=$success.Replace('numtests=3','numtests=2')
 partial=$success+"`nINSTRUMENTATION_STATUS: class=incomplete"
 extraFinal=$success+"`nINSTRUMENTATION_CODE: -1"
}
$results=@(foreach($name in $mutations.Keys){
 $text=$mutations[$name];$text|Set-Content "$EvidenceDirectory/$name.log"
 $report=Read-BridgeRunner $text $expected 'emulator'
 $ok=($report.valid -eq ($name -ceq 'valid'))
 @{name=$name;passed=$ok;observed=$report}
})
foreach($case in @(@{name='duplicate-inventory';tests=@($expected[0],$expected[0])},@{name='empty-inventory';tests=@()})){
 $report=Read-BridgeRunner $success $case.tests 'emulator'
 $results+=@{name=$case.name;passed=(-not $report.valid);observed=$report}
}
$results|ConvertTo-Json -Depth 8|Set-Content "$EvidenceDirectory/results.json"
if(@($results|Where-Object {-not $_.passed}).Count){throw 'Runner report gate regression failed'}
Write-Output "PASS $($results.Count) real runner-parser cases"

function Invoke-BridgeProcess([string]$File,[string[]]$Arguments,[int]$TimeoutSeconds) {
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$File; $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    foreach($argument in $Arguments){[void]$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$start
    try {
        [void]$process.Start()
        $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
        $timedOut=-not $process.WaitForExit($TimeoutSeconds*1000)
        if($timedOut){$process.Kill($true); $process.WaitForExit()}
        return @{exitCode=$process.ExitCode;timedOut=$timedOut;output=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()}
    } finally {$process.Dispose()}
}
function ConvertTo-BridgeShell([string[]]$Tokens) {
    # adb joins shell arguments; quote every remote token, including fingerprints.
    return (($Tokens|ForEach-Object { "'"+$_.Replace("`r`n", "`n").Replace("'", "'"+'"'+"'"+'"'+"'")+"'" }) -join ' ')
}

# Shared strict AndroidJUnitRunner parser for the physical and hosted test hosts.
function Read-BridgeRunner([string]$Text,[string[]]$Expected,[string]$Run) {
    $started=[Collections.Generic.List[string]]::new(); $passed=[Collections.Generic.List[string]]::new()
    $failed=[Collections.Generic.List[string]]::new(); $clean=[Collections.Generic.List[string]]::new()
    $errors=[Collections.Generic.List[string]]::new(); $fields=@{}
    if($Expected.Count -eq 0 -or @($Expected|Select-Object -Unique).Count -ne $Expected.Count){$errors.Add('Empty or duplicate expected inventory')}
    foreach($line in ($Text -split '\r?\n')) {
        if($line -cmatch '^INSTRUMENTATION_STATUS: ([A-Za-z]+)=(.*)$'){$fields[$Matches[1]]=$Matches[2]}
        elseif($line -cmatch '^INSTRUMENTATION_STATUS_CODE: (-?\d+)$') {
            $code=[int]$Matches[1]
            if($code -eq 2 -and $fields.ContainsKey('bridgeCleanup')) {$clean.Add($fields.bridgeCleanup)}
            else {
                $id="$($fields.class)#$($fields.test)"
                if($Expected -cnotcontains $id){$errors.Add("Unexpected test: $id")}
                if($fields.numtests -cne [string]$Expected.Count){$errors.Add('Missing or wrong runner test count')}
                if($code -eq 1){$started.Add($id)}
                elseif($code -eq 0){
                    if($started -cnotcontains $id){$errors.Add('Completion without start')}; $passed.Add($id)
                }else{$failed.Add($id);$errors.Add("Failure/skip status: $code")}
            }
            $fields=@{}
        }
    }
    if($fields.Count -ne 0){$errors.Add('Incomplete runner status block')}
    foreach($id in $Expected){
        if(@($started|Where-Object {$_ -ceq $id}).Count -ne 1 -or @($passed|Where-Object {$_ -ceq $id}).Count -ne 1){$errors.Add("Incomplete/duplicate test: $id")}
        if(($id.Contains('.NativePushBridgeLifecycleTest#') -or $id.Contains('.OverthinkingNotificationInstrumentationTest#'))){
            $mark=$Run+':'+$id.Split('#')[1]+':empty'
            if(@($clean|Where-Object {$_ -ceq $mark}).Count -ne 1){$errors.Add("Missing/duplicate durable cleanup: $id")}
        }
    }
    $cleanupCount=@($Expected|Where-Object {($_.Contains('.NativePushBridgeLifecycleTest#') -or $_.Contains('.OverthinkingNotificationInstrumentationTest#'))}).Count
    if($clean.Count -ne $cleanupCount){$errors.Add('Wrong number of Android cleanup records')}
    if($Text -cmatch 'Process crashed|INSTRUMENTATION_FAILED|FAILURES!!!|shortMsg=|INSTRUMENTATION_ABORTED' -or
       @([regex]::Matches($Text,'(?m)^INSTRUMENTATION_CODE: -?\d+\r?$')).Count -ne 1 -or
       @([regex]::Matches($Text,'(?m)^INSTRUMENTATION_CODE: -1\r?$')).Count -ne 1 -or
       @([regex]::Matches($Text,'(?m)^OK \('+ $Expected.Count +' tests\)\r?$')).Count -ne 1){$errors.Add('Missing successful final suite or runner crash')}
    return @{valid=($errors.Count -eq 0);expected=$Expected.Count;started=$started.Count;passed=$passed.Count;failed=$failed.Count;
        notStarted=@($Expected|Where-Object {$started -cnotcontains $_}).Count;errors=@($errors);cleanup=@($clean);passedTests=@($passed)}
}

#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Prepare','Run')][string]$Mode='Prepare',
    [string]$Delivery,
    [string]$EvidenceDirectory,
    [string]$Adb,
    [string]$Aapt,
    [string]$ApkSigner,
    [string]$UpgradeFromDelivery,
    [string]$Serial,
    [Nullable[int]]$AndroidUser,
    [string]$RunId,
    [string]$DeviceIdentity,
    [string]$AuthorizationRecord
)

# Isolated bridge only. Dot sourcing exposes the SAME orchestration to side-effect-free tests.
# No public mock/bypass argument. Human consent is checked by the operator; a JSON
# record binds that consent to one selection and is not consent by itself.
. (Join-Path $PSScriptRoot 'runner_report.ps1')
function Get-BridgeDeliveryClasses($Pair) {
    $legacy=@('com.berkayb.soundconnect.soundconnect_23_12_25codx.NativePushBridgeLifecycleTest',
        'com.berkayb.soundconnect.soundconnect_23_12_25codx.NativeBridgeFixtureTest')
    if($Pair.app.path -match '[\\/]tasks[\\/]BIL-007[\\/]evidence[\\/]01-developer-01[\\/]apks[\\/]') {
        return $legacy + 'com.berkayb.soundconnect.soundconnect_23_12_25codx.OverthinkingNotificationInstrumentationTest'
    }
    return $legacy
}
function Invoke-BridgeVivo([hashtable]$Config,[scriptblock]$Executor=${function:Invoke-BridgeProcess}) {
    $ErrorActionPreference='Stop'
    $package='tr.com.soundconnect.app.warmtest'; $testPackage="$package.test"
    $runner='androidx.test.runner.AndroidJUnitRunner'
    $classes=@('com.berkayb.soundconnect.soundconnect_23_12_25codx.NativePushBridgeLifecycleTest',
        'com.berkayb.soundconnect.soundconnect_23_12_25codx.NativeBridgeFixtureTest')
    if($Config.mode -cnotin @('Prepare','Run')){throw 'Unknown mode'}
    if(Test-Path -LiteralPath $Config.evidence){throw 'Use a new evidence directory'}
    [void](New-Item -ItemType Directory -Path $Config.evidence)
    $evidence=(Resolve-Path -LiteralPath $Config.evidence).Path
    $commands=[Collections.Generic.List[object]]::new()
    $result=@{status='REJECTED';deviceMutationsStarted=$false;mode=$Config.mode}
    function Command([string]$Name,[string]$File,[string[]]$Arguments,[int]$Timeout=30,[int[]]$Allowed=@(0)) {
        $out=& $Executor $File $Arguments $Timeout
        $log=Join-Path $evidence "$Name.log"
        $out.output|Set-Content -LiteralPath $log -Encoding utf8
        $commands.Add(@{cwd=(Get-Location).Path;command=$File;arguments=$Arguments;exitCode=$out.exitCode;timedOut=$out.timedOut;timeoutSeconds=$Timeout;log=$log})
        if($out.timedOut){throw "Timed out: $Name; runtime may remain, no retry/cleanup"}
        if($Allowed -notcontains $out.exitCode){throw "$Name failed: exit $($out.exitCode)"}
        return [string]$out.output
    }
    function Device([string]$Name,[string[]]$Arguments,[int]$Timeout=30,[int[]]$Allowed=@(0)) {
        Command $Name $Config.adb (@('-s',$Config.serial)+$Arguments) $Timeout $Allowed
    }
    function Shell([string]$Name,[string[]]$Tokens,[int]$Timeout=30,[int[]]$Allowed=@(0)) {
        Device $Name @('shell',(ConvertTo-BridgeShell $Tokens)) $Timeout $Allowed
    }
    function Exact([object]$Observed,[object]$Expected,[string]$Label) {
        if(-not [string]::Equals([string]$Observed,[string]$Expected,[StringComparison]::Ordinal)){throw "Mismatch: $Label"}
    }
    function Hashes {
        foreach($artifact in @($delivery.app,$delivery.test)){
            if($artifact.sha256 -cnotmatch '^[A-F0-9]{64}$'){throw 'Invalid pinned APK hash'}
            Exact (Get-FileHash -LiteralPath $artifact.path).Hash $artifact.sha256 'fixed APK hash'
        }
    }
    function FixedApk($artifact) {
        $path=(Resolve-Path -LiteralPath $artifact.path).Path
        if($path -match '[\\/]build[\\/]' -or $path -notmatch '[\\/]tasks[\\/](?:BIL-001[\\/]evidence[\\/]03-[^\\/]+|BIL-003[\\/]evidence[\\/]01-[^\\/]+|BIL-007[\\/]evidence[\\/]01-developer-01)[\\/]apks[\\/]'){
            throw 'Use fixed BIL-001 / 03, BIL-003 / 01 or BIL-007 / 01-developer-01 evidence APK copies'
        }
        Exact (Get-FileHash -LiteralPath $path).Hash $artifact.sha256 'fixed APK hash'
    }
    function Signer([string]$Phase,$artifact) {
        if([string]::IsNullOrWhiteSpace($Config.apksigner)){throw 'APK signer verifier required'}
        $output=Command "$Phase-signer" (Join-Path $env:JAVA_HOME 'bin/java.exe') @('-jar',$Config.apksigner,'verify','--print-certs',$artifact.path) 60
        $certs=[regex]::Matches($output,'(?m)^Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]{64})\r?$')
        if($certs.Count -ne 1){throw 'Exactly one verified APK signer required'}
        return $certs[0].Groups[1].Value.ToUpperInvariant()
    }
    function VerifyPair([string]$Phase,$pair) {
        foreach($artifact in @($pair.app,$pair.test)){FixedApk $artifact}
        Exact (Split-Path ([IO.Path]::GetFullPath($pair.app.path))) (Split-Path ([IO.Path]::GetFullPath($pair.test.path))) 'APK pair evidence root'
        $shell=(Get-Process -Id $PID).Path
        $directory=Join-Path $evidence "$Phase-apk-gate"
        [void](Command "$Phase-apk-verifier" $shell @('-NoProfile','-File',(Join-Path $PSScriptRoot 'verify_apks.ps1'),'-AppApk',$pair.app.path,'-TestApk',$pair.test.path,'-Aapt',$Config.aapt,'-EvidenceDirectory',$directory) 120)
        $gate=Get-Content -LiteralPath (Join-Path $directory 'apk-gate.json') -Raw|ConvertFrom-Json
        Exact $gate.status 'VERIFIED' 'actual verifier result'; Exact $gate.appSha256 $pair.app.sha256 'verified app hash'; Exact $gate.testSha256 $pair.test.sha256 'verified test hash'
        Exact $gate.runner $runner 'verified runner'; Exact $gate.targetPackage $package 'verified target'
        $signer=Signer "$Phase-app" $pair.app
        Exact (Signer "$Phase-test" $pair.test) $signer 'app/test signer certificate'
        return $signer
    }
    function PreviousProvenance($pair,[string]$Manifest) {
        $priorClasses=@(Get-BridgeDeliveryClasses $pair)
        $priorTests=@($pair.tests)
        if($priorTests.Count -eq 0 -or @($priorTests|Select-Object -Unique).Count -ne $priorTests.Count -or
            @($priorTests|Where-Object {$_ -isnot [string] -or $_ -cnotmatch '^[A-Za-z0-9_.]+#[A-Za-z0-9_]+$' -or $priorClasses -cnotcontains $_.Split('#')[0]}).Count -ne 0 -or
            @($priorClasses|Where-Object {$class=$_;@($priorTests|Where-Object {$_.StartsWith($class+'#',[StringComparison]::Ordinal)}).Count -eq 0}).Count -ne 0){
            throw 'Previous delivery inventory must be unique and belong to its own classes'
        }
        $root=Split-Path (Resolve-Path -LiteralPath $Manifest).Path
        function ReadEvidence([object]$Reference,[string]$Label) {
            if($Reference -isnot [string] -or [string]::IsNullOrWhiteSpace($Reference)){throw "Previous $Label unreadable"}
            $path=[IO.Path]::GetFullPath($(if([IO.Path]::IsPathRooted($Reference)){$Reference}else{Join-Path $root $Reference}))
            if(-not $path.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
                throw 'Previous provenance reference outside delivery root'
            }
            try {return Get-Content -LiteralPath $path -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop}
            catch {throw "Previous $Label unreadable"}
        }
        function Successful($record) {
            if($null -eq $record -or ($record.exitCode -isnot [int] -and $record.exitCode -isnot [long]) -or $record.exitCode -ne 0 -or
                ($null -ne $record.PSObject.Properties['timedOut'] -and ($record.timedOut -isnot [bool] -or $record.timedOut))){
                throw 'Previous successful build result required'
            }
        }
        $command=ReadEvidence $pair.buildCommand 'build command'
        if($null -ne $command.PSObject.Properties['timedOut'] -and ($command.timedOut -isnot [bool] -or $command.timedOut)){
            throw 'Previous successful build result required'
        }
        $explicit=@('buildExit','before','after'|Where-Object {$null -ne $pair.PSObject.Properties[$_]})
        if($explicit.Count -ne 0 -and $explicit.Count -ne 3){throw 'Incomplete previous provenance references'}
        if($explicit.Count -eq 3){
            Successful (ReadEvidence $pair.buildExit 'build result')
            if($null -ne $command.PSObject.Properties['exitCode']){Successful $command}
        }else{Successful $command}
        $args=@($command.arguments)
        foreach($required in @(':app:assembleDebug',':app:assembleDebugAndroidTest','-PsoundconnectBridgeHarness=true')){
            if(@($args|Where-Object {$_ -ceq $required}).Count -ne 1){throw 'Previous isolated build arguments required'}
        }
        if(@($args|Where-Object {$_ -isnot [string] -or ($_ -clike '-PsoundconnectBridgeHarness=*' -and $_ -cne '-PsoundconnectBridgeHarness=true') -or
            ($_ -clike '-Ptarget=*' -and $_ -cne '-Ptarget=integration_test/native_push_bridge_harness.dart')}).Count -ne 0){throw 'Previous isolated build arguments required'}
        if($pair.sources -isnot [array] -or $pair.sources.Count -lt 6){throw 'Missing previous source provenance'}
        $sourcePaths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach($source in $pair.sources){
            if($source.path -isnot [string] -or [string]::IsNullOrWhiteSpace($source.path) -or -not [IO.Path]::IsPathFullyQualified($source.path) -or
                $source.sha256 -isnot [string] -or $source.sha256 -cnotmatch '^[A-F0-9]{64}$'){
                throw 'Invalid previous source entry'
            }
            if(-not $sourcePaths.Add([IO.Path]::GetFullPath($source.path))){throw 'Duplicate previous source path'}
        }
        foreach($stage in @('before','after')){
            $reference=if($explicit.Count -eq 3){$pair.$stage}else{"build-sources-$stage.json"}
            $snapshot=ReadEvidence $reference 'source snapshot'
            $entries=if($explicit.Count -eq 3){$snapshot.inputs}else{$snapshot}
            $hashField=if($explicit.Count -eq 3){'sha256'}else{'hash'}
            if($entries -isnot [array] -or $entries.Count -eq 0){throw 'Invalid previous snapshot entries'}
            $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach($entry in $entries){
                if($entry.path -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.path) -or $entry.$hashField -isnot [string] -or
                    $entry.$hashField -cnotmatch '^[A-F0-9]{64}$' -or $entry.path.Replace('\','/') -match '(^|/)(\.|\.\.)(/|$)|//'){
                    throw 'Invalid previous snapshot entry'
                }
                if(-not $paths.Add($entry.path.Replace('\','/'))){throw 'Duplicate previous snapshot path'}
            }
            foreach($source in $pair.sources){
                # Find by path first: a duplicate with a different hash must never
                # disappear from the candidate set because its hash did not match.
                $matches=@($entries|Where-Object {
                    $path=$_.path.Replace('\','/');$full=[IO.Path]::GetFullPath($source.path).Replace('\','/')
                    $full -ceq $path -or $full.EndsWith('/'+$path,[StringComparison]::Ordinal)
                })
                if($matches.Count -ne 1 -or $matches[0].$hashField -cne $source.sha256){throw 'Previous source/build provenance mismatch'}
            }
        }
    }
    function Packages([string]$Phase,[switch]$IncludeUninstalled) {
        $tokens=@('pm','list','packages','--user','0','-U','--show-versioncode')
        # -U prints UID; -u ALSO includes uninstalled packages with retained data.
        # Neither this view nor a package-name prefix proves an installed target.
        if($IncludeUninstalled){$tokens+='-u'}
        $output=Shell "$Phase-packages" ($tokens+@('tr.com.soundconnect.app'))
        $found=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
        foreach($line in ($output.Trim() -split '\r?\n')) {
            if($line -ceq ''){continue}
            if($line -cnotmatch '^package:(tr\.com\.soundconnect\.app(?:\.[A-Za-z0-9_.]+)?) versionCode:(\d+) uid:(\d+)$'){throw 'Unreadable package inventory'}
            if($found.ContainsKey($Matches[1])){throw 'Duplicate package entry'}
            $found[$Matches[1]]=@{version=$Matches[2];uid=$Matches[3]}
        }
        return $found
    }
    function InstalledHash([string]$Phase,[string]$Pkg,[string]$ExpectedHash) {
        $path=(Shell "$Phase-$Pkg-path" @('pm','path','--user','0',$Pkg)).Trim()
        if($path -cnotmatch '^package:(/data/app/[A-Za-z0-9_+./=~-]+/base\.apk)$'){throw 'Expected exactly one installed base APK; splits/unreadable package rejected'}
        $hash=(Shell "$Phase-$Pkg-hash" @('sha256sum',$Matches[1])).Trim()
        if($hash -cnotmatch '^([a-fA-F0-9]{64})\s+'){throw 'Unreadable installed APK hash'}
        Exact $Matches[1].ToUpperInvariant() $ExpectedHash 'installed APK bytes (includes signer/manifest)'
    }
    function IsolatedUids($inventory) {
        if(-not $inventory.ContainsKey($package) -or -not $inventory.ContainsKey($testPackage)){throw 'Both installed test packages required'}
        $uids=@($inventory[$package].uid,$inventory[$testPackage].uid)
        if($uids[0] -eq $uids[1]){throw 'App/test shared UID forbidden'}
        foreach($protected in @('tr.com.soundconnect.app','tr.com.soundconnect.app.preview')){
            if($inventory.ContainsKey($protected) -and $uids -contains $inventory[$protected].uid){throw 'Product/preview shared UID forbidden'}
        }
    }
    function EmptyState([string]$Phase) {
        # Only fixed test filenames. Missing directory is OK only after a readable
        # run-as working directory; permission errors are never treated as empty.
        $storage=@'
test -r . && test -x . || exit 61
if [ -e no_backup ]; then
 test -d no_backup && test -r no_backup && test -x no_backup || exit 62
fi
for n in soundconnect-push-rendering soundconnect-push-reset; do
 for s in .bak .new; do
  if [ -e "no_backup/$n$s" ]; then echo ATOMIC_RESIDUE; exit 63; fi
 done
 if [ -e "no_backup/$n" ]; then
  test -f "no_backup/$n" && test -r "no_backup/$n" || exit 64
  echo "$n"; cat "no_backup/$n" || exit 65; echo
 else echo "$n"; echo ABSENT; fi
done
'@
        $state=Shell "$Phase-state" @('run-as',$package,'sh','-c',$storage)
        $match=[regex]::Match($state,'\Asoundconnect-push-rendering\r?\n([^\r\n]+)\r?\nsoundconnect-push-reset\r?\n([^\r\n]+)\r?\n?\z')
        if(-not $match.Success){throw 'Unreadable durable state'}
        if($match.Groups[1].Value -cne 'ABSENT'){
            $binding=$match.Groups[1].Value|ConvertFrom-Json
            $parsed=[Guid]::Empty
            if(-not [Guid]::TryParseExact($binding.epoch,'D',[ref]$parsed) -or $binding.recipientId -cne ''){throw 'Nonempty/invalid recipient retained'}
        }
        if($match.Groups[2].Value -cne 'ABSENT'){
            $reset=$match.Groups[2].Value|ConvertFrom-Json
            if($reset.required -isnot [bool] -or $reset.required){throw 'Reset latch not clear'}
        }
    }
    function Quiescent([string]$Phase) {
        $pidText=Shell "$Phase-process" @('pidof',$package) 30 @(0,1)
        if(-not [string]::IsNullOrWhiteSpace($pidText)){throw 'Preexisting harness process retained'}
        # Filter on device before logging: no other app notification or Activity
        # content is returned. Require recognizable service headers, fail closed.
        $cards=@'
dumpsys notification | awk 'BEGIN {h=0;n=0} /Notification List:/ {h=1} /NotificationRecord\(/ && /pkg=tr\.com\.soundconnect\.app\.warmtest / {n++} END {if(!h) exit 71; print n}'
'@
        Exact (Shell "$Phase-cards" @('sh','-c',$cards)).Trim() '0' 'preexisting harness cards'
        $activities=@'
dumpsys activity activities | awk 'BEGIN {h=0;n=0} /ACTIVITY MANAGER ACTIVITIES/ {h=1} /ActivityRecord\{/ && /tr\.com\.soundconnect\.app\.warmtest\// {n++} END {if(!h) exit 72; print n}'
'@
        Exact (Shell "$Phase-activities" @('sh','-c',$activities)).Trim() '0' 'preexisting harness Activity'
        EmptyState $Phase
    }
    try {
        $delivery=Get-Content -LiteralPath $Config.delivery -Raw|ConvertFrom-Json
        $classes=@(Get-BridgeDeliveryClasses $delivery)
        Exact $delivery.package $package 'delivery package'; Exact $delivery.testPackage $testPackage 'delivery test package'
        Exact $delivery.runner $runner 'delivery runner'; Exact ($delivery.classes -join ',') ($classes -join ',') 'explicit classes'
        foreach($source in $delivery.sources){Exact (Get-FileHash -LiteralPath $source.path).Hash $source.sha256 'source/build provenance'}
        if($delivery.sources.Count -lt 6){throw 'Missing source/build provenance'}
        $inventory=@(foreach($class in $classes){
            $fileName=$class.Split('.')[-1]+'.kt'
            $source=@($delivery.sources|Where-Object {[IO.Path]::GetFileName($_.path) -ceq $fileName})
            if($source.Count -ne 1){throw 'Missing exact test source provenance'}
            $text=Get-Content -LiteralPath $source[0].path -Raw
            if($text -match '@Ignore'){throw 'Ignored bridge tests forbidden'}
            $methods=[regex]::Matches($text,'(?m)^ {4}@Test[ \t]+fun\s+(\w+)\s*\(')
            if($methods.Count -eq 0){throw 'Empty native class inventory'}
            foreach($method in $methods){$class+'#'+$method.Groups[1].Value}
        })
        if($delivery.tests.Count -ne $inventory.Count -or @($delivery.tests|Select-Object -Unique).Count -ne $inventory.Count -or
            @($inventory|Where-Object {$delivery.tests -cnotcontains $_}).Count -ne 0){throw 'Expected exact source-derived test suite inventory'}
        Hashes
        $newSigner=VerifyPair 'current' $delivery
        $result.signerSha256=$newSigner
        $previous=$null
        if($Config.upgradeFrom){
            $previous=Get-Content -LiteralPath $Config.upgradeFrom -Raw|ConvertFrom-Json
            Exact $previous.package $package 'previous package'; Exact $previous.testPackage $testPackage 'previous test package'
            Exact $previous.runner $runner 'previous runner'; Exact ($previous.classes -join ',') ((Get-BridgeDeliveryClasses $previous) -join ',') 'previous classes'
            PreviousProvenance $previous $Config.upgradeFrom
            Exact (VerifyPair 'previous' $previous) $newSigner 'old/new signer certificate'
            $result.upgradeFromSha256=(Get-FileHash -LiteralPath $Config.upgradeFrom).Hash
        }
        if($Config.mode -ceq 'Prepare'){$result.status='PREPARED_NO_DEVICE_ACTION';return $result}
        if($Config.serial -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$' -or $Config.serial.StartsWith('emulator-', [StringComparison]::OrdinalIgnoreCase)){throw 'Explicit physical serial required; no fallback'}
        # This narrow tool intentionally supports only explicitly selected current
        # owner user 0. Work profiles/secondary users need controller review.
        if($null -eq $Config.user -or $Config.user -ne 0){throw 'Explicit current Android owner user 0 required'}
        if($Config.runId -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$'){throw 'Nonempty run identity required'}
        $identity=Get-Content -LiteralPath $Config.identity -Raw|ConvertFrom-Json
        $approval=Get-Content -LiteralPath $Config.authorization -Raw|ConvertFrom-Json
        if($approval.approved -isnot [bool] -or -not $approval.approved -or $approval.readyNow -isnot [bool] -or -not $approval.readyNow -or
            [string]::IsNullOrWhiteSpace($approval.userMessage) -or [string]::IsNullOrWhiteSpace($approval.source) -or
            [string]::IsNullOrWhiteSpace($approval.recordedAt)){throw 'Recorded human install/run consent and current readiness required'}
        foreach($key in @('serial','runId')){Exact $approval.$key $Config.$key "approval $key"}
        Exact $approval.androidUser $Config.user 'approval user'; Exact $approval.appSha256 $delivery.app.sha256 'approval app'; Exact $approval.testSha256 $delivery.test.sha256 'approval test'
        if($previous){
            if($approval.dataPreservingUpgrade -isnot [bool] -or -not $approval.dataPreservingUpgrade){throw 'Explicit data-preserving upgrade selection required'}
            Exact $approval.previousDeliverySha256 $result.upgradeFromSha256 'approved previous delivery'
        }
        foreach($key in @('manufacturer','model','fingerprint','android','abi')){
            if([string]::IsNullOrWhiteSpace($identity.$key) -or $identity.$key -ceq 'unknown'){throw "Unreadable expected identity: $key"}
            Exact $approval.$key $identity.$key "approval $key"
        }
        if($identity.manufacturer -ine 'vivo'){throw 'Only selected Vivo supported'}
        Exact (Device 'serial' @('get-serialno')).Trim() $Config.serial 'connected exact serial'
        Exact (Device 'state' @('get-state')).Trim() 'device' 'online device'
        Exact (Shell 'current-user' @('am','get-current-user')).Trim() '0' 'selected current user'
        foreach($pair in @(@('manufacturer','ro.product.manufacturer'),@('model','ro.product.model'),@('fingerprint','ro.build.fingerprint'),@('android','ro.build.version.release'),@('abi','ro.product.cpu.abi'))){
            Exact (Shell $pair[0] @('getprop',$pair[1])).Trim() $identity.($pair[0]) $pair[0]
        }
        $qemu=(Shell 'qemu' @('getprop','ro.kernel.qemu')).Trim()
        # On physical builds this optional property may be absent. Physical identity
        # is established by all five exact Build/getprop fields above, not absence.
        if($qemu -cnotin @('','0')){throw 'Emulator qemu property rejected'}
        $hardware=(Shell 'hardware' @('getprop','ro.hardware')).Trim()
        if([string]::IsNullOrWhiteSpace($hardware) -or $hardware -cin @('ranchu','goldfish') -or $identity.model.Contains('sdk_gphone') -or $identity.fingerprint.Contains('generic')){throw 'Emulator/unreadable hardware rejected'}
        $abis=[regex]::Matches((Get-Content -LiteralPath (Join-Path $evidence 'current-apk-gate/app-assets.log') -Raw),'(?m)^lib/([^/]+)/libflutter\.so\r?$')|ForEach-Object {$_.Groups[1].Value}
        if($abis -cnotcontains $identity.abi){throw 'APK does not contain selected device ABI'}
        $before=Packages 'before'; $result.packagesBefore=$before
        $includingUninstalled=Packages 'before-including-uninstalled' -IncludeUninstalled
        $result.packagesBeforeIncludingUninstalled=$includingUninstalled
        foreach($pkg in @($package,$testPackage)){
            $visible=$before.ContainsKey($pkg); $known=$includingUninstalled.ContainsKey($pkg)
            if($known -and -not $visible){throw "Retained/uninstalled test package: $pkg; no install or reactivation"}
            if($visible -and -not $known){throw "Inconsistent package views: $pkg missing with -u; no mutation"}
            if($visible){
                Exact $includingUninstalled[$pkg].uid $before[$pkg].uid "package views UID: $pkg"
                Exact $includingUninstalled[$pkg].version $before[$pkg].version "package views version: $pkg"
            }
        }
        $existing=$before.ContainsKey($package); $existingTest=$before.ContainsKey($testPackage)
        if($existing -ne $existingTest){throw 'Partial preexisting installation retained; no overwrite'}
        if($previous -and -not $existing){throw 'Upgrade requires the complete known installed pair'}
        if($existing){
            IsolatedUids $before
            $expected=if($previous){$previous}else{$delivery}
            InstalledHash 'before' $package $expected.app.sha256; InstalledHash 'before' $testPackage $expected.test.sha256
            Quiescent 'before'
        }
        Hashes
        if(-not $existing -or $previous){
            $result.deviceMutationsStarted=$true
            $result.completedInstalls=@()
            foreach($artifact in @($delivery.app,$delivery.test)){
                Hashes
                $installArgs=@('install','--user','0')
                if($previous){$installArgs+='-r'}
                $install=Device ('install-'+[IO.Path]::GetFileNameWithoutExtension($artifact.path)) ($installArgs+@('-t',$artifact.path)) 180
                if($install.Trim() -cnotmatch '(?m)^Success$' -or $install -match 'Failure|Error'){throw 'Install did not report success; no repair/uninstall'}
                $result.completedInstalls+=@{path=$artifact.path;sha256=$artifact.sha256}
                # Two installs are not atomic. A failure leaves evidence and stops;
                # a mixed old/new pair is rejected on every subsequent invocation.
            }
        }
        $installed=Packages 'installed'; IsolatedUids $installed
        if($existing){foreach($pkg in @($package,$testPackage)){Exact $installed[$pkg].uid $before[$pkg].uid 'updated test UID'}}
        foreach($protected in @('tr.com.soundconnect.app','tr.com.soundconnect.app.preview')){
            Exact ($installed[$protected]|ConvertTo-Json -Compress) ($before[$protected]|ConvertTo-Json -Compress) 'protected identity before test'
        }
        InstalledHash 'installed' $package $delivery.app.sha256; InstalledHash 'installed' $testPackage $delivery.test.sha256
        $instrument=(Shell 'runner' @('pm','list','instrumentation')).Trim() -split '\r?\n'
        $target=@($instrument|Where-Object {$_ -clike "instrumentation:$testPackage/*"})
        if($target.Count -ne 1){throw 'Single installed runner required'}
        Exact $target[0] "instrumentation:$testPackage/$runner (target=$package)" 'installed runner/target'
        Quiescent 'installed'
        Exact (Shell 'user-before-test' @('am','get-current-user')).Trim() '0' 'current user before test'
        $arguments=@('am','instrument','--user','0','-w','-r','-e','class',($classes -join ','),'-e','bridgeMode','isolated-vivo',
            '-e','bridgeRunId',$Config.runId,'-e','bridgeManufacturer',$identity.manufacturer,'-e','bridgeModel',$identity.model,
            '-e','bridgeFingerprint',$identity.fingerprint,"$testPackage/$runner")
        $result.deviceMutationsStarted=$true
        $text=Shell 'instrumentation' $arguments 900
        $native=Read-BridgeRunner $text $delivery.tests $Config.runId
        $native|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'native-result.json') -Encoding utf8
        if(-not $native.valid){throw 'Native suite incomplete/crashed/failed; no repeat or cleanup'}
        EmptyState 'after'
        $after=Packages 'after'; $result.packagesAfter=$after
        IsolatedUids $after
        foreach($protected in @('tr.com.soundconnect.app','tr.com.soundconnect.app.preview')){
            Exact ($after[$protected]|ConvertTo-Json -Compress) ($before[$protected]|ConvertTo-Json -Compress) 'protected identity after test'
        }
        $result.status='PASSED_ISOLATED_NATIVE_ONLY'
        return $result
    } catch {
        $result.error=$_.Exception.Message
        # Never clear/reinstall/retry. Preserve runner and only test-package state;
        # diagnostic failures cannot hide the original error.
        if($result.deviceMutationsStarted){
            $runnerLog=Join-Path $evidence 'instrumentation.log'
            if(Test-Path -LiteralPath $runnerLog){
                try {
                    Read-BridgeRunner (Get-Content -LiteralPath $runnerLog -Raw) $delivery.tests $Config.runId|
                        ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'native-result.json') -Encoding utf8
                } catch {$result.runnerDiagnosticError=$_.Exception.Message}
            }
            # Capture only a warmtest AndroidRuntime crash block, filtered on the
            # device before logging. No log clear or unrelated application dump.
            $crash=@'
logcat -d -t 1000 -v brief AndroidRuntime:E '*:S' | awk 'BEGIN {p=0;n=0} /Process: tr\.com\.soundconnect\.app\.warmtest, PID: / {split($0,a,"PID: ");p=a[2]+0} {if(p>0 && $0 ~ ("\\([ ]*" p "\\):")){print;n++}} END {if(n==0) print "NO_MATCHING_WARMTEST_CRASH_IN_BOUNDED_LOG"}'
'@
            try {[void](Shell 'failure-logcat' @('sh','-c',$crash))} catch {$result.logcatDiagnosticError=$_.Exception.Message}
            try {EmptyState 'failure'} catch {$result.durableDiagnosticError=$_.Exception.Message}
            try {$result.packagesAfterFailure=Packages 'failure'} catch {$result.packageDiagnosticError=$_.Exception.Message}
        }
        throw
    } finally {
        $commands|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'commands.json') -Encoding utf8
        $result|ConvertTo-Json -Depth 9|Set-Content -LiteralPath (Join-Path $evidence 'result.json') -Encoding utf8
    }
}
if($MyInvocation.InvocationName -ne '.') {
    Invoke-BridgeVivo @{mode=$Mode;delivery=$Delivery;evidence=$EvidenceDirectory;adb=$Adb;aapt=$Aapt;apksigner=$ApkSigner;upgradeFrom=$UpgradeFromDelivery;serial=$Serial;
        user=$AndroidUser;runId=$RunId;identity=$DeviceIdentity;authorization=$AuthorizationRecord}|ConvertTo-Json -Depth 9
}

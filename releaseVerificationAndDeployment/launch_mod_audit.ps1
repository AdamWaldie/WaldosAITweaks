param(
    [string]$ArmaPath='',
    [string]$Package='',
    [string]$Focus='all',
    [ValidateSet('VR','Altis')][string]$World='VR',
    [ValidateSet('normal','headless')][string]$BatchMode='normal',
    [string]$HeadlessProvider='',
    [string[]]$Mods=@(),
    [ValidateSet("turret_aiming")][string[]]$EnginePolicies=@(),
    [string]$Python='python',
    [int]$Port=24142,
    [int]$ResolutionWidth=3840,
    [int]$ResolutionHeight=2160,
    [ValidateRange(30,600)][int]$ClientReadyTimeoutSeconds=180,
    [ValidateRange(10,120)][int]$ClientWindowTimeoutSeconds=60,
    [ValidateRange(0,2)][int]$HeadlessClients=0,
    [switch]$WithZen,
    [switch]$NativeBaseline,
    [ValidateSet("infantry","mixed")][string]$PerformanceComposition="infantry",
    [switch]$ServerOnly,
    [switch]$WaitForCompletion,
    [ValidateRange(60,21600)][int]$BatchTimeoutSeconds=14400,
    [switch]$StageOnly
)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
if (!$Package) { $Package=Join-Path $repo '.hemttout/build' }
if ($BatchMode -eq 'normal' -and $HeadlessClients -ne 0) {throw 'Normal batches require zero HCs; use BatchMode headless for migration tests'}
if ($BatchMode -eq 'headless' -and $HeadlessClients -ne 2) {throw 'Headless batches require two HCs for split-owner acceptance'}
if ($Focus -in @('performancecontact','performancemixed') -and $BatchMode -ne 'headless') {throw 'Multi-owner performance requires a dedicated headless batch; use standaloneperformance for normal comparisons'}
if ($Focus -eq 'indooractorshc' -and ($BatchMode -ne 'headless' -or $HeadlessClients -ne 2 -or !$HeadlessProvider)) {throw 'Individual indoor HC fixtures require BatchMode headless, HeadlessClients 2 and a real HeadlessProvider'}
if ($Focus -in @('indooractors','indoornatural') -and ($BatchMode -ne 'normal' -or $HeadlessClients -ne 0)) {throw 'Individual indoor normal fixtures require BatchMode normal and HeadlessClients 0'}
if ($ServerOnly -and $Focus -ne 'dangerload') {throw 'ServerOnly is restricted to the dangerload loader diagnostic.'}
if (!$ArmaPath) {
    $ArmaPath=(Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\bohemia interactive\arma 3').main
}
if (!$StageOnly -and (Get-Process arma3*,arma3server* -ErrorAction SilentlyContinue)) {
    throw 'An Arma process is already running. Finish that session before launching this batch.'
}
if ($NativeBaseline -and $EnginePolicies.Count) {throw 'NativeBaseline cannot load WAIT engine policies'}
if ($NativeBaseline -and $Focus -notin @('standaloneperformance','nativebuildings')) {throw 'NativeBaseline requires an addon-independent focus'}
if ($Focus -eq 'standaloneperformance' -and $HeadlessClients -ne 0) {throw 'Standalone server-owned performance requires HeadlessClients 0; use the migration audit for headless cases'}
$stageDefaultDependencies=!$Mods.Count
if ($stageDefaultDependencies) {
    $Mods=@(Join-Path $ArmaPath '!Workshop/@CBA_A3')
    if ($WithZen) {$Mods+=Join-Path $ArmaPath '!Workshop/@Zeus Enhanced'}
}
foreach ($mod in $Mods) {if (!(Test-Path -LiteralPath $mod)) {throw "Dependency folder missing: $mod"}}
$runtime=Join-Path $repo ('.qa/runtime-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$providerArguments=@()
if ($HeadlessProvider) {
    if ($HeadlessClients -lt 1) {throw 'Native headless integration requires a connected headless client'}
    $providerArguments=@('--headless-provider',(Resolve-Path -LiteralPath $HeadlessProvider).Path)
}
if ($NativeBaseline) {
    & $Python (Join-Path $PSScriptRoot 'mod_pipeline.py') stage $Package $runtime --focus $Focus --world $World --batch-mode $BatchMode --native-baseline --performance-composition $PerformanceComposition @providerArguments
} else {
    & $Python (Join-Path $PSScriptRoot 'mod_pipeline.py') stage $Package $runtime --focus $Focus --world $World --batch-mode $BatchMode --performance-composition $PerformanceComposition @providerArguments
}
if ($LASTEXITCODE) {throw 'Audit staging failed'}
$launchMods=$Mods
if ($stageDefaultDependencies) {
    $launchMods=@()
    foreach ($mod in $Mods) {
        $stagedMod=Join-Path $runtime (Split-Path $mod -Leaf)
        Copy-Item -LiteralPath $mod -Destination $stagedMod -Recurse
        $workshopMetadata=Join-Path $stagedMod 'meta.cpp'
        if (Test-Path -LiteralPath $workshopMetadata) {Remove-Item -LiteralPath $workshopMetadata -Force}
        $launchMods+=$stagedMod
    }
}
# Optional engine configuration is selected from the same sealed package, never a source folder.
# These paths join the one shared mod argument used by server, client and every headless client.
$policyMods=@()
foreach ($policy in ($EnginePolicies | Select-Object -Unique)) {
    $policyMod=Join-Path $runtime ("@WaldosAITweaks/optionals/@waldo_ai_tweaks_"+$policy)
    if (!(Test-Path -LiteralPath (Join-Path $policyMod 'addons')) -or
        !(Get-ChildItem -LiteralPath (Join-Path $policyMod 'addons') -Filter '*.pbo')) {
        throw "Selected engine policy is missing from the sealed package: $policy"
    }
    $policyMods+=(Resolve-Path -LiteralPath $policyMod).Path
}
$launchMods+=$policyMods
$manifest=Get-Content -Raw (Join-Path $runtime 'audit-manifest.json') | ConvertFrom-Json
$manifest | Add-Member dependencySources ($Mods | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
$manifest | Add-Member dependencies ($launchMods | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
$manifest | Add-Member enginePolicies @($EnginePolicies | Select-Object -Unique)
$manifest | Add-Member resolution @($ResolutionWidth,$ResolutionHeight)
$manifest | Add-Member headlessClients $HeadlessClients
$manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $runtime 'audit-manifest.json')
if ($StageOnly) {Write-Output "Staged packaged audit: $runtime"; return}
# Staging can inspect a development package; physical acceptance needs committed identity.
if ($manifest.package.dirty -ne $false -or $manifest.package.commit -notmatch '^[0-9a-f]{40}$') {
    throw 'Audit launch requires a clean committed package. Commit validated source, rebuild its seal, and stage a fresh candidate before launching.'
}

$mission=Join-Path $runtime "WAIT_Audit.$World"
$installedMission=Join-Path $ArmaPath ('MPMissions/WAIT_Audit_'+(Split-Path $runtime -Leaf)+'.'+$World)
Copy-Item -LiteralPath $mission -Destination $installedMission -Recurse
$missionName=Split-Path $installedMission -Leaf
$missionName=[System.IO.Path]::GetFileNameWithoutExtension($missionName)
$config=Join-Path $runtime 'server.cfg'
@"
hostname="WAIT packaged audit";
password="";
passwordAdmin="";
maxPlayers=3;
BattlEye=0;
verifySignatures=0;
allowedFilePatching=0;
headlessClients[]={"127.0.0.1"};
localClient[]={"127.0.0.1"};
persistent=1;
class Missions {class Audit {template="$missionName.$World"; difficulty="Regular";};};
"@ | Set-Content $config
$modArg=if ($NativeBaseline) {'-mod='+($launchMods -join ';')} else {
    '-mod='+(@((Join-Path $runtime '@WaldosAITweaks'))+$launchMods -join ';')
}
function Start-AuditProcess([string]$exe,[string[]]$arguments,[switch]$Interactive) {
    $quoted=$arguments | ForEach-Object {'"'+$_+'"'}
    # Background server/HC helpers stay hidden. The observer is an interactive game client:
    # it must expose its lobby/window so mission entry and physical behaviour can be verified.
    $auditWindowStyle = if ($Interactive) {'Normal'} else {'Hidden'}
    Start-Process -FilePath (Join-Path $ArmaPath $exe) -ArgumentList $quoted -WorkingDirectory $ArmaPath -WindowStyle $auditWindowStyle -PassThru
}
if (-not ('WaitAuditWindow' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WaitAuditWindow {
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@
}
function Show-AuditClientWindow([System.Diagnostics.Process]$Process,[int]$TimeoutSeconds) {
    $windowDeadline=(Get-Date).AddSeconds($TimeoutSeconds)
    $windowHandle=[IntPtr]::Zero
    while ((Get-Date) -lt $windowDeadline -and !$Process.HasExited) {
        $Process.Refresh()
        $windowHandle=$Process.MainWindowHandle
        if ($windowHandle -ne [IntPtr]::Zero -and [WaitAuditWindow]::IsWindowVisible($windowHandle)) {break}
        Start-Sleep -Milliseconds 250
    }
    if ($windowHandle -eq [IntPtr]::Zero -or !$([WaitAuditWindow]::IsWindowVisible($windowHandle))) {
        throw "Arma audit client did not expose a visible window within $TimeoutSeconds seconds. The batch is not considered launched."
    }
    # SW_RESTORE also handles a client which Windows opened minimized behind another application.
    [WaitAuditWindow]::ShowWindowAsync($windowHandle,9) | Out-Null
    [WaitAuditWindow]::SetForegroundWindow($windowHandle) | Out-Null
    return $windowHandle
}
$serverProfile=Join-Path $runtime 'server'
$server=Start-AuditProcess 'arma3server_x64.exe' @('-noBattlEye','-autoInit','-netlog',"-port=$Port","-config=$config","-profiles=$serverProfile",$modArg)
$processes=@($server.Id)
$auditProcessHandles=@($server)
# Record the server immediately: even a failed readiness gate must be stoppable
# through the identity-checked audit shutdown path.
@{runtime=$runtime; mission=$installedMission; process_ids=$processes; fingerprint=$manifest.package.fingerprint} | ConvertTo-Json | Set-Content (Join-Path $runtime 'launch.json')
$deadline=(Get-Date).AddSeconds(120)
$ready=$false
$networkReady=$false
while ((Get-Date) -lt $deadline -and !$server.HasExited) {
    $logs=Get-ChildItem $serverProfile -Filter '*.rpt' -Recurse -ErrorAction SilentlyContinue
    foreach ($log in $logs) {
        if (Select-String -LiteralPath $log.FullName -SimpleMatch 'WAIT AUDIT SERVER READY' -Quiet) {$ready=$true}
        if (Select-String -LiteralPath $log.FullName -SimpleMatch 'Connected to Steam servers' -Quiet) {$networkReady=$true}
    }
    if ($ready -and ($ServerOnly -or $networkReady)) {break}
    Start-Sleep -Seconds 1
}
if (!$ready -or (!$ServerOnly -and !$networkReady)) {throw "Server did not reach mission and network readiness (mission=$ready network=$networkReady). Inspect $runtime; recorded processes have been left available for inspection."}
if ($ServerOnly) {
    @{runtime=$runtime; mission=$installedMission; process_ids=$processes; fingerprint=$manifest.package.fingerprint} | ConvertTo-Json | Set-Content (Join-Path $runtime 'launch.json')
    Write-Output "WAIT danger loader diagnostic entered WAIT_Audit.VR server-side. Runtime: $runtime"
    return
}
for ($i=1; $i -le $HeadlessClients; $i++) {
    $hc=Start-AuditProcess 'arma3server_x64.exe' @('-client','-noBattlEye','-netlog','-connect=127.0.0.1',"-port=$Port",("-profiles="+(Join-Path $runtime "hc$i")),"-name=WAIT_HC$i",$modArg)
    $processes+=$hc.Id
    $auditProcessHandles+=$hc
    # Preserve each successful partial launch if a later HC/client fails to start.
    @{runtime=$runtime; mission=$installedMission; process_ids=$processes; fingerprint=$manifest.package.fingerprint} | ConvertTo-Json | Set-Content (Join-Path $runtime 'launch.json')
}
$clientProfile=Join-Path $runtime 'client'
New-Item -ItemType Directory -Force $clientProfile | Out-Null
@"
winX=0;
winY=0;
winW=$ResolutionWidth;
winH=$ResolutionHeight;
resolutionW=$ResolutionWidth;
resolutionH=$ResolutionHeight;
Windowed=1;
"@ | Set-Content (Join-Path $clientProfile 'Arma3.cfg')
$clientConfig=Join-Path $clientProfile 'Arma3.cfg'
$client=Start-AuditProcess 'arma3_x64.exe' @('-noBattlEye','-netlog','-window','-noPause','-skipIntro','-noSplash','-showScriptErrors','-world=empty','-connect=127.0.0.1',"-port=$Port","-profiles=$clientProfile","-cfg=$clientConfig","-x=$ResolutionWidth","-y=$ResolutionHeight","-windowWidth=$ResolutionWidth","-windowHeight=$ResolutionHeight",'-name=WAIT_Audit',$modArg) -Interactive
$processes+=$client.Id
$auditProcessHandles+=$client
@{runtime=$runtime; mission=$installedMission; process_ids=$processes; fingerprint=$manifest.package.fingerprint} | ConvertTo-Json | Set-Content (Join-Path $runtime 'launch.json')
$clientWindowHandle=Show-AuditClientWindow $client $ClientWindowTimeoutSeconds
$clientDeadline=(Get-Date).AddSeconds($ClientReadyTimeoutSeconds)
$observerReady=$false
while ((Get-Date) -lt $clientDeadline -and !$client.HasExited -and !$server.HasExited) {
    $logs=Get-ChildItem $serverProfile -Filter '*.rpt' -Recurse -ErrorAction SilentlyContinue
    foreach ($log in $logs) {
        if (Select-String -LiteralPath $log.FullName -SimpleMatch 'WAIT AUDIT OBSERVER ZEUS READY' -Quiet) {$observerReady=$true; break}
    }
    if ($observerReady) {break}
    Start-Sleep -Seconds 1
}
if (!$observerReady) {
    $entryFailure='ENTRY_TIMEOUT'
    $entryDetail="No observer entry within $ClientReadyTimeoutSeconds seconds"
    if ($client.HasExited) {
        $entryFailure='CLIENT_EXITED_BEFORE_ENTRY'
        $entryDetail="Client exited before observer entry (exit code $($client.ExitCode))"
    } elseif ($server.HasExited) {
        $entryFailure='SERVER_EXITED_BEFORE_ENTRY'
        $entryDetail="Server exited before observer entry (exit code $($server.ExitCode))"
    }
    @{status=$entryFailure; detail=$entryDetail; mission_ready=$ready; network_ready=$networkReady; observer_ready=$false} | ConvertTo-Json | Set-Content (Join-Path $runtime 'entry-status.json')
    throw "$entryDetail. Inspect $runtime; this batch is not valid and its recorded processes have been left available for inspection."
}
$client.Refresh()
if ($client.MainWindowHandle -eq [IntPtr]::Zero -or !$([WaitAuditWindow]::IsWindowVisible($client.MainWindowHandle))) {
    throw "Client entered WAIT_Audit.$World but its interactive window is no longer visible. Inspect $runtime; this batch is not valid."
}
[WaitAuditWindow]::ShowWindowAsync($client.MainWindowHandle,9) | Out-Null
[WaitAuditWindow]::SetForegroundWindow($client.MainWindowHandle) | Out-Null
Write-Output "WAIT batch entered WAIT_Audit.$World in a visible ${ResolutionWidth}x${ResolutionHeight} client window. The audit mission skips role selection and assigns the sole observer Zeus slot automatically. Runtime: $runtime"
if ($WaitForCompletion) {
    # Retain the actual Process handles: a later process inventory cannot recover exit codes
    # and PID reuse must not make an unrelated application look like this audit.
    $trackedProcesses=$auditProcessHandles
    $batchDeadline=(Get-Date).AddSeconds($BatchTimeoutSeconds)
    $batchState='RUNNING'
    do {
        $records=@($trackedProcesses | ForEach-Object {
            $_.Refresh()
            @{id=$_.Id; exited=$_.HasExited; exitCode=if ($_.HasExited) {$_.ExitCode} else {$null}}
        })
        $serverComplete=$false
        $clientComplete=$false
        foreach ($rpt in (Get-ChildItem $runtime -Filter '*.rpt' -Recurse)) {
            if (Select-String -LiteralPath $rpt.FullName -Pattern 'WAIT CORTEX QA SERVER COMPLETE:|WAIT STANDALONE PERF COMPLETE' -Quiet) {$serverComplete=$true}
            if (Select-String -LiteralPath $rpt.FullName -SimpleMatch 'WAIT CORTEX QA CLIENT COMPLETE:' -Quiet) {$clientComplete=$true}
        }
        if ($serverComplete -and ($clientComplete -or $Focus -eq 'standaloneperformance')) {$batchState='COMPLETED'}
        elseif ($server.HasExited -or $client.HasExited) {$batchState='PROCESS_EXIT_BEFORE_COMPLETION'}
        elseif ((Get-Date) -ge $batchDeadline) {$batchState='OBSERVATION_TIMEOUT'}
        @{state=$batchState; observedAt=(Get-Date).ToUniversalTime().ToString('o'); processes=$records;
            serverComplete=$serverComplete; clientComplete=$clientComplete; fingerprint=$manifest.package.fingerprint
        } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $runtime 'batch-status.json')
        if ($batchState -eq 'RUNNING') {Start-Sleep -Seconds 2}
    } while ($batchState -eq 'RUNNING')
    Write-Output "WAIT batch observation: $batchState. Processes are left untouched. Evidence: $runtime/batch-status.json"
}

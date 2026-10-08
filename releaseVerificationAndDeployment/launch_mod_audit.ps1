param(
    [string]$ArmaPath='',
    [string]$Package='',
    [string]$Focus='all',
    [string[]]$Mods=@(),
    [string]$Python='python',
    [int]$Port=24142,
    [int]$ResolutionWidth=3840,
    [int]$ResolutionHeight=2160,
    [ValidateRange(30,600)][int]$ClientReadyTimeoutSeconds=180,
    [ValidateRange(0,2)][int]$HeadlessClients=2,
    [switch]$WithZen,
    [switch]$ServerOnly,
    [switch]$StageOnly
)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
if (!$Package) { $Package=Join-Path $repo '.hemttout/build' }
if ($ServerOnly -and $Focus -ne 'dangerload') {throw 'ServerOnly is restricted to the dangerload loader diagnostic.'}
if (!$ArmaPath) {
    $ArmaPath=(Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\bohemia interactive\arma 3').main
}
if (!$StageOnly -and (Get-Process arma3*,arma3server* -ErrorAction SilentlyContinue)) {
    throw 'An Arma process is already running. Finish that session before launching this batch.'
}
$stageDefaultDependencies=!$Mods.Count
if ($stageDefaultDependencies) {
    $Mods=@(Join-Path $ArmaPath '!Workshop/@CBA_A3')
    if ($WithZen) {$Mods+=Join-Path $ArmaPath '!Workshop/@Zeus Enhanced'}
}
foreach ($mod in $Mods) {if (!(Test-Path -LiteralPath $mod)) {throw "Dependency folder missing: $mod"}}
$runtime=Join-Path $repo ('.qa/runtime-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
& $Python (Join-Path $PSScriptRoot 'mod_pipeline.py') stage $Package $runtime --focus $Focus
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
$manifest=Get-Content -Raw (Join-Path $runtime 'audit-manifest.json') | ConvertFrom-Json
$manifest | Add-Member dependencySources ($Mods | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
$manifest | Add-Member dependencies ($launchMods | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
$manifest | Add-Member resolution @($ResolutionWidth,$ResolutionHeight)
$manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $runtime 'audit-manifest.json')
if ($StageOnly) {Write-Output "Staged packaged audit: $runtime"; return}
$mission=Join-Path $runtime 'WAIT_Audit.VR'
$installedMission=Join-Path $ArmaPath ('MPMissions/WAIT_Audit_'+(Split-Path $runtime -Leaf)+'.VR')
Copy-Item -LiteralPath $mission -Destination $installedMission -Recurse
$missionName=Split-Path $installedMission -Leaf
$missionName=$missionName.Substring(0,$missionName.Length-3)
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
class Missions {class Audit {template="$missionName.VR"; difficulty="Regular";};};
"@ | Set-Content $config
$modArg='-mod='+(@((Join-Path $runtime '@WaldosAITweaks'))+$launchMods -join ';')
function Start-AuditProcess([string]$exe,[string[]]$arguments,[switch]$Interactive) {
    $quoted=$arguments | ForEach-Object {'"'+$_+'"'}
    # Background server/HC helpers stay hidden. The observer is an interactive game client:
    # it must expose its lobby/window so mission entry and physical behaviour can be verified.
    $auditWindowStyle = if ($Interactive) {'Normal'} else {'Hidden'}
    Start-Process -FilePath (Join-Path $ArmaPath $exe) -ArgumentList $quoted -WindowStyle $auditWindowStyle -PassThru
}
$serverProfile=Join-Path $runtime 'server'
$server=Start-AuditProcess 'arma3server_x64.exe' @('-noBattlEye','-autoInit','-netlog',"-port=$Port","-config=$config","-profiles=$serverProfile",$modArg)
$deadline=(Get-Date).AddSeconds(120)
$ready=$false
while ((Get-Date) -lt $deadline -and !$server.HasExited) {
    $logs=Get-ChildItem $serverProfile -Filter '*.rpt' -Recurse -ErrorAction SilentlyContinue
    foreach ($log in $logs) {
        if (Select-String -LiteralPath $log.FullName -SimpleMatch 'WAIT AUDIT SERVER READY' -Quiet) {$ready=$true; break}
    }
    if ($ready) {break}
    Start-Sleep -Seconds 1
}
if (!$ready) {throw "Server did not reach WAIT audit readiness. Inspect $runtime; processes have been left available for inspection."}
$processes=@($server.Id)
if ($ServerOnly) {
    @{runtime=$runtime; mission=$installedMission; process_ids=$processes; fingerprint=$manifest.package.fingerprint} | ConvertTo-Json | Set-Content (Join-Path $runtime 'launch.json')
    Write-Output "WAIT danger loader diagnostic entered WAIT_Audit.VR server-side. Runtime: $runtime"
    return
}
for ($i=1; $i -le $HeadlessClients; $i++) {
    $hc=Start-AuditProcess 'arma3server_x64.exe' @('-client','-noBattlEye','-netlog','-connect=127.0.0.1',"-port=$Port",("-profiles="+(Join-Path $runtime "hc$i")),"-name=WAIT_HC$i",$modArg)
    $processes+=$hc.Id
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
$client=Start-AuditProcess 'arma3_x64.exe' @('-noBattlEye','-netlog','-window','-noPause','-skipIntro','-noSplash','-showScriptErrors','-connect=127.0.0.1',"-port=$Port","-profiles=$clientProfile","-cfg=$clientConfig","-x=$ResolutionWidth","-y=$ResolutionHeight",'-name=WAIT_Audit',$modArg) -Interactive
$processes+=$client.Id
@{runtime=$runtime; mission=$installedMission; process_ids=$processes; fingerprint=$manifest.package.fingerprint} | ConvertTo-Json | Set-Content (Join-Path $runtime 'launch.json')
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
    throw "Client did not enter WAIT_Audit.VR with observer Zeus within $ClientReadyTimeoutSeconds seconds. Inspect $runtime; this batch is not valid and its processes have been left available for inspection."
}
Write-Output "WAIT batch entered WAIT_Audit.VR. The audit mission skips role selection and assigns the sole observer Zeus slot automatically. Runtime: $runtime"

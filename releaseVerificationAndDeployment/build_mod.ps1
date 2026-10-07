param(
    [ValidateSet('Build','Release')][string]$Mode='Build',
    [string]$Hemtt='hemtt',
    [string]$Python='python',
    [switch]$SkipStaticChecks
)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
Push-Location $repo
try {
    if (!$SkipStaticChecks) {
        & $Python -m unittest discover -s releaseVerificationAndDeployment -p 'test_*.py'
        if ($LASTEXITCODE) { throw 'Static regression checks failed' }
        & $Python releaseVerificationAndDeployment/sqf_validator.py
        if ($LASTEXITCODE) { throw 'SQF validation failed' }
        & $Python releaseVerificationAndDeployment/config_style_checker.py
        if ($LASTEXITCODE) { throw 'config_style_checker.py failed' }
        & $Python releaseVerificationAndDeployment/documentation_contract_checker.py
        if ($LASTEXITCODE) { throw 'documentation_contract_checker.py failed' }
        & $Python releaseVerificationAndDeployment/zeus_script_parity_checker.py
        if ($LASTEXITCODE) { throw 'zeus_script_parity_checker.py failed' }
        & $Python releaseVerificationAndDeployment/performance_audit.py
        if ($LASTEXITCODE) { throw 'performance_audit.py failed' }
        & $Python releaseVerificationAndDeployment/check_cortex_coverage.py
        if ($LASTEXITCODE) { throw 'Feature coverage checks failed' }
    }
    # The addon contains SQF/config/FSM only. HEMTT still rapifies config with --no-bin.
    & $Hemtt $Mode.ToLowerInvariant() --no-bin
    if ($LASTEXITCODE) { throw 'HEMTT package build failed' }
    & $Hemtt utils config inspect addons/main/fsm/tacticalDrill.fsm
    if ($LASTEXITCODE) { throw 'FSM configuration validation failed' }
    & $Hemtt utils config inspect addons/main/fsm/dangerAssessment.fsm
    if ($LASTEXITCODE) { throw 'Danger FSM configuration validation failed' }
    & $Hemtt utils config inspect addons/main/fsm/groupTactics.fsm
    if ($LASTEXITCODE) { throw 'Group tactics FSM configuration validation failed' }
    & $Hemtt utils config inspect addons/main/fsm/buildingOperation.fsm
    if ($LASTEXITCODE) { throw 'Building operation FSM configuration validation failed' }
    & $Hemtt utils config inspect addons/main/fsm/convoyOperation.fsm
    if ($LASTEXITCODE) { throw 'Convoy operation FSM configuration validation failed' }
    & $Hemtt utils config inspect addons/main/fsm/airAttackOperation.fsm
    if ($LASTEXITCODE) { throw 'Aircraft attack FSM configuration validation failed' }
    & $Python releaseVerificationAndDeployment/mod_pipeline.py seal ".hemttout/$($Mode.ToLowerInvariant())"
    if ($LASTEXITCODE) { throw 'Package sealing failed' }
} finally { Pop-Location }

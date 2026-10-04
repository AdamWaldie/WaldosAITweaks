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
        & $Python releaseVerificationAndDeployment/check_cortex_coverage.py
        if ($LASTEXITCODE) { throw 'Feature coverage checks failed' }
    }
    # The addon contains SQF/config/FSM only. HEMTT still rapifies config with --no-bin.
    & $Hemtt $Mode.ToLowerInvariant() --no-bin
    if ($LASTEXITCODE) { throw 'HEMTT package build failed' }
    & $Hemtt utils config inspect addons/main/fsm/tacticalDrill.fsm
    if ($LASTEXITCODE) { throw 'FSM configuration validation failed' }
    & $Python releaseVerificationAndDeployment/mod_pipeline.py seal ".hemttout/$($Mode.ToLowerInvariant())"
    if ($LASTEXITCODE) { throw 'Package sealing failed' }
} finally { Pop-Location }

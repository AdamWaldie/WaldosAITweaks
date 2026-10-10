"""Stage an actual companion headless provider into a disposable integration mission only."""
import hashlib
import json
from pathlib import Path
import shutil

REQUIRED = ('headlessDetectLocal.sqf', 'headlessRegisterClient.sqf',
            'headlessMigrateGroup.sqf', 'headlessAdoptGroupLocal.sqf',
            'headlessRebalance.sqf', 'headlessMigrationWorker.sqf', 'headlessDebugLog.sqf')


def stage_provider(repository, mission):
    repository, mission = Path(repository), Path(mission)
    source = repository/'MissionScripts'/'Headless'
    missing = [name for name in REQUIRED if not (source/name).is_file()]
    if missing:
        raise ValueError('Incomplete headless provider: '+', '.join(missing))
    if not mission.is_dir():
        raise ValueError('Integration mission must already exist')
    destination = mission/'compatibilityHeadlessProvider'
    if destination.exists():
        raise ValueError('Provider destination already exists')
    paths = sorted(source.glob('*.sqf'))
    destination.mkdir()
    hashes = {}
    bindings = []
    for path in paths:
        shutil.copyfile(path, destination/path.name)
        hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        function = 'Waldo_fnc_'+path.stem[0].upper()+path.stem[1:]
        bindings.append(f'{function}=compile preprocessFileLineNumbers "compatibilityHeadlessProvider{chr(92)}{path.name}";')
    header = r"""/*
 * Author: WaldoTheWarfighter
 * Purpose: Load the actual companion transfer and adoption provider for a disposable integration audit.
 * Locality/authority: Every audit machine installs functions; only the provider server owns transfers.
 * Repeat/JIP: Local installation sentinel; native bounded registration handles headless joins.
 * Arguments: None. Return: Nothing. Callers: integration mission initialization.
 * Example: call compile preprocessFileLineNumbers "compatibilityHeadlessProvider\init.sqf";
 */
if (missionNamespace getVariable ["WAIT_QA_NativeHeadlessInstalled",false]) exitWith {};
missionNamespace setVariable ["WAIT_QA_NativeHeadlessInstalled",true];
"""
    # Keep background distribution out of this explicit-transfer fixture. This is not an
    # automatic balancing acceptance case; all transfers still use the unmodified provider.
    defaults = """
if (isNil "Waldo_Headless_Enable") then {Waldo_Headless_Enable=true};
if (isNil "Waldo_Headless_Debug") then {Waldo_Headless_Debug=false};
if (isNil "Waldo_Headless_MinGroupAgeSeconds") then {Waldo_Headless_MinGroupAgeSeconds=3600};
if (isNil "Waldo_AIRebalance_Enable") then {Waldo_AIRebalance_Enable=false};
// Audit observation only: keep the original provider return and remote sender context.
WAIT_QA_NativeRegisterOriginal=Waldo_fnc_HeadlessRegisterClient;
Waldo_fnc_HeadlessRegisterClient={
    private _sender=remoteExecutedOwner;
    private _enabled=missionNamespace getVariable ["Waldo_Headless_Enable",false];
    private _result=_this call WAIT_QA_NativeRegisterOriginal;
    private _observed=missionNamespace getVariable ["WAIT_QA_NativeRegisterObserved",0];
    if (_observed < 30) then {
        missionNamespace setVariable ["WAIT_QA_NativeRegisterObserved",_observed+1];
        diag_log format ["WAIT NATIVE HC REGISTER RESULT: %1",[clientOwner,isServer,_sender,_enabled,_result,
            (entities "HeadlessClient_F") apply {owner _x},
            (allPlayers select {_x isKindOf "HeadlessClient_F"}) apply {owner _x}]];
    };
    _result
};
diag_log format ["WAIT NATIVE HC REMOTE POLICY: %1",[configFile,missionConfigFile] apply {
    private _functions=_x >> "CfgRemoteExec" >> "Functions";
    [isClass _functions,isNumber (_functions >> "mode"),getNumber (_functions >> "mode"),
        isClass (_functions >> "Waldo_fnc_HeadlessRegisterClient"),
        getNumber (_functions >> "Waldo_fnc_HeadlessRegisterClient" >> "allowedTargets")]
}];
[] call Waldo_fnc_HeadlessDetectLocal;
diag_log "WAIT NATIVE HEADLESS PROVIDER INSTALLED";
"""
    (destination/'init.sqf').write_text(header+'\n'.join(bindings)+'\n'+defaults, encoding='utf-8')
    evidence = dict(scope='EXPLICIT_NATIVE_TRANSFERS_ONLY', source=str(repository.resolve()), files=hashes)
    (destination/'source-manifest.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
    return evidence

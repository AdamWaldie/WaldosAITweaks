/*
 * Author: WaldoTheWarfighter
 * Runs disposable Cortex acceptance cases through real public functions and records RPT results.
 * Locality/authority: interface client only; only staged by the audit launcher's explicit CortexAudit switch.
 * Repeat/JIP: one run per machine; fresh fixtures are cleaned up, no production JIP replay.
 * Arguments: None. Return: Nothing (scheduled script).
 * Current callers: staged audit continuation. Example: [] execVM "cortexQAClient.sqf";
 */
if (!hasInterface || {missionNamespace getVariable ["WAIT_CortexQA_ClientRunning",false]}) exitWith {};
missionNamespace setVariable ["WAIT_CortexQA_ClientRunning",true];
[] execVM "cortexQAGuide.sqf";
waitUntil {uiSleep 0.5; !isNull player && {!isNull getAssignedCuratorLogic player} && {missionNamespace getVariable ["WAIT_CortexQA_ServerDone",false]}};
private _failures = [];
private _check = {params ["_id","_ok"]; diag_log format ["WMP CORTEX QA|%1|%2|",_id,["FAIL","PASS"] select _ok]; if (!_ok) then {_failures pushBack _id}};
missionNamespace setVariable ["WAIT_CortexQA_Phase",["CBA configuration checks","Compare registered CBA options with the shared specification and effective runtime values. This does not certify persistence, JIP or the Addon Options interface.",[]]];
private _spec = [] call WAIT_fnc_CortexTuningSpec;
private _keys = _spec apply {_x select 0};
["UI-01b-canonical-settings",count _keys == count (_keys arrayIntersect _keys)] call _check;
["UI-CBA-registration-ready",missionNamespace getVariable ["WAIT_AITweaks_CBASettingsRegistered",false]] call _check;
{
    _x params ["_key","_label","_help","_kind","_options","_default"];
    private _registered = !isNil {[_key,"default"] call CBA_settings_fnc_get};
    [format ["UI-registered-%1",_key],_registered] call _check;
    if (_registered) then {
        private _value = [_key] call CBA_settings_fnc_get;
        private _valid = _value isEqualType _default;
        if (_valid) then {
            switch (_kind) do {
                case "SLIDER": {_valid = _value >= (_options select 0) && {_value <= (_options select 1)}};
                case "COMBO": {_valid = _value in (_options select 0)};
            };
        };
        [format ["UI-effective-%1",_key],_valid && {_value isEqualTo (missionNamespace getVariable [_key,_default])}] call _check;
    };
} forEach _spec;
missionNamespace setVariable ["WAIT_CortexQA_ClientDone",true];
missionNamespace setVariable ["WAIT_CortexQA_Phase",["Client checks finished",format ["%1 client finding(s). Configuration is available in CBA Addon Options. Persistence, server enforcement, JIP and interactive UI checks remain pending.",count _failures],[]]];
player createDiaryRecord ["Diary",["Cortex client results",format ["CBA registration/effective-state findings: %1. Server findings: %2. No settings were changed by these client checks.",_failures,missionNamespace getVariable ["WAIT_CortexQA_ServerFailures",[]]]]];
diag_log format ["WMP CORTEX QA CLIENT COMPLETE: %1 finding(s) %2",count _failures,_failures];

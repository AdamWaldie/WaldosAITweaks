/*
 * Author: WaldoTheWarfighter
 * Changes Cortex difficulty and tuning settings during a mission, on every machine.
 *
 * Accepts only the settings in WAIT_fnc_CortexTuningSpec. Slider values are clamped to their range,
 * combo values must be one of the listed choices, and anything else is ignored with an RPT line. The
 * accepted values are broadcast, so the server and every headless client use them on each squad's
 * next step. Master/skill changes also update local workers after the complete revision is applied.
 * CBA Addon Options is the configuration UI; scripts use this validated CBA server-layer API.
 * Locality and authority: server-authoritative; a call on a client is forwarded to the server.
 *
 * Repeat/JIP: monotonically ordered local application; joining owners use the full settings snapshot.
 * Arguments:
 * 0: settings <HASHMAP> - variable name to new value, for example WAIT_AIPass_Aggression to 1.5
 *
 * Return Value:
 * Number - settings applied (on a client: -1, forwarded)
 *
 * Example:
 * [createHashMapFromArray [["WAIT_AIPass_Aggression", 1.5], ["WAIT_AIPass_Cohesion", 0.8]]] call WAIT_fnc_CortexTuning;
 * Result: from a trigger, squads become more aggressive and break sooner for the rest of the mission.
 *
 * Current callers: mission triggers, scripts and disposable server audits.
 */

params [["_settings", createHashMap, [createHashMap]]];
if (!isServer) exitWith {
    [_settings] remoteExecCall ["WAIT_fnc_CortexTuning", 2];
    -1
};
if (remoteExecutedOwner > 2 && {!(remoteExecutedOwner in ((allCurators apply {getAssignedCuratorUnit _x}) select {!isNull _x} apply {owner _x}))}) exitWith {
    diag_log format ["[WAIT] Tuning from owner %1 refused: only the server or an assigned curator may change it.", remoteExecutedOwner];
    0
};
private _spec = [] call WAIT_fnc_CortexTuningSpec;
private _updates = [];
{
    private _variable = _x;
    private _value = _y;
    private _index = _spec findIf {(_x select 0) == _variable};
    if (_index < 0) then {
        diag_log format ["[WAIT] Tuning ignored unknown setting %1.", _variable];
    } else {
        (_spec select _index) params ["", "", "", "_kind", "_options"];
        private _accepted = switch (_kind) do {
            case "SLIDER": {
                if (_value isEqualType 0) then {
                    _options params ["_min", "_max", "_decimals"];
                    _value = (_value max _min) min _max;
                    if (_decimals == 0) then {_value = round _value};
                    true
                } else {false};
            };
            case "CHECKBOX": {_value isEqualType true};
            case "COMBO": {_value isEqualType "" && {toUpperANSI _value in ((_options select 0) apply {toUpperANSI _x})}};
            default {false};
        };
        if (_accepted) then {
            if (_value isEqualType "") then {_value = toUpperANSI _value};
            _updates pushBack [_variable, _value];
        } else {
            diag_log format ["[WAIT] Tuning ignored %1 = %2 (not a valid %3 value).", _variable, _value, toLowerANSI _kind];
        };
    };
} forEach _settings;
// CBA is the sole effective configuration store. Curator changes are server-enforced for this
// session, not saved silently into the administrator profile. CBA handles callback/JIP replay.
{[_x select 0, _x select 1, true, "server", false] call CBA_settings_fnc_set} forEach _updates;
if (_updates isNotEqualTo []) then {
    private _revision = (missionNamespace getVariable ["WAIT_AIPass_SettingsRevision",0])+1;
    missionNamespace setVariable ["WAIT_AIPass_SettingsRevision",_revision,true];
    // Retire old positional JIP initializers; joining owners use the authoritative full snapshot.
    if (_updates findIf {(_x select 0) find "WAIT_AIRebalance_" == 0} >= 0) then {[] remoteExecCall ["","WAIT_AIRebalance_RuntimeInit"]};
    if (_updates findIf {(_x select 0) == "WAIT_AIPass_Enable"} >= 0) then {[] remoteExecCall ["","WAIT_AIPass_RuntimeInit"]};
    private _snapshot = _spec apply {[_x select 0,missionNamespace getVariable [_x select 0,_x select 5]]};
    [_revision,_snapshot] remoteExecCall ["WAIT_fnc_CortexSettingsLocal",0];
};
diag_log format ["[WAIT] Tuning applied: %1", _updates];
count _updates

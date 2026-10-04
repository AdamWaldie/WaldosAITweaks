/*
 * Author: WaldoTheWarfighter
 * Validates and publishes a curator's Cortex settings changes from the optional ZEN control panel.
 * Locality / Authority: Server only through a CBA server event; the requesting player must own an assigned curator.
 * Repeat/JIP: Each accepted revision publishes current missionNamespace values for JIP and rejects stale revisions.
 * Arguments: 0 requester <OBJECT>; 1 key/value rows <ARRAY>, optionally ending in __expectedRevision.
 * Return Value: BOOL - true when a non-stale, authorised request is accepted.
 * Current callers: WAIT_AITweaks_SettingsRequest CBA server event installed during preInit.
 * Example: [player, [["WAIT_AIPass_Enable", true], ["__expectedRevision", 2]]] call WAIT_fnc_AITweaksSettingsRequestServer;
 */

if (!isServer) exitWith {false};
params [["_requester", objNull, [objNull]], ["_rows", [], [[]]]];
if (isNull _requester || {isNull getAssignedCuratorLogic _requester}) exitWith {false};

private _spec = createHashMap;
{_spec set [_x select 0, _x]} forEach ([] call WAIT_fnc_CortexTuningSpec);
private _revision = missionNamespace getVariable ["WAIT_AIPass_SettingsRevision", 0];
private _expected = _revision;
{
    _x params [["_key", "", [""]], "_value"];
    if (_key == "__expectedRevision") then {_expected = _value};
} forEach _rows;
if !(_expected isEqualTo _revision) exitWith {false};

private _changed = 0;
{
    _x params [["_key", "", [""]], "_value"];
    private _row = _spec getOrDefault [_key, []];
    if (_row isNotEqualTo [] && {_value isEqualType (_row select 5)}) then {
        missionNamespace setVariable [_key, _value, true];
        _changed = _changed + 1;
    };
} forEach _rows;
if (_changed == 0) exitWith {true};
missionNamespace setVariable ["WAIT_AIPass_SettingsRevision", _revision + 1, true];
true

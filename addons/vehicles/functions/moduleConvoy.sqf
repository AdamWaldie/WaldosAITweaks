/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes a native Zeus convoy order on the explicitly attached vehicle.
 * Locality/authority: Global module activation, handled once on the placing logic owner with
 * an interface. SimpleAiConvoy validates the requesting curator and applies authoritative state.
 * Repeat/JIP: Disposable command; processed guard prevents repeat dispatch. No JIP action replay.
 * Arguments: 0 logic <OBJECT>, objNull; 1 synchronized units <ARRAY>, []; 2 activated <BOOL>, true.
 * Return Value: BOOL - true if dispatched, false for invalid target or inactive/nonlocal invocation.
 * Current callers: WAIT_ModuleConvoyStart/Hold/Release native curator modules.
 * Example: [convoyOrderLogic, [], true] call WAIT_fnc_ModuleConvoy;
 */
params [["_logic", objNull, [objNull]], ["_units", [], [[]]], ["_activated", true, [true]]];
if (isNull _logic || {!_activated} || {!local _logic} || {!hasInterface}) exitWith {false};
if (_logic getVariable ["WAIT_processed", false]) exitWith {false};
_logic setVariable ["WAIT_processed", true];
private _target = attachedTo _logic;
private _operation = getText (configFile >> "CfgVehicles" >> typeOf _logic >> "WAIT_operation");
if (isNull _target || {!(_target isKindOf "LandVehicle")} || {!alive driver _target} || {isPlayer driver _target}) exitWith {
    ["CONVOY", "Place the order on a crewed AI land vehicle. No nearby vehicle is selected automatically.", "ERROR"] call WAIT_fnc_AITweaksNotifyLocal;
    deleteVehicle _logic;
    false
};
private _group = group driver _target;
private _entry = (missionNamespace getVariable ["WAIT_Convoy_Registry", []]) select {(_x select 0) == _group};
private _config = if (_entry isEqualTo []) then {[]} else {(_entry select 0) select 1};
private _speed = _config param [1, missionNamespace getVariable ["WAIT_Convoy_DefaultSpeed", 30]];
private _spacing = _config param [2, missionNamespace getVariable ["WAIT_Convoy_DefaultSeparation", 30]];
private _push = _config param [3, missionNamespace getVariable ["WAIT_Convoy_DefaultPushThrough", true]];
private _accepted = switch (_operation) do {
    case "START": {[_group, _speed, _spacing, _push] call WAIT_fnc_SimpleAiConvoy};
    case "STOP": {[_group, 0, _spacing, _push] call WAIT_fnc_SimpleAiConvoy};
    case "RELEASE": {[_group, _speed, _spacing, _push, true] call WAIT_fnc_SimpleAiConvoy};
    default {false};
};
deleteVehicle _logic;
_accepted

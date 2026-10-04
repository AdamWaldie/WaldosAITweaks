/*
 * Author: WaldoTheWarfighter
 * Configures, holds/unloads or releases the selected AI vehicle group's convoy. Never guesses the nearest vehicle.
 * Locality/authority: interface dialog; SimpleAiConvoy forwards to the server and authenticates the curator owner.
 * Repeat/JIP: configuration replaces the existing registration; server registry replays to HCs.
 * Arguments: 0: module position <ARRAY>; 1: selected vehicle <OBJECT>, default objNull.
 * Return Value: Nothing.
 * Current callers: optional ZEN module registration in bootstrap/zenRegister.sqf.
 * Example: [getPosATL truck1, truck1] call WAIT_fnc_ZenConvoyModule;
 */
params ["_modulePos", ["_target", objNull, [objNull]]];
if (isNull _target || {!(_target isKindOf "LandVehicle")} || {!alive driver _target}) exitWith {
    ["CONVOY", "Place the module on a crewed AI land vehicle.", "ERROR"] call WAIT_fnc_AITweaksNotifyLocal;
};
private _group = group driver _target;
private _entry = (missionNamespace getVariable ["WAIT_Convoy_Registry",[]]) select {(_x select 0) == _group};
private _config = if (_entry isEqualTo []) then {[]} else {(_entry select 0) select 1};
private _vehicles = [];
{private _v = vehicle _x; if (_v isKindOf "LandVehicle" && {group driver _v == _group}) then {_vehicles pushBackUnique _v}} forEach units _group;
if (_config isEqualTo [] && {count _vehicles < 2}) exitWith {
    ["CONVOY","Group at least two AI-driven vehicles together in Zeus, give their leader a route, then place this module on a vehicle in that group.","ERROR"] call WAIT_fnc_AITweaksNotifyLocal;
};
private _operations = if (_config isEqualTo []) then {["START"]} else {["START","STOP","RELEASE"]};
private _operationLabels = if (_config isEqualTo []) then {["Start convoy on its waypoint route"]} else {["Apply settings / resume route","Hold and unload passengers","Release convoy control"]};
[
    format ["Cortex convoy: %1 / %2 vehicles / %3",groupId _group,count _vehicles,_config param [5,"Not started"]],
    [
        ["COMBO", ["Operation", "Configure/resume applies travel settings. Stop holds vehicles and dismounts cargo. Release restores prior settings and removes control."], [_operations, _operationLabels, 0]],
        ["SLIDER", ["Maximum speed (km/h)", "The lead slows for sharp bends and stretched spacing."], [5, 120, _config param [1,30], 0]],
        ["SLIDER", ["Separation (m)", "Minimum centre spacing; vehicle length can increase it. Mixed convoys pace for slower vehicles."], [10, 100, _config param [2,30], 0]],
        ["CHECKBOX", ["Push through contact", "On: move through contact; stop and dismount cargo if pinned for 15 seconds. Off: stop and dismount cargo on contact. Weapon crew remain mounted. Resume does not automatically reboard dismounted passengers."], _config param [3,true]]
    ],
    {
        params ["_values", "_target"];
        _values params ["_operation", "_speed", "_separation", "_pushThrough"];
        private _group = group driver _target;
        switch (_operation) do {
            case "STOP": {[_group, 0, round _separation, _pushThrough] call WAIT_fnc_SimpleAiConvoy};
            case "RELEASE": {[_group, round _speed, round _separation, _pushThrough, true] call WAIT_fnc_SimpleAiConvoy};
            default {[_group, round _speed, round _separation, _pushThrough] call WAIT_fnc_SimpleAiConvoy};
        };
    }, {}, _target
] call zen_dialog_fnc_create;

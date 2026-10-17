/*
 * Author: WaldoTheWarfighter
 * Purpose: Selects an explicit AI squad and building for the production physical clearance task.
 * Locality/authority: interface dialog only; server authenticates curator and validates target;
 * current group owner preflights and acknowledges CortexClearBuilding through named dispatch.
 * Repeat/JIP: one-shot selector snapshot; owner validates again. No settings or JIP command replay.
 * Arguments: 0 module centre ATL <ARRAY>, []; 1 attached target <OBJECT>, objNull.
 * Return: BOOL - dialog opened, not task acceptance, building entry or hostile-room clearance.
 * Current callers: optional ZEN custom module registration.
 * Example: [getPosATL house1,house1] call WAIT_fnc_ZenClearModule;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]]];
if (!hasInterface || {isNil "zen_dialog_fnc_create"} || {count _position != 3}
    || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {false};
private _groups=allGroups;
_groups resize ((count _groups) min 128);
_groups=_groups select {!isNull leader _x && {alive leader _x} && {units _x findIf {isPlayer _x} < 0}};
if (!isNull _target && {_target isKindOf "CAManBase"} && {!isPlayer _target}) then {
    private _selected=group _target;
    _groups=[_selected]+(_groups-[_selected]);
};
private _buildings=nearestObjects [_position,["House"],150,true];
_buildings resize ((count _buildings) min 128);
_buildings=_buildings select {alive _x && {(_x buildingPos -1) isNotEqualTo []}};
if (!isNull _target && {_target isKindOf "House"} && {alive _target}
    && {(_target buildingPos -1) isNotEqualTo []}) then {
    _buildings=[_target]+(_buildings-[_target]);
};
if (_groups isEqualTo [] || {_buildings isEqualTo []}) exitWith {
    ["CLEAR","No selectable squad or building reporting interior positions. Place on an AI soldier or building to include it explicitly.","ERROR"] call WAIT_fnc_AITweaksNotifyLocal;
    false
};
private _labels=_buildings apply {
    private _name=getText (configOf _x >> "displayName");
    if (_name == "") then {_name=typeOf _x};
    format ["%1 / %2 m / %3 reported positions",_name,round (_position distance2D _x),count (_x buildingPos -1)]
};
[
    "Clear building task",
    [
        ["COMBO",["Squad","Explicit squad to clear this building. Requires at least two capable soldiers on foot; existing ownership and feature gates still apply."],[_groups,_groups apply {format ["%1 / %2 / %3 soldiers",side _x,groupId _x,count units _x]},0]],
        ["COMBO",["Building","Select the exact building. Up to 128 candidates within 150 m; an attached house is included. Reported positions do not prove physical access or a safe room. Actors enter, traverse and exit normally."],[_buildings,_labels,0]]
    ],
    {
        params ["_values"];
        _values params ["_group","_building"];
        [[["order","CLEAR"],["group",_group],["building",_building]],clientOwner] call WAIT_fnc_CortexOrderDispatch;
    },{},[]
] call zen_dialog_fnc_create;
true

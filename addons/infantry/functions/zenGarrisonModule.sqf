/*
 * Author: WaldoTheWarfighter
 * Purpose: Selects an explicit AI squad and garrison area task, walking or instant placement.
 * Locality/authority: interface dialog only. Server authenticates curator and validates the task;
 * current group owner preflights and acknowledges its real garrison executor.
 * Repeat/JIP: a fresh accepted task replaces the old task; no dialog or command replay for JIP.
 * The selection snapshot is checked again on acceptance. No global settings are changed.
 * Arguments: 0 centre ATL <ARRAY>, []; 1 attached target <OBJECT>, objNull.
 * Return: BOOL - dialog created, not task acceptance or physical arrival.
 * Current callers: ZEN registration and WAIT_fnc_ModuleGarrison.
 * Example: [getPosATL house1,soldier1] call WAIT_fnc_ZenGarrisonModule;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]]];
if (!hasInterface || {isNil "zen_dialog_fnc_create"} || {count _position != 3}) exitWith {false};
// One-shot UI enumeration, never a recurring AI scan. Explicit attached squad remains available
// even when the 128-item selector cap excludes it from the initial list.
private _groups = allGroups;
_groups resize ((count _groups) min 128);
_groups = _groups select {!isNull leader _x && {alive leader _x} && {units _x findIf {isPlayer _x} < 0}};
if (!isNull _target && {_target isKindOf "CAManBase"} && {!isPlayer _target}) then {
    private _selected = group _target;
    _groups = [_selected] + (_groups - [_selected]);
};
if (_groups isEqualTo []) exitWith {
    ["GARRISON","No selectable AI squad. Place the module on an AI soldier to select its squad explicitly.","ERROR"] call WAIT_fnc_AITweaksNotifyLocal;
    false
};
[
    "Garrison area task",
    [
        ["COMBO",["Squad","Explicit squad to occupy buildings within this task area. The selector shows up to 128 groups; place on a soldier to include its squad."],[_groups,_groups apply {format ["%1 / %2 / %3 soldiers",side _x,groupId _x,count units _x]},0]],
        ["SLIDER",["Area radius (m)","Search buildings around the module position. Surplus soldiers receive exterior security assignments."],[15,150,50,0]],
        ["COMBO",["Placement","Walk approaches assigned positions normally. Instant placement moves eligible interior defenders once; exterior security still walks. This does not clear hostile rooms."],[[false,true],["Walk into positions","Instant interior placement"],0]],
        ["CHECKBOX",["Prefer higher positions","When enabled, select higher roofed posts first. When disabled, distribute posts randomly within the roofed-first candidate list. This does not establish route accessibility."],true]
    ],
    {
        params ["_values","_position"];
        _values params ["_group","_radius","_teleport","_sortByHeight"];
        [[["order","GARRISON"],["group",_group],["position",_position],["radius",round _radius],["teleport",_teleport],["sortByHeight",_sortByHeight]],clientOwner] call WAIT_fnc_CortexOrderDispatch;
    },{},+_position
] call zen_dialog_fnc_create;
true

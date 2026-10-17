/*
 * Author: WaldoTheWarfighter
 * Purpose: Selects an explicit AI squad, defensive line centre, facing and width for a real task.
 * Locality/authority: interface dialog only; server authenticates the curator and routes validated
 * task parameters to the current group owner, which preflights and acknowledges CortexDefend.
 * Repeat/JIP: new task replaces existing posted work; dialog/commands are not replayed to JIP.
 * Selection is a one-shot snapshot, revalidated at dispatch/execution. No addon setting changes.
 * Arguments: 0 centre ATL <ARRAY>, []; 1 attached target <OBJECT>, objNull.
 * Return: BOOL - dialog opened, not acceptance or physical defence completion.
 * Current callers: ZEN registration and WAIT_fnc_ModuleGarrison for WAIT_ModuleDefend.
 * Example: [getMarkerPos "ridge",soldier1] call WAIT_fnc_ZenDefendModule;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]]];
if (!hasInterface || {isNil "zen_dialog_fnc_create"} || {count _position != 3}) exitWith {false};
private _groups=allGroups;
_groups resize ((count _groups) min 128);
_groups=_groups select {!isNull leader _x && {alive leader _x} && {units _x findIf {isPlayer _x} < 0}};
if (!isNull _target && {_target isKindOf "CAManBase"} && {!isPlayer _target}) then {
    private _selected=group _target;
    _groups=[_selected]+(_groups-[_selected]);
};
if (_groups isEqualTo []) exitWith {
    ["DEFEND","No selectable AI squad. Place the module on an AI soldier to include its squad explicitly.","ERROR"] call WAIT_fnc_AITweaksNotifyLocal;
    false
};
[
    "Defend area task",
    [
        ["COMBO",["Squad","Select the squad that will occupy this defensive line. Up to 128 initial groups; an attached soldier's squad is included."],[_groups,_groups apply {format ["%1 / %2 / %3 soldiers",side _x,groupId _x,count units _x]},0]],
        ["SLIDER",["Facing (degrees)","Direction of the threat: 0 north, 90 east, 180 south, 270 west. Soldiers occupy cover with overlapping watch sectors."],[0,360,if (isNull _target) then {0} else {getDir _target},0]],
        ["SLIDER",["Line width (m)","Width across the facing direction. The existing defence executor assigns a line and rear reserve; this is a task parameter, not a global setting."],[15,150,60,0]]
    ],
    {
        params ["_values","_position"];
        _values params ["_group","_facing","_width"];
        [[["order","DEFEND"],["group",_group],["position",_position],["facing",round _facing],["width",round _width]],clientOwner] call WAIT_fnc_CortexOrderDispatch;
    },{},+_position
] call zen_dialog_fnc_create;
true

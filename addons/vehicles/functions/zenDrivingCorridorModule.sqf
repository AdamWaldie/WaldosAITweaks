/*
 * Author: WaldoTheWarfighter
 * Purpose: Opens scoped navigation-corridor creation/edit/removal behaviour controls.
 * Locality / Authority: Interface dialog only; named payload goes to the authenticated server.
 * Repeat/JIP: One accepted dialog sends one monotonic serial/expiry. No dialog or command replay.
 * Arguments: 0 position ATL <ARRAY, []>; 1 explicit existing corridor <OBJECT, objNull>;
 * 2 default facing <NUMBER, 0> - native module orientation when creating.
 * Return Value: BOOL - dialog opened, not server acceptance or physical passage.
 * Current callers: ZEN registration and ModuleDrivingCorridor.
 * Example: [getMarkerPos "bridge",objNull] call WAIT_fnc_ZenDrivingCorridorModule;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]],["_defaultFacing",0,[0]]];
if (!hasInterface || {isNil "zen_dialog_fnc_create"} || {count _position != 3}) exitWith {false};
if (!isNull _target && {!(_target isKindOf "WAIT_DrivingCorridorArea")}) exitWith {
    ["NAVIGATION CORRIDOR","Place on empty ground to create, or on the exact existing corridor area to edit. No nearest area is selected.","ERROR"] call WAIT_fnc_AITweaksNotifyLocal;false
};
private _editing=!isNull _target;
private _definition=if (_editing) then {_target getVariable ["WAIT_DrivingCorridor_Task",[0,25,5,15]]} else {[0,25,5,15]};
private _transform=if (_editing) then {[getPosWorld _target,vectorDir _target,vectorUp _target]} else {[]};
[
    "Navigation corridor task",
    [
        ["COMBO",["Task action","Create on empty ground. Update/remove applies only to the explicitly selected corridor area."],
            [if (_editing) then {["UPDATE","REMOVE"]} else {["CREATE"]},if (_editing) then {["Update selected corridor","Remove selected corridor"]} else {["Create corridor"]},0]],
        ["SLIDER",["Direction (degrees)","Axis through the corridor: 0 north/south, 90 east/west. Existing routes must cross opposite ends. AI-steering land vehicles and dry supported paths only. Both driver and commander must remain available on the vehicle owner."],[0,360,if (_editing) then {getDir _target} else {_defaultFacing},0]],
        ["SLIDER",["Half-length (m)","Distance from centre to either end, excluding hull-sized approach/exit extensions."],[5,45,_definition param [1,25],0]],
        ["SLIDER",["Half-width (m)","Distance from centreline to either side. The whole living convoy envelope must fit."],[2,20,_definition param [2,5],0]],
        ["SLIDER",["Task speed (km/h)","Upper speed for the vehicle or convoy lead; existing traffic, pedestrian and convoy safety limits still win."],[5,30,_definition param [3,15],0]]
    ],
    {
        params ["_values","_context"];
        _context params ["_position","_target","_transform"];
        _values params ["_mode","_facing","_halfLength","_halfWidth","_speed"];
        private _serial=(missionNamespace getVariable ["WAIT_DrivingCorridor_LocalSerial",0])+1;
        missionNamespace setVariable ["WAIT_DrivingCorridor_LocalSerial",_serial];
        [[["mode",_mode],["area",_target],["position",_position],["transform",_transform],
            ["facing",round _facing],["halfLength",round _halfLength],["halfWidth",round _halfWidth],
            ["speed",round _speed],["serial",_serial],["expires",serverTime+10]]] call WAIT_fnc_DrivingCorridorDispatch;
    },{},[+_position,_target,_transform]
] call zen_dialog_fnc_create;
true

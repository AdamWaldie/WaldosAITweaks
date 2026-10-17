/*
 * Author: WaldoTheWarfighter
 * Purpose: Places a scoped navigation-corridor behaviour task, optionally editing an explicit area.
 * Locality / Authority: Placing interface/logic owner only; server authenticates and registers.
 * Repeat/JIP: Disposable frontend processes once; persistent area is a separate editable Logic.
 * Without ZEN, creates a 25 m half-length/5 m half-width/15 km/h corridor along module facing.
 * Existing-area edits require the optional labelled dialog; deleting the area invalidates work.
 * Arguments: 0 logic <OBJECT, objNull>; 1 units <ARRAY, []>; 2 activated <BOOL, true>.
 * Return Value: BOOL - dialog/request submitted, not physical crossing.
 * Current callers: WAIT_ModuleDrivingCorridor native curator module.
 * Example: [corridorTaskLogic,[],true] call WAIT_fnc_ModuleDrivingCorridor;
 */
params [["_logic",objNull,[objNull]],["_units",[],[[]]],["_activated",true,[true]]];
if (isNull _logic || {!_activated} || {!local _logic} || {!hasInterface}) exitWith {false};
if (_logic getVariable ["WAIT_processed",false]) exitWith {false};
_logic setVariable ["WAIT_processed",true];
private _target=attachedTo _logic;private _position=getPosATL _logic;private _facing=getDir _logic;
private _accepted=false;
if (!isNil "zen_dialog_fnc_create") then {
    _accepted=[_position,_target,_facing] call WAIT_fnc_ZenDrivingCorridorModule;
} else {
    if (isNull _target) then {
        private _serial=(missionNamespace getVariable ["WAIT_DrivingCorridor_LocalSerial",0])+1;
        missionNamespace setVariable ["WAIT_DrivingCorridor_LocalSerial",_serial];
        _accepted=[[["mode","CREATE"],["position",_position],["facing",_facing],
            ["halfLength",25],["halfWidth",5],["speed",15],["serial",_serial],["expires",serverTime+10]]]
            call WAIT_fnc_DrivingCorridorDispatch;
    } else {
        ["NAVIGATION CORRIDOR","Place on empty ground to create. Editing an existing area requires the optional task dialog; delete its area to remove it.","ERROR"] call WAIT_fnc_AITweaksNotifyLocal;
    };
};
deleteVehicle _logic;
_accepted

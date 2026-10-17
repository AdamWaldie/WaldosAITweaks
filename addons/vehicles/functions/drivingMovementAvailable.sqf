/*
 * Author: WaldoTheWarfighter
 * Purpose: Determines whether ordinary driving may write while finite WAIT movement is active.
 * Locality / Authority: Read-only on the current group owner, or trusted server recheck; never grants tactical ownership.
 * Repeat/JIP: Reads the live public movement lease and exact current reverse epoch/deadline.
 * No handlers, timers or cached permission are installed; every command rechecks this boundary.
 * Unknown or malformed leases block admission; only fully typed finite expiry can free work.
 * Arguments: 0 group <GROUP, grpNull>; 1 server recheck <BOOL, false>, server-only read of remote state.
 * Return Value: BOOL - false for unsupported locality or live/unknown tactical movement ownership.
 * Current callers: DrivingOperationStart/Step, DrivingAssistStart/Release, DrivingCrewStep,
 * DrivingGateOpenServer and finite driving helpers.
 * Example: private _free = [group driver truck1] call WAIT_fnc_DrivingMovementAvailable;
 */
params [["_group",grpNull,[grpNull]],["_serverCheck",false,[true]]];
if (isNull _group || {!local _group && {!(_serverCheck && {isServer})}}) exitWith {false};
private _lease=_group getVariable ["WAIT_Cortex_MovementLease",[]];
if (_lease isNotEqualTo []) then {
    private _typed=_lease isEqualType [] && {count _lease == 2}
        && {(_lease select 0) isEqualType ""} && {(_lease select 0) != ""}
        && {(_lease select 1) isEqualType 0} && {finite (_lease select 1)};
    if (!_typed || {serverTime < (_lease select 1)}) exitWith {_lease=["RESERVED"]};
    _lease=[];
};
if (_lease isNotEqualTo []) exitWith {false};
private _reverse=_group getVariable ["WAIT_VehicleReverse",[]];
if (_reverse isEqualTo []) exitWith {true};
private _positionValid={
    params ["_position","_counts"];
    _position isEqualType [] && {count _position in _counts}
        && {_position findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
private _typed=_reverse isEqualType [] && {count _reverse == 9}
    && {(_reverse select 0) isEqualType objNull}
    && {[1,2,5,6] findIf {!((_reverse select _x) isEqualType 0) || {!finite (_reverse select _x)}} < 0}
    && {[_reverse select 3,[3]] call _positionValid}
    && {[_reverse select 4,[2,3]] call _positionValid}
    && {[_reverse select 7,[3]] call _positionValid}
    && {(_reverse select 8) isEqualType ""}
    && {(_reverse select 8) in ["BACK","LEFT","RIGHT","STOPTURNING"]};
if (!_typed) exitWith {false};
!((_reverse select 2) == (_group getVariable ["WAIT_AIPass_Epoch",0])
    && {time < (_reverse select 5)})

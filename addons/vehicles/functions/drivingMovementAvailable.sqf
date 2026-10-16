/*
 * Author: WaldoTheWarfighter
 * Purpose: Determines whether ordinary driving may write while finite WAIT movement is active.
 * Locality / Authority: Read-only on the current group owner; never grants tactical ownership.
 * Repeat/JIP: Reads the live public movement lease and exact current reverse epoch/deadline.
 * No handlers, timers or cached permission are installed; every command rechecks this boundary.
 * Arguments: 0 group <GROUP, grpNull>.
 * Return Value: BOOL - false for nonlocal groups or an unexpired tactical movement owner.
 * Current callers: DrivingOperationStart, DrivingOperationStep, DrivingAssistStart and DrivingAssistRelease.
 * Example: private _free = [group driver truck1] call WAIT_fnc_DrivingMovementAvailable;
 */
params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group}) exitWith {false};
private _lease=_group getVariable ["WAIT_Cortex_MovementLease",[]];
if (count _lease == 2 && {serverTime < (_lease select 1)}) exitWith {false};
private _reverse=_group getVariable ["WAIT_VehicleReverse",[]];
!(count _reverse == 9 && {(_reverse select 2) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {time < (_reverse select 5)})

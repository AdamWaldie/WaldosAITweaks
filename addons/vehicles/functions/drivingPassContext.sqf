/*
 * Author: WaldoTheWarfighter
 * Purpose: Reads the crew, locality and native-order identity of two road-pass participants.
 * Locality/authority: Read-only anywhere; this receipt is an observation, never owner agreement.
 * Repeat/JIP: No state, commands or handlers. Re-read before consuming deferred scan evidence.
 * Arguments: 0 vehicles <ARRAY of OBJECT>, [], exactly two distinct live LandVehicles.
 * Return: ARRAY [observing client owner, participant rows], [] for invalid participants.
 * Each row is [vehicle, vehicle owner, driver receipt, effective-commander receipt]. An actor
 * receipt includes actor/owner, group/owner/epoch, player/remote control, native command and
 * expected destination, plus the full authored route receipt. Missing crew use an empty row.
 * Current callers: DrivingPassPlan, DrivingPassGeometry, DrivingPassTraffic, DrivingPassPrepare,
 * DrivingPassAgreementServer and DrivingPassAgreementOwner.
 * Example: private _receipt=[[truck1,truck2]] call WAIT_fnc_DrivingPassContext;
 */
params [["_vehicles",[],[[]]]];
if (count _vehicles != 2 || {(_vehicles select 0) isEqualTo (_vehicles select 1)}
    || {_vehicles findIf {!(_x isEqualType objNull) || {isNull _x} || {!alive _x}
        || {!(_x isKindOf "LandVehicle")}} >= 0}) exitWith {[]};
private _actorReceipt={
    params ["_actor"];
    if (isNull _actor) exitWith {[]};
    private _group=group _actor;
    [_actor,owner _actor,_group,groupOwner _group,_group getVariable ["WAIT_AIPass_Epoch",0],
        isPlayer _actor,remoteControlled _actor,currentCommand _actor,+(expectedDestination _actor),
        [_group] call WAIT_fnc_NativeOrderReceipt]
};
[clientOwner,_vehicles apply {
    private _operator=effectiveCommander _x;
    if (isNull _operator) then {_operator=driver _x};
    [_x,owner _x,[driver _x] call _actorReceipt,[_operator] call _actorReceipt]
}]
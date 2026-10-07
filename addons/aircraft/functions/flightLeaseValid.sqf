/*
 * Author: WaldoTheWarfighter
 * Purpose: Checks whether one WAIT controller still owns the local aircraft flight-mutation lease.
 * Locality / Authority: Cheap read on the aircraft owner. It rejects player/direct-control takeover; each bounded controller retains its existing slower Zeus, order and specialist validation before mutation.
 * Repeat/JIP: Pure bounded predicate; public lease state is diagnostic and never transfers authority.
 * Arguments: 0 aircraft <OBJECT>; 1 controller <STRING>; 2 token <STRING>.
 * Return Value: Boolean - true only for the exact current local lease owner.
 * Current callers: aircraft attack, helicopter landing, missile defence and helicopter braking mutation boundaries.
 * Example: [_aircraft,"LANDING",str _revision] call WAIT_fnc_FlightLeaseValid;
 */
params [["_aircraft",objNull,[objNull]],["_controller","",[""]],["_token","",[""]]];
if (isNull _aircraft || {!local _aircraft} || {!alive _aircraft}) exitWith {false};
private _pilot=currentPilot _aircraft;
if (isNull _pilot || {!alive _pilot} || {isPlayer _pilot} || {!isNull (remoteControlled _pilot)}) exitWith {false};
private _lease=_aircraft getVariable ["WAIT_FlightLease",createHashMap];
count _lease > 0
    && {(_lease getOrDefault ["controller",""]) == _controller}
    && {(_lease getOrDefault ["token",""]) == _token}
    && {(_lease getOrDefault ["owner",-1]) == clientOwner}

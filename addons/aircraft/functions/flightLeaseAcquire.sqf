/*
 * Author: WaldoTheWarfighter
 * Purpose: Acquires the single owner-local WAIT flight-mutation lease for an AI aircraft.
 * Locality / Authority: Aircraft-owner local. Player, curator, specialist and non-local aircraft are rejected before lease mutation.
 * Repeat/JIP: Re-acquiring the same controller/token refreshes its lease. A strictly higher priority may replace an older WAIT controller; public state is diagnostic only and grants no remote authority.
 * Arguments: 0 aircraft <OBJECT>; 1 controller <STRING>; 2 token <STRING>; 3 priority <NUMBER>.
 * Return Value: Boolean - true only when the caller owns the current flight lease.
 * Current callers: aircraft attack, helicopter landing, missile defence and helicopter braking controllers.
 * Example: [_aircraft,"AIR_ATTACK",str _generation,300] call WAIT_fnc_FlightLeaseAcquire;
 */
params [
    ["_aircraft",objNull,[objNull]],
    ["_controller","",[""]],
    ["_token","",[""]],
    ["_priority",0,[0]]
];
if (isNull _aircraft || {!local _aircraft} || {!alive _aircraft} || {_controller == ""} || {_token == ""}) exitWith {false};
private _pilot=currentPilot _aircraft;
if (isNull _pilot || {!alive _pilot} || {isPlayer _pilot} || {!isNull (remoteControlled _pilot)}) exitWith {false};
private _group=group _pilot;
if (isNull _group || {[_group] call WAIT_fnc_CortexZeusHeld} || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
private _lease=_aircraft getVariable ["WAIT_FlightLease",createHashMap];
// Public state may arrive from the previous owner during headless/client migration. Ownership is
// part of the lease identity, so a new local owner adopts immediately instead of being blocked by
// the previous machine's priority until an old callback that can no longer run releases it.
if (count _lease > 0 && {(_lease getOrDefault ["owner",-1]) != clientOwner}) then {_lease=createHashMap};
private _same=count _lease > 0
    && {(_lease getOrDefault ["controller",""]) == _controller}
    && {(_lease getOrDefault ["token",""]) == _token}
    && {(_lease getOrDefault ["owner",-1]) == clientOwner};
if (_same) exitWith {
    true
};
if (count _lease > 0 && {_priority <= (_lease getOrDefault ["priority",0])}) exitWith {false};
private _revision=(_aircraft getVariable ["WAIT_FlightLeaseRevision",0])+1;
_aircraft setVariable ["WAIT_FlightLeaseRevision",_revision];
private _newLease=createHashMapFromArray [
    ["controller",_controller],["token",_token],["priority",_priority],
    ["owner",clientOwner],["revision",_revision],["startedAt",serverTime],["updatedAt",serverTime],
    ["replaced",if (count _lease > 0) then {[_lease getOrDefault ["controller",""],_lease getOrDefault ["token",""]]} else {[]}]
];
_aircraft setVariable ["WAIT_FlightLease",_newLease,true];
true

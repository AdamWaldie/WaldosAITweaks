/*
 * Author: WaldoTheWarfighter
 * Purpose: Releases an exact WAIT aircraft flight lease without clearing a newer controller.
 * Locality / Authority: Aircraft-owner local. Controller and token must match the live lease.
 * Repeat/JIP: Idempotent. A stale release is a no-op; the public diagnostic state records the last valid release.
 * Arguments: 0 aircraft <OBJECT>; 1 controller <STRING>; 2 token <STRING>; 3 reason <STRING>, default RELEASED.
 * Return Value: Boolean - true only when the matching lease was released.
 * Current callers: aircraft attack, helicopter landing, missile defence, braking and Cortex shutdown cleanup.
 * Example: [_aircraft,"DECELERATION",str _generation,"STABLE"] call WAIT_fnc_FlightLeaseRelease;
 */
params [
    ["_aircraft",objNull,[objNull]],["_controller","",[""]],["_token","",[""]],
    ["_reason","RELEASED",[""]]
];
if (isNull _aircraft || {!local _aircraft}) exitWith {false};
private _lease=_aircraft getVariable ["WAIT_FlightLease",createHashMap];
if (count _lease == 0
    || {(_lease getOrDefault ["controller",""]) != _controller}
    || {(_lease getOrDefault ["token",""]) != _token}
    || {(_lease getOrDefault ["owner",-1]) != clientOwner}) exitWith {false};
_aircraft setVariable ["WAIT_FlightLeaseLast",[
    _controller,_token,_lease getOrDefault ["revision",-1],_reason,serverTime
],true];
_aircraft setVariable ["WAIT_FlightLease",nil,true];
true

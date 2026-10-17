/*
 * Author: WaldoTheWarfighter
 * Purpose: Forward a nearby gate observation to server authority under the current driving route.
 * Locality/authority: Current group/vehicle/driver owner only; non-server network calls are refused.
 * Server independently validates every authority, source, transform, lock and geometry condition.
 * Repeat/JIP: One initial request and at most one delivery retry per gate/route context.
 * Public pending context preserves the delivery count/deadline across owner migration;
 * a matching server acknowledgement suppresses later requests. Pending state grants no authority.
 * No JIP command replay or asynchronous callback; native animation state is separate.
 * Ordinary route intent is rechecked before delivery; convoy acquired STOP retains its own contract.
 * Opening receipt is diagnostic only. Existing geometry cap owns approach/wait and never times out
 * into clearance. Server retains a finite per-route attempt budget across owner migration.
 * Arguments: 0 group <GROUP, grpNull>; 1 vehicle <OBJECT, objNull>; 2 observation <ARRAY, []>
 * from DrivingGateCap; 3 convoy revision <NUMBER, -1> (-1 ordinary driving).
 * Return Value: BOOL - request sent, not opening, passability or physical passage confirmation.
 * Current callers: DrivingAssistStart and ConvoyTick after their live command-authority checks.
 * Example: [_group,_vehicle,_gateObservation] call WAIT_fnc_DrivingGateRequest;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],["_observation",[],[[]]],["_revision",-1,[0]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (isNull _group || {isNull _vehicle} || {!local _group} || {!local _vehicle}
    || {isNull driver _vehicle} || {!local driver _vehicle} || {group driver _vehicle != _group}
    || {count _observation != 5} || {isNull (_observation select 1)}
    || {(_observation select 2) < 0} || {(_observation select 2) > 12}
    || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
    || {!simulationEnabled driver _vehicle} || {isObjectHidden driver _vehicle}
    || {abs speed _vehicle > 8} || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
private _route=[_group] call WAIT_fnc_DrivingRouteReceipt;
if (_route isEqualTo [] || {_revision < 0 && {!([_group,_vehicle,_route] call WAIT_fnc_DrivingGateIntent)}}) exitWith {false};
private _gate=_observation select 1;
private _driver=driver _vehicle;
private _commander=effectiveCommander _vehicle;
if (isNull _commander) then {_commander=_driver};
private _transform=[getPosWorld _gate,vectorDir _gate,vectorUp _gate];
private _context=[_group,+_route,_revision,_gate,+_transform];
private _ack=_vehicle getVariable ["WAIT_DrivingGate_Result",[]];
if (count _ack == 7 && {(_ack select 0) == _gate} && {(_ack select 3) == _group}
    && {(_ack select 4) isEqualTo _route} && {(_ack select 5) == _revision}
    && {(_ack select 6) isEqualTo _transform}) exitWith {
    private _reason=_ack select 1;
    if (_reason in ["OPEN_REQUESTED","SHARED_OPENING"] && {serverTime >= (_ack select 2)}) then {_reason="OPEN_WINDOW_EXPIRED"};
    _vehicle setVariable ["WAIT_DrivingGate_RequestState",[_context,_reason,_ack select 2]];
    false
};
private _pending=_vehicle getVariable ["WAIT_DrivingGate_Pending",[]];
private _same=count _pending == 3 && {(_pending select 0) isEqualTo _context};
private _attempts=if (_same) then {_pending select 2} else {0};
if (_same && {serverTime < (_pending select 1)}) exitWith {false};
if (_attempts >= 2) exitWith {
    _vehicle setVariable ["WAIT_DrivingGate_RequestState",[_context,"REQUEST_TIMEOUT",_pending select 1]];
    false
};
// The current seats bind this request too; a queued request cannot borrow a successor driver.
private _payload=[["group",_group],["vehicle",_vehicle],["gate",_gate],["route",_route],
    ["transform",_transform],["driver",_driver],["commander",_commander],
    ["convoyRevision",_revision],["expires",serverTime+5]];
_vehicle setVariable ["WAIT_DrivingGate_Pending",[_context,serverTime+5,_attempts+1],true];
_vehicle setVariable ["WAIT_DrivingGate_RequestState",[_context,"AWAITING_SERVER",serverTime+5]];
if (isServer) then {[_payload] call WAIT_fnc_DrivingGateOpenServer}
else {[_payload] remoteExecCall ["WAIT_fnc_DrivingGateOpenServer",2]};
true

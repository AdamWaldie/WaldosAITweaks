/*
 * Author: WaldoTheWarfighter
 * Finds one living group member that can pass a report or support request, preferring the leader while
 * allowing an observing wingman to maintain communication when the leader is unavailable or jammed.
 * Locality/authority: read-only; callable on any machine. The bounded twelve-member scan performs no
 * reveal, target sharing, movement, inventory mutation or network call.
 * Repeat/JIP: recomputes current eligibility on every call and publishes no state.
 * Arguments: 0: group <GROUP>.
 * Return Value: communicating member <OBJECT>, objNull when no eligible member can transmit.
 * Current callers: support, reinforcement, artillery, report and combined-arms coordination.
 * Example: private _radio = [group _unit] call WAIT_fnc_CortexGroupTransmitter;
 */
params [["_group", grpNull, [grpNull]]];
if (isNull _group) exitWith {objNull};
private _members = (units _group) select {alive _x && {!isPlayer _x} && {lifeState _x != "INCAPACITATED"}};
if (_members isEqualTo []) exitWith {objNull};
private _leader = leader _group;
if (_leader in _members) then {
    _members = [_leader] + (_members - [_leader]);
};
private _transmitter = objNull;
{
    if ([_x] call WAIT_fnc_CortexCanTransmit) exitWith {_transmitter = _x};
} forEach (_members select [0, 12]);
_transmitter

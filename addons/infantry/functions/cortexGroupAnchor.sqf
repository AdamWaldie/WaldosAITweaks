/*
 * Author: WaldoTheWarfighter
 * Purpose: Finds one combat-effective, owner-local actor for finite local lifecycle work when a
 * group leader is killed, incapacitated or under player control. Unlike a transmitter, this helper
 * does not require a radio and must not be used to authorise communication or support requests.
 * Locality/authority: Read-only; returns only an actor local to the calling machine. The bounded
 * twelve-member scan performs no target, movement, inventory or network mutation.
 * Repeat/JIP: Recomputes from current group membership. A new owner obtains its own local anchor.
 * Arguments: 0: group <GROUP>.
 * Return Value: local combat-effective actor <OBJECT>, objNull when none is available.
 * Current callers: danger and common operation lifecycle cleanup/start paths.
 * Example: private _actor = [group player] call WAIT_fnc_CortexGroupAnchor;
 */

params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {objNull};
private _members=(units _group) select {
    local _x && {!isPlayer _x} && {[_x] call WAIT_fnc_CortexCombatEffective}
};
if (_members isEqualTo []) exitWith {objNull};
private _leader=leader _group;
if (_leader in _members) then {_members=[_leader]+(_members-[_leader])};
_members param [0,objNull]

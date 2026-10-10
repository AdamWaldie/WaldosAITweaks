/*
 * Author: WaldoTheWarfighter
 * Purpose: Finds one combat-effective, owner-local actor for finite local lifecycle work when a
 * group leader is killed, incapacitated, player-controlled or specialist-owned. Unlike a transmitter, this helper
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
private _eligible={
    params ["_actor"];
    !isNull _actor && {local _actor} && {!isPlayer _actor}
        && {isNull remoteControlled _actor}
        && {[_actor] call WAIT_fnc_CortexCombatEffective}
        && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}
        && {([_actor] call WAIT_fnc_CortexExternalOwner) == ""}
};
private _leader=leader _group;
if ([_leader] call _eligible) exitWith {_leader};
private _members=(units _group) select [0,12];
private _index=_members findIf {[_x] call _eligible};
if (_index < 0) exitWith {objNull};
_members select _index

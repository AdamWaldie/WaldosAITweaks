/*
 * Author: WaldoTheWarfighter
 * Purpose: Reports whether a group is currently under player, direct curator remote, specialist or explicitly
 * declared external control. Cleanup uses this narrow question instead of broad eligibility so a
 * WAIT feature shutdown can restore its own holds without writing into another controller's order.
 * Locality / Authority: Read-only and callable on any machine; callers still issue commands only
 * on the current group owner.
 * Repeat/JIP: Re-evaluates live ownership markers on every call and changes no public state.
 * Arguments:
 * 0: group <GROUP>, default grpNull.
 * 1: ignore temporary Zeus hold <BOOL>, default false. Direct remote control and all other
 *    external ownership still take priority when true.
 * 2: actor-local context <OBJECT>, objNull. A valid member narrows specialist checks to that actor;
 * player, curator and explicit group ownership remain group-wide. Group command callers omit it.
 * Return Value: Boolean - true when WAIT must not restore formation, posture or combat state.
 * Current callers: explicit-order, regroup, convoy, support and delegated-building cleanup.
 * Example: if ([group soldier1] call WAIT_fnc_CortexExternalTakeover) exitWith {};
 * Result: a cleanup routine removes its own state without replacing a curator's order.
 */

params [["_group",grpNull,[grpNull]], ["_ignoreZeusHold",false,[true]], ["_actorContext",objNull,[objNull]]];
if (isNull _group) exitWith {true};
// This is called immediately before every WAIT command boundary. Cache the membership once and
// evaluate specialist ownership once per actor; the leader is a group member, so a separate
// leader probe only duplicated configuration and marker reads on the most frequent path.
private _members=units _group;
if (!isNull _actorContext && {group _actorContext != _group}) exitWith {true};
private _specialistSubjects=if (isNull _actorContext) then {_members} else {[_actorContext]};

(_members findIf {isPlayer _x} >= 0)
|| {!_ignoreZeusHold && {[_group] call WAIT_fnc_CortexZeusHeld}}
|| {_members findIf {!isNull (remoteControlled _x)} >= 0}
|| {_members findIf {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])} >= 0}
|| {_specialistSubjects findIf {[_x] call WAIT_fnc_CortexExternalOwner != ""} >= 0}
|| {[_group] call WAIT_fnc_CompatibilityExternalControl}

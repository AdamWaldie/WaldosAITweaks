/*
 * Author: WaldoTheWarfighter
 * Purpose: Reports whether a group is currently under player, direct curator remote, specialist or explicitly
 * declared external control. Cleanup uses this narrow question instead of broad eligibility so a
 * WAIT feature shutdown can restore its own holds without writing into another controller's order.
 * Locality / Authority: Read-only and callable on any machine; callers still issue commands only
 * on the current group owner.
 * Repeat/JIP: Re-evaluates live ownership markers on every call and changes no public state.
 * Arguments: 0: group <GROUP>, default grpNull.
 * Return Value: Boolean - true when WAIT must not restore formation, posture or combat state.
 * Current callers: explicit-order, regroup, convoy, support and delegated-building cleanup.
 * Example: if ([group soldier1] call WAIT_fnc_CortexExternalTakeover) exitWith {};
 * Result: a cleanup routine removes its own state without replacing a curator's order.
 */

params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {true};

isPlayer leader _group
|| {(units _group) findIf {isPlayer _x} >= 0}
|| {[_group] call WAIT_fnc_CortexZeusHeld}
|| {(units _group) findIf {!isNull (remoteControlled _x)} >= 0}
|| {(units _group) findIf {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])} >= 0}
|| {([leader _group] call WAIT_fnc_CortexExternalOwner) != ""}
|| {(units _group) findIf {[_x] call WAIT_fnc_CortexExternalOwner != ""} >= 0}
|| {[_group] call WAIT_fnc_CompatibilityExternalControl}

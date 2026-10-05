/*
 * Author: WaldoTheWarfighter
 * Purpose: Classifies a coalesced danger observation for the native AI and WAIT diagnostics without
 * creating a second target, route, firing or movement owner.
 * Locality/authority: Runs on the current group owner after WAIT_fnc_DangerSelect has already bounded
 * and validated an observation. It reads only the leader vehicle state and an existing operation.
 * Repeat/JIP: Pure selection with no side effects. The caller publishes the finite result with its
 * generation, so a new owner reconstructs it from a fresh local observation.
 * Arguments: 0: group <GROUP>; 1: selected event <ARRAY> [cause, position, observedAt, expires].
 * Return Value: STRING - RELEASE, MAINTAIN, VEHICLE, HIDE or ENGAGE.
 * Current callers: WAIT_fnc_DangerStep.
 * Example: [group player,["SUPPRESSED",getPosATL player,time,time + 2]] call WAIT_fnc_DangerActionSelect;
 */

params [["_group",grpNull,[grpNull]], ["_event",[],[[]]]];
if (isNull _group || {!local _group} || {count _event != 4}) exitWith {"RELEASE"};
if ([_group] call WAIT_fnc_CortexZeusHeld
    || {[leader _group] call WAIT_fnc_CortexExternalOwner != ""}
    || {[_group] call WAIT_fnc_CompatibilityExternalControl}) exitWith {"RELEASE"};
// A current operation has already committed a physical route and owns its restoration. A danger
// event raises its priority but must not send the group back to an earlier reaction position.
if (count (_group getVariable ["WAIT_Operation",createHashMap]) > 0) exitWith {"MAINTAIN"};
private _leader=leader _group;
if (isNull _leader || {!alive _leader}) exitWith {"RELEASE"};
if (vehicle _leader != _leader) exitWith {"VEHICLE"};
private _cause=_event select 0;
if (_cause in ["HIT","EXPLOSION","SUPPRESSED"]) exitWith {"HIDE"};
"ENGAGE"

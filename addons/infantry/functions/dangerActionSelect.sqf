/*
 * Author: WaldoTheWarfighter
 * Purpose: Classifies a coalesced danger observation for the native AI and WAIT diagnostics without
 * creating a second target, route, firing or movement owner.
 * Locality/authority: Runs on the current group owner after WAIT_fnc_DangerSelect has already bounded
 * and validated an observation. It reads one bounded living group representative and an existing operation.
 * Repeat/JIP: Pure selection with no side effects. The caller publishes the finite result with its
 * generation, so a new owner reconstructs it from a fresh local observation.
 * Arguments: 0: group <GROUP>; 1: selected event <ARRAY> [cause, position, observedAt, expires].
 * Return Value: STRING - RELEASE, FORCED, MAINTAIN, VEHICLE, HIDE or ENGAGE.
 * Current callers: WAIT_fnc_DangerStep, WAIT_fnc_OperationCancel and WAIT_fnc_OperationRelease.
 * Example: [group player,["SUPPRESSED",getPosATL player,time,time + 2]] call WAIT_fnc_DangerActionSelect;
 */

params [["_group",grpNull,[grpNull]], ["_event",[],[[]]]];
if (isNull _group || {!local _group} || {count _event != 4}) exitWith {"RELEASE"};
// This is intentionally the same handover boundary used by the danger FSM, operation cleanup and
// vehicle helpers. Keeping local copies here allowed a newly-recognised owner (for example a player
// in the group) to receive a reaction after the other danger paths had already yielded.
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {"RELEASE"};
private _actor=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _actor) then {_actor=leader _group};
if (isNull _actor || {!alive _actor}) exitWith {"RELEASE"};
// A native forced command remains authoritative through the group handoff as well as the immediate
// engine branch. Without this second check, the queued assessment could change group posture after
// the unit-level FSM had deliberately yielded to ATTACK, boarding, healing or another forced task.
if (fleeing _actor || {currentCommand _actor in ["ATTACK","GET IN","ACTION","HEAL","REARM","JOIN"]}) exitWith {"FORCED"};
if (!isNull objectParent _actor) exitWith {"VEHICLE"};
// A current operation has already committed a physical route and owns its restoration. A danger
// event raises its priority but must not send the group back to an earlier reaction position.
if (count (_group getVariable ["WAIT_Operation",createHashMap]) > 0) exitWith {"MAINTAIN"};
private _cause=_event select 0;
if (_cause in ["HIT","EXPLOSION","SUPPRESSED","SCREAM","CASUALTY"]) exitWith {"HIDE"};
"ENGAGE"

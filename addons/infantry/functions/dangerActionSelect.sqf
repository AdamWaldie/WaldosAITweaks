/*
 * Author: WaldoTheWarfighter
 * Purpose: Classifies a coalesced danger observation for the native AI and WAIT diagnostics without
 * creating a second target, route, firing or movement owner.
 * Locality/authority: Runs on the current group owner after WAIT_fnc_DangerSelect has already bounded
 * and validated an observation. It reads one bounded living group representative and an existing operation.
 * Repeat/JIP: Pure selection with no side effects. The caller publishes the finite result with its
 * generation, so a new owner reconstructs it from a fresh local observation.
 * Arguments: 0: group <GROUP>; 1: selected event <ARRAY>
 * [cause, position, observedAt, expires, optional hostile source, optional response observer,
 * optional source observer].
 * Return Value: STRING - RELEASE, FORCED, MAINTAIN, VEHICLE, HIDE or ENGAGE.
 * Current callers: WAIT_fnc_DangerStep, WAIT_fnc_OperationCancel and WAIT_fnc_OperationRelease.
 * Example: [group player,["SUPPRESSED",getPosATL player,time,time + 2]] call WAIT_fnc_DangerActionSelect;
 */

params [["_group",grpNull,[grpNull]], ["_event",[],[[]]]];
if (isNull _group || {!local _group} || {!(count _event in [4,5,6,7])}) exitWith {"RELEASE"};
// This is intentionally the same handover boundary used by the danger FSM, operation cleanup and
// vehicle helpers. Keeping local copies here allowed a newly-recognised owner (for example a player
// in the group) to receive a reaction after the other danger paths had already yielded.
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {"RELEASE"};
private _actor=_event param [5,objNull,[objNull]];
// An explicit witness carries response-domain ownership. Its loss cannot be repaired by
// substituting a foot leader for a crew member or an unrelated surviving soldier.
if (count _event >= 6 && {!([_actor] call WAIT_fnc_CortexCombatEffective)
    || {!local _actor} || {group _actor != _group}}) exitWith {"RELEASE"};
// Only older position-only callers intentionally use the current group representative.
if (count _event < 6) then {
    _actor=[_group] call WAIT_fnc_CortexGroupAnchor;
    if (isNull _actor) then {_actor=leader _group};
};
if (!([_actor] call WAIT_fnc_CortexCombatEffective) || {!local _actor} || {isPlayer _actor}
    || {group _actor != _group}
    || {[_actor] call WAIT_fnc_CompatibilityExternalControl}) exitWith {"RELEASE"};
// A concrete native task remains authoritative through the group handoff as well as the immediate
// engine branch. ATTACK is deliberately absent: Arma also assigns it during ordinary autonomous
// combat, and WAIT's response changes only a finite posture while native targeting and movement stay
// authoritative. Zeus, players and declared external owners have already yielded above.
if (fleeing _actor || {currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}) exitWith {"FORCED"};
if (!isNull objectParent _actor) exitWith {"VEHICLE"};
private _cause=_event select 0;
// Detection, proximity, a firing opportunity and audible fire require the native-known hostile
// retained in the event before they can become an engagement. Resolve this before MAINTAIN: an
// approximate observation during an existing operation may preserve that route, but it cannot gain
// CONTACT authority merely because WAIT already owns movement.
private _source=_event param [4,objNull,[objNull]];
// A retained identity is not permanent hostility. Zeus/mission side changes and surrender
// invalidate engagement authority even while native knowledge still remembers that object.
if (_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"] && {!isNull _source}
    && {!alive _source || {captive _source} || {(side _group) getFriend (side _source) >= 0.6}}) exitWith {"RELEASE"};
if (_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"]
    && {isNull (_event param [4,objNull,[objNull]])}) exitWith {"HIDE"};
// A current operation has already committed a physical route and owns its restoration. A danger
// event raises its priority but must not send the group back to an earlier reaction position.
if (count (_group getVariable ["WAIT_Operation",createHashMap]) > 0) exitWith {"MAINTAIN"};
if (_cause in ["HIT","EXPLOSION","SUPPRESSED","SCREAM","CASUALTY","BODY_FOUND"]) exitWith {"HIDE"};
"ENGAGE"

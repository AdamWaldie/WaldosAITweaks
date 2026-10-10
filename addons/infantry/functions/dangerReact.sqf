/*
 * Author: WaldoTheWarfighter
 * Purpose: Applies a short, local danger posture selected by the danger FSM without replacing an active WAIT or external movement operation.
 * Locality/authority: Runs where the observed actor and its group are local. It changes only group behaviour and combat mode that it records as owned. Explicit BLUE/GREEN hold-fire discipline remains authoritative.
 * Repeat/JIP: One public lease contains prior/applied values, operation generation, locality epoch and owner. Repeated events extend the lease; restore changes only values still matching WAIT's application and discards its lease on external takeover. DangerStep owns the finite response context.
 * Arguments: 0 actor <OBJECT>; 1 cause <STRING, RESTORE or RELEASE>; 2 approximate danger position <ARRAY, []>; 3 classified action <STRING, "">.
 * Return Value: STRING - RESTORED, ASSESS, POSTURE or IGNORED.
 * Current callers: DangerStep and CortexGroupTick cleanup.
 * Example: [leader group player,"SUPPRESSED",getPosATL player,"HIDE"] call WAIT_fnc_DangerReact;
 */
params [["_actor",objNull,[objNull]],["_cause","RESTORE",[""]],["_position",[],[[]]],["_action","",[""]]];
if (isNull _actor || {!local _actor} || {!alive _actor}) exitWith {"IGNORED"};
private _group=group _actor;
if (isNull _group || {!local _group}) exitWith {"IGNORED"};
private _lease=_group getVariable ["WAIT_Danger_ReactionLease",[]];
private _generation=_group getVariable ["WAIT_OperationGeneration",0];
private _epoch=_group getVariable ["WAIT_AIPass_Epoch",0];
private _leaseOwned=count _lease == 8
    && {(_lease select 5) == _generation}
    && {(_lease select 6) == _epoch}
    && {(_lease select 7) == clientOwner};
// Use the same local surviving actor used by danger setup and cleanup when comparing WAIT's
// temporary posture. A leader casualty or reassignment must not make an intact WAIT lease look
// externally changed, or restore a stale posture over the new leader.
private _postureActor=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _postureActor) then {_postureActor=leader _group};
// Use the shared takeover decision used by every operation cleanup. A partial copy here previously
// missed player-controlled members and could restore a short WAIT posture over a newer controller.
private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;
if (_cause in ["RESTORE","RELEASE"]) exitWith {
    // Never restore a WAIT posture over a curator, player or specialist controller. The old lease
    // has no authority after that handover, so discard it instead of guessing what to restore.
    if (_yieldToOwner || {count _lease > 0 && {!_leaseOwned}}) exitWith {
        _group setVariable ["WAIT_Danger_ReactionLease",nil,true];
        "YIELDED"
    };
    // RESTORE waits for the finite response lease to expire. RELEASE is used by a Zeus/new-order,
    // disable or locality handover and must relinquish only the values this response still owns
    // immediately; otherwise the old COMBAT/ROE posture can outlive the controller that set it.
    if (_leaseOwned && {_cause == "RELEASE" || {time >= (_lease select 4)}}) then {
        _lease params ["_behaviour","_ownedBehaviour","_combatMode","_ownedCombatMode"];
        if (behaviour _postureActor == _ownedBehaviour) then {_group setBehaviour _behaviour};
        if (combatMode _group == _ownedCombatMode) then {_group setCombatMode _combatMode};
        _group setVariable ["WAIT_Danger_ReactionLease",nil,true];
        "RESTORED"
    } else {"ASSESS"}
};
if !(_cause in ["HIT","EXPLOSION","SUPPRESSED","DETECTED","PROXIMITY","CANFIRE","GUNFIRE","CASUALTY","BODY_FOUND","SCREAM"]) exitWith {"IGNORED"};
if (_yieldToOwner) exitWith {"IGNORED"};
// The immediate FSM response is deliberately posture-only. Movement, target assignment and route
// ownership stay with native AI or the already-running WAIT operation. This makes the classifier
// useful without creating a second combat controller.
if (_action == "RELEASE") exitWith {"IGNORED"};
// Vehicle crews and actors executing a native forced command are observation-only here. Their
// dedicated vehicle/native owner receives the group-brain wake, but WAIT does not alter behaviour,
// ROE, posture or movement while that owner is active.
if (_action in ["FORCED","VEHICLE"]) exitWith {"ASSESS"};
// Casualty and scream causes do not identify a hostile. The per-soldier engine FSM may still use a
// short weak stance, while the group layer preserves its current behaviour and ROE. Morale and
// survivor-role logic consume actual losses independently on their normal bounded group step.
if (_cause in ["CASUALTY","BODY_FOUND","SCREAM"]) exitWith {"ASSESS"};
// BLUE and GREEN are deliberate fire-control orders rather than passive defaults. Preserve them
// exactly: the actor-local engine FSM may still take a finite weak stance, but a danger callback
// cannot silently authorise fire or launch group tactics against the mission maker's order.
if (combatMode _group in ["BLUE","GREEN"]) exitWith {"ASSESS"};
if !(_action in ["HIDE","ENGAGE","MAINTAIN",""]) then {_action=""};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
// MAINTAIN is valid only while a real operation still owns the committed route. A delayed danger
// callback can outlive operation cleanup, so reclassify that orphaned label instead of treating it
// as evidence of movement ownership.
if (_action == "MAINTAIN" && {count _operation == 0}) then {
    _action=["ENGAGE","HIDE"] select (_cause in ["HIT","EXPLOSION","SUPPRESSED","CASUALTY","BODY_FOUND","SCREAM"]);
};
// Expiry permits cleanup; it does not prove cleanup has run. A late renewing event must
// preserve the original baseline while the exact owned values still remain applied.
private _behaviourIntact=_leaseOwned && {behaviour _postureActor == (_lease select 1)};
private _combatIntact=_leaseOwned && {combatMode _group == (_lease select 3)};
private _leaseIntact=_leaseOwned && {_behaviourIntact} && {_combatIntact};
private _priorBehaviour=if (_behaviourIntact) then {_lease select 0} else {behaviour _postureActor};
private _priorCombat=if (_combatIntact) then {_lease select 2} else {combatMode _group};
private _appliedBehaviour=if (_behaviourIntact) then {_lease select 1} else {_priorBehaviour};
private _appliedCombat=if (_combatIntact) then {_lease select 3} else {_priorCombat};
// CARELESS is an explicit mission-maker instruction. A danger observation alone must not
// silently turn it into a WAIT combat task.
if (_priorBehaviour in ["SAFE","AWARE"]) then {
    if (behaviour _postureActor != "COMBAT") then {_group setBehaviour "COMBAT"};
    _appliedBehaviour="COMBAT";
};
// MAINTAIN means keep the committed route, not ignore the threat. A manoeuvring element may adopt
// the same short combat posture as an idle element without receiving a destination, target or
// firing command. This closes the gap where an active advance/flank/CQB operation suppressed its
// own danger response merely because it already owned movement.
private _engaging=_action == "ENGAGE" || {_action == "MAINTAIN" && {_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"]}};
// Suppression renews the finite response without withdrawing an already-authorised engagement.
// Exact ownership is required; an external mode change and BLUE/GREEN orders remain authoritative.
private _keepEngagement=_combatIntact && {_appliedCombat == "RED"};
private _desiredCombat=if (_engaging || {_keepEngagement}) then {"RED"} else {"YELLOW"};
// A committed tactical drill owns its YELLOW discipline. Danger response may retain
// posture but cannot turn that exact lease into RED and falsely trigger ROE_CHANGED.
private _tacticalState=_group getVariable ["WAIT_AIPass_State",createHashMap];
private _tacticalDrill=_tacticalState getOrDefault ["drill",createHashMap];
private _tacticalMode=_tacticalDrill getOrDefault ["groupCombatMode",[]];
private _tacticalModeOwned=count _operation > 0 && {count _tacticalMode == 2}
    && {(_operation getOrDefault ["generation",-2]) == _generation}
    && {(_operation getOrDefault ["ownerEpoch",-1]) == _epoch}
    && {(_tacticalDrill getOrDefault ["operationGeneration",-1]) == _generation}
    && {(_tacticalDrill getOrDefault ["stage",""]) in ["START","MOVE","PAUSE","HOLD"]}
    && {combatMode _group == (_tacticalMode select 1)};
if (!_tacticalModeOwned && {_priorCombat == "WHITE" || {_engaging && {_priorCombat == "YELLOW"}}}) then {
    if (combatMode _group != _desiredCombat) then {_group setCombatMode _desiredCombat};
    _appliedCombat=_desiredCombat;
};
private _responseDurations=createHashMapFromArray [["HIT",3],["EXPLOSION",2.5],["SUPPRESSED",2],["CASUALTY",2],["BODY_FOUND",1.5],["SCREAM",1.5],["PROXIMITY",1.5],["CANFIRE",1.5],["DETECTED",1.5],["GUNFIRE",1]];
private _until=(time + (_responseDurations getOrDefault [_cause,1])) max (if (_leaseIntact) then {_lease select 4} else {-1});
_group setVariable ["WAIT_Danger_ReactionLease",[_priorBehaviour,_appliedBehaviour,_priorCombat,_appliedCombat,_until,_generation,_epoch,clientOwner],true];
"POSTURE"

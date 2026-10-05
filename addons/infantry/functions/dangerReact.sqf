/*
 * Author: WaldoTheWarfighter
 * Purpose: Applies a short, local danger posture selected by the danger FSM without replacing an active WAIT or external movement operation.
 * Locality/authority: Runs where the observed actor and its group are local. It changes only group behaviour and combat mode that it records as owned.
 * Repeat/JIP: One public lease contains the prior and applied values. Repeated events extend the lease; restore changes only values still matching WAIT's application and discards its lease on external takeover. DangerStep owns the finite response context.
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
private _yieldToOwner=[_group] call WAIT_fnc_CortexZeusHeld
    || {[_actor] call WAIT_fnc_CortexExternalOwner != ""}
    || {[_group] call WAIT_fnc_CompatibilityExternalControl};
if (_cause in ["RESTORE","RELEASE"]) exitWith {
    // Never restore a WAIT posture over a curator, player or specialist controller. The old lease
    // has no authority after that handover, so discard it instead of guessing what to restore.
    if (_yieldToOwner) exitWith {
        _group setVariable ["WAIT_Danger_ReactionLease",nil,true];
        "YIELDED"
    };
    // RESTORE waits for the finite response lease to expire. RELEASE is used by a Zeus/new-order,
    // disable or locality handover and must relinquish only the values this response still owns
    // immediately; otherwise the old COMBAT/ROE posture can outlive the controller that set it.
    if (count _lease == 5 && {_cause == "RELEASE" || {time >= (_lease select 4)}}) then {
        _lease params ["_behaviour","_ownedBehaviour","_combatMode","_ownedCombatMode"];
        if (behaviour leader _group == _ownedBehaviour) then {_group setBehaviour _behaviour};
        if (combatMode _group == _ownedCombatMode) then {_group setCombatMode _combatMode};
        _group setVariable ["WAIT_Danger_ReactionLease",nil,true];
        "RESTORED"
    } else {"ASSESS"}
};
if !(_cause in ["HIT","EXPLOSION","SUPPRESSED","DETECTED","GUNFIRE"]) exitWith {"IGNORED"};
if (_yieldToOwner) exitWith {"IGNORED"};
// A manoeuvre already owns the group movement. It receives the event through GroupTick and must
// keep its committed route rather than being sent back to a reaction position.
if (count (_group getVariable ["WAIT_Operation",createHashMap]) > 0) exitWith {
    "ASSESS"
};
// The immediate FSM response is deliberately posture-only. Movement, target assignment and route
// ownership stay with native AI or the already-running WAIT operation. This makes the classifier
// useful without creating a second combat controller.
if (_action == "MAINTAIN") exitWith {"ASSESS"};
if (_action == "RELEASE") exitWith {"IGNORED"};
if !(_action in ["HIDE","ENGAGE","VEHICLE",""]) then {_action=""};
private _leaseIntact=count _lease == 5 && {time < (_lease select 4)}
    && {behaviour leader _group == (_lease select 1)} && {combatMode _group == (_lease select 3)};
private _priorBehaviour=if (_leaseIntact) then {_lease select 0} else {behaviour leader _group};
private _priorCombat=if (_leaseIntact) then {_lease select 2} else {combatMode _group};
private _appliedBehaviour=if (_leaseIntact) then {_lease select 1} else {_priorBehaviour};
private _appliedCombat=if (_leaseIntact) then {_lease select 3} else {_priorCombat};
// CARELESS is an explicit mission-maker instruction. A danger observation alone must not
// silently turn it into a WAIT combat task.
if (_priorBehaviour in ["SAFE","AWARE"]) then {
    _group setBehaviour "COMBAT";
    _appliedBehaviour="COMBAT";
};
private _desiredCombat=if (_action == "ENGAGE") then {"RED"} else {"YELLOW"};
if (_priorCombat == "BLUE" || {_action == "ENGAGE" && {_priorCombat != "RED"}}) then {
    _group setCombatMode _desiredCombat;
    _appliedCombat=_desiredCombat;
};
private _responseDurations=createHashMapFromArray [["HIT",3],["EXPLOSION",2.5],["SUPPRESSED",2],["DETECTED",1.5],["GUNFIRE",1]];
private _until=(time + (_responseDurations getOrDefault [_cause,1])) max (_lease param [4,-1]);
_group setVariable ["WAIT_Danger_ReactionLease",[_priorBehaviour,_appliedBehaviour,_priorCombat,_appliedCombat,_until],true];
"POSTURE"

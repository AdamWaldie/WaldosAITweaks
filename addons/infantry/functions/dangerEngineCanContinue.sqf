/*
 * Author: WaldoTheWarfighter
 * Purpose: Cheaply decide whether a running finite engine danger response still belongs to WAIT.
 * This gate intentionally avoids squad scans, terrain work and config inspection because the engine
 * may evaluate it repeatedly during the response's sub-two-second observation window.
 * Locality / Authority: Runs where the affected AI soldier is local and reads only live gates and
 * explicit actor/group ownership markers. It issues no command and changes no state.
 * Repeat/JIP: Stateless and repeat-safe. A new locality starts a fresh engine danger FSM.
 * Arguments: 0: affected soldier <OBJECT>, objNull; 1: initial observation <BOOL>, false.
 * Initial observation permits native task classification only; waiting responses still yield immediately.
 * Return Value: Boolean - true while the current short WAIT response may continue.
 * Current callers: Engine-loaded infantry danger FSM Waiting state.
 * Example: if !([cursorObject] call WAIT_fnc_DangerEngineCanContinue) exitWith {};
 */

params [["_actor",objNull,[objNull]],["_initial",false,[true]]];
if (isNull _actor || {!local _actor} || {!([_actor] call WAIT_fnc_CortexCombatEffective)}
    || {isPlayer _actor}) exitWith {false};
private _group=group _actor;
if (isNull _group || {!local _group}
    || {!(missionNamespace getVariable ["WAIT_AIPass_Active",false])}
    || {!(missionNamespace getVariable ["WAIT_AIPass_Danger_Enable",true])}
    || {[] call WAIT_fnc_CortexIsPaused}) exitWith {false};

private _disabled=_group getVariable ["WAIT_AIPass_DisabledFeatures",[]];
if ("ALL" in _disabled || {"WAIT_AIPass_Danger_Enable" in _disabled}
    || {_group getVariable ["WAIT_AI_Exclude",false]}
    || {_group getVariable ["WAIT_AIPass_Exclude",false]}
    || {_actor getVariable ["WAIT_AI_Exclude",false]}
    || {_actor getVariable ["WAIT_AIPass_Exclude",false]}
    || {[_actor] call WAIT_fnc_CompatibilityExternalControl}
    || {!isNull (remoteControlled _actor)}
    || {!isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}) exitWith {false};

// Native task ownership can change after the event was classified and while this finite response
// is waiting. Recheck only the affected actor here so a fresh boarding, action, treatment, rearm,
// join or fleeing task interrupts before another WAIT stance or recycle. ATTACK deliberately remains
// eligible because the engine also uses it for ordinary autonomous combat.
if (behaviour _actor == "CARELESS" || {!_initial && {fleeing _actor
    || {toUpperANSI (currentCommand _actor) in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}}}) exitWith {false};

// A carrier reservation can begin after this response was classified. Interrupt that old
// response, but let an already classified FORCED state keep its bounded wait instead of
// rapidly recycling the same event while the assistant walks to the assembly position.
private _carrierTask=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
private _response=_actor getVariable ["WAIT_Danger_EngineResponse",[]];
if (!_initial && {isNull objectParent _actor} && {count _carrierTask == 3}
    && {(_carrierTask select 0) in ["STATIC_DEPLOY","STATIC_PACK","STATIC_SUPPORT"]}
    && {time < (_carrierTask select 2)}
    && {(_response param [0,"",[""]]) != "FORCED"}) exitWith {false};

// The full Zeus helper may inspect waypoints and update a timing cache. The danger FSM only needs
// the cheap interruption edge: a new curator token, a known live hold, or curator-owned waypoints.
private _token=_group getVariable ["WAIT_AIPass_ZeusHold",[]];
private _newToken=_token isNotEqualTo []
    && {(_group getVariable ["WAIT_AIPass_ZeusSeenToken",-1]) != (_token param [0,-1,[0]])};
!_newToken
    && {time >= (_group getVariable ["WAIT_AIPass_ZeusLocalUntil",-1])}
    && {!(_group getVariable ["WAIT_AIPass_ZeusWaypoints",false])}

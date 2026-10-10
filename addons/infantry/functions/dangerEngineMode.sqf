/*
 * Author: WaldoTheWarfighter
 * Purpose: Classify one engine danger record into a finite immediate-response state.
 * Locality / Authority: Runs for the local AI soldier and reads current orders and ownership only.
 * Repeat/JIP: Pure classification. A new owner receives and classifies later engine danger locally.
 * Arguments: 0: soldier <OBJECT>, objNull; 1: selected engine danger record <ARRAY>, [].
 * Return Value: String - RELEASE, FORCED, VEHICLE, IMMEDIATE, HIDE, ENGAGE or ASSESS.
 * Current callers: Engine-loaded infantry danger FSM.
 * Example: [cursorObject,[2,getPosATL cursorObject,time + 1,objNull]] call WAIT_fnc_DangerEngineMode;
 */

params [["_actor",objNull,[objNull]],["_record",[],[[]]]];
if (isNull _actor || {!local _actor} || {!([_actor] call WAIT_fnc_CortexCombatEffective)}
    || {isPlayer _actor} || {[_actor] call WAIT_fnc_CompatibilityExternalControl}
    || {count _record < 3}) exitWith {"RELEASE"};
private _group=group _actor;
if (isNull _group || {!local _group}
    || {!(missionNamespace getVariable ["WAIT_AIPass_Active",false])}
    || {!([_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!([_group,false,true,false,_actor] call WAIT_fnc_CortexIsEligible)}
    || {[] call WAIT_fnc_CortexIsPaused}
    || {behaviour _actor == "CARELESS"}) exitWith {"RELEASE"};
// ATTACK is also the engine's ordinary autonomous combat command. Treating it as authored
// ownership made the danger FSM observation-only for the exact actors already fighting. Zeus,
// players and declared external owners have already yielded above; retain only commands which
// represent a concrete boarding, action, treatment, supply or group-transfer task here.
if (fleeing _actor || {currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN"]}) exitWith {"FORCED"};
// Vehicle response is a domain handoff, not an infantry path request. Classify it before the
// on-foot MOVE gate so an intentionally immobile static gunner, artillery crew or stopped vehicle
// commander still publishes danger to the correct dedicated owner. No movement is issued here.
if (!isNull objectParent _actor) exitWith {"VEHICLE"};
// Only a live carrier reservation yields immediate danger actions. Ordinary ATTACK and squad
// manoeuvre remain combat-enabled; a stale reservation cannot suppress the danger response.
private _carrierTask = _actor getVariable ["WAIT_Cortex_ActorMove",[]];
if (count _carrierTask == 3
    && {(_carrierTask select 0) in ["STATIC_DEPLOY","STATIC_PACK"]}
    && {time < (_carrierTask select 2)}) exitWith {"FORCED"};
if !(_actor checkAIFeature "MOVE") exitWith {"RELEASE"};
private _cause=_record select 0;
if (_cause in [1,2,4,9]) exitWith {"IMMEDIATE"};
if (_cause in [5,6,7]) exitWith {"HIDE"};
// Detection, proximity and firing-opportunity causes are meaningful attack states only when the
// engine supplied a live hostile source. Treating a friendly or missing source as ENGAGE promoted
// ambient/friendly danger into CONTACT and RED combat mode without target knowledge.
if (_cause in [0,3,8]) exitWith {
    private _source=_record param [3,objNull,[objNull]];
    if (!isNull _source && {alive _source} && {(side _group) getFriend (side _source) < 0.6}) then {"ENGAGE"} else {"ASSESS"}
};
"ASSESS"

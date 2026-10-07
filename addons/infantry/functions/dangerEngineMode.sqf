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
if (isNull _actor || {!local _actor} || {!alive _actor} || {isPlayer _actor} || {count _record < 3}) exitWith {"RELEASE"};
private _group=group _actor;
if (isNull _group || {!local _group}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {behaviour _actor == "CARELESS"}
    || {!(_actor checkAIFeature "MOVE")}) exitWith {"RELEASE"};
if (fleeing _actor || {currentCommand _actor in ["ATTACK","GET IN","ACTION","HEAL","REARM","JOIN"]}) exitWith {"FORCED"};
if (!isNull objectParent _actor) exitWith {"VEHICLE"};
private _cause=_record select 0;
if (_cause in [1,2,4,9]) exitWith {"IMMEDIATE"};
if (_cause in [5,6,7]) exitWith {"HIDE"};
// Detection, proximity and firing-opportunity causes are meaningful attack states only when the
// engine supplied a live hostile source. Treating a friendly or missing source as ENGAGE promoted
// ambient/friendly danger into CONTACT and RED combat mode without target knowledge.
if (_cause in [0,3,8]) exitWith {
    private _source=_record param [3,objNull,[objNull]];
    if (!isNull _source && {alive _source} && {(side _group) getFriend (side group _source) < 0.6}) then {"ENGAGE"} else {"ASSESS"}
};
"ASSESS"

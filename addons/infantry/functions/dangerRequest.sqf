/*
 * Author: WaldoTheWarfighter
 * Purpose: Coalesce observed danger into one finite group assessment FSM.
 * Locality / Authority: owner-local; never reveals targets or sends movement commands.
 * Repeat/JIP: generation-checked, machine-local state; new owners rebuild from new observations.
 * Arguments: 0: observer <OBJECT>, objNull; 1: cause <STRING>, GUNFIRE;
 * 2: approximate ATL position <ARRAY>, []; 3: engine-confirmed hostile source <OBJECT>, objNull.
 * Return Value: Boolean - whether the observation was accepted.
 * Current callers: WAIT engine danger intake and the group EnemyDetected observer.
 * Example: [leader _group,"HIT",getPosATL leader _group] call WAIT_fnc_DangerRequest;
 */

params [["_actor",objNull,[objNull]],["_cause","GUNFIRE",[""]],["_position",[],[[]]],["_source",objNull,[objNull]]];
if (isNull _actor || {!local _actor} || {!([_actor] call WAIT_fnc_CortexCombatEffective)} || {isPlayer _actor}
    || {!(_cause in ["HIT","EXPLOSION","SUPPRESSED","DETECTED","PROXIMITY","CANFIRE","GUNFIRE","CASUALTY","BODY_FOUND","SCREAM"])} || {count _position != 3}) exitWith {false};
private _group=group _actor;
if (!(missionNamespace getVariable ["WAIT_AIPass_Active",false])
    || {!local _group}
    || {!([_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!(_group getVariable ["WAIT_AIPass_Managed",false])}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[] call WAIT_fnc_CortexIsPaused}) exitWith {false};
// Eligibility was checked at observer installation and is rechecked before dispatch. Keep bullet
// callbacks cheap; each observer keeps at most the ten accepted causes, with no squad scan.
// One witness must not throttle or replace another witness in a different occupied domain.
private _cadence=_actor getVariable ["WAIT_Danger_EventCadence",createHashMap];
if (time < (_cadence getOrDefault [_cause,-1])) exitWith {false};
_cadence set [_cause,time+0.25];
_actor setVariable ["WAIT_Danger_EventCadence",_cadence];
private _events=_group getVariable ["WAIT_Danger_Events",[]];
private _index=_events findIf {(_x select 0) == _cause && {(_x param [5,objNull,[objNull]]) == _actor}};
// Preserve identity only when the engine supplied a live hostile already known by this observer.
// The group layer revalidates the object against its native knowledge before using it. This is not
// reveal or target assignment; objNull remains the normal value for approximate hazards and reports.
private _hostileSource=objNull;
private _sourceObserver=_actor;
if (!isNull _source && {alive _source} && {!captive _source}
    && {!(_source getVariable ["ace_captives_isSurrendering",false])} && {(side _group) getFriend (side _source) < 0.6}
    && {_actor knowsAbout _source > 0}) then {_hostileSource=_source};
if (isNull _hostileSource && {_index >= 0}) then {
    private _prior=_events select _index;
    private _priorSource=_prior param [4,objNull,[objNull]];
    private _priorObserver=_prior param [6,_prior param [5,objNull,[objNull]],[objNull]];
    if ((_prior param [3,-1,[0]]) > time && {!isNull _priorSource} && {alive _priorSource} && {!captive _priorSource}
        && {!(_priorSource getVariable ["ace_captives_isSurrendering",false])}
        && {[_priorObserver] call WAIT_fnc_CortexCombatEffective} && {local _priorObserver} && {group _priorObserver == _group}
        && {(side _group) getFriend (side _priorSource) < 0.6}
        && {_priorObserver knowsAbout _priorSource > 0}) then {
        _hostileSource=_priorSource;
        _sourceObserver=_priorObserver;
    };
};
// Retain the exact local observer which received the native danger event. A mixed crew/passenger
// or mounted/foot group cannot be classified from an arbitrary group anchor later: doing so turns
// vehicle danger into a foot response (or the reverse) whenever the selected anchor occupies a
// different domain. A separate source observer preserves the native witness when a newer
// approximate event inherits a still-live hostile identity from the previous coalesced record.
private _event=[_cause,+_position,time,time+2,_hostileSource,_actor,_sourceObserver];
if (_index >= 0) then {_events set [_index,_event]} else {_events pushBack _event};
// Retain recent observations at the fixed group limit; a full queue must not permanently
// reject a newly hit witness while its earlier occupants remain in the front slots.
_group setVariable ["WAIT_Danger_Events",_events select [((count _events)-16) max 0,16]];
private _running=_group getVariable ["WAIT_Danger_FSM",[]];
if (count _running == 3 && {(_running select 0) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {(_running select 1) == (_group getVariable ["WAIT_Danger_Generation",0])}
    && {!completedFSM (_running select 2)}) exitWith {true};
private _generation=(_group getVariable ["WAIT_Danger_Generation",0])+1;
_group setVariable ["WAIT_Danger_Generation",_generation];
private _epoch=_group getVariable ["WAIT_AIPass_Epoch",0];
private _fsm=[_group,_epoch,_generation] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\dangerAssessment.fsm";
_group setVariable ["WAIT_Danger_FSM",[_epoch,_generation,_fsm]];
true

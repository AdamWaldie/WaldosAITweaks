/*
 * Author: WaldoTheWarfighter
 * Purpose: Coalesce observed danger into one finite group assessment FSM.
 * Locality / Authority: owner-local; never reveals targets or sends movement commands.
 * Repeat/JIP: generation-checked, machine-local state; new owners rebuild from new observations.
 * Arguments: 0: observer <OBJECT>, objNull; 1: cause <STRING>, GUNFIRE; 2: approximate ATL position <ARRAY>, [].
 * Return Value: Boolean - whether the observation was accepted.
 * Current callers: Owner-local member events installed by WAIT_fnc_DangerSetup.
 * Example: [leader _group,"HIT",getPosATL leader _group] call WAIT_fnc_DangerRequest;
 */

params [["_actor",objNull,[objNull]],["_cause","GUNFIRE",[""]],["_position",[],[[]]]];
if (isNull _actor || {!local _actor} || {!alive _actor} || {isPlayer _actor}
    || {!(_cause in ["HIT","EXPLOSION","SUPPRESSED","DETECTED","GUNFIRE"])} || {count _position != 3}) exitWith {false};
private _group=group _actor;
if (!(missionNamespace getVariable ["WAIT_AIPass_Active",false])
    || {!local _group}
    || {!([_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!(_group getVariable ["WAIT_AIPass_Managed",false])}
    || {[_group] call WAIT_fnc_CortexZeusHeld}
    || {[_actor] call WAIT_fnc_CortexExternalOwner != ""}
    || {[leader _group] call WAIT_fnc_CortexExternalOwner != ""}
    || {[_group] call WAIT_fnc_CompatibilityExternalControl}
    || {[] call WAIT_fnc_CortexIsPaused}) exitWith {false};
// Eligibility was checked at observer installation and is rechecked before dispatch. Keep bullet
// callbacks cheap; repeated events of one cause cannot scan the squad or start extra FSMs.
private _cadence=_group getVariable ["WAIT_Danger_EventCadence",createHashMap];
if (time < (_cadence getOrDefault [_cause,-1])) exitWith {false};
_cadence set [_cause,time+0.25];
_group setVariable ["WAIT_Danger_EventCadence",_cadence];
private _events=_group getVariable ["WAIT_Danger_Events",[]];
private _index=_events findIf {(_x select 0) == _cause};
private _event=[_cause,+_position,time,time+2];
if (_index >= 0) then {_events set [_index,_event]} else {_events pushBack _event};
_group setVariable ["WAIT_Danger_Events",_events select [0,16]];
private _running=_group getVariable ["WAIT_Danger_FSM",[]];
if (count _running == 3 && {(_running select 0) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {!completedFSM (_running select 2)}) exitWith {true};
private _generation=(_group getVariable ["WAIT_Danger_Generation",0])+1;
_group setVariable ["WAIT_Danger_Generation",_generation];
private _epoch=_group getVariable ["WAIT_AIPass_Epoch",0];
private _fsm=[_group,_epoch,_generation] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\dangerAssessment.fsm";
_group setVariable ["WAIT_Danger_FSM",[_epoch,_generation,_fsm]];
true

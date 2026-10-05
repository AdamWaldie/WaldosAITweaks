/*
 * Author: WaldoTheWarfighter
 * Exercises real queued squad movement and completion fairness under the minimum scheduler budget.
 * Locality/authority: scheduled server fixture; production scheduler runs owner-local movement jobs.
 * Repeat/JIP: fresh actors, public destinations; caller restores settings, fixture jobs retire on deletion.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>; required audit callbacks.
 * Return: Nothing. Current caller: cortexQAServer.sqf.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAScheduler.sqf";
 */
params ["_check","_phase","_wait"];
[createHashMapFromArray [["WAIT_AIPass_Enable",true]]] call WAIT_fnc_CortexTuning;
private _saved = createHashMapFromArray [
    ["WAIT_AIPass_TickBudgetMs", missionNamespace getVariable ["WAIT_AIPass_TickBudgetMs",1]],
    ["WAIT_AIRebalance_Enable", missionNamespace getVariable ["WAIT_AIRebalance_Enable",true]],
    ["WAIT_AIRebalance_Mode", missionNamespace getVariable ["WAIT_AIRebalance_Mode","AUTO"]],
    ["WAIT_AIRebalance_Profile", missionNamespace getVariable ["WAIT_AIRebalance_Profile","LINE"]]
];
[createHashMapFromArray [["WAIT_AIPass_TickBudgetMs",0.2]]] call WAIT_fnc_CortexTuning;
private _groups=[];
private _actors=[];
private _states=[];
for "_i" from 0 to 11 do {
    private _group=createGroup [east,true];
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setVariable ["WAIT_AIPass_Exclude",true,true];
    private _unit=_group createUnit ["O_Soldier_F",[1800+_i*12,1700,0],[],0,"NONE"];
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["QUEUED SQUAD %1",_i+1],true];
    private _target=[1800+_i*12,1780,0];
    _unit setVariable ["WAIT_CortexQA_Target",_target,true];
    _group setCombatMode "BLUE";
    _group setBehaviourStrong "CARELESS";
    _groups pushBack _group; _actors pushBack _unit;
    _states pushBack createHashMapFromArray [["group",_group],["unit",_unit],["target",_target],["submitted",diag_tickTime],["first",-1],["complete",0]];
};
missionNamespace setVariable ["WAIT_CortexQA_Actors",_actors,true];
["Scheduler: twelve physical movements","Twelve independent squads must walk 80 m to their markers. The real Cortex queue has its minimum 0.2 ms soft budget. Every job must start within ten seconds and retire once; accepted orders alone do not pass.",[1860,1740,0]] call _phase;
// Exercise independent runtime ownership through real CBA settings before measuring movements.
[createHashMapFromArray [["WAIT_AIRebalance_Enable",true],["WAIT_AIRebalance_Mode","DAY"],["WAIT_AIRebalance_Profile","LINE"]]] call WAIT_fnc_CortexTuning;
private _skillsReady = [{missionNamespace getVariable ["WAIT_AI_RebalanceActive",false]},20] call _wait;
["SCHED-skill-start-prerequisite",_skillsReady] call _check;
private _skillActor = _actors select 0;
private _expectedSpot = _skillActor skill "spotDistance";
[createHashMapFromArray [["WAIT_AIPass_Enable",false]]] call WAIT_fnc_CortexTuning;
private _skillsOnly = [{!(missionNamespace getVariable ["WAIT_AIPass_Active",false]) && {missionNamespace getVariable ["WAIT_AI_RebalanceActive",false]}},20] call _wait;
["Scheduler: skills remain after tactics stop","The labelled soldier must retain skill updates while tactical jobs are disabled. This is a measured skill-layer check, not combat acceptance.",getPosATL _skillActor] call _phase;
_skillActor setVariable ["WAIT_CortexQA_Label","SKILL REFRESH / TACTICS OFF",true];
_skillActor setSkill ["spotDistance",0];
_skillActor setVariable ["WAIT_Cortex_LightingSignature",nil];
private _refreshLimit = (ceil ((count (missionNamespace getVariable ["WAIT_Cortex_LightingUnits",[]])) / 10)) + 10;
private _refreshed = [{abs ((_skillActor skill "spotDistance")-_expectedSpot) < 0.01},_refreshLimit] call _wait;
["SCHED-skills-survive-tactics-stop",_skillsOnly && {_expectedSpot > 0} && {_refreshed},str [_expectedSpot,_skillActor skill "spotDistance"]] call _check;
[createHashMapFromArray [["WAIT_AIRebalance_Enable",false]]] call WAIT_fnc_CortexTuning;
private _allStopped = [{!(missionNamespace getVariable ["WAIT_AI_RebalanceActive",false]) && {isNil {missionNamespace getVariable "WAIT_AIPass_SchedulerHandle"}}},20] call _wait;
["SCHED-last-runtime-releases-callback",_allStopped] call _check;
[createHashMapFromArray [["WAIT_AIPass_Enable",true]]] call WAIT_fnc_CortexTuning;
["Scheduler: tactics without skills","With skill adjustment disabled, twelve real queued squads must still walk to their markers. Every job must start, physically arrive and retire once.",[1860,1740,0]] call _phase;
private _active=[{missionNamespace getVariable ["WAIT_AIPass_Active",false]},20] call _wait;
["SCHED-active-prerequisite",_active] call _check;
{
    _x set ["submitted",diag_tickTime];
    [{
        params ["_state"];
        private _unit=_state get "unit";
        if (!alive _unit) exitWith {-1};
        if ((_state get "first") < 0) then {
            _state set ["first",diag_tickTime];
            _unit doMove (_state get "target");
        };
        if (_unit distance2D (_state get "target") <= 2) exitWith {
            _state set ["complete",(_state get "complete")+1];
            -1
        };
        0.25
    },_x,0] call WAIT_fnc_CortexQueueJob;
} forEach _states;
private _arrived=[{_states findIf {(_x get "complete") != 1} < 0},90] call _wait;
private _delays=_states apply {if ((_x get "first") < 0) then {-1} else {(_x get "first")-(_x get "submitted")}};
["SCHED-no-start-starvation",_delays findIf {_x < 0 || {_x > 10}} < 0,str _delays] call _check;
["SCHED-every-squad-physical-arrival",_arrived && {_states findIf {!alive (_x get "unit") || {(_x get "unit") distance2D (_x get "target") > 2}} < 0},str (_states apply {(_x get "unit") distance2D (_x get "target")})] call _check;
sleep 5;
["SCHED-terminal-jobs-not-repeated",_states findIf {(_x get "complete") != 1} < 0,str (_states apply {_x get "complete"})] call _check;
{deleteVehicle _x} forEach _actors;
{deleteGroup _x} forEach _groups;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
[_saved] call WAIT_fnc_CortexTuning;

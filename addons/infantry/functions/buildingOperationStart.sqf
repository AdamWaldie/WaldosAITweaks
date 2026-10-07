/*
 * Author: WaldoTheWarfighter
 * Purpose: Start the single owner-local building operation FSM for a prepared physical-clearance job.
 * Locality / Authority: Must run where the group is local. It owns semantic building progression but
 * delegates each bounded movement/progress step to WAIT's shared scheduler.
 * Repeat/JIP: Replaces only the current clear generation. Public room evidence remains durable and a
 * new owner reconstructs actor assignments through the ordinary clear-order resume path.
 * Arguments: 0: prepared building job <HASHMAP>.
 * Return Value: Boolean - true when a building brain was started for the current owner.
 * Current caller: WAIT_fnc_CortexClearBuilding.
 * Example: [_job] call WAIT_fnc_BuildingOperationStart;
 */

params [["_job",createHashMap,[createHashMap]]];
private _group=_job getOrDefault ["group",grpNull];
if (isNull _group || {!local _group} || {count _job == 0}) exitWith {false};
private _generation=_job getOrDefault ["generation",-1];
if (_generation < 0 || {_generation != (_group getVariable ["WAIT_AIPass_ClearGeneration",-2])}) exitWith {false};
private _old=_group getVariable ["WAIT_BuildingBrain",createHashMap];
if (count _old > 0) then {
    _old set ["cancelled",true];
    _old set ["cancelReason","REPLACED"];
};
private _epoch=_group getVariable ["WAIT_AIPass_Epoch",0];
private _brain=createHashMapFromArray [
    ["group",_group],
    ["job",_job],
    ["ownerEpoch",_epoch],
    ["generation",_generation],
    ["phase",toUpperANSI (_job getOrDefault ["phase","ENTRY"])],
    ["pending",false],
    ["completed",false],
    ["finished",false],
    ["cancelled",false],
    ["cancelReason",""],
    ["nextAt",time],
    ["lastStepAt",-1],
    ["lastDelay",-1],
    ["queuedAt",-1],
    ["watchdogCount",0]
];
_group setVariable ["WAIT_BuildingBrain",_brain];
_group setVariable ["WAIT_BuildingBrain_State",["ENTRY",_generation,_epoch,serverTime,"STARTED",0,0,count (_job getOrDefault ["positions",[]])],true];
private _handle=[_group,_epoch,_generation,_brain] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\buildingOperation.fsm";
_group setVariable ["WAIT_BuildingBrain_FSM",_handle];
true

/*
 * Author: WaldoTheWarfighter
 * Purpose: Queue one bounded physical building-operation step for the current FSM generation.
 * Locality / Authority: Owner-local. It issues no movement directly and submits one coalesced callback
 * to WAIT's shared scheduler.
 * Repeat/JIP: Pending work is coalesced by group, owner epoch and clear generation.
 * Arguments: 0: group <GROUP>; 1: owner epoch <NUMBER>; 2: generation <NUMBER>;
 * 3: building brain <HASHMAP>; 4: expected phase <STRING>.
 * Return Value: Boolean - true when a current or newly queued step exists.
 * Current caller: WAIT buildingOperation FSM.
 * Example: [_group,2,4,_brain,"SWEEP"] call WAIT_fnc_BuildingOperationQueue;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_epoch",-1,[0]],
    ["_generation",-1,[0]],
    ["_brain",createHashMap,[createHashMap]],
    ["_expectedPhase","ENTRY",[""]]
];
if (isNull _group || {!local _group} || {count _brain == 0}
    || {_epoch != (_group getVariable ["WAIT_AIPass_Epoch",0])}
    || {_generation != (_group getVariable ["WAIT_AIPass_ClearGeneration",-2])}
    || {_brain getOrDefault ["cancelled",false]}
    || {_brain getOrDefault ["finished",false]}) exitWith {false};
if (_brain getOrDefault ["pending",false]) exitWith {true};
_brain set ["pending",true];
_brain set ["completed",false];
_brain set ["expectedPhase",_expectedPhase];
private _key=format ["WAIT_BUILDING_%1_%2_%3",str _group,_epoch,_generation];
[WAIT_fnc_BuildingOperationStep,_brain,0,_key] call WAIT_fnc_CortexQueueJob;
true

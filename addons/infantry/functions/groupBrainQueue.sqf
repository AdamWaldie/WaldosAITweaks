/*
 * Author: WaldoTheWarfighter
 * Purpose: Queue one bounded tactical-brain decision for the current semantic FSM state.
 * Locality / Authority: Owner-local. The function issues no engine command itself; it submits one
 * generation-scoped callback to WAIT's shared scheduler.
 * Repeat/JIP: A pending step is coalesced by group, epoch and generation. Re-entry cannot create a
 * second group decision owner.
 * Arguments:
 * 0: group <GROUP>; 1: owner epoch <NUMBER>; 2: generation <NUMBER>;
 * 3: brain <HASHMAP>; 4: expected semantic phase <STRING>.
 * Return Value: Boolean - true when a current or newly queued step exists.
 * Current caller: WAIT groupTactics FSM.
 * Example: [_group,2,7,_brain,"CONTACT"] call WAIT_fnc_GroupBrainQueue;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_epoch",-1,[0]],
    ["_generation",-1,[0]],
    ["_brain",createHashMap,[createHashMap]],
    ["_expectedPhase","CALM",[""]]
];
if (isNull _group || {!local _group} || {count _brain == 0}
    || {_epoch != (_group getVariable ["WAIT_AIPass_Epoch",0])}
    || {_generation != (_group getVariable ["WAIT_GroupBrain_Generation",0])}
    || {_brain getOrDefault ["cancelled",false]}) exitWith {false};
if (_brain getOrDefault ["pending",false]) exitWith {true};
_brain set ["pending",true];
_brain set ["completed",false];
_brain set ["expectedPhase",_expectedPhase];
_brain set ["queuedAt",time];
private _key=format ["WAIT_GROUP_BRAIN_%1_%2_%3",str _group,_epoch,_generation];
[WAIT_fnc_GroupBrainStep,_brain,0,_key] call WAIT_fnc_CortexQueueJob;
true

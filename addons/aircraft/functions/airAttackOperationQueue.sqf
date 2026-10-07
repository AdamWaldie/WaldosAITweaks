/*
 * Author: WaldoTheWarfighter
 * Purpose: Queues one bounded native aircraft-attack step for the current finite air-operation brain.
 * Locality / Authority: Aircraft-owner local. It issues no flight or weapon command directly and submits one coalesced callback to WAIT's shared scheduler.
 * Repeat/JIP: Aircraft and generation form the coalescing key; stale owners and replaced brains are rejected.
 * Arguments: 0 aircraft <OBJECT>; 1 generation <NUMBER>; 2 brain <HASHMAP>; 3 expected phase <STRING>.
 * Return Value: Boolean - true when a current or newly queued step exists.
 * Current caller: WAIT airAttackOperation FSM.
 * Example: [_aircraft,3,_brain,"INGRESS"] call WAIT_fnc_AirAttackOperationQueue;
 */
params [["_aircraft",objNull,[objNull]],["_generation",-1,[0]],["_brain",createHashMap,[createHashMap]],["_expectedPhase","PLAN",[""]]];
if (isNull _aircraft || {!local _aircraft} || {count _brain == 0}
    || {_generation != (_aircraft getVariable ["WAIT_AirAttack_BrainGeneration",-2])}
    || {(_aircraft getVariable ["WAIT_AirAttack_Brain",createHashMap]) isNotEqualTo _brain}
    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}) exitWith {false};
if (_brain getOrDefault ["pending",false]) exitWith {true};
_brain set ["pending",true];
_brain set ["completed",false];
_brain set ["expectedPhase",_expectedPhase];
_brain set ["queuedAt",time];
private _key=format ["WAIT_AIR_ATTACK_%1_%2",netId _aircraft,_generation];
[WAIT_fnc_AirAttackOperationStep,_brain,0,_key] call WAIT_fnc_CortexQueueJob;
true

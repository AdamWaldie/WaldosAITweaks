/*
 * Author: WaldoTheWarfighter
 * Purpose: Queues one bounded discovery, reservation or coordination step for a finite support request.
 * Locality / Authority: Server only. Responder movement remains owner-local and this function submits no movement command directly.
 * Repeat/JIP: Requester and generation form a coalescing key; stale or replaced brains cannot queue another step.
 * Arguments: 0 requester <GROUP>; 1 generation <NUMBER>; 2 brain <HASHMAP>; 3 expected phase <STRING>.
 * Return Value: Boolean - true when a current or newly queued step exists.
 * Current caller: WAIT supportRequest FSM.
 * Example: [_requester,4,_brain,"RESERVE"] call WAIT_fnc_SupportRequestQueue;
 */
params [["_requester",grpNull,[grpNull]],["_generation",-1,[0]],["_brain",createHashMap,[createHashMap]],["_expectedPhase","DISCOVER",[""]]];
if (!isServer || {isNull _requester} || {count _brain == 0}
    || {_generation != (_requester getVariable ["WAIT_Support_BrainGeneration",-2])}
    || {(_requester getVariable ["WAIT_Support_Brain",createHashMap]) isNotEqualTo _brain}
    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}) exitWith {false};
if (_brain getOrDefault ["pending",false]) exitWith {true};
_brain set ["pending",true];
_brain set ["completed",false];
_brain set ["expectedPhase",_expectedPhase];
_brain set ["queuedAt",time];
private _key=format ["WAIT_SUPPORT_%1_%2",_brain getOrDefault ["serial",-1],_generation];
[WAIT_fnc_SupportRequestStep,_brain,0,_key] call WAIT_fnc_CortexQueueJob;
true

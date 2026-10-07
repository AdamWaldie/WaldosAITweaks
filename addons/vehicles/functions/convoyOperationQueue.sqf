/*
 * Author: WaldoTheWarfighter
 * Purpose: Queues one bounded convoy-control step for the current finite convoy brain.
 * Locality / Authority: Owner-local. It issues no vehicle command directly and submits one coalesced callback to WAIT's shared scheduler.
 * Repeat/JIP: Group, registry revision and token coalesce duplicate work and reject stale owners.
 * Arguments: 0 group <GROUP>; 1 registry revision <NUMBER>; 2 configuration <ARRAY>; 3 convoy brain <HASHMAP>; 4 expected semantic phase <STRING>.
 * Return Value: Boolean - true when a current or newly queued step exists.
 * Current caller: WAIT convoyOperation FSM.
 * Example: [_group,4,_configuration,_brain,"SPACING"] call WAIT_fnc_ConvoyOperationQueue;
 */
params [["_group",grpNull,[grpNull]],["_registryRevision",-1,[0]],["_configuration",[],[[]]],["_brain",createHashMap,[createHashMap]],["_expectedPhase","CRUISE",[""]]];
if (isNull _group || {!local _group} || {count _brain == 0} || {_registryRevision != (missionNamespace getVariable ["WAIT_Convoy_ReceivedRevision",-2])} || {(_brain getOrDefault ["jobToken",""]) isNotEqualTo (_group getVariable ["WAIT_Convoy_LocalJobToken",""])} || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}) exitWith {false};
if (_brain getOrDefault ["pending",false]) exitWith {true};
_brain set ["pending",true];_brain set ["completed",false];_brain set ["expectedPhase",_expectedPhase];
private _key=format ["WAIT_CONVOY_%1_%2_%3",str _group,_registryRevision,_brain getOrDefault ["jobToken",""]];
[WAIT_fnc_ConvoyOperationStep,_brain,0,_key] call WAIT_fnc_CortexQueueJob;
true

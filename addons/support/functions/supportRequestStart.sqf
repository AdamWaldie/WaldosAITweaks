/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one server-owned finite brain for a bounded cross-squad support request.
 * Locality / Authority: Server only. Responder owners continue to validate and execute their own movement and combat roles.
 * Repeat/JIP: The exact request serial reuses its brain. A replacement increments the requester generation and invalidates older queued work; requests are not recreated for JIP.
 * Arguments: 0 support request job <HASHMAP>; 1 initial delay <NUMBER>, default 0.
 * Return Value: Boolean - true when the exact support request has an active brain.
 * Current caller: WAIT_fnc_CortexSupportServer.
 * Example: [_job,1] call WAIT_fnc_SupportRequestStart;
 */
params [["_job",createHashMap,[createHashMap]],["_delay",0,[0]]];
if (!isServer || {count _job == 0}) exitWith {false};
private _requester=_job getOrDefault ["requester",grpNull];
private _serial=_job getOrDefault ["serial",-1];
private _key=_job getOrDefault ["key",""];
if (isNull _requester || {_serial < 0} || {_key == ""}) exitWith {false};
private _registered=(missionNamespace getVariable ["WAIT_AIPass_SupportRequests",createHashMap]) getOrDefault [_key,createHashMap];
if (_registered isNotEqualTo _job) exitWith {false};
private _current=_requester getVariable ["WAIT_Support_Brain",createHashMap];
if (count _current > 0 && {(_current getOrDefault ["serial",-2]) == _serial}
    && {!(_current getOrDefault ["cancelled",false])} && {!(_current getOrDefault ["finished",false])}) exitWith {true};
if (count _current > 0) then {_current set ["cancelled",true];_current set ["cancelReason","REPLACED"]};
private _generation=(_requester getVariable ["WAIT_Support_BrainGeneration",0])+1;
private _brain=createHashMapFromArray [
    ["requester",_requester],["job",_job],["serial",_serial],["generation",_generation],
    ["phase","DISCOVER"],["pending",false],["completed",false],["finished",false],
    ["cancelled",false],["cancelReason",""],["nextAt",time+(_delay max 0)],
    ["lastStepAt",-1],["lastDelay",_delay max 0],["queuedAt",-1],["watchdogCount",0]
];
_requester setVariable ["WAIT_Support_BrainGeneration",_generation];
_requester setVariable ["WAIT_Support_Brain",_brain];
_requester setVariable ["WAIT_Support_Brain_State",["DISCOVER",_generation,serverTime,"STARTED"],true];
private _handle=[_job,_generation,_brain] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\supportRequest.fsm";
_requester setVariable ["WAIT_Support_Brain_FSM",_handle];
true

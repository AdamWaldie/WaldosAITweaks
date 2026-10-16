/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires matching ordinary driving work and releases only its tracked speed leases.
 * Locality / Authority: Owner-local group only; no ownership transfer or second scheduler.
 * Repeat/JIP: Epoch, generation and current-brain identity reject stale work. New owners start
 * their own execution; local jobs and FSM handles are never replayed to JIP.
 * Arguments: 0 brain <HASHMAP, empty>; 1 reason <STRING, RELEASED>.
 * Return Value: Nothing.
 * Current callers: WAIT drivingOperation FSM, DrivingOperationStart and CortexReleaseGroup.
 * Example: [_brain,"ZEUS"] call WAIT_fnc_DrivingOperationFinish;
 */
params [["_brain",createHashMap,[createHashMap]],["_reason","RELEASED",[""]]];
_brain set ["cancelled",true];_brain set ["finished",true];_brain set ["pending",false];
_brain set ["completed",true];_brain set ["cancelReason",_reason];
private _group=_brain getOrDefault ["group",grpNull];
if (isNull _group || {!local _group}
    || {(_group getVariable ["WAIT_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {};
[_group,_brain,true] call WAIT_fnc_DrivingCrewStep;
{[_x,_group] call WAIT_fnc_DrivingAssistRelease} forEach (_group getVariable ["WAIT_DrivingAssist_Vehicles",[]]);
_group setVariable ["WAIT_DrivingAssist_Vehicles",nil];
_group setVariable ["WAIT_Driving_FSM",nil];
_group setVariable ["WAIT_Driving_State",["HANDBACK",_brain get "generation",serverTime,_reason],true];
// Keep a terminal receipt only for exhausted retries. A new order may start a new operation.
if (_reason != "EXHAUSTED") then {_group setVariable ["WAIT_Driving_Brain",nil]};

/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes one bounded aircraft-attack implementation step and reports its resulting semantic phase to the finite FSM.
 * Locality / Authority: Runs through WAIT's shared scheduler on the aircraft owner. WAIT_fnc_CortexAirAttack rechecks control before every native command boundary.
 * Repeat/JIP: One-shot callback. Aircraft generation and brain identity reject stale work after replacement or locality migration.
 * Arguments: 0 aircraft attack brain <HASHMAP>.
 * Return Value: Number - always -1 because the FSM schedules later steps.
 * Current caller: WAIT_fnc_AirAttackOperationQueue through WAIT_fnc_CortexQueueJob.
 * Example: [_brain] call WAIT_fnc_AirAttackOperationStep;
 */
params [["_brain",createHashMap,[createHashMap]]];
private _aircraft=_brain getOrDefault ["aircraft",objNull];
private _generation=_brain getOrDefault ["generation",-1];
private _cancel={
    params ["_reason"];
    _brain set ["pending",false];
    _brain set ["completed",true];
    _brain set ["finished",true];
    _brain set ["cancelled",true];
    _brain set ["cancelReason",_reason];
    -1
};
if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith {[_brain getOrDefault ["cancelReason","CANCELLED"]] call _cancel};
if (isNull _aircraft || {!local _aircraft}) exitWith {["OWNERSHIP_LOST"] call _cancel};
if (_generation != (_aircraft getVariable ["WAIT_AirAttack_BrainGeneration",-2])
    || {(_aircraft getVariable ["WAIT_AirAttack_Brain",createHashMap]) isNotEqualTo _brain}) exitWith {["REPLACED"] call _cancel};
private _job=_brain getOrDefault ["job",createHashMap];
if (count _job == 0) exitWith {["INVALID_JOB"] call _cancel};
private _leaseToken=_brain getOrDefault ["flightLeaseToken",""];
if !([_aircraft,"AIR_ATTACK",_leaseToken] call WAIT_fnc_FlightLeaseValid) then {
    _job set ["flightLeaseLost",true];
};
private _delay=[_job] call WAIT_fnc_CortexAirAttack;
private _phase=toUpperANSI (_job getOrDefault ["stage","PLAN"]);
if !(_phase in ["PLAN","INGRESS","ATTACK","EGRESS"]) then {_phase="PLAN"};
_brain set ["phase",_phase];
_brain set ["lastStepAt",time];
_brain set ["lastDelay",_delay];
_brain set ["pending",false];
_brain set ["completed",true];
if (_delay < 0) then {
    _brain set ["finished",true];
    _brain set ["cancelReason",(_aircraft getVariable ["WAIT_Cortex_AirAttackOutcome",["ENDED"]]) param [0,"ENDED"]];
} else {
    _brain set ["nextAt",time+_delay];
};
_aircraft setVariable ["WAIT_AirAttack_Brain_State",[
    _phase,_generation,serverTime,_brain getOrDefault ["cancelReason",""],_delay
],true];
-1

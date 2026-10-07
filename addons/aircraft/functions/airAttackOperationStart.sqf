/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one owner-local finite aircraft-attack brain for a live aircraft and target request.
 * Locality / Authority: Runs only on the aircraft owner. The FSM owns phase persistence; WAIT_fnc_CortexAirAttack retains bounded native flight, targeting and weapon-release work.
 * Repeat/JIP: A current active brain is reused. A new generation invalidates older local work after replacement or locality adoption.
 * Arguments: 0 attack job <HASHMAP>; 1 initial delay <NUMBER>, default 0.
 * Return Value: Boolean - true when an active brain exists for the aircraft.
 * Current callers: WAIT_fnc_CortexDiscover and WAIT_fnc_CortexCombinedArmsLocal.
 * Example: [createHashMapFromArray [["aircraft",_plane],["target",_target]],0] call WAIT_fnc_AirAttackOperationStart;
 */
params [["_job",createHashMap,[createHashMap]],["_delay",0,[0]]];
private _aircraft=_job getOrDefault ["aircraft",objNull];
if (isNull _aircraft || {!local _aircraft}) exitWith {false};
private _current=_aircraft getVariable ["WAIT_AirAttack_Brain",createHashMap];
if (count _current > 0 && {!(_current getOrDefault ["cancelled",false])} && {!(_current getOrDefault ["finished",false])}) exitWith {true};
if (count _current > 0) then {_current set ["cancelled",true];_current set ["cancelReason","REPLACED"]};
private _generation=(_aircraft getVariable ["WAIT_AirAttack_BrainGeneration",0])+1;
private _leaseToken=str _generation;
if !([_aircraft,"AIR_ATTACK",_leaseToken,300] call WAIT_fnc_FlightLeaseAcquire) exitWith {false};
_aircraft setVariable ["WAIT_AirAttack_BrainGeneration",_generation];
_job set ["flightLeaseToken",_leaseToken];
private _brain=createHashMapFromArray [
    ["aircraft",_aircraft],["job",_job],["generation",_generation],["phase","PLAN"],
    ["pending",false],["completed",false],["finished",false],["cancelled",false],
    ["cancelReason",""],["nextAt",time+(_delay max 0)],["lastStepAt",-1],["lastDelay",_delay max 0],
    ["flightLeaseToken",_leaseToken]
];
_aircraft setVariable ["WAIT_Cortex_AirAttackJob",true];
_aircraft setVariable ["WAIT_AirAttack_Brain",_brain];
_aircraft setVariable ["WAIT_AirAttack_Brain_State",["PLAN",_generation,serverTime,"STARTED"],true];
private _handle=[_aircraft,_generation,_brain] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\airAttackOperation.fsm";
_aircraft setVariable ["WAIT_AirAttack_Brain_FSM",_handle];
true

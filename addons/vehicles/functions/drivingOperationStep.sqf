/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes one route-owned driving sample and derives its next FSM phase from actual vehicle state.
 * Locality / Authority: Owner-local group only; no ownership transfer or second scheduler.
 * Public diagnostics publish on state changes and a ten-second heartbeat using this same callback.
 * Repeat/JIP: Epoch, generation and current-brain identity reject stale work. New owners start
 * their own execution; local jobs and FSM handles are never replayed to JIP.
 * Arguments: 0 brain <HASHMAP, empty>.
 * Return Value: NUMBER - -1; the FSM queues later work.
 * Current callers: WAIT_fnc_DrivingOperationQueue through CortexQueueJob.
 * Example: [_brain] call WAIT_fnc_DrivingOperationStep;
 */
params [["_brain",createHashMap,[createHashMap]]];
private _group=_brain getOrDefault ["group",grpNull];
private _reject={params ["_reason"];_brain set ["cancelled",true];_brain set ["cancelReason",_reason];_brain set ["pending",false];_brain set ["completed",true];-1};
if (isNull _group || {!local _group} || {_brain getOrDefault ["cancelled",false]}
    || {(_group getVariable ["WAIT_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {["OWNER_CHANGED"] call _reject};
if ([_group] call WAIT_fnc_CortexZeusHeld || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {["TAKEOVER"] call _reject};
if (!([_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled)) exitWith {["DISABLED"] call _reject};
if (!([_group] call WAIT_fnc_DrivingMovementAvailable)) exitWith {["TACTICAL_OWNER"] call _reject};
if (([_group] call WAIT_fnc_DrivingRouteReceipt) isNotEqualTo (_brain get "route")) exitWith {["ORDER_CHANGED"] call _reject};
private _crewPending=[_group,_brain] call WAIT_fnc_DrivingCrewStep;
[_group,_brain] call WAIT_fnc_DrivingAssistStart;
private _bypass="";private _obstacle=false;private _corridor="";
private _phase="HANDBACK";private _owned=0;private _recovery=false;private _waiting=false;private _exhausted=false;private _traffic=false;private _rearLeg=false;
{
    private _state=_x getVariable ["WAIT_DrivingAssist_State",[]];
    if ((_state param [3,grpNull]) == _group) then {
        _owned=_owned+1;
        if ((_state param [8,""]) in ["BYPASS_PLAN","BYPASS_FOLLOW"]) then {_bypass=_state select 8};
        _obstacle=_obstacle || {(_state param [8,""]) in ["OBSTACLE_APPROACH","OBSTACLE_WAIT"]};
        if ((_state param [8,""]) in ["CORRIDOR_APPROACH","CORRIDOR_CROSS"]) then {_corridor=_state select 8};
        _traffic=_traffic || {(_state param [8,""]) == "TRAFFIC_FOLLOW"};
        _waiting=_waiting || {(_state param [8,""]) == "INTENTIONAL_WAIT"};
        _recovery=_recovery || {(_state param [6,0]) in [1,2,3]};
        _rearLeg=_rearLeg || {(_state param [6,0]) == 2};
        _exhausted=_exhausted || {(_state param [8,""]) == "EXHAUSTED"};
    };
} forEach (_group getVariable ["WAIT_DrivingAssist_Vehicles",[]]);
if (_owned > 0) then {_phase=if (_recovery) then {"RECOVERY"} else {if (_waiting) then {"INTENTIONAL_WAIT"} else {if (_traffic) then {"TRAFFIC"} else {"CRUISE"}}}};
if (_obstacle && {_owned > 0}) then {_phase="OBSTACLE"};
if (_corridor != "") then {_phase=_corridor};
if (_bypass != "") then {_phase=_bypass};
if (_owned == 0 && {!_crewPending}) then {_brain set ["cancelReason","NO_ELIGIBLE_VEHICLE"]};
if (_exhausted) then {_phase="HANDBACK";_brain set ["cancelReason","EXHAUSTED"]};
if (_crewPending) then {_phase="CREW_HANDOVER"};
_brain set ["phase",_phase];_brain set ["nextAt",time+([4,1] select (_crewPending || {_traffic} || {_obstacle} || {_rearLeg} || {_corridor != ""} || {_bypass != ""}))];_brain set ["pending",false];_brain set ["completed",true];
// Publish transitions immediately, plus a sparse heartbeat at existing callback cadence.
// The local brain owns this receipt: a new owner/brain publishes its first sample even if
// its phase/generation happens to match the previous owner's public diagnostic packet.
private _statusKey=[_phase,_brain get "generation",_brain get "cancelReason"];
private _lastStatusAt=_brain getOrDefault ["lastStatusAt",-1e9];
if (_statusKey isNotEqualTo (_brain getOrDefault ["lastStatus",[]])
    || {serverTime-_lastStatusAt >= 10} || {serverTime < _lastStatusAt}) then {
    _group setVariable ["WAIT_Driving_State",[_phase,_brain get "generation",serverTime,_brain get "cancelReason"],true];
    _brain set ["lastStatus",_statusKey];_brain set ["lastStatusAt",serverTime];
};
-1

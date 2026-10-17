/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one route-scoped ordinary driving FSM; registered convoys retain their own writer.
 * Seat-only casualty handover can start for local crew in a remote vehicle. Driving still requires
 * vehicle locality; native unit seat actions never acquire its speed/path authority.
 * Locality / Authority: Owner-local group only; no ownership transfer or second scheduler.
 * Repeat/JIP: Epoch, generation and current-brain identity reject stale work. New owners start
 * their own execution; local jobs and FSM handles are never replayed to JIP.
 * Arguments: 0 group <GROUP, grpNull>.
 * Return Value: BOOL - whether a current driving brain exists.
 * Current callers: WAIT_fnc_DrivingAssistStart.
 * Example: [group driver truck1] call WAIT_fnc_DrivingOperationStart;
 */
params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group} || {!(missionNamespace getVariable ["WAIT_AIPass_Active",false])}
    || {!([_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!([_group] call WAIT_fnc_DrivingMovementAvailable)}
    || {[_group] call WAIT_fnc_CortexZeusHeld} || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
private _route=[_group] call WAIT_fnc_DrivingRouteReceipt;
if (_route isEqualTo []) exitWith {false};
if ((_group getVariable ["WAIT_DrivingRecovery_Yield",[]]) isEqualTo _route) exitWith {false};
_group setVariable ["WAIT_DrivingRecovery_Yield",nil,true];
// Direct script admission uses the same locality establishment as ordinary group discovery.
if (!(_group getVariable ["WAIT_AIPass_Adopted",false])) then {
    if ([_group] call WAIT_fnc_CortexIsEligible) then {[_group,true] call WAIT_fnc_CortexLocality};
};
if (!local _group || {!(_group getVariable ["WAIT_AIPass_Adopted",false])}) exitWith {false};
private _epoch=_group getVariable ["WAIT_AIPass_Epoch",0];
private _current=_group getVariable ["WAIT_Driving_Brain",createHashMap];
if (count _current > 0 && {(_current getOrDefault ["ownerEpoch",-1]) == _epoch}
    && {(_current getOrDefault ["route",[]]) isEqualTo _route}) exitWith {
    // Exhaustion is a result for this exact order, not permission to restart the same retries.
    !(_current getOrDefault ["cancelled",false]) && {!(_current getOrDefault ["finished",false])}
};
if (count _current > 0) then {[_current,"REPLACED"] call WAIT_fnc_DrivingOperationFinish};
private _hasVehicle=(units _group) findIf {
    private _vehicle=vehicle _x;
    _vehicle != _x && {_vehicle isKindOf "LandVehicle"} && {!(_vehicle isKindOf "StaticWeapon")}
        && {alive _vehicle} && {canMove _vehicle}
        && {(local _vehicle && {!isNull driver _vehicle} && {group driver _vehicle == _group})
            || {vehicle leader _group == _vehicle && {[_x] call WAIT_fnc_CortexCombatEffective}
                && {(isNull driver _vehicle || {!alive driver _vehicle})}
                && {[_group,"WAIT_AIPass_DrivingAssist_Recovery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}}}
        && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
} >= 0;
if (!_hasVehicle) exitWith {false};
private _generation=(_group getVariable ["WAIT_Driving_Generation",0])+1;
_group setVariable ["WAIT_Driving_Generation",_generation];
private _brain=createHashMapFromArray [["group",_group],["ownerEpoch",_epoch],
    ["generation",_generation],["route",_route],["phase","CRUISE"],["pending",false],
    ["completed",false],["cancelled",false],["finished",false],["cancelReason",""],
    ["nextAt",time],["queuedAt",time],["watchdogCount",0]];
_group setVariable ["WAIT_Driving_Brain",_brain];
private _handle=[_brain] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\drivingOperation.fsm";
_group setVariable ["WAIT_Driving_FSM",_handle];
true

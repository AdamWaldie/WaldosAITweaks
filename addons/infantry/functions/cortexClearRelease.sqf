/*
 * Author: WaldoTheWarfighter
 * Cancels a clearing order immediately and resumes formation after doStop. Clearance does not own
 * group behaviour or combat mode, so release preserves any contact or Zeus change made during it.
 * Locality/authority: server authenticates dispatch; the current owner executes group commands.
 * Repeat/JIP: request tokens are consumed once; no stale order is replayed for JIP.
 * Arguments: 0: group <GROUP>, default grpNull; 1: restore formation <BOOL>, default true. Pass
 * false when Zeus has already supplied a replacement order so cleanup cannot overwrite it.
 * Return Value: Boolean, a clearing order existed.
 * Current callers: AI Orders, replacement orders, Zeus release and stop.
 * Example: [_group] call WAIT_fnc_CortexClearRelease;
 */
params [["_group", grpNull, [grpNull]],["_restore",true,[true]]];
if (isNull _group || {!local _group} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
private _delegated=_group getVariable ["WAIT_Cortex_BuildingBackend",[]];
if (count _delegated >= 2 && {(_delegated select 0) == "COMPAT"} && {(_delegated select 1) == "CQB"}) exitWith {
    [_group,_restore] call WAIT_fnc_CortexBuildingBackendRelease
};
private _order = _group getVariable ["WAIT_AIPass_ClearOrder", []];
if (_order isEqualTo []) exitWith {false};
// A disabled feature must still release WAIT's own movement lease.  Only an actual player,
// Zeus, compatibility or specialist takeover suppresses a formation recall; broad eligibility
// also includes normal feature gates and would otherwise leave a released clear element stopped.
private _externalTakeover = [_group] call WAIT_fnc_CortexExternalTakeover;
if (_restore && {_externalTakeover}) then {_restore=false};
private _buildingBrain=_group getVariable ["WAIT_BuildingBrain",createHashMap];
if (count _buildingBrain > 0) then {
    _buildingBrain set ["cancelled",true];
    _buildingBrain set ["cancelReason","CLEAR_RELEASE"];
    _buildingBrain set ["completed",true];
};
_group setVariable ["WAIT_AIPass_ClearGeneration", (_group getVariable ["WAIT_AIPass_ClearGeneration", 0]) + 1];
_group setVariable ["WAIT_BuildingBrain",nil];
_group setVariable ["WAIT_BuildingBrain_FSM",nil];
// A release often comes from a Zeus replacement order.  Invalidate the common operation now,
// rather than waiting for the low-frequency building job to notice the cleared flag.  Restrict
// this to CLEAR so a newer, externally owned operation cannot be cancelled by stale clear state.
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if ((_operation getOrDefault ["intent",""]) == "CLEAR") then {
    [_group,_operation getOrDefault ["generation",-1],"CLEAR_RELEASE"] call WAIT_fnc_OperationCancel;
};
_group setVariable ["WAIT_Cortex_ClearResult",["CANCELLED",count (_order select 1),count ((_order select 0) buildingPos -1)],true];
_group setVariable ["WAIT_Cortex_ClearEvidence",[+(_order param [1,[]]),+(_order param [4,[]]),+(_order param [5,[]]),+(_order param [6,[]]),_order param [2,serverTime],_order param [7,serverTime]],true];
_group setVariable ["WAIT_AIPass_ClearOrder", nil, true];
_group setVariable ["WAIT_AIPass_ClearBuilding", nil, true];
_group setVariable ["WAIT_Cortex_ClearEgress",nil,true];
_group setVariable ["WAIT_AIPass_ClearApplied", nil];
private _leader=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
{
    if (local _x && {!isPlayer _x}) then {
        if (alive _x && {lifeState _x != "INCAPACITATED"}) then {
            // A replacement owner receives untouched stance and speed. These values are only
            // WAIT's lease while the clear release is returning control to the formation.
            if (_restore && {unitPos _x == "UP"} && {!isNil {_x getVariable "WAIT_Cortex_ClearStance"}}) then {
                _x setUnitPos (_x getVariable ["WAIT_Cortex_ClearStance","AUTO"]);
            };
            if (_restore && {!isNil {_x getVariable "WAIT_Cortex_ClearForcedSpeed"}} && {abs ((getForcedSpeed _x)-(_x getVariable ["WAIT_Cortex_ClearAppliedSpeed",getForcedSpeed _x])) <= 0.1}) then {
                _x forceSpeed (_x getVariable ["WAIT_Cortex_ClearForcedSpeed",-1]);
            };
            if (_restore) then {_x doFollow _leader};
        };
        _x setVariable ["WAIT_Cortex_ClearStance",nil];
        _x setVariable ["WAIT_Cortex_ClearForcedSpeed",nil];
                    _x setVariable ["WAIT_Cortex_ClearAppliedSpeed",nil];
    };
} forEach units _group;
true

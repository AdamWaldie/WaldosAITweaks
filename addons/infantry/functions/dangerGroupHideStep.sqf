/*
 * Author: WaldoTheWarfighter
 * Purpose: Apply or release one finite squad-level low-profile response after immediate incoming danger without taking movement, target or firing ownership.
 * Locality / Authority: Runs only on the owner of the local AI group from the existing group-brain step. It changes weak stance only for local, idle, on-foot actors not reserved by another WAIT operation.
 * Repeat/JIP: One generation-owned group lease records each actor's prior and applied weak stance. Repeated calls retain that lease; release restores only an unchanged WAIT-applied stance. Zeus, player, specialist, locality and newer-generation handover discard the lease without writing over the new owner.
 * Arguments: 0: group <GROUP>, grpNull; 1: danger generation <NUMBER>, -1; 2: active <BOOL>, false; 3: cause <STRING>, "".
 * Return Value: Boolean - true while one or more exact-owned squad stance leases remain active.
 * Current callers: WAIT_fnc_CortexGroupTick, WAIT_fnc_CortexReleaseGroup and WAIT_fnc_DangerSetup.
 * Example: [group player,group player getVariable ["WAIT_Danger_Generation",0],true,"HIT"] call WAIT_fnc_DangerGroupHideStep;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_generation",-1,[0]],
    ["_active",false,[true]],
    ["_cause","",[""]]
];
if (isNull _group) exitWith {false};

private _leases=_group getVariable ["WAIT_Danger_GroupHideLeases",[]];
private _external=!local _group
    || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[_group] call WAIT_fnc_CortexZeusHeld};
private _release={
    if (!_external) then {
        {
            _x params ["_unit","_prior","_applied"];
            if (!isNull _unit && {local _unit} && {toUpperANSI (unitPos _unit) == _applied}) then {
                _unit setUnitPosWeak _prior;
            };
        } forEach _leases;
    };
    _group setVariable ["WAIT_Danger_GroupHideLeases",nil];
    false
};

if (!_active || {_external}
    || {_generation != (_group getVariable ["WAIT_Danger_Generation",0])}
    || {!(missionNamespace getVariable ["WAIT_AIPass_Active",false])}
    || {!([_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) exitWith {call _release};

if (_leases isNotEqualTo []) exitWith {
    private _valid=_leases select {
        _x params ["_unit","_prior","_applied","_leaseGeneration"];
        !isNull _unit && {alive _unit} && {local _unit} && {group _unit == _group}
            && {_leaseGeneration == _generation} && {toUpperANSI (unitPos _unit) == _applied}
    };
    if (count _valid != count _leases) then {
        // A newer actor-level or external stance decision invalidates only that actor's proof of
        // ownership. Retain the remaining exact leases without reapplying or expanding the set.
        _group setVariable ["WAIT_Danger_GroupHideLeases",_valid];
    };
    _valid isNotEqualTo []
};

private _operation=_group getVariable ["WAIT_Operation",createHashMap];
private _reserved=if (count _operation > 0) then {
    (_operation getOrDefault ["participants",[]]) + (_operation getOrDefault ["unavailable",[]])
} else {[]};
private _candidates=(units _group) select {
    local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x}
        && {[_x] call WAIT_fnc_CortexCombatEffective}
        && {!(_x in _reserved)}
        && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
        && {currentCommand _x == ""}
        && {(_x getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo []}
};
// Bound work and avoid turning a whole platoon prone on one callback. Up to four idle actors lower
// their profile; active movers, native tasks and operation participants continue uninterrupted.
_candidates resize ((count _candidates) min 4);
private _newLeases=[];
{
    private _prior=toUpperANSI (unitPos _x);
    private _applied=["MIDDLE","DOWN"] select (getSuppression _x > 0.55 && {_cause in ["HIT","SUPPRESSED"]});
    if (_prior != _applied) then {
        _x setUnitPosWeak _applied;
        _newLeases pushBack [_x,_prior,_applied,_generation];
    };
} forEach _candidates;
if (_newLeases isEqualTo []) exitWith {false};
_group setVariable ["WAIT_Danger_GroupHideLeases",_newLeases];
private _stats=_group getVariable ["WAIT_Danger_EngineStats",createHashMap];
_stats set ["groupHideResponses",((_stats getOrDefault ["groupHideResponses",0])+1) min 100000];
_stats set ["lastGroupHideActors",_newLeases apply {_x select 0}];
_group setVariable ["WAIT_Danger_EngineStats",_stats];
true

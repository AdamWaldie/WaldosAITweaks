/*
 * Author: WaldoTheWarfighter
 * Purpose: Apply or release one finite squad-level low-profile response after immediate incoming danger without taking movement, target or firing ownership.
 * Locality / Authority: Runs only on the owner of the local AI group from the existing group-brain step. It changes weak stance only for local, idle, on-foot actors not reserved by another WAIT operation.
 * Cleanup may restore its exact weak posture during ordinary movement or a WAIT cover route;
 * it does not change that route. Starting a new group posture still requires an idle actor.
 * Repeat/JIP: One generation-owned group lease records each actor's prior and applied weak stance, operation generation and owner epoch. Repeated calls retain that lease; release restores only an unchanged WAIT-applied stance. Zeus, player, specialist, locality and newer-generation handover discard the lease without writing over the new owner.
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
private _sameOwner={
    params ["_proof"];
    count _proof < 6 || {(_proof select 4) == (_group getVariable ["WAIT_OperationGeneration",0])
        && {(_proof select 5) == (_group getVariable ["WAIT_AIPass_Epoch",0])}}
};
private _mayRestore={
    params ["_proof"];
    private _unit=_proof param [0,objNull,[objNull]];
    private _move=_unit getVariable ["WAIT_Cortex_ActorMove",[]];
    private _postureFree=_move isEqualTo []
        || {_move isEqualType [] && {count _move == 3} && {
            (_move param [2,1e12,[0]]) <= time || {(_move select 0) == "DANGER_COVER"}
        }};
    [_proof] call _sameOwner
        && {[_unit] call WAIT_fnc_CortexCombatEffective}
        && {currentCommand _unit in ["","MOVE","ATTACK","FIRE","SUPPRESS"]}
        && {_postureFree}
        && {(_unit getVariable ["WAIT_Danger_EngineStanceLease",[]]) isEqualTo []}
};
private _release={
    if (!_external) then {
        {
            _x params ["_unit","_prior","_applied"];
            if ([_x] call _mayRestore && {!isNull _unit} && {alive _unit} && {local _unit} && {!isPlayer _unit}
                && {group _unit == _group} && {isNull objectParent _unit}
                && {!([_unit] call WAIT_fnc_CompatibilityExternalControl)}
                && {toUpperANSI (unitPos _unit) == _applied}) then {
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
    {
        _x params ["_unit","_prior","_applied","_leaseGeneration"];
        // Generation replacement ends this finite posture. Dropping its record alone left
        // the old weak stance behind and made the next generation capture it as its baseline.
        if (_leaseGeneration != _generation && {[_x] call _mayRestore} && {!isNull _unit} && {alive _unit}
            && {local _unit} && {!isPlayer _unit} && {group _unit == _group}
            && {isNull objectParent _unit} && {!([_unit] call WAIT_fnc_CompatibilityExternalControl)}
            && {toUpperANSI (unitPos _unit) == _applied}) then {
            _unit setUnitPosWeak _prior;
        };
    } forEach _leases;
    private _valid=_leases select {
        _x params ["_unit","_prior","_applied","_leaseGeneration"];
        !isNull _unit && {alive _unit} && {local _unit} && {!isPlayer _unit}
            && {group _unit == _group} && {isNull objectParent _unit}
            && {!([_unit] call WAIT_fnc_CompatibilityExternalControl)}
            && {[_x] call _sameOwner} && {[_unit] call WAIT_fnc_CortexCombatEffective}
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
        && {(_x getVariable ["WAIT_Danger_EngineStanceLease",[]]) isEqualTo []}
};
// Preserve the squad's immediate anti-armour and anti-air answer. A low-profile danger response
// must not select the only launcher-capable actor merely because that actor appears early in group
// order. Rank ordinary riflemen first, then medics and automatic riflemen, and keep leaders plus
// loaded AT/AA gunners as the final fallback. The fallback still matters for very small specialist
// teams, where a finite weak stance is safer than manufacturing a movement response.
private _ranked=[];
{
    private _role=[_x] call WAIT_fnc_CortexUnitRole;
    private _capabilities=[_x] call WAIT_fnc_CortexCapabilities;
    private _readinessCost=switch (true) do {
        case (_capabilities isNotEqualTo []): {30};
        case (_role == "LEADER"): {20};
        case (_role == "MG"): {10};
        case (_role == "MEDIC"): {5};
        default {0};
    };
    _ranked pushBack [_readinessCost,_forEachIndex,_x];
} forEach _candidates;
_ranked sort true;
_candidates=_ranked apply {_x select 2};
// Bound work and avoid turning a whole platoon prone on one callback. Up to four idle actors lower
// their profile; active movers, native tasks and operation participants continue uninterrupted.
_candidates resize ((count _candidates) min 4);
private _newLeases=[];
{
    private _prior=toUpperANSI (unitPos _x);
    private _applied=["MIDDLE","DOWN"] select (getSuppression _x > 0.55 && {_cause in ["HIT","SUPPRESSED"]});
    if (_prior != _applied) then {
        _x setUnitPosWeak _applied;
        _newLeases pushBack [_x,_prior,_applied,_generation,
            _group getVariable ["WAIT_OperationGeneration",0],_group getVariable ["WAIT_AIPass_Epoch",0]];
    };
} forEach _candidates;
if (_newLeases isEqualTo []) exitWith {false};
_group setVariable ["WAIT_Danger_GroupHideLeases",_newLeases];
private _stats=_group getVariable ["WAIT_Danger_EngineStats",createHashMap];
_stats set ["groupHideResponses",((_stats getOrDefault ["groupHideResponses",0])+1) min 100000];
_stats set ["lastGroupHideActors",_newLeases apply {_x select 0}];
_group setVariable ["WAIT_Danger_EngineStats",_stats];
true

/*
 * Author: WaldoTheWarfighter
 * Purpose: Runs one bounded, owner-local vanilla medical assistance operation for a calm friendly squad.
 * Locality / Authority: Runs only on the group owner and commands only local on-foot AI. It yields to Zeus,
 * player control, active combat movement and any detected specialist medical owner.
 * Repeat / JIP: The public operation generation and small aid record are rechecked every group tick. A new owner
 * cancels the old operation rather than resuming a stale treatment command.
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP> - current Cortex group state.
 * 2: phase <STRING> - current Cortex phase.
 * Return Value: BOOL - true while WAIT owns a finite aid operation.
 * Current callers: WAIT_fnc_CortexGroupTick.
 * Example: [group player,createHashMap,"CALM"] call WAIT_fnc_CortexMedicalStep;
 * Result: an eligible local medic physically approaches and uses the native treatment command, or WAIT leaves the squad unchanged.
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_state",createHashMap,[createHashMap]],
    ["_phase","",[""]]
];
if (isNull _group || {!local _group}
    || {!([_group,"WAIT_AIPass_MedicalAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {[_group] call WAIT_fnc_CortexZeusHeld}
    || {[_group] call WAIT_fnc_CompatibilityExternalControl}
    || {(["medicalBackend"] call WAIT_fnc_CompatibilityAvailable)}) exitWith {false};

private _finish = {
    params ["_result","_reason"];
    private _aid=_group getVariable ["WAIT_Cortex_MedicalAid",[]];
    private _generation=_aid param [0,-1];
    if (_generation >= 0) then {
        if (_result == "COMPLETE") then {
            [_group,_generation,"COMPLETE",_reason] call WAIT_fnc_OperationRelease;
        } else {
            [_group,_generation,_reason] call WAIT_fnc_OperationCancel;
        };
    };
    _group setVariable ["WAIT_Cortex_MedicalAid",nil,true];
    false
};

// Ownership can change after the tick-level eligibility check and immediately before an engine
// command. Recheck at each movement or treatment write so Zeus and specialist controllers never
// receive a stale WAIT command from this finite operation.
private _mayIssueMedical = {
    !([_group] call WAIT_fnc_CortexExternalTakeover)
        && {!([_group] call WAIT_fnc_CortexZeusHeld)}
        && {!([_group] call WAIT_fnc_CompatibilityExternalControl)}
};

private _aid=_group getVariable ["WAIT_Cortex_MedicalAid",[]];
private _dangerResponse=_group getVariable ["WAIT_Danger_Response",[]];
private _dangerActive=count _dangerResponse == 5
    && {(_dangerResponse select 4) == (_group getVariable ["WAIT_Danger_Generation",-1])}
    && {time < (_dangerResponse select 3)};
if (_aid isNotEqualTo []) exitWith {
    // Medical runs before the normal contact planner in CortexGroupTick. Retire it here when the
    // danger FSM has produced a live response, then return false so the same group tick can consume
    // that response instead of waiting for another medical interval.
    if (_dangerActive) exitWith {["CANCELLED","COMBAT_RESUMED"] call _finish};
    _aid params ["_generation","_medic","_casualty","_startedAt","_lastOrderAt","_bestDistance","_lastProgressAt"];
    if (isNull _medic || {isNull _casualty} || {!alive _medic} || {!alive _casualty}
        || {!local _medic} || {!local _casualty} || {group _medic != _group} || {group _casualty != _group}
        || {vehicle _medic != _medic} || {vehicle _casualty != _casualty}
        || {!([_medic] call WAIT_fnc_CortexCombatEffective)}
        || {_casualty getVariable ["ACE_isUnconscious",false]} || {lifeState _casualty == "INCAPACITATED"}) exitWith {
        ["CANCELLED","ACTOR_UNAVAILABLE"] call _finish
    };
    if (damage _casualty < (missionNamespace getVariable ["WAIT_AIPass_MedicalAssist_DamageThreshold",0.35])) exitWith {
        missionNamespace setVariable ["WAIT_AIPass_MedicalAssists",(missionNamespace getVariable ["WAIT_AIPass_MedicalAssists",0])+1];
        ["COMPLETE","TREATED"] call _finish
    };
    if (_phase in ["CONTACT","RETREAT"] || {time-_startedAt >= (missionNamespace getVariable ["WAIT_AIPass_MedicalAssist_Timeout",45])}) exitWith {
        ["CANCELLED",["COMBAT_RESUMED","TIMEOUT"] select (time-_startedAt >= (missionNamespace getVariable ["WAIT_AIPass_MedicalAssist_Timeout",45]))] call _finish
    };
    private _distance=_medic distance2D _casualty;
    // At treatment range the medic's lack of displacement is expected: the native HealSoldier action can work
    // in place. The shared progress monitor is only meaningful while this finite operation is
    // physically approaching its casualty, otherwise it would incorrectly cancel a working aid.
    private _cancelReason="";
    if (_distance > 4) then {
        private _operationState=[_group,_generation,2,12] call WAIT_fnc_OperationStep;
        if (_operationState in ["LOST_OWNER","ZEUS","EXTERNAL","REPLACED"]) then {_cancelReason=_operationState};
        if (_operationState == "STALLED") then {_cancelReason="NO_PROGRESS"};
    };
    if (_cancelReason != "") exitWith {["CANCELLED",_cancelReason] call _finish};
    if !(call _mayIssueMedical) exitWith {["CANCELLED","EXTERNAL"] call _finish};
    if (_distance < _bestDistance-2) then {
        _bestDistance=_distance;
        _lastProgressAt=time;
    };
    if (_distance > 4 && {time-_lastProgressAt >= 12}) exitWith {
        ["CANCELLED","NO_PROGRESS"] call _finish
    };
    if (time-_lastOrderAt >= 8 && {call _mayIssueMedical}) then {
        if (_distance > 4) then {
            _medic doMove getPosATL _casualty;
            _medic setDestination [getPosATL _casualty,"LEADER PLANNED",true];
        } else {
            _medic action ["HealSoldier",_casualty];
        };
        _aid set [4,time];
        _aid set [5,_bestDistance];
        _aid set [6,_lastProgressAt];
        _group setVariable ["WAIT_Cortex_MedicalAid",_aid,true];
    };
    true
};

// Treatment is a security action, not a substitute for a current assault, withdrawal, building task,
// passenger procedure or direct order. Restrict selection to CALM/SECURITY and only when no finite
// WAIT operation already owns the group.
if (_dangerActive) exitWith {false};
if !(_phase in ["CALM","SECURITY"]) exitWith {false};
if (count (_group getVariable ["WAIT_Operation",createHashMap]) > 0
    || {_group getVariable ["WAIT_AIPass_ClearBuilding",false]}
    || {(_group getVariable ["WAIT_AIPass_Garrison",[]]) isNotEqualTo []}
    || {(_group getVariable ["WAIT_AIPass_Defend",[]]) isNotEqualTo []}) exitWith {false};

private _members=(units _group) select {
    alive _x && {local _x} && {!isPlayer _x} && {group _x == _group}
        && {vehicle _x == _x} && {[_x] call WAIT_fnc_CortexCombatEffective}
        && {!(_x getVariable ["ACE_isUnconscious",false])}
};
private _threshold=missionNamespace getVariable ["WAIT_AIPass_MedicalAssist_DamageThreshold",0.35];
// Command succession is independent of medical eligibility. A wounded current leader still needs a
// living medic; the pair selection below excludes only self-treatment.
private _casualties=_members select {damage _x >= _threshold};
if (_casualties isEqualTo []) exitWith {false};
private _medics=_members select {_x getUnitTrait "Medic" || {(_x getVariable ["ace_medical_medicClass",0]) > 0}};
if (_medics isEqualTo []) exitWith {false};
private _pair=[];
private _best=1e9;
{
    private _medic=_x;
    {
        private _distance=_medic distance2D _x;
        if (_medic != _x && {_distance < _best} && {_distance <= (missionNamespace getVariable ["WAIT_AIPass_MedicalAssist_Range",80])}) then {
            _best=_distance;
            _pair=[_medic,_x];
        };
    } forEach _casualties;
} forEach _medics;
if (_pair isEqualTo []) exitWith {false};
_pair params ["_medic","_casualty"];
private _operation=[_group,"MEDICAL_AID",_casualty,[_medic], [getPosATL _casualty],"APPROACH"] call WAIT_fnc_OperationStart;
if (count _operation == 0) exitWith {false};
private _generation=_operation get "generation";
if !(call _mayIssueMedical) exitWith {
    [_group,_generation,"EXTERNAL"] call WAIT_fnc_OperationCancel;
    false
};
if (_best > 4) then {
    _medic doMove getPosATL _casualty;
    _medic setDestination [getPosATL _casualty,"LEADER PLANNED",true];
} else {
    _medic action ["HealSoldier",_casualty];
};
_group setVariable ["WAIT_Cortex_MedicalAid",[_operation get "generation",_medic,_casualty,time,time,_best,time],true];
true

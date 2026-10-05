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

private _aid=_group getVariable ["WAIT_Cortex_MedicalAid",[]];
if (_aid isNotEqualTo []) exitWith {
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
    private _operationState=[_group,_generation,2,12] call WAIT_fnc_OperationStep;
    if (_operationState in ["LOST_OWNER","ZEUS","EXTERNAL","REPLACED"]) exitWith {
        ["CANCELLED",_operationState] call _finish
    };
    private _distance=_medic distance2D _casualty;
    if (_distance < _bestDistance-2) then {
        _bestDistance=_distance;
        _lastProgressAt=time;
    };
    if (_operationState == "STALLED" || {time-_lastProgressAt >= 12}) exitWith {
        ["CANCELLED","NO_PROGRESS"] call _finish
    };
    if (time-_lastOrderAt >= 8) then {
        _medic doHeal _casualty;
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
private _casualties=_members select {_x != leader _group && {damage _x >= _threshold}};
if (_casualties isEqualTo []) exitWith {false};
private _medics=_members select {_x != leader _group && {[_x] call WAIT_fnc_CortexUnitRole == "MEDIC"}};
if (_medics isEqualTo []) exitWith {false};
private _pair=[];
private _best=1e9;
{
    private _medic=_x;
    {
        private _distance=_medic distance2D _x;
        if (_distance < _best && {_distance <= (missionNamespace getVariable ["WAIT_AIPass_MedicalAssist_Range",80])}) then {
            _best=_distance;
            _pair=[_medic,_x];
        };
    } forEach _casualties;
} forEach _medics;
if (_pair isEqualTo []) exitWith {false};
_pair params ["_medic","_casualty"];
private _operation=[_group,"MEDICAL_AID",_casualty,[_medic], [getPosATL _casualty],"APPROACH"] call WAIT_fnc_OperationStart;
if (count _operation == 0) exitWith {false};
_medic doHeal _casualty;
_group setVariable ["WAIT_Cortex_MedicalAid",[_operation get "generation",_medic,_casualty,time,time,_best,time],true];
true

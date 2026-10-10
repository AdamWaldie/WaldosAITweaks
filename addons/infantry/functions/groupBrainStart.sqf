/*
 * Author: WaldoTheWarfighter
 * Purpose: Start or wake the one owner-local tactical brain for an eligible ground group.
 * Locality / Authority: Must run where the group is local. It never transfers ownership and never
 * issues movement; the FSM routes bounded decisions through the shared WAIT scheduler.
 * Repeat/JIP: Repeated calls reuse the current owner epoch and generation. Locality migration,
 * Zeus, external ownership, disablement or release invalidates the generation before old work can run.
 * Arguments:
 * 0: group <GROUP, default grpNull>
 * 1: wake now <BOOL, default false> - shorten the next decision deadline without adding another job.
 * Return Value: Boolean - true when a brain exists for the current owner.
 * Current callers: WAIT_fnc_CortexDiscover, WAIT_fnc_DangerStep and owner-local adoption.
 * Example: [_group,true] call WAIT_fnc_GroupBrainStart;
 */

params [["_group",grpNull,[grpNull]],["_wake",false,[true]]];
if (isNull _group || {!local _group} || {!(missionNamespace getVariable ["WAIT_AIPass_Active",false])}) exitWith {false};
// Native danger may bootstrap this brain before the discovery sweep reaches its group.
// Establish locality first so discovery cannot later invalidate an epoch-zero live brain.
if (!(_group getVariable ["WAIT_AIPass_Adopted",false])) then {
    if ([_group] call WAIT_fnc_CortexIsEligible) then {[_group,true] call WAIT_fnc_CortexLocality};
};
if (!local _group || {!(_group getVariable ["WAIT_AIPass_Adopted",false])}) exitWith {false};
private _epoch=_group getVariable ["WAIT_AIPass_Epoch",0];
private _brain=_group getVariable ["WAIT_GroupBrain",createHashMap];
if (count _brain > 0
    && {(_brain getOrDefault ["ownerEpoch",-1]) == _epoch}
    && {!(_brain getOrDefault ["cancelled",false])}) exitWith {
    if (_wake) then {
        _brain set ["wakeAt",time];
        _brain set ["nextAt",time];
        missionNamespace setVariable ["WAIT_AIPass_NextJobDue",time];
    };
    true
};
private _generation=(_group getVariable ["WAIT_GroupBrain_Generation",0])+1;
_group setVariable ["WAIT_GroupBrain_Generation",_generation];
_brain=createHashMapFromArray [
    ["group",_group],
    ["ownerEpoch",_epoch],
    ["generation",_generation],
    ["phase","CALM"],
    ["legacyPhase","CALM"],
    ["pending",false],
    ["completed",false],
    ["cancelled",false],
    ["cancelReason",""],
    ["nextAt",time],
    ["wakeAt",time],
    ["lastStepAt",-1],
    ["lastDelay",-1],
    ["queuedAt",-1],
    ["watchdogCount",0],
    ["responsiveUntil",0]
];
_group setVariable ["WAIT_GroupBrain",_brain];
_group setVariable ["WAIT_GroupBrain_State",["CALM",_generation,_epoch,serverTime,"STARTED"],true];
private _handle=[_group,_epoch,_generation,_brain] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\groupTactics.fsm";
_group setVariable ["WAIT_GroupBrain_FSM",_handle];
_group setVariable ["WAIT_AIPass_Managed",true];
true

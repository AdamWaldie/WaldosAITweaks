/*
 * Author: WaldoTheWarfighter
 * Purpose: Completes a matching WAIT operation after its physical outcome is known.
 * Locality/authority: Current group owner only.
 * Repeat/JIP: A replaced, previous-owner or externally claimed operation is not reported as complete. The completion record is public.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 result <STRING, COMPLETE>; 3 reason <STRING, COMPLETE>.
 * Return Value: BOOL - true when the matching operation was released.
 * Current callers: OperationStep and finite feature completion paths.
 * Example: [group player,4,"COMPLETE","OBJECTIVE_REACHED"] call WAIT_fnc_OperationRelease;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_result","COMPLETE",[""]],["_reason","COMPLETE",[""]]];
if (isNull _group || {!local _group}) exitWith {false};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {false};
if ((_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])) exitWith {false};
// Completion queued before a takeover is no longer an owned physical outcome. Retire only the
// matching generation as cancelled; never publish COMPLETE over a curator/specialist handover.
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {
    private _handoverReason=["EXTERNAL","ZEUS"] select ([_group] call WAIT_fnc_CortexZeusHeld);
    [_group,_generation,_handoverReason] call WAIT_fnc_OperationCancel;
    false
};
[_group,_operation,_reason] call WAIT_fnc_OperationRestore;
[_group,createHashMap,objNull,[],"RELEASE",_generation] call WAIT_fnc_CortexVehicleReverseStep;
[_group,_generation] call WAIT_fnc_CortexGroupMoveClear;
// Only an on-foot operation can have acquired a danger posture lease. Air, vehicle and naval
// operations share the generation record without touching their native combat state on release.
private _dangerActor=objNull;
if (_operation getOrDefault ["dangerPosture",false]) then {
    _dangerActor=[_group] call WAIT_fnc_CortexGroupAnchor;
    if (isNull _dangerActor) then {_dangerActor=leader _group};
    [_dangerActor,"RELEASE"] call WAIT_fnc_DangerReact;
};
_group setVariable ["WAIT_Operation",nil,true];
_group setVariable ["WAIT_OperationResult",[_operation getOrDefault ["intent",""],toUpperANSI _result,_generation,serverTime,toUpperANSI _reason],true];
// Completion can return a group directly to a still-live contact. Reclassify only that existing
// bounded context after the movement owner is gone, so the group keeps its combat posture without
// receiving a second route, target or firing controller. External ownership is rejected downstream.
private _dangerResponse=_group getVariable ["WAIT_Danger_Response",[]];
if (_operation getOrDefault ["dangerPosture",false] && {count _dangerResponse == 5}
    && {(_dangerResponse select 4) == (_group getVariable ["WAIT_Danger_Generation",-1])}
    && {time < (_dangerResponse select 3)}) then {
    private _dangerEvent=_dangerResponse select [0,4];
    private _dangerAction=[_group,_dangerEvent] call WAIT_fnc_DangerActionSelect;
    [_dangerActor,_dangerEvent select 0,_dangerEvent select 1,_dangerAction] call WAIT_fnc_DangerReact;
};
true

/*
 * Author: WaldoTheWarfighter
 * Purpose: Completes a matching WAIT operation after its physical outcome is known.
 * Locality/authority: Current group owner only.
 * Repeat/JIP: A replaced operation is not restored or reported as complete. The completion record is public.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 result <STRING, COMPLETE>; 3 reason <STRING, COMPLETE>.
 * Return Value: BOOL - true when the matching operation was released.
 * Current callers: OperationStep and finite feature completion paths.
 * Example: [group player,4,"COMPLETE","OBJECTIVE_REACHED"] call WAIT_fnc_OperationRelease;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_result","COMPLETE",[""]],["_reason","COMPLETE",[""]]];
if (isNull _group || {!local _group}) exitWith {false};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {false};
[_group,_generation] call WAIT_fnc_CortexGroupMoveClear;
// Only an on-foot operation can have acquired a danger posture lease. Air, vehicle and naval
// operations share the generation record without touching their native combat state on release.
if (_operation getOrDefault ["dangerPosture",false]) then {
    private _dangerActor=[_group] call WAIT_fnc_CortexGroupTransmitter;
    if (isNull _dangerActor) then {_dangerActor=leader _group};
    [_dangerActor,"RELEASE"] call WAIT_fnc_DangerReact;
};
_group setVariable ["WAIT_Operation",nil,true];
_group setVariable ["WAIT_OperationResult",[_operation getOrDefault ["intent",""],toUpperANSI _result,_generation,serverTime,toUpperANSI _reason],true];
true

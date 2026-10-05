/*
 * Author: WaldoTheWarfighter
 * Purpose: Cancels one matching WAIT operation and removes only its owned movement state.
 * Locality/authority: Current group owner only; callers forward before invoking when required.
 * Repeat/JIP: A missing or superseded generation is a no-op. The cancellation result is public for diagnostics and JIP inspection.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 reason <STRING, CANCELLED>.
 * Return Value: BOOL - true when the matching operation was cancelled.
 * Current callers: OperationStart, Zeus handover, release and recovery failure paths.
 * Example: [group player,4,"ZEUS"] call WAIT_fnc_OperationCancel;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_reason","CANCELLED",[""]]];
if (isNull _group || {!local _group}) exitWith {false};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {false};
_operation set ["cancelReason",toUpperANSI _reason];
_operation set ["phase","CANCELLED"];
[_group,_generation] call WAIT_fnc_CortexGroupMoveClear;
// Only an on-foot operation can have acquired a danger posture lease. Air, vehicle and naval
// operations share the generation record without touching their native combat state on release.
if (_operation getOrDefault ["dangerPosture",false]) then {[leader _group,"RELEASE"] call WAIT_fnc_DangerReact};
_group setVariable ["WAIT_Operation",nil,true];
_group setVariable ["WAIT_OperationResult",[_operation getOrDefault ["intent",""],"CANCELLED",_generation,serverTime,toUpperANSI _reason],true];
true

/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one owner-local finite convoy brain for a registered convoy snapshot.
 * Locality / Authority: Runs only where the convoy group is local. The FSM owns convoy intent and transitions; physical spacing and route work remains a bounded shared-scheduler callback.
 * Repeat/JIP: Registry revision and local job token invalidate older brains after reconfiguration, JIP replay or locality migration. A matching active brain is reused.
 * Arguments: 0 group <GROUP>; 1 configuration <ARRAY>; 2 registry revision <NUMBER>; 3 local job token <STRING>.
 * Return Value: Boolean - true when the current convoy brain exists on this owner.
 * Current callers: WAIT_fnc_ConvoySync and WAIT_fnc_ConvoyHeadlessAdoptLocal.
 * Example: [convoyGroup,_configuration,4,"4:2:SYNC"] call WAIT_fnc_ConvoyOperationStart;
 */
params [["_group",grpNull,[grpNull]],["_configuration",[],[[]]],["_registryRevision",-1,[0]],["_jobToken","",[""]]];
if (isNull _group || {!local _group} || {count _configuration < 8} || {_registryRevision < 0}) exitWith {false};
private _current=_group getVariable ["WAIT_Convoy_Brain",createHashMap];
if (count _current > 0 && {!(_current getOrDefault ["cancelled",false])} && {(_current getOrDefault ["registryRevision",-2]) == _registryRevision} && {(_current getOrDefault ["jobToken",""]) isEqualTo _jobToken}) exitWith {true};
if (count _current > 0) then {_current set ["cancelled",true];_current set ["cancelReason","REPLACED"]};
private _reason=toUpperANSI (_configuration param [8,"NONE"]);
private _phase=if ((_configuration param [5,"TRAVEL"]) == "HALT") then {switch (_reason) do {case "ARRIVED":{"ARRIVED"};case "AMBUSH":{"CONTACT_HOLD"};case "MANUAL":{"ORDERED_HOLD"};default {"OBSTRUCTION"}}} else {"CRUISE"};
private _brain=createHashMapFromArray [["group",_group],["configuration",_configuration],["registryRevision",_registryRevision],["jobToken",_jobToken],["phase",_phase],["pending",false],["completed",false],["finished",false],["cancelled",false],["cancelReason",""],["nextAt",time],["lastStepAt",-1],["lastDelay",-1],["queuedAt",-1],["watchdogCount",0],["spacingPairs",0],["recoveryActors",0]];
_group setVariable ["WAIT_Convoy_Brain",_brain];
_group setVariable ["WAIT_Convoy_Brain_State",[_phase,_configuration param [0,-1],_registryRevision,serverTime,"STARTED"],true];
private _handle=[_group,_registryRevision,_configuration,_brain] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\convoyOperation.fsm";
_group setVariable ["WAIT_Convoy_Brain_FSM",_handle];
true

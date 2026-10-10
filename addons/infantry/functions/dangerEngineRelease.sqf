/*
 * Author: WaldoTheWarfighter
 * Purpose: Release WAIT's finite weak danger stance without overwriting a newer owner.
 * Locality / Authority: Runs where the AI soldier is local when the engine danger FSM finishes.
 * Repeat/JIP: Repeat-safe and machine-local. Always clears the completed response marker. Restores
 * the recorded prior stance only while the actor still has WAIT's exact applied stance and no player,
 * Zeus or specialist controller has taken ownership. New leases also bind operation generation, owner epoch and group; replacement work cannot inherit the restoration.
 * Arguments: 0: soldier <OBJECT>, objNull.
 * Return Value: Boolean - true when WAIT restored its exact owned stance, otherwise false.
 * Current callers: Engine-loaded infantry danger FSM Finished state.
 * Example: [cursorObject] call WAIT_fnc_DangerEngineRelease;
 */

params [["_actor",objNull,[objNull]]];
if (isNull _actor) exitWith {false};
// This marker describes the currently executing engine-FSM action. Keeping it after Finished made
// diagnostics report a response which no longer existed and let a later owner inherit stale state.
// Clear it even when there was no stance to restore or locality changed during the response.
_actor setVariable ["WAIT_Danger_EngineResponse",nil];
private _lease=_actor getVariable ["WAIT_Danger_EngineStanceLease",[]];
if (count _lease < 3) exitWith {false};
_actor setVariable ["WAIT_Danger_EngineStanceLease",nil];
private _evidence={
    params ["_reason"];
    _actor setVariable ["WAIT_Danger_EngineReleaseEvidence",[serverTime,_reason,+_lease,unitPos _actor]];
    false
};
if (!local _actor || {!alive _actor} || {isPlayer _actor}) exitWith {["LOST_ACTOR_AUTHORITY"] call _evidence};
private _group=group _actor;
if (isNull _group || {!local _group} || {[_group,false,_actor] call WAIT_fnc_CortexExternalTakeover}
    || {[_group] call WAIT_fnc_CortexZeusHeld}
    || {[_actor] call WAIT_fnc_CompatibilityExternalControl}) exitWith {["EXTERNAL_OWNER"] call _evidence};

if (count _lease >= 6 && {(_lease select 3) != (_group getVariable ["WAIT_OperationGeneration",0])
    || {(_lease select 4) != (_group getVariable ["WAIT_AIPass_Epoch",0])}
    || {(_lease select 5) != _group}}) exitWith {["NEW_OPERATION_OR_OWNER"] call _evidence};
if (!([_actor] call WAIT_fnc_CortexCombatEffective)
    || {currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}) exitWith {["NATIVE_TASK_OR_MEDICAL"] call _evidence};

private _prior=toUpperANSI (_lease param [0,"AUTO",[""]]);
private _applied=toUpperANSI (_lease param [1,"",[""]]);
if (_applied == "" || {toUpperANSI (unitPos _actor) != _applied}) exitWith {["STANCE_CHANGED"] call _evidence};
if !(_prior in ["AUTO","UP","MIDDLE","DOWN"]) then {_prior="AUTO"};
_actor setUnitPosWeak _prior;
["RESTORED"] call _evidence;
true

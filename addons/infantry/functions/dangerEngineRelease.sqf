/*
 * Author: WaldoTheWarfighter
 * Purpose: Release WAIT's finite weak danger stance without overwriting a newer owner.
 * Locality / Authority: Runs where the AI soldier is local when the engine danger FSM finishes.
 * Repeat/JIP: Repeat-safe and machine-local. Always clears the completed response marker. Restores
 * the recorded prior stance only while the actor still has WAIT's exact applied stance and no player,
 * Zeus or specialist controller has taken ownership.
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
if (!local _actor || {!alive _actor} || {isPlayer _actor}) exitWith {false};
private _group=group _actor;
if (isNull _group || {!local _group} || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[_group] call WAIT_fnc_CortexZeusHeld}) exitWith {false};

private _prior=toUpperANSI (_lease param [0,"AUTO",[""]]);
private _applied=toUpperANSI (_lease param [1,"",[""]]);
if (_applied == "" || {toUpperANSI (unitPos _actor) != _applied}) exitWith {false};
if !(_prior in ["AUTO","UP","MIDDLE","DOWN"]) then {_prior="AUTO"};
_actor setUnitPosWeak _prior;
true

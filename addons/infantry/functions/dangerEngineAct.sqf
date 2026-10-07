/*
 * Author: WaldoTheWarfighter
 * Purpose: Apply one bounded immediate danger posture without taking movement, target or firing ownership.
 * Locality / Authority: Runs only for the local AI soldier after ownership and order classification.
 * Repeat/JIP: Uses weak stance suggestions which native AI may replace. It records one expiring,
 * machine-local response sample for diagnostics; group posture restoration remains owned by the
 * finite group danger response. It never creates a movement, target or firing lease.
 * Arguments: 0: soldier <OBJECT>, objNull; 1: mode <STRING>, ASSESS; 2: selected record <ARRAY>, [].
 * Return Value: Number - short observation deadline in seconds.
 * Current callers: Engine-loaded infantry danger FSM action states.
 * Example: [cursorObject,"IMMEDIATE",[2,getPosATL cursorObject,time + 1,objNull]] call WAIT_fnc_DangerEngineAct;
 */

params [["_actor",objNull,[objNull]],["_mode","ASSESS",[""]],["_record",[],[[]]]];
if (isNull _actor || {!local _actor} || {!alive _actor} || {isPlayer _actor}) exitWith {0};
private _group=group _actor;
if (isNull _group || {!local _group} || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[_group] call WAIT_fnc_CortexZeusHeld}) exitWith {0};
private _delays=createHashMapFromArray [["FORCED",0.75],["VEHICLE",1],["IMMEDIATE",1],["HIDE",1.25],["ENGAGE",1],["ASSESS",0.75]];
private _delay=_delays getOrDefault [_mode,0.75];
private _cause=_record param [0,-1,[0]];

// Forced orders and vehicle crews already have an engine movement owner. Recording the response is
// useful, but changing their posture would compete with that owner. Foot soldiers receive only a
// weak posture suggestion; native combat and the generation-owned group operation remain free to
// replace it immediately.
if (_mode == "IMMEDIATE") then {
    private _hardCover=(getSuppression _actor > 0.55) || {_cause in [2,4]} || {currentCommand _actor == "STOP"};
    _actor setUnitPosWeak (["MIDDLE","DOWN"] select _hardCover);
};
if (_mode == "HIDE") then {
    _actor setUnitPosWeak (["MIDDLE","DOWN"] select (getSuppression _actor > 0.25 || {_cause in [5,6]}));
};

private _stats=_group getVariable ["WAIT_Danger_EngineStats",createHashMap];
private _modes=_stats getOrDefault ["modes",createHashMap];
_modes set [_mode,((_modes getOrDefault [_mode,0])+1) min 100000];
_stats set ["modes",_modes];
_stats set ["lastMode",_mode];
_stats set ["lastActor",_actor];
_stats set ["lastActionAt",time];
_group setVariable ["WAIT_Danger_EngineStats",_stats];
_actor setVariable ["WAIT_Danger_EngineResponse",[_mode,_cause,time,time+_delay]];
_delay

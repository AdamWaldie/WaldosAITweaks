/*
 * Author: WaldoTheWarfighter
 * Purpose: Apply one bounded immediate danger posture without taking movement, target or firing ownership.
 * Locality / Authority: Runs only for the local AI soldier after ownership and order classification.
 * Repeat/JIP: Uses weak stance suggestions which native AI may replace. No persistent state is created;
 * group posture restoration remains owned by the finite group danger response.
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
if (_mode == "IMMEDIATE") then {
    _actor setUnitPosWeak (["MIDDLE","DOWN"] select (getSuppression _actor > 0.55 || {currentCommand _actor == "STOP"}));
};
if (_mode == "HIDE") then {_actor setUnitPosWeak "DOWN"};
private _delays=createHashMapFromArray [["FORCED",0.75],["VEHICLE",1],["IMMEDIATE",1],["HIDE",1.25],["ENGAGE",1],["ASSESS",0.75]];
_delays getOrDefault [_mode,0.75]

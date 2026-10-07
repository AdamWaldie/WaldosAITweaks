/*
 * Author: WaldoTheWarfighter
 * Purpose: Convert one bounded engine danger queue into WAIT group danger observations.
 * Locality / Authority: Runs unscheduled on the machine local to the affected AI soldier. It records
 * causes and approximate positions only; it never reveals, targets, moves or changes the actor.
 * Repeat/JIP: Safe to repeat. DangerRequest coalesces each cause and generation on the current group
 * owner. A locality change ends the old engine FSM and fresh engine danger starts on the new owner.
 * Arguments: 0: affected soldier <OBJECT>, objNull; 1: engine records <ARRAY>, each
 * [cause number, ATL/ASL position, expiry number, source object], [].
 * Return Value: Boolean - true when at least one record was accepted by WAIT.
 * Current callers: Engine-loaded infantry danger FSM.
 * Example: [cursorObject,[[2,getPosATL cursorObject,time + 1,objNull]]] call WAIT_fnc_DangerEngineSubmit;
 */

params [['_actor',objNull,[objNull]],['_records',[],[[]]]];
if (isNull _actor || {!local _actor} || {!alive _actor} || {isPlayer _actor}) exitWith {false};
private _group=group _actor;
if (isNull _group || {!local _group}
    || {!(missionNamespace getVariable ['WAIT_AIPass_Active',false])}
    || {!([_group,'WAIT_AIPass_Danger_Enable',true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!(_group getVariable ['WAIT_AIPass_Managed',false])}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[] call WAIT_fnc_CortexIsPaused}) exitWith {false};

private _causeNames=['DETECTED','GUNFIRE','HIT','DETECTED','EXPLOSION','CASUALTY','CASUALTY','SCREAM','DETECTED','SUPPRESSED'];
private _latest=createHashMap;
{
    if (_x isEqualType [] && {count _x >= 3}) then {
        private _cause=_x param [0,-1,[0]];
        private _position=_x param [1,[],[[]]];
        private _expires=_x param [2,time,[0]];
        if (_cause >= 0 && {_cause < count _causeNames} && {count _position >= 2} && {_expires >= time - 0.25}) then {
            if (count _position == 2) then {_position pushBack ((getPosATL _actor) select 2)};
            if (count _position == 3) then {_latest set [_causeNames select _cause,+_position]};
        };
    };
} forEach (_records select [0,12]);

private _accepted=false;
{
    if ([_actor,_x,_latest get _x] call WAIT_fnc_DangerRequest) then {_accepted=true};
} forEach (keys _latest);
if (_accepted) then {
    private _count=_group getVariable ['WAIT_Danger_EngineEvents',0];
    _group setVariable ['WAIT_Danger_EngineEvents',(_count + 1) min 100000];
    _group setVariable ['WAIT_Danger_EngineLastAt',time];
};
_accepted

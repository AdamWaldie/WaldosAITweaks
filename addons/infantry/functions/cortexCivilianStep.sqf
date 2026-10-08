/*
 * Author: WaldoTheWarfighter
 * Advances one finite civilian danger escape through WAIT's shared owner-local scheduler.
 * The step observes physical progress, permits one recovery reissue after a genuine stall and then
 * retires. It restores only CARELESS/FULL/UP values still owned by this generation. Zeus, player,
 * locality and specialist/external ownership cancel immediately without issuing another command.
 *
 * Locality / Authority: runs only on the current owner of the civilian's group and unit.
 * Repeat/JIP: generation and locality scoped; stale or migrated jobs retire without replay.
 *
 * Arguments:
 * 0: state <HASHMAP> containing unit, group, generation, destination and restore values
 *
 * Return Value:
 * Number - seconds until the next step, or -1 when the response is finished.
 *
 * Current callers: WAIT_fnc_CortexCivilianReact through WAIT_fnc_CortexQueueJob.
 *
 * Example:
 * [WAIT_fnc_CortexCivilianStep,_state,2,"WAIT_CIVILIAN_12"] call WAIT_fnc_CortexQueueJob;
 * Result: the escape is observed without a private loop or repeated destination churn.
 */

params [["_state",createHashMap,[createHashMap]]];
private _unit=_state getOrDefault ["unit",objNull];
private _group=_state getOrDefault ["group",grpNull];
private _generation=_state getOrDefault ["generation",-1];
private _destination=_state getOrDefault ["destination",[]];
private _finish={
    if (!isNull _unit && {local _unit}
        && {_generation == (_unit getVariable ["WAIT_Cortex_CivilianGeneration",-2])}
        && {!([_group] call WAIT_fnc_CortexExternalTakeover)}) then {
        private _restore=_state getOrDefault ["restore",[]];
        if (count _restore == 3) then {
            if (behaviour _unit == "CARELESS") then {_unit setBehaviour (_restore select 0)};
            if (speedMode _group == "FULL") then {_group setSpeedMode (_restore select 1)};
            if (unitPos _unit == "UP") then {_unit setUnitPos (_restore select 2)};
        };
        _unit setVariable ["WAIT_Cortex_CivilianReaction",[],true];
    };
    -1
};
if (isNull _unit || {isNull _group} || {!local _unit} || {!local _group} || {!alive _unit}
    || {isPlayer _unit} || {_generation != (_unit getVariable ["WAIT_Cortex_CivilianGeneration",-2])}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {-1};
if !(missionNamespace getVariable ["WAIT_AIPass_CivilianReaction_Enable",true]) exitWith {call _finish};
if (_destination isEqualTo [] || {serverTime >= (_state getOrDefault ["until",0])}
    || {_unit distance2D _destination < 6}) exitWith {call _finish};

private _position=getPosATL _unit;
private _lastPosition=_state getOrDefault ["lastPosition",_position];
if (_position distance2D _lastPosition >= 3) then {
    _state set ["lastPosition",_position];
    _state set ["lastProgressAt",serverTime];
};
if (serverTime-(_state getOrDefault ["lastProgressAt",serverTime]) >= 8) then {
    if (_state getOrDefault ["reissued",false]) exitWith {call _finish};
    // One engine-native retry is sufficient. A second stall is reported by retirement rather than
    // allowing a civilian to hold the shared queue or repeatedly overwrite movement.
    _unit doMove _destination;
    _state set ["reissued",true];
    _state set ["lastProgressAt",serverTime];
};
2

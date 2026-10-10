/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Commits a defence line's reserve once, to where it is needed.
 *
 * Called from WAIT_fnc_CortexGroupTick while a defending group is in CONTACT. The reserve moves to
 * the line spot of a fallen soldier when a third of the line is lost, or to the line spot nearest an
 * enemy believed within 60 m of the line. Each lateral reinforcement slot contracts towards that
 * already validated line spot when rough terrain would otherwise strand a reserve soldier. Only the
 * committed reserve is reapplied: the existing line retains its hold, watch sector and route generation.
 * The reserve then holds at the reinforced line, watching the same sector.
 * Unconscious, captive and specialist-controlled actors cannot be committed. Loss checks count
 * combat-effective line members rather than treating every living member as an available defender.
 * Locality and authority: call where the group is local.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP>
 * 2: enemies <ARRAY> - from WAIT_fnc_CortexKnowledge
 *
 * Return Value:
 * Boolean - true when the reserve was committed
 *
 * Example:
 * [_group, _state, _enemies] call WAIT_fnc_CortexDefendStep;
 * Result: the reserve fills the gap where the line was broken.
 *
 * Current caller: WAIT_fnc_CortexGroupTick.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_enemies", [], [[]]]];
if (isNull _group || {!local _group}) exitWith {false};
if (_state getOrDefault ["reserveCommitted", false] || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
private _lineUnits = (units _group) select {((_x getVariable ["WAIT_AIPass_DefendPos", []]) param [2, ""]) == "LINE"};
private _reserve = (units _group) select {
    [_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
        && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}
        && {((_x getVariable ["WAIT_AIPass_DefendPos", []]) param [2, ""]) == "RESERVE"}
};
if (_reserve isEqualTo [] || {_lineUnits isEqualTo []}) exitWith {false};
private _aliveLine = _lineUnits select {[_x] call WAIT_fnc_CortexCombatEffective};
private _target = [];
if (count _aliveLine / count _lineUnits <= 0.67) then {
    private _fallen = _lineUnits select {!([_x] call WAIT_fnc_CortexCombatEffective)};
    if (_fallen isNotEqualTo []) then {_target = (_fallen select 0) getVariable ["WAIT_AIPass_DefendPos", []]};
};
if (_target isEqualTo []) then {
    {
        private _assignment = _x getVariable ["WAIT_AIPass_DefendPos", []];
        private _spot = _assignment param [0, []];
        if (count _spot >= 2 && {_enemies findIf {((_x select 1) distance2D _spot) < 60} >= 0}) exitWith {_target = _assignment};
    } forEach _lineUnits;
};
if (_target isEqualTo []) exitWith {false};
_target params ["_spot", "_sector"];
{
    private _position = _spot getPos [3 + _forEachIndex * 3, _sector + 90];
    if (surfaceIsWater _position || {((surfaceNormal _position) select 2) < 0.55}) then {
        private _distance=3+_forEachIndex*3;
        {
            private _alternative=_spot getPos [_distance*_x,_sector+90];
            if (!surfaceIsWater _alternative && {((surfaceNormal _alternative) select 2) >= 0.55}) exitWith {_position=_alternative};
        } forEach [0.65,0.35,0];
    };
    if !([_group,false,_x] call WAIT_fnc_CortexExternalTakeover) then {
        _x setVariable ["WAIT_AIPass_DefendPos", [_position, _sector, "LINE"], true];
    };
} forEach _reserve;
_state set ["reserveCommitted", true];
[_group,_reserve] call WAIT_fnc_CortexDefendApplyLocal;
diag_log format ["[WAIT] %1 committed reserve (%2 soldiers)", _group, count _reserve];
true


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
 * Unconscious, captive, mounted, reserved and specialist-controlled actors cannot be committed.
 * Only settled reserve soldiers with idle/STOP commands and a matching HOLD receipt are available; newer individual orders
 * remain untouched. Reinforcement geometry is planned and checked for overlap before publication.
 * An invalid layout leaves the reserve uncommitted for a later decision tick. Loss checks count
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
private _reserveAvailable={
    params ["_actor"];
    private _assignment=_actor getVariable ["WAIT_AIPass_DefendPos",[]];
    private _receipt=_actor getVariable ["WAIT_Cortex_DefendMove",[]];
    private _held=_receipt isEqualType [] && {count _receipt == 6}
        && {(_receipt select 0) isEqualTo _group} && {(_receipt select 4) isEqualTo _assignment}
        && {(_receipt select 5) == "HOLD"}
        && {[1,2] findIf {!((_receipt select _x) isEqualType 0) || {!finite (_receipt select _x)} || {(_receipt select _x) < 0}} < 0}
        && {(_receipt select 2) <= (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {(_receipt select 3) isEqualType []} && {count (_receipt select 3) == 3}
        && {(_receipt select 3) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {(getPosATL _actor) vectorDistance (_receipt select 3) <= 3};
    _held && {local _actor} && {group _actor == _group} && {isNull objectParent _actor}
        && {!isPlayer _actor} && {isNull remoteControlled _actor}
        && {[_actor] call WAIT_fnc_CortexCombatEffective}
        && {!([_actor] call WAIT_fnc_CortexActorMoveReserved)}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {_actor getVariable ["WAIT_AIPass_DefendHolding",false]}
        && {currentCommand _actor in ["","STOP"]}
        && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
};
private _reserve = (units _group) select {
    [_x] call _reserveAvailable
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
if (count _spot != 3 || {_spot findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!(_sector isEqualType 0)} || {!finite _sector} || {count _reserve > 64}) exitWith {false};
private _placements=[];
private _taken=_aliveLine apply {+((_x getVariable ["WAIT_AIPass_DefendPos",[]]) select 0)};
private _layoutValid=true;
{
    private _position = _spot getPos [3 + _forEachIndex * 3, _sector + 90];
    if (surfaceIsWater _position || {((surfaceNormal _position) select 2) < 0.55}) then {
        private _distance=3+_forEachIndex*3;
        {
            private _alternative=_spot getPos [_distance*_x,_sector+90];
            if (!surfaceIsWater _alternative && {((surfaceNormal _alternative) select 2) >= 0.55}) exitWith {_position=_alternative};
        } forEach [0.65,0.35,0];
    };
    if (surfaceIsWater _position || {((surfaceNormal _position) select 2) < 0.55}
        || {_taken findIf {_x distance2D _position < 1} >= 0}) then {_layoutValid=false};
    _taken pushBack +_position;
    _placements pushBack [_x,[_position,_sector,"LINE"]];
} forEach _reserve;
// No assignment writes until every selected actor and reinforcement slot remains usable.
if (!_layoutValid || {!local _group} || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {_reserve findIf {!([_x] call _reserveAvailable)} >= 0}) exitWith {false};
{_x params ["_actor","_assignment"];_actor setVariable ["WAIT_AIPass_DefendPos",_assignment,true]} forEach _placements;
_state set ["reserveCommitted", true];
[_group,_reserve,_reserve] call WAIT_fnc_CortexDefendApplyLocal;
diag_log format ["[WAIT] %1 committed reserve (%2 soldiers)", _group, count _reserve];
true


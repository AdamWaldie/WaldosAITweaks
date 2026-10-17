/*
 * Author: WaldoTheWarfighter
 * Purpose: Validates an exterior building observation candidate without issuing commands.
 * Locality/authority: Read-only on any machine; caller retains operation and movement authority.
 * Repeat/JIP: Recomputes current geometry and occupancy; publishes nothing and installs no handles.
 * Arguments: 0 actor <OBJECT, objNull>; 1 building <OBJECT, objNull>; 2 candidate ATL <ARRAY, []>;
 * 3 selected exit ATL <ARRAY, []>; 4 watch ATL <ARRAY, []>; 5 exits <ARRAY, []>;
 * 6 reserved ATL positions <ARRAY, []>; 7 committed observer lanes <ARRAY, []>,
 * each [post ATL, watch ATL]; 8 diagnostics <BOOL, false>. Limits: 64 exits,
 * 128 reserved posts and 64 lanes. Every coordinate must be a finite numeric triple;
 * malformed/over-budget input refuses before any world/geometry query.
 * Diagnostic mode returns the same acceptance result with read-only check measurements.
 * Return Value: BOOL by default; diagnostic mode returns [BOOL, named check pairs ARRAY].
 * Supported observation geometry never establishes path arrival or room safety.
 * Current callers: WAIT_fnc_BuildingOperationStep and WAIT_fnc_CortexGarrisonApplyLocal.
 * Example: [_unit,_house,_spot,_exit,_watch,[_exit],[]] call WAIT_fnc_BuildingExteriorCandidate;
 */
params [["_actor",objNull,[objNull]],["_building",objNull,[objNull]],
    ["_target",[],[[]]],["_entry",[],[[]]],["_watch",[],[[]]],
    ["_entries",[],[[]]],["_taken",[],[[]]],["_observerLanes",[],[[]]],["_diagnostics",false,[true]]];
private _positionValid={
    params ["_position"];
    _position isEqualType [] && {count _position == 3}
        && {_position findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
if (isNull _actor || {isNull _building}
    || {!([_target] call _positionValid)} || {!([_entry] call _positionValid)}
    || {!([_watch] call _positionValid)} || {count _entries > 64} || {count _taken > 128}
    || {count _observerLanes > 64}
    || {_entries findIf {!([_x] call _positionValid)} >= 0}
    || {_taken findIf {!([_x] call _positionValid)} >= 0}
    || {_observerLanes findIf {
        !(_x isEqualType []) || {count _x != 2}
            || {!([_x select 0] call _positionValid)}
            || {!([_x select 1] call _positionValid)}
    } >= 0}) exitWith {
    if (_diagnostics) then {[false,[["inputs",false]]]} else {false}
};
private _bounds=boundingBoxReal _building;
private _model=_building worldToModel _target;
private _minimum=_bounds select 0;
private _maximum=_bounds select 1;
private _exterior=(_model select 0) < (_minimum select 0)-0.5
    || {(_model select 0) > (_maximum select 0)+0.5}
    || {(_model select 1) < (_minimum select 1)-0.5}
    || {(_model select 1) > (_maximum select 1)+0.5};
// Cover geometry is not a native path receipt. Exclude configured same-floor exit vicinity and
// validate standing space at the endpoint. Native pathfinding may route around corners.
private _blocksExit=_entries findIf {
    _target distance2D _x < 3 && {abs (((AGLToASL _target) select 2)-((AGLToASL _x) select 2)) <= 1}
} >= 0;
private _observationClear=!terrainIntersectASL [
    (AGLToASL _target) vectorAdd [0,0,1.6],AGLToASL _watch]
    && {(lineIntersectsSurfaces [(AGLToASL _target) vectorAdd [0,0,1.6],
        AGLToASL _watch,_actor,objNull,true,1,"VIEW","NONE"]) isEqualTo []};
// Prospective posts must not occlude another committed observer or have their own view
// blocked by that future actor. Actual terrain/object visibility is still checked above.
private _blocksSegment = {
    params ["_point","_start","_end"];
    private _axis=_end vectorDiff _start;
    private _lengthSquared=_axis vectorDotProduct _axis;
    if (_lengthSquared < 0.01) exitWith {false};
    private _fraction=((_point vectorDiff _start) vectorDotProduct _axis)/_lengthSquared;
    _fraction > 0 && {_fraction < 1}
        && {_point vectorDistance (_start vectorAdd (_axis vectorMultiply _fraction)) < 1.2}
};
private _candidateBody=(AGLToASL _target) vectorAdd [0,0,1.1];
private _candidateEye=(AGLToASL _target) vectorAdd [0,0,1.6];
private _laneBlocked=_observerLanes findIf {
    private _postASL=AGLToASL (_x select 0);
    [_candidateBody,_postASL vectorAdd [0,0,1.6],AGLToASL (_x select 1)] call _blocksSegment
        || {[_postASL vectorAdd [0,0,1.1],_candidateEye,AGLToASL _watch] call _blocksSegment}
} >= 0;
private _separated=_taken findIf {_target distance2D _x < 3} < 0
    && {(_target nearEntities ["CAManBase",1.2]) select {_x != _actor} isEqualTo []};
private _dry="NOT_CHECKED";
private _slopeZ="NOT_CHECKED";
private _standingChecked=false;
private _standingClear=false;
private _valid=_observationClear && {!_laneBlocked} && {_separated} && {_exterior} && {!_blocksExit} && {_target distance2D _entry >= 3}
&& {_target distance2D _entry <= 18} && {_dry=!surfaceIsWater _target; _dry}
&& {_slopeZ=(surfaceNormal _target) select 2; _slopeZ >= 0.65}
&& {
    _standingChecked=true;
    _standingClear=(lineIntersectsSurfaces [(AGLToASL _target) vectorAdd [0,0,0.15],
        (AGLToASL _target) vectorAdd [0,0,1.8],_actor,objNull,true,1,"GEOM","NONE"]) isEqualTo [];
    _standingClear
};
if (_diagnostics) exitWith {[_valid,[
    ["outside",_exterior],["exitClear",!_blocksExit],["view",_observationClear],
    ["plannedLanesClear",!_laneBlocked],["separated",_separated],
    ["exitDistance",_target distance2D _entry],["dry",_dry],
    ["slopeZ",_slopeZ],
    ["standing",if (_standingChecked) then {_standingClear} else {"NOT_CHECKED"}]
]]};
_valid

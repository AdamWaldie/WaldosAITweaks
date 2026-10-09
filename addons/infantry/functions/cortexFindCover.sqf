/*
 * Author: WaldoTheWarfighter
 * Finds a covered position near a point, on the far side of a solid object from a threat.
 *
 * The candidate sits outside the
 * object's rotated horizontal bounds on the side away from the threat, and it is accepted only if a
 * line-of-fire ray from the threat's eye height to the candidate's chest height is blocked. Candidates inside the object's bounds or under its roof are rejected. Trees, rocks, walls, fences, hides and buildings count;
 * bushes do not (they conceal but do not stop rounds). The engine's `findCover` is not implemented in
 * Arma 3, so this is scripted.
 * Locality and authority: read-only; callable anywhere.
 *
 * Arguments:
 * 0: position <ARRAY> - ATL point to search around
 * 1: threat <ARRAY> - ATL position of the threat
 * 2: radius <NUMBER> - search radius in metres (optional, default: 12)
 * 3: reserved <ARRAY> - ATL positions already taken by squad-mates (optional, default: [])
 *
 * 4: group <GROUP> - optional grpNull, supplies per-group feature exclusions.
 * Repeat/JIP: read-only; candidates are recalculated only when a caller requests a search.
 * Return Value:
 * Array - [coverPosATL, found <BOOL>]; the original position when no cover qualifies
 *
 * Example:
 * ([_boundPoint, _enemyPos, 12, _taken] call WAIT_fnc_CortexFindCover) params ["_spot", "_found"];
 * Result: a nearby spot with solid cover between it and the enemy, if one exists.
 *
 * Current callers: WAIT_fnc_CortexFlankStep, WAIT_fnc_CortexGrenadeCheck and WAIT_fnc_CortexAntiArmour.
 */

params [["_position", [], [[]]], ["_threat", [], [[]]], ["_radius", 12, [0]], ["_reserved", [], [[]]], ["_group",grpNull,[grpNull]]];
if (count _position < 2 || {count _threat < 2}) exitWith {[_position, false]};
_radius = (_radius max 1) min 25;
private _validate = [_group,"WAIT_AIPass_CoverValidation_Enable",true] call WAIT_fnc_CortexFeatureEnabled;
private _objects = nearestTerrainObjects [_position, ["TREE", "SMALL TREE", "ROCK", "ROCKS", "WALL", "FENCE", "HIDE", "BUILDING", "HOUSE"], _radius, true, true];
if (count _objects > 10) then {_objects resize 10};
private _placed=(nearestObjects [_position, ["House", "Wall", "Strategic"], _radius, true]) select [0,10];
{_objects pushBackUnique _x} forEach _placed;
// Rank both sources together before the geometry budget. Appending placed cover after terrain
// and truncating immediately could discard a nearby wall behind ten more distant trees.
private _ranked=_objects apply {[_x distance2D _position,_forEachIndex,_x]};
_ranked sort true;
_objects=(_ranked select [0,10]) apply {_x select 2};
private _threatASL = (AGLToASL _threat) vectorAdd [0, 0, 1.6];
private _result = [];
{
    private _object = _x;
    private _bounds = boundingBoxReal _object;
    private _minimum=_bounds select 0;
    private _maximum=_bounds select 1;
    private _modelCentre=(_minimum vectorAdd _maximum) vectorMultiply 0.5;
    private _half=(_maximum vectorDiff _minimum) vectorMultiply 0.5;
    private _modelThreat=_object worldToModel _threat;
    private _away=_modelCentre vectorDiff _modelThreat;
    private _horizontal=[_away select 0,_away select 1,0];
    if (vectorMagnitude _horizontal < 0.01) then {_horizontal=[0,1,0]};
    private _direction=vectorNormalized _horizontal;
    // Intersect the threat-away ray with the rotated horizontal box. A capped circular
    // radius could leave a point inside a long wall or the footprint of a large house.
    private _edge=1e6;
    for "_axis" from 0 to 1 do {
        private _component=abs (_direction select _axis);
        if (_component > 0.001) then {_edge=_edge min ((_half select _axis)/_component)};
    };
    private _candidate=_object modelToWorld (_modelCentre vectorAdd (_direction vectorMultiply (_edge+0.8)));
    _candidate set [2, 0];
    private _candidateASL = AGLToASL _candidate;
    private _free = _candidate distance2D _position <= _radius
        && {!surfaceIsWater _candidate}
        && {_reserved findIf {_x distance2D _candidate < 2} < 0}
        && {(lineIntersectsSurfaces [_candidateASL vectorAdd [0, 0, 0.5], _candidateASL vectorAdd [0, 0, 20], objNull, objNull, true, 1]) findIf {(_x select 2) == _object || {(_x select 3) == _object}} < 0};
    if (_free && {_validate}) then {
        _free = (surfaceNormal _candidate select 2) >= 0.65
            && {(_candidate nearEntities ["CAManBase",1.2]) isEqualTo []}
            && {(lineIntersectsSurfaces [_candidateASL vectorAdd [0,0,0.15],_candidateASL vectorAdd [0,0,1.8],objNull,objNull,true,1,"GEOM","NONE"]) isEqualTo []};
        if (_free) then {
            {if ((lineIntersectsSurfaces [_candidateASL vectorAdd [0,0,0.8],(_candidateASL vectorAdd [0,0,0.8]) vectorAdd _x,objNull,objNull,true,1,"GEOM","NONE"]) isNotEqualTo []) exitWith {_free = false}} forEach [[0.45,0,0],[-0.45,0,0],[0,0.45,0],[0,-0.45,0]];
        };
    };
    if (_free) then {
        private _endASL = _candidateASL vectorAdd [0, 0, 1];
        // Start the object ray 2 m out from the threat: starting at the believed enemy position
        // would hit the enemy soldier (or his own cover) and make every spot look covered.
        private _rayStart = _threatASL vectorAdd ((_threatASL vectorFromTo _endASL) vectorMultiply 2);
        private _blocked = terrainIntersectASL [_threatASL, _endASL]
            || {(lineIntersectsSurfaces [_rayStart, _endASL, objNull, objNull, true, 1, "FIRE", "GEOM"]) isNotEqualTo []};
        if (_blocked) then {_result = [_candidate, true]};
    };
    if (_result isNotEqualTo []) exitWith {};
} forEach _objects;
if (_result isEqualTo []) then {[_position, false]} else {_result}

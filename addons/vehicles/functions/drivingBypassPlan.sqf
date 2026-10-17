/*
 * Author: WaldoTheWarfighter
 * Purpose: Proposes one physical left/right bypass around a freshly observed bounded solid object.
 * Locality / Authority: Read-only on vehicle owner; cannot issue a path, alter world objects or
 * acquire movement authority. The future finite executor must guard owner/route/command receipts.
 * Repeat/JIP: No state/handlers. One side per call, no internal retry or cached clearance. Never
 * replay an old proposal after movement/rotation/deletion or vehicle/owner changes.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 solid observation <ARRAY, []> from DrivingGeometryCap;
 * 2 side <NUMBER, 1> exactly -1 left or 1 right; 3 convoy envelope <ARRAY, []> optional
 * [halfWidth, halfLength, height] metres expanding the current vehicle only.
 * Return Value: ARRAY [valid BOOL, reason STRING, pointsATL ARRAY, pointsASL ARRAY,
 * obstacle transform ARRAY, vehicle transform ARRAY, rayCount NUMBER].
 * Limits: stationary STATIC object only (vehicle hulls must remain engine-off and unoccupied), observation <=1.5 seconds old/50 m away, vehicle <=8 km/h;
 * projected object span <=30 m, hull circumscribed clearance radius <=12 m. Five guide anchors
 * resample at <=5 m, at most 24 stations/279 support/body rays. No spawning or collision helpers.
 * The radius deliberately overbounds turn footprint; no turning-radius or native steering success
 * is implied. Unsupported terrain/moving objects, large hulls or missing support refuse.
 * Current callers: DrivingBypassStep and trusted diagnostic/script preflight.
 * Example: [truck1,_solidObservation,-1] call WAIT_fnc_DrivingBypassPlan;
 */
params [["_vehicle",objNull,[objNull]],["_observed",[],[[]]],["_side",1,[0]],["_envelope",[],[[]]]];
private _fail={params ["_reason",["_rays",0]];[false,_reason,[],[],[],[],_rays]};
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle} || {!canMove _vehicle}
    || {!(_vehicle isKindOf "LandVehicle")}) exitWith {["OWNER_UNAVAILABLE"] call _fail};
if (count _observed != 9 || {!(_side in [-1,1])}
    || {_envelope isNotEqualTo [] && {count _envelope != 3 || {
        _envelope findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x > 100}} >= 0
    }}}) exitWith {["INVALID_OBSERVATION"] call _fail};
private _obstacle=_observed select 1;
if (!(_obstacle isEqualType objNull) || {isNull _obstacle} || {(_observed select 5) != "STATIC"}
    || {!([_obstacle] call WAIT_fnc_DrivingBypassObstacleAvailable)} || {abs speed _vehicle > 8}) exitWith {["NOT_STATIC_BYPASS"] call _fail};
private _sampled=_observed select 3;private _gap=_observed select 2;
if (!(_sampled isEqualType 0) || {!finite _sampled} || {_sampled > time} || {time-_sampled > 1.5}
    || {!(_gap isEqualType 0)} || {!finite _gap} || {_gap < 0} || {_gap > 50}) exitWith {["STALE_OBSERVATION"] call _fail};
private _transform=[getPosWorld _obstacle,vectorDir _obstacle,vectorUp _obstacle];
if (_transform isNotEqualTo (_observed select 8)) exitWith {["OBSTACLE_CHANGED"] call _fail};
private _vehicleTransform=[getPosWorld _vehicle,vectorDir _vehicle,vectorUp _vehicle];
private _origin=getPosASL _vehicle;private _forward=vectorDir _vehicle;_forward set [2,0];_forward=vectorNormalized _forward;
private _right=[_forward select 1,-(_forward select 0),0];
private _bounds=boundingBoxReal _vehicle;private _low=_bounds select 0;private _high=_bounds select 1;
private _halfWidth=((abs (_low select 0)) max (abs (_high select 0))) max (_envelope param [0,0]);
private _halfLength=((abs (_low select 1)) max (abs (_high select 1))) max (_envelope param [1,0]);
private _height=((_high select 2)-(_low select 2)) max (_envelope param [2,0]);
private _radius=sqrt ((_halfWidth^2)+(_halfLength^2))+1;
if (_radius > 12) exitWith {["HULL_BUDGET"] call _fail};
private _other=boundingBoxReal _obstacle;private _otherLow=_other select 0;private _otherHigh=_other select 1;
if (_otherLow vectorDistance _otherHigh < 0.5) exitWith {["UNCERTAIN_OBSTACLE_HULL"] call _fail};
private _minX=1e9;private _maxX=-1e9;private _minY=1e9;private _maxY=-1e9;
{
    private _xCoord=_x;
    {private _yCoord=_x;{
        private _delta=(_obstacle modelToWorldWorld [_xCoord,_yCoord,_x]) vectorDiff _origin;
        private _lateral=_delta vectorDotProduct _right;private _along=_delta vectorDotProduct _forward;
        _minX=_minX min _lateral;_maxX=_maxX max _lateral;_minY=_minY min _along;_maxY=_maxY max _along;
    } forEach [_otherLow select 2,_otherHigh select 2];} forEach [_otherLow select 1,_otherHigh select 1];
} forEach [_otherLow select 0,_otherHigh select 0];
if (_maxX-_minX > 30 || {_maxY-_minY > 30} || {_minY <= _radius+6}) exitWith {["INSUFFICIENT_APPROACH_ROOM"] call _fail};
private _before=_minY-_radius-3;private _after=_maxY+_radius+10;
private _lateral=if (_side > 0) then {_maxX+_radius+3} else {_minX-_radius-3};
private _anchors=[[0,0],[0,_before],[_lateral,_before],[_lateral,_after],[0,_after]] apply {
    (_origin vectorAdd (_right vectorMultiply (_x select 0))) vectorAdd (_forward vectorMultiply (_x select 1))
};
private _guide=[_anchors select 0];private _overBudget=false;
for "_i" from 1 to (count _anchors-1) do {
    private _from=_anchors select (_i-1);private _to=_anchors select _i;
    private _segments=ceil ((_from distance2D _to)/5);
    if (count _guide+_segments > 24) then {_overBudget=true} else {
        if (!_overBudget) then {
            for "_j" from 1 to _segments do {_guide pushBack (_from vectorAdd ((_to vectorDiff _from) vectorMultiply (_j/_segments)))};
        };
    };
};
if (_overBudget) exitWith {["PATH_BUDGET"] call _fail};
// Circumscribed support/body clearance overbounds corners without pretending a point fits a hull.
private _geometry=[_vehicle,_guide,_radius,_height] call WAIT_fnc_DrivingPathGeometry;
if (!(_geometry select 0)) exitWith {[_geometry select 1,_geometry select 4] call _fail};
if (!([_obstacle] call WAIT_fnc_DrivingBypassObstacleAvailable)
    || {[getPosWorld _obstacle,vectorDir _obstacle,vectorUp _obstacle] isNotEqualTo _transform}
    || {[getPosWorld _vehicle,vectorDir _vehicle,vectorUp _vehicle] isNotEqualTo _vehicleTransform}) exitWith {
    ["GEOMETRY_CHANGED",_geometry select 4] call _fail
};
[true,"PROPOSAL",_geometry select 2,_geometry select 3,_transform,_vehicleTransform,_geometry select 4]

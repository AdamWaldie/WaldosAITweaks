/*
 * Author: WaldoTheWarfighter
 * Purpose: Samples live forward body geometry once for both gates and other solid obstructions.
 * Locality / Authority: Read-only on vehicle owner; trusted server may recheck a remote vehicle.
 * Existing driving/convoy callbacks own all speed/movement commands. No helper props or physics.
 * Repeat/JIP: No handlers/cache/clearance leases. Current transforms and GEOM surfaces are sampled
 * on every call; deletion, movement, rotation and damage do not rely on a mission-object grid.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 requested m/s <NUMBER, 20>, clamped 0..35;
 * 2 server recheck <BOOL, false> - read-only remote-vehicle sampling allowed on server;
 * 3 measured curvature <ARRAY, []> optional finite inverse-metre value from local track;
 * optional second BOOL permits stopped prediction only for fresh native-path evidence.
 * Empty retains instantaneous native-yaw fallback for independent server/script rechecks.
 * Return Value: ARRAY [gate observation ARRAY, solid observation ARRAY]. Gate observation retains
 * [cap m/s, gate OBJECT, gap metres, time, rays]. Solid is empty without a sampled blocker, else
 * [cap m/s, object (objNull for terrain), gap, time, rays, kind, hit ASL, normal, transform].
 * Work: nine straight or at most 27 turning GEOM rays/four hits each; nominal braking horizon <=600 m.
 * Gate classification is cached only within this call: up to 108 hit objects/eight config checks
 * each for ambiguous barrier names. Static H-barriers are not assumed to be animated gates.
 * Current forward motion and model-space yaw predict at most 2.5 seconds of curved travel,
 * clamped to 70 degrees; the remaining horizon follows the final tangent. Rigid hull offsets
 * rotate with each predicted pose. Unsupported/stationary yaw falls back to straight sensing.
 * Bodies use current absolute pitch/elevation. Gentle upward support is excluded from generic
 * blocking. Downward-facing underside hits remain solid constraints; occupied/active land-vehicle and pedestrian hulls retain their dedicated observers.
 * Stationary engine-off unoccupied land hulls also feed finite bypass planning; their independent
 * traffic cap remains active. Per-call classification inspects at most 16 land hulls and avoids
 * repeated crew reads per ray. Over-budget hulls retain traffic-only handling. No hit
 * never proves an entire path clear. Predicted turns, narrow/low geometry, slopes and actual braking
 * need physical validation. This observes approach constraints, not a bypass/detour executor.
 * Current callers: DrivingAssistStart, ConvoyTick and DrivingGateCap's server-compatible adapter.
 * Example: private _observed=[truck1,15] call WAIT_fnc_DrivingGeometryCap;
 */
params [["_vehicle",objNull,[objNull]],["_requested",20,[0]],["_serverCheck",false,[true]],["_measured",[],[[]]]];
if (!finite _requested) then {_requested=0};
_requested=(_requested max 0) min 35;
if (isNull _vehicle || {!local _vehicle && {!(_serverCheck && {isServer})}} || {!alive _vehicle}) exitWith {[[_requested,objNull,-1,time,0],[]]};
private _box=boundingBoxReal _vehicle;
private _low=_box select 0;private _high=_box select 1;
private _front=(_high select 1)+0.2;
private _left=(_low select 0)-0.2;private _right=(_high select 0)+0.2;
private _massFactor=((1+(((getMass _vehicle)-3000)/7000)) max 1) min 2.5;
private _deceleration=4/_massFactor;
private _reaction=4;
private _velocity=((velocity _vehicle) vectorDotProduct (vectorDir _vehicle)) max 0;
private _speed=_velocity max _requested;
private _horizon=((_speed*_reaction)+((_speed*_speed)/(2*_deceleration))+6) max 25 min 600;
// Read-only native yaw needs no per-vehicle history, publication or extra callback.
private _yaw=(angularVelocityModelSpace _vehicle) param [2,0];
if (!finite _yaw || {_velocity <= 1}) then {_yaw=0};
private _bendLength=(_velocity*2.5) max 8 min _horizon;
private _curvature=if (_velocity > 1) then {_yaw/_velocity} else {0};
if (count _measured in [1,2] && {(_measured select 0) isEqualType 0} && {finite (_measured select 0)}) then {
    _curvature=if (_velocity > 1 || {_measured param [1,false,[true]]}) then {_measured select 0} else {0};
};
private _maxCurvature=(70/57.2957795)/_bendLength;
_curvature=(_curvature max -_maxCurvature) min _maxCurvature;
private _turning=abs (_curvature*_bendLength*57.2957795) >= 3;
private _stations=[[0,0,0,0],[0,_horizon,0,_horizon]];
if (_turning) then {
    _stations=[[0,0,0,0]];
    {
        private _distance=_x;private _bent=_distance min _bendLength;
        private _angle=_curvature*_bent*57.2957795;
        private _xPos=(1-cos _angle)/_curvature;private _yPos=(sin _angle)/_curvature;
        if (_distance > _bendLength) then {
            _xPos=_xPos+sin _angle*(_distance-_bendLength);
            _yPos=_yPos+cos _angle*(_distance-_bendLength);
        };
        _stations pushBack [_xPos,_yPos,_angle,_distance];
    } forEach ([0.5*_bendLength,_bendLength,_horizon] arrayIntersect [0.5*_bendLength,_bendLength,_horizon]);
};
private _nearest=1e9;private _gate=objNull;private _rays=0;
private _solidGap=1e9;private _solid=[];private _gateClasses=createHashMap;
private _staticHulls=createHashMap;
private _bottom=(_low select 2)+0.45;
private _top=((_high select 2)-0.2) max _bottom;
private _heights=[_bottom,(_bottom+_top)*0.5,_top];
_heights=_heights arrayIntersect _heights;
{
    private _height=_x;
    {
        private _width=_x;
        for "_segment" from 1 to (count _stations-1) do {
        private _modelPoints=[_stations select (_segment-1),_stations select _segment] apply {
            _x params ["_centreX","_centreY","_angle"];
            [_centreX+_width*cos _angle+_front*sin _angle,
                _centreY-_width*sin _angle+_front*cos _angle,_height]
        };
        private _from=_vehicle modelToWorldWorld (_modelPoints select 0);
        private _to=_vehicle modelToWorldWorld (_modelPoints select 1);
        _rays=_rays+1;
        private _hits=lineIntersectsSurfaces [_from,_to,_vehicle,objNull,true,4,"GEOM","NONE"];
        {
            private _hit=_x;
            private _object=_hit select 3;
            if (isNull _object) then {_object=_hit select 2};
            private _position=_hit select 0;private _normal=_hit select 1;
            // Braking uses vehicle travel, not the longer arc of its outer body edge.
            private _segmentStart=(_stations select (_segment-1)) select 3;
            private _segmentEnd=(_stations select _segment) select 3;
            private _fraction=((_from vectorDistance _position)/((_from vectorDistance _to) max 0.01)) min 1;
            private _gap=_segmentStart+_fraction*(_segmentEnd-_segmentStart);
            private _isGate=false;
            if (!isNull _object && {_object != _vehicle}) then {
                private _classKey=str _object;
                private _known=_gateClasses getOrDefault [_classKey,-1];
                if (_known isEqualType true) then {_isGate=_known} else {
                    private _name=toLowerANSI ((typeOf _object)+" "+((getModelInfo _object) param [0,""]));
                    _isGate=["gate","zavora","vrata","branka"] findIf {_name find _x >= 0} >= 0;
                    // Concrete H-barriers and bag walls are obstacles, not gates to animate.
                    // A barrier-only name requires a canonical door source (at most eight checks).
                    if (!_isGate && {_name find "barrier" >= 0}) then {
                        for "_index" from 1 to 8 do {
                            if (isClass (configOf _object >> "AnimationSources" >> format ["Door_%1_sound_source",_index])) then {_isGate=true};
                        };
                    };
                    _gateClasses set [_classKey,_isGate];
                };
                if (_isGate && {_gap < _nearest}) then {_nearest=_gap;_gate=_object};
            };
            // Traffic and pedestrians retain their existing hull observers. Static/classless
            // props, parked aircraft/boats and steep terrain add no synthetic collision props.
            // Upward-facing support is not a blocking wall merely because a forward ray meets a hill/deck.
            // Downward-facing undersides still obstruct the sampled body rows; abs(normal Z)
            // would also erase those overhead constraints.
            private _staticHull=false;
            if (!isNull _object && {_object isKindOf "LandVehicle"}) then {
                private _key=str _object;
                private _cached=_staticHulls getOrDefault [_key,-1];
                if (_cached isEqualType true) then {_staticHull=_cached} else {
                    if (count _staticHulls < 16) then {
                        _staticHull=[_object] call WAIT_fnc_DrivingBypassObstacleAvailable;
                        _staticHulls set [_key,_staticHull];
                    };
                };
            };
            private _represented=!isNull _object && {_object isKindOf "CAManBase" || {_object isKindOf "LandVehicle" && {!_staticHull}}};
            if (!_isGate && {!_represented} && {(_normal select 2) < 0.7} && {_gap < _solidGap}) then {
                _solidGap=_gap;
                private _kind=if (isNull _object) then {"TERRAIN"} else {
                    ["STATIC","MOVING_OBJECT"] select (abs speed _object > 0.5)
                };
                private _transform=if (isNull _object) then {[]} else {[getPosWorld _object,vectorDir _object,vectorUp _object]};
                _solid=[_object,_kind,+_position,+_normal,_transform];
            };

        } forEach _hits;
        };
    } forEach [_left,(_left+_right)*0.5,_right];
} forEach _heights;
private _capForGap={
    params ["_gap"];
    private _room=(_gap-6) max 0;
    private _reactionSpeed=_deceleration*_reaction;
    _requested min ((sqrt ((_reactionSpeed*_reactionSpeed)+2*_deceleration*_room)-_reactionSpeed) max 0)
};
private _gateObservation=if (isNull _gate) then {[_requested,objNull,-1,time,_rays]} else {
    [[_nearest] call _capForGap,_gate,_nearest,time,_rays]
};
private _solidObservation=if (_solid isEqualTo []) then {[]} else {
    [[_solidGap] call _capForGap,_solid select 0,_solidGap,time,_rays,
        _solid select 1,_solid select 2,_solid select 3,_solid select 4]
};
[_gateObservation,_solidObservation]

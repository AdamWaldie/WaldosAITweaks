/*
 * Author: WaldoTheWarfighter
 * Purpose: Proposes a finite road-pass corridor and relative-motion budget from current observations.
 * Locality/authority: Read-only on passing vehicle owner. A proposal grants no driving authority.
 * Repeat/JIP: Fresh observations only; no state, commands, handlers, claims or replay.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 predecessor <OBJECT>, objNull;
 * 2 proposed passing speed km/h <NUMBER>, 50 (5..120).
 * Return: HASHMAP with status PROPOSAL or REFUSED, reason, and on proposal guideASL,
 * requiredTravel, estimatedSeconds, maximumSeconds, observedAt, vehicles, transforms and context.
 * PROPOSAL is NOT clearance: no hull/support/occupancy rays or native route feasibility have
 * been proved. An executor must obtain owner agreement, validate geometry and retain safety caps.
 * Bounds: 32 road transitions, at most 16 connections per piece, 350 m travel. Junctions,
 * bridges, pedestrian roads, loops, sharp turns and invalid endpoint geometry refuse.
 * Road endpoints retain their ASL elevation. No terrain flattening or physics shortcut.
 * At most 128 stations sample the centreline at <=5 m, ramp out from the current lane and return over
 * the final 30 m. Each lane offset uses its own road endpoints; insufficient pull-out
 * room or a predecessor outside the traversed road chain refuses. Actual hull clearance
 * still gates any future executor return.
 * Current callers: trusted script preflight and experimental DrivingPassAdmission; physical acceptance remains outstanding.
 * Example: private _proposal=[truck1,truck2,50] call WAIT_fnc_DrivingPassPlan;
 */
params [["_vehicle",objNull,[objNull]],["_front",objNull,[objNull]],["_speedKmh",50,[0]]];
private _fail={params ["_reason"];createHashMapFromArray [["status","REFUSED"],["reason",_reason]]};
if (isNull _vehicle || {isNull _front} || {_vehicle == _front} || {!local _vehicle}
    || {!alive _vehicle} || {!alive _front} || {!canMove _vehicle}
    || {!(_vehicle isKindOf "LandVehicle")} || {!(_front isKindOf "LandVehicle")}) exitWith {["VEHICLE_UNAVAILABLE"] call _fail};
if (!finite _speedKmh || {_speedKmh < 5} || {_speedKmh > 120}) exitWith {["INVALID_SPEED"] call _fail};
if (group driver _vehicle == group driver _front) exitWith {["SAME_GROUP"] call _fail};
private _context=[[_vehicle,_front]] call WAIT_fnc_DrivingPassContext;
if (_context isEqualTo []) exitWith {["INVALID_CONTEXT"] call _fail};
private _forward=velocityModelSpace _front select 1;
if (_forward < -0.1 || {(velocityModelSpace _vehicle select 1) < -0.1}) exitWith {["REVERSING"] call _fail};
private _relative=_speedKmh/3.6-(_forward max 0);
if (_relative < 2) exitWith {["INSUFFICIENT_SPEED_GAIN"] call _fail};
private _heading=getDir _vehicle;
if (abs (((getDir _front-_heading+540) mod 360)-180) > 25) exitWith {["NOT_ALIGNED"] call _fail};
private _delta=(getPosASL _front) vectorDiff (getPosASL _vehicle);
private _gap=_delta vectorDotProduct [sin _heading,cos _heading,0];
if (_gap <= 0 || {_gap > 60} || {abs (_delta select 2) > 2}) exitWith {["NOT_FORWARD_PEER"] call _fail};
private _ownBounds=boundingBoxReal _vehicle;private _frontBounds=boundingBoxReal _front;
private _ownHalfLength=(abs ((_ownBounds select 0) select 1)) max (abs ((_ownBounds select 1) select 1));
private _frontHalfLength=(abs ((_frontBounds select 0) select 1)) max (abs ((_frontBounds select 1) select 1));
private _ownHalfWidth=(abs ((_ownBounds select 0) select 0)) max (abs ((_ownBounds select 1) select 0));
private _frontHalfWidth=(abs ((_frontBounds select 0) select 0)) max (abs ((_frontBounds select 1) select 0));
private _seconds=(_gap+_ownHalfLength+_frontHalfLength+7)/(_relative*0.8)+2.5;
private _passTravel=(_speedKmh/3.6)*_seconds;
private _needed=_passTravel+30;
if (_seconds > 24 || {_needed > 350}) exitWith {["PASS_BUDGET"] call _fail};
private _road=roadAt _vehicle;
if (isNull _road) exitWith {["NO_ROAD"] call _fail};
private _frontRoad=roadAt _front;
if (isNull _frontRoad) exitWith {["PEER_NOT_ON_ROAD"] call _fail};
private _frontInfo=getRoadInfo _frontRoad;
private _frontBegin=_frontInfo param [6,[],[[]]];private _frontEnd=_frontInfo param [7,[],[[]]];
if (_frontInfo param [2,false,[true]] || {_frontInfo param [8,false,[true]]}
    || {count _frontBegin != 3} || {count _frontEnd != 3}
    || {(_frontBegin+_frontEnd) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {["PEER_ROAD_GEOMETRY"] call _fail};
private _frontAxis=_frontEnd vectorDiff _frontBegin;_frontAxis set [2,0];
if (vectorMagnitude _frontAxis < 0.1) exitWith {["PEER_ROAD_GEOMETRY"] call _fail};
_frontAxis=vectorNormalized _frontAxis;
if (_frontAxis vectorDotProduct (vectorDir _front) < 0) then {_frontAxis=_frontAxis vectorMultiply -1};
private _frontLeft=[-(_frontAxis select 1),_frontAxis select 0,0];
private _frontLateral=((getPosASL _front) vectorDiff _frontBegin) vectorDotProduct _frontLeft;
private _visited=[];private _previous=objNull;private _last=getPosASL _vehicle;
private _travel=0;private _guide=[];private _returnIndex=-1;private _reason="ROAD_BUDGET";
private _offset=_ownHalfWidth+_frontHalfWidth+1;
private _entryLateral=0;private _passingLateral=0;private _laneCaptured=false;
private _entryTravel=((_speedKmh/3.6)*2.5) max 12;
for "_index" from 0 to 31 do {
    if (isNull _road || {_road in _visited}) exitWith {_reason="ROAD_LOOP_OR_END"};
    _visited pushBack _road;
    private _info=getRoadInfo _road;
    if (_info param [2,false,[true]] || {_info param [8,false,[true]]}) exitWith {_reason="PEDESTRIAN_OR_BRIDGE"};
    private _begin=_info param [6,[],[[]]];private _end=_info param [7,[],[[]]];
    if (count _begin != 3 || {count _end != 3}
        || {_begin distance2D _end < 0.1}
        || {(_begin+_end) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {_reason="ROAD_GEOMETRY"};
    private _centre=(_begin vectorAdd _end) vectorMultiply 0.5;
    private _connections=roadsConnectedTo _road;
    if (count _connections > 16 || {count _connections >= 3}) exitWith {_reason="JUNCTION_OR_CONNECTION_BUDGET"};
    private _next=objNull;private _best=181;
    {
        if (_x != _previous && {!(_x in _visited)}) then {
            private _angle=abs ((((_centre getDir _x)-_heading+540) mod 360)-180);
            if (_angle < _best) then {_best=_angle;_next=_x};
        };
    } forEach _connections;
    if (isNull _next || {_best > 35}) exitWith {_reason="ROAD_END_OR_TURN"};
    private _nextHeading=_centre getDir _next;
    if (!_laneCaptured) then {
        private _ownAxis=_end vectorDiff _begin;_ownAxis set [2,0];
        _ownAxis=vectorNormalized _ownAxis;
        if (_ownAxis vectorDotProduct (vectorDir _vehicle) < 0) then {_ownAxis=_ownAxis vectorMultiply -1};
        private _left=[-(_ownAxis select 1),_ownAxis select 0,0];
        _entryLateral=((getPosASL _vehicle) vectorDiff _centre) vectorDotProduct _left;
        // Work on the centreline before applying the lane offset exactly once.
        _last=(getPosASL _vehicle) vectorDiff (_left vectorMultiply _entryLateral);
        _passingLateral=_frontLateral+_offset;
        private _available=_gap-_ownHalfLength-_frontHalfLength-3;
        // Smoothstep has maximum derivative 1.5. Reserve a gradual transition
        // rather than proposing a late cut across the predecessor's current hull.
        private _minimumPullout=(1.5*abs (_passingLateral-_entryLateral)/tan 20) max 12;
        if (_available < _minimumPullout) then {_reason="INSUFFICIENT_PULL_OUT_ROOM"} else {
            _entryTravel=_entryTravel min _available;
            _entryTravel=_entryTravel max _minimumPullout;
        };
        _laneCaptured=true;
    };
    if (_reason == "INSUFFICIENT_PULL_OUT_ROOM") exitWith {};
    // The first road midpoint can be behind the actor: do not propose a reverse entry.
    if ((_centre vectorDiff (getPosASL _vehicle)) vectorDotProduct [sin (getDir _vehicle),cos (getDir _vehicle),0] > 2) then {
        private _segment=_last distance2D _centre;
        private _remaining=_needed-_travel;
        if (_segment > _remaining) then {
            _centre=_last vectorAdd ((_centre vectorDiff _last) vectorMultiply (_remaining/_segment));
            _segment=_remaining;
        };
        private _steps=ceil (_segment/5);
        if (_steps > 0 && {count _guide+_steps <= 128}) then {
            private _segmentHeading=_last getDir _centre;
            private _left=[-cos _segmentHeading,sin _segmentHeading,0];
            for "_station" from 1 to _steps do {
                private _fraction=_station/_steps;
                private _along=_travel+_segment*_fraction;
                if (_returnIndex < 0 && {_along >= _passTravel}) then {_returnIndex=count _guide};
                private _out=(_along/_entryTravel) min 1;
                private _back=(((_along-_passTravel)/30) max 0) min 1;
                _out=_out*_out*(3-2*_out);_back=_back*_back*(3-2*_back);
                private _lateral=_entryLateral+(_passingLateral-_entryLateral)*_out*(1-_back);
                private _base=_last vectorAdd ((_centre vectorDiff _last) vectorMultiply _fraction);
                _guide pushBack (_base vectorAdd (_left vectorMultiply _lateral));
            };
            _travel=_travel+_segment;_last=_centre;
        } else {_reason="STATION_BUDGET"};
    };
    if (_reason == "STATION_BUDGET") exitWith {};
    if (_travel >= _needed && {count _guide >= 3}) exitWith {_reason=""};
    _previous=_road;_road=_next;_heading=_nextHeading;
};
if (_reason != "") exitWith {[_reason] call _fail};
if (_returnIndex < 2 || {_returnIndex >= count _guide-1}) exitWith {["PASS_LEG_BUDGET"] call _fail};
if !(_frontRoad in _visited) exitWith {["PEER_OFF_CORRIDOR"] call _fail};
if (([[_vehicle,_front]] call WAIT_fnc_DrivingPassContext) isNotEqualTo _context) exitWith {["CONTEXT_CHANGED"] call _fail};
createHashMapFromArray [["status","PROPOSAL"],["reason","GEOMETRY_AND_AGREEMENT_REQUIRED"],
    ["context",_context],["returnIndex",_returnIndex],["guideASL",_guide],["requiredTravel",_needed],["estimatedSeconds",_seconds],
    ["maximumSeconds",_seconds*1.8+5],["observedAt",serverTime],["vehicles",[_vehicle,_front]],
    ["transforms",[_vehicle,_front] apply {[getPosWorld _x,vectorDir _x,vectorUp _x]}]]
/*
 * Author: WaldoTheWarfighter
 * Purpose: Validates a bounded ASL path proposal against support, lateral slope and body geometry.
 * Locality / Authority: Read-only vehicle owner. No route, movement, physics or speed commands.
 * Repeat/JIP: Fresh proposal only; no cache, handles or historical clearance replay. Consumers
 * must revalidate their target/route/owner receipt before execution and observe runtime geometry.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 guide ASL <ARRAY, []>, 2..24 finite positions,
 * adjacent distance 0.05..8 m; 2 half-width <NUMBER, 2>, 0.5..20 m;
 * 3 body height <NUMBER, 2>, 0.5..20 m; 4 ignored logic <OBJECT, objNull>.
 * Return Value: ARRAY [valid BOOL, reason STRING, pointsATL ARRAY, pointsASL ARRAY, rayCount].
 * Bound: 24 stations/72 support rays plus 23*9 body rays (279 total). Current corridor calls
 * use at most 20 stations/231 rays. Three body heights include middle-height beams/overhangs.
 * Terrain and static decks may support proposals; vehicle/person surfaces and moving props cannot.
 * This is discrete sampled geometry, not continuous swept-volume or steering feasibility proof.
 * Current callers: DrivingCorridorGeometry and DrivingBypassPlan.
 * Example: [truck1,_guideASL,2.5,3] call WAIT_fnc_DrivingPathGeometry;
 */
params [["_vehicle",objNull,[objNull]],["_guide",[],[[]]],["_halfWidth",2,[0]],
    ["_height",2,[0]],["_ignored",objNull,[objNull]]];
private _fail={params ["_reason",["_rays",0]];[false,_reason,[],[],_rays]};
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle}) exitWith {["OWNER_UNAVAILABLE"] call _fail};
if (count _guide < 2 || {count _guide > 24} || {!finite _halfWidth} || {!finite _height}
    || {_halfWidth < 0.5} || {_halfWidth > 20} || {_height < 0.5} || {_height > 20}
    || {_guide findIf {!(_x isEqualType []) || {count _x != 3}
        || {_x findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} >= 0}} >= 0}) exitWith {["INVALID_PATH"] call _fail};
if (!isNull _ignored && {!(_ignored isKindOf "Logic")}) exitWith {["INVALID_IGNORED_OBJECT"] call _fail};
private _valid=true;private _invalidReason="SEGMENT_BUDGET";
for "_i" from 1 to (count _guide-1) do {
    private _length=(_guide select (_i-1)) distance2D (_guide select _i);
    if (_length < 0.05 || {_length > 8.01}) then {_valid=false};
};
for "_i" from 1 to (count _guide-2) do {
    if ((_guide select (_i-1)) distance2D (_guide select (_i+1)) < 0.05) then {
        _valid=false;_invalidReason="REVERSING_PATH";
    };
};
if (!_valid) exitWith {[_invalidReason] call _fail};
private _points=[];private _rays=0;private _reason="";private _rights=[];
for "_i" from 0 to (count _guide-1) do {
    if (_reason == "") then {
        private _base=_guide select _i;
        private _direction=(_guide select ((_i+1) min (count _guide-1))) vectorDiff (_guide select ((_i-1) max 0));
        _direction set [2,0];_direction=vectorNormalized _direction;
        private _right=[_direction select 1,-(_direction select 0),0];_rights pushBack _right;
        private _supports=[];
        {
            private _sample=_base vectorAdd (_right vectorMultiply _x);
            private _hits=lineIntersectsSurfaces [_sample vectorAdd [0,0,3],_sample vectorAdd [0,0,-3],
                _vehicle,_ignored,true,1,"GEOM","NONE",true];_rays=_rays+1;
            if (_hits isEqualTo []) then {_reason="MISSING_SUPPORT"} else {
                private _hit=_hits select 0;
                // A flat roof is not a road deck. Resolve proxy and parent hits so an
                // occupied, parked or wrecked vehicle cannot become traversable support.
                private _supportObject=if (!isNull (_hit select 3)) then {_hit select 3} else {_hit select 2};
                if (!isNull _supportObject && {_supportObject isKindOf "AllVehicles"
                    || {vectorMagnitude velocity _supportObject > 0.1}}) then {_reason="UNSTABLE_SUPPORT"};
                if (surfaceIsWater _sample && {isNull (_hit select 2) || {((_hit select 0) select 2) <= 0.25}}) then {_reason="WET_SUPPORT"};
                if (((_hit select 1) select 2) < 0.85) then {_reason="STEEP_SUPPORT"};
                _supports pushBack (_hit select 0);
            };
        } forEach [-_halfWidth,0,_halfWidth];
        if (count _supports == 3) then {
            private _middle=_supports select 1;
            if (abs (((_supports select 0) select 2)-(_middle select 2)) > 0.5
                || {abs (((_supports select 2) select 2)-(_middle select 2)) > 0.5}) then {_reason="CROSS_SLOPE"};
            _points pushBack _middle;
        };
    };
};
if (_reason != "") exitWith {[_reason,_rays] call _fail};
private _bodyHeights=[0.5,(_height+0.5)*0.5,_height] arrayIntersect [0.5,(_height+0.5)*0.5,_height];
for "_i" from 1 to (count _points-1) do {
    if (_reason == "") then {
        private _from=_points select (_i-1);private _to=_points select _i;
        if (abs ((_to select 2)-(_from select 2)) > (_from distance2D _to)*0.25) then {_reason="LONGITUDINAL_SLOPE"};
        {
            private _offset=_x;
            {
                private _up=[0,0,_x];
                private _a=(_from vectorAdd ((_rights select (_i-1)) vectorMultiply _offset)) vectorAdd _up;
                private _b=(_to vectorAdd ((_rights select _i) vectorMultiply _offset)) vectorAdd _up;
                private _hits=lineIntersectsSurfaces [_a,_b,_vehicle,_ignored,true,1,"GEOM","NONE",true];_rays=_rays+1;
                if (_hits isNotEqualTo []) then {_reason="BODY_OBSTRUCTION"};
            } forEach _bodyHeights;
        } forEach [-_halfWidth,0,_halfWidth];
    };
};
if (_reason != "") exitWith {[_reason,_rays] call _fail};
[true,"PROPOSAL",_points apply {ASLToATL _x},_points,_rays]

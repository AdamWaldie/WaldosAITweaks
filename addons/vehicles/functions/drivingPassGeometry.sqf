/*
 * Author: WaldoTheWarfighter
 * Purpose: Checks one bounded overlapping portion of a fresh road-pass proposal.
 * Locality/authority: Read-only vehicle owner. No movement, agreement or priority is acquired.
 * Repeat/JIP: Stateless; each call observes current support/body geometry. Prior portions are
 * not replayed as clearance. A future executor must own scan orchestration and live safety.
 * Arguments: 0 proposal <HASHMAP>, empty; 1 start station <NUMBER>, 0, integer.
 * Return: HASHMAP status REFUSED or SLICE_PROPOSAL, reason, from, next, lastSlice,
 * pointsATL, pointsASL, rayCount and observedAt. lastSlice means only the end of this
 * proposal was sampled; it does not certify preceding portions or a whole pass.
 * Bound: 12 stations/36 support rays, 11*9 segment body rays and 12*9 longitudinal
 * footprint rays (243 maximum) per call. Half-length is bounded to 20 m.
 * Adjacent calls overlap one station. Proposal age is at most two seconds before and after
 * geometry. Crew/locality/native-order context must match before and after each slice.
 * Oriented width and length traces replace an isotropic radius; no continuous swept-volume,
 * traffic prediction, owner agreement or native steering success is implied.
 * Current callers: trusted script preflight and experimental DrivingPassAdmission; physical acceptance remains outstanding.
 * Example: private _slice=[_proposal,0] call WAIT_fnc_DrivingPassGeometry;
 */
params [["_proposal",createHashMap,[createHashMap]],["_cursor",0,[0]]];
private _fail={params ["_reason",["_rays",0]];createHashMapFromArray [["status","REFUSED"],["reason",_reason],["rayCount",_rays]]};
if ((_proposal getOrDefault ["status",""]) != "PROPOSAL") exitWith {["INVALID_PROPOSAL"] call _fail};
private _vehicles=_proposal getOrDefault ["vehicles",[]];
if (!(_vehicles isEqualType []) || {count _vehicles != 2}
    || {_vehicles findIf {!(_x isEqualType objNull) || {isNull _x} || {!alive _x}} >= 0}) exitWith {["VEHICLE_UNAVAILABLE"] call _fail};
private _vehicle=_vehicles select 0;
if (!local _vehicle) exitWith {["OWNER_UNAVAILABLE"] call _fail};
private _context=_proposal getOrDefault ["context",[]];
private _sameContext={_context isNotEqualTo [] && {([_vehicles] call WAIT_fnc_DrivingPassContext) isEqualTo _context}};
if !(call _sameContext) exitWith {["CONTEXT_CHANGED"] call _fail};
private _observed=_proposal getOrDefault ["observedAt",-1];
private _fresh={_observed isEqualType 0 && {finite _observed} && {serverTime >= _observed} && {serverTime-_observed <= 2}};
if !(call _fresh) exitWith {["STALE_PROPOSAL"] call _fail};
private _guide=_proposal getOrDefault ["guideASL",[]];
if (!(_guide isEqualType []) || {count _guide < 2} || {count _guide > 128}
    || {!finite _cursor} || {_cursor != floor _cursor} || {_cursor < 0} || {_cursor >= count _guide-1}) exitWith {["INVALID_SLICE"] call _fail};
private _slice=_guide select [_cursor,12];
private _box=boundingBoxReal _vehicle;
private _low=_box select 0;private _high=_box select 1;
private _halfWidth=(abs (_low select 0)) max (abs (_high select 0));
private _halfLength=(abs (_low select 1)) max (abs (_high select 1));
if (_halfLength > 20) exitWith {["HULL_FOOTPRINT_BUDGET"] call _fail};
private _width=_halfWidth+0.5;
private _height=((_high select 2)-(_low select 2)) max 1;
private _geometry=[_vehicle,_slice,_width,_height] call WAIT_fnc_DrivingPathGeometry;
private _rays=_geometry select 4;
if (!(_geometry select 0)) exitWith {[_geometry select 1,_rays] call _fail};
// Width is not a turning circle. Check actual longitudinal hull extent at every
// supported station; the other vehicle is never excluded from obstruction rays.
private _points=_geometry select 3;
private _blocked=false;
private _heights=[0.5,(_height+0.5)*0.5,_height] arrayIntersect [0.5,(_height+0.5)*0.5,_height];
for "_station" from 0 to (count _points-1) do {
    if (!_blocked) then {
        private _point=_points select _station;
        private _direction=(_points select ((_station+1) min (count _points-1)))
            vectorDiff (_points select ((_station-1) max 0));
        _direction=vectorNormalized _direction;
        private _right=vectorNormalized [_direction select 1,-(_direction select 0),0];
        {
            if (!_blocked) then {
                private _offset=_right vectorMultiply _x;
                {
                    private _centre=(_point vectorAdd _offset) vectorAdd [0,0,_x];
                    private _a=_centre vectorDiff (_direction vectorMultiply (_halfLength+0.5));
                    private _b=_centre vectorAdd (_direction vectorMultiply (_halfLength+0.5));
                    private _hits=lineIntersectsSurfaces [_a,_b,_vehicle,objNull,true,1,"GEOM","NONE",true];
                    _rays=_rays+1;
                    if (_hits isNotEqualTo []) exitWith {_blocked=true};
                } forEach _heights;
            };
        } forEach [-_width,0,_width];
    };
};
if (_blocked) exitWith {["BODY_FOOTPRINT_OBSTRUCTION",_rays] call _fail};
if (!(call _fresh) || {!local _vehicle} || {!(call _sameContext)}) exitWith {["STALE_SCAN_OR_OWNER",_rays] call _fail};
private _next=_cursor+count _slice-1;
createHashMapFromArray [["status","SLICE_PROPOSAL"],["reason","LIVE_AUTHORITY_AND_TRAFFIC_REQUIRED"],
    ["context",_context],["from",_cursor],["next",_next],["lastSlice",_next == count _guide-1],
    ["pointsATL",_geometry select 2],["pointsASL",_geometry select 3],
    ["rayCount",_rays],["observedAt",serverTime]]
/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes current occupied pass-corridor hulls and measured approaching traffic.
 * Locality/authority: Read-only passing-vehicle owner; no priority, agreement or movement writes.
 * Repeat/JIP: Fresh observation only. Both crew/order contexts and two-second proposal age
 * are checked before and after work. Never replay a prior traffic observation as clearance.
 * Arguments: 0 proposal <HASHMAP>, empty, from DrivingPassPlan.
 * Return: HASHMAP status REFUSED or TRAFFIC_OBSERVATION, blocked BOOL, reason, actor,
 * candidateCount, observedAt and context. No observed conflict is not permission to pass.
 * Bound: one native area query <=1250 m, at most 64 candidates and 127 guide segments each;
 * dense results refuse without inspecting a selected prefix. No raycasts or recurring handler.
 * Area discovery includes dead vehicle entities; parked/empty/destroyed hulls remain obstacles.
 * The intended predecessor is excluded only from this corridor observer; independent following
 * and collision caps must still constrain it. Mounted people are represented by their vehicle.
 * Predicted risk intersects measured constant-course motion with each expanded corridor segment,
 * using simultaneous longitudinal, lateral and vertical time intervals. This is conservative:
 * separate arrival times can still refuse; parallel off-corridor travel alone does not.
 * Approaching risk uses actual velocity and a finite constant-course estimate, not an assumption
 * that another driver yields. Curved/future traffic still requires runtime collision/abort checks.
 * Current callers: DrivingPassPrepare/Step/Begin and trusted preflight; automatic admission remains experimental.
 * Example: private _traffic=[_proposal] call WAIT_fnc_DrivingPassTraffic;
 */
params [["_proposal",createHashMap,[createHashMap]]];
private _fail={params ["_reason",["_count",0]];createHashMapFromArray [["status","REFUSED"],
    ["blocked",true],["reason",_reason],["candidateCount",_count]]};
if ((_proposal getOrDefault ["status",""]) != "PROPOSAL") exitWith {["INVALID_PROPOSAL"] call _fail};
private _vehicles=_proposal getOrDefault ["vehicles",[]];
private _context=_proposal getOrDefault ["context",[]];
private _observed=_proposal getOrDefault ["observedAt",-1];
private _current={_observed isEqualType 0 && {finite _observed} && {serverTime >= _observed}
    && {serverTime-_observed <= 2} && {_context isNotEqualTo []}
    && {([_vehicles] call WAIT_fnc_DrivingPassContext) isEqualTo _context}};
if !(call _current) exitWith {["STALE_CONTEXT"] call _fail};
private _vehicle=_vehicles select 0;private _front=_vehicles select 1;
if (!local _vehicle) exitWith {["OWNER_UNAVAILABLE"] call _fail};
private _guide=_proposal getOrDefault ["guideASL",[]];
private _duration=_proposal getOrDefault ["estimatedSeconds",-1];
private _travel=_proposal getOrDefault ["requiredTravel",-1];
if (!(_guide isEqualType []) || {count _guide < 2} || {count _guide > 128}
    || {_guide findIf {!(_x isEqualType []) || {count _x != 3}
        || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}
    || {!(_duration isEqualType 0)} || {!finite _duration} || {_duration <= 0} || {_duration > 24}
    || {!(_travel isEqualType 0)} || {!finite _travel} || {_travel <= 0} || {_travel > 350}) exitWith {["INVALID_CORRIDOR"] call _fail};
// Cover the full proposed travel plus a 35 m/s oncoming approach and 60 m margin.
// The old 17 m/s envelope could omit ordinary fast road traffic until after admission.
// Faster modded traffic can still originate beyond this nominal envelope: no clearance guarantee.
private _range=((_travel+35*_duration+60) max 150) min 1250;
private _area=[getPosATL _vehicle,_range,_range,0,false,_range];
private _candidates=_area nearEntities [["LandVehicle","CAManBase"],false,false,false];
if (count _candidates > 64) exitWith {["TRAFFIC_BUDGET",count _candidates] call _fail};
private _box=boundingBoxReal _vehicle;
private _width=((abs ((_box select 0) select 0)) max (abs ((_box select 1) select 0)))+0.5;
private _height=((_box select 1) select 2)-((_box select 0) select 2);
private _halfLength=(abs ((_box select 0) select 1)) max (abs ((_box select 1) select 1));
private _reason="NO_OBSERVED_CONFLICT";private _limiting=objNull;
{
    private _other=_x;
    if (_other != _vehicle && {_other != _front} && {!isNull _other}
        && {!(_other isKindOf "CAManBase") || {isNull objectParent _other}}) then {
        private _position=getPosASL _other;
        private _otherBox=boundingBoxReal _other;
        private _otherWidth=(abs ((_otherBox select 0) select 0)) max (abs ((_otherBox select 1) select 0));
        private _otherLength=(abs ((_otherBox select 0) select 1)) max (abs ((_otherBox select 1) select 1));
        private _radius=sqrt (_otherWidth^2+_otherLength^2);
        private _vertical=(_height+((_otherBox select 1) select 2)-((_otherBox select 0) select 2))*0.5+1;
        private _occupied=false;private _approaching=false;
        private _velocity=velocity _other;
        for "_segment" from 1 to (count _guide-1) do {
            private _a=_guide select (_segment-1);private _b=_guide select _segment;
            private _delta=_b vectorDiff _a;private _flat=+_delta;_flat set [2,0];
            private _relative=_position vectorDiff _a;_relative set [2,0];
            private _fraction=((_relative vectorDotProduct _flat)/((_flat vectorDotProduct _flat) max 0.01) max 0) min 1;
            private _closest=_a vectorAdd (_delta vectorMultiply _fraction);
            if (_position distance2D _closest <= _width+_radius+1
                && {abs ((_position select 2)-(_closest select 2)) <= _vertical}) exitWith {_occupied=true};
            private _length=vectorMagnitude _flat;
            if (_length > 0.1 && {vectorMagnitude _velocity > 0.5}) then {
                private _along=_flat vectorMultiply (1/_length);
                private _right=[_along select 1,-(_along select 0),0];
                private _offset=_position vectorDiff _a;
                private _longMargin=_halfLength+_radius+1;
                private _sideMargin=_width+_radius+1;
                private _enter=0;private _leave=_duration;private _possible=true;
                // All axes must overlap at the same future time. A nearby oncoming
                // actor on a parallel road is not by itself a corridor conflict.
                {
                    _x params ["_coordinate","_speed","_minimum","_maximum"];
                    if (abs _speed < 0.01) then {
                        if (_coordinate < _minimum || {_coordinate > _maximum}) then {_possible=false};
                    } else {
                        private _first=(_minimum-_coordinate)/_speed;
                        private _last=(_maximum-_coordinate)/_speed;
                        _enter=_enter max (_first min _last);
                        _leave=_leave min (_first max _last);
                        if (_enter > _leave) then {_possible=false};
                    };
                    if (!_possible) exitWith {};
                } forEach [
                    [_offset vectorDotProduct _along,_velocity vectorDotProduct _along,-_longMargin,_length+_longMargin],
                    [_offset vectorDotProduct _right,_velocity vectorDotProduct _right,-_sideMargin,_sideMargin],
                    [_position select 2,_velocity select 2,((_a select 2) min (_b select 2))-_vertical,((_a select 2) max (_b select 2))+_vertical]
                ];
                if (_possible && {_enter <= _leave}) then {_approaching=true};
            };
            if (_approaching) exitWith {};
        };
        if (_occupied || {_approaching}) exitWith {
            _limiting=_other;_reason=["APPROACHING_TRAFFIC","OCCUPIED_CORRIDOR"] select _occupied;
        };
    };
} forEach _candidates;
if (!(call _current) || {!local _vehicle}) exitWith {["CONTEXT_CHANGED",count _candidates] call _fail};
createHashMapFromArray [["status","TRAFFIC_OBSERVATION"],["blocked",!isNull _limiting],
    ["reason",_reason],["actor",_limiting],["candidateCount",count _candidates],
    ["observedAt",serverTime],["context",_context]]
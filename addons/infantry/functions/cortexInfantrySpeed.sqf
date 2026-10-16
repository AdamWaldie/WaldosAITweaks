/*
 * Author: WaldoTheWarfighter
 * Purpose: Derives a hull-relative friendly-pedestrian speed ceiling for existing driving writers.
 * Locality/authority: Read-only on the current vehicle owner; never issues movement commands.
 * Repeat/JIP: Fresh bounded observations only; no handlers, leases or cached clearance to replay.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 requested km/h <NUMBER, 0>;
 * 2 controlling group <GROUP, grpNull>; 3 ordinary driving <BOOL, false>;
 * 4 travel intent <NUMBER, 0>: 0 actual velocity, -1 owned rear leg, 1 owned forward retry.
 * Ordinary mode follows the driving-assistance gate; convoy mode retains its opt-in infantry gate.
 * Return Value: NUMBER km/h, zero..request. Dense sets fail closed. At most 32 pedestrian hulls,
 * eight corners each; a speed-dependent query is capped at 250 m. Nominal braking and four-second
 * response allowance are conservative policy, not measured native braking or crossing prediction.
 * Current callers: ConvoyTick, DrivingAssistStart, convoy avoidance audit.
 * Example: private _speed = [_truck,30,group driver _truck,true] call WAIT_fnc_CortexInfantrySpeed;
 */
params [["_vehicle",objNull,[objNull]],["_requested",0,[0]],
    ["_group",grpNull,[grpNull]],["_ordinary",false,[false]],["_travelIntent",0,[0]]];
if (!finite _requested) exitWith {0};
_requested=(_requested max 0) min 126;
if (isNull _vehicle || {isNull _group} || {!local _vehicle}) exitWith {_requested};
private _enabled=if (_ordinary) then {
    [_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled
} else {[_group,"WAIT_Convoy_AvoidInfantry_Enable",false] call WAIT_fnc_CortexFeatureEnabled};
if (!_enabled) exitWith {_requested};
private _bounds=boundingBoxReal _vehicle;
private _low=_bounds select 0;private _high=_bounds select 1;
private _reverse=if (_travelIntent == 0) then {
    (velocityModelSpace _vehicle select 1) < -0.5
} else {_travelIntent < 0};
private _sign=[1,-1] select _reverse;
private _edge=if (_reverse) then {-(_low select 1)} else {_high select 1};
private _speed=abs (velocityModelSpace _vehicle select 1);
private _massFactor=((1+(((getMass _vehicle)-3000)/7000)) max 1) min 2.5;
private _deceleration=4/_massFactor;
private _reaction=4;
private _planningSpeed=_speed max (_requested/3.6);
private _look=(_planningSpeed*_reaction+(_planningSpeed*_planningSpeed)/(2*_deceleration)+5) min 230;
private _radius=(_look+abs _edge+5) min 250;
private _people=_vehicle nearEntities ["CAManBase",_radius];
if (count _people > 32) exitWith {0};
private _limit=_requested;
{
    private _person=_x;
    if (alive _person && {vehicle _person == _person}
        && {(side _group) getFriend (side group _person) >= 0.6}) then {
        private _personBounds=boundingBoxReal _person;
        private _personLow=_personBounds select 0;private _personHigh=_personBounds select 1;
        private _minX=1e9;private _maxX=-1e9;private _minY=1e9;private _maxY=-1e9;
        private _minZ=1e9;private _maxZ=-1e9;
        {
            private _height=_x;
            {
                private _width=_x;
                {
                    private _point=_vehicle worldToModel (_person modelToWorld [_width,_x,_height]);
                    private _along=(_point select 1)*_sign;
                    _minX=_minX min (_point select 0);_maxX=_maxX max (_point select 0);
                    _minY=_minY min _along;_maxY=_maxY max _along;
                    _minZ=_minZ min (_point select 2);_maxZ=_maxZ max (_point select 2);
                } forEach [_personLow select 1,_personHigh select 1];
            } forEach [_personLow select 0,_personHigh select 0];
        } forEach [_personLow select 2,_personHigh select 2];
        private _behindEdge=if (_reverse) then {-(_high select 1)} else {_low select 1};
        if (_maxX >= (_low select 0)-1 && {_minX <= (_high select 0)+1}
            && {_maxZ >= (_low select 2)-0.3} && {_minZ <= (_high select 2)+0.3}
            && {_maxY >= _behindEdge} && {_minY <= _edge+_look}) then {
            private _room=(_minY-_edge-3) max 0;
            private _reactionSpeed=_deceleration*_reaction;
            private _allowed=(sqrt ((_reactionSpeed*_reactionSpeed)+2*_deceleration*_room)-_reactionSpeed) max 0;
            // No minimum crawl through an occupied hull, and no hysteresis can discard zero.
            _limit=_limit min (_allowed*3.6);
        };
    };
} forEach _people;
_limit

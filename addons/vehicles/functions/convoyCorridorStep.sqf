/*
 * Author: WaldoTheWarfighter
 * Purpose: Tracks actual whole-column corridor passage and supplies follower speed ceilings after
 * the lead hands back. It cannot issue movement, steering, stop, waypoint or speed commands.
 * Locality / Authority: Current convoy group owner/current registry brain only. Cleanup is scoped
 * to the original configuration revision; stale cleanup cannot erase successor passage work.
 * Repeat/JIP: Public bounded episode/entered/crossed receipts survive owner adoption without
 * movement replay or deadline renewal. At most 20 snapshotted vehicles and eight corners each.
 * The deadline is frozen by lead admission, including original column length allowance (max 1800 s).
 * Arguments: 0 group <GROUP, grpNull>; 1 configuration <ARRAY, []>; 2 cancel reason <STRING, empty>.
 * Return Value: ARRAY [active BOOL, capsMps HASHMAP keyed netId, crossed NUMBER, required NUMBER].
 * Geometry: actual hull projection, lateral containment and nearest sampled support elevation;
 * no new rays or world scans. Original waypoint metadata/count and Zeus receipt protect handover,
 * while normal forward waypoint-index progression does not pretend the tail has crossed.
 * Current callers: ConvoyTick, ConvoyCrewLocal and ConvoyReleaseLocal.
 * Example: private _passage=[_group,_configuration] call WAIT_fnc_ConvoyCorridorStep;
 */
params [["_group",grpNull,[grpNull]],["_configuration",[],[[]]],["_cancel","",[""]]];
private _inactive=[false,createHashMap,0,0];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _group} || {!local _group}) exitWith {_inactive};
private _revision=_configuration param [0,-1];
private _episode=_group getVariable ["WAIT_Convoy_CorridorPassage",createHashMap];
private _retire={
    params ["_reason",["_status","INCOMPLETE"]];
    _group setVariable ["WAIT_Convoy_CorridorResult",[_status,_reason,serverTime,
        _episode get "rows",_episode get "area",_episode get "revision",_episode get "identity"],true];
    _group setVariable ["WAIT_Convoy_CorridorPassage",nil,true];
    _inactive
};
if (_cancel != "") exitWith {
    if (count _episode > 0 && {(_episode get "revision") == _revision}) then {[_cancel,"CANCELLED"] call _retire} else {_inactive}
};
private _brain=_group getVariable ["WAIT_Convoy_Brain",createHashMap];
if (count _brain == 0 || {_brain getOrDefault ["cancelled",false]}
    || {(_brain getOrDefault ["configuration",[]]) isNotEqualTo _configuration}
    || {(_brain getOrDefault ["registryRevision",-1]) != (missionNamespace getVariable ["WAIT_Convoy_ReceivedRevision",-2])}
    || {(_brain getOrDefault ["jobToken",""]) isNotEqualTo (_group getVariable ["WAIT_Convoy_LocalJobToken",""])}
    || {(missionNamespace getVariable ["WAIT_Convoy_LocalRegistry",[]]) findIf {
        (_x select 0) isEqualTo _group && {(_x select 1) isEqualTo _configuration}
    } < 0}) exitWith {_inactive};
if (count _episode == 0) then {
    private _lead=(_group getVariable ["WAIT_Convoy_LocalState",createHashMap]) getOrDefault ["lead",objNull];
    private _work=_lead getVariable ["WAIT_DrivingCorridor_Work",createHashMap];
    private _vehicles=_configuration param [4,[]];
    private _identity=[_work getOrDefault ["context",[]],_work getOrDefault ["hardDeadline",-1]];
    private _terminal=_group getVariable ["WAIT_Convoy_CorridorResult",[]];
    if ((_terminal param [6,[]]) isNotEqualTo _identity && {count _work > 0} && {count _vehicles > 0} && {count _vehicles <= 20}
        && {(_work getOrDefault ["controller",[]]) isEqualTo ["CONVOY",_revision]}) then {
        private _rows=_vehicles apply {[_x,driver _x,effectiveCommander _x,false,false]};
        private _route=_work get "route";
        _episode=createHashMapFromArray [["identity",_identity],["lead",_lead],["started",serverTime],["revision",_revision],["area",_work get "area"],
            ["definition",_work get "definition"],["transform",_work get "transform"],
            ["travel",_work get "travel"],["asl",_work get "asl"],["far",_work get "far"],
            ["route",_route],["routeIndex",(_route select 0) select 0],["routeCount",count waypoints _group],
            ["zeus",+(_group getVariable ["WAIT_AIPass_ZeusHold",[]])],
            ["deadline",_work get "tailDeadline"],["rows",_rows]];
        _group setVariable ["WAIT_Convoy_CorridorPassage",_episode,true];
    };
};
if (count _episode == 0) exitWith {_inactive};
if ((_episode get "revision") != _revision || {(_configuration param [5,""]) != "TRAVEL"}) exitWith {["CONFIGURATION_CHANGED","CANCELLED"] call _retire};
if (!([_group,"WAIT_Convoy_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled)
    || {[_group] call WAIT_fnc_CortexExternalTakeover} || {[_group] call WAIT_fnc_CortexZeusHeld}
    || {(_group getVariable ["WAIT_AIPass_ZeusHold",[]]) isNotEqualTo (_episode get "zeus")}) exitWith {["OWNER_CHANGED","CANCELLED"] call _retire};
private _area=_episode get "area";private _definition=_episode get "definition";
if (isNull _area || {(_area getVariable ["WAIT_DrivingCorridor_Task",[]]) isNotEqualTo _definition}
    || {[getPosWorld _area,vectorDir _area,vectorUp _area] isNotEqualTo (_episode get "transform")}) exitWith {["AREA_CHANGED","CANCELLED"] call _retire};
private _index=_episode get "routeIndex";
if (count waypoints _group != (_episode get "routeCount") || {currentWaypoint _group < _index}
    || {([_group,"",false,_index] call WAIT_fnc_AuthoredRouteReceipt) isNotEqualTo (_episode get "route")}) exitWith {["ORDER_CHANGED","CANCELLED"] call _retire};
if (serverTime >= (_episode get "deadline")) exitWith {["TAIL_TIMEOUT"] call _retire};
private _rows=_episode get "rows";
if (count _rows == 0 || {count _rows > 20}) exitWith {["INVALID_ROSTER"] call _retire};
private _lead=_episode get "lead";
private _leadWork=_lead getVariable ["WAIT_DrivingCorridor_Work",createHashMap];
private _leadResult=_lead getVariable ["WAIT_DrivingCorridor_Result",[]];
private _leadRow=_rows findIf {(_x select 0) isEqualTo _lead};
if (_leadRow >= 0 && {!((_rows select _leadRow) select 4)} && {count _leadWork == 0}
    && {(_leadResult param [1,-1]) >= (_episode get "started")}
    && {(_leadResult param [2,objNull]) isEqualTo _area}
    && {(_leadResult param [0,""]) != "PHYSICALLY_CROSSED"}) exitWith {
    ["LEAD_"+(_leadResult param [0,"FAILED"])] call _retire
};
private _caps=createHashMap;private _crossed=0;private _changed=false;private _failure="";
private _travel=_episode get "travel";private _right=[_travel select 1,-(_travel select 0),0];
private _centre=getPosASL _area;private _far=_episode get "far";private _halfLength=_definition select 1;
private _asl=_episode get "asl";private _exit=_asl select ((count _asl)-1);
private _targetSpeed=(_definition select 3)/3.6;
{
    private _row=_x;
    _row params ["_vehicle","_driver","_operator","_entered","_passed"];
    if (_passed) then {_crossed=_crossed+1} else {
        if (isNull _vehicle || {!alive _vehicle} || {!canMove _vehicle}
            || {!local _vehicle} || {driver _vehicle != _driver} || {effectiveCommander _vehicle != _operator}
            || {isNull _driver} || {isNull _operator} || {group _driver != _group}
            || {!([_driver] call WAIT_fnc_CortexCombatEffective)}) then {_failure="VEHICLE_UNAVAILABLE"} else {
            private _origin=getPosASL _vehicle;private _projection=(_origin vectorDiff _centre) vectorDotProduct _travel;
            private _bounds=boundingBoxReal _vehicle;private _low=_bounds select 0;private _high=_bounds select 1;
            private _tailClear=true;private _insideWidth=true;
            {
                private _xCoord=_x;
                {private _yCoord=_x;{
                    private _corner=_vehicle modelToWorldWorld [_xCoord,_yCoord,_x];
                    if ((_corner vectorDiff _far) vectorDotProduct _travel < 5) then {_tailClear=false};
                    if (abs ((_corner vectorDiff _centre) vectorDotProduct _right) > (_definition select 2)+0.5) then {_insideWidth=false};
                } forEach [_low select 2,_high select 2];} forEach [_low select 1,_high select 1];
            } forEach [_low select 0,_high select 0];
            private _nearest=_asl select 0;private _distance=1e9;
            {private _d=_origin distance2D _x;if (_d < _distance) then {_distance=_d;_nearest=_x}} forEach _asl;
            private _level=abs ((_origin select 2)-(_nearest select 2)) <= 2;
            if (abs _projection <= _halfLength && {!_insideWidth || {!_level}}) then {_failure="TAIL_DEPARTED_CORRIDOR"};
            if (!_entered && {_projection >= -_halfLength} && {_projection <= -_halfLength+15}
                && {_insideWidth} && {_level}) then {_row set [3,true];_entered=true;_changed=true};
            if (_entered && {_tailClear} && {_insideWidth} && {_origin distance2D _exit <= 20}
                && {abs ((_origin select 2)-(_exit select 2)) <= 2}) then {
                _row set [4,true];_crossed=_crossed+1;_changed=true;
            } else {
                // Lower the existing follower speed writer progressively before entry. This
                // nominal mass-based braking ceiling does not prove physical braking distance.
                private _body=(abs (_low select 1)) max (abs (_high select 1));
                private _room=(-_halfLength-_projection-_body-6) max 0;
                private _mass=((1+(((getMass _vehicle)-3000)/7000)) max 1) min 2.5;
                private _deceleration=4/_mass;private _reaction=4*_deceleration;
                private _cap=(sqrt (((_targetSpeed+_reaction)^2)+2*_deceleration*_room)-_reaction) max _targetSpeed;
                _caps set [netId _vehicle,_cap];
            };
        };
    };
} forEach _rows;
if (_failure != "") exitWith {[_failure] call _retire};
if (_crossed == count _rows && {count _rows > 0}) exitWith {["ALL_VEHICLES_PHYSICALLY_CROSSED","COMPLETE"] call _retire};
if (_changed) then {_episode set ["rows",_rows];_group setVariable ["WAIT_Convoy_CorridorPassage",_episode,true]};
[true,_caps,_crossed,count _rows]

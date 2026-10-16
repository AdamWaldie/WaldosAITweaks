/*
 * Author: WaldoTheWarfighter
 * Purpose: Records ordered physical bypass passage for every snapshotted convoy vehicle.
 * Locality / Authority: Current owner-local registry brain only; no movement or speed commands.
 * Repeat/JIP: Public original deadline, route/Zeus/obstacle receipts and checkpoint indices survive
 * migration without replay or clock renewal. Terminal identity prevents failed episode recreation.
 * Arguments: 0 group <GROUP, grpNull>; 1 configuration <ARRAY, []>; 2 cancel reason <STRING, empty>.
 * Return Value: ARRAY [active BOOL, capsMps HASHMAP keyed netId, passed NUMBER, required NUMBER].
 * Approach caps use current hull distance and the existing nominal mass/reaction model;
 * after ordered first-checkpoint entry the ceiling is 8 km/h until actual full-hull passage.
 * Bounds: at most 20 vehicles, 24 checkpoints, four checkpoint advances/eight hull corners per
 * vehicle per callback; metadata only, no rays or world scans. Lead passage cannot pass followers.
 * Owner-local pose observations capture short passed checkpoint segments, bound to the exact
 * episode/job token. Migration or gaps over three seconds discard inferred passage.
 * Current callers: ConvoyTick, ConvoyCrewLocal and ConvoyReleaseLocal.
 * Example: private _passage=[_group,_configuration] call WAIT_fnc_ConvoyBypassStep;
 */
params [["_group",grpNull,[grpNull]],["_configuration",[],[[]]],["_cancel","",[""]]];
private _inactive=[false,createHashMap,0,0];
if (isRemoteExecuted || {isNull _group} || {!local _group}) exitWith {_inactive};
private _revision=_configuration param [0,-1];
private _episode=_group getVariable ["WAIT_Convoy_BypassPassage",createHashMap];
private _retire={
    params ["_reason",["_status","INCOMPLETE"]];
    _group setVariable ["WAIT_Convoy_BypassResult",[_status,_reason,serverTime,
        _episode get "rows",_episode get "obstacle",_episode get "revision",_episode get "identity"],true];
    _group setVariable ["WAIT_Convoy_BypassPassage",nil,true];
    _group setVariable ["WAIT_Convoy_BypassCapture",nil];_inactive
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
    private _work=_lead getVariable ["WAIT_DrivingBypass_Work",createHashMap];
    private _identity=[_work getOrDefault ["context",[]],_work getOrDefault ["deadline",-1]];
    private _terminal=_group getVariable ["WAIT_Convoy_BypassResult",[]];
    private _vehicles=_configuration param [4,[]];
    if (count _work > 0 && {(_work getOrDefault ["phase",""]) == "FOLLOW"}
        && {(_work getOrDefault ["controller",[]]) isEqualTo ["CONVOY",_revision]}
        && {(_terminal param [6,[]]) isNotEqualTo _identity} && {count _vehicles > 0} && {count _vehicles <= 20}) then {
        private _route=_work get "route";
        _episode=createHashMapFromArray [["identity",_identity],["lead",_lead],["started",serverTime],
            ["revision",_revision],["obstacle",_work get "obstacle"],["transform",_work get "transform"],
            ["points",_work get "points"],["far",_work get "far"],["forward",_work get "forward"],
            ["route",_route],["routeIndex",(_route select 0) select 0],["routeCount",count waypoints _group],
            ["zeus",+(_group getVariable ["WAIT_AIPass_ZeusHold",[]])],["deadline",_work get "tailDeadline"],
            ["rows",_vehicles apply {[_x,driver _x,effectiveCommander _x,0,false]}]];
        _group setVariable ["WAIT_Convoy_BypassPassage",_episode,true];
    };
};
if (count _episode == 0) exitWith {_inactive};
if ((_episode get "revision") != _revision || {(_configuration param [5,""]) != "TRAVEL"}) exitWith {["CONFIGURATION_CHANGED","CANCELLED"] call _retire};
if (!([_group,"WAIT_Convoy_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled)
    || {!([_group,"WAIT_Convoy_RouteRecovery_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {[_group] call WAIT_fnc_CortexExternalTakeover} || {[_group] call WAIT_fnc_CortexZeusHeld}
    || {(_group getVariable ["WAIT_AIPass_ZeusHold",[]]) isNotEqualTo (_episode get "zeus")}) exitWith {["OWNER_CHANGED","CANCELLED"] call _retire};
private _obstacle=_episode get "obstacle";
if (isNull _obstacle || {abs speed _obstacle > 0.5}
    || {[getPosWorld _obstacle,vectorDir _obstacle,vectorUp _obstacle] isNotEqualTo (_episode get "transform")}) exitWith {["OBSTACLE_CHANGED","CANCELLED"] call _retire};
private _index=_episode get "routeIndex";
if (count waypoints _group != (_episode get "routeCount") || {currentWaypoint _group < _index}
    || {([_group,"",false,_index] call WAIT_fnc_AuthoredRouteReceipt) isNotEqualTo (_episode get "route")}) exitWith {["ORDER_CHANGED","CANCELLED"] call _retire};
if (serverTime >= (_episode get "deadline")) exitWith {["TAIL_TIMEOUT"] call _retire};
private _rows=_episode get "rows";private _points=_episode get "points";
if (count _rows == 0 || {count _rows > 20} || {count _points < 2} || {count _points > 24}) exitWith {["INVALID_EPISODE"] call _retire};
private _lead=_episode get "lead";private _leadWork=_lead getVariable ["WAIT_DrivingBypass_Work",createHashMap];
private _leadResult=_lead getVariable ["WAIT_DrivingBypass_Result",[]];
if (count _leadWork == 0 && {(_leadResult param [1,-1]) >= (_episode get "started")}
    && {(_leadResult param [2,objNull]) == _obstacle} && {(_leadResult param [0,""]) != "PHYSICALLY_PASSED"}) exitWith {
    ["LEAD_"+(_leadResult param [0,"FAILED"])] call _retire
};
private _captureIdentity=[_episode get "identity",clientOwner,_brain getOrDefault ["jobToken",""]];
private _captureState=_group getVariable ["WAIT_Convoy_BypassCapture",[]];
private _captures=if (count _captureState == 2 && {(_captureState select 0) isEqualTo _captureIdentity}) then {
    _captureState select 1
} else {createHashMap};
private _nextCaptures=createHashMap;
private _caps=createHashMap;private _passedCount=0;private _changed=false;private _failure="";
{
    private _row=_x;_row params ["_vehicle","_driver","_operator","_checkpoint","_passed"];
    if (_passed) then {_passedCount=_passedCount+1} else {
        if (isNull _vehicle || {!alive _vehicle} || {!canMove _vehicle} || {!local _vehicle}
            || {driver _vehicle != _driver} || {effectiveCommander _vehicle != _operator}
            || {[_driver,_operator] findIf {isNull _x || {!local _x} || {group _x != _group}
                || {!([_x] call WAIT_fnc_CortexCombatEffective)} || {isPlayer _x} || {!isNull remoteControlled _x}
                || {[_x] call WAIT_fnc_CortexExternalOwner != ""}} >= 0}) then {_failure="VEHICLE_UNAVAILABLE"} else {
            private _origin=getPosASL _vehicle;
            private _capture=_captures getOrDefault [netId _vehicle,[]];
            private _previous=+_origin;
            if (count _capture == 2 && {serverTime >= (_capture select 1)}
                && {serverTime-(_capture select 1) <= 3}
                && {_origin vectorDistance (_capture select 0) <= 12}) then {_previous=+(_capture select 0)};
            private _sweep=_origin vectorDiff _previous;
            private _sweepXY=+_sweep;_sweepXY set [2,0];
            private _squared=_sweepXY vectorDotProduct _sweepXY;private _lastFraction=0;
            for "_i" from 1 to 4 do {
                if (_checkpoint >= count _points) exitWith {};
                private _point=_points select _checkpoint;
                private _offset=_point vectorDiff _previous;_offset set [2,0];
                private _fraction=if (_squared > 0.01) then {((_offset vectorDotProduct _sweepXY)/_squared) max 0 min 1} else {1};
                private _closest=_previous vectorAdd (_sweep vectorMultiply _fraction);
                if (_fraction < _lastFraction || {_closest distance2D _point > 3.5}
                    || {abs ((_closest select 2)-(_point select 2)) > 2}) exitWith {};
                _lastFraction=_fraction;_checkpoint=_checkpoint+1;
            };
            _nextCaptures set [netId _vehicle,[+_origin,serverTime]];
            if (_checkpoint != (_row select 3)) then {_row set [3,_checkpoint];_changed=true};
            private _clear=_checkpoint >= count _points;
            if (_clear) then {
                private _bounds=boundingBoxReal _vehicle;private _low=_bounds select 0;private _high=_bounds select 1;
                {private _xCoord=_x;{private _yCoord=_x;{
                    private _corner=_vehicle modelToWorldWorld [_xCoord,_yCoord,_x];
                    if ((_corner vectorDiff (_episode get "far")) vectorDotProduct (_episode get "forward") < 5) then {_clear=false};
                } forEach [_low select 2,_high select 2];} forEach [_low select 1,_high select 1];} forEach [_low select 0,_high select 0];
            };
            if (_clear) then {_row set [4,true];_changed=true;_passedCount=_passedCount+1} else {
                // Distant followers keep approach room rather than inheriting an immediate
                // whole-column crawl. Ordered first-checkpoint entry ends this allowance.
                private _room=0;
                if (_checkpoint == 0) then {
                    private _bounds=boundingBoxReal _vehicle;private _low=_bounds select 0;private _high=_bounds select 1;
                    private _body=(abs (_low select 1)) max (abs (_high select 1));
                    _room=((_origin distance2D (_points select 0))-_body-6) max 0;
                };
                private _mass=((1+(((getMass _vehicle)-3000)/7000)) max 1) min 2.5;
                private _deceleration=4/_mass;private _reaction=4*_deceleration;private _target=8/3.6;
                private _cap=(sqrt (((_target+_reaction)^2)+2*_deceleration*_room)-_reaction) max _target;
                _caps set [netId _vehicle,_cap];
            };
        };
    };
} forEach _rows;
_group setVariable ["WAIT_Convoy_BypassCapture",[_captureIdentity,_nextCaptures]];
if (_failure != "") exitWith {[_failure] call _retire};
if (_passedCount == count _rows) exitWith {["ALL_VEHICLES_PHYSICALLY_PASSED","COMPLETE"] call _retire};
if (_changed) then {_episode set ["rows",_rows];_group setVariable ["WAIT_Convoy_BypassPassage",_episode,true]};
[true,_caps,_passedCount,count _rows]

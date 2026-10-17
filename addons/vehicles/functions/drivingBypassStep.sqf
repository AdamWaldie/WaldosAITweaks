/*
 * Author: WaldoTheWarfighter
 * Purpose: Runs one finite ordinary/convoy-lead bypass PLAN/FOLLOW step through the existing controller.
 * Locality / Authority: Internal synchronous owner callback only. Current driving brain and the
 * caller's fresh authority predicate and internal plain-route/crew gates protect every command. Never remote.
 * New PLAN acquisition preserves native STOP/FOLLOW/ATTACK/unowned WAIT on either seat;
 * its two actors must be idle or moving to the full three-dimensional authored destination. Owned FOLLOW-phase
 * doStop receipts retain their separate retirement contract.
 * Individual actor reservations on either seat veto acquisition and every later command.
 * Repeat/JIP: Public serializable work stores original 90-second deadline, two-side attempt budget,
 * path/checkpoint/seat/route receipts. New owners adopt without command replay or clock renewal.
 * Arguments: 0 group <GROUP, grpNull>; 1 vehicle <OBJECT, objNull>; 2 brain <HASHMAP, empty>;
 * 3 fresh solid observation <ARRAY, []>; 4 authority predicate <CODE, {false}>, local only;
 * 5 controller <STRING, ORDINARY> - ORDINARY or CONVOY; followers never enter this executor.
 * Return Value: ARRAY [active BOOL, capMps NUMBER, phase STRING, sourceConstraintMayYield BOOL].
 * Bounds: one side proposal per callback (max two); FOLLOW validates one actual next segment
 * (at most 15 rays) and advances at most four ordered physical checkpoints per callback.
 * Capture uses current pose or a <=3-second, <=12-metre observed ASL segment; it is not
 * replayed across owner epochs or treated as proof of continuous collision-free travel. No new scheduler.
 * Full ordered checkpoint visit and actual tail clearance alone complete. Invalid geometry,
 * command/owner changes, obstacle crew/engine/attachment changes and deadline expiry retain failure; no elapsed-time or ready success.
 * Current callers: DrivingAssistStart and ConvoyTick. Convoy followers retain predecessor trails.
 * Neither path acceptance nor this API is physical QA.
 * Example: [_group,_vehicle,_brain,_solid,_mayRecoverRoute] call WAIT_fnc_DrivingBypassStep;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],["_brain",createHashMap,[createHashMap]],
    ["_observed",[],[[]]],["_authority",{false},[{}]],["_controller","ORDINARY",[""]]];
private _inactive=[false,1e6,"",false];
if (isRemoteExecuted) exitWith {_inactive};
if (!(_controller in ["ORDINARY","CONVOY"])) exitWith {_inactive};
private _convoy=_controller == "CONVOY";
private _configuration=_brain getOrDefault ["configuration",[]];
private _controllerReceipt=[_controller,if (_convoy) then {_configuration param [0,-1]} else {-1}];
private _route=[_group] call WAIT_fnc_DrivingRouteReceipt;
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
private _seatsAvailable={
    [_driver,_operator] findIf {
        isNull _x || {!local _x} || {group _x != _group} || {vehicle _x != _vehicle}
            || {!([_x] call WAIT_fnc_CortexCombatEffective)}
            || {[_x] call WAIT_fnc_CortexActorMoveReserved} || {isPlayer _x}
            || {!isNull remoteControlled _x} || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {[_x] call WAIT_fnc_CortexExternalOwner != ""}
            || {!simulationEnabled _x} || {isObjectHidden _x}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN",
                "REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID",
                "HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}
    } < 0
};
// This executor must enforce authored intent itself before it can be shared by another controller.
private _plainRoute={
    private _index=currentWaypoint _group;
    if (_index <= 0 || {_index >= count waypoints _group}) exitWith {false};
    private _waypoint=[_group,_index];private _statements=waypointStatements _waypoint;
    private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
    waypointType _waypoint == "MOVE" && {_condition == "true"}
        && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
        && {waypointScript _waypoint == ""} && {(waypointTimeout _waypoint param [2,0]) <= 0}
        && {isNull waypointAttachedVehicle _waypoint} && {isNull waypointAttachedObject _waypoint}
        && {(synchronizedWaypoints _waypoint) isEqualTo []} && {(synchronizedTriggers _waypoint) isEqualTo []}
};
// Before any alternate movement exists, only idle or route-matching native MOVE
// commands authorize acquisition. STOP/FOLLOW/ATTACK and unowned WAIT are not consent.
private _nativeAdmissionReady={
    private _destination=waypointPosition [_group,currentWaypoint _group];
    [_driver,_operator] findIf {
        private _command=toUpperANSI currentCommand _x;
        private _target=(expectedDestination _x) param [0,[],[[]]];
        _command != "" && {_command != "MOVE" || {count _target != 3
            || {_target findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {_target vectorDistance _destination > 3}
        }}
    } < 0
};
private _controllerCurrent={
    if (_convoy) exitWith {
        private _mobile=(_configuration param [4,[]]) select {
            alive _x && {canMove _x} && {[driver _x] call WAIT_fnc_CortexCombatEffective}
                && {group driver _x == _group}
        };
        (_group getVariable ["WAIT_Convoy_Brain",createHashMap]) isEqualTo _brain
            && {(_brain getOrDefault ["registryRevision",-1]) == (missionNamespace getVariable ["WAIT_Convoy_ReceivedRevision",-2])}
            && {(_brain getOrDefault ["jobToken",""]) isEqualTo (_group getVariable ["WAIT_Convoy_LocalJobToken",""])}
            && {(missionNamespace getVariable ["WAIT_Convoy_LocalRegistry",[]]) findIf {
                (_x select 0) isEqualTo _group && {(_x select 1) isEqualTo _configuration}
            } >= 0}
            && {(_configuration param [5,""]) == "TRAVEL"}
            && {count (_configuration param [4,[]]) <= 20}
            && {_mobile isNotEqualTo []} && {(_mobile select 0) isEqualTo _vehicle}
            && {_mobile findIf {!local _x || {!local driver _x}} < 0}
            && {_vehicle getVariable ["WAIT_Convoy_Active",false]}
            && {(_vehicle getVariable ["WAIT_Convoy_Group",grpNull]) == _group}
            && {[_group,"WAIT_Convoy_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
            && {[_group,false,false,true] call WAIT_fnc_CortexIsEligible}
    };
    (_group getVariable ["WAIT_Driving_Brain",createHashMap]) isEqualTo _brain
        && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {(_brain getOrDefault ["route",[]]) isEqualTo _route}
        && {[_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
        && {[_group] call WAIT_fnc_DrivingMovementAvailable}
        && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
        && {vehicle leader _group isEqualTo _vehicle}
};
private _mayWrite={
    !isNull _group && {local _group} && {!isNull _vehicle} && {local _vehicle}
        && {call _controllerCurrent}
        && {!(_brain getOrDefault ["cancelled",false])}
        && {_route isNotEqualTo []} && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {call _plainRoute} && {call _authority} && {call _seatsAvailable}
        && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
        && {!([_group] call WAIT_fnc_CortexExternalTakeover)} && {!([_group] call WAIT_fnc_CortexZeusHeld)}
        && {alive _vehicle} && {canMove _vehicle} && {driver _vehicle == _driver} && {effectiveCommander _vehicle == _operator}
        && {[_group,["WAIT_AIPass_DrivingAssist_Recovery_Enable","WAIT_Convoy_RouteRecovery_Enable"] select _convoy,true] call WAIT_fnc_CortexFeatureEnabled}
        && {isAISteeringComponentEnabled _vehicle} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
        && {isNil {_vehicle getVariable "WAIT_DrivingCorridor_Work"}}
};
private _captureOwner=[clientOwner,_brain getOrDefault ["ownerEpoch",-1],_brain getOrDefault ["jobToken",""],_brain getOrDefault ["generation",-1]];
private _work=_vehicle getVariable ["WAIT_DrivingBypass_Work",createHashMap];
if (!(call _mayWrite)) exitWith {
    if ((_work getOrDefault ["controller",["ORDINARY",-1]]) isEqualTo _controllerReceipt) then {
        [_vehicle,_group,"AUTHORITY_ENDED"] call WAIT_fnc_DrivingBypassRelease;
    };_inactive
};
if (count _work > 0 && {(_work get "group") != _group}) then {
    _vehicle setVariable ["WAIT_DrivingBypass_Work",nil,true];_work=createHashMap;
};
if (count _work > 0 && {(_work getOrDefault ["controller",["ORDINARY",-1]]) isNotEqualTo _controllerReceipt}) then {
    [_vehicle,_group,"CONTROLLER_CHANGED",false,true] call WAIT_fnc_DrivingBypassRelease;_work=createHashMap;
};
if (count _work == 0 && {!_convoy || {isNil {_group getVariable "WAIT_Convoy_BypassPassage"}}}) then {
    if (count _observed == 9 && {(_observed select 5) == "STATIC"} && {!isNull (_observed select 1)}
        && {abs speed _vehicle <= 8}) then {
        private _context=[_group,_route,_observed select 1,_driver,_operator,_controllerReceipt];
        private _cooldown=_vehicle getVariable ["WAIT_DrivingBypass_Cooldown",[]];
        private _command=expectedDestination _operator;
        if (_cooldown findIf {(_x select 0) isEqualTo _context && {(_x select 1) > serverTime}} < 0
            && {call _nativeAdmissionReady}) then {
            _work=createHashMapFromArray [["group",_group],["route",_route],["driver",_driver],["operator",_operator],
                ["context",_context],["controller",_controllerReceipt],["obstacle",_observed select 1],["transform",_observed select 8],
                ["deadline",serverTime+90],["side",1],["phase","PLAN"],["index",0],
                ["command",+_command],["driverCommand",+(expectedDestination _driver)],
                ["driverTask",toUpperANSI currentCommand _driver],["operatorTask",toUpperANSI currentCommand _operator]];
            _vehicle setVariable ["WAIT_DrivingBypass_Work",_work,true];
        };
    };
};
if (count _work == 0) exitWith {_inactive};
private _obstacle=_work get "obstacle";private _reason="";
if ((_work get "route") isNotEqualTo _route || {(_work get "driver") != _driver} || {(_work get "operator") != _operator}
    || {(expectedDestination _operator) isNotEqualTo (_work get "command")}
    || {(expectedDestination _driver) isNotEqualTo (_work get "driverCommand")}
    || {(toUpperANSI currentCommand _driver) != (_work getOrDefault ["driverTask","__MISSING__"])}
    || {(toUpperANSI currentCommand _operator) != (_work getOrDefault ["operatorTask","__MISSING__"])}) then {_reason="COMMAND_CHANGED"};
if (_reason == "" && {(_work get "phase") == "PLAN"} && {!(call _nativeAdmissionReady)}) then {_reason="COMMAND_CHANGED"};
if (_reason == "" && {!([_obstacle] call WAIT_fnc_DrivingBypassObstacleAvailable)
    || {[getPosWorld _obstacle,vectorDir _obstacle,vectorUp _obstacle] isNotEqualTo (_work get "transform")}}) then {_reason="OBSTACLE_CHANGED"};
if (_reason == "" && {serverTime >= (_work get "deadline")}) then {_reason="TIMEOUT"};
if (_reason != "") exitWith {[_vehicle,_group,_reason,_reason != "COMMAND_CHANGED"] call WAIT_fnc_DrivingBypassRelease;_inactive};
if ((_work get "phase") == "PLAN") exitWith {
    if (count _observed != 9 || {(_observed select 1) != _obstacle} || {(_observed select 8) isNotEqualTo (_work get "transform")}) exitWith {
        [_vehicle,_group,"OBSERVATION_CHANGED"] call WAIT_fnc_DrivingBypassRelease;_inactive
    };
    private _envelope=[];private _columnLength=0;
    if (_convoy) then {
        _envelope=[0,0,0];
        {
            private _bounds=boundingBoxReal _x;private _lo=_bounds select 0;private _hi=_bounds select 1;
            _envelope set [0,(_envelope select 0) max ((abs (_lo select 0)) max (abs (_hi select 0)))];
            _envelope set [1,(_envelope select 1) max ((abs (_lo select 1)) max (abs (_hi select 1)))];
            _envelope set [2,(_envelope select 2) max ((_hi select 2)-(_lo select 2))];
            _columnLength=_columnLength+((_hi select 1)-(_lo select 1))+(_configuration param [2,30]);
        } forEach (_configuration param [4,[]]);
    };
    private _proposal=[_vehicle,_observed,_work get "side",_envelope] call WAIT_fnc_DrivingBypassPlan;
    if (!(_proposal select 0)) exitWith {
        if ((_work get "side") == 1) then {
            _work set ["side",-1];_vehicle setVariable ["WAIT_DrivingBypass_Work",_work,true];
            [true,8/3.6,"BYPASS_PLAN",false]
        } else {[_vehicle,_group,_proposal select 1] call WAIT_fnc_DrivingBypassRelease;_inactive}
    };
    private _points=_proposal select 2;private _asl=_proposal select 3;
    private _destination=ATLToASL waypointPosition [_group,currentWaypoint _group];
    private _forward=vectorDir _vehicle;_forward set [2,0];_forward=vectorNormalized _forward;
    private _exit=_asl select ((count _asl)-1);
    if ((_destination vectorDiff _exit) vectorDotProduct _forward < _columnLength+(waypointCompletionRadius [_group,currentWaypoint _group] max 20)+10) exitWith {
        [_vehicle,_group,"DESTINATION_CLEARANCE"] call WAIT_fnc_DrivingBypassRelease;_inactive
    };
    if (!(call _mayWrite) || {!([_obstacle] call WAIT_fnc_DrivingBypassObstacleAvailable)} || {!(call _nativeAdmissionReady)} || {(expectedDestination _operator) isNotEqualTo (_work get "command")}
        || {(expectedDestination _driver) isNotEqualTo (_work get "driverCommand")}) exitWith {_inactive};
    private _box=boundingBoxReal _vehicle;private _low=_box select 0;private _high=_box select 1;
    private _halfWidth=((abs (_low select 0)) max (abs (_high select 0))) max (_envelope param [0,0]);
    private _halfLength=((abs (_low select 1)) max (abs (_high select 1))) max (_envelope param [1,0]);
    private _radius=sqrt ((_halfWidth^2)+(_halfLength^2))+1;
    if (_operator != _driver) then {doStop _operator};doStop _driver;
    _vehicle setDriveOnPath _points;
    _work set ["phase","FOLLOW"];_work set ["points",_asl];_work set ["index",1];
    _work set ["capture",[getPosASL _vehicle,serverTime,+_captureOwner]];
    _work set ["radius",_radius];_work set ["height",((_high select 2)-(_low select 2)) max (_envelope param [2,0])];
    _work set ["tailDeadline",(_work get "deadline")+((_columnLength/(8/3.6)+60) min 1710)];
    _work set ["forward",_forward];_work set ["far",_exit vectorDiff (_forward vectorMultiply (_radius+10))];
    _work set ["command",+(expectedDestination _operator)];_work set ["driverCommand",+(expectedDestination _driver)];
    _work set ["driverTask",toUpperANSI currentCommand _driver];_work set ["operatorTask",toUpperANSI currentCommand _operator];
    _vehicle setVariable ["WAIT_DrivingBypass_Work",_work,true];
    [true,8/3.6,"BYPASS_FOLLOW",false]
};
private _points=_work get "points";private _index=_work get "index";private _origin=getPosASL _vehicle;
// A callback can arrive after a checkpoint was passed. Capture only the next ordered
// prefix against a short observed movement segment, never an arbitrary nearest future point.
private _capture=_work getOrDefault ["capture",[]];
private _previous=+_origin;
if (count _capture == 3 && {(_capture select 2) isEqualTo _captureOwner}
    && {serverTime >= (_capture select 1)} && {serverTime-(_capture select 1) <= 3}
    && {_origin vectorDistance (_capture select 0) <= 12}) then {_previous=+(_capture select 0)};
private _sweep=_origin vectorDiff _previous;
private _sweepXY=+_sweep;_sweepXY set [2,0];
private _squared=_sweepXY vectorDotProduct _sweepXY;
private _lastFraction=0;
for "_i" from 1 to 4 do {
    if (_index >= count _points) exitWith {};
    private _point=_points select _index;
    private _offset=_point vectorDiff _previous;_offset set [2,0];
    private _fraction=if (_squared > 0.01) then {((_offset vectorDotProduct _sweepXY)/_squared) max 0 min 1} else {1};
    private _closest=_previous vectorAdd (_sweep vectorMultiply _fraction);
    if (_fraction < _lastFraction || {_closest distance2D _point > 2.5} || {abs ((_closest select 2)-(_point select 2)) > 2}) exitWith {};
    _lastFraction=_fraction;_index=_index+1;
};
_work set ["capture",[+_origin,serverTime,+_captureOwner]];
if (_index != (_work get "index")) then {_work set ["index",_index];_vehicle setVariable ["WAIT_DrivingBypass_Work",_work,true]};
if (_index >= count _points) exitWith {
    private _box=boundingBoxReal _vehicle;private _low=_box select 0;private _high=_box select 1;private _clear=true;
    {private _xCoord=_x;{private _yCoord=_x;{
        private _corner=_vehicle modelToWorldWorld [_xCoord,_yCoord,_x];
        if ((_corner vectorDiff (_work get "far")) vectorDotProduct (_work get "forward") < 5) then {_clear=false};
    } forEach [_low select 2,_high select 2];} forEach [_low select 1,_high select 1];} forEach [_low select 0,_high select 0];
    if (_clear) then {[_vehicle,_group,"PHYSICALLY_PASSED"] call WAIT_fnc_DrivingBypassRelease;_inactive}
    else {[true,8/3.6,"BYPASS_FOLLOW",false]}
};
private _next=_points select _index;
private _health=[_vehicle,[_origin,_next],_work get "radius",_work get "height"] call WAIT_fnc_DrivingPathGeometry;
if (!(_health select 0)) exitWith {[_vehicle,_group,"LEG_"+(_health select 1)] call WAIT_fnc_DrivingBypassRelease;_inactive};
[true,8/3.6,"BYPASS_FOLLOW",true]

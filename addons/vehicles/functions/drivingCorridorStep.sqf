/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes a finite current-controller APPROACH/CROSS episode through a registered area.
 * Locality / Authority: Called only by the current ordinary/convoy brain, for its lead vehicle.
 * Shares existing speed/traffic writers; never edits waypoints, transfers locality or enables AI.
 * Separate commander/driver seats require symmetric local task eligibility. Native commander
 * approach hands to an owned two-actor stop/fixed path; crossing watches both command receipts.
 * New acquisition requires both actors idle or route-matching MOVE; native STOP, FOLLOW,
 * ATTACK and unowned WAIT remain authoritative. APPROACH permits its owned arrival wait but
 * rejects a new STOP/other native task before taking fixed steering. CROSS owns its own doStop.
 * Individual actor reservations on either seat veto acquisition and every later command.
 * Repeat/JIP: Public command/seat/route/area receipts allow current-owner adoption without reissue
 * or deadline renewal. Original 120-second approach and half-length+45-second crossing budgets
 * remain finite. Area edits, new orders, changed seats and external ownership retire old work.
 * Arguments: 0 group <GROUP, grpNull>; 1 vehicle <OBJECT, objNull>; 2 brain <HASHMAP, empty>;
 * 3 controller <STRING, ORDINARY> - ORDINARY or CONVOY; never admits convoy followers.
 * Return Value: ARRAY [active BOOL, taskCapMps NUMBER, phase STRING]. False grants no movement.
 * Cost: At most 32 passive area rows per admission; one geometry proposal per eligible area after
 * metadata selection, bounded to 231 rays. Failed proposals and terminal episodes cool down for
 * 120 seconds by exact area revision/transform/route context. No added scheduler or global scan.
 * Current callers: DrivingAssistStart and ConvoyTick; registered areas come from server task dispatch.
 * Example: private _corridor=[_group,_vehicle,_brain] call WAIT_fnc_DrivingCorridorStep;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],
    ["_brain",createHashMap,[createHashMap]],["_controller","ORDINARY",[""]]];
private _inactive=[false,1e6,""];
if (isRemoteExecuted || {!(_controller in ["ORDINARY","CONVOY"])}) exitWith {_inactive};
private _convoy=_controller == "CONVOY";
private _configuration=_brain getOrDefault ["configuration",[]];
private _controllerReceipt=[_controller,if (_convoy) then {_configuration param [0,-1]} else {-1}];
private _route=[_group] call WAIT_fnc_DrivingRouteReceipt;
private _driver=driver _vehicle;
private _operator=effectiveCommander _vehicle;
// A separate commander is an independent command boundary, not permission to bypass its task.
private _crewReady={
    [_driver,_operator] findIf {
        isNull _x || {!local _x} || {group _x != _group} || {vehicle _x != _vehicle}
            || {!([_x] call WAIT_fnc_CortexCombatEffective)}
            || {[_x] call WAIT_fnc_CortexActorMoveReserved} || {isPlayer _x}
            || {!isNull remoteControlled _x}
            || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {[_x] call WAIT_fnc_CortexExternalOwner != ""}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {!simulationEnabled _x} || {isObjectHidden _x}
            || {currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN",
                "REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID",
                "HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}
    } < 0
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
private _approachTasksReady={
    [_driver,_operator] findIf {!(toUpperANSI currentCommand _x in ["","MOVE","WAIT"])} < 0
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
        && {count _brain > 0} && {!(_brain getOrDefault ["cancelled",false])}
        && {call _controllerCurrent} && {_route isNotEqualTo []}
        && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {_convoy || {missionNamespace getVariable ["WAIT_AIPass_Active",false]}}
        && {!([_group] call WAIT_fnc_CortexExternalTakeover)} && {!([_group] call WAIT_fnc_CortexZeusHeld)}
        && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
        && {alive _vehicle} && {canMove _vehicle}
        && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
        && {call _crewReady}
        && {driver _vehicle isEqualTo _driver} && {effectiveCommander _vehicle isEqualTo _operator}
        && {isAISteeringComponentEnabled _vehicle}
};
if (!isNil {_vehicle getVariable "WAIT_DrivingBypass_Work"}) exitWith {_inactive};
private _work=_vehicle getVariable ["WAIT_DrivingCorridor_Work",createHashMap];
if !(call _mayWrite) exitWith {
    [_vehicle,_group,"OWNER_OR_ORDER_CHANGED",false] call WAIT_fnc_DrivingCorridorRelease;
    _inactive
};
// Only an ungated authored MOVE can authorize an alternate path or its native handback.
private _waypoint=[_group,currentWaypoint _group];
private _statements=waypointStatements _waypoint;
private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
private _plain=waypointType _waypoint == "MOVE" && {_condition == "true"}
    && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
    && {waypointScript _waypoint == ""} && {(waypointTimeout _waypoint param [2,0]) <= 0}
    && {isNull waypointAttachedVehicle _waypoint} && {isNull waypointAttachedObject _waypoint}
    && {(synchronizedWaypoints _waypoint) isEqualTo []} && {(synchronizedTriggers _waypoint) isEqualTo []};
if (!_plain) exitWith {
    [_vehicle,_group,"GATED_ORDER",false] call WAIT_fnc_DrivingCorridorRelease;_inactive
};
// A new current driver group can retire an obsolete journal, never its old movement command.
if (count _work > 0 && {(_work getOrDefault ["group",grpNull]) != _group}) then {
    _vehicle setVariable ["WAIT_DrivingCorridor_Work",nil,true];_work=createHashMap;
};
if (count _work > 0) exitWith {
    private _area=_work get "area";private _definition=_work get "definition";
    private _reason="";
    if ((_work get "group") != _group || {(_work get "route") isNotEqualTo _route}
        || {(_work get "driver") != _driver} || {(_work get "operator") != _operator}
        || {(expectedDestination _operator) isNotEqualTo (_work get "command")}
        || {(_work getOrDefault ["phase",""]) == "CROSS" && {
            (expectedDestination _driver) isNotEqualTo (_work getOrDefault ["driverCommand",[]])
        }}) then {_reason="COMMAND_CHANGED"};
    if (_reason isEqualTo "" && {(_work getOrDefault ["phase",""]) == "APPROACH"}
        && {!(call _approachTasksReady)}) then {_reason="COMMAND_CHANGED"};
    if (_reason isEqualTo "" && {(_work getOrDefault ["controller",[]]) isNotEqualTo _controllerReceipt}) then {
        _reason="CONTROLLER_CHANGED";
    };
    if (_reason isEqualTo "" && {isNull _area || {
        (_area getVariable ["WAIT_DrivingCorridor_Task",[]]) isNotEqualTo _definition
        || {[getPosWorld _area,vectorDir _area,vectorUp _area] isNotEqualTo (_work get "transform")}
    }}) then {_reason="AREA_CHANGED"};
    if (_reason isEqualTo "" && {serverTime >= (_work get "deadline")}) then {_reason="TIMEOUT"};
    if (_reason isNotEqualTo "") exitWith {
        [_vehicle,_group,_reason,_reason != "COMMAND_CHANGED"] call WAIT_fnc_DrivingCorridorRelease;_inactive
    };
    // Adoption changes only bookkeeping. It cannot restart the original command or clock.
    private _epoch=_group getVariable ["WAIT_AIPass_Epoch",0];
    if ((_work get "epoch") != _epoch) then {
        _work set ["epoch",_epoch];_vehicle setVariable ["WAIT_DrivingCorridor_Work",_work,true];
    };
    private _points=_work get "points";private _asl=_work get "asl";
    private _phase=_work get "phase";
    if (_phase == "APPROACH") then {
        private _entry=_asl select 0;private _forward=vectorDir _vehicle;_forward set [2,0];
        if ((getPosASL _vehicle) distance2D _entry <= 8
            && {abs (((getPosASL _vehicle) select 2)-(_entry select 2)) <= 2}
            && {(vectorNormalized _forward) vectorDotProduct (_work get "travel") >= 0.85}
            && {call _mayWrite} && {call _approachTasksReady}
            && {(expectedDestination _operator) isEqualTo (_work get "command")}) then {
            // Detach only these two owned native movement actors. Do not disable any AI
            // feature, change leader/seats or replay a group-wide stop over other vehicles.
            if (_operator != _driver) then {doStop _operator};
            doStop _driver;
            _vehicle setDriveOnPath _points;
            _work set ["phase","CROSS"];
            _work set ["command",+(expectedDestination _operator)];
            _work set ["driverCommand",+(expectedDestination _driver)];
            _work set ["deadline",(_work get "hardDeadline") min (serverTime+(_definition select 1)+45)];
            _vehicle setVariable ["WAIT_DrivingCorridor_Work",_work,true];_phase="CROSS";
        };
    };
    if (_phase == "CROSS") then {
        private _travel=_work get "travel";private _far=_work get "far";
        private _origin=getPosASL _vehicle;
        private _centre=getPosASL _area;
        private _delta=_origin vectorDiff _centre;
        private _projection=_delta vectorDotProduct _travel;
        private _lateralAxis=[_travel select 1,-(_travel select 0),0];
        private _halfLength=_definition select 1;
        private _withinWidth=true;
        private _box=boundingBoxReal _vehicle;private _low=_box select 0;private _high=_box select 1;
        private _crossed=true;
        {
            private _xCoord=_x;
            {private _yCoord=_x;{
                private _corner=_vehicle modelToWorldWorld [_xCoord,_yCoord,_x];
                if ((_corner vectorDiff _far) vectorDotProduct _travel < 5) then {_crossed=false};
                if (abs ((_corner vectorDiff _centre) vectorDotProduct _lateralAxis) > (_definition select 2)+0.5) then {
                    _withinWidth=false;
                };
            } forEach [_low select 2,_high select 2];} forEach [_low select 1,_high select 1];
        } forEach [_low select 0,_high select 0];
        // An exit pose alone cannot prove corridor passage after a detour around the area.
        // Observe the near plane in order, preserve it across migration, and reject lateral departure.
        if (!_withinWidth && {abs _projection <= _halfLength}) exitWith {
            [_vehicle,_group,"CORRIDOR_DEPARTED"] call WAIT_fnc_DrivingCorridorRelease;
        };
        if (!(_work getOrDefault ["entered",false]) && {_projection >= -_halfLength}
            && {_projection <= (-_halfLength+15)} && {_withinWidth}) then {
            _work set ["entered",true];_vehicle setVariable ["WAIT_DrivingCorridor_Work",_work,true];
        };
        private _exit=_asl select ((count _asl)-1);
        if (_crossed && {_work getOrDefault ["entered",false]} && {_withinWidth} && {(getPosASL _vehicle) distance2D _exit <= 20}
            && {abs (((getPosASL _vehicle) select 2)-(_exit select 2)) <= 2}) exitWith {
            [_vehicle,_group,"PHYSICALLY_CROSSED"] call WAIT_fnc_DrivingCorridorRelease;
        };
    };
    if (isNil {_vehicle getVariable "WAIT_DrivingCorridor_Work"}) then {_inactive}
    else {[true,(_definition select 3)/3.6,"CORRIDOR_"+_phase]}
};
// An unfinished column passage owns this area episode after its lead has handed back.
// Do not admit a second lead corridor while the same revision still has vehicles inside/approaching.
private _passage=_group getVariable ["WAIT_Convoy_CorridorPassage",createHashMap];
if (_convoy && {count _passage > 0} && {(_passage get "revision") == (_configuration param [0,-1])}
    && {serverTime < (_passage get "deadline")}) exitWith {_inactive};
private _destination=waypointPosition _waypoint;
// Do not replace a newer individual MOVE merely because its group route is unchanged.
if !(call _nativeAdmissionReady) exitWith {_inactive};
private _snapshot=missionNamespace getVariable ["WAIT_DrivingCorridor_Snapshot",[0,[]]];
private _records=_snapshot param [1,[]];
if (count _records > 32) exitWith {_inactive};
private _cooldown=(_vehicle getVariable ["WAIT_DrivingCorridor_Cooldown",[]]) select {(_x select 1) > serverTime};
private _selected=[];private _best=1e9;
{
    _x params ["_area","_definition"];
    if (!isNull _area && {count _definition == 4}
        && {(_area getVariable ["WAIT_DrivingCorridor_Task",[]]) isEqualTo _definition}) then {
        private _transform=[getPosWorld _area,vectorDir _area,vectorUp _area];
        private _context=[_area,_definition,_transform,_route,_controllerReceipt];
        if (_cooldown findIf {(_x select 0) isEqualTo _context} < 0) then {
            private _axis=vectorDir _area;_axis set [2,0];_axis=vectorNormalized _axis;
            private _centre=getPosASL _area;private _origin=getPosASL _vehicle;
            private _vehicleProjection=(_origin vectorDiff _centre) vectorDotProduct _axis;
            private _targetProjection=((ATLToASL _destination) vectorDiff _centre) vectorDotProduct _axis;
            private _halfLength=_definition select 1;
            if (_vehicleProjection*_targetProjection < 0 && {abs _vehicleProjection > _halfLength}
                && {abs _targetProjection > _halfLength} && {abs ((_origin select 2)-(_centre select 2)) < 6}) then {
                private _side=[-1,1] select (_vehicleProjection > 0);
                private _entry=_centre vectorAdd (_axis vectorMultiply ((_halfLength+10)*_side));
                private _exit=_centre vectorDiff (_axis vectorMultiply ((_halfLength+10)*_side));
                private _distance=_origin distance2D _entry;
                if (_distance < 400 && {_distance < _best}
                    && {_distance+(_entry distance2D _exit)+(_exit distance2D _destination)
                        < 1.5*(_origin distance2D _destination)+100}) then {
                    _best=_distance;_selected=[_area,_definition,_transform,_context,_side,_axis];
                };
            };
        };
    };
} forEach _records;
if (_selected isEqualTo []) exitWith {_inactive};
_selected params ["_area","_definition","_transform","_context","_side","_axis"];
// A narrow lead must not admit a wide/tall follower into a corridor it cannot fit.
// Reuse one worst-case solid-support proposal rather than multiplying raycasts per vehicle.
private _envelope=[];
if (_convoy) then {
    _envelope=[0,0,0];
    {
        if (!isNull _x && {alive _x}) then {
            private _bounds=boundingBoxReal _x;private _low=_bounds select 0;private _high=_bounds select 1;
            _envelope set [0,(_envelope select 0) max ((abs (_low select 0)) max (abs (_high select 0)))];
            _envelope set [1,(_envelope select 1) max ((abs (_low select 1)) max (abs (_high select 1)))];
            _envelope set [2,(_envelope select 2) max ((_high select 2)-(_low select 2))];
        };
    } forEach (_configuration param [4,[]]);
};
private _proposal=[_vehicle,_area,_definition,_side,_envelope] call WAIT_fnc_DrivingCorridorGeometry;
if (!(_proposal select 0)) exitWith {
    if (count _cooldown >= 32) then {_cooldown deleteAt 0};
    _cooldown pushBack [_context,serverTime+120];
    _vehicle setVariable ["WAIT_DrivingCorridor_Cooldown",_cooldown,true];
    _vehicle setVariable ["WAIT_DrivingCorridor_Result",[_proposal select 1,serverTime,_area,"ADMISSION"],true];_inactive
};
if (!(call _mayWrite) || {(expectedDestination _operator) isNotEqualTo _native}
    || {_vehicle distance2D ((_proposal select 2) select 0) > 400}
    || {(_proposal select 4) isNotEqualTo _transform}) exitWith {_inactive};
private _points=_proposal select 2;private _asl=_proposal select 3;
private _tailLength=0;
if (_convoy) then {
    private _column=_configuration param [4,[]];
    for "_i" from 1 to (count _column-1) do {
        _tailLength=_tailLength+((_configuration param [2,30]) max ((_column select _i) distance2D (_column select (_i-1))));
    };
};
// Do not drive beyond an authored destination and then turn back into the corridor.
// A column also needs room for its retained predecessor gaps beyond the far end.
private _exitPoint=(_proposal select 3) select ((count (_proposal select 3))-1);
private _exitRoom=((ATLToASL _destination) vectorDiff _exitPoint) vectorDotProduct (_axis vectorMultiply (-_side));
private _requiredRoom=_tailLength;
if (_convoy) then {_requiredRoom=_requiredRoom+(waypointCompletionRadius _waypoint max 20)+10};
if (_exitRoom < _requiredRoom) exitWith {
    if (count _cooldown >= 32) then {_cooldown deleteAt 0};
    _cooldown pushBack [_context,serverTime+120];
    _vehicle setVariable ["WAIT_DrivingCorridor_Cooldown",_cooldown,true];
    _vehicle setVariable ["WAIT_DrivingCorridor_Result",["DESTINATION_CLEARANCE",serverTime,_area,"ADMISSION"],true];
    _inactive
};
private _tailSpeed=((_definition select 3) min (_configuration param [1,_definition select 3]))/3.6;
private _tailDeadline=serverTime+((120+(_definition select 1)+45+60+_tailLength/(_tailSpeed max 1.39)) min 1800);
if (!(call _mayWrite) || {!(call _nativeAdmissionReady)}) exitWith {_inactive};
_operator doMove (_points select 0);
_work=createHashMapFromArray [["group",_group],["controller",_controllerReceipt],["driver",_driver],["operator",_operator],
    ["route",_route],["area",_area],["definition",_definition],["transform",_transform],
    ["context",_context],["epoch",_group getVariable ["WAIT_AIPass_Epoch",0]],
    ["points",_points],["asl",_asl],["travel",_axis vectorMultiply (-_side)],
    ["far",(getPosASL _area) vectorDiff (_axis vectorMultiply ((_definition select 1)*_side))],
    ["tailDeadline",_tailDeadline],["phase","APPROACH"],["deadline",serverTime+120],["hardDeadline",serverTime+120+(_definition select 1)+45],
    ["command",+(expectedDestination _operator)]];
_vehicle setVariable ["WAIT_DrivingCorridor_Work",_work,true];
[true,(_definition select 3)/3.6,"CORRIDOR_APPROACH"]

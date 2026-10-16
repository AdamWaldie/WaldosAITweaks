/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires a matching ordinary recovery journal; only its exact owned reverse can stop
 * and hand back to the unchanged plain authored MOVE. Forward retries retire metadata only.
 * Locality / Authority: Current vehicle/group owner. Original seats, both native destinations,
 * route, external/tactical ownership and crew tasks protect cleanup. No waypoint reconstruction.
 * Active fire, attack, service and other non-route commands forbid movement cleanup.
 * A native STOP overrides an unchanged destination receipt and forbids movement cleanup.
 * Repeat/JIP: Public stage clocks and cap baseline survive migration without command replay.
 * Cleanup compares the current journal before clearing; newer work and commands remain untouched.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 expected group <GROUP, grpNull>;
 * 2 reason <STRING, RELEASED>; 3 resume <BOOL, true> permits exact reverse handback.
 * Return Value: BOOL - matching journal retired, never physical recovery success.
 * Current callers: DrivingAssistStart and DrivingAssistRelease.
 * Example: [truck1,group driver truck1,"DRIVING_RELEASED"] call WAIT_fnc_DrivingRecoveryRelease;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_reason","RELEASED",[""]],["_resume",true,[true]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _vehicle} || {!local _vehicle}) exitWith {false};
private _work=_vehicle getVariable ["WAIT_DrivingRecovery_Work",createHashMap];
if (count _work == 0 || {(_work get "group") != _group}) exitWith {false};
private _driver=_work get "driver";private _operator=_work get "operator";
private _owned=_resume && {(_work get "kind") == "REVERSE"}
    && {local _group} && {!isNull _driver} && {!isNull _operator}
    && {driver _vehicle == _driver} && {effectiveCommander _vehicle == _operator}
    && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
    && {(expectedDestination _operator) isEqualTo (_work get "command")}
    && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)} && {!([_group] call WAIT_fnc_CortexZeusHeld)}
    && {[_group] call WAIT_fnc_DrivingMovementAvailable}
    && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
    && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}};
{
    _owned=_owned && {!isNull _x} && {local _x} && {group _x == _group} && {vehicle _x == _vehicle}
        && {[_x] call WAIT_fnc_CortexCombatEffective} && {!isPlayer _x} && {isNull remoteControlled _x}
        && {isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {[_x] call WAIT_fnc_CortexExternalOwner == ""} && {simulationEnabled _x} && {!isObjectHidden _x}
        && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
        && {currentCommand _x != "STOP"}
        && {toUpperANSI currentCommand _x in ["","MOVE","WAIT"]}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
            "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])};
} forEach [_driver,_operator];
if (_owned) then {
    doStop _driver;if (_operator != _driver) then {doStop _operator};
    private _index=currentWaypoint _group;private _waypoint=[_group,_index];private _statements=waypointStatements _waypoint;
    private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
    if (_index > 0 && {_index < count waypoints _group} && {waypointType _waypoint == "MOVE"} && {_condition == "true"}
        && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
        && {waypointScript _waypoint == ""} && {(waypointTimeout _waypoint param [2,0]) <= 0}
        && {isNull waypointAttachedVehicle _waypoint} && {isNull waypointAttachedObject _waypoint}
        && {(synchronizedWaypoints _waypoint) isEqualTo []} && {(synchronizedTriggers _waypoint) isEqualTo []}) then {
        if (_driver != _operator) then {_driver doFollow _operator};
        if (vehicle leader _group == _vehicle) then {_operator doMove waypointPosition _waypoint} else {
            if (vehicle leader _group isKindOf "LandVehicle") then {_operator doFollow leader _group};
        };
    };
};
if ((_vehicle getVariable ["WAIT_DrivingRecovery_Work",createHashMap]) isEqualTo _work) then {
    _vehicle setVariable ["WAIT_DrivingRecovery_Result",[_reason,serverTime,_group,_work get "kind",_work get "hardDeadline"],true];
    _vehicle setVariable ["WAIT_DrivingRecovery_Work",nil,true];
};
true

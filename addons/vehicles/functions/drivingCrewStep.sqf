/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes one finite native internal-seat replacement for an ordinary leader vehicle.
 * A dead driver receives one native Eject action; only a confirmed vacant seat permits MoveToDriver.
 * Living incapacitated drivers are never displaced. Cargo crew are preferred to weapon operators.
 * Locality / Authority: Internal current group/crew owner only, exact driving brain and
 * unit-local native actions. Vehicle may still belong to another owner; no vehicle command is issued.
 * An authored plain MOVE is required. Player, Zeus, specialist, convoy, service and newer orders win.
 * Repeat/JIP: Public original deadline and issued phases survive transfer without replaying actions.
 * Terminal receipts suppress repeated attempts for the same driver and route. No forced seating,
 * physics movement, repair, AI-feature reset, waypoint rewrite or second scheduler is used.
 * Arguments: 0 group <GROUP, grpNull>; 1 current driving brain <HASHMAP, empty>;
 * 2 release <BOOL, false> retires a matching journal without further native action.
 * Return Value: BOOL - an admitted native seat action is pending, not restored mobility.
 * Current callers: DrivingOperationStep and DrivingOperationFinish.
 * Example: [group commander truck1,_brain] call WAIT_fnc_DrivingCrewStep;
 */
params [["_group",grpNull,[grpNull]],["_brain",createHashMap,[createHashMap]],["_release",false,[true]]];
if (remoteExecutedOwner > 0 || {isNull _group} || {!local _group}
    || {(_group getVariable ["WAIT_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {false};
private _previousVehicle=_brain getOrDefault ["crewVehicle",objNull];
if (!_release && {!isNull _previousVehicle} && {_previousVehicle != vehicle leader _group}) then {
    [_group,_brain,true] call WAIT_fnc_DrivingCrewStep;
};
private _vehicle=if (_release) then {_brain getOrDefault ["crewVehicle",objNull]} else {vehicle leader _group};
if (isNull _vehicle || {_vehicle == leader _group} || {!(_vehicle isKindOf "LandVehicle")} || {_vehicle isKindOf "StaticWeapon"}) exitWith {false};
private _work=_vehicle getVariable ["WAIT_DrivingCrew_Work",createHashMap];
private _driver=driver _vehicle;
// Normal healthy drivers incur no route snapshot or crew enumeration here.
if (!_release && {count _work == 0} && {!isNull _driver} && {alive _driver}) exitWith {false};
private _route=if (_release) then {[]} else {[_group] call WAIT_fnc_DrivingRouteReceipt};
if (_release) exitWith {
    if (count _work > 0 && {(_work get "group") == _group}
        && {(_work get "route") isEqualTo (_brain getOrDefault ["route",[]])}
        && {(_group getVariable ["WAIT_Driving_Brain",createHashMap]) isEqualTo _brain}
        && {!((_work get "phase") in ["COMPLETE","CANCELLED","EXPIRED"])}) then {
        _work set ["phase","CANCELLED"];_work set ["ended",serverTime];
        _vehicle setVariable ["WAIT_DrivingCrew_Work",_work,true];
    };
    false
};
private _changed=false;
if (count _work > 0 && {(_work get "group") != _group || {(_work get "route") isNotEqualTo _route}}) then {
    _work=createHashMap;_changed=true;
};
private _terminal=count _work > 0 && {(_work get "phase") in ["COMPLETE","CANCELLED","EXPIRED"]};
// A later casualty is a distinct episode; a failed vacancy cannot restart every callback.
if (_terminal && {!isNull _driver} && {_driver != (_work get "driver")} && {!alive _driver}) then {
    _work=createHashMap;_terminal=false;_changed=true;
};
private _publish={if (_changed) then {_vehicle setVariable ["WAIT_DrivingCrew_Work",_work,true]}};
if (_terminal || {count _work == 0 && {!isNull _driver} && {alive _driver}}) exitWith {call _publish;false};
private _candidate=if (count _work > 0) then {_work get "candidate"} else {objNull};
private _phase=if (count _work > 0) then {_work get "phase"} else {""};
private _crew=fullCrew [_vehicle,"",false];
private _tasks=["GET IN","GET OUT","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
    "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"];
private _available={
    _crew=fullCrew [_vehicle,"",false];
    // Physical vacancy alone does not release a mission-assigned incoming driver.
    private _driverSeat=(fullCrew [_vehicle,"driver",true]) param [0,[]];
    private _assignedDriver=_driverSeat param [5,objNull];
    local _group && {alive _vehicle} && {canMove _vehicle} && {abs speed _vehicle < 1}
        && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle} && {!lockedDriver _vehicle}
        && {vehicle leader _group == _vehicle}
        && {(_group getVariable ["WAIT_Driving_Brain",createHashMap]) isEqualTo _brain}
        && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {!(_brain getOrDefault ["cancelled",false])} && {missionNamespace getVariable ["WAIT_AIPass_Active",false]}
        && {[_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
        && {[_group,"WAIT_AIPass_DrivingAssist_Recovery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
        && {[_group] call WAIT_fnc_DrivingMovementAvailable}
        && {!([_group] call WAIT_fnc_CortexZeusHeld)} && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
        && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
        && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
        && {count _crew <= 20} && {count _driverSeat >= 6}
        && {isNull _assignedDriver || {!alive _assignedDriver} || {_assignedDriver == _candidate}}
        && {_route isNotEqualTo []}
        && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {_crew findIf {
            private _actor=_x select 0;
            isPlayer _actor || {!isNull remoteControlled _actor}
                || {!isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                || {[_actor] call WAIT_fnc_CortexExternalOwner != ""}
                || {alive _actor && {group _actor != _group || {!local _actor}
                    || {currentCommand _actor in _tasks}
                    || {currentCommand _actor == "ACTION" && {!(_actor == _candidate && {_phase == "SWITCHING"})}}}}
        } < 0}
};
private _finish={
    params ["_result"];
    if (count _work > 0) then {_work set ["phase",_result];_work set ["ended",serverTime];_changed=true};
    call _publish;false
};
if !(call _available) exitWith {["CANCELLED"] call _finish};
private _index=currentWaypoint _group;private _wp=[_group,_index];private _statements=waypointStatements _wp;
private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
if (_index <= 0 || {_index >= count waypoints _group} || {waypointType _wp != "MOVE"} || {_condition != "true"}
    || {((_statements param [1,""]) splitString (toString [32,9,13,10])) isNotEqualTo []}
    || {waypointScript _wp != ""} || {(waypointTimeout _wp param [2,0]) > 0}
    || {!isNull waypointAttachedVehicle _wp} || {!isNull waypointAttachedObject _wp}
    || {(synchronizedWaypoints _wp) isNotEqualTo []} || {(synchronizedTriggers _wp) isNotEqualTo []}) exitWith {["CANCELLED"] call _finish};
if (count _work == 0) then {
    if (!isNull _driver && {alive _driver}) exitWith {};
    private _choices=_crew select {
        private _actor=_x select 0;
        alive _actor && {local _actor} && {group _actor == _group} && {!isPlayer _actor}
            && {[_actor] call WAIT_fnc_CortexCombatEffective}
            && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
            && {assignedVehicle _actor in [objNull,_vehicle]}
    };
    private _cargo=_choices select {toLowerANSI (_x select 1) == "cargo"};
    if (_cargo isNotEqualTo []) then {_choices=_cargo};
    if (_choices isNotEqualTo []) then {
        _candidate=(_choices select 0) select 0;
        _work=createHashMapFromArray [["group",_group],["route",_route],["driver",_driver],["candidate",_candidate],
            ["command",+(expectedDestination _candidate)],["assignment",assignedVehicleRole _candidate],
            ["leader",leader _group],["leaderCommand",+(expectedDestination leader _group)],
            ["deadline",serverTime+25],["phase","READY"],["started",serverTime]];
        _phase="READY";_changed=true;_brain set ["crewVehicle",_vehicle];
    };
};
if (count _work == 0) exitWith {call _publish;false};
_brain set ["crewVehicle",_vehicle];
if (driver _vehicle == _candidate && {[_candidate] call WAIT_fnc_CortexCombatEffective}) exitWith {["COMPLETE"] call _finish};
if (serverTime >= (_work get "deadline")) exitWith {["EXPIRED"] call _finish};
if (isNull _candidate || {!local _candidate} || {vehicle _candidate != _vehicle}
    || {!([_candidate] call WAIT_fnc_CortexCombatEffective)}
    || {!simulationEnabled _candidate} || {isObjectHidden _candidate}
    || {!(_candidate checkAIFeature "MOVE")} || {!(_candidate checkAIFeature "PATH")}
    || {leader _group != (_work get "leader")}
    || {(expectedDestination leader _group) isNotEqualTo (_work get "leaderCommand")} || {!(assignedVehicle _candidate in [objNull,_vehicle])}
    || {(expectedDestination _candidate) isNotEqualTo (_work get "command")}
    || {assignedVehicleRole _candidate isNotEqualTo (_work get "assignment")}) exitWith {["CANCELLED"] call _finish};
if (!isNull _driver && {_driver != (_work get "driver") || {alive _driver}}) exitWith {["CANCELLED"] call _finish};
// Seat vacancy and native order proof are checked atomically with each action.
private _commandsOwned={
    vehicle _candidate == _vehicle && {[_candidate] call WAIT_fnc_CortexCombatEffective}
        && {simulationEnabled _candidate} && {!isObjectHidden _candidate}
        && {_candidate checkAIFeature "MOVE"} && {_candidate checkAIFeature "PATH"}
        && {leader _group == (_work get "leader")}
        && {(expectedDestination leader _group) isEqualTo (_work get "leaderCommand")}
        && {(expectedDestination _candidate) isEqualTo (_work get "command")}
        && {assignedVehicle _candidate in [objNull,_vehicle]}
        && {assignedVehicleRole _candidate isEqualTo (_work get "assignment")}
};
if (_phase == "READY" && {!isNull _driver}) then {
    isNil {
        if (call _available && {call _commandsOwned} && {driver _vehicle == _driver} && {!alive _driver}
            && {local _driver} && {!isPlayer _driver} && {simulationEnabled _driver} && {!isObjectHidden _driver}) then {
            _driver action ["Eject",_vehicle];
            _work set ["phase","VACATING"];_changed=true;_phase="VACATING_ISSUED";
        };
    };
};
if (_phase in ["READY","VACATING"]) then {
    isNil {
        if (call _available && {call _commandsOwned} && {isNull driver _vehicle}) then {
            _candidate action ["MoveToDriver",_vehicle];
            _work set ["command",+(expectedDestination _candidate)];
            _work set ["leaderCommand",+(expectedDestination leader _group)];
            _work set ["assignment",assignedVehicleRole _candidate];
            _work set ["phase","SWITCHING"];_changed=true;
        };
    };
};
call _publish;
true

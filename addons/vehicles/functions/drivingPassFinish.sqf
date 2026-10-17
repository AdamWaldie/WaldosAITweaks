/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires exact pass work and optionally hands its unchanged command to the native route.
 * Locality/authority: Vehicle/group owner. Current epoch, brain generation, both seats and
 * destinations, live simulation, external controller/Zeus state and the unchanged authored route
 * protect every stop/handback; detectable newer orders/controllers survive.
 * Observed STOP events veto command cleanup. Whether a repeated identical STOP emits that
 * group event remains an engine-level interruption test requirement. A newer authored route
 * retires metadata/consent only: cleanup never inserts a formation-follow fallback.
 * Repeat/JIP: Exact local journal and matching public leg receipt retire once, token-specific
 * broker release. Successor owners use DrivingPassRetireInherited, never replay this work. No ownership
 * transfer, physics shortcut or JIP command. A blocked abort records failure and may keep STOP.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 group <GROUP>, grpNull;
 * 2 reason <STRING>, RELEASED; 3 resume native route <BOOL>, false.
 * Return: BOOL - matching work retired, not full behaviour acceptance.
 * Current callers: DrivingPassStep and DrivingAssistRelease.
 * Example: [truck1,group driver truck1,"RELEASED",true] call WAIT_fnc_DrivingPassFinish;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],["_reason","RELEASED",[""]],["_resume",false,[true]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _vehicle} || {!local _vehicle}) exitWith {false};
private _work=_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap];
if (count _work == 0 || {(_work get "group") != _group}) exitWith {false};
private _stop=_vehicle getVariable ["WAIT_DrivingPass_Interrupted",[]];
private _driver=_work get "driver";private _operator=_work get "operator";
private _brain=_group getVariable ["WAIT_Driving_Brain",createHashMap];
private _actorFree={params ["_actor"];local _actor && {!isPlayer _actor} && {isNull remoteControlled _actor}
    && {vehicle _actor == _vehicle} && {simulationEnabled _actor} && {!isObjectHidden _actor}
    && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
    && {[_actor] call WAIT_fnc_CortexExternalOwner == ""}
    && {[_actor] call WAIT_fnc_CortexCombatEffective} && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
    && {!([_actor] call WAIT_fnc_CortexActorMoveReserved)}
    && {currentCommand _actor in ["","MOVE","WAIT","STOP"]}};
private _owned={
    _stop=_vehicle getVariable ["WAIT_DrivingPass_Interrupted",[]];
    private _interrupted=_stop isEqualType [] && {count _stop == 5}
        && {(_stop select [0,3]) isEqualTo [_work get "token",_work get "epoch",_work get "generation"]};
    !(_work getOrDefault ["interrupted",false]) && {!_interrupted} && {local _vehicle} && {local _group} && {(_work get "epoch") == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {(_work get "generation") == (_brain getOrDefault ["generation",-1])}
    && {driver _vehicle == _driver} && {(effectiveCommander _vehicle) in [_operator,objNull]}
    && {[_driver] call _actorFree} && {[_operator] call _actorFree}
    && {group _driver == _group} && {group _operator == _group}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)} && {!([_group] call WAIT_fnc_CortexZeusHeld)}
    && {[_group] call WAIT_fnc_DrivingMovementAvailable}
    && {alive _vehicle} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
    && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
    && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
    && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
    && {(expectedDestination _operator) isEqualTo (_work get "command")}
    && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")}
};
isNil {
[_group,_vehicle,_work,true] call WAIT_fnc_DrivingPassCommandWatch;
if (call _owned && {_work get "issued"}) then {
    doStop _driver;if (_operator != _driver) then {doStop _operator};
    if (_resume && {local _vehicle} && {local _group} && {driver _vehicle == _driver}
        && {(_work get "epoch") == (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {!([_group] call WAIT_fnc_CortexExternalTakeover)}) then {
        if (_driver != _operator) then {_driver doFollow _operator};
        if (([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")) then {
            _operator doMove waypointPosition [_group,currentWaypoint _group];
        };
    };
};
    false
};
if ((_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap]) isEqualTo _work) then {
    _vehicle setVariable ["WAIT_DrivingPass_Result",[_reason,serverTime,_work get "phase",_work get "peer",getPosASL _vehicle],true];
    _vehicle setVariable ["WAIT_DrivingPass_Work",nil];
    private _leg=_vehicle getVariable ["WAIT_DrivingPass_Leg",[]];
    if (_leg isEqualType [] && {count _leg == 13} && {(_leg select 0) == "PASS_LEG_V1"}
        && {(_leg select 1) == clientOwner} && {(_leg select 2) == _group}
        && {(_leg select 3) == (_work get "epoch")} && {(_leg select 4) == (_work get "generation")}
        && {(_leg select 5) == (_work get "token")}) then {
        _vehicle setVariable ["WAIT_DrivingPass_Leg",nil,true];
    };
};
_stop=_vehicle getVariable ["WAIT_DrivingPass_Interrupted",[]];
if (_stop isEqualType [] && {count _stop == 5}
    && {(_stop select [0,3]) isEqualTo [_work get "token",_work get "epoch",_work get "generation"]}
    && {(_vehicle getVariable ["WAIT_DrivingPass_Interrupted",[]]) isEqualTo _stop}) then {
    _vehicle setVariable ["WAIT_DrivingPass_Interrupted",nil,true];
};
[_vehicle,_group,_work get "token"] call WAIT_fnc_DrivingPassAgreementRelease;
true
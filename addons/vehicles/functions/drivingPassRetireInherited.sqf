/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires a previous owner's exact issued pass leg; never resumes its pass work.
 * Locality/authority: Current vehicle and crew/group owner only. Matching native destinations,
 * authored route, seats and free actor/controller authority guard native route handback.
 * Repeat/JIP: One public command receipt, no executable work or timer replay. Split locality
 * waits for the existing discovery sweep. Expiry never authorizes renewed passing. An identical
 * native STOP without an observed group event remains ambiguous and needs physical QA.
 * A matching published STOP observation forbids native handback after transfer.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 expected group <GROUP>, grpNull permits any.
 * Return: BOOL - stale receipt retired, not proof of handback movement or passage.
 * Current callers: CortexLocality, CortexDiscover, DrivingAssistStart/Release.
 * Example: [truck1] call WAIT_fnc_DrivingPassRetireInherited;
 */
params [["_vehicle",objNull,[objNull]],["_expectedGroup",grpNull,[grpNull]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _vehicle} || {!local _vehicle}) exitWith {false};
private _receipt=_vehicle getVariable ["WAIT_DrivingPass_Leg",[]];
if (!(_receipt isEqualType []) || {count _receipt != 13}
    || {(_receipt select 0) isNotEqualTo "PASS_LEG_V1"}
    || {[1,3,4,11] findIf {!((_receipt select _x) isEqualType 0) || {!finite (_receipt select _x)}} >= 0}
    || {!((_receipt select 2) isEqualType grpNull)} || {!((_receipt select 5) isEqualType "")}
    || {(_receipt select 5) == ""}
    || {[6,7,12] findIf {!((_receipt select _x) isEqualType objNull)} >= 0}
    || {[8,9,10] findIf {!((_receipt select _x) isEqualType [])} >= 0}) exitWith {false};
_receipt params ["","_oldOwner","_group","_epoch","_generation","_token","_driver","_operator",
    "_driverCommand","_command","_route","","_peer"];
if (!isNull _expectedGroup && {_group != _expectedGroup}) exitWith {false};
// Wait only while the recorded crew still occupies these seats. Changed seats/deleted groups
// invalidate cleanup authority; remote former occupants must not retain a permanent pass veto.
private _sameSeats=driver _vehicle == _driver && {(effectiveCommander _vehicle) in [_operator,objNull]};
if (_sameSeats && {!isNull _group} && {(!local _group)
    || {!isNull _driver && {!local _driver}} || {!isNull _operator && {!local _operator}}}) exitWith {false};
private _work=_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap];
private _brain=createHashMap;
if (!isNull _group) then {_brain=_group getVariable ["WAIT_Driving_Brain",createHashMap]};
private _live=_sameSeats && {!isNull _group} && {_oldOwner == clientOwner} && {_epoch == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {(_brain getOrDefault ["generation",-1]) == _generation}
    && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])}
    && {(_work getOrDefault ["token",""]) == _token}
    && {(_work getOrDefault ["generation",-1]) == _generation};
if (_live) exitWith {false};
private _stop=_vehicle getVariable ["WAIT_DrivingPass_Interrupted",[]];
private _interrupted=_stop isEqualType [] && {count _stop == 5}
    && {(_stop select [0,3]) isEqualTo [_token,_epoch,_generation]};
private _successor=count _work > 0 && {(_work getOrDefault ["token",""]) != _token};
private _mayRetire={
    private _event=_vehicle getVariable ["WAIT_DrivingPass_Interrupted",[]];
    private _observedStop=_event isEqualType [] && {count _event == 5}
        && {(_event select [0,3]) isEqualTo [_token,_epoch,_generation]};
    !_observedStop && {!(_work getOrDefault ["interrupted",false])} && {!_successor} && {(_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap]) isEqualTo _work}
    && {["WAIT_DrivingRecovery_Work","WAIT_DrivingBypass_Work","WAIT_DrivingCorridor_Work"] findIf {
        count (_vehicle getVariable [_x,createHashMap]) > 0
    } < 0} && {
    local _vehicle && {!isNull _group} && {local _group} && {alive _vehicle} && {simulationEnabled _vehicle}
        && {!isObjectHidden _vehicle} && {!isNull _driver} && {!isNull _operator}
        && {driver _vehicle == _driver}
        && {(effectiveCommander _vehicle) in [_operator,objNull]}
        && {vehicle leader _group == _vehicle}
        && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
        && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
        && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
        && {!([_group] call WAIT_fnc_CortexZeusHeld)}
        && {[_group] call WAIT_fnc_DrivingMovementAvailable}
        && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {(expectedDestination _driver) isEqualTo _driverCommand}
        && {(expectedDestination _operator) isEqualTo _command}
        && {[_driver,_operator] findIf {isNull _x || {!local _x} || {group _x != _group}
            || {vehicle _x != _vehicle} || {!simulationEnabled _x} || {isObjectHidden _x} || {isPlayer _x} || {!isNull remoteControlled _x}
            || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {!([_x] call WAIT_fnc_CortexCombatEffective)}
            || {[_x] call WAIT_fnc_CortexActorMoveReserved}
            || {[_x] call WAIT_fnc_CortexExternalOwner != ""}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {!(currentCommand _x in ["","MOVE","WAIT","STOP"])}} < 0}
        && {(_vehicle getVariable ["WAIT_DrivingPass_Leg",[]]) isEqualTo _receipt}
    }
};
private _handedBack=false;
isNil {
    if (call _mayRetire) then {
        doStop _driver;if (_operator != _driver) then {doStop _operator};
        // Resume only the unchanged authored waypoint, never the old OUT/RETURN guide.
        private _index=currentWaypoint _group;
        if (_index > 0 && {_index < count waypoints _group}
            && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo _route}) then {
            if (_driver != _operator) then {_driver doFollow _operator};
            _operator doMove waypointPosition [_group,_index];
            _handedBack=true;
        };
    };
    if ((_vehicle getVariable ["WAIT_DrivingPass_Leg",[]]) isEqualTo _receipt) then {
        _vehicle setVariable ["WAIT_DrivingPass_Leg",nil,true];
        _vehicle setVariable ["WAIT_DrivingPass_Result",[
            ["INHERITED_DISCARDED","INHERITED_NATIVE_HANDBACK"] select _handedBack,
            serverTime,"RETIRED",_peer,getPosASL _vehicle],true];
    };
    // A returning owner may retain private work from its previous ownership episode.
    if ((_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap]) isEqualTo _work
        && {(_work getOrDefault ["token",""]) == _token}
        && {(_work getOrDefault ["epoch",-1]) == _epoch}
        && {(_work getOrDefault ["generation",-1]) == _generation}) then {
        _vehicle setVariable ["WAIT_DrivingPass_Work",nil];
    };
    false
};
[_group,_vehicle,createHashMapFromArray [["token",_token],["epoch",_epoch],["generation",_generation]],true]
    call WAIT_fnc_DrivingPassCommandWatch;
if (_interrupted && {(_vehicle getVariable ["WAIT_DrivingPass_Interrupted",[]]) isEqualTo _stop}) then {
    _vehicle setVariable ["WAIT_DrivingPass_Interrupted",nil,true];
};
[_vehicle,_group,_token] call WAIT_fnc_DrivingPassAgreementRelease;
true

/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires an controller-owned bypass and only its exact owned fixed path/native handback.
 * Locality / Authority: Current vehicle/group owner. Both seats, route, command receipts and
 * external/tactical ownership protect cleanup; a newer command is never recalled.
 * Repeat/JIP: Public episode retires once; bounded 32-entry object/route cooldown lasts 120 s.
 * PLAN owns no movement and cannot stop native actors. Local handles/code are never published.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 expected group <GROUP, grpNull>;
 * 2 reason <STRING, RELEASED>; 3 resume <BOOL, true> permits exact unchanged authored-route handback.
 * 4 stopOnly <BOOL, false> stops exact-owned work without route recall;
 * 5 expected revision <NUMBER, -1> optionally limits convoy cleanup to its original revision.
 * Return Value: BOOL - matching episode retired, never proof of actual passage.
 * Current callers: DrivingBypassStep, DrivingAssistRelease, ConvoyTick, ConvoyCrewLocal and ConvoyReleaseLocal.
 * Example: [truck1,group driver truck1,"OBSTACLE_CHANGED"] call WAIT_fnc_DrivingBypassRelease;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_reason","RELEASED",[""]],["_resume",true,[true]],["_stopOnly",false,[true]],["_expectedRevision",-1,[0]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _vehicle} || {!local _vehicle}
    || {isNull _group} || {!local _group}) exitWith {false};
private _work=_vehicle getVariable ["WAIT_DrivingBypass_Work",createHashMap];
if (count _work == 0 || {(_work get "group") != _group}) exitWith {false};
private _controller=_work getOrDefault ["controller",["ORDINARY",-1]];
private _convoy=(_controller param [0,""]) == "CONVOY";
if (_expectedRevision >= 0 && {(!_convoy) || {(_controller param [1,-2]) != _expectedRevision}}) exitWith {false};
private _current=_group getVariable ["WAIT_Convoy_Brain",createHashMap];
private _currentConfiguration=_current getOrDefault ["configuration",[]];
private _successor=_convoy && {_currentConfiguration isNotEqualTo []}
    && {(_currentConfiguration param [0,-1]) != (_controller param [1,-2])}
    && {!(_current getOrDefault ["cancelled",false])};
private _haltCleanup=_reason == "CONVOY_HALT" && {_expectedRevision == (_controller param [1,-2])}
    && {(_currentConfiguration param [5,""]) == "HALT"}
    && {(missionNamespace getVariable ["WAIT_Convoy_LocalRegistry",[]]) findIf {
        (_x select 0) == _group && {(_x select 1) isEqualTo _currentConfiguration}
    } >= 0};
if (_successor && {!_haltCleanup} && {!(_reason in ["CONTROLLER_CHANGED","CONVOY_LEAD_CHANGED"])}) exitWith {false};
private _driver=_work get "driver";private _operator=_work get "operator";private _route=_work get "route";
private _owned=(_work get "phase") == "FOLLOW" && {_resume || {_stopOnly}}
    && {!isNull _driver} && {!isNull _operator} && {local _driver} && {local _operator}
    && {driver _vehicle == _driver} && {effectiveCommander _vehicle == _operator}
    && {group _driver == _group} && {group _operator == _group}
    && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo _route}
    && {(expectedDestination _operator) isEqualTo (_work get "command")}
    && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)} && {!([_group] call WAIT_fnc_CortexZeusHeld)}
    && {_convoy || {[_group] call WAIT_fnc_DrivingMovementAvailable}}
    && {_convoy || {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}}
    && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}};
{
    _owned=_owned && {!isNull _x} && {local _x} && {vehicle _x == _vehicle}
        && {[_x] call WAIT_fnc_CortexCombatEffective} && {!isPlayer _x} && {isNull remoteControlled _x}
        && {isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {simulationEnabled _x} && {!isObjectHidden _x}
        && {[_x] call WAIT_fnc_CortexExternalOwner == ""}
        && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
            "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])};
} forEach [_driver,_operator];
if (_owned) then {
    doStop _driver;if (_operator != _driver) then {doStop _operator};
    private _index=currentWaypoint _group;
    if (_resume && {_index > 0} && {_index < count waypoints _group}
        && {_convoy || {vehicle leader _group == _vehicle}}
        && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {!([_group] call WAIT_fnc_CortexExternalTakeover)}) then {
        if (_driver != _operator) then {_driver doFollow _operator};
        _operator doMove waypointPosition [_group,_index];
    };
};
private _context=_work get "context";
private _cooldown=(_vehicle getVariable ["WAIT_DrivingBypass_Cooldown",[]]) select {
    (_x select 1) > serverTime && {(_x select 0) isNotEqualTo _context}
};
if (count _cooldown >= 32) then {_cooldown deleteAt 0};
_cooldown pushBack [_context,serverTime+120];
_vehicle setVariable ["WAIT_DrivingBypass_Cooldown",_cooldown,true];
_vehicle setVariable ["WAIT_DrivingBypass_Result",[_reason,serverTime,_work get "obstacle",_work get "index"],true];
_vehicle setVariable ["WAIT_DrivingBypass_Work",nil,true];
true

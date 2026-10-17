/*
 * Author: WaldoTheWarfighter
 * Purpose: Checks ordinary driving command intent before a gate-opening request or mutation.
 * Locality / Authority: Read-only current owner or trusted server recheck. Callers authenticate
 * sender, route, seats, capability and locks separately; this helper grants no movement authority.
 * Repeat/JIP: Fresh native commands and public finite journals only; no cache, writes or replay.
 * Plain route matching compares full PositionAGL destinations, including height.
 * An unchanged owned bypass FOLLOW/corridor CROSS may retain its acquired STOP. A later
 * indistinguishable STOP cannot be separated from that receipt and remains a known limitation.
 * Arguments: 0 group <GROUP, grpNull>; 1 vehicle <OBJECT, objNull>; 2 route <ARRAY, []>.
 * Return Value: BOOL - current ordinary route/owned alternate command intent, not gate clearance.
 * Current callers: DrivingGateRequest, DrivingGateOpenServer and DrivingPassCanConsent, ordinary mode only.
 * Example: private _allowed=[group driver truck1,truck1,_route] call WAIT_fnc_DrivingGateIntent;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],["_route",[],[[]]]];
if (isNull _group || {isNull _vehicle} || {_route isEqualTo []}
    || {([_group] call WAIT_fnc_DrivingRouteReceipt) isNotEqualTo _route}) exitWith {false};
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
if (isNull _operator) then {_operator=_driver};
if (isNull _driver || {isNull _operator}) exitWith {false};
private _index=currentWaypoint _group;private _waypoint=[_group,_index];
private _destination=waypointPosition _waypoint;
private _statements=waypointStatements _waypoint;
private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
if (waypointType _waypoint != "MOVE" || {_condition != "true"}
    || {((_statements param [1,""]) splitString (toString [32,9,13,10])) isNotEqualTo []}
    || {waypointScript _waypoint != ""} || {(waypointTimeout _waypoint param [2,0]) > 0}
    || {!isNull waypointAttachedVehicle _waypoint} || {!isNull waypointAttachedObject _waypoint}
    || {(synchronizedWaypoints _waypoint) isNotEqualTo []}
    || {(synchronizedTriggers _waypoint) isNotEqualTo []}) exitWith {false};
private _alternate=false;
{
    _x params ["_variable","_phase"];
    private _work=_vehicle getVariable [_variable,createHashMap];
    if ((_work getOrDefault ["group",grpNull]) == _group
        && {(_work getOrDefault ["controller",[]]) isEqualTo ["ORDINARY",-1]}
        && {(_work getOrDefault ["phase",""]) == _phase}
        && {serverTime < (_work getOrDefault ["deadline",-1])}
        && {(_work getOrDefault ["route",[]]) isEqualTo _route}
        && {(_work getOrDefault ["driver",objNull]) == _driver}
        && {(_work getOrDefault ["operator",objNull]) == _operator}
        && {(expectedDestination _driver) isEqualTo (_work getOrDefault ["driverCommand",[]])}
        && {(expectedDestination _operator) isEqualTo (_work getOrDefault ["command",[]])}
        && {_variable != "WAIT_DrivingBypass_Work" || {
            (toUpperANSI currentCommand _driver) == (_work getOrDefault ["driverTask","__MISSING__"])
                && {(toUpperANSI currentCommand _operator) == (_work getOrDefault ["operatorTask","__MISSING__"])}
        }}
        && {[_driver,_operator] findIf {!(toUpperANSI currentCommand _x in ["","STOP","MOVE","WAIT"])} < 0}) exitWith {
        _alternate=true;
    };
} forEach [["WAIT_DrivingBypass_Work","FOLLOW"],["WAIT_DrivingCorridor_Work","CROSS"]];
// Corridor approach owns the operator's alternate MOVE but has not acquired STOP.
// Its separate driver must still retain idle/plain-route intent.
private _approach=_vehicle getVariable ["WAIT_DrivingCorridor_Work",createHashMap];
if (!_alternate && {(_approach getOrDefault ["group",grpNull]) == _group}
    && {(_approach getOrDefault ["controller",[]]) isEqualTo ["ORDINARY",-1]}
    && {(_approach getOrDefault ["phase",""]) == "APPROACH"}
    && {serverTime < (_approach getOrDefault ["deadline",-1])}
    && {(_approach getOrDefault ["route",[]]) isEqualTo _route}
    && {(_approach getOrDefault ["driver",objNull]) == _driver}
    && {(_approach getOrDefault ["operator",objNull]) == _operator}
    && {(expectedDestination _operator) isEqualTo (_approach getOrDefault ["command",[]])}
    && {toUpperANSI currentCommand _operator in ["","MOVE","WAIT"]}) then {
    private _driverTask=toUpperANSI currentCommand _driver;
    private _driverTarget=(expectedDestination _driver) param [0,[],[[]]];
    _alternate=_driver == _operator || {_driverTask == ""}
        || {_driverTask == "MOVE" && {count _driverTarget == 3} && {_driverTarget vectorDistance _destination <= 3}};
};
if (_alternate) exitWith {true};
[_driver,_operator] findIf {
    private _command=toUpperANSI currentCommand _x;
    _command != "" && {_command != "MOVE" || {
        private _target=(expectedDestination _x) param [0,[],[[]]];
        count _target != 3 || {_target vectorDistance _destination > 3}
    }}
} < 0

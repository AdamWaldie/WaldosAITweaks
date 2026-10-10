/*
 * Author: WaldoTheWarfighter
 * Purpose: Commits one WAIT-owned temporary waypoint without replacing it again while the
 * requested destination, radius and mode remain materially the same. This avoids command churn
 * that makes an engine group stop, turn around or continuously re-form.
 * Locality/authority: Call on the current group owner. The function exits without issuing a
 * command if the group is not local or has become ineligible; addWaypoint and setCurrentWaypoint
 * must remain owner-local. A protected native task on a living member blocks a new group waypoint,
 * because a group waypoint cannot exclude that actor; independent actor operations remain available. The shared gate prevents delayed callbacks from adding a WAIT route after
 * Zeus, a player, or an external controller has taken ownership.
 * Repeat/JIP: The public intent record survives locality transfer. The new owner can reuse a
 * still-valid waypoint instead of injecting a duplicate. A materially changed request replaces
 * only the existing WAIT waypoint; authored mission and Zeus waypoints are never removed.
 *
 * An inserted waypoint uses normal engine movement: the group moves in formation, and when it completes the waypoint it carries on with
 * its own patrol or task waypoints. WAIT pass waypoints retain the WAIT description marker so
 * existing saved operations and validation can identify them; the owning intent record is the
 * authoritative removal scope. Only one WAIT pass waypoint exists per group at a time.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: position <ARRAY> - ATL destination
 * 2: completion radius <NUMBER> - metres (optional, default: 25)
 * 3: type <STRING> - waypoint type, MOVE or SAD (optional, default: "MOVE")
 *
 * Return Value:
 * Array - the waypoint [group, index]
 *
 * Example:
 * [_group, _rallyPoint] call WAIT_fnc_CortexGroupMove;
 * Result: the group moves to the rally point, then resumes its own waypoints.
 *
 * Current callers: retreat, reinforcement, coordinated assault, investigation, vehicle withdrawal and
 * standoff, and shoot-and-scoot.
 */

params [["_group", grpNull, [grpNull]], ["_position", [], [[]]], ["_radius", 25, [0]], ["_type", "MOVE", [""]], ["_operationGeneration", -1, [0]]];
if (isNull _group || {!local _group} || {count _position < 2}
    || {!([_group,false,false,true] call WAIT_fnc_CortexIsEligible)}) exitWith {[grpNull, -1]};
// A group-wide route cannot preserve an individual boarding, treatment or supply command.
// Do not convert that native task into MOVE, even when the group's general eligibility is valid.
// This does not disable sensing, firing or independently eligible actor-level operations.
if ((units _group) findIf {
    alive _x && {toUpperANSI (currentCommand _x) in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}
} >= 0) exitWith {[grpNull,-1]};
// Callers do not need to thread an operation token through every tactical helper. When a common
// operation is active, bind this route to its current generation automatically; ordinary mission
// support moves remain intentionally unscoped.
if (_operationGeneration < 0) then {
    _operationGeneration=(_group getVariable ["WAIT_Operation",createHashMap]) getOrDefault ["generation",-1];
};

private _desired = +_position;
_desired resize 3;
_radius = _radius max 1;
_type = toUpper _type;
private _intent = _group getVariable ["WAIT_Cortex_GroupMoveIntent", createHashMap];
private _previousWaypoint = _intent getOrDefault ["waypoint", []];
private _previousPosition = _intent getOrDefault ["position", []];
private _previousRadius = _intent getOrDefault ["radius", -1];
private _previousType = _intent getOrDefault ["type", ""];
private _hasOwnedWaypoint = count _previousWaypoint == 2
    && {(_previousWaypoint select 0) isEqualTo _group}
    && {(_previousWaypoint select 1) >= 0}
    && {(_previousWaypoint select 1) < count waypoints _group}
    && {waypointDescription _previousWaypoint == "WAIT AI PASS"};

// Keep an established engine route until a meaningful tactical change. Position drift inside the
// current completion radius and a small retask tolerance cannot justify a new waypoint.
private _sameDestination = count _previousPosition >= 2
    && {_desired distance2D _previousPosition <= ((_radius max _previousRadius) min 15)};
private _sameRequest = _hasOwnedWaypoint
    && {_sameDestination}
    && {abs (_radius - _previousRadius) <= 2}
    && {_type == _previousType};
if (_sameRequest) exitWith {_previousWaypoint};
// A curator, player or specialist can take the group after the earlier eligibility gate but before
// the waypoint write. Recheck at the mutation boundary so no delayed WAIT route is inserted over it.
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {[grpNull, -1]};
[_group] call WAIT_fnc_CortexGroupMoveClear;
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {[grpNull, -1]};
private _waypoint = _group addWaypoint [_position, 0, currentWaypoint _group];
_waypoint setWaypointType _type;
_waypoint setWaypointCompletionRadius _radius;
_waypoint setWaypointDescription "WAIT AI PASS";
_group setCurrentWaypoint _waypoint;
_group setVariable ["WAIT_Cortex_GroupMoveIntent", createHashMapFromArray [
    ["waypoint", _waypoint],
    ["position", _desired],
    ["radius", _radius],
    ["type", _type],
    ["issuedAt", serverTime],
    ["operationGeneration", _operationGeneration]
], true];
_waypoint


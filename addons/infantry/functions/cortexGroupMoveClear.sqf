/*
 * Author: WaldoTheWarfighter
 * Purpose: Removes only WAIT-owned temporary waypoints and clears their committed intent.
 * Locality/authority: Call on the group owner. deleteWaypoint is global, but owner-local use
 * prevents a stale machine from cancelling a newer owner's route.
 * Repeat/JIP: The public intent record is cleared before waypoint removal. Repeated cleanup is
 * harmless and never deletes authored Zeus or mission waypoints. Edited owned waypoints relinquish their internal description; generation-bound cleanup does not sweep other routes.
 *
 * Deleting the current waypoint makes the engine continue with the group's next waypoint, so the
 * group's own orders resume. The function first removes the waypoint recorded by
 * WAIT_fnc_CortexGroupMove, then cleans up only remaining legacy WAIT pass markers from the end
 * of the list so indices stay valid while deleting.
 *
 * Arguments:
 * 0: group <GROUP>, default grpNull.
 * 1: operation generation <NUMBER>, default -1 - only clear matching generation when non-negative.
 *
 * Return Value:
 * Number - waypoints removed
 *
 * Example:
 * [_group] call WAIT_fnc_CortexGroupMoveClear;
 * Result: the group goes back to its own waypoints.
 *
 * Current callers: WAIT_fnc_CortexGroupMove, WAIT_fnc_CortexGroupTick and WAIT_fnc_CortexReleaseGroup.
 */

params [["_group", grpNull, [grpNull]], ["_operationGeneration", -1, [0]]];
if (isNull _group || {!local _group}) exitWith {0};
private _intent = _group getVariable ["WAIT_Cortex_GroupMoveIntent", createHashMap];
// A delayed operation may only clear the waypoint it originally committed. Generic feature cleanup
// still passes -1 and uses the current intent, but generation-bound lifecycle cleanup must yield
// when a later operation has replaced this route.
if (_operationGeneration >= 0 && {(_intent getOrDefault ["operationGeneration",-1]) != _operationGeneration}) exitWith {0};
private _ownedWaypoint = _intent getOrDefault ["waypoint", []];
_group setVariable ["WAIT_Cortex_GroupMoveIntent", nil, true];
private _removed = 0;
if (count _ownedWaypoint == 2 && {(_ownedWaypoint select 0) isEqualTo _group}) then {
    private _index = _ownedWaypoint select 1;
    if (_index >= 0 && {_index < count waypoints _group} && {waypointDescription _ownedWaypoint == "WAIT AI PASS"}) then {
        private _snapshot=_group getVariable ["WAIT_Cortex_ZeusOrderSnapshot",[]];
        private _hold=_group getVariable ["WAIT_AIPass_ZeusHold",[]];
        private _curatorClaim=count _snapshot == 7 && {count _hold == 2}
            && {(_snapshot select 0) == (_hold select 0)} && {(_snapshot select 5) == _index};
        private _position=_intent getOrDefault ["position",[]];
        private _edited=count _position < 2
            || {waypointPosition _ownedWaypoint distance2D _position > 1}
            || {waypointType _ownedWaypoint != (_intent getOrDefault ["type",""])}
            || {abs (waypointCompletionRadius _ownedWaypoint-(_intent getOrDefault ["radius",-1])) > 0.1};
        if (_curatorClaim || {_edited}) then {
            // Relinquish the internal marker so ordinary order tracking can see the successor.
            // Preserve its position, type, radius, index and all native movement properties.
            _ownedWaypoint setWaypointDescription "";
        } else {
        deleteWaypoint _ownedWaypoint;
        _removed = _removed + 1;
        };
    };
};
if (_operationGeneration < 0) then {
for "_index" from (count waypoints _group - 1) to 0 step -1 do {
    if (waypointDescription [_group, _index] == "WAIT AI PASS") then {
        deleteWaypoint [_group, _index];
        _removed = _removed + 1;
    };
};
};
_removed


/*
 * Author: WaldoTheWarfighter
 * Purpose: Reads the full current authored driving waypoint identity without executing its condition.
 * Script, attachment, house-position, synchronization and loiter edits invalidate old recovery.
 * Attached target motion preserves identity; only changing the attached object changes the order.
 * Locality / Authority: Read-only anywhere; only current owners consume it for movement admission.
 * Repeat/JIP: Epoch, generation and current-brain identity reject stale work. New owners start
 * their own execution; local jobs and FSM handles are never replayed to JIP.
 * Arguments: 0 group <GROUP, grpNull>.
 * Return Value: ARRAY - opaque shared metadata rows; empty without an authored current waypoint.
 * Cost: reads metadata only for the current waypoint; handle lookup scales with route length.
 * Current callers: WAIT_fnc_DrivingAssistStart, DrivingOperationStart and DrivingOperationStep.
 * Example: private _order = [group driver truck1] call WAIT_fnc_DrivingRouteReceipt;
 */
params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {[]};
private _index=currentWaypoint _group;
if (_index <= 0 || {_index >= count waypoints _group}) exitWith {[]};
[_group,"",false,_index] call WAIT_fnc_AuthoredRouteReceipt

/*
 * Author: WaldoTheWarfighter
 * Purpose: Read the full current authored native waypoint identity for task replacement guards.
 * Locality/authority: Read-only anywhere; movement owners compare receipts before issuing commands.
 * Repeat/JIP: No state or handlers are installed. Callers persist the receipt in their durable operation.
 * Arguments: 0 group <GROUP>, default grpNull.
 * Return: ARRAY - empty for null; [waypoint count,-1] for implicit/no authored order;
 * otherwise [waypoint count, current index, opaque full authored metadata rows].
 * Script, attachment, house/loiter and synchronization edits are included. Moving an attached
 * target retains identity; its transient position is not an authored order replacement.
 * This reads authored values only; it never evaluates conditions or executes statements.
 * Only current-node metadata is read; native handle enumeration scales with route length.
 * Current callers: CortexClearBuilding, BuildingOperationStep, GroupBrainStep,
 * CortexOrderDispatch and CortexOrderLocal.
 * Example: private _receipt = [group soldier1] call WAIT_fnc_NativeOrderReceipt;
 */
params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {[]};
private _count=count waypoints _group;
private _index=currentWaypoint _group;
// Index zero is the engine's implicit spawn waypoint. Its natural completion is not a new order.
if (_count <= 1 || {_index <= 0} || {_index >= _count}) exitWith {[_count,-1]};
[_count,_index,[_group,"",false,_index] call WAIT_fnc_AuthoredRouteReceipt]

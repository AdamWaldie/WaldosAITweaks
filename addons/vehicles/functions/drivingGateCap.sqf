/*
 * Author: WaldoTheWarfighter
 * Purpose: Returns the gate-only view of the shared forward geometry observation.
 * Locality / Authority: Read-only vehicle owner, or trusted server recheck; no world mutation.
 * Repeat/JIP: Fresh observation only, no handlers/cache or passability replay. Animation/damage
 * never substitutes for physical geometry. Shared observer owns the 27-ray/108-hit turning bound (nine rays when straight).
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 requested cap m/s <NUMBER, 20>;
 * 2 authoritative server recheck <BOOL, false> permits remote-vehicle geometry on server.
 * Return Value: ARRAY [cap m/s, gate OBJECT, hull gap m, sampledAt, rays]. No gate is objNull.
 * Current callers: DrivingGateOpenServer; other executors consume both shared observations directly.
 * Example: private _gate=[truck1,15] call WAIT_fnc_DrivingGateCap;
 */
params [["_vehicle",objNull,[objNull]],["_requested",20,[0]],["_serverCheck",false,[true]]];
([_vehicle,_requested,_serverCheck] call WAIT_fnc_DrivingGeometryCap) select 0

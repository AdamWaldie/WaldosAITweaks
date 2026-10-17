/*
 * Author: WaldoTheWarfighter
 * Purpose: Read whether a solid object remains a stationary physical bypass candidate.
 * Vehicle hulls require an engine-off, unoccupied state; live crew, attachment or towing
 * invalidates a proposal even when the object's position has not changed yet.
 * Locality/authority: Read-only anywhere. The current driving owner alone admits/executes
 * a bypass; this predicate grants no movement, collision exemption or permission to pass traffic.
 * Repeat/JIP: No state, handlers or cache. Call at observation, planning and active-step boundaries.
 * Arguments: 0 obstacle <OBJECT>, default objNull.
 * Return: BOOL - false for null, pedestrians, moving/attached objects, or occupied/active vehicles.
 * Bounds: one current object and at most 64 crew; no world searches, rays or scheduler work.
 * Current callers: DrivingGeometryCap, DrivingBypassPlan and DrivingBypassStep.
 * Example: private _available=[parkedTruck] call WAIT_fnc_DrivingBypassObstacleAvailable;
 */
params [["_obstacle",objNull,[objNull]]];
if (isNull _obstacle || {_obstacle isKindOf "CAManBase"}
    || {abs speed _obstacle > 0.5} || {!isNull attachedTo _obstacle}
    || {(attachedObjects _obstacle) isNotEqualTo []}) exitWith {false};
if !(_obstacle isKindOf "AllVehicles") exitWith {true};
private _crew=crew _obstacle;
!isEngineOn _obstacle && {count _crew <= 64} && {_crew findIf {alive _x} < 0}

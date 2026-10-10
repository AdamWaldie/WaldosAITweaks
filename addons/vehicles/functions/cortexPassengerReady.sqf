/*
 * Author: WaldoTheWarfighter
 * Checks shared passenger safety before routine unloading or boarding; emergency engine bailouts remain independent.
 * Locality/authority: read-only on the requesting owner unless stated below.
 * Repeat/JIP: no side effects; runtime gates and actor task ownership are read again on every call.
 * Matching boarding may continue, but medical, equipment, finite actor reservations and replacement
 * boarding tasks yield without issuing seat or movement commands.
 * Arguments: 0: soldier <OBJECT>, objNull; 1: vehicle <OBJECT>, objNull; 2: boarding <BOOL>, false.
 * Return Value: Boolean.
 * Current callers: ConvoyCrewLocal, Vehicles and RestoreCalm.
 * Example: [_unit, _vehicle] call WAIT_fnc_CortexPassengerReady;
 */
params [["_unit", objNull, [objNull]], ["_vehicle", objNull, [objNull]], ["_boarding", false, [true]]];
if (isNull _vehicle || {!alive _vehicle} || {!local _unit} || {isPlayer _unit}
    || {!([_unit] call WAIT_fnc_CortexCombatEffective)}
    || {[group _unit,false,_unit] call WAIT_fnc_CortexExternalTakeover}
    || {"ALL" in ((group _unit) getVariable ["WAIT_AIPass_DisabledFeatures", []])}
    || {!isNull (_unit getVariable ["bis_fnc_moduleRemoteControl_owner", objNull])}
    || {abs speed _vehicle >= 1}) exitWith {false};
// A finite actor-level task owns this soldier independently of the passenger group's
// contact episode. Routine dismount/remount must not supersede its cover or recovery move.
private _reservation=_unit getVariable ["WAIT_Cortex_ActorMove",[]];
if (_reservation isNotEqualTo [] && {!(_reservation isEqualType []) || {count _reservation != 3}
    || {!((_reservation select 2) isEqualType 0)} || {time < (_reservation select 2)}}) exitWith {false};
// Routine seat changes must not steal an actor's medical, equipment or other authored task.
// The matching GET IN is our permitted continuation, not permission to replace a different seat.
private _command=toUpperANSI currentCommand _unit;
if (_command in ["GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]
    || {_command == "GET IN" && {!_boarding || {assignedVehicle _unit != _vehicle}}}) exitWith {false};
// A ground-level bridge deck is allowed only when a short downward geometry ray actually hits it.
private _position = getPosASL _vehicle;
private _wet = surfaceIsWater _position;
if (_wet) then {
    private _deck = lineIntersectsSurfaces [_position vectorAdd [0,0,0.5], _position vectorAdd [0,0,-3], _vehicle, _unit, true, 1, "GEOM", "NONE"];
    if (_deck isEqualTo []) exitWith {};
    _wet = (((_deck select 0) select 0) select 2) <= 0.5;
};
if (_wet) exitWith {false};
if (_boarding) exitWith {vehicle _unit == _unit && {canMove _vehicle} && {_vehicle emptyPositions "cargo" > 0}};
// Primary driver, gunner and commander roles are operating crew even if a turret flag is set.
vehicle _unit == _vehicle && {(fullCrew [_vehicle, "", false]) findIf {
    (_x select 0) == _unit && {(_x select 1) == "cargo" || {(_x select 1) == "turret" && {_x select 4}}}
} >= 0}

/*
 * Author: WaldoTheWarfighter
 * Purpose: Refuse scripted fire assignment while an actor has a protected native task or movement reservation.
 * Locality/authority: Read-only on the actor owner. Callers retain health, ROE, station and target authority.
 * Repeat/JIP: No state changes or renewal; reads the current task on every admission and fire boundary.
 * Arguments: 0 actor <OBJECT, objNull>.
 * Return: BOOL, true only for a local actor without a protected task or movement reservation.
 * Current callers: CortexCombinedArmsLocal, CortexCombinedGroundStep and CortexVehicles.
 * Example: private _available=[gunner tank1] call WAIT_fnc_CortexActorFireTaskAvailable;
 */
params [["_actor",objNull,[objNull]]];
if (isNull _actor || {!local _actor} || {[_actor] call WAIT_fnc_CortexActorMoveReserved}) exitWith {false};
!(toUpperANSI currentCommand _actor in [
    "GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
    "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED",
    "ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"
])

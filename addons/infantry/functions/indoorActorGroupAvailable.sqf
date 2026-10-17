/*
 * Author: WaldoTheWarfighter
 * Purpose: Decide whether an existing infantry operation leaves one actor free for indoor work.
 * Locality/authority: Read-only on the actor/group owner. Explicit disjoint rosters grant no
 * movement authority by themselves; the caller must still validate native orders and actor leases.
 * Repeat/JIP: Stateless; no reservation or operation generation is renewed or replayed.
 * Arguments: 0 actor <OBJECT>, objNull.
 * Return: BOOL; false for ambiguous/group-wide/overlapping work or malformed ownership records.
 * Current callers: IndoorActorOperation and CortexBuildingDoor indoor context.
 * Example: private _free=[soldier1] call WAIT_fnc_IndoorActorGroupAvailable;
 */
params [["_actor",objNull,[objNull]]];
if (isNull _actor || {!local _actor}) exitWith {false};
private _group=group _actor;
if (isNull _group || {!local _group}) exitWith {false};
if ((_group getVariable ["WAIT_AIPass_Garrison",[]]) isNotEqualTo []
    || {(_group getVariable ["WAIT_AIPass_Defend",[]]) isNotEqualTo []}
    || {_group getVariable ["WAIT_AIPass_ClearBuilding",false]}) exitWith {false};
private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
if (_actor in ((_state getOrDefault ["drill",createHashMap]) getOrDefault ["units",[]])
    || {_actor in (_state getOrDefault ["supportHeld",[]])}) exitWith {false};
// A temporary group waypoint owns formation travel, even if its record names fewer actors.
if (count (_group getVariable ["WAIT_Cortex_GroupMoveIntent",createHashMap]) > 0) exitWith {false};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation == 0) exitWith {true};
if (!((_operation getOrDefault ["intent",""]) in ["ADVANCE","FLANK","ASSAULT"])
    || {(_operation getOrDefault ["generation",-1]) != (_group getVariable ["WAIT_OperationGeneration",0])}
    || {(_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}
    || {(_operation getOrDefault ["cancelReason",""]) != ""}
    || {!((_operation getOrDefault ["participantsRequired",false]) isEqualTo true)}) exitWith {false};
private _participants=_operation getOrDefault ["participants",[]];
if (!(_participants isEqualType []) || {_participants isEqualTo []} || {count _participants > 64}) exitWith {false};
if (_participants findIf {!(_x isEqualType objNull) || {isNull _x} || {group _x != _group} || {!local _x}} >= 0) exitWith {false};
!(_actor in _participants)
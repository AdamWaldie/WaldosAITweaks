/*
 * Author: WaldoTheWarfighter
 * Owner execution preserves unknown/malformed actor reservations through the shared strict predicate.
 * Runs one reserved squad bound as two successive balanced fire-team movements.
 * Locality/authority: group owner consumes the current server role and matching lease.
 * Repeat/JIP: sequence prevents duplicate starts; migration restores mover leases before
 * the new owner consumes the durable role. Uses the finite tactical-drill FSM and publishes a
 * heartbeat so GroupTick can fail and restore a lost or starved controller.
 * Arguments: 0: group <GROUP>; 1: state <HASHMAP>; 2: role <ARRAY>, required.
 * Return: Boolean, true if a finite bound starts. Current caller: CortexSupportMaintain.
 * Example: [_group,_state,_role] call WAIT_fnc_CortexSupportBoundStart;
 */
params ["_group","_state","_role"];
if (!local _group || {count _role != 5} || {count (_state getOrDefault ["drill",createHashMap]) > 0}) exitWith {false};
// SupportMaintain can observe the role just before a curator or specialist claims the group.
// Recheck at the drill-allocation boundary: a rejected bound leaves the existing native/external
// order untouched and lets the server retire this role on the next acknowledgement.
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {false};
_role params ["_leaseToken","_sequence","_roleName","_point","_enemy"];
if (_roleName != "MOVE" || {_role isNotEqualTo (_group getVariable ["WAIT_Cortex_SupportRole",[]])}) exitWith {false};
private _lease=_group getVariable ["WAIT_AIPass_SupportLease",[]];
if (count _lease != 6 || {(_lease select 0) != _leaseToken} || {serverTime >= (_lease select 2)}) exitWith {false};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
private _generation=_state getOrDefault ["supportOperationGeneration",-1];
private _ownerEpoch=_group getVariable ["WAIT_AIPass_Epoch",0];
if (_generation < 0 || {(_operation getOrDefault ["generation",-2]) != _generation}
    || {(_operation getOrDefault ["ownerEpoch",-1]) != _ownerEpoch}
    || {(_operation getOrDefault ["intent",""]) != "COORDINATED_ASSAULT"}) exitWith {false};
private _final=_point distance2D (_lease select 5) < 2;
private _unavailable=_operation getOrDefault ["unavailable",[]];
private _fit=(units _group) select {
    local _x && {[_x] call WAIT_fnc_CortexCombatEffective} && {isNull objectParent _x}
        && {!(_x in _unavailable)} && {!isPlayer _x} && {isNull remoteControlled _x}
        && {([_x] call WAIT_fnc_CortexExternalOwner) == ""}
        && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
        && {_x checkAIFeature "PATH"} && {_x checkAIFeature "MOVE"}
        && {!([_x] call WAIT_fnc_CortexActorMoveReserved)}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
if (count _fit < 3) exitWith {false};
// Do not discard leaders, machine gunners or anti-tank soldiers when forming the
// moving teams. The server reserves any four combat-effective dismounts; applying a
// narrower role filter here made ordinary four-person squads accept a 180-second MOVE
// turn which they could never start. Interleaving retains both support weapons while
// ensuring every accepted squad produces two viable elements.
private _first=[];
private _second=[];
{
    ([_first,_second] select (_forEachIndex mod 2)) pushBack _x;
} forEach _fit;
if (count _first < 2 || {count _second < 1}) exitWith {false};
private _token=format ["SUPPORT:%1:%2:%3",_leaseToken,_sequence,clientOwner];
_state set ["drill",createHashMapFromArray [
    ["token",_token],["supportToken",_leaseToken],["supportSequence",_sequence],
    ["operationGeneration",_generation],["ownerEpoch",_ownerEpoch],
    ["type","ADVANCE"],["teams",[_first,_second]],["teamSizes",[count _first,count _second]],["teamTurn",0],["units",_fit],["desiredStrength",count _fit],
    ["points",[[+_point,["SUPPORT_BOUND","FINAL"] select _final]]],["index",0],["stage",""],
    ["enemyPos",+_enemy],["disabled",[]],["spots",[]],["started",time],["lastStep",time],
    ["boundStart",time],["pauseUntil",0]
]];
[_group,_state get "drill","START","COORDINATED_BOUND_ACCEPTED"] call WAIT_fnc_CortexDrillSetStage;
_state set ["supportBoundSequence",_sequence];
_group setVariable ["WAIT_Cortex_SupportBoundResult",[],true];
_group setVariable ["WAIT_Cortex_DrillReinforcements",[],true];
[_group,_token] call WAIT_fnc_CortexDrillStart;
true

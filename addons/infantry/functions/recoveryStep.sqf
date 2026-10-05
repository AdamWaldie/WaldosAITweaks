/*
 * Author: WaldoTheWarfighter
 * Purpose: Makes one bounded physical recovery attempt for a stalled participant without delaying the rest of its operation.
 * Locality/authority: Current group owner and current local participant only.
 * Repeat/JIP: Each actor receives one recovery generation. Exhaustion is published in the operation record and does not fabricate progress.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 actor <OBJECT>; 3 destination <ARRAY>.
 * Return Value: STRING - RECOVERING, EXHAUSTED, YIELDED or INVALID.
 * Current callers: Operation-backed manoeuvre and building jobs.
 * Example: [group player,4,soldier1,getPosATL player] call WAIT_fnc_RecoveryStep;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_actor",objNull,[objNull]],["_destination",[],[[]]]];
if (isNull _group || {isNull _actor} || {!local _group} || {!local _actor} || {count _destination < 2}) exitWith {"INVALID"};
// This is the final direct movement command in a recovery path. Recheck handover at the point of
// issue because a Zeus or specialist operation can arrive between an earlier operation step and
// this isolated retry. Recovery must retire rather than overwrite the newer controller's route.
if ([_group] call WAIT_fnc_CortexZeusHeld
    || {[_actor] call WAIT_fnc_CortexExternalOwner != ""}
    || {[leader _group] call WAIT_fnc_CortexExternalOwner != ""}
    || {[_group] call WAIT_fnc_CompatibilityExternalControl}) exitWith {"YIELDED"};
if (vehicle _actor != _actor || {!([_actor] call WAIT_fnc_CortexCombatEffective)}) exitWith {"INVALID"};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {"INVALID"};
private _recovery=_operation getOrDefault ["recovery",createHashMap];
private _key=netId _actor;
private _previous=_recovery getOrDefault [_key,[]];
private _attempts=if (_previous isEqualType []) then {_previous param [0,0]} else {_previous};
if (_attempts >= 1) exitWith {"EXHAUSTED"};
// Store the one physical retry and its start time. OperationStep can later quarantine only this
// actor if it still makes no progress; other participants retain their committed route.
_recovery set [_key,[_attempts+1,time,+_destination]];
_operation set ["recovery",_recovery];
_group setVariable ["WAIT_Operation",_operation,true];
_actor enableAI "PATH";
_actor doMove _destination;
_actor setDestination [_destination,"LEADER PLANNED",true];
"RECOVERING"

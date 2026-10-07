/*
 * Author: WaldoTheWarfighter
 * Purpose: Makes one bounded native recovery attempt for a stalled participant without enabling disabled AI features, duplicating route commands or delaying the rest of its operation.
 * Locality/authority: Current group owner and current local participant only.
 * Repeat/JIP: Each actor receives one attempt per operation generation and owner epoch. The final command boundary rechecks takeover; actors with MOVE or PATH disabled are left untouched.
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
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {"YIELDED"};
if (vehicle _actor != _actor || {!([_actor] call WAIT_fnc_CortexCombatEffective)}
    || {!(_actor checkAIFeature "MOVE")} || {!(_actor checkAIFeature "PATH")}) exitWith {"INVALID"};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {"INVALID"};
if ((_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])) exitWith {"INVALID"};
private _recovery=_operation getOrDefault ["recovery",createHashMap];
private _key=netId _actor;
private _previous=_recovery getOrDefault [_key,[]];
private _attempts=if (_previous isEqualType []) then {_previous param [0,0]} else {_previous};
if (_attempts >= 1) exitWith {"EXHAUSTED"};
// Store the one physical retry and its start time. OperationStep can later quarantine only this
// actor if it still makes no progress; other participants retain their committed route.
_recovery set [_key,[_attempts+1,time,+_destination]];
// Recheck the exact generation, epoch and external owner at the final command boundary. One
// doMove already requests a fresh native route; adding setDestination for the same destination
// created a second path instruction and could produce hesitation or a turn-back during recovery.
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {"YIELDED"};
private _currentOperation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _currentOperation == 0
    || {(_currentOperation getOrDefault ["generation",-2]) != _generation}
    || {(_currentOperation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {"INVALID"};
_currentOperation set ["recovery",_recovery];
_group setVariable ["WAIT_Operation",_currentOperation,true];
_actor doMove _destination;
"RECOVERING"

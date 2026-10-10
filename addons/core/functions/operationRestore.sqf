/*
 * Author: WaldoTheWarfighter
 * Purpose: Restore exact-owned operation settings without changing movement, targets or formation.
 * Locality/authority: Current group owner; matching operation generation and owner epoch only.
 * Repeat/JIP: Consumes the matching restore entry once. Migration cleanup does not restore old-owner
 * settings; resumable feature orders retain their original baseline for the destination owner.
 * Arguments: 0 group <GROUP>, grpNull; 1 operation <HASHMAP>, empty; 2 reason <STRING>, RELEASE.
 * Return: Boolean - true when an unchanged owned setting was restored.
 * Current callers: WAIT_fnc_OperationCancel and WAIT_fnc_OperationRelease.
 * Example: [group player,group player getVariable ["WAIT_Operation",createHashMap],"COMPLETE"] call WAIT_fnc_OperationRestore;
 */
params [["_group",grpNull,[grpNull]],["_operation",createHashMap,[createHashMap]],["_reason","RELEASE",[""]]];
if (isNull _group || {!local _group} || {count _operation == 0}
    || {toUpperANSI _reason == "OWNERSHIP_LOST"}) exitWith {false};
private _current=_group getVariable ["WAIT_Operation",createHashMap];
if ((_current getOrDefault ["generation",-1]) != (_operation getOrDefault ["generation",-2])
    || {(_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {false};
private _restore=_operation getOrDefault ["restore",createHashMap];
private _attack=_restore getOrDefault ["groupAttack",[]];
if (count _attack != 2 || {!((_attack select 0) isEqualType true)} || {!((_attack select 1) isEqualType true)}) exitWith {false};
_restore deleteAt "groupAttack";
private _members=units _group;
if (count _members > 64 || {[_group] call WAIT_fnc_CompatibilityExternalControl}
    || {_members findIf {isPlayer _x || {[_x] call WAIT_fnc_CompatibilityExternalControl}} >= 0}) exitWith {false};
private _anchor=leader _group;
if (isNull _anchor || {attackEnabled _anchor != (_attack select 1)}) exitWith {false};
// A later different setting belongs to its new owner. Restoring this unchanged boolean does
// not issue an attack or alter a Zeus waypoint, target, posture or movement command.
_group enableAttack (_attack select 0);
true

/*
 * Author: WaldoTheWarfighter
 * Purpose: Replaces unavailable tactical-role participants with capable surviving soldiers.
 * Locality/authority: Reads only local actors and updates the current group operation on its owner.
 * Repeat/JIP: Idempotent for an unchanged generation. Public operation state carries the current capable roster after migration.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 desired count <NUMBER>; 3 excluded actors <ARRAY, []>.
 * Return Value: ARRAY of capable local participants.
 * Current callers: bounding, clear-building and withdrawal recovery.
 * Example: [group player,4,4,[]] call WAIT_fnc_RebalanceRoles;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_desired",0,[0]],["_excluded",[],[[]]]];
if (isNull _group || {!local _group}) exitWith {[]};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {[]};
private _capable=(units _group) select {alive _x && {local _x} && {!isPlayer _x} && {lifeState _x != "INCAPACITATED"} && {isNull objectParent _x} && {!(_x in _excluded)}};
private _current=(_operation getOrDefault ["participants",[]]) select {_x in _capable};
{if (count _current < _desired && {!(_x in _current)}) then {_current pushBack _x}} forEach _capable;
_operation set ["participants",_current];
_group setVariable ["WAIT_Operation",_operation,true];
_current

/*
 * Author: WaldoTheWarfighter
 * Purpose: Replaces unavailable tactical-role participants with capable surviving soldiers without dropping the active element from progress accounting.
 * Locality/authority: Reads only local actors and updates the current group operation on its owner.
 * Protected native tasks and finite actor reservations cannot be recruited or retained as active role participants; an earlier roster entry does not override a newer finite owner.
 * Repeat/JIP: Idempotent for an unchanged generation and owner epoch. Only roster changes publish
 * operation state; unchanged callbacks do not retransmit it. Public state carries the roster after
 * migration; actors marked unavailable remain excluded.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 desired count <NUMBER>; 3 excluded actors <ARRAY, []>.
 * Return Value: ARRAY of capable local participants.
 * Current callers: bounding, clear-building and withdrawal recovery.
 * Example: [group player,4,4,[]] call WAIT_fnc_RebalanceRoles;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_desired",0,[0]],["_excluded",[],[[]]]];
if (isNull _group || {!local _group}) exitWith {[]};
if ([_group] call WAIT_fnc_CortexZeusHeld || {[_group] call WAIT_fnc_CompatibilityExternalControl}) exitWith {[]};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {[]};
if ((_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])) exitWith {[]};
private _blocked=(_operation getOrDefault ["unavailable",[]])+_excluded;
private _capable=(units _group) select {
    private _reservation=_x getVariable ["WAIT_Cortex_ActorMove",[]];
    private _reservationFree=_reservation isEqualTo []
        || {_reservation isEqualType [] && {count _reservation == 3} && {(_reservation param [2,1e12,[0]]) <= time}};
    local _x && {!isPlayer _x} && {isNull (remoteControlled _x)}
        && {([_x] call WAIT_fnc_CortexExternalOwner) == ""} && {[_x] call WAIT_fnc_CortexCombatEffective}
        && {isNull objectParent _x} && {!(_x in _blocked)}
        && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
        && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
        && {_reservationFree}
};
// Narrow specialist ownership to an eligible ordinary candidate; player/Zeus/group control
// remains group-wide. No candidate means no role publication or replacement.
if (_capable isEqualTo [] || {[_group,false,_capable select 0] call WAIT_fnc_CortexExternalTakeover}) exitWith {[]};
private _current=(_operation getOrDefault ["participants",[]]) select {_x in _capable};
{if (count _current < _desired && {!(_x in _current)}) then {_current pushBack _x}} forEach _capable;
if (_current isNotEqualTo (_operation getOrDefault ["participants",[]])) then {
    _operation set ["participants",_current];
    _group setVariable ["WAIT_Operation",_operation,true];
};
_current

/*
 * Author: WaldoTheWarfighter
 * Releases a finite Cortex naval landing and restores the exact boat speed borrowed for dismount.
 *
 * Locality/authority: call on the current group owner. Only the group whose token matches the
 * public boat plan may clear that plan or restore the boat. Passenger groups release only their
 * own movement lease. Zeus takeover and locality cleanup use this same path.
 * Repeat/JIP: public plan tokens and exact saved forced-speed values make repeated or late cleanup
 * harmless. No unit is boarded, moved or teleported during release.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP> (optional; current Cortex state by default)
 * 2: reason <STRING, CANCELLED> for the matching shared operation.
 *
 * Return Value:
 * Nothing
 *
 * Current callers: CortexNavalAssault and CortexReleaseGroup.
 *
 * Example:
 * [_group, _state] call WAIT_fnc_CortexNavalRelease;
 * Result: the boat and squad resume their authored orders.
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_state",createHashMap,[createHashMap]],
    ["_reason","CANCELLED",[""]]
];
if (isNull _group) exitWith {};
// A handover release must clear WAIT state without restoring a speed chosen by a later
// curator, mission or specialist controller.
private _externalTakeover=[_group] call WAIT_fnc_CortexExternalTakeover;
private _operation=_state getOrDefault ["navalOperation",[]];
if (_operation isEqualTo []) then {
    _operation=_group getVariable ["WAIT_Cortex_NavalOperation",[]];
};
private _token=_operation param [0,""];
private _boat=_operation param [1,objNull];
if (!isNull _boat) then {
    private _plan=_boat getVariable ["WAIT_Cortex_NavalPlan",[]];
    if (count _plan == 9 && {_token != ""} && {(_plan select 0) == _token}
        && {(_plan select 1) == _group} && {local _boat}) then {
        private _saved=_boat getVariable ["WAIT_Cortex_NavalForcedSpeed",[]];
        if (_saved isNotEqualTo [] && {!_externalTakeover}) then {_boat forceSpeed (_saved param [0,-1])};
        _boat setVariable ["WAIT_Cortex_NavalForcedSpeed",nil];
        _boat setVariable ["WAIT_Cortex_NavalPlan",nil,true];
    };
};
private _movement=_state getOrDefault ["movementLease",[]];
if ((_movement param [0,""]) in ["NAVAL_ASSAULT","NAVAL_LANDING"]) then {
    [_group] call WAIT_fnc_CortexGroupMoveClear;
    [_group,_movement param [0,""],false] call WAIT_fnc_CortexOwnershipLease;
    _state deleteAt "movementLease";
};
private _operationGeneration=_state getOrDefault ["navalOperationGeneration",-1];
if (_operationGeneration >= 0) then {
    if (toUpperANSI _reason == "COMPLETE") then {
        [_group,_operationGeneration,"COMPLETE","NAVAL_"+toUpperANSI _reason] call WAIT_fnc_OperationRelease;
    } else {
        [_group,_operationGeneration,"NAVAL_"+toUpperANSI _reason] call WAIT_fnc_OperationCancel;
    };
};
_state deleteAt "navalOperationGeneration";
_state deleteAt "navalOperation";
_group setVariable ["WAIT_Cortex_NavalOperation",nil,true];
_group setVariable ["WAIT_Cortex_NavalStatus",nil,true];

/*
 * Author: WaldoTheWarfighter
 * Selects and starts one viable local infantry manoeuvre from the squad's live tactical context.
 *
 * WAIT_fnc_CortexTacticalAssess first distinguishes close infantry, authored forward movement,
 * armour overmatch, fortified or elevated positions, and open versus concealed approaches. It
 * returns at most two candidate intents and one already-known contact. This dispatcher tries those
 * candidates in order, so a failed avenue or cooldown can immediately fall back without leaving a
 * capable squad idle. The assessment is deterministic from live evidence; no random permission
 * roll, scheduled assembly or separate tactical worker is introduced.
 *
 * Locality and authority: call only where the group is local. It reads the current server-published
 * feature gates and the live authored order/contact context, then delegates to owner-local starts.
 * Repeat/JIP: start functions reject active leases, drills and cooldowns, so repeated calls are safe.
 * Feature and order changes apply on the next group tick; no state is replayed to JIP clients.
 *
 * Arguments:
 * 0: group <GROUP> - local infantry group in contact
 * 1: state <HASHMAP> - current Cortex group state
 * 2: enemies <ARRAY> - current WAIT_fnc_CortexKnowledge result
 * 3: flank enabled <BOOL> - authoritative live feature gate (default true)
 * 4: advance enabled <BOOL> - authoritative live feature gate (default true)
 * 5: assault enabled <BOOL> - authoritative live feature gate (default true)
 *
 * Return Value:
 * Boolean - true when either manoeuvre started
 *
 * Current caller: WAIT_fnc_CortexGroupTick.
 *
 * Example:
 * private _started = [_group, _state, _enemies, true, true, true] call WAIT_fnc_CortexTacticalStart;
 * Result: Cortex follows the live objective/contact context and immediately tries the other viable
 * manoeuvre if the first cannot start.
 */

params [
    ["_group", grpNull, [grpNull]],
    ["_state", createHashMap, [createHashMap]],
    ["_enemies", [], [[]]],
    ["_flankEnabled", true, [true]],
    ["_advanceEnabled", true, [true]],
    ["_assaultEnabled", true, [true]]
];
if (isNull _group || {!local _group}) exitWith {false};

if (!_flankEnabled && {!_advanceEnabled} && {!_assaultEnabled}) exitWith {false};
private _assessment=[_group,_state,_enemies,_flankEnabled,_advanceEnabled,_assaultEnabled] call WAIT_fnc_CortexTacticalAssess;
private _intent=_assessment getOrDefault ["intent","HOLD"];
private _reason=_assessment getOrDefault ["reason","NO_VIABLE_CONTACT"];
private _targetIndex=_assessment getOrDefault ["targetIndex",-1];
private _candidates=_assessment getOrDefault ["candidates",[]];
private _evidence=_assessment getOrDefault ["evidence",[]];
_group setVariable ["WAIT_Cortex_TacticalAssessment",[
    _intent,_reason,serverTime,_evidence,_enemies apply {_x param [0,objNull,[objNull]]}
],true];
if (_targetIndex < 0 || {_candidates isEqualTo []}) exitWith {false};
private _prioritiseContact={
    params ["_contacts","_index"];
    if (_index <= 0) exitWith {+_contacts};
    [_contacts select _index]
        + (_contacts select [0,_index])
        + (_contacts select [_index+1])
};
private _orderedEnemies=[_enemies,_targetIndex] call _prioritiseContact;
private _started=false;
{
    switch (_x) do {
        case "ASSAULT": {_started=[_group,_state,_orderedEnemies] call WAIT_fnc_CortexAssaultStart};
        case "FLANK": {_started=[_group,_state,_orderedEnemies] call WAIT_fnc_CortexFlankStart};
        case "ADVANCE": {_started=[_group,_state,_orderedEnemies] call WAIT_fnc_CortexAdvanceStart};
    };
    if (_started) exitWith {};
} forEach _candidates;
if (_started) then {
    _group setVariable ["WAIT_Cortex_TacticalAssessment",[
        _intent,_reason,serverTime,_evidence,_enemies apply {_x param [0,objNull,[objNull]]},"STARTED"
    ],true];
};
_started

/*
 * Author: WaldoTheWarfighter
 * Selects and starts one viable local infantry manoeuvre from the squad's live tactical context.
 *
 * An active forward MOVE, SAD or DESTROY order prefers a bounded advance because that manoeuvre
 * preserves the authored objective. A squad without such an order prefers a flank against its live
 * contact. The other enabled manoeuvre is tried immediately when the preferred one cannot satisfy
 * its actor, range, avenue, cooldown or safety gates. Behaviour profiles do not assign squads a
 * fixed movement pattern and no random permission roll can leave a capable squad idle. A fresh
 * hostile inside the flank/advance minimum range first enters the direct assault path, closing the
 * former dead zone where every ordinary manoeuvre rejected the same contact. Each action selects
 * its first viable contact from the existing bounded knowledge result instead of allowing an
 * unsuitable nearest contact to veto a second known threat. The selected record is moved to the
 * front only for the delegated start call; WAIT does not reveal, retarget or rescan anything. Feature
 * switches remain the explicit mission-maker controls. The selector adds no scheduler, terrain
 * scan or per-unit loop; the selected start function owns the finite movement it creates.
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
private _started=false;
private _waypointIndex = currentWaypoint _group;
private _hasForwardOrder = _waypointIndex < count waypoints _group
    && {waypointDescription [_group,_waypointIndex] != "WAIT AI PASS"}
    && {waypointType [_group,_waypointIndex] in ["MOVE","SAD","DESTROY"]}
    && {leader _group distance2D waypointPosition [_group,_waypointIndex] > 80};
private _prioritiseContact={
    params ["_contacts","_index"];
    if (_index <= 0) exitWith {+_contacts};
    [_contacts select _index]
        + (_contacts select [0,_index])
        + (_contacts select [_index+1])
};
private _closeRange=(missionNamespace getVariable ["WAIT_AIPass_Assault_Range",80]) min 60;
private _assaultIndex=_enemies findIf {
    private _target=_x param [0,objNull,[objNull]];
    private _age=_x param [2,1e9,[0]];
    private _distance=_x param [3,1e9,[0]];
    !isNull _target && {alive _target} && {_age <= 10}
        && {_distance >= 12} && {_distance <= _closeRange}
};
if (_assaultEnabled && {_assaultIndex >= 0}) then {
    private _assaultEnemies=[_enemies,_assaultIndex] call _prioritiseContact;
    _started=[_group,_state,_assaultEnemies] call WAIT_fnc_CortexAssaultStart;
};
if (_started) exitWith {true};
if (!_flankEnabled && {!_advanceEnabled}) exitWith {false};
private _advanceIndex=_enemies findIf {
    private _target=_x param [0,objNull,[objNull]];
    private _age=_x param [2,1e9,[0]];
    private _distance=_x param [3,0,[0]];
    !isNull _target && {alive _target} && {_distance >= 60}
        && {_hasForwardOrder || {_age <= 10}}
};
private _advanceEnemies=if (_advanceIndex >= 0) then {
    [_enemies,_advanceIndex] call _prioritiseContact
} else {
    +_enemies
};
private _preferFlank = _flankEnabled && {!_advanceEnabled || {!_hasForwardOrder}};
if (_preferFlank) then {
    _started = [_group, _state, _enemies] call WAIT_fnc_CortexFlankStart;
    if (!_started && {_advanceEnabled}) then {
        _started = [_group, _state, _advanceEnemies] call WAIT_fnc_CortexAdvanceStart;
    };
} else {
    _started = [_group, _state, _advanceEnemies] call WAIT_fnc_CortexAdvanceStart;
    if (!_started && {_flankEnabled}) then {
        _started = [_group, _state, _enemies] call WAIT_fnc_CortexFlankStart;
    };
};
_started

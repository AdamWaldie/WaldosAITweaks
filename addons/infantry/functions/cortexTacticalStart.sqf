/*
 * Author: WaldoTheWarfighter
 * Selects and starts one viable local infantry manoeuvre from the squad's live tactical context.
 *
 * An active forward MOVE, SAD or DESTROY order prefers a bounded advance because that manoeuvre
 * preserves the authored objective. A squad without such an order prefers a flank against its live
 * contact. The other enabled manoeuvre is tried immediately when the preferred one cannot satisfy
 * its actor, range, avenue, cooldown or safety gates. Behaviour profiles do not assign squads a
 * fixed movement pattern and no random permission roll can leave a capable squad idle. A fresh
 * dismounted infantry hostile inside the flank/advance minimum range first enters the direct
 * assault path, closing the former dead zone where every ordinary manoeuvre rejected the same
 * contact. Vehicles, mounted crew and static weapons remain with anti-armour, fire-control,
 * standoff, flank or withdrawal logic instead of becoming infantry clear-through objectives. Each action selects
 * its first viable contact from the existing bounded knowledge result instead of allowing an
 * unsuitable nearest contact to veto a second known threat. Autonomous foot manoeuvre considers
 * dismounted infantry and fixed emplacements; tanks, APCs, ordinary vehicles, mounted crew and
 * aircraft remain with native fire, anti-armour, support or withdrawal. An authored forward order
 * may still advance through contact because that objective belongs to the mission maker. The selected record is moved to the
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
// Weapon employment and movement suitability are separate decisions. CortexAntiArmour and native
// targeting have already had their opportunity in this group tick; feeding the same mobile vehicle
// contact into the generic foot selector made rifle teams flank or charge a platform instead of
// keeping a coherent firing position. Fixed emplacements remain manoeuvre objectives because a
// side approach can physically clear their crew and firing arc.
private _manoeuvreEnemies=_enemies select {
    private _target=_x param [0,objNull,[objNull]];
    private _platform=if (isNull _target) then {objNull} else {vehicle _target};
    !isNull _target && {alive _target}
        && {(_target isKindOf "CAManBase" && {isNull objectParent _target})
            || {!isNull _platform && {_platform isKindOf "StaticWeapon"}}}
};
private _closeRange=(missionNamespace getVariable ["WAIT_AIPass_Assault_Range",80]) min 60;
private _assaultIndex=_manoeuvreEnemies findIf {
    private _target=_x param [0,objNull,[objNull]];
    private _age=_x param [2,1e9,[0]];
    private _distance=_x param [3,1e9,[0]];
    !isNull _target && {alive _target} && {_age <= 10}
        && {_target isKindOf "CAManBase"} && {isNull objectParent _target}
        && {_distance >= 12} && {_distance <= _closeRange}
};
if (_assaultEnabled && {_assaultIndex >= 0}) then {
    private _assaultEnemies=[_manoeuvreEnemies,_assaultIndex] call _prioritiseContact;
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
// Without an authored forward objective, contact itself is the destination and must therefore be a
// valid foot-manoeuvre target. With a mission-authored MOVE/SAD/DESTROY objective, preserve that
// route and merely use the best live contact as its fire/cover context.
if (!_hasForwardOrder) then {
    _advanceIndex=_manoeuvreEnemies findIf {
        private _age=_x param [2,1e9,[0]];
        private _distance=_x param [3,0,[0]];
        _distance >= 60 && {_age <= 10}
    };
    _advanceEnemies=if (_advanceIndex >= 0) then {
        [_manoeuvreEnemies,_advanceIndex] call _prioritiseContact
    } else {
        +_manoeuvreEnemies
    };
};
if (!_hasForwardOrder && {_manoeuvreEnemies isEqualTo []}) exitWith {
    _group setVariable ["WAIT_Cortex_TacticalAssessment",["FIRE_SUPPORT_ONLY",serverTime,
        _enemies apply {_x param [0,objNull,[objNull]]}],true];
    false
};
private _preferFlank = _flankEnabled && {!_advanceEnabled || {!_hasForwardOrder}};
if (_preferFlank) then {
    _started = [_group, _state, _manoeuvreEnemies] call WAIT_fnc_CortexFlankStart;
    if (!_started && {_advanceEnabled}) then {
        _started = [_group, _state, _advanceEnemies] call WAIT_fnc_CortexAdvanceStart;
    };
} else {
    _started = [_group, _state, _advanceEnemies] call WAIT_fnc_CortexAdvanceStart;
    if (!_started && {_flankEnabled}) then {
        _started = [_group, _state, _manoeuvreEnemies] call WAIT_fnc_CortexFlankStart;
    };
};
_started

/*
 * Author: WaldoTheWarfighter
 * Updates a squad's morale during a fight and says whether it should retreat or surrender.
 *
 * Weighted pressure: casualties against peak strength (45%), average
 * suppression (20%), losing the leader it started the fight with (10%), being outnumbered by enemies
 * seen in the last 30 s (15%), known armour within 400 m with no anti-tank gunner in the squad (20%)
 * and average wounds (10%). Average courage skill offsets it, so AI Rebalance profiles and mission
 * skills still matter. WAIT_AIPass_Cohesion (AI Tuning, default 1) divides the pressure, so squads
 * hold longer above 1 and break sooner below it. Morale falls quickly towards the pressure and recovers slowly (60% versus 10%
 * of the gap per step). The thresholds come from the group's behaviour profile
 * (WAIT_fnc_CortexProfile): STEADY at moraleShaken or more, SHAKEN above moraleBroken, BROKEN below
 * it. A broken squad must recover 0.1 above moraleBroken before it counts as shaken again, so it
 * cannot flicker. With the shipped table, MILITIA breaks much sooner than ELITE.
 * Shaken squads do not start flank, assault or advance drills. Broken squads retreat; with
 * WAIT_AIPass_Surrender_Enable, a broken squad no larger than the profile's surrenderSurvivors, with
 * an enemy believed within 60 m and no friendly squad within 300 m, surrenders instead.
 * Morale inputs come from state the pass already holds; there are no allUnits scans.
 * Locality and authority: call where the group is local.
 *
 * Repeat/JIP: current feature gates and eligibility are rechecked; owner jobs are retired on migration.
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP>
 * 2: enemies <ARRAY> - from WAIT_fnc_CortexKnowledge
 *
 * Return Value:
 * String - "" to carry on, "RETREAT" or "SURRENDER"
 *
 * Example:
 * private _outcome = [_group, _state, _enemies] call WAIT_fnc_CortexMorale;
 * Result: a squad that has lost most of its men under heavy fire breaks off.
 *
 * Current caller: WAIT_fnc_CortexGroupTick.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_enemies", [], [[]]]];
private _alive = (units _group) select {alive _x};
private _count = count _alive;
if (_count == 0) exitWith {""};
private _peak = (_group getVariable ["WAIT_AIPass_PeakSize", _count]) max _count;
private _courage = 0;
private _suppression = 0;
private _wounds = 0;
{
    _courage = _courage + (_x skill "courage");
    _wounds = _wounds + damage _x;
    if (local _x) then {_suppression = _suppression + getSuppression _x};
} forEach _alive;
_courage = _courage / _count;
_suppression = _suppression / _count;
_wounds = _wounds / _count;
private _contactLeader = _state getOrDefault ["contactLeader", leader _group];
private _leaderLost = [0, 1] select (!alive _contactLeader && {leader _group != _contactLeader});
private _recent = {(_x select 2) <= 30} count _enemies;
private _outnumbered = (((_recent / _count) - 1) max 0) min 2;
private _hasAT = _alive findIf {"AT" in ([_x] call WAIT_fnc_CortexCapabilities)} >= 0;
private _armour = [0, 1] select (!_hasAT && {_enemies findIf {
    private _enemy = vehicle (_x select 0);
    (_enemy isKindOf "Tank" || {_enemy isKindOf "Wheeled_APC_F"}) && {(_x select 3) <= 400} && {(_x select 2) <= 30}
} >= 0});
private _pressure = 0.45 * (1 - _count / _peak) + 0.2 * _suppression + 0.1 * _leaderLost
    + 0.15 * (_outnumbered / 2) + 0.2 * _armour + 0.1 * _wounds - 0.3 * (_courage - 0.5);
// Cohesion (AI Tuning): above 1 squads take more before they break, below 1 they break sooner.
_pressure = _pressure / ((missionNamespace getVariable ["WAIT_AIPass_Cohesion", 1]) max 0.1);
private _target = ((1 - _pressure) max 0) min 1;
private _morale = _state getOrDefault ["morale", 1];
_morale = if (_target < _morale) then {_morale + (_target - _morale) * 0.6} else {_morale + (_target - _morale) * 0.1};
_state set ["morale", _morale];
private _previous = _state getOrDefault ["moraleState", "STEADY"];
private _profile = [_group] call WAIT_fnc_CortexProfile;
private _broken = _profile get "moraleBroken";
private _current = switch (true) do {
    case (_morale < _broken || {_previous == "BROKEN" && {_morale < _broken + 0.1}}): {"BROKEN"};
    case (_morale < (_profile get "moraleShaken")): {"SHAKEN"};
    default {"STEADY"};
};
_state set ["moraleState", _current];
if (_current != _previous && {missionNamespace getVariable ["WAIT_AIPass_Debug", false]}) then {
    diag_log format ["[WAIT] %1 morale %2 -> %3 (%4)", _group, _previous, _current, _morale toFixed 2];
};
if (_current != "BROKEN") exitWith {""};

// The surrender executor deliberately handles only soldiers on foot. A mounted crew or passenger
// group must continue through the common withdrawal path instead of selecting an impossible terminal
// action and then skipping its movement step every tick.
private _allOnFoot = _alive findIf {vehicle _x != _x} < 0;
if (_allOnFoot && {[_group,"WAIT_AIPass_Surrender_Enable", true] call WAIT_fnc_CortexFeatureEnabled} && {_count <= (_profile get "surrenderSurvivors")}
    && {_enemies findIf {(_x select 3) < 60} >= 0}) then {
    private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;
    if (isNull _anchor) then {_anchor=leader _group};
    private _leaderPos = getPosATL _anchor;
    private _side = side _group;
    // This runs only for a broken squad, but must still stay spatially bounded. Scanning every
    // group turns simultaneous morale checks into an O(groups squared) workload at scale.
    private _friendsNear = (_leaderPos nearEntities ["Man",300]) findIf {
        alive _x && {group _x != _group} && {side group _x == _side}
            && {[_x] call WAIT_fnc_CortexCombatEffective} && {!fleeing _x}
    } >= 0;
    if (!_friendsNear) exitWith {"SURRENDER"};
    ["", "RETREAT"] select ((_state getOrDefault ["phase", ""]) == "CONTACT")
} else {
    ["", "RETREAT"] select ((_state getOrDefault ["phase", ""]) == "CONTACT")
}

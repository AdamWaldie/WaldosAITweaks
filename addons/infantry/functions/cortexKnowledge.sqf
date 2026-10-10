/*
 * Author: WaldoTheWarfighter
 * Purpose: Summarises bounded, engine-confirmed enemy knowledge for one local AI group without
 * creating or sharing target knowledge.
 * Locality/authority: Read-only; call where the group is local. It reads native AI knowledge and
 * prunes only that owner's short-lived observation cache. Nothing is broadcast or commanded.
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Summarises what a group already knows about nearby enemies, using only engine knowledge.
 *
 * The pass uses existing engine detection and preserves AI Rebalance settings. Enemies come from the leader's `targets` list plus a small,
 * owner-local cache of engine-confirmed group contacts. The believed position is `getHideFrom` from a member that already knows the enemy,
 * which the engine extrapolates when the enemy is out of sight. Seen age
 * is the newest lastSeen/lastThreat across up to eight living members, so a leader in cover does not
 * hide a firefight the rest of the squad is in. An enemy counts only if the group knows about it
 * (knownByGroup and knowsAbout of at least 1), which also covers `lastSeen` being 0 before any sighting.
 * At most eight enemies, nearest first, are examined.
 * Locality and authority: see the authority statement above.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: range <NUMBER> - metres from the leader (optional, default: WAIT_AIPass_EngageRange)
 *
 * Return Value:
 * Array - [enemies, seenCount]. enemies is an array of
 * [enemy <OBJECT>, believedPosATL <ARRAY>, seenAge <NUMBER>, distance <NUMBER>, errorMargin <NUMBER>],
 * nearest first. seenCount counts enemies seen within the last 5 seconds.
 *
 * Example:
 * ([_group] call WAIT_fnc_CortexKnowledge) params ["_enemies", "_seenCount"];
 * Result: the group's nearest known enemies and how many of them it can currently see.
 *
 * Current callers: WAIT_fnc_CortexGroupTick and the behaviour functions it calls.
 */

params [["_group", grpNull, [grpNull]], ["_range", -1, [0]]];
if (_range < 0) then {_range = missionNamespace getVariable ["WAIT_AIPass_EngageRange", 800]};
private _leader = leader _group;
if (!([_leader] call WAIT_fnc_CortexCombatEffective)) then {
    _leader=[_group] call WAIT_fnc_CortexGroupAnchor;
};
if (isNull _leader || {!alive _leader}) exitWith {[[], 0]};

// Native target lists remain the primary candidate source. EnemyDetected may be raised for a
// wingman while the leader is in cover, so include only those recent engine-confirmed contacts as
// local candidates. The cache neither shares a target nor bypasses the per-member knowledge check
// below, and is pruned every normal knowledge pass.
private _observed=_group getVariable ["WAIT_Danger_ObservedContacts",[]];
_observed=_observed select {
    _x isEqualType [] && {count _x in [2,3]} && {(_x select 0) isEqualType objNull}
        && {alive (_x select 0)} && {(_x select 1) > time}
};
if (_observed isEqualTo []) then {_group setVariable ["WAIT_Danger_ObservedContacts",nil]} else {
    _group setVariable ["WAIT_Danger_ObservedContacts",_observed]
};
// Preserve the actual local native knower recorded by EnemyDetected inside the same eight-member
// evaluation bound. Large squads otherwise lost immediate contact whenever the detecting wingman
// fell outside the arbitrary first-eight slice and the leader remained behind cover.
private _witnesses=[];
{
    private _target=_x select 0;
    private _witness=_x param [2,objNull,[objNull]];
    if ([_witness] call WAIT_fnc_CortexCombatEffective && {local _witness} && {group _witness == _group}
        && {_witness knowsAbout _target >= 1}) then {_witnesses pushBackUnique _witness};
} forEach _observed;
private _allMembers = (units _group) select {[_x] call WAIT_fnc_CortexCombatEffective};
private _members=([_leader]+_witnesses+(_allMembers-[_leader]-_witnesses))
    arrayIntersect ([_leader]+_witnesses+(_allMembers-[_leader]-_witnesses));
if (count _members > 8) then {_members resize 8};
private _candidateTargets=+(_leader targets [true, _range]);
{_candidateTargets pushBackUnique (_x select 0)} forEach _observed;
private _candidates = [];
{
    private _enemy = _x;
    if (alive _enemy && {!captive _enemy}) then {
        // Use a native knower's believed position. A leader that has not seen the contact must not
        // erase a wingman's valid group knowledge or replace it with an exact object position.
        private _knower=_members param [_members findIf {_x knowsAbout _enemy >= 1},objNull];
        if (!isNull _knower) then {
            private _position=_knower getHideFrom _enemy;
            if (_position isNotEqualTo [0,0,0] && {_leader distance2D _position <= _range}) then {
                // The unique index breaks ties so sort never has to compare objects.
                _candidates pushBack [_leader distance2D _position,count _candidates,_enemy,_position];
            };
        };
    };
} forEach _candidateTargets;
_candidates sort true;
if (count _candidates > 8) then {_candidates resize 8};

private _enemies = [];
private _seenCount = 0;
{
    _x params ["_distance", "_order", "_enemy", "_position"];
    private _newest = -1;
    private _knownByGroup = false;
    private _error = 1000;
    {
        private _knowledge = _x targetKnowledge _enemy;
        if (_knowledge select 0) then {_knownByGroup = true};
        _newest = _newest max ((_knowledge select 2) max (_knowledge select 3));
        _error = _error min (_knowledge select 5);
    } forEach _members;
    if (_knownByGroup) then {
        private _age = if (_newest > 0) then {time - _newest} else {1e6};
        if (_age <= 5) then {_seenCount = _seenCount + 1};
        _enemies pushBack [_enemy, _position, _age, _distance, _error];
    };
} forEach _candidates;
[_enemies, _seenCount]


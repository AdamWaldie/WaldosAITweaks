/*
 * Author: WaldoTheWarfighter
 * Purpose: Give one otherwise uncommitted infantry actor a finite chance to occupy a nearby useful
 * empty static weapon during confirmed contact, without taking the squad's movement operation. If
 * no existing emplacement is available, delegates compatible carried weapon bags to the finite
 * physical deployment state.
 * Locality / Authority: Runs on the current group owner. It issues a gunner assignment only to one
 * local AI actor and never moves, creates, repairs, rearms, teleports or changes the static weapon.
 * Repeat/JIP: One contact-episode lease records the exact actor, weapon and assignment. A contact is
 * sampled once; failed or unsuitable attempts are not retried until a later contact. Locality change
 * discards engine commands and lets the new owner reassess. Cleanup cancels only WAIT's exact still-
 * matching assignment; Zeus, player, specialist and newer external ownership are never overwritten.
 * Arguments: 0 group <GROUP>; 1 group state <HASHMAP>; 2 known enemies <ARRAY>.
 * Return Value: STRING - DISABLED, IDLE, MOVING, ACTIVE, FAILED or YIELDED.
 * Current callers: WAIT_fnc_CortexGroupTick while a group is in confirmed CONTACT.
 * Example: [group player, [group player] call WAIT_fnc_CortexGroupState, []] call WAIT_fnc_CortexStaticSupport;
 */

params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_enemies",[],[[]]]];
if (isNull _group || {!local _group}) exitWith {"YIELDED"};
private _lease=_group getVariable ["WAIT_Danger_StaticSupport",[]];
private _clearActorMove={
    params ["_actor"];
    if (!isNull _actor && {local _actor}) then {
        private _actorMove=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
        if ((_actorMove param [0,""]) == "STATIC_SUPPORT") then {
            _actor setVariable ["WAIT_Cortex_ActorMove",nil];
        };
    };
};
private _release={
    params ["_external"];
    if (count _lease >= 7) then {
        private _actor=_lease param [1,objNull,[objNull]];
        private _weapon=_lease param [2,objNull,[objNull]];
        [_actor] call _clearActorMove;
        if (!_external && {!isNull _actor} && {alive _actor} && {local _actor}
            && {!isPlayer _actor} && {group _actor == _group}
            && {!isNull _weapon} && {assignedVehicle _actor == _weapon}) then {
            [_actor] orderGetIn false;
            unassignVehicle _actor;
            if (vehicle _actor == _weapon) then {_actor action ["GetOut",_weapon]};
        };
    };
    _group setVariable ["WAIT_Danger_StaticSupport",nil,true];
};

private _enabled=missionNamespace getVariable ["WAIT_AIPass_Active",false]
    && {[_group,"WAIT_AIPass_StaticSupport_Enable",true] call WAIT_fnc_CortexFeatureEnabled};
private _external=[_group] call WAIT_fnc_CortexExternalTakeover;
private _phase=toUpperANSI (_state getOrDefault ["phase","CALM"]);
private _holdFire=combatMode _group in ["BLUE","GREEN"];
if (!_enabled || {_phase != "CONTACT"} || {_holdFire} || {_enemies isEqualTo []} || {_external}) exitWith {
    [_external] call _release;
    [_group,_state,[]] call WAIT_fnc_CortexStaticDeployStep;
    ["IDLE","YIELDED"] select _external
};

private _episode=_state getOrDefault ["phaseStart",time];
if ((_group getVariable ["WAIT_Danger_StaticDeployment",[]]) isNotEqualTo []) exitWith {
    [_group,_state,_enemies] call WAIT_fnc_CortexStaticDeployStep
};
if (count _lease >= 7) exitWith {
    _lease params ["_leaseEpisode","_actor","_weapon","_issuedAt","_deadline","_status","_startPosition"];
    if (_leaseEpisode != _episode || {isNull _actor} || {!alive _actor} || {!local _actor}
        || {isPlayer _actor} || {group _actor != _group} || {isNull _weapon} || {!alive _weapon}
        || {!(simulationEnabled _weapon)} || {assignedVehicle _actor != _weapon && {vehicle _actor != _weapon}}) exitWith {
        [false] call _release;
        "FAILED"
    };
    if (vehicle _actor == _weapon && {gunner _weapon == _actor}) exitWith {
        [_actor] call _clearActorMove;
        if (_status != "ACTIVE") then {
            _lease set [5,"ACTIVE"];
            _group setVariable ["WAIT_Danger_StaticSupport",_lease,true];
        };
        "ACTIVE"
    };
    if (time >= _deadline) exitWith {
        [false] call _release;
        _group setVariable ["WAIT_Danger_StaticAttempt",[_episode,"FAILED",serverTime],true];
        "FAILED"
    };
    "MOVING"
};

private _attempt=_group getVariable ["WAIT_Danger_StaticAttempt",[]];
if ((_attempt param [0,-1,[0]]) == _episode) exitWith {_attempt param [1,"IDLE",[""]]};
// An existing group operation already owns its participant set. Static support is selected before a
// new manoeuvre starts and then composes beside it; it never removes an actor from a live operation.
if (count (_group getVariable ["WAIT_Operation",createHashMap]) > 0) exitWith {
    // Temporary operation ownership is not a failed contact-episode attempt.
    "IDLE"
};
private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _anchor) then {_anchor=leader _group};
if (isNull _anchor) exitWith {"IDLE"};
private _sideIndex=switch (side _group) do {case west:{1}; case east:{0}; case independent:{2}; default {3}};
private _weapons=(nearestObjects [_anchor,["StaticWeapon"],75,true]) select {
    // canFire requires an operator and cannot qualify an empty emplacement.
    alive _x && {simulationEnabled _x} && {damage _x < 0.9} && {someAmmo _x}
        && {_x emptyPositions "gunner" > 0}
        && {crew _x isEqualTo []} && {locked _x < 2}
        && {getNumber (configOf _x >> "side") in [_sideIndex,3]}
};
if (_weapons isEqualTo []) exitWith {
    private _deploy=[_group,_state,_enemies] call WAIT_fnc_CortexStaticDeployStep;
    if (_deploy != "IDLE") then {
        _group setVariable ["WAIT_Danger_StaticAttempt",[_episode,_deploy,serverTime],true];
    };
    _deploy
};
private _rankedWeapons=_weapons apply {[_anchor distance2D _x,_x]};
_rankedWeapons sort true;
private _weapon=(_rankedWeapons select 0) select 1;
private _candidates=(units _group) select {
    alive _x && {local _x} && {!isPlayer _x} && {_x != leader _group}
        && {[_x] call WAIT_fnc_CortexCombatEffective} && {vehicle _x == _x}
        && {isNull assignedVehicle _x}
        // Native contact commands such as TARGET and WATCH are transient observations, not an
        // external movement owner. Reject only concrete actor tasks which boarding would actually
        // interrupt; the group-level Zeus/mission-order gate above already protects authored work.
        && {!(toUpperANSI (currentCommand _x) in ["GET IN","ACTION","HEAL","REARM","JOIN"])}
        && {(_x getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo []}
};
if (_candidates isEqualTo []) exitWith {
    _group setVariable ["WAIT_Danger_StaticAttempt",[_episode,"NO_ACTOR",serverTime],true];
    "IDLE"
};
private _rankedActors=_candidates apply {[_x distance2D _weapon,_x]};
_rankedActors sort true;
private _actor=(_rankedActors select 0) select 1;
private _deadline=time+20;
_actor assignAsGunner _weapon;
[_actor] orderGetIn true;
_actor setVariable ["WAIT_Cortex_ActorMove",["STATIC_SUPPORT",getPosATL _weapon,_deadline]];
_lease=[_episode,_actor,_weapon,time,_deadline,"MOVING",getPosATL _actor];
_group setVariable ["WAIT_Danger_StaticSupport",_lease,true];
_group setVariable ["WAIT_Danger_StaticAttempt",[_episode,"MOVING",serverTime],true];
"MOVING"

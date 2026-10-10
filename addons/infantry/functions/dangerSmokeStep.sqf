/*
 * Author: WaldoTheWarfighter
 * Direction requires retained native contact; an impact without contact cannot define a throw bearing.
 * Purpose: Opportunistically deploy one carried smoke grenade during a severe finite danger response without delaying cover, movement, firing or the group operation state.
 * Locality / Authority: Runs inside the owner-local group-brain scheduler. It selects one local foot soldier and queues one local throw after rechecking WAIT, Zeus, specialist and generation ownership.
 * Selection tries at most three ordinary carriers; unavailable inventory backs off without blocking the group.
 * Repeat/JIP: A generation-scoped group lease and cooldown coalesce a danger burst. Queued throws are not replayed to JIP and a later generation, order or external owner cancels before weapon release.
 * Arguments: 0: group <GROUP>; 1: danger response <ARRAY> [cause, position, observedAt, expires, generation].
 * Return Value: Boolean - true only when a smoke throw was queued for the current danger generation.
 * Current callers: WAIT_fnc_CortexGroupTick.
 * Example: [group player,["SUPPRESSED",getPosATL player,time,time+2,4]] call WAIT_fnc_DangerSmokeStep;
 */

params [["_group",grpNull,[grpNull]],["_response",[],[[]]]];
if (isNull _group || {!local _group} || {count _response != 5}) exitWith {false};
_response params ["_cause","_threat","_observedAt","_expires","_generation"];
if (!(_cause in ["HIT","EXPLOSION","SUPPRESSED"]) || {count _threat < 2}
    || {time >= _expires} || {_generation != (_group getVariable ["WAIT_Danger_Generation",-1])}
    || {!(missionNamespace getVariable ["WAIT_AIPass_Active",false])}
    || {!([_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!([_group,"WAIT_AIPass_DangerSmoke_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {combatMode _group in ["BLUE","GREEN"]}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
private _lease=_group getVariable ["WAIT_Danger_SmokeLease",[]];
if (count _lease == 3 && {(_lease select 0) == _generation}) exitWith {false};
if (time < (_group getVariable ["WAIT_Danger_SmokeAfter",-1])) exitWith {false};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
private _reserved=if (count _operation > 0) then {+(_operation getOrDefault ["participants",[]])} else {[]};
// ATTACK is also the engine's ordinary autonomous combat command. It does not
// imply a specialist/native action owner; the queued throw still rechecks those tasks.
private _actorAvailable={
    params ["_actor"];
    private _reservation=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
    !(count _reservation == 3 && {(_reservation param [2,-1,[0]]) > time})
};
private _candidates=(units _group) select {
    [_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
        && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
        && {vehicle _x == _x} && {[_x] call _actorAvailable}
        && {currentCommand _x in ["","MOVE","ATTACK","SUPPRESS","FIRE"]}
        && {!(_x in _reserved)} && {getSuppression _x >= 0.55 || {_cause in ["HIT","EXPLOSION"]}}
};
if (_candidates isEqualTo []) then {
    _candidates=(units _group) select {
        [_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
        && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
            && {vehicle _x == _x} && {[_x] call _actorAvailable}
        && {currentCommand _x in ["","MOVE","ATTACK","SUPPRESS","FIRE"]}
            && {getSuppression _x >= 0.7 || {_cause == "HIT"}}
    };
};
if (_candidates isEqualTo []) exitWith {false};
private _ranked=_candidates apply {[-getSuppression _x,random 1,_x]};
_ranked sort true;
private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
private _contact=_state getOrDefault ["enemyPos",[]];
// An impact is not a shooter bearing. Never screen an arbitrary blast position:
// it can be behind the actor while the actual contact remains in front.
if (!(_state getOrDefault ["contactKnowledge",false]) || {count _contact < 2}) exitWith {false};
private _screenThreat=+_contact;
private _thrower=objNull;
private _queued=false;
{
    private _candidate=_x select 2;
    private _origin=getPosATL _candidate;
    if (_origin distance2D _screenThreat >= 3) then {
        private _screen=_origin getPos [18,_origin getDir _screenThreat];
        _screen set [2,_origin select 2];
        _queued=[_candidate,_screen,"SMOKE",["DANGER",_generation,_expires]] call WAIT_fnc_CortexThrowGrenade;
    };
    if (_queued) exitWith {_thrower=_candidate};
} forEach (_ranked select [0,3]);
if (!_queued) exitWith {
    // A missing grenade must not cause inventory/config work on every tactical callback.
    _group setVariable ["WAIT_Danger_SmokeAfter",time+3];
    false
};
_group setVariable ["WAIT_Danger_SmokeLease",[_generation,_thrower,time],true];
_group setVariable ["WAIT_Danger_SmokeAfter",time+45];
private _stats=_group getVariable ["WAIT_Danger_EngineStats",createHashMap];
_stats set ["smokeResponses",((_stats getOrDefault ["smokeResponses",0])+1) min 100000];
_stats set ["lastSmokeActor",_thrower];
_group setVariable ["WAIT_Danger_EngineStats",_stats];
true

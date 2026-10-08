/*
 * Author: WaldoTheWarfighter
 * Purpose: Decide whether one completed engine danger response needs a bounded follow-up sample.
 * It preserves close hostile contact, its original danger cause and commander vehicle awareness
 * without issuing movement, targeting, firing or posture commands and without starting another
 * tactical controller.
 * Locality / Authority: Runs only for the local AI actor from its engine danger FSM. The existing
 * group brain remains the sole group-level decision owner.
 * Repeat/JIP: Stateless apart from bounded diagnostics. Locality loss or any newer owner makes the
 * caller terminate. A follow-up record remains finite and is revalidated on every cycle.
 * Arguments: 0: actor <OBJECT>, objNull; 1: response mode <STRING>, ASSESS;
 * 2: selected engine record <ARRAY>, [].
 * Return Value: Array - one follow-up engine record, or [] when the response should drain and end.
 * Current callers: Engine-loaded infantry danger FSM Recycle state.
 * Example: [cursorObject,"ENGAGE",[0,getPosATL cursorObject,time + 1,objNull]] call WAIT_fnc_DangerEngineRecycle;
 */

params [['_actor',objNull,[objNull]],['_mode','ASSESS',['']],['_record',[],[[]]]];
if (isNull _actor || {!local _actor} || {!alive _actor} || {isPlayer _actor}
    || {count _record < 4} || {!([_actor] call WAIT_fnc_DangerEngineCanContinue)}) exitWith {[]};

private _group=group _actor;
private _source=_record param [3,objNull,[objNull]];
if (isNull _group || {isNull _source} || {!alive _source}) exitWith {[]};
if ((side _group) getFriend (side _source) >= 0.6) exitWith {[]};

private _cause=_record param [0,-1,[0]];
private _follow=false;
switch (_mode) do {
    case 'ENGAGE': {
        // Close hostile contact remains actionable between native danger callbacks. This mirrors
        // the engine's expected persistence while leaving target choice and movement native.
        _follow=_actor distance2D _source < 35 && {_actor knowsAbout _source > 0};
    };
    case 'VEHICLE': {
        // Only the effective commander may sustain vehicle awareness. Other crew finish their
        // reflex immediately so a full crew cannot multiply the same vehicle response.
        _follow=effectiveCommander (vehicle _actor) == _actor
            && {_cause in [0,2,3,8,9]}
            && {_actor knowsAbout _source > 0};
    };
};
if (!_follow) exitWith {[]};

private _position=_actor getHideFrom _source;
// Recycling may retain only the engine's believed geometry. Falling back to the source object's
// exact live position manufactures precision at the moment native memory is no longer usable and
// lets a stale finite response outlive genuine knowledge. End this actor response instead; normal
// EnemyDetected/knowledge intake will wake the shared group brain again after a real reacquisition.
if (_position isEqualTo [0,0,0]) exitWith {[]};
if (count _position == 2) then {_position pushBack ((getPosATL _actor) select 2)};
if (count _position != 3) exitWith {[]};

private _stats=_group getVariable ['WAIT_Danger_EngineStats',createHashMap];
_stats set ['recycles',((_stats getOrDefault ['recycles',0])+1) min 100000];
_stats set ['lastRecycleAt',time];
_stats set ['lastRecycleActor',_actor];
if (_mode == 'VEHICLE') then {
    private _actors=_stats getOrDefault ['vehicleRecycleActors',[]];
    private _actorId=netId _actor;
    if (_actorId == '') then {_actorId=str _actor};
    _actors pushBackUnique _actorId;
    _actors resize ((count _actors) min 4);
    _stats set ['vehicleRecycleActors',_actors];
};
_group setVariable ['WAIT_Danger_EngineStats',_stats];
// Retain the cause which justified the response. Collapsing a continuing hit or near-round event
// into DETECTED made the next group handoff lose its safety priority and could prematurely retire
// a mounted response even though the same known hostile remained actionable.
[_cause,+_position,time+1.5,_source]

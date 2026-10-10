/*
 * Author: WaldoTheWarfighter
 * Purpose: Apply one bounded, low-priority danger stance without taking movement, target or firing ownership or arresting a committed operation.
 * Locality / Authority: Runs only for the local AI soldier after ownership and order classification.
 * Repeat/JIP: Uses one machine-local, expiring weak-stance lease. A repeated danger response retains
 * the original authored stance and refreshes only WAIT's applied value. Native or external stance
 * changes invalidate the lease and are not overwritten. A committed mover is never forced prone.
 * Idle prone riflemen may perform one native lateral evasion after a hit or near round.
 * A per-actor cooldown prevents repeated actions; committed routes and specialist/native tasks yield.
 * It never creates a movement, target or firing lease.
 * Arguments: 0: soldier <OBJECT>, objNull; 1: mode <STRING>, ASSESS; 2: selected record <ARRAY>, [].
 * Return Value: Number - short observation deadline in seconds.
 * Current callers: Engine-loaded infantry danger FSM action states.
 * Example: [cursorObject,"IMMEDIATE",[2,getPosATL cursorObject,time + 1,objNull]] call WAIT_fnc_DangerEngineAct;
 */

params [["_actor",objNull,[objNull]],["_mode","ASSESS",[""]],["_record",[],[[]]]];
if (isNull _actor || {!local _actor} || {!([_actor] call WAIT_fnc_CortexCombatEffective)}
    || {isPlayer _actor}) exitWith {0};
private _group=group _actor;
if (isNull _group || {!local _group}
    || {!(missionNamespace getVariable ["WAIT_AIPass_Active",false])}
    || {!([_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!([_group,false,true,false,_actor] call WAIT_fnc_CortexIsEligible)}
    || {[] call WAIT_fnc_CortexIsPaused}
    || {[_group,false,_actor] call WAIT_fnc_CortexExternalTakeover}
    || {[_group] call WAIT_fnc_CortexZeusHeld}) exitWith {0};
// Recheck actor-level authority at the command boundary; group eligibility alone does not
// cover a specialist actor sharing an otherwise ordinary group.
if ([_actor] call WAIT_fnc_CompatibilityExternalControl
    || {currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN"]}) exitWith {0};
private _delays=createHashMapFromArray [["FORCED",0.75],["VEHICLE",1],["IMMEDIATE",1],["HIDE",1.25],["ENGAGE",1],["ASSESS",0.75]];
// A small local offset prevents an entire squad from changing stance on the same frame while
// retaining a strict upper bound and no recurring work.
private _delay=(_delays getOrDefault [_mode,0.75]) + random 0.25;
private _cause=_record param [0,-1,[0]];
private _desiredStance="";
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
private _participants=if (count _operation > 0) then {_operation getOrDefault ["participants",[]]} else {[]};
private _unavailable=if (count _operation > 0) then {_operation getOrDefault ["unavailable",[]]} else {[]};
// A live route belongs to the common operation owner. Immediate danger may lower a mover's profile,
// but a repeated explosion or suppression stream must not pin that actor prone and stall the route.
private _committedMover=count _operation > 0
    && {_actor in _participants}
    && {!(_actor in _unavailable)}
    && {(_operation getOrDefault ["route",[]]) isNotEqualTo []}
    && {toUpperANSI (_operation getOrDefault ["phase",""]) in ["APPROACH","ENTRY","MANOEUVRE","ASSAULT","MOVING","TRAVEL","WITHDRAW"]};

// Some finite actor-level opportunities compose beside the group operation. Static deployment,
// packing, cover, grenade evasion and launcher relocation already own an exact destination and deadline; an immediate
// danger response must not force these movers prone merely because they are not group participants.
private _actorMove=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
if (count _actorMove == 3 && {(_actorMove param [2,-1,[0]]) > time}
    && {(_actorMove param [0,"",[""]]) in ["STATIC_DEPLOY","STATIC_PACK","DANGER_COVER","GRENADE_EVASION","ANTI_ARMOUR","STATIC_SUPPORT"]}) then {
    _committedMover=true;
};
// An idle prone rifleman can react physically without a new destination or a tactical worker.
// Native actions retain engine collision and animation handling. Never roll a committed mover,
// override another native action, or replay this response on every danger recycle.
if (_mode == "IMMEDIATE" && {_cause in [2,9]} && {!_committedMover}
    && {[_group,"WAIT_AIPass_DangerEvasion_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {isNull objectParent _actor} && {stance _actor == "PRONE"}
    && {abs (speed _actor) < 0.5}
    && {currentCommand _actor in ["","ATTACK","FIRE","SUPPRESS"]}
    && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
    && {primaryWeapon _actor != ""} && {currentWeapon _actor == primaryWeapon _actor}
    && {time >= (_actor getVariable ["WAIT_Danger_EvasionAfter",-1])}) then {
    private _point=_record param [1,[],[[]]];
    private _action=selectRandom ["EvasiveLeft","EvasiveRight"];
    if (count _point >= 2 && {_actor distance2D _point >= 3}) then {
        _action=["EvasiveRight","EvasiveLeft"] select (_actor getRelDir _point < 180);
    };
    _actor setVariable ["WAIT_Danger_EvasionAfter",time+3];
    _actor playActionNow _action;
    _actor setVariable ["WAIT_Danger_LastEvasion",[time,_cause,_action,
        _group getVariable ["WAIT_Danger_Generation",-1],getPosATL _actor]];
};
// Body and scream observations deserve a visible finite assessment, not only a stance flag.
// Use the position form only: an object argument would fully disclose that object.
// Preserve committed movement and concrete native tasks; this never reveals an enemy.
if (_mode == "HIDE" && {_cause in [5,6,7]} && {!_committedMover}
    && {[_group,"WAIT_AIPass_DangerObservation_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {isNull objectParent _actor} && {currentCommand _actor == ""}) then {
    private _position=_record param [1,[],[[]]];
    if (count _position == 3 && {_position findIf {!(_x isEqualType 0)} < 0}) then {
        _actor glanceAt _position;
    };
};
// Forced orders and vehicle crews already have an engine movement owner. Recording the response is
// useful, but changing their posture would compete with that owner. Foot soldiers receive only a
// short scripted stance. Direct commander stance orders have higher engine priority, while another
// script or controller changing the scripted stance invalidates WAIT's exact lease on release.
if (_mode == "IMMEDIATE") then {
    // Visible fire, a direct hit, an explosion and a near round are immediate physical hazards.
    // The group layer may grant one idle actor a bounded cover move; this actor-local reflex also
    // lowers the profile immediately while that scheduled cover selection is pending.
    private _hardCover=(getSuppression _actor > 0.55) || {_cause in [1,2,4,9]} || {currentCommand _actor == "STOP"};
    _desiredStance=["MIDDLE","DOWN"] select (_hardCover && {!_committedMover});
};
if (_mode == "HIDE") then {
    // Seeing a casualty or hearing a scream is alerting evidence, not proof of rounds arriving at
    // this actor. Keep a mobile crouch unless native suppression itself justifies going prone.
    _desiredStance=["MIDDLE","DOWN"] select (!_committedMover && {getSuppression _actor > 0.45});
};
if (_mode == "ENGAGE") then {
    // An authored stealth/hold-fire element should reduce its silhouette when it detects a real
    // hostile instead of WAIT converting awareness into fire or movement authority. This remains a
    // weak, expiring stance and is never applied to a committed mover.
    private _stealthHold=behaviour _actor == "STEALTH"
        && {combatMode _group in ["BLUE","GREEN"]}
        && {abs (speed _actor) < 1}
        && {!_committedMover};
    if (_stealthHold) then {
        _desiredStance="DOWN";
    } else {
        if (getSuppression _actor > 0.2 && {stance _actor == "STAND"}) then {
            _desiredStance="MIDDLE";
        };
    };
};

if (_desiredStance != "") then {
    private _currentStance=toUpperANSI (unitPos _actor);
    private _lease=_actor getVariable ["WAIT_Danger_EngineStanceLease",[]];
    private _priorStance=_currentStance;
    // A group-hide lease is another WAIT posture owner, not an external authored stance.
    // Transfer its original baseline before the actor FSM acquires this soldier; otherwise the
    // actor captures a temporary crouch/prone value and restores that value permanently later.
    private _groupLeases=_group getVariable ["WAIT_Danger_GroupHideLeases",[]];
    private _groupLeaseIndex=_groupLeases findIf {(_x param [0,objNull]) == _actor};
    if (_groupLeaseIndex >= 0) then {
        private _groupLease=_groupLeases select _groupLeaseIndex;
        if (_currentStance == (_groupLease param [2,"",[""]])) then {
            _priorStance=_groupLease param [1,_currentStance,[""]];
        };
        _groupLeases deleteAt _groupLeaseIndex;
        _group setVariable ["WAIT_Danger_GroupHideLeases",_groupLeases];
    };
    private _mayApply=true;
    if (count _lease >= 3) then {
        _priorStance=_lease param [0,_currentStance,[""]];
        private _previousApplied=_lease param [1,"",[""]];
        // A different owner changed the stance during our response. Drop WAIT's lease and leave it alone.
        if (_currentStance != _previousApplied) then {
            _actor setVariable ["WAIT_Danger_EngineStanceLease",nil];
            _mayApply=false;
        };
    };
    if (_mayApply) then {
        // Weak stance is deliberate: native combat AI and the active movement owner can override it
        // immediately. WAIT records the exact applied value only so cleanup remains generation-safe.
        _actor setUnitPosWeak _desiredStance;
        _actor setVariable ["WAIT_Danger_EngineStanceLease",[_priorStance,_desiredStance,time+_delay]];
    };
};

private _stats=_group getVariable ["WAIT_Danger_EngineStats",createHashMap];
private _modes=_stats getOrDefault ["modes",createHashMap];
_modes set [_mode,((_modes getOrDefault [_mode,0])+1) min 100000];
_stats set ["modes",_modes];
_stats set ["lastMode",_mode];
_stats set ["lastActor",_actor];
_stats set ["lastActionAt",time];
if (_mode == "VEHICLE") then {
    // Preserve the domain distinction at the engine boundary. The FSM still owns no movement:
    // group, vehicle, aircraft and support controllers consume the matching bounded handoff.
    _stats set ["lastVehicleProfile",[_actor] call WAIT_fnc_DangerVehicleProfile];
};
_group setVariable ["WAIT_Danger_EngineStats",_stats];
_actor setVariable ["WAIT_Danger_EngineResponse",[_mode,_cause,time,time+_delay]];
_delay

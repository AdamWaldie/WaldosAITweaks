/*
 * Author: WaldoTheWarfighter
 * Purpose: Convert one bounded engine danger queue into WAIT group danger observations.
 * Locality / Authority: Runs unscheduled on the machine local to the affected AI soldier. It records
 * causes and approximate positions only; it never reveals, targets, moves or changes the actor.
 * Repeat/JIP: Safe to repeat. A valid first observation may bootstrap the group's single tactical
 * brain before the periodic discovery sweep reaches it. DangerRequest then coalesces each cause and
 * generation on the current group owner. A locality change ends the old engine FSM and fresh engine
 * danger starts on the new owner.
 * Arguments: 0: affected soldier <OBJECT>, objNull; 1: engine records <ARRAY>, each
 * [cause number, ATL/ASL position, expiry number, source object], [].
 * Return Value: Boolean - true when at least one valid record was processed for a local reflex or
 * group handoff. Reflex-only records do not start the group brain.
 * Current callers: Engine-loaded infantry danger FSM.
 * Example: [cursorObject,[[2,getPosATL cursorObject,time + 1,objNull]]] call WAIT_fnc_DangerEngineSubmit;
 */

params [['_actor',objNull,[objNull]],['_records',[],[[]]]];
if (isNull _actor || {!local _actor} || {!alive _actor} || {isPlayer _actor}) exitWith {false};
private _group=group _actor;
if (isNull _group || {!local _group}
    || {!(missionNamespace getVariable ['WAIT_AIPass_Active',false])}
    || {!([_group,'WAIT_AIPass_Danger_Enable',true] call WAIT_fnc_CortexFeatureEnabled)}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[] call WAIT_fnc_CortexIsPaused}) exitWith {false};

private _causeNames=['DETECTED','GUNFIRE','HIT','DETECTED','EXPLOSION','CASUALTY','CASUALTY','SCREAM','DETECTED','SUPPRESSED'];
private _latest=createHashMap;
private _processed=false;
private _reflexOnly=0;
{
    if (_x isEqualType [] && {count _x >= 3}) then {
        private _cause=_x param [0,-1,[0]];
        private _position=_x param [1,[],[[]]];
        private _expires=_x param [2,time,[0]];
        if (_cause >= 0 && {_cause < count _causeNames} && {count _position >= 2} && {_expires >= time - 0.25}) then {
            _processed=true;
            if (count _position == 2) then {_position pushBack ((getPosATL _actor) select 2)};
            private _source=_x param [3,objNull,[objNull]];
            private _knownFriendly=!isNull _source && {(side _group) getFriend (side group _source) >= 0.6};
            private _hostileEngage=_cause in [0,3,8]
                && {!isNull _source} && {alive _source}
                && {(side _group) getFriend (side group _source) < 0.6};
            // Immediate hazards remain a local reflex even when a friendly weapon caused them, but
            // they may not manufacture group contact. Engage causes require a confirmed hostile.
            private _groupRelevant=if (_cause in [0,3,8]) then {_hostileEngage} else {!_knownFriendly || {_cause in [5,7]}};
            if (count _position == 3 && {_groupRelevant}) then {
                _latest set [_causeNames select _cause,+_position];
            } else {
                _reflexOnly=_reflexOnly+1;
            };
        };
    };
} forEach (_records select [0,12]);

// A reflex-only record must not start a persistent group brain. Bootstrap the existing tactical
// owner only when at least one observation is relevant to group combat planning.
private _bootstrapped=false;
if (count _latest > 0 && {!(_group getVariable ['WAIT_AIPass_Managed',false])}
    && {[_group,false,true] call WAIT_fnc_CortexIsEligible}) then {
    _bootstrapped=[_group,true] call WAIT_fnc_GroupBrainStart;
};
private _groupReady=_group getVariable ['WAIT_AIPass_Managed',false];
private _accepted=false;
private _acceptedCauses=[];
if (_groupReady) then {
    {
        if ([_actor,_x,_latest get _x] call WAIT_fnc_DangerRequest) then {
            _accepted=true;
            _acceptedCauses pushBack _x;
        };
    } forEach (keys _latest);
};
if (_processed) then {
    private _stats=_group getVariable ['WAIT_Danger_EngineStats',createHashMap];
    _stats set ['submissions',((_stats getOrDefault ['submissions',0])+1) min 100000];
    _stats set ['acceptedRecords',((_stats getOrDefault ['acceptedRecords',0])+count _acceptedCauses) min 100000];
    _stats set ['reflexOnlyRecords',((_stats getOrDefault ['reflexOnlyRecords',0])+_reflexOnly) min 100000];
    _stats set ['lastCauses',+_acceptedCauses];
    _stats set ['lastAt',time];
    if (_bootstrapped) then {
        _stats set ['bootstraps',((_stats getOrDefault ['bootstraps',0])+1) min 100000];
    };
    _group setVariable ['WAIT_Danger_EngineStats',_stats];
};
if (_accepted) then {
    private _count=_group getVariable ['WAIT_Danger_EngineEvents',0];
    _group setVariable ['WAIT_Danger_EngineEvents',(_count + 1) min 100000];
    _group setVariable ['WAIT_Danger_EngineLastAt',time];
};
// The engine FSM may still execute the selected local reflex when no group observation was
// submitted. Returning false here would turn known-friendly near fire into RELEASE and suppress
// even that physical reaction.
_processed

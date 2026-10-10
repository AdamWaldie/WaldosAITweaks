/*
 * Author: WaldoTheWarfighter
 * Purpose: Convert one bounded engine danger queue into WAIT group danger observations.
 * Locality / Authority: Runs unscheduled on the machine local to the affected AI soldier. It records
 * causes and approximate positions only; it never reveals, targets, moves or changes the actor.
 * Repeat/JIP: Safe to repeat. A valid first observation may install the group's bounded contact
 * observer and bootstrap its single tactical brain before the periodic discovery sweep reaches it.
 * DangerRequest then coalesces each cause and generation on the current group owner. A locality
 * change ends the old engine FSM and fresh engine danger starts on the new owner.
 * Arguments: 0: affected soldier <OBJECT>, objNull; 1: engine records <ARRAY>, each
 * [cause number, ATL/ASL position, expiry number, source object], []; 2: selected response mode
 * <STRING>, ASSESS. FORCED records remain local observations and RELEASE records are discarded
 * before group planning.
 * Return Value: Boolean - true when at least one valid record was processed for a local reflex or
 * group handoff. Reflex-only records do not start the group brain.
 * Current callers: Engine-loaded infantry danger FSM.
 * Example: [cursorObject,[[2,getPosATL cursorObject,time + 1,objNull]],"IMMEDIATE"] call WAIT_fnc_DangerEngineSubmit;
 */

params [['_actor',objNull,[objNull]],['_records',[],[[]]],['_mode','ASSESS',['']]];
if (isNull _actor || {!local _actor} || {!alive _actor} || {isPlayer _actor}) exitWith {false};
private _group=group _actor;
if (isNull _group || {!local _group}
    || {!(missionNamespace getVariable ['WAIT_AIPass_Active',false])}
    || {!([_group,'WAIT_AIPass_Danger_Enable',true] call WAIT_fnc_CortexFeatureEnabled)}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[] call WAIT_fnc_CortexIsPaused}) exitWith {false};

// Preserve the engine distinction between losing a member of this group and finding another body.
// Both are bounded alerts, but only the former may carry squad-casualty priority downstream.
private _causeNames=['DETECTED','GUNFIRE','HIT','PROXIMITY','EXPLOSION','CASUALTY','BODY_FOUND','SCREAM','CANFIRE','SUPPRESSED','ASSESS'];
private _latest=createHashMap;
private _latestSource=createHashMap;
private _latestExpiry=createHashMap;
private _latestSourceExpiry=createHashMap;
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
            private _knownFriendly=!isNull _source && {(side _group) getFriend (side _source) >= 0.6};
            private _hostileSource=!isNull _source && {alive _source}
                && {(side _group) getFriend (side _source) < 0.6};
            private _hostileEngage=_cause in [0,3,8] && {_hostileSource};
            // Discovering a friendly body from another group is still an alert; native cause 6
            // must not be discarded merely because that casualty shares the observer's side.
            // Immediate hazards remain a local reflex even when a friendly weapon caused them, but
            // they may not manufacture group contact. Engage causes require a confirmed hostile.
            // The engine FSM has already classified concrete boarding, treatment, supply, action
            // and join tasks as FORCED. Keep their danger evidence actor-local: publishing even a
            // transient group record can wake CONTACT before the later group step clears it.
            private _groupRelevant=if (_mode in ['FORCED','RELEASE'] || {_cause == 10}) then {false} else {
                if (_cause in [0,3,8]) then {_hostileEngage} else {!_knownFriendly || {_cause in [5,6,7]}}
            };
            if (count _position == 3 && {_groupRelevant}) then {
                private _causeName=_causeNames select _cause;
                // The engine supplies the current record before its queued records. Select by
                // expiry rather than iteration order so an older queued duplicate cannot replace
                // the freshest geometry or erase a valid hostile identity during dense contact.
                if (_expires >= (_latestExpiry getOrDefault [_causeName,-1])) then {
                    _latest set [_causeName,+_position];
                    _latestExpiry set [_causeName,_expires];
                    if (!(_causeName in _latestSource)) then {_latestSource set [_causeName,objNull]};
                };
                // Identity and geometry have independent freshness. A newer approximate record
                // may have no source, while a slightly older record in the same bounded queue has
                // a live hostile already known by the observer. Retain the freshest valid source.
                if (_hostileSource && {_expires >= (_latestSourceExpiry getOrDefault [_causeName,-1])}) then {
                    _latestSource set [_causeName,_source];
                    _latestSourceExpiry set [_causeName,_expires];
                };
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
    // A native danger callback can be the group's first WAIT contact before the sparse discovery
    // sweep reaches it. Install the same repeat-safe group observer before publishing the brain so
    // later native EnemyDetected transitions retain their real witness and cannot fall into the
    // discovery interval. DangerSetup adds one group handler and never starts a second worker.
    [_group] call WAIT_fnc_DangerSetup;
    _bootstrapped=[_group,true] call WAIT_fnc_GroupBrainStart;
};
private _groupReady=_group getVariable ['WAIT_AIPass_Managed',false];
private _accepted=false;
private _acceptedCauses=[];
if (_groupReady) then {
    {
        if ([_actor,_x,_latest get _x,_latestSource getOrDefault [_x,objNull]] call WAIT_fnc_DangerRequest) then {
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

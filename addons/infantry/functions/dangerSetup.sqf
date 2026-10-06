/*
 * Author: WaldoTheWarfighter
 * Purpose: Maintain repeat-safe, bounded danger observers across one local AI group.
 * Locality / Authority: group-owner local; observers never reveal targets or send movement commands.
 * Repeat/JIP: generation-checked, machine-local event-handler identifiers are retired on membership,
 * leader or locality changes. New owners rebuild only their local observers from fresh observations.
 * Arguments: 0: group <GROUP>, grpNull; 1: cleanup <BOOL>, false.
 * Return Value: Nothing.
 * Current callers: WAIT discovery, locality and shutdown.
 * Example: [_group] call WAIT_fnc_DangerSetup;
 */

params [["_group",grpNull,[grpNull]],["_cleanup",false,[true]]];
if (isNull _group) exitWith {};
private _leader=leader _group;
// Contact affecting a wingman must reach the same finite group assessment as contact affecting the
// leader. Keep the observation set squad-sized and leader-first so this remains event-driven rather
// than becoming a per-unit scheduler on large formations.
private _members=(units _group) select {alive _x && {local _x} && {!isPlayer _x}};
_members=([_leader]+(_members-[_leader])) arrayIntersect ([_leader]+(_members-[_leader]));
_members=_members select {alive _x && {local _x} && {!isPlayer _x}};
_members resize ((count _members) min 12);
// Observer installation follows the same takeover boundary as finite operations. A specialist or
// player-owned member must not leave residual danger handlers attached to the remaining group.
private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;
private _enabled=!_cleanup && {local _group} && {missionNamespace getVariable ["WAIT_AIPass_Active",false]}
    && {[_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {[_group,false,true] call WAIT_fnc_CortexIsEligible}
    && {!_yieldToOwner};
private _tracked=_group getVariable ["WAIT_Danger_Handlers",[]];
private _groupHandlers=_group getVariable ["WAIT_Danger_GroupHandlers",[]];
private _membershipChanged=_tracked isNotEqualTo [] && {(_tracked param [0,[]]) isNotEqualTo _members};
if (_tracked isNotEqualTo [] && {!_enabled || {_membershipChanged}}) then {
    {
        _x params ["_unit","_event","_handler"];
        if (!isNull _unit) then {_unit removeEventHandler [_event,_handler]};
    } forEach (_tracked param [1,[]]);
    _group setVariable ["WAIT_Danger_Handlers",nil]; _tracked=[];
    // Membership churn is normal during casualties, dismounts and recovery. Reinstalling observer
    // handlers must not discard a valid group-level danger response or stop its finite FSM.
    if (!_enabled) then {
        if (local _group && {!_yieldToOwner}) then {[leader _group,"RELEASE"] call WAIT_fnc_DangerReact};
        _group setVariable ["WAIT_Danger_Generation",(_group getVariable ["WAIT_Danger_Generation",0])+1];
        _group setVariable ["WAIT_Danger_Events",nil];
        _group setVariable ["WAIT_Danger_EventCadence",nil];
        _group setVariable ["WAIT_Danger_ObservedContacts",nil];
        _group setVariable ["WAIT_Danger_Response",nil,true];
        _group setVariable ["WAIT_Danger_Action",nil,true];
    };
};
if (!_enabled && {_groupHandlers isNotEqualTo []}) then {
    {_group removeEventHandler _x} forEach _groupHandlers;
    _group setVariable ["WAIT_Danger_GroupHandlers",nil];
    _groupHandlers=[];
};
if (!_enabled) exitWith {};
if (_groupHandlers isEqualTo []) then {
    private _handler=_group addEventHandler ["EnemyDetected",{
        params ["_observingGroup","_target"];
        if (isNull _observingGroup || {!local _observingGroup} || {isNull _target} || {!alive _target}) exitWith {};
        private _observer=leader _observingGroup;
        private _targetGroup=group _target;
        private _friendly=!isNull _targetGroup && {(side _observingGroup) getFriend (side _targetGroup) >= 0.6};
        // EnemyDetected belongs to the group, not necessarily its leader. A covered leader often
        // has no direct knowledge while a wingman has made the native-confirmed sighting. Read a
        // bounded local roster so that event-driven danger still wakes the existing group decision
        // without turning this handler into a squad scan or granting the leader target knowledge.
        private _spotters=(units _observingGroup) select {alive _x && {local _x} && {!isPlayer _x}};
        _spotters resize ((count _spotters) min 12);
        if (isNull _observer || {!local _observer} || {!alive _observer} || {_friendly}
            || {_spotters findIf {_x knowsAbout _target >= 1} < 0}) exitWith {};
        // Keep only a short owner-local record of contacts the engine has already confirmed for
        // this group. CortexKnowledge validates every record against native knowledge before it
        // can affect a decision. It is deliberately not public: this is a local candidate source,
        // not a target-sharing channel or a replacement for normal contact reports.
        private _contacts=_observingGroup getVariable ["WAIT_Danger_ObservedContacts",[]];
        _contacts=_contacts select {
            _x isEqualType [] && {count _x == 2} && {(_x select 0) isEqualType objNull}
                && {alive (_x select 0)} && {(_x select 1) > time}
        };
        private _contactIndex=_contacts findIf {(_x select 0) == _target};
        private _contact=[_target,time+10];
        if (_contactIndex >= 0) then {_contacts set [_contactIndex,_contact]} else {_contacts pushBack _contact};
        if (count _contacts > 8) then {_contacts=_contacts select ((count _contacts)-8)};
        _observingGroup setVariable ["WAIT_Danger_ObservedContacts",_contacts];
        // The engine has already confirmed this contact. Pass only the observer position into
        // the queue: WAIT wakes the existing decision job but does not publish or assign a target.
        [_observer,"DETECTED",getPosATL _observer] call WAIT_fnc_DangerRequest;
    }];
    _groupHandlers=[["EnemyDetected",_handler]];
    _group setVariable ["WAIT_Danger_GroupHandlers",_groupHandlers];
};
if (_tracked isNotEqualTo []) exitWith {};
private _handlers=[];
{
    private _member=_x;
    _handlers pushBack [_member,"Hit",_member addEventHandler ["Hit",{
        params ["_actor"]; [_actor,"HIT",getPosATL _actor] call WAIT_fnc_DangerRequest;
    }]];
    _handlers pushBack [_member,"Explosion",_member addEventHandler ["Explosion",{
        params ["_actor"]; [_actor,"EXPLOSION",getPosATL _actor] call WAIT_fnc_DangerRequest;
    }]];
    _handlers pushBack [_member,"Suppressed",_member addEventHandler ["Suppressed",{
        params ["_actor"]; [_actor,"SUPPRESSED",getPosATL _actor] call WAIT_fnc_DangerRequest;
    }]];
    _handlers pushBack [_member,"FiredNear",_member addEventHandler ["FiredNear",{
        params ["_actor","_firer"];
        if (isNull _firer || {(side group _actor) getFriend (side group _firer) >= 0.6}) exitWith {};
        // No exact source, object identity, reveal or target assignment enters the danger queue.
        [_actor,"GUNFIRE",getPosATL _actor] call WAIT_fnc_DangerRequest;
    }]];
} forEach _members;
_group setVariable ["WAIT_Danger_Handlers",[_members,_handlers]];

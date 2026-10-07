/*
 * Author: WaldoTheWarfighter
 * Purpose: Maintain the bounded group contact observer that complements the engine danger FSM.
 * Locality / Authority: Group-owner local. The engine FSM supplies immediate causes; this observer
 * retains only engine-confirmed target identity without revealing targets or issuing movement.
 * Repeat/JIP: Repeat-safe. Machine-local handler identifiers are removed on disable or locality
 * handover, and the new owner rebuilds the observer from fresh native contact events.
 * Arguments: 0: group <GROUP>, grpNull; 1: cleanup <BOOL>, false.
 * Return Value: Nothing.
 * Current callers: WAIT discovery, locality reconciliation and shutdown.
 * Example: [_group] call WAIT_fnc_DangerSetup;
 */

params [["_group",grpNull,[grpNull]],["_cleanup",false,[true]]];
if (isNull _group) exitWith {};
private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;
private _enabled=!_cleanup && {local _group} && {missionNamespace getVariable ["WAIT_AIPass_Active",false]}
    && {[_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {[_group,false,true] call WAIT_fnc_CortexIsEligible}
    && {!_yieldToOwner};

// Retire handlers from pre-FSM packaged candidates. New builds never install these per-unit event
// handlers, but repeat-safe cleanup prevents a live development reload from keeping two intakes.
private _legacy=_group getVariable ["WAIT_Danger_Handlers",[]];
if (_legacy isNotEqualTo []) then {
    {
        _x params ["_unit","_event","_handler"];
        if (!isNull _unit) then {_unit removeEventHandler [_event,_handler]};
    } forEach (_legacy param [1,[]]);
    _group setVariable ["WAIT_Danger_Handlers",nil];
};

private _groupHandlers=_group getVariable ["WAIT_Danger_GroupHandlers",[]];
if (!_enabled && {_groupHandlers isNotEqualTo []}) then {
    {_group removeEventHandler _x} forEach _groupHandlers;
    _group setVariable ["WAIT_Danger_GroupHandlers",nil];
    _groupHandlers=[];
};
if (!_enabled) exitWith {
    if (local _group && {!_yieldToOwner}) then {
        private _dangerActor=[_group] call WAIT_fnc_CortexGroupAnchor;
        if (isNull _dangerActor) then {_dangerActor=leader _group};
        [_dangerActor,"RELEASE"] call WAIT_fnc_DangerReact;
    };
    _group setVariable ["WAIT_Danger_Generation",(_group getVariable ["WAIT_Danger_Generation",0])+1];
    _group setVariable ["WAIT_Danger_Events",nil];
    _group setVariable ["WAIT_Danger_EventCadence",nil];
    _group setVariable ["WAIT_Danger_ObservedContacts",nil];
    _group setVariable ["WAIT_Danger_Response",nil,true];
    _group setVariable ["WAIT_Danger_Action",nil,true];
};
if (_groupHandlers isNotEqualTo []) exitWith {};

private _handler=_group addEventHandler ["EnemyDetected",{
    params ["_observingGroup","_target"];
    if (isNull _observingGroup || {!local _observingGroup} || {isNull _target} || {!alive _target}) exitWith {};
    private _targetGroup=group _target;
    private _friendly=!isNull _targetGroup && {(side _observingGroup) getFriend (side _targetGroup) >= 0.6};
    private _spotters=(units _observingGroup) select {alive _x && {local _x} && {!isPlayer _x}};
    _spotters resize ((count _spotters) min 12);
    private _leader=leader _observingGroup;
    private _observer=if (!isNull _leader && {alive _leader} && {local _leader}) then {_leader} else {
        _spotters param [0,objNull]
    };
    if (isNull _observer || {_friendly} || {_spotters findIf {_x knowsAbout _target >= 1} < 0}) exitWith {};
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
    [_observer,"DETECTED",getPosATL _observer] call WAIT_fnc_DangerRequest;
}];
_group setVariable ["WAIT_Danger_GroupHandlers",[["EnemyDetected",_handler]]];

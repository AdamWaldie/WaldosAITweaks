/*
 * Author: WaldoTheWarfighter
 * Purpose: Start the packaged WAIT audit and provide an observer curator and HC registry.
 * Locality/authority: Dedicated server. Only audit fixtures are created.
 * Repeat/JIP: One initialization per mission; arriving or respawned observers receive the curator.
 * Arguments: None. Return: Nothing. Current callers: engine mission initialization.
 * Example: Launch WAIT_Audit.VR with the checked-in launcher.
 */
call compile preprocessFileLineNumbers "auditIdentity.sqf";
if (isNil "WAIT_AITweaks_PostInitComplete") exitWith {diag_log "WAIT AUDIT ERROR: addon absent"};
private _spawn=createMarker ["respawn_west",[5800,5800,0]];
_spawn setMarkerType "Empty";
private _logicGroup=createGroup sideLogic;
private _curator=_logicGroup createUnit ["ModuleCurator_F",[5800,5800,0],[],0,"NONE"];
_curator setVariable ["Addons",3,true];
[_curator] spawn {
    params ["_curator"];
    waitUntil {sleep 0.5; (allPlayers select {isPlayer _x && {!(_x isKindOf "HeadlessClient_F")}}) isNotEqualTo []};
    private _observer=(allPlayers select {isPlayer _x && {!(_x isKindOf "HeadlessClient_F")}}) select 0;
    _observer assignCurator _curator;
    _curator addCuratorEditableObjects [allUnits + vehicles,true];
    diag_log "WAIT AUDIT OBSERVER ZEUS READY";
    [] execVM "cortexQAServer.sqf";
    while {!isNull _curator} do {
        sleep 2;
        private _observers=allPlayers select {isPlayer _x && {!(_x isKindOf "HeadlessClient_F")}};
        if (_observers isNotEqualTo []) then {
            private _current=_observers select 0;
            if (getAssignedCuratorLogic _current != _curator) then {
                unassignCurator _curator;
                _current assignCurator _curator;
                diag_log "WAIT AUDIT OBSERVER ZEUS READY";
            };
        };
        _curator addCuratorEditableObjects [allUnits + vehicles,true];
    };
};
[] spawn {
    while {true} do {
        private _hcs=allPlayers select {_x isKindOf "HeadlessClient_F"};
        missionNamespace setVariable ["WAIT_Headless_Clients",_hcs apply {[owner _x,_x]},true];
        sleep 2;
    };
};
// When the mission is hosted alongside WAIT, exercise its real authoritative migration funnel so
// WAIT receives the published adoption revision and destination-local event. The standalone audit
// retains a deliberately labelled engine-only fallback for packaged WAIT-only candidates.
WAIT_fnc_HeadlessMigrateGroup={
    params ["_group","_owner"];
    if (isNull _group || {_owner < 2}) exitWith {false};
    if !(isNil "Waldo_fnc_HeadlessMigrateGroup") exitWith {[_group,_owner] call Waldo_fnc_HeadlessMigrateGroup};
    _group setGroupOwner _owner;
    diag_log format ["[WAIT AUDIT] Engine-only HC transfer group=%1 owner=%2; WAIT migration provider unavailable.",_group,_owner];
    true
};
diag_log "WAIT AUDIT SERVER READY";

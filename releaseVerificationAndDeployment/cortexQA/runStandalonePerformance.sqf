/*
 * Author: WaldoTheWarfighter
 * Purpose: Sample one addon-independent 50-group infantry patrol for matched native/WAIT launches.
 * Locality/authority: Dedicated server owns fixtures and sampling; no WAIT functions are required.
 * Repeat/JIP: One guarded run per mission. Removes its frame handler and all created actors/groups.
 * Arguments: None. Return Value: Nothing; results are written to the server RPT.
 * Current callers: Standalone benchmark mission staging (integration pending).
 * Example: [] execVM "cortexQAStandalonePerformance.sqf";
 */
if (!isServer || {missionNamespace getVariable ["WAIT_QA_StandalonePerfRunning",false]}) exitWith {};
missionNamespace setVariable ["WAIT_QA_StandalonePerfRunning",true];
private _loaded=isClass (configFile >> "CfgPatches" >> "WAIT_AI_Tweaks_Main");
private _fsm=getText (configFile >> "CfgVehicles" >> "O_Soldier_F" >> "fsmDanger");
private _groups=[];
private _actors=[];
for "_i" from 0 to 49 do {
    private _group=createGroup [east,true];
    // Identical ownership exclusions in both launches; no automatic HC provider may redistribute.
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    private _origin=[800+(_i mod 10)*35,800+floor (_i/10)*35,0];
    for "_j" from 0 to 5 do {
        private _actor=_group createUnit ["O_Soldier_F",_origin vectorAdd [(_j mod 3)*2,floor (_j/3)*2,0],[],0,"NONE"];
        _actor setVariable ["acex_headless_blacklist",true,true];
        _actors pushBack _actor;
    };
    _group setBehaviour "AWARE";
    _group setCombatMode "BLUE";
    private _waypoint=_group addWaypoint [_origin vectorAdd [0,2000,0],0];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointSpeed "NORMAL";
    _group setCurrentWaypoint _waypoint;
    _groups pushBack _group;
    sleep 0.01;
};
diag_log format ["WAIT STANDALONE PERF IDENTITY: %1",[_loaded,_fsm,50,300,"INFANTRY_PATROL",groupOwner (_groups select 0)]];
sleep 20;
private _origins=_groups apply {getPosATL leader _x};
missionNamespace setVariable ["WAIT_QA_StandaloneSamples",[]];
private _handler=addMissionEventHandler ["EachFrame",{
    private _samples=missionNamespace getVariable ["WAIT_QA_StandaloneSamples",[]];
    if (count _samples < 120000) then {_samples pushBack (diag_deltaTime*1000)};
}];
sleep 60;
removeMissionEventHandler ["EachFrame",_handler];
private _samples=+(missionNamespace getVariable ["WAIT_QA_StandaloneSamples",[]]);
_samples sort true;
private _quantile={
    params ["_fraction"];
    if (_samples isEqualTo []) exitWith {-1};
    _samples select ((floor (((count _samples)-1)*_fraction)) max 0)
};
private _moving=0;
private _alive=0;
private _owned=0;
{
    if (leader _x distance2D (_origins select _forEachIndex) >= 30) then {_moving=_moving+1};
    _alive=_alive+({alive _x} count units _x);
    if (groupOwner _x == 2) then {_owned=_owned+1};
} forEach _groups;
private _valid=count _samples >= 100 && {_moving == 50} && {_alive == 300} && {_owned == 50};
diag_log format ["WAIT STANDALONE PERF RESULT: %1",[_loaded,_valid,count _samples,
    [0.5] call _quantile,[0.95] call _quantile,[0.99] call _quantile,_moving,_alive,_owned]];
{deleteVehicle _x} forEach _actors;
{deleteGroup _x} forEach _groups;
missionNamespace setVariable ["WAIT_QA_StandaloneSamples",nil];
missionNamespace setVariable ["WAIT_QA_StandalonePerfCompleted",true,true];
diag_log "WAIT STANDALONE PERF COMPLETE";

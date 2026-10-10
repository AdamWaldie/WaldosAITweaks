/*
 * Author: WaldoTheWarfighter
 * Purpose: Sample one addon-independent 50-group infantry or mixed patrol for matched native/WAIT launches.
 * Locality/authority: Dedicated server owns fixtures and sampling; no WAIT functions are required.
 * Repeat/JIP: One guarded run per mission. Removes its frame handler and all created actors/groups.
 * Arguments: None. Return Value: Nothing; results are written to the server RPT.
 * Current callers: Standalone performance mission initServer.sqf.
 * Example: [] execVM "cortexQAStandalonePerformance.sqf";
 */
if (!isServer || {missionNamespace getVariable ["WAIT_QA_StandalonePerfRunning",false]}) exitWith {};
missionNamespace setVariable ["WAIT_QA_StandalonePerfRunning",true];
private _loaded=isClass (configFile >> "CfgPatches" >> "WAIT_AI_Tweaks_Main");
private _expectedLoaded=missionNamespace getVariable ["WAIT_QA_PerfExpectedLoaded",_loaded];
if (_loaded != _expectedLoaded) exitWith {diag_log "WAIT STANDALONE PERF INVALID: addon identity mismatch"};
private _fsm=getText (configFile >> "CfgVehicles" >> "O_Soldier_F" >> "fsmDanger");
private _composition=missionNamespace getVariable ["WAIT_QA_PerfComposition","infantry"];
if (!(_composition in ["infantry","mixed"])) exitWith {diag_log "WAIT STANDALONE PERF INVALID: composition"};
private _vehicles=[];
private _fixtureValid=true;
private _groups=[];
private _actors=[];
for "_i" from 0 to 49 do {
    private _group=createGroup [east,true];
    // Identical ownership exclusions in both launches; no automatic HC provider may redistribute.
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    private _origin=[800+(_i mod 10)*35,800+floor (_i/10)*35,0];
    private _legLength=2000;
    if (_composition == "infantry" || {_i < 25}) then {
        for "_j" from 0 to 5 do {
            private _actor=_group createUnit ["O_Soldier_F",_origin vectorAdd [(_j mod 3)*2,floor (_j/3)*2,0],[],0,"NONE"];
            _actor setVariable ["acex_headless_blacklist",true,true];
            _actors pushBack _actor;
        };
    } else {
        private _air=_i >= 40;
        private _plane=_i >= 45;
        private _class=if (_plane) then {"O_Plane_CAS_02_dynamicLoadout_F"} else {
            if (_air) then {"O_Heli_Attack_02_dynamicLoadout_F"} else {
                ["O_MRAP_02_hmg_F","O_APC_Tracked_02_cannon_F"] select (_i mod 2)
            }
        };
        _origin=[2500+(_i-25)*500,800,[0,300] select _air];
        private _vehicle=createVehicle [_class,_origin,[],0,["NONE","FLY"] select _air];
        _vehicle setDir 0;
        _vehicle enableSimulationGlobal true;
        private _seats=(fullCrew [_vehicle,"",true]) select {
            (_x select 1) != "cargo" && {!(_x select 4)}
        };
        {
            _x params ["_occupant","_role","_cargoIndex","_turret"];
            private _actor=_group createUnit [["O_crew_F","O_Pilot_F"] select _air,_origin,[],0,"NONE"];
            _actor setVariable ["acex_headless_blacklist",true,true];
            if (_role == "driver") then {_actor moveInDriver _vehicle} else {_actor moveInTurret [_vehicle,_turret]};
            _fixtureValid=_fixtureValid && {objectParent _actor == _vehicle};
            _actors pushBack _actor;
        } forEach (_seats select [0,3]);
        _fixtureValid=_fixtureValid && {!isNull driver _vehicle} && {simulationEnabled _vehicle};
        if (_air) then {
            _vehicle engineOn true;
            _vehicle flyInHeight 300;
            _vehicle setVelocity [0,[55,150] select _plane,0];
            _legLength=20000;
        };
        _vehicles pushBack _vehicle;
    };
    _group setBehaviour "AWARE";
    _group setCombatMode "BLUE";
    private _waypoint=_group addWaypoint [_origin vectorAdd [0,_legLength,0],0];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointSpeed "NORMAL";
    _group setCurrentWaypoint _waypoint;
    _groups pushBack _group;
    sleep 0.01;
};
{_x addCuratorEditableObjects [_actors+_vehicles,true]} forEach allCurators;
private _expectedActors=count _actors;
private _scenario=["INFANTRY_PATROL","MIXED_PATROL"] select (_composition == "mixed");
diag_log format ["WAIT STANDALONE PERF IDENTITY: %1",[_loaded,_fsm,50,_expectedActors,_scenario,groupOwner (_groups select 0)]];
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
private _observers=allPlayers select {!(_x isKindOf "HeadlessClient_F")};
private _observerValid=count _observers == 1 && {alive (_observers select 0)};
private _valid=_fixtureValid && {_vehicles findIf {!alive _x || {!simulationEnabled _x}} < 0} && {_observerValid} && {count _samples >= 100} && {_moving == 50} && {_alive == _expectedActors} && {_owned == 50};
diag_log format ["WAIT STANDALONE PERF RESULT: %1",[_loaded,_valid,count _samples,
    [0.5] call _quantile,[0.95] call _quantile,[0.99] call _quantile,_moving,_alive,_owned,count _observers,_observerValid]];
{deleteVehicle _x} forEach _actors;
{deleteGroup _x} forEach _groups;
{deleteVehicle _x} forEach _vehicles;
missionNamespace setVariable ["WAIT_QA_StandaloneSamples",nil];
missionNamespace setVariable ["WAIT_QA_StandalonePerfCompleted",true,true];
diag_log "WAIT STANDALONE PERF COMPLETE";

/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe production ordinary driving around an empty parked hull and a wreck,
 * then physically board a blocker during an active bypass and require invalidation.
 * Locality/authority: scheduled server-only normal batch. Creates disposable native MOVE
 * fixtures; WAIT discovery and its real operation FSM own all follower movement.
 * Repeat/JIP: fresh actors per case; restores tuning, deletes crews/vehicles/groups and
 * clears public observer labels. No owner migration or historical command replay.
 * Arguments: 0 check <CODE>; 1 phase <CODE>; 2 wait <CODE>, required audit callbacks.
 * Return: Nothing. No test-side bypass start, path, result, transform or completion writes.
 * Current caller: runServer.sqf parkedbypass/vehicles/full normal focus.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAParkedBypass.sqf";
 */
params ["_check","_phase","_wait"];
if (!isServer || {missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false]}) exitWith {};
private _previous=createHashMapFromArray [
    ["WAIT_AIPass_Enable",missionNamespace getVariable ["WAIT_AIPass_Enable",true]],
    ["WAIT_AIPass_Contact_Enable",missionNamespace getVariable ["WAIT_AIPass_Contact_Enable",true]],
    ["WAIT_AIPass_DrivingAssist_Enable",missionNamespace getVariable ["WAIT_AIPass_DrivingAssist_Enable",true]],
    ["WAIT_AIPass_DrivingAssist_Recovery_Enable",missionNamespace getVariable ["WAIT_AIPass_DrivingAssist_Recovery_Enable",true]]
];
[createHashMapFromArray [["WAIT_AIPass_Enable",true],["WAIT_AIPass_Contact_Enable",false],
    ["WAIT_AIPass_DrivingAssist_Enable",true],["WAIT_AIPass_DrivingAssist_Recovery_Enable",true]]] call WAIT_fnc_CortexTuning;
private _northBounds={
    params ["_object"];
    private _bounds=boundingBoxReal _object;private _low=_bounds select 0;private _high=_bounds select 1;
    private _minimum=1e9;private _maximum=-1e9;
    {private _xx=_x;{private _yy=_x;{
        private _point=_object modelToWorldWorld [_xx,_yy,_x];
        _minimum=_minimum min (_point select 1);_maximum=_maximum max (_point select 1);
    } forEach [_low select 2,_high select 2];} forEach [_low select 1,_high select 1];} forEach [_low select 0,_high select 0];
    [_minimum,_maximum]
};
{
    private _mode=_x;private _lane=6500+_forEachIndex*250;
    private _start=[_lane,3500,0];private _destination=[_lane,3950,0];
    private _vehicle=createVehicle ["O_Truck_03_transport_F",_start,[],0,"NONE"];
    private _blocker=createVehicle ["B_MRAP_01_F",[_lane,3620,0],[],0,"NONE"];
    _vehicle setDir 0;_blocker setDir 90;
    if (_mode == "WRECK") then {_blocker setDamage 1};
    createVehicleCrew _vehicle;
    private _group=group driver _vehicle;
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setBehaviour "SAFE";_group setCombatMode "BLUE";_group setSpeedMode "FULL";
    private _boardingGroup=createGroup [east,true];
    _boardingGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _boardingGroup setVariable ["acex_headless_blacklist",true,true];
    _boardingGroup setVariable ["WAIT_AIPass_Exclude",true,true];
    _boardingGroup setBehaviour "CARELESS";_boardingGroup setCombatMode "BLUE";
    private _wp=_group addWaypoint [_destination,0];_wp setWaypointType "MOVE";_wp setWaypointCompletionRadius 5;
    _group setCurrentWaypoint _wp;
    (driver _vehicle) setVariable ["WAIT_CortexQA_Label","PARKED BYPASS "+_mode,true];
    (driver _vehicle) setVariable ["WAIT_CortexQA_Target",_destination,true];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[_vehicle,_blocker,driver _vehicle],true];
    ["Ordinary bypass: "+_mode,"The truck must use production discovery and physically pass the parked hull with lateral clearance and no damage. In OCCUPIED, a native boarding order starts only after real bypass work exists; crew entry must invalidate it. No bypass path or result is injected.",getPosATL _blocker] call _phase;
    private _ready=!isNull driver _vehicle && {local _vehicle} && {local _group}
        && {simulationEnabled _vehicle} && {simulationEnabled _blocker}
        && {!surfaceIsWater _start} && {!surfaceIsWater getPosATL _blocker}
        && {crew _blocker isEqualTo []} && {!isEngineOn _blocker};
    ["DRIVING-parked-"+_mode+"-fixture",_ready] call _check;
    private _damage=[damage _vehicle,damage _blocker];
    private _active=false;private _clear=true;private _lateral=0;private _tail=false;
    private _boardingStarted=false;private _boarded=false;private _boarder=objNull;
    private _invalidated=false;private _passed=false;private _until=time+150;
    while {time < _until && {!_passed} && {!_invalidated}} do {
        sleep 0.5;
        private _work=_vehicle getVariable ["WAIT_DrivingBypass_Work",createHashMap];
        private _result=_vehicle getVariable ["WAIT_DrivingBypass_Result",[]];
        private _thisActive=count _work > 0 && {(_work getOrDefault ["obstacle",objNull]) == _blocker};
        if (_thisActive) then {_active=true};
        if (_mode == "OCCUPIED" && {_thisActive} && {!_boardingStarted}) then {
            _boardingStarted=true;
            _boarder=_boardingGroup createUnit ["O_Soldier_F",_blocker modelToWorld [-3,0,0],[],0,"NONE"];
            _boarder assignAsDriver _blocker;[_boarder] orderGetIn true;
        };
        if (!isNull _boarder && {vehicle _boarder == _blocker} && {alive _boarder}) then {_boarded=true};
        _lateral=_lateral max abs (((getPosASL _vehicle) select 0)-_lane);
        private _ownBounds=[_vehicle] call _northBounds;private _blockBounds=[_blocker] call _northBounds;
        if ((_ownBounds select 0) > (_blockBounds select 1)+5) then {_tail=true};
        if (damage _vehicle > (_damage select 0)+0.01 || {damage _blocker > (_damage select 1)+0.01}) then {_clear=false};
        _passed=_mode != "OCCUPIED" && {_active} && {_tail} && {_lateral >= 3}
            && {_vehicle distance2D _start >= 140} && {(_result param [0,""]) == "PHYSICALLY_PASSED"}
            && {(_result param [2,objNull]) == _blocker};
        _invalidated=_mode == "OCCUPIED" && {_active} && {_boarded} && {count _work == 0}
            && {(_result param [0,""]) == "OBSTACLE_CHANGED"} && {(_result param [2,objNull]) == _blocker};
        diag_log format ["WAIT PARKED BYPASS: mode=%1 t=%2 position=%3 speed=%4 active=%5 lateral=%6 tail=%7 clear=%8 boarded=%9 result=%10",
            _mode,time,getPosASL _vehicle,speed _vehicle,_thisActive,_lateral,_tail,_clear,_boarded,_result];
    };
    ["DRIVING-parked-"+_mode+"-production-bypass-started",_ready && {_active}] call _check;
    if (_mode == "OCCUPIED") then {
        ["DRIVING-parked-occupied-native-boarding",_active && {_boardingStarted} && {_boarded}] call _check;
        ["DRIVING-parked-occupied-work-invalidated",_ready && {_boarded} && {_invalidated} && {_clear}] call _check;
    } else {
        ["DRIVING-parked-"+_mode+"-actual-full-hull-passage",_ready && {_passed} && {_clear},str [_lateral,_tail,getPosASL _vehicle]] call _check;
    };
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
    {private _object=_x;{deleteVehicle _x} forEach crew _object;deleteVehicle _object} forEach [_vehicle,_blocker];
    {deleteVehicle _x} forEach units _boardingGroup;
    {deleteGroup _x} forEach [_group,_boardingGroup];
} forEach ["EMPTY","WRECK","OCCUPIED"];
[_previous] call WAIT_fnc_CortexTuning;

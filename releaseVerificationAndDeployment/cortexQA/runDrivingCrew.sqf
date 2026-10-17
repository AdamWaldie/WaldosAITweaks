/*
 * Author: WaldoTheWarfighter
 * Purpose: Prepares real ordinary-driver casualty/replacement and protected-seat comparisons.
 * Locality / Authority: Scheduled server, normal batch only. Initial mounting, casualty,
 * unconsciousness, lock, assignment and explicit STOP are fixture inputs. No production callbacks, completion
 * state, replacement seat actions or post-casualty relocation are injected by the test.
 * Repeat/JIP: Fresh disposable actors per case; tuning restored, explicit corpse/crew cleanup.
 * Observer labels replicate; this fixture does not transfer groups to headless clients.
 * Arguments: 0 check <CODE, required>; 1 phase <CODE, required>; 2 wait <CODE, required>.
 * Return Value: Nothing. Every result remains unrun until a fresh authorized normal audit.
 * Current callers: runServer.sqf normal vehicles/full or focused drivercrew batch.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQADrivingCrew.sqf";
 */
params ["_check","_phase","_wait"];
if (!isServer || {missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false]}) exitWith {};
private _settings=["WAIT_AIPass_Enable","WAIT_AIPass_Contact_Enable","WAIT_AIPass_DrivingAssist_Enable","WAIT_AIPass_DrivingAssist_Recovery_Enable"];
private _previous=createHashMapFromArray (_settings apply {[_x,missionNamespace getVariable [_x,true]]});
[createHashMapFromArray [["WAIT_AIPass_Enable",true],["WAIT_AIPass_Contact_Enable",false],
    ["WAIT_AIPass_DrivingAssist_Enable",true],["WAIT_AIPass_DrivingAssist_Recovery_Enable",true]]] call WAIT_fnc_CortexTuning;
{
    private _kind=_x;
    private _start=[4400+_forEachIndex*200,2150,0];
    private _destination=_start vectorAdd [0,350,0];
    private _vehicle=createVehicle ["O_MRAP_02_F",_start,[],0,"NONE"];
    _vehicle setDir 0;createVehicleCrew _vehicle;_vehicle forceSpeed 0;
    private _driver=driver _vehicle;private _group=group _driver;
    _group setVariable ["WAIT_AIPass_Exclude",true,true];
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setBehaviour "SAFE";_group setCombatMode "BLUE";_group setSpeedMode "FULL";
    private _replacement=_group createUnit ["O_Soldier_F",_start vectorAdd [5,0,0],[],0,"NONE"];
    // Initial mounting only, before the casualty and production admission.
    _replacement moveInCargo _vehicle;_group selectLeader _replacement;
    private _incoming=objNull;private _incomingGroup=grpNull;
    if (_kind == "ASSIGNED") then {
        _incomingGroup=createGroup [east,true];
        _incomingGroup setVariable ["WAIT_AIPass_Exclude",true,true];
        _incomingGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
        _incomingGroup setVariable ["acex_headless_blacklist",true,true];
        _incoming=_incomingGroup createUnit ["O_Soldier_F",_start vectorAdd [30,0,0],[],0,"NONE"];
        _incoming assignAsDriver _vehicle;
    };
    if (_kind == "LOCKED") then {_vehicle lockDriver true};
    private _waypoint=_group addWaypoint [_destination,0];
    _waypoint setWaypointType "MOVE";_waypoint setWaypointCompletionRadius 5;
    _group setCurrentWaypoint _waypoint;
    private _ready=!isNull _driver && {vehicle _replacement == _vehicle} && {local _group} && {local _vehicle}
        && {local _replacement} && {canMove _vehicle} && {simulationEnabled _vehicle}
        && {!surfaceIsWater getPosATL _vehicle} && {vehicle leader _group == _vehicle};
    _replacement setVariable ["WAIT_CortexQA_Label","DRIVER HANDOVER "+_kind+": ACTUAL SEAT / ROUTE",true];
    _replacement setVariable ["WAIT_CortexQA_Target",_destination,true];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[_vehicle,_driver,_replacement,_incoming],true];
    ["Ordinary driver handover: "+_kind,
        if (_kind == "REPLACE") then {"The original driver dies. WAIT must remove the corpse using its own native action, move mounted crew into the confirmed free driver seat, and physically resume this route. The fixture never seats the replacement or calls the production executor."}
        else {"Protected comparison: the living unconscious driver, locked seat, incoming driver assignment or explicit STOP must prevent the mounted replacement from taking the seat. Original fixture intent must remain intact."},_start] call _phase;
    ["DRIVING-crew-"+_kind+"-fixture",_ready] call _check;
    if (_kind == "UNCONSCIOUS") then {_driver setUnconscious true} else {_driver setDamage 1};
    private _damaged=damage _vehicle;private _routeStart=getPosATL _vehicle;
    if (_kind == "STOP") then {doStop _replacement};
    _vehicle forceSpeed -1;
    _group setVariable ["WAIT_AIPass_Exclude",false,true];
    if (_kind == "REPLACE") then {
        private _seated=[{driver _vehicle == _replacement && {alive _replacement} && {vehicle _driver != _vehicle}
            && {(_vehicle getVariable ["WAIT_DrivingCrew_Work",createHashMap]) getOrDefault ["phase",""] == "COMPLETE"}},40] call _wait;
        ["DRIVING-crew-actual-replacement",_ready && {_seated},str [driver _vehicle,_replacement,_vehicle getVariable ["WAIT_DrivingCrew_Work",createHashMap]]] call _check;
        _routeStart=getPosATL _vehicle;
        private _moved=if (_seated) then {
            [{driver _vehicle == _replacement && {_vehicle distance2D _routeStart >= 35} && {speed _vehicle > 3}
                && {(_vehicle distance2D _destination) < (_routeStart distance2D _destination)-30}},60] call _wait
        } else {false};
        ["DRIVING-crew-replacement-physical-route",_ready && {_seated} && {_moved}
            && {alive _vehicle} && {damage _vehicle <= _damaged+0.01},str [getPosATL _vehicle,speed _vehicle,damage _vehicle]] call _check;
    } else {
        private _preserved=true;
        for "_sample" from 1 to 64 do {
            sleep 0.5;
            private _work=_vehicle getVariable ["WAIT_DrivingCrew_Work",createHashMap];
            if (driver _vehicle == _replacement || {(_work getOrDefault ["phase",""]) in ["VACATING","SWITCHING","COMPLETE"]}) then {_preserved=false};
            if (_kind == "UNCONSCIOUS" && {!alive _driver || {driver _vehicle != _driver}}) then {_preserved=false};
            if (_kind == "LOCKED" && {!lockedDriver _vehicle}) then {_preserved=false};
            if (_kind == "STOP" && {currentCommand _replacement != "STOP"}) then {_preserved=false};
            if (_kind == "ASSIGNED" && {assignedVehicle _incoming != _vehicle
                || {(assignedVehicleRole _incoming param [0,""]) != "driver"}}) then {_preserved=false};
            if (_sample mod 2 == 0) then {
                diag_log format ["WAIT DRIVING CREW SAMPLE: case=%1 t=%2 driver=%3 replacement=%4 work=%5 incoming=%6",
                    _kind,time,driver _vehicle,_replacement,_work,assignedVehicleRole _incoming];
            };
        };
        ["DRIVING-crew-"+_kind+"-intent-preserved",_ready && {_preserved},str [_kind,driver _vehicle,assignedVehicleRole _incoming]] call _check;
    };
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
    private _cleanup=(crew _vehicle)+[_driver,_replacement,_incoming];
    {if (!isNull _x) then {deleteVehicle _x}} forEach (_cleanup arrayIntersect _cleanup);
    deleteVehicle _vehicle;deleteGroup _group;
    if (!isNull _incomingGroup) then {deleteGroup _incomingGroup};
} forEach ["REPLACE","UNCONSCIOUS","LOCKED","ASSIGNED","STOP"];
[_previous] call WAIT_fnc_CortexTuning;

/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe natural automatic road passing and native waypoint replacement on Altis.
 * Locality/authority: Scheduled server, normal batch only. Native MOVE waypoints and a slow
 * predecessor's authored speed cap are fixture inputs. Production discovery/admission/FSMs
 * own all passer movement; no pass helper, fixed path, success state or AI relocation is injected.
 * Repeat/JIP: Fresh groups/vehicles for PASS and REPLACE; tuning restored and actors deleted.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>, required audit callbacks.
 * Return: Nothing. Layout search is bounded to eight centres, eight roads/two directions,
 * 64 transitions and 16 connections per piece, with a 90-second setup deadline.
 * Physical samples project eight corners of each hull every 0.25 seconds for <=150 s/case.
 * This is a behaviour diagnostic, not a matched performance measurement or HC acceptance.
 * Current caller: runServer.sqf roadpassing focus; stage requires Altis and normal ownership.
 * Example: stage the roadpassing focus with world Altis; run only when audits are authorised.
 */
params ["_check","_phase","_wait"];
private _terrain=worldName == "Altis" && {isServer} && {!(missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false])};
["PASS-road-normal-Altis-prerequisite",_terrain] call _check;
if (!_terrain) exitWith {};
private _searchUntil=diag_tickTime+90;
private _walk={
    params ["_road","_reverse"];
    private _info=getRoadInfo _road;
    private _begin=_info param [6,[],[[]]];private _end=_info param [7,[],[[]]];
    if (count _begin != 3 || {count _end != 3}) exitWith {[]};
    private _heading=(_begin getDir _end)+([0,180] select _reverse);private _initial=_heading;
    private _points=[(_begin vectorAdd _end) vectorMultiply 0.5];
    private _visited=[];private _previous=objNull;private _travel=0;private _valid=true;
    for "_index" from 0 to 63 do {
        if (isNull _road || {_road in _visited} || {diag_tickTime >= _searchUntil}) exitWith {_valid=false};
        _visited pushBack _road;_info=getRoadInfo _road;
        _begin=_info param [6,[],[[]]];_end=_info param [7,[],[[]]];
        if (count _begin != 3 || {count _end != 3} || {_info param [2,false,[true]]}
            || {_info param [8,false,[true]]}) exitWith {_valid=false};
        private _centre=(_begin vectorAdd _end) vectorMultiply 0.5;
        private _connections=roadsConnectedTo _road;
        if (count _connections > 16 || {count _connections >= 3}) exitWith {_valid=false};
        private _next=objNull;private _best=181;
        {if (_x != _previous && {!(_x in _visited)}) then {
            private _angle=abs ((((_centre getDir _x)-_heading+540) mod 360)-180);
            if (_angle < _best) then {_next=_x;_best=_angle};
        }} forEach _connections;
        if (isNull _next || {_best > 20}) exitWith {_valid=false};
        private _nextInfo=getRoadInfo _next;
        private _a=_nextInfo param [6,[],[[]]];private _b=_nextInfo param [7,[],[[]]];
        if (count _a != 3 || {count _b != 3} || {_nextInfo param [2,false,[true]]}
            || {_nextInfo param [8,false,[true]]}) exitWith {_valid=false};
        private _point=(_a vectorAdd _b) vectorMultiply 0.5;
        private _segment=_point distance2D _centre;private _nextHeading=_centre getDir _point;
        if (_segment < 0.1 || {surfaceIsWater _point}
            || {abs ((_point select 2)-(_centre select 2))/_segment > 0.025}
            || {abs (((_nextHeading-_initial+540) mod 360)-180) > 25}) exitWith {_valid=false};
        _travel=_travel+_segment;_points pushBack _point;
        if (_travel >= 650) exitWith {};
        _previous=_road;_road=_next;_heading=_nextHeading;
    };
    if (_valid && {_travel >= 650}) then {_points} else {[]}
};
private _route=[];
{
    if (_route isNotEqualTo [] || {diag_tickTime >= _searchUntil}) exitWith {};
    private _roads=_x nearRoads 500;
    {private _road=_x;
        {private _candidate=[_road,_x] call _walk;
            if (_candidate isNotEqualTo []) exitWith {_route=_candidate};
        } forEach [false,true];
        if (_route isNotEqualTo [] || {diag_tickTime >= _searchUntil}) exitWith {};
    } forEach (_roads select [0,8]);
} forEach [[16600,12800,0],[14800,16400,0],[17000,14200,0],[12000,15000,0],
    [18500,12700,0],[10500,14000,0],[13500,19000,0],[20000,17000,0]];
["PASS-road-bounded-layout",_route isNotEqualTo [],str [count _route,diag_tickTime,_searchUntil]] call _check;
if (_route isEqualTo []) exitWith {};
private _at={
    params ["_distance"];
    private _travel=0;private _result=[];
    for "_index" from 1 to (count _route-1) do {
        private _from=_route select (_index-1);private _to=_route select _index;
        private _length=_from distance2D _to;
        if (_length > 0 && {_travel+_length >= _distance}) exitWith {
            _result=[_from vectorAdd ((_to vectorDiff _from) vectorMultiply ((_distance-_travel)/_length)),_from getDir _to];
        };
        _travel=_travel+_length;
    };
    _result
};
private _start=[10] call _at;private _frontStart=[65] call _at;private _goal=[620] call _at;
private _heading=_start select 1;private _axis=[sin _heading,cos _heading,0];private _right=[cos _heading,-sin _heading,0];
private _origin=+(_start select 0);
private _spawnPositions=[_start,_frontStart,_goal] apply {ASLToAGL ((_x select 0) vectorAdd (_right vectorMultiply 1))};
private _span={
    params ["_object"];
    private _box=boundingBoxReal _object;private _low=_box select 0;private _high=_box select 1;
    private _minimum=1e9;private _maximum=-1e9;
    {private _xx=_x;{private _yy=_x;{
        private _point=(_object modelToWorldWorld [_xx,_yy,_x]) vectorDiff _origin;
        private _along=_point vectorDotProduct _axis;_minimum=_minimum min _along;_maximum=_maximum max _along;
    } forEach [_low select 2,_high select 2];} forEach [_low select 1,_high select 1];} forEach [_low select 0,_high select 0];
    [_minimum,_maximum]
};
private _keys=["WAIT_AIPass_Enable","WAIT_AIPass_Contact_Enable","WAIT_AIPass_DrivingAssist_Enable","WAIT_AIPass_DrivingAssist_Passing_Enable"];
private _previous=createHashMapFromArray (_keys apply {[_x,missionNamespace getVariable [_x,false]]});
[createHashMapFromArray [["WAIT_AIPass_Enable",true],["WAIT_AIPass_Contact_Enable",false],
    ["WAIT_AIPass_DrivingAssist_Enable",true],["WAIT_AIPass_DrivingAssist_Passing_Enable",true]]] call WAIT_fnc_CortexTuning;
{
    private _mode=_x;
    ["Automatic road pass: "+_mode,"Production traffic observation must naturally qualify and negotiate a pass. Watch actual lateral travel, complete hull separation and return. REPLACE changes only the native waypoint during active OUT; the newer order must survive and produce real travel. No passing helper or result is injected.",_spawnPositions select 0] call _phase;
    private _vehicle=createVehicle ["B_MRAP_01_F",_spawnPositions select 0,[],0,"NONE"];
    private _front=createVehicle ["B_Truck_01_transport_F",_spawnPositions select 1,[],0,"NONE"];
    _vehicle setDir (_start select 1);_front setDir (_frontStart select 1);
    createVehicleCrew _vehicle;createVehicleCrew _front;
    private _group=group driver _vehicle;private _frontGroup=group driver _front;
    { _x setVariable ["WAIT_Headless_ExcludeGroup",true,true];_x setVariable ["acex_headless_blacklist",true,true];
        _x setBehaviour "SAFE";_x setCombatMode "BLUE";_x setSpeedMode "FULL";
    } forEach [_group,_frontGroup];
    private _ready=[{local _vehicle && {local _front} && {local _group} && {local _frontGroup}
        && {!isNull driver _vehicle} && {!isNull driver _front} && {_group != _frontGroup}
        && {simulationEnabled _vehicle} && {simulationEnabled _front}
        && {!isNull (roadAt _vehicle)} && {!isNull (roadAt _front)}
        && {!(surfaceIsWater (getPosWorld _vehicle))} && {!(surfaceIsWater (getPosWorld _front))}},8] call _wait;
    ["PASS-road-"+_mode+"-fresh-native-fixture",_ready] call _check;
    // Authored predecessor speed is an input; the passer receives no test-side speed/path command.
    _front forceSpeed (12/3.6);
    {private _wp=_x addWaypoint [_spawnPositions select 2,0];_wp setWaypointType "MOVE";
        _wp setWaypointCompletionRadius 5;_x setCurrentWaypoint _wp;
    } forEach [_group,_frontGroup];
    (driver _vehicle) setVariable ["WAIT_CortexQA_Label","AUTO PASSER "+_mode,true];
    (driver _vehicle) setVariable ["WAIT_CortexQA_Target",_spawnPositions select 2,true];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[_vehicle,_front,driver _vehicle,driver _front],true];
    private _damage=[damage _vehicle,damage _front];private _active=false;private _out=false;
    private _returned=false;private _clear=true;private _excursion=0;private _passed=false;
    private _replaced=false;private _replacement=[];private _replaceStart=[];private _preserved=true;private _newTravel=false;
    private _until=time+150;
    while {time < _until && {!_passed} && {!_newTravel}} do {
        sleep 0.25;
        private _work=_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap];
        private _result=_vehicle getVariable ["WAIT_DrivingPass_Result",[]];
        private _matching=count _work > 0 && {(_work getOrDefault ["peer",objNull]) == _front};
        _active=_active || {_matching};
        if (_matching && {(_work getOrDefault ["phase",""]) == "OUT"}) then {_out=true};
        if (_matching && {(_work getOrDefault ["phase",""]) == "RETURN"}) then {_returned=true};
        private _delta=(getPosASL _vehicle) vectorDiff (getPosASL _front);
        _excursion=_excursion max abs (_delta vectorDotProduct _right);
        private _ownSpan=[_vehicle] call _span;private _frontSpan=[_front] call _span;
        private _ahead=(_ownSpan select 0) > (_frontSpan select 1)+6;
        if (damage _vehicle > (_damage select 0)+0.01 || {damage _front > (_damage select 1)+0.01}) then {_clear=false};
        if (_mode == "REPLACE" && {_out} && {_matching} && {!_replaced}) then {
            _replaced=true;_replaceStart=getPosASL _vehicle;
            _replacement=ASLToAGL (_replaceStart vectorAdd (_right vectorMultiply 180));
            private _wp=_group addWaypoint [_replacement,0];_wp setWaypointType "MOVE";_wp setWaypointCompletionRadius 5;
            _group setCurrentWaypoint _wp;
        };
        if (_replaced) then {
            if ((waypointPosition [_group,currentWaypoint _group]) vectorDistance _replacement > 3) then {_preserved=false};
            _newTravel=count _work == 0 && {_preserved} && {_vehicle distance2D _replacement < 20}
                && {(getPosASL _vehicle) vectorDistance _replaceStart >= 100};
        };
        _passed=_mode == "PASS" && {_active} && {_out} && {_returned} && {_ahead}
            && {_excursion >= 3} && {abs (_delta vectorDotProduct _right) <= 2}
            && {(getPosASL _vehicle) vectorDistance _origin >= 80} && {(_result param [0,""]) == "RETURN_COMPLETE"};
        diag_log format ["WAIT AUTO ROAD PASS: mode=%1 t=%2 positions=%3 speeds=%4 active=%5 excursion=%6 ahead=%7 replaced=%8 result=%9 admission=%10",
            _mode,time,[getPosASL _vehicle,getPosASL _front],[speed _vehicle,speed _front],_matching,_excursion,_ahead,_replaced,_result,
            _vehicle getVariable ["WAIT_DrivingPass_AdmissionResult",[]]];
    };
    ["PASS-road-"+_mode+"-natural-owned-operation",_ready && {_active} && {_out}] call _check;
    if (_mode == "PASS") then {
        ["PASS-road-actual-clear-return",_ready && {_passed} && {_clear},str [_excursion,_returned,getPosASL _vehicle]] call _check;
    } else {
        ["PASS-road-replacement-native-order-preserved",_replaced && {_preserved}] call _check;
        ["PASS-road-replacement-physical-travel",_ready && {_active} && {_replaced} && {_newTravel} && {_clear}] call _check;
    };
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
    {private _object=_x;{deleteVehicle _x} forEach crew _object;deleteVehicle _object} forEach [_vehicle,_front];
    {deleteGroup _x} forEach [_group,_frontGroup];
} forEach ["PASS","REPLACE"];
[_previous] call WAIT_fnc_CortexTuning;

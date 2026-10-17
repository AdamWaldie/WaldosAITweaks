/*
 * Author: WaldoTheWarfighter
 * Compares wheeled, tracked and mixed convoy continuity at four spacings; additive mixed
 * columns separately exercise 15/30/50/75 km/h at a fixed 30 m spacing.
 * One wheeled case applies native reverse input to the lead and observes follower yield/restart;
 * no actor/vehicle relocation or velocity assignment supplies its physical prerequisite.
 * Native driver incapacity additionally requires automatic IMMOBILE and physical halt, then
 * continued hold after recovery until an explicit public resume request.
 * Outside VR one bounded scan rotates the 1.8 km route across real relieved terrain; all spacing,
 * heading and order measurements use that selected route axis rather than world X/Y.
 * Locality/authority: scheduled server creates and owns fixtures through the public convoy API.
 * Repeat/JIP: fresh groups per case; public observer vehicles; release and delete each case.
 * Local controller limits, progress age, recovery count and retained route targets accompany each
 * timing row; remote owner state is explicitly unavailable rather than inferred from public pose.
 * The existing finite 80-second window logs one compact timing sample per second, including
 * effective-commander destinations, physical longitudinal gap and applied speed cap.
 * These diagnostics are audit-only and cannot pass physical acceptance or performance budgets.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>; required audit callbacks.
 * Return: Nothing. Current caller: cortexQAServer.sqf.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAConvoyMatrix.sqf";
 */
params ["_check","_phase","_wait"];
private _terrainOrigin=[2500,2500,0];
private _terrainHeading=0;
private _terrainRelief=0;
private _terrainMaximumGrade=0;
private _terrainMinimumNormal=1;
private _terrainScenarioReady=worldName == "VR";
private _terrainWorld={
    params ["_origin","_heading","_localX","_localY"];
    _origin vectorAdd [
        _localX*cos _heading+_localY*sin _heading,
        -_localX*sin _heading+_localY*cos _heading,
        0
    ]
};
private _routeSamples=[];
for "_along" from -180 to 1000 step 50 do {_routeSamples pushBack [0,_along]};
for "_across" from 50 to 400 step 50 do {_routeSamples pushBack [_across,1000]};
for "_along" from 1050 to 1400 step 50 do {_routeSamples pushBack [400,_along]};
if (!_terrainScenarioReady) then {
    private _found=[];
    private _margin=1800;
    private _scanStep=1000 max ((worldSize-2*_margin)/5);
    for "_candidateX" from _margin to (worldSize-_margin) step _scanStep do {
        for "_candidateY" from _margin to (worldSize-_margin) step _scanStep do {
            for "_heading" from 0 to 315 step 45 do {
                if (_found isEqualTo []) then {
                    private _heights=[];
                    private _usable=true;
                    private _maximumGrade=0;
                    private _minimumNormal=1;
                    private _previous=[];
                    {
                        private _sample=[[_candidateX,_candidateY,0],_heading,_x select 0,_x select 1] call _terrainWorld;
                        private _normal=(surfaceNormal _sample) select 2;
                        if (surfaceIsWater _sample || {_normal < 0.65}) exitWith {_usable=false};
                        private _height=getTerrainHeightASL _sample;
                        if (_previous isNotEqualTo [] && {_sample distance2D (_previous select 0) <= 75}) then {
                            private _grade=abs (_height-(_previous select 1))/(_sample distance2D (_previous select 0) max 1);
                            _maximumGrade=_maximumGrade max _grade;
                            if (_grade > 0.8) then {_usable=false};
                        };
                        _minimumNormal=_minimumNormal min _normal;
                        _previous=[_sample,_height];
                        _heights pushBack _height;
                    } forEach _routeSamples;
                    if (_usable && {_heights isNotEqualTo []}) then {
                        private _relief=(selectMax _heights)-(selectMin _heights);
                        if (_relief >= 30 && {_relief <= 220}) then {
                            _found=[_candidateX,_candidateY,0];
                            _terrainHeading=_heading;
                            _terrainRelief=_relief;
                            _terrainMaximumGrade=_maximumGrade;
                            _terrainMinimumNormal=_minimumNormal;
                        };
                    };
                };
            };
        };
    };
    if (_found isNotEqualTo []) then {_terrainOrigin=_found; _terrainScenarioReady=true};
};
private _terrainPosition={
    params ["_x","_y"];
    [_terrainOrigin,_terrainHeading,_x-2500,_y-2500] call _terrainWorld
};
private _terrainForward=[sin _terrainHeading,cos _terrainHeading,0];
private _terrainRight=[cos _terrainHeading,-sin _terrainHeading,0];
["CNVM-terrain-scenario",_terrainScenarioReady,
    str [worldName,_terrainOrigin,_terrainHeading,_terrainRelief,_terrainMaximumGrade,_terrainMinimumNormal]] call _check;
if (!_terrainScenarioReady) exitWith {};
private _columnOnly=(missionNamespace getVariable ["WAIT_CortexQA_Focus","all"]) in ["convoycolumn","convoytracked"];
private _trackedOnly=(missionNamespace getVariable ["WAIT_CortexQA_Focus","all"]) == "convoytracked";
private _followDiagnostic=(missionNamespace getVariable ["WAIT_CortexQA_Focus","all"]) == "convoyfollow";
private _diagnostic=(missionNamespace getVariable ["WAIT_CortexQA_Focus","all"]) == "convoydiagnostic";
private _types = [
    ["BASELINE-WHEELED",["O_MRAP_02_F","O_Truck_03_transport_F","O_Truck_03_transport_F"]],
    ["BASELINE-TRACKED",["O_APC_Tracked_02_cannon_F","O_APC_Tracked_02_cannon_F","O_APC_Tracked_02_cannon_F"]],
    ["BASELINE-MIXED",["O_MRAP_02_F","O_APC_Tracked_02_cannon_F","O_Truck_03_transport_F"]],
    ["WHEELED",["O_MRAP_02_F","O_Truck_03_transport_F","O_Truck_03_transport_F"]],
    ["TRACKED",["O_APC_Tracked_02_cannon_F","O_APC_Tracked_02_cannon_F","O_APC_Tracked_02_cannon_F"]],
    ["MIXED",["O_MRAP_02_F","O_APC_Tracked_02_cannon_F","O_Truck_03_transport_F"]]
];
if (_diagnostic) then {
    _types=["BASELINE-CONTROL","BASELINE-LEAD-MOVE","BASELINE-FORCE-SPEED","BASELINE-OMIT-LEAD-GAP"] apply {[_x,["O_MRAP_02_F","O_Truck_03_transport_F","O_Truck_03_transport_F"]]};
};
if (_followDiagnostic) then {
    _diagnostic=true;
    _types=["BASELINE-DRIVER-FOLLOW","BASELINE-VEHICLE-FOLLOW","BASELINE-MOVE-FORCE"] apply {[_x,["O_MRAP_02_F","O_Truck_03_transport_F","O_Truck_03_transport_F"]]};
};
if (_columnOnly) then {_types=_types select {(_x select 0) find "BASELINE-" != 0}};
if (_trackedOnly) then {_types=_types select {(_x select 0) == "TRACKED"}};
if (!_diagnostic && {!_columnOnly} && {!_trackedOnly}) then {
    {
        _types pushBack [format ["MIXED-SPEED-%1",_x],["O_MRAP_02_F","O_APC_Tracked_02_cannon_F","O_Truck_03_transport_F"],_x];
    } forEach [15,30,50,75];
};
{
    _x params ["_label","_classes"];
    private _requestedSpeed=_x param [2,30,[0]];
    private _speedCase=count _x >= 3;
    private _baseline = _label find "BASELINE-" == 0;
    {
        private _spacing = _x;
        private _id = format ["CNVM-%1-%2",_label,_spacing];
        [_id,"This case creates operating crew, no cargo passengers: all must stay aboard. Watch their labelled vehicles and actual tracks on the 1 km straight, then a deliberate halt/resume. Separate cases test corners. BASELINE labels identify engine-only comparisons.",[2500,2500] call _terrainPosition] call _phase;
        private _group = createGroup [east,true];
        // Normal fixture owns this group. Capture only WAIT cases; engine baselines stay untouched.
        _group setVariable ["WAIT_Convoy_CaptureControl",!_baseline];
        _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
        _group setVariable ["acex_headless_blacklist",true,true];
        private _vehicles=[];
        private _fixtureCrew=[];
        _group setGroupIdGlobal [_id];
        {
            private _vehicle=createVehicle [_x,[2500,2500-_forEachIndex*_spacing] call _terrainPosition,[],0,"NONE"];
            _vehicle setDir _terrainHeading;
            _vehicle setVariable ["WAIT_CortexQA_GapBand",[_spacing*0.8,_spacing*1.2],true];
            createVehicleCrew _vehicle;
            private _vehicleNumber=_forEachIndex+1;
            {
                _fixtureCrew pushBack [_x,_vehicle];
                _x setVariable ["WAIT_CortexQA_Label",format ["%1 / vehicle %2 crew",_id,_vehicleNumber],true];
            } forEach crew _vehicle;
            _vehicle setVariable ["WAIT_CortexQA_Case",_id,true];
            _vehicle setVariable ["WAIT_CortexQA_Exits",[],true];
            _vehicle addEventHandler ["GetOut",{
                params ["_vehicle","_role","_unit"];
                if (isNull _unit) exitWith {}; // Deleted fixture occupants are cleanup, not physical exits.
                private _exits=_vehicle getVariable ["WAIT_CortexQA_Exits",[]];
                _exits pushBack [netId _unit,_role,serverTime,getPosATL _vehicle];
                _vehicle setVariable ["WAIT_CortexQA_Exits",_exits,true];
                diag_log format ["WAIT CORTEX QA MATRIX CREW EXIT: case=%1 unit=%2 role=%3 position=%4 assigned=%5 assignedRole=%6 command=%7 convoyActive=%8",_vehicle getVariable ["WAIT_CortexQA_Case",""],netId _unit,_role,getPosATL _unit,assignedVehicle _unit,assignedVehicleRole _unit,currentCommand _unit,_vehicle getVariable ["WAIT_Convoy_Active",false]];
            }];
            private _old=group driver _vehicle;
            (crew _vehicle) joinSilent _group;
            deleteGroup _old;
            {_x setVariable ["acex_headless_blacklist",true,true]} forEach crew _vehicle;
            _vehicles pushBack _vehicle;
        } forEach _classes;
        missionNamespace setVariable ["WAIT_CortexQA_Actors",_fixtureCrew apply {_x select 0},true];
        _group selectLeader driver (_vehicles select 0);
        _group setBehaviour "SAFE";
        _group setCombatMode "BLUE";
        private _wp=_group addWaypoint [[2500,3500] call _terrainPosition,0]; _wp setWaypointType "MOVE";
        _wp=_group addWaypoint [[2900,3500] call _terrainPosition,0]; _wp setWaypointType "MOVE";
        _wp=_group addWaypoint [[2900,3900] call _terrainPosition,0]; _wp setWaypointType "MOVE";
        missionNamespace setVariable ["WAIT_CortexQA_ConvoyVehicles",_vehicles,true];
        if (_baseline) then {
            _group setVariable ["WAIT_AIPass_Exclude",true,true];
            _group setFormation "COLUMN"; _group enableAttack false;
            {
                _x limitSpeed 34.5;
                if (_label != "BASELINE-OMIT-LEAD-GAP" || {_forEachIndex > 0}) then {_x setConvoySeparation _spacing};
                _x setUnloadInCombat [false,false];
            } forEach _vehicles;
            if (_label in ["BASELINE-LEAD-MOVE","BASELINE-MOVE-FORCE"]) then {driver (_vehicles select 0) doMove ([2500,3500] call _terrainPosition)};
            if (_label in ["BASELINE-FORCE-SPEED","BASELINE-MOVE-FORCE"]) then {{_x forceSpeed (30/3.6)} forEach _vehicles};
            (_vehicles select 0) limitSpeed 30;
            if (_label == "BASELINE-DRIVER-FOLLOW") then {{if (_forEachIndex > 0) then {(driver _x) doFollow leader _group}} forEach _vehicles};
            if (_label == "BASELINE-VEHICLE-FOLLOW") then {{if (_forEachIndex > 0) then {_x doFollow leader _group}} forEach _vehicles};
            [_id+"-fixture",count _vehicles == 3 && {_vehicles findIf {!alive driver _x} < 0}] call _check;
        } else {[_id+"-start",[_group,_requestedSpeed,_spacing,true] call WAIT_fnc_SimpleAiConvoy] call _check};
        private _origins=_vehicles apply {getPosATL _x};
        private _samples=[0,0,0];
        private _stops=[0,0,0];
        private _restartCounts=[0,0,0];
        private _wasStopped=[false,false,false];
        private _count=0;
        private _maxLateral=0;
        private _gapInBand=[0,0];
        private _minimumGaps=[1e9,1e9];
        private _maximumGaps=[0,0];
        private _orderBroken=false;
        private _start=diag_tickTime;
        private _nextLog=0;
        private _nextFollow=0;
        // Startup is assessed separately so a loop cannot hide inside the warm-up window.
        private _startupTurned=false;
        private _startupBackwards=false;
        private _startupFirstMove=[-1,-1,-1];
        private _startupRestarts=[0,0,0];
        private _startupStopsAfterMove=[0,0,0];
        private _startupMoving=[false,false,false];
        for "_sample" from 1 to 40 do {
            {
                private _index=_forEachIndex;
                private _moving=abs speed _x > 2;
                private _wasMoving=_startupMoving select _index;
                if (_moving && {!_wasMoving}) then {
                    if ((_startupFirstMove select _index) < 0) then {
                        _startupFirstMove set [_index,diag_tickTime-_start];
                    } else {_startupRestarts set [_index,(_startupRestarts select _index)+1]};
                };
                if (!_moving && {_wasMoving}) then {
                    _startupStopsAfterMove set [_index,(_startupStopsAfterMove select _index)+1];
                };
                _startupMoving set [_index,_moving];
                if (_moving && {abs (((getDir _x-_terrainHeading+540) mod 360)-180) > 75}) then {_startupTurned=true};
                private _startupDelta=(getPosATL _x) vectorDiff (_origins select _forEachIndex);
                if ((_startupDelta vectorDotProduct _terrainForward) < -5) then {_startupBackwards=true};
            } forEach _vehicles;
            sleep 0.5;
        };
        // Observations only: a speed threshold crossing is not a completed start or collision.
        // Preserve the excluded warm-up window without inventing an unvalidated acceptance limit.
        diag_log format ["WAIT CORTEX QA MATRIX STARTUP: case=%1 windowSeconds=%2 firstMoveSeconds=%3 restarts=%4 stopsAfterMove=%5 positions=%6 speeds=%7",_id,diag_tickTime-_start,_startupFirstMove,_startupRestarts,_startupStopsAfterMove,_vehicles apply {getPosATL _x},_vehicles apply {speed _x}];
        [_id+"-startup-no-loop",!_startupTurned && {!_startupBackwards},str [_startupTurned,_startupBackwards]] call _check;
        while {diag_tickTime-_start < 80} do {
            if (_baseline && {diag_tickTime >= _nextFollow}) then {
                _nextFollow=diag_tickTime+5;
                {if (speed _x < 5) then {_x doFollow leader _group}; _x setConvoySeparation _spacing} forEach (_vehicles select [1]);
            };
            {
                // This measurement window is the northbound straight. Measure real
                // geometry, not the group formation flag or accepted movement order.
                if (_forEachIndex > 0) then {
                    private _front=_vehicles select (_forEachIndex-1);
                    private _frontPosition=getPosATL _front;
                    private _gap=_x distance2D _front;
                    private _slot=_forEachIndex-1;
                    private _bodyLengths=0;
                    {private _bounds=boundingBoxReal _x; _bodyLengths=_bodyLengths+abs (((_bounds select 1) select 1)-((_bounds select 0) select 1))} forEach [_x,_front];
                    private _targetGap=_spacing max (_bodyLengths*0.5+5);
                    private _tolerance=(_targetGap*0.2) max 3;
                    private _low=(_targetGap-_tolerance) max (_bodyLengths*0.5+5);
                    private _high=_targetGap+_tolerance;
                    _x setVariable ["WAIT_CortexQA_GapBand",[_low,_high],true];
                    if (_gap >= _low && {_gap <= _high}) then {_gapInBand set [_slot,(_gapInBand select _slot)+1]};
                    _minimumGaps set [_slot,(_minimumGaps select _slot) min _gap];
                    _maximumGaps set [_slot,(_maximumGaps select _slot) max _gap];
                    _maxLateral=_maxLateral max abs (((getPosATL _x) vectorDiff _frontPosition) vectorDotProduct _terrainRight);
                };
                if (_forEachIndex > 0 && {(((getPosATL _x) vectorDiff (getPosATL (_vehicles select (_forEachIndex-1)))) vectorDotProduct _terrainForward) > 3}) then {_orderBroken=true};
                private _v=abs speed _x;
                private _i=_forEachIndex;
                _samples set [_i,(_samples select _i)+_v];
                private _stopped=_v < 2;
                if (_stopped) then {_stops set [_i,(_stops select _i)+1]};
                if (!_stopped && {_wasStopped select _i}) then {_restartCounts set [_i,(_restartCounts select _i)+1]};
                _wasStopped set [_i,_stopped];
            } forEach _vehicles;
            // Audit-only bounded timing, aligned with the controller cadence. The existing
            // five-second aggregate can miss a complete start/stop cycle between samples.
            private _timingOwnerLocal=local _group;
            private _timingController=if (_timingOwnerLocal) then {_group getVariable ["WAIT_Convoy_LocalState",createHashMap]} else {createHashMap};
            private _timingLimits=_timingController getOrDefault ["speedLimits",createHashMap];
            private _timingFollowers=_timingController getOrDefault ["followers",createHashMap];
            private _timing=_vehicles apply {
                private _index=_forEachIndex;
                private _operator=effectiveCommander _x;
                if (isNull _operator) then {_operator=driver _x};
                private _longitudinal=-1;
                if (_index > 0) then {
                    private _front=_vehicles select (_index-1);
                    private _bearing=getDir _front;
                    private _delta=(getPosATL _front) vectorDiff (getPosATL _x);
                    _delta set [2,0];
                    _longitudinal=_delta vectorDotProduct [sin _bearing,cos _bearing,0];
                };
                private _controllerEvidence=if (_timingOwnerLocal) then {
                    private _key=netId _x;
                    private _progress=_timingFollowers getOrDefault [_key,[]];
                    ["LOCAL",_timingLimits getOrDefault [_key,[]],
                        _timingController getOrDefault ["leadSpeedLimit",[]],
                        _progress param [1,-1],_progress param [4,0],
                        _progress param [5,[]],_progress param [6,[]],
                        isAISteeringComponentEnabled _x,
                        (_timingController getOrDefault ["controlSamples",createHashMap]) getOrDefault [_key,[]],
                        _timingController getOrDefault ["leadControlSample",[]]]
                } else {["UNAVAILABLE_REMOTE_OWNER",groupOwner _group]};
                [netId _x,speed _x,getForcedSpeed _x,velocityModelSpace _x,
                    _longitudinal,netId _operator,currentCommand _operator,expectedDestination _operator,
                    _controllerEvidence]
            };
            diag_log format ["WAIT CORTEX QA CONVOY TIMING: %1",[_id,serverTime,diag_tickTime-_start,_timing]];
            _count=_count+1;
            if (diag_tickTime >= _nextLog) then {
                _nextLog=diag_tickTime+5;
                private _convoyBrain=_group getVariable ["WAIT_Convoy_Brain",createHashMap];
                diag_log format ["WAIT CORTEX QA CONVOY ADMISSION: case=%1 groupOwner=%2 epoch=%3 brainEpoch=%4 lastStep=%5 pending=%6 queuedAt=%7 skipped=%8",_id,groupOwner _group,
                    _group getVariable ["WAIT_AIPass_Epoch",0],_convoyBrain getOrDefault ["ownerEpoch",-1],
                    _convoyBrain getOrDefault ["lastStepAt",-1],_convoyBrain getOrDefault ["pending",false],
                    _convoyBrain getOrDefault ["queuedAt",-1],_convoyBrain getOrDefault ["skippedReason",""]];
                private _localPacing=if (local _group) then {
                    private _controller=_group getVariable ["WAIT_Convoy_LocalState",createHashMap];
                    private _limits=_controller getOrDefault ["speedLimits",createHashMap];
                    _vehicles apply {[netId _x,_limits getOrDefault [netId _x,[]],velocityModelSpace _x]}
                } else {["UNAVAILABLE_REMOTE_OWNER",groupOwner _group]};
                diag_log format ["WAIT CORTEX QA CONVOY PACING: case=%1 owner=%2 local=%3 vehicleLimitTimeModelVelocity=%4",_id,groupOwner _group,local _group,_localPacing];
                diag_log format ["WAIT CORTEX QA CONVOY MATRIX: case=%1 speeds=%2 forced=%3 gaps=%4 motion=%5 formation=%6 steering=%7",_id,_vehicles apply {speed _x},_vehicles apply {getForcedSpeed _x},[(_vehicles select 1) distance2D (_vehicles select 0),(_vehicles select 2) distance2D (_vehicles select 1)],_vehicles apply {[getDir _x,currentCommand driver _x,expectedDestination driver _x,getPosATL _x]},formation _group,_vehicles apply {isAISteeringComponentEnabled _x}];
            };
            sleep 1;
        };
        [_id+"-single-file",_count >= 40 && {_maxLateral <= 8} && {!_orderBroken},format ["maximum predecessor lateral offset=%1 m; order broken=%2",_maxLateral,_orderBroken]] call _check;
        [_id+"-spacing-band",_count >= 40 && {_gapInBand findIf {_x / (_count max 1) < 0.8} < 0},
            format ["in-band samples=%1/%2 min=%3 max=%4",_gapInBand,_count,_minimumGaps,_maximumGaps]] call _check;
        private _averages=_samples apply {_x/(_count max 1)};
        // Keep the original 30 km/h criteria (18 km/h, 300 m). Lower-speed cases
        // require proportional real travel, never merely an accepted speed setting.
        private _minimumAverage=_requestedSpeed*0.6;
        private _minimumTravel=_minimumAverage/3.6*60;
        diag_log format ["WAIT CORTEX QA CONVOY SPEED: case=%1 requestedKmh=%2 spacingM=%3 minimumAverageKmh=%4 minimumTravelM=%5",_id,_requestedSpeed,_spacing,_minimumAverage,_minimumTravel];
        [_id+"-continuous-speed",_count >= 40 && {_averages findIf {!finite _x || {_x < _minimumAverage}} < 0},str _averages] call _check;
        [_id+"-stop-fraction",_count >= 40 && {_stops findIf {_x/(_count max 1) > 0.1} < 0},str [_stops,_count]] call _check;
        [_id+"-restart-count",_restartCounts findIf {_x > 2} < 0,str _restartCounts] call _check;
        private _travelled=true;
        {
            private _distance=_x distance2D (_origins select _forEachIndex);
            if (!finite _distance || {_distance < _minimumTravel}) then {_travelled=false};
        } forEach _vehicles;
        [_id+"-physical-progress",_travelled,str (_vehicles apply {getPosATL _x})] call _check;
        if (!_baseline) then {
            diag_log format ["WAIT CORTEX QA HALT SEATS BEFORE: case=%1 seats=%2",_id,_vehicles apply {fullCrew [_x,"",false]}];
            [_group,0,_spacing,true] call WAIT_fnc_SimpleAiConvoy;
            private _registeredHalt=(missionNamespace getVariable ["WAIT_Convoy_Registry",[]]) select {(_x select 0) == _group};
            diag_log format ["WAIT CORTEX QA HALT REQUEST: case=%1 registry=%2",_id,_registeredHalt];
            private _halted=[{_vehicles findIf {abs speed _x > 1} < 0},20] call _wait;
            [_id+"-halt-stationary",_halted,str (_vehicles apply {[speed _x,getForcedSpeed _x,currentCommand driver _x,expectedDestination driver _x,owner _x]})] call _check;
            {
                diag_log format ["WAIT CORTEX QA HALT COMMANDERS: case=%1 vehicle=%2 effective=%3 crew=%4",_id,_forEachIndex,effectiveCommander _x,
                    (crew _x) apply {[assignedVehicleRole _x,currentCommand _x,expectedDestination _x]}];
            } forEach _vehicles;
            private _restartOrigins=_vehicles apply {getPosATL _x};
            [_id+" restart","Same straight route after a deliberate stop: every vehicle must resume forwards without a U-turn or long hold. Heading and actual destinations are recorded.",getPosATL (_vehicles select 1)] call _phase;
            [_id+"-resume-accepted",[_group,_requestedSpeed,_spacing,true] call WAIT_fnc_SimpleAiConvoy] call _check;
            private _turned=false;
            private _resumed=[{
                private _moving=true;
                {
                    if (abs speed _x > 2 && {abs (((getDir _x-_terrainHeading+540) mod 360)-180) > 75}) then {_turned=true};
                    private _distance=_x distance2D (_restartOrigins select _forEachIndex);
                    private _speed=abs speed _x;
                    if (!finite _distance || {!finite _speed} || {_distance < 60} || {_speed < 10}) then {_moving=false};
                } forEach _vehicles;
                _moving
            },60] call _wait;
            private _resumeEvidence=[];
            {
                _resumeEvidence pushBack [getPosATL _x,_x distance2D (_restartOrigins select _forEachIndex),speed _x,getDir _x,
                    currentCommand driver _x,expectedDestination driver _x,getForcedSpeed _x];
            } forEach _vehicles;
            [_id+"-resume-forward-progress",_resumed,str _resumeEvidence] call _check;
            [_id+"-resume-no-turnaround",!_turned,str [_terrainHeading,_resumeEvidence]] call _check;
        };
        if (!_baseline && {_label == "WHEELED"} && {_spacing == 30}) then {
            private _reverseLead=_vehicles select 0;
            private _reverseFollower=_vehicles select 1;
            [_id+" reverse yield","Diagnostic stimulus: native BACK input is applied to the lead. Actual backward travel must occur, then the follower must physically yield and both must resume forward. No velocity or position is assigned.",getPosATL _reverseFollower] call _phase;
            [_group,0,_spacing,true] call WAIT_fnc_SimpleAiConvoy;
            private _columnStopped=[{_vehicles findIf {abs speed _x > 1} < 0},20] call _wait;
            private _slowAccepted=[_group,5,_spacing,true] call WAIT_fnc_SimpleAiConvoy;
            private _slowRevision=_group getVariable ["WAIT_Convoy_Revision",-1];
            private _slowApplied=[{
                private _receipt=_reverseLead getVariable ["WAIT_Convoy_OwnedSpeed",[]];
                count _receipt == 3 && {(_receipt select 0) == _group}
                    && {(_receipt select 1) == _slowRevision}
                    && {getForcedSpeed _reverseLead > 0}
                    && {getForcedSpeed _reverseLead <= 5/3.6+0.1}
            },10] call _wait;
            _reverseLead sendSimpleCommand "STOP";
            private _leadStopped=_columnStopped && {_slowAccepted} && {_slowApplied}
                && {[{abs speed _reverseLead < 1},8] call _wait};
            private _leadBounds=boundingBoxReal _reverseLead;
            private _followerBounds=boundingBoxReal _reverseFollower;
            private _bodyClearance=(abs ((_leadBounds select 0) select 1)+abs ((_leadBounds select 1) select 1)
                +abs ((_followerBounds select 0) select 1)+abs ((_followerBounds select 1) select 1))*0.5+3;
            private _clearanceSafe=_reverseLead distance2D _reverseFollower > _bodyClearance+8;
            private _reverseOrigin=getPosATL _reverseLead;
            private _reverseAxis=vectorDir _reverseLead;
            _reverseLead sendSimpleCommand "STOPTURNING";
            if (_leadStopped && {_clearanceSafe}) then {_reverseLead sendSimpleCommand "BACK"};
            private _reverseSamples=0;
            private _yieldSamples=0;
            private _maximumFollowerSpeed=0;
            private _reverseSince=-1;
            private _reverseDeadline=time+8;
            while {time < _reverseDeadline && {_leadStopped} && {_clearanceSafe}} do {
                if (_reverseLead distance2D _reverseFollower <= _bodyClearance+2) exitWith {_clearanceSafe=false};
                if (-(((getPosATL _reverseLead) vectorDiff _reverseOrigin) vectorDotProduct _reverseAxis) >= 6) exitWith {};
                if ((velocityModelSpace _reverseLead select 1) < -0.5) then {
                    _reverseSamples=_reverseSamples+1;
                    if (_reverseSince < 0) then {_reverseSince=time};
                    if (time-_reverseSince >= 1.5) then {
                        _yieldSamples=_yieldSamples+1;
                        _maximumFollowerSpeed=_maximumFollowerSpeed max abs speed _reverseFollower;
                    };
                };
                sleep 0.5;
            };
            private _backwardTravel=-(((getPosATL _reverseLead) vectorDiff _reverseOrigin) vectorDotProduct _reverseAxis);
            _reverseLead sendSimpleCommand "STOP";
            private _reverseReal=_leadStopped && {_clearanceSafe} && {_reverseSamples >= 4} && {_backwardTravel >= 2};
            [_id+"-reverse-physical-prerequisite",_reverseReal,str [_leadStopped,_slowAccepted,_slowApplied,_clearanceSafe,_reverseSamples,_backwardTravel]] call _check;
            [_id+"-reverse-follower-physical-yield",_reverseReal && {_yieldSamples >= 4} && {_maximumFollowerSpeed <= 1},str [_yieldSamples,_maximumFollowerSpeed,getPosATL _reverseFollower]] call _check;
            _reverseLead sendSimpleCommand "STOP";
            [_group,_requestedSpeed,_spacing,true] call WAIT_fnc_SimpleAiConvoy;
            _reverseLead sendSimpleCommand "FORWARD";
            private _forwardOrigins=[getPosATL _reverseLead,getPosATL _reverseFollower];
            [_id+"-reverse-forward-recovery",[{
                ((_reverseLead distance2D (_forwardOrigins select 0)) >= 30)
                    && {((_reverseFollower distance2D (_forwardOrigins select 1)) >= 30)}
                    && {(velocityModelSpace _reverseLead select 1) > 1}
                    && {(velocityModelSpace _reverseFollower select 1) > 1}
            },60] call _wait,str [_forwardOrigins,getPosATL _reverseLead,getPosATL _reverseFollower]] call _check;
        };
        if (!_baseline && {_label == "WHEELED"} && {_spacing == 30}) then {
            private _drivers=_vehicles apply {driver _x};
            private _driverStimulusReady=_drivers findIf {isNull _x || {!alive _x} || {!local _x}} < 0;
            [_id+" driver incapacity","Native unconsciousness is the diagnostic stimulus. The registry must enter IMMOBILE and every vehicle physically stop. Recovering the drivers must not resume the convoy without a new public order.",getPosATL (_vehicles select 0)] call _phase;
            if (_driverStimulusReady) then {{_x setUnconscious true} forEach _drivers};
            private _incapacitated=_driverStimulusReady && {[{_drivers findIf {lifeState _x != "INCAPACITATED"} < 0},8] call _wait};
            [_id+"-driver-incapacity-prerequisite",_incapacitated,str (_drivers apply {[netId _x,lifeState _x,owner _x]})] call _check;
            private _immobile=[{
                private _entry=(missionNamespace getVariable ["WAIT_Convoy_Registry",[]]) select {(_x select 0) == _group};
                _entry isNotEqualTo [] && {private _cfg=(_entry select 0) select 1;
                    (_cfg select 5) == "HALT" && {(_cfg param [8,""]) == "IMMOBILE"}}
            },20] call _wait;
            [_id+"-driver-incapacity-immobile-transition",_incapacitated && {_immobile}] call _check;
            private _physicallyStopped=[{_vehicles findIf {abs speed _x > 1} < 0},20] call _wait;
            [_id+"-driver-incapacity-physical-halt",_incapacitated && {_immobile} && {_physicallyStopped},str (_vehicles apply {[speed _x,getPosATL _x]})] call _check;
            {_x setUnconscious false} forEach (_drivers select {local _x && {alive _x}});
            private _recovered=[{_drivers findIf {lifeState _x == "INCAPACITATED" || {!alive _x}} < 0},8] call _wait;
            sleep 3;
            private _heldRegistry=(missionNamespace getVariable ["WAIT_Convoy_Registry",[]]) select {(_x select 0) == _group};
            private _remainedHeld=_heldRegistry isNotEqualTo [] && {(((_heldRegistry select 0) select 1) select 5) == "HALT"}
                && {_vehicles findIf {abs speed _x > 1} < 0};
            [_id+"-driver-recovery-retains-halt",_incapacitated && {_immobile} && {_recovered} && {_remainedHeld}] call _check;
            private _recoveryOrigins=_vehicles apply {getPosATL _x};
            private _resumeRecovered=[_group,_requestedSpeed,_spacing,true] call WAIT_fnc_SimpleAiConvoy;
            private _recoveryTravel=[{
                private _allMoving=true;
                {
                    if (_x distance2D (_recoveryOrigins select _forEachIndex) < 30 || {abs speed _x < 2}) then {_allMoving=false};
                } forEach _vehicles;
                _allMoving
            },60] call _wait;
            [_id+"-driver-recovery-explicit-physical-resume",_recovered && {_resumeRecovered} && {_recoveryTravel},str (_vehicles apply {getPosATL _x})] call _check;
        };
        [_id+"-operating-crew-retained",_fixtureCrew findIf {!alive (_x select 0) || {vehicle (_x select 0) != (_x select 1)}} < 0 && {_vehicles findIf {(_x getVariable ["WAIT_CortexQA_Exits",[]]) isNotEqualTo []} < 0},str (_vehicles apply {_x getVariable ["WAIT_CortexQA_Exits",[]]})] call _check;
        if (!_baseline) then {[_group,0,_spacing,true,true] call WAIT_fnc_SimpleAiConvoy};
        // Delete the original fixture roster, including anyone now on foot or in another seat.
        {deleteVehicle (_x select 0)} forEach _fixtureCrew;
        [_id+"-fixture-cleanup",[{_fixtureCrew findIf {!isNull (_x select 0)} < 0},10] call _wait] call _check;
        missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
        {private _v=_x; {deleteVehicle _x} forEach crew _v; deleteVehicle _v} forEach _vehicles;
        deleteGroup _group;
        missionNamespace setVariable ["WAIT_CortexQA_ConvoyVehicles",[],true];
    } forEach (if (_speedCase || {_diagnostic}) then {[30]} else {if (_columnOnly) then {[30,50]} else {[[15,30,50,75],[50]] select _baseline}});
} forEach _types;

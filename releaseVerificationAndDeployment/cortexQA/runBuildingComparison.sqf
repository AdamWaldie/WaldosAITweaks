/*
 * Author: WaldoTheWarfighter
 * Compares physical building entry using independent engine commands across small and large,
 * single- and multi-storey house models, then exercises production garrison and clearance.
 * Locality/authority: scheduled dedicated-server audit; normal fixtures are server-pinned.
 * Normal and HC exit observations accumulate assignments as bounded planning publishes them.
 * HC acceptance includes pending workers and rejects roster loss across the transfer.
 * The HC batch adds an explicit mid-egress transfer through the real migration provider.
 * Clearance acceptance requires covered interior navigation positions; exposed positions remain
 * separately recorded as exterior evidence, rather than being counted as uncleared rooms.
 * Fresh-clearance room observations use live pose, house bounds and intervening GEOM checks,
 * independently of production visit receipts; proximity/audio interior alone cannot pass.
 * Native door diagnostics retry each method/model's first physically missed node with all unlocked
 * doors open; original failures remain, and no production clearance receives door assistance.
 * Repeat/JIP: disposable actors and houses are removed; observer state is public for joining clients.
 * Normal-owner clearance records at most 24 native path events per actor, eight seconds apart,
 * with at most 24 path points plus the final point. Local diagnostic handlers are removed before
 * actor cleanup; they issue no movement and are not evidence of physical arrival.
 * Existing bounded actor samples include native movement failure/completion and canMove flags;
 * none grants a physical visit or changes a retry budget.
 * Exterior reserve observation requires live physical arrival, heading within 75 degrees of
 * the assigned watch point and an unobstructed actual eye-to-watch ray. All living exterior
 * participants in the twelve-person fixture must be observed; stage labels alone cannot pass.
 * An additive garrison overflow case requires all interior posts and two distinct exterior observers,
 * then physical ordinary-order handover. Normal-only single-survivor cases lose either pair
 * slot after independent entry observation and require new physical room progress without reserves. A separate natural-contact case retains its original
 * patrol route and requires actual post-clear travel after native gunfire kills the defender.
 * No new route or movement reset is injected after that contact starts. This is navigation/occupation, not combat-effectiveness proof.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>; all required audit callbacks.
 * Optional fourth argument: nativeOnly <BOOL>, false; stop after independent comparisons.
 * Optional fifth argument: skipNative <BOOL>, false; run production acceptance without repeating controls.
 * Optional sixth argument: transformOnly <BOOL>, false; focused moved-building cancellation/reorder.
 * Optional seventh argument: largeOnly <BOOL>, false; run the same four/twelve-person Big02
 * fixtures and original assertions only. This diagnostic does not replace full CLEAR acceptance.
 * Return: Nothing. Current callers: cortexQA/runServer.sqf.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQABuildings.sqf";
 */
params ["_check","_phase","_wait",["_nativeOnly",false,[true]],["_skipNative",false,[true]],["_transformOnly",false,[true]],["_largeOnly",false,[true]]];
// Independent live-pose observation, never a production receipt or completion flag.
// Audio interior values remain diagnostic; bounds plus geometry establish this
// fixture's navigation visit, not hostile room safety or universal building support.
private _observedRoomVisit={
    params ["_actor","_house","_room"];
    if (!alive _actor || {!isNull objectParent _actor}) exitWith {false};
    private _actual=getPosASL _actor;
    private _target=AGLToASL _room;
    if (_actual vectorDistance _target > 1.5 || {abs ((_actual select 2)-(_target select 2)) > 0.75}) exitWith {false};
    private _bounds=boundingBoxReal _house;
    private _pose=_house worldToModel (getPosATL _actor);
    private _low=_bounds select 0;
    private _high=_bounds select 1;
    if ((_pose select 0) < (_low select 0) || {(_pose select 0) > (_high select 0)}
        || {(_pose select 1) < (_low select 1)} || {(_pose select 1) > (_high select 1)}
        || {(_pose select 2) < (_low select 2)} || {(_pose select 2) > (_high select 2)}) exitWith {false};
    // A model bounding box can enclose an open courtyard or space beside a wing.
    // Require physical overhead geometry belonging to this house, independently of WAIT receipts.
    private _roof=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.5],
        _actual vectorAdd [0,0,10],_actor,objNull,true,4,"GEOM","NONE"];
    if (_roof isEqualTo []) exitWith {false};
    private _nearestRoof=_roof select 0;
    if ((_nearestRoof select 2) != _house && {(_nearestRoof select 3) != _house}) exitWith {false};
    private _hits=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.6],_target vectorAdd [0,0,0.6],_actor,objNull,true,8,"GEOM","NONE"];
    // Another building, prop or wall also blocks a physical navigation visit.
    _hits isEqualTo []
};
// Independent physical exit observation. An interior fallback hold cannot pass.
private _observedExit={
    params ["_actor","_house","_exitTarget"];
    if (!alive _actor || {!isNull objectParent _actor} || {count _exitTarget != 3}) exitWith {false};
    if (_actor distance2D _exitTarget > 1.5
        || {abs (((getPosATL _actor) select 2)-(_exitTarget select 2)) > 0.75}) exitWith {false};
    private _bounds=boundingBoxReal _house;
    private _low=_bounds select 0;
    private _high=_bounds select 1;
    private _outside={
        params ["_pose"];
        (_pose select 0) < (_low select 0)-0.5 || {(_pose select 0) > (_high select 0)+0.5}
            || {(_pose select 1) < (_low select 1)-0.5} || {(_pose select 1) > (_high select 1)+0.5}
    };
    [_house worldToModel (getPosATL _actor)] call _outside
        && {[_house worldToModel _exitTarget] call _outside}
};
private _recordFixture={
    params ["_house","_label"];
    private _positions=_house buildingPos -1;
    private _detail=[worldName,["TERRAIN","CREATE_VEHICLE"] select (worldName == "VR"),typeOf _house,getModelInfo _house,
        isSimpleObject _house,simulationEnabled _house,count _positions,getPosATL _house];
    diag_log format ["WAIT BUILDING FIXTURE: %1",[_label,_detail]];
    // Access points are model path entrances, not authored clearance destinations.
    // Record terrain clearance without moving either terrain or curator-created houses.
    private _accessProfile=[];
    for "_access" from 0 to 15 do {
        private _point=_house buildingExit _access;
        if (_point isEqualTo [0,0,0]) exitWith {};
        private _asl=AGLToASL _point;
        _accessProfile pushBack [_access,_point,(_asl select 2)-getTerrainHeightASL _point];
    };
    diag_log format ["WAIT BUILDING PLACEMENT: %1",[_label,getPosWorld _house,
        vectorDir _house,vectorUp _house,_accessProfile]];

    private _doorProfile=[];
    private _doorCount=(getNumber (configOf _house >> "numberOfDoors")) min 16;
    for "_door" from 1 to _doorCount do {
        private _source=format ["Door_%1_sound_source",_door];
        _doorProfile pushBack [_door,_source,
            isClass (configOf _house >> "AnimationSources" >> _source),
            _house selectionPosition [format ["Door_%1_trigger",_door],"Memory"]];
    };
    _house setVariable ["WAIT_CortexQA_DoorProfile",_doorProfile];
    diag_log format ["WAIT BUILDING DOOR CONFIG: %1",[_label,_doorProfile]];
    ["BUILD-fixture-"+_label,!isNull _house && {!isSimpleObject _house}
        && {_positions isNotEqualTo []},str _detail] call _check;
};

private _validateNewFixturePlacement={
    params ["_house","_label"];
    // Correct only a newly created production audit fixture, before any actor exists.
    // Derive a small bounded lift from model access clearance, never a classname map.
    private _highestAccess=-1e12;
    for "_access" from 0 to 15 do {
        private _point=_house buildingExit _access;
        if (_point isEqualTo [0,0,0]) exitWith {};
        _highestAccess=_highestAccess max (((AGLToASL _point) select 2)-getTerrainHeightASL _point);
    };
    private _fixtureLift=0;
    if (_highestAccess < -0.05 && {_highestAccess >= -0.35}) then {
        _fixtureLift=(ceil ((0.15-_highestAccess)/0.05))*0.05;
        _house setPosATL ((getPosATL _house) vectorAdd [0,0,_fixtureLift]);
    };
    ["CLEAR-"+_label+"-placement-access",_highestAccess+_fixtureLift >= -0.05,
        str [_highestAccess,_fixtureLift,getPosATL _house]] call _check;
};

// Native command FSMs use moveTo internally; other controls retain doMove.
// Each excluded actor has one writer and independent physical arrival sampling.
private _issueNativeComparison={
    params ["_actor","_goal","_method"];
    if (_method == "COMMAND-FSM") then {
        _actor doFSM ["nativeBuildingMove.fsm",_goal,objNull];
    } else {
        _actor doMove _goal;
        if (_method == "REPLAN") then {_actor setDestination [_goal,"LEADER PLANNED",true]};
        // Isolate native DirectGo planning from full path/formation planning.
        // This excluded control still requires physical arrival; it is not production steering.
        if (_method == "DIRECT-GO") then {_actor setDestination [_goal,"LEADER DIRECT",true]};
        if (_method == "FORMATION") then {_actor setDestination [_goal,"FORMATION PLANNED",true]};
        // Isolate the upstream CQB destination hint from its random position offset:
        // original node coordinates, existing native request, no forced replan.
        if (_method == "FORMATION-HINT") then {_actor setDestination [_goal,"FORMATION PLANNED",false]};
    };
};

if (!_skipNative) then {
private _cases = [];
private _actors = [];
private _terrainHouses=if (_nativeOnly && {worldName == "Altis"}) then {
    nearestTerrainObjects [[16600,12800,0],["House"],5000,false,true]
} else {[]};
private _usedTerrainHouses=[];
{
    private _class = _x;
    private _row = _forEachIndex;
    {
        private _method = _x;
        private _house=if (worldName == "Altis") then {
            (_terrainHouses select {typeOf _x == _class && {!(_x in _usedTerrainHouses)}}) param [0,objNull]
        } else {createVehicle [_class,[6250+_forEachIndex*60,5800+_row*60,0],[],0,"NONE"]};
        if (isNull _house) exitWith {[format ["BUILD-%1-model-%2-terrain-fixture",_method,_row+1],false,_class] call _check};
        if (worldName == "VR") then {_house enableSimulationGlobal true} else {_usedTerrainHouses pushBack _house};
        if (worldName == "VR" && {_method in ["PLACED-LEADER","PLACED-FOLLOWER","ROOM-STOP","ROOM-SPEED"]}) then {
            [_house,format ["native-%1-model-%2",_method,_row+1]] call _validateNewFixturePlacement;
        };
        [_house,format ["%1-model-%2",_method,_row+1]] call _recordFixture;
        private _group = createGroup [east,true];
        _group setVariable ["WAIT_AIPass_Exclude",true,true];
        _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
        _group setVariable ["acex_headless_blacklist",true,true];
        // Matched validated fixtures isolate the native leader/follower role. A
        // separate real commander remains outside only in the follower control.
        if (_method == "PLACED-FOLLOWER") then {
            private _anchor=_group createUnit ["O_Soldier_F",_house getPos [30,150],[],0,"NONE"];
            _anchor allowDamage false;
            _anchor setVariable ["acex_headless_blacklist",true,true];
            _anchor setVariable ["WAIT_CortexQA_Label",format ["FIXED NATIVE LEADER / model %1",_row+1],true];
            doStop _anchor;
            _actors pushBack _anchor;
        };
        private _unit = _group createUnit ["O_Soldier_F",_house getPos [25,180],[],0,"NONE"];
        _unit setVariable ["acex_headless_blacklist",true,true];
        _unit allowDamage false;
        if (_method in ["PLACED-LEADER","ROOM-STOP","ROOM-SPEED"]) then {
            // Match the follower control's two-member group. Only leader identity
            // differs; a stopped spare actor exists outside in both controls.
            private _spare=_group createUnit ["O_Soldier_F",_house getPos [30,150],[],0,"NONE"];
            _spare allowDamage false;
            _spare setVariable ["acex_headless_blacklist",true,true];
            _spare setVariable ["WAIT_CortexQA_Label",format ["FIXED NATIVE PEER / model %1",_row+1],true];
            doStop _spare;
            _actors pushBack _spare;
        };
        private _target = (_house buildingPos -1) param [0,[]];
        private _label = format ["%1 / model %2",_method,_row+1];
        _unit setVariable ["WAIT_CortexQA_Label",_label,true];
        _unit setVariable ["WAIT_CortexQA_Target",_target,true];
        _actors pushBack _unit;
        _cases pushBack [_group,_unit,_house,_target,_method,_label,false];
    } forEach ["DIRECT","HOUSE-WAYPOINT","REPLAN","DIRECT-GO","FORMATION","FORMATION-HINT","COMMAND-FSM","PLACED-LEADER","PLACED-FOLLOWER","ROOM-STOP","ROOM-SPEED"];
} forEach ["Land_i_House_Small_03_V1_F","Land_i_House_Small_01_V1_F","Land_i_House_Big_01_V1_F","Land_i_House_Big_02_V1_F"];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_actors,true];
private _comparisonPosition=if (_cases isNotEqualTo []) then {getPosATL ((_cases select 0) select 2)} else {[16600,12800,0]};
["Building entry: independent comparisons","Excluded soldiers compare direct movement, a building-attached waypoint, leader-planned and formation-planned path replanning, native DirectGo planning, a formation destination hint without replanning, and a native movement command FSM across small and large, single- and multi-storey houses. Cyan trails show actual movement; targets show remaining distance. Matched PLACED controls validate only new audit fixtures before spawning a leader or a follower with a separate stopped commander. Each model reports independently and does not replace the production clearance cases.",_comparisonPosition] call _phase;
{
    _x params ["_group","_unit","_house","_target","_method","_label"];
    private _valid = simulationEnabled _house && {simulationEnabled _unit} && {local _unit} && {_target isNotEqualTo []}
        && {!(_method in ["PLACED-LEADER","ROOM-STOP","ROOM-SPEED"]) || {leader _group == _unit}}
        && {_method != "PLACED-FOLLOWER" || {leader _group != _unit}}
        && {!(_method in ["PLACED-LEADER","PLACED-FOLLOWER","ROOM-STOP","ROOM-SPEED"]) || {count units _group == 2}};
    [format ["BUILD-%1-ready",_label],_valid] call _check;
    if (_valid) then {
        if (_method != "HOUSE-WAYPOINT") then {doStop _unit; [_unit,_target,_method] call _issueNativeComparison} else {
            private _wp = _group addWaypoint [getPosATL _house,0];
            _wp setWaypointType "MOVE";
            _wp waypointAttachObject _house;
            _wp setWaypointHousePosition 0;
            _group setCurrentWaypoint _wp;
        };
    };
} forEach _cases;
private _deadline = time + 90;
waitUntil {
    sleep 2;
    {
        _x params ["_group","_unit","_house","_target","_method","_label"];
        if (_target isNotEqualTo [] && {alive _unit} && {_unit distance _target <= 2}) then {_x set [6,true]};
    } forEach _cases;
    time >= _deadline || {_cases findIf {!(_x select 6)} < 0}
};
{
    _x params ["_group","_unit","_house","_target","_method","_label","_arrived"];
    [format ["BUILD-%1-arrival",_label],_arrived,format ["class=%1 owner=%2 simulation=%3 position=%4 target=%5 command=%6 expected=%7",typeOf _house,groupOwner _group,simulationEnabled _unit,getPosATL _unit,_target,currentCommand _unit,expectedDestination _unit]] call _check;
    if (_method in ["PLACED-LEADER","PLACED-FOLLOWER","ROOM-STOP","ROOM-SPEED"]) then {
        diag_log format ["WAIT NATIVE BUILDING ROLE: %1",[_label,netId _unit,netId leader _group,
            getPosASL _unit,getPosASL leader _group,currentCommand leader _group,
            (units _group) apply {[netId _x,getPosASL _x,currentCommand _x]}]];
    };
} forEach _cases;
// Entry at position zero does not prove that later model nodes are reachable.
// Reuse the isolated native comparison actors to test successive 3D nodes without
// WAIT route ownership, partner assignments or room selection. Skipped nodes remain failures.
private _walkCases=[];
{
    _x params ["_group","_unit","_house","_target","_method","_label"];
    if (_method != "HOUSE-WAYPOINT") then {
        private _nodes=(_house buildingPos -1) select [0,16];
        _walkCases pushBack [_unit,_nodes,0,_nodes apply {false},time,_method,_label,-1,getForcedSpeed _unit];
    };
} forEach _cases;
["Building traversal: independent comparisons","The same excluded actors now attempt successive model positions. Physical 3D arrival is required for each node. A bounded timeout skips a node only to inspect the next; it never marks that node visited or validates WAIT clearance.",_comparisonPosition] call _phase;
private _walkDeadline=time+240;
waitUntil {
    sleep 2;
    {
        _x params ["_unit","_nodes","_cursor","_seen","_issued","_method","_label","_holdUntil","_baselineSpeed"];
        if (_cursor < count _nodes) then {
            private _node=_nodes select _cursor;
            private _arrived=(getPosASL _unit) vectorDistance (AGLToASL _node) <= 1.5;
            if (_arrived || {_holdUntil >= 0} || {time-_issued >= 20}) then {
                if (_arrived) then {_seen set [_cursor,true]};
                if (_arrived && {_holdUntil < 0} && {_method in ["ROOM-STOP","ROOM-SPEED"]}) then {
                    // Isolate the production inter-room hold after actual arrival. No
                    // timeout or hold receipt can mark a missed node visited.
                    if (_method == "ROOM-STOP") then {doStop _unit} else {_unit forceSpeed 0};
                    _x set [7,time+1];
                    _x set [4,time];
                    diag_log format ["WAIT NATIVE ROOM HOLD: %1",[_label,_cursor,getPosASL _unit,currentCommand _unit,getUnitState _unit]];
                } else {
                if (_holdUntil < 0 || {time >= _holdUntil}) then {
                if (_method == "ROOM-SPEED") then {_unit forceSpeed _baselineSpeed};
                _x set [7,-1];
                _cursor=_cursor+1;
                _x set [2,_cursor];
                _x set [4,time];
                if (_cursor < count _nodes) then {
                    private _next=_nodes select _cursor;
                    [_unit,_next,_method] call _issueNativeComparison;
                    _unit setVariable ["WAIT_CortexQA_Target",_next,true];
                    _unit setVariable ["WAIT_CortexQA_Label",format ["%1 / node %2",_label,_cursor],true];

                };
                };
                };
            };
        };
    } forEach _walkCases;
    time >= _walkDeadline || {_walkCases findIf {(_x select 2) < count (_x select 1)} < 0}
};
{
    _x params ["_unit","_nodes","_cursor","_seen","_issued","_method","_label"];
    ["BUILD-TRAVERSE-"+_label,_nodes isNotEqualTo [] && {_seen findIf {!_x} < 0},
        str [_nodes,_seen,getPosATL _unit,currentCommand _unit,expectedDestination _unit,getUnitState _unit,
            _unit getVariable ["WAIT_CortexQA_NativeFsmResult",[]],
            ["NATIVE_MOVE",moveToFailed _unit,moveToCompleted _unit,canMove _unit]]] call _check;
} forEach _walkCases;
// Isolate door state after preserving every original traversal failure. This is
// an explicit native diagnostic, never assistance to the production clearance cases.
private _doorControls=[];
{
    _x params ["_group","_unit","_house","_target","_method","_label"];
    if (_method in ["DIRECT","REPLAN","DIRECT-GO","FORMATION","FORMATION-HINT","COMMAND-FSM"]) then {
        private _walkIndex=_walkCases findIf {(_x select 0) == _unit};
        private _missedIndex=if (_walkIndex >= 0) then {
            ((_walkCases select _walkIndex) select 3) findIf {!_x}
        } else {-1};
        // Select the recorded miss, not a hard-coded room/floor. A fully traversed
        // model has no failure to diagnose and is left unchanged.
        private _node=if (_missedIndex >= 0) then {
            (_house buildingPos -1) param [_missedIndex,[]]
        } else {[]};
        private _doorCount=if (_node isEqualTo []) then {0} else {(getNumber (configOf _house >> "numberOfDoors")) min 16};
        if (_node isNotEqualTo []) then {
            [_unit,_node,_method] call _issueNativeComparison;
            _unit setVariable ["WAIT_CortexQA_Target",_node,true];

            _doorControls pushBack [_unit,_node,_label,false,_doorCount,_house];
        };
    };
} forEach _cases;
// Matched local interaction control precedes the all-open diagnostic. It uses the
// production proximity/floor envelope, but no WAIT controller or actor relocation.
private _localDoorSeen=_doorControls apply {false};
["Building traversal: local door interaction","Native actors retry their first missed point. Only recognized unlocked doors within three metres and on the actor's floor may open. A door opening refreshes that actor's native room request once. Physical arrival remains required; the earlier traversal failures are retained.",_comparisonPosition] call _phase;
private _localDoorDeadline=time+60;
waitUntil {
    sleep 2;
    {
        _x params ["_unit","_node","_label","_arrived","_doorCount","_house"];
        private _opened=false;
        for "_door" from 1 to _doorCount do {
            private _source=format ["Door_%1_sound_source",_door];
            private _memory=_house selectionPosition [format ["Door_%1_trigger",_door],"Memory"];
            private _position=_house modelToWorldWorld _memory;
            private _distance=(getPosASL _unit) vectorDistance _position;
            private _floorDifference=abs (((getPosASL _unit) select 2)-(_position select 2));
            if (_memory isNotEqualTo [0,0,0] && {_house animationSourcePhase _source < 0.1}
                && {(_house getVariable [format ["bis_disabled_Door_%1",_door],0]) isEqualTo 0}
                && {_distance <= 3} && {_floorDifference <= 1.5}) then {
                [_house,_door,1] call BIS_fnc_door;
                _opened=true;
                diag_log format ["WAIT NATIVE LOCAL DOOR: %1",[_label,_door,_distance,_floorDifference,getPosASL _unit,_position]];
            };
        };
        if (_opened) then {
            private _method=(_cases select (_cases findIf {(_x select 1) == _unit})) select 4;
            [_unit,_node,_method] call _issueNativeComparison;
        };
        if ((getPosASL _unit) vectorDistance (AGLToASL _node) <= 1.5) then {_localDoorSeen set [_forEachIndex,true]};
    } forEach _doorControls;
    time >= _localDoorDeadline || {_localDoorSeen findIf {!_x} < 0}
};
{
    _x params ["_unit","_node","_label","_arrived","_doorCount","_house"];
    ["BUILD-LOCAL-DOORS-"+_label,_localDoorSeen select _forEachIndex,str [getPosASL _unit,_node,currentCommand _unit,expectedDestination _unit]] call _check;
    for "_door" from 1 to _doorCount do {
        if ((_house getVariable [format ["bis_disabled_Door_%1",_door],0]) isEqualTo 0) then {[_house,_door,1] call BIS_fnc_door};
    };
    private _method=(_cases select (_cases findIf {(_x select 1) == _unit})) select 4;
    [_unit,_node,_method] call _issueNativeComparison;
} forEach _doorControls;
["Building traversal: native open-door control","Diagnostic only: unlocked doors are explicitly opened on the native comparison houses, then actors retry their first physically missed model node. Original failures remain. Production clearance receives no test-side door assistance.",_comparisonPosition] call _phase;
private _doorDeadline=time+60;
waitUntil {
    sleep 2;
    {
        if ((getPosASL (_x select 0)) vectorDistance (AGLToASL (_x select 1)) <= 1.5) then {_x set [3,true]};
    } forEach _doorControls;
    time >= _doorDeadline || {_doorControls findIf {!(_x select 3)} < 0}
};
{
    _x params ["_unit","_node","_label","_arrived","_doorCount","_house"];
    private _doorPhases=[];
    for "_door" from 1 to _doorCount do {
        _doorPhases pushBack [_door,
            _house animationSourcePhase format ["Door_%1_sound_source",_door],
            _house animationPhase format ["Door_%1_rot",_door],
            _house getVariable [format ["bis_disabled_Door_%1",_door],0]];
    };
    private _doorsOpen=_doorPhases isNotEqualTo []
        && {_doorPhases findIf {((_x select 1) max (_x select 2)) < 0.9} < 0};
    ["BUILD-OPEN-DOORS-FIXTURE-"+_label,_doorsOpen,str _doorPhases] call _check;
    ["BUILD-OPEN-DOORS-"+_label,_arrived && {_doorsOpen},str [_doorPhases,getPosATL _unit,_node,expectedDestination _unit]] call _check;
} forEach _doorControls;
sleep 15;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{_x params ["_group","_unit","_house"]; {deleteVehicle _x} forEach units _group; deleteGroup _group; if (worldName == "VR") then {deleteVehicle _house}} forEach _cases;
if (_nativeOnly && {worldName == "VR"}) then {
    // Controlled diagnostic: same model, direction, flat ground and open doors.
    // Height is the only placement difference; no production object is repositioned.
    private _issueHeightMove={
        params ["_unit","_target","_method"];
        // A deterministic small offset probes node-edge planning without changing
        // the recorded objective or physical acceptance radius.
        private _destination=if (_method == "OFFSET") then {_target vectorAdd [0.35,0.35,0]} else {_target};
        _unit doMove _destination;
        if (_method == "REPLAN") then {_unit setDestination [_target,"LEADER PLANNED",true]}; if (_method == "FORMATION") then {_unit setDestination [_target,"FORMATION PLANNED",true]};
        if (_method == "OFFSET") then {_unit setDestination [_target,"FORMATION PLANNED",false]};
    };
    private _heightCases=[];
    {
        private _fixtureClass=_x;
        private _modelRow=_forEachIndex;
        {
        private _height=_x;
        private _row=_modelRow*3+_forEachIndex;
        {
            private _method=_x;
            private _house=createVehicle [_fixtureClass,[6250+_forEachIndex*60,6120+_row*60,0],[],0,"NONE"];
            _house setDir 0;
            _house setPosATL [6250+_forEachIndex*60,6120+_row*60,_height];
            private _label=format ["HEIGHT-%1-%2-%3",_fixtureClass,_height,_method];
            [_house,_label] call _recordFixture;
            private _doorCount=(getNumber (configOf _house >> "numberOfDoors")) min 16;
            private _doorPhases=[];
            for "_door" from 1 to _doorCount do {
                {
                    private _source=format ["Door_%1_%2_source",_door,_x];
                    if (isClass (configOf _house >> "AnimationSources" >> _source)) then {
                        _house animateSource [_source,1,true];
                        _doorPhases pushBack [_door,_source,_house animationSourcePhase _source];
                    };
                } forEach ["sound","noSound"];
            };
            ["BUILD-PLACEMENT-DOORS-"+_label,_doorPhases isNotEqualTo []
                && {_doorPhases findIf {(_x select 2) < 0.9} < 0},str [_doorCount,_doorPhases]] call _check;
            private _group=createGroup [east,true];
            private _unit=_group createUnit ["O_Soldier_F",_house getPos [25,180],[],0,"NONE"];
            _unit allowDamage false;
            _unit setVariable ["WAIT_CortexQA_Label",_label,true];
            private _nodes=(_house buildingPos -1) select [0,16];
            private _target=_nodes param [0,[]];
            _unit setVariable ["WAIT_CortexQA_Target",_target,true];
            [_unit,_target,_method] call _issueHeightMove;
            _heightCases pushBack [_group,_unit,_house,_nodes,0,_nodes apply {false},time,_method,_label];
        } forEach ["DIRECT","REPLAN","OFFSET"];
        } forEach [0,0.3,0.6];
    } forEach ["Land_i_House_Small_01_V1_F","Land_i_House_Big_01_V1_F","Land_i_House_Big_02_V1_F"];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",_heightCases apply {_x select 1},true];
    ["Building entry: controlled placement height","Diagnostic only: identical houses at 0, 0.3 and 0.6 metres, all doors open. Each actor attempts every model node. Failed nodes remain unvisited when the bounded diagnostic advances. Raised houses test access clearance; they are not a production remedy. OFFSET uses a small deterministic move offset with the original room-node hint; visits still require arrival at the original node.",[6250,6120,0]] call _phase;
    private _heightDeadline=time+240;
    waitUntil {
        sleep 2;
        {
            _x params ["_group","_unit","_house","_nodes","_cursor","_seen","_issued","_method","_label"];
            if (_cursor < count _nodes) then {
                private _target=_nodes select _cursor;
                private _arrived=(getPosASL _unit) vectorDistance (AGLToASL _target) <= 1.5;
                if (_arrived || {time-_issued >= 20}) then {
                    if (_arrived) then {_seen set [_cursor,true]};
                    _x set [6,time];
                    _cursor=_cursor+1;
                    _x set [4,_cursor];
                    if (_cursor < count _nodes) then {
                        _target=_nodes select _cursor;
                        [_unit,_target,_method] call _issueHeightMove;
                        _unit setVariable ["WAIT_CortexQA_Target",_target,true];
                    };
                };
            };
        } forEach _heightCases;
        time >= _heightDeadline || {_heightCases findIf {(_x select 4) < count (_x select 3)} < 0}
    };
    {
        _x params ["_group","_unit","_house","_nodes","_cursor","_seen","_issued","_method","_label"];
        ["BUILD-PLACEMENT-"+_label,_seen isNotEqualTo [] && {_seen findIf {!_x} < 0},str [_nodes,_seen,getPosATL _unit,expectedDestination _unit]] call _check;
    } forEach _heightCases;
    // Preserve first-pass failures before testing whether approach order caused them.
    // Revisit failed nodes once from the actor's final physical position; never teleport.
    private _revisitCases=[];
    {
        _x params ["_group","_unit","_house","_nodes","_cursor","_seen","_issued","_method","_label"];
        private _failedNodes=[];
        {if (!_x) then {_failedNodes pushBack (_nodes select _forEachIndex)}} forEach _seen;
        if (_failedNodes isNotEqualTo []) then {
            _revisitCases pushBack [_unit,_failedNodes,0,_failedNodes apply {false},time,_method,_label];
            [_unit,_failedNodes select 0,_method] call _issueHeightMove;
            _unit setVariable ["WAIT_CortexQA_Target",_failedNodes select 0,true];
        };
    } forEach _heightCases;
    ["Building traversal: failed-node revisit","Original failures remain recorded. Actors revisit missed nodes once from their actual final position, testing approach order. Only physical arrival can pass; no actor relocation or production route assistance is applied.",[6250,6120,0]] call _phase;
    private _revisitDeadline=time+180;
    waitUntil {
        sleep 1;
        {
            _x params ["_unit","_nodes","_cursor","_seen","_issued","_method","_label"];
            if (_cursor < count _nodes) then {
                private _arrived=(getPosASL _unit) vectorDistance (AGLToASL (_nodes select _cursor)) <= 1.5;
                if (_arrived || {time-_issued >= 20}) then {
                    if (_arrived) then {_seen set [_cursor,true]};
                    _cursor=_cursor+1;
                    _x set [2,_cursor]; _x set [4,time];
                    if (_cursor < count _nodes) then {
                        [_unit,_nodes select _cursor,_method] call _issueHeightMove;
                        _unit setVariable ["WAIT_CortexQA_Target",_nodes select _cursor,true];
                    };
                };
            };
        } forEach _revisitCases;
        time >= _revisitDeadline || {_revisitCases findIf {(_x select 2) < count (_x select 1)} < 0}
    };
    {
        _x params ["_unit","_nodes","_cursor","_seen","_issued","_method","_label"];
        ["BUILD-REVISIT-"+_label,_seen findIf {!_x} < 0,str [_nodes,_seen,getPosATL _unit,expectedDestination _unit]] call _check;
    } forEach _revisitCases;
    sleep 10;
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
    {_x params ["_group","_unit","_house"]; deleteVehicle _unit; deleteGroup _group; deleteVehicle _house} forEach _heightCases;
};
};
if (_nativeOnly) exitWith {};

if (!_transformOnly) then {
// Observer negative control: spawn outside, verify the live wall/proximity
// prerequisite, then query the independent observer. This is not production admission.
private _wallHouse=createVehicle ["Land_i_House_Big_02_V1_F",[6350,6000,0],[],0,"NONE"];
_wallHouse enableSimulationGlobal true;
[_wallHouse,"wall-control"] call _validateNewFixturePlacement;
private _wallBounds=boundingBoxReal _wallHouse;
private _wallCandidate=[];
private _wallSearch=[0,0,0,0,1e12,1e12]; // samples, distance rejects, floor rejects, clear rays, closest, floor delta
{
    if (_wallCandidate isNotEqualTo []) exitWith {};
    private _room=_x;
    // Bound the search around real room nodes. Model bounds include roofs/steps
    // and cannot establish whether a nearby supported point lies beyond a wall.
    private _edges=[];
    for "_bearing" from 0 to 330 step 30 do {_edges pushBack (_room getPos [1.25,_bearing])};
    {
        private _outside=+_x;
        private _targetASL=AGLToASL _room;
        private _probe=AGLToASL _outside;
        private _support=lineIntersectsSurfaces [_probe vectorAdd [0,0,1],_probe vectorAdd [0,0,-2],objNull,objNull,true,1,"GEOM","NONE"];
        private _pose=if (_support isNotEqualTo [] && {(((_support select 0) select 1) select 2) >= 0.7}) then {
            +((_support select 0) select 0)
        } else {[_probe select 0,_probe select 1,getTerrainHeightASL _outside]};
        _outside=ASLToAGL _pose;
        private _target=AGLToASL _room;
        private _distance=_pose vectorDistance _target;
        private _floorDelta=abs ((_pose select 2)-(_target select 2));
        _wallSearch set [0,(_wallSearch select 0)+1];
        _wallSearch set [4,(_wallSearch select 4) min _distance];
        _wallSearch set [5,(_wallSearch select 5) min _floorDelta];
        if (_distance > 1.5) then {_wallSearch set [1,(_wallSearch select 1)+1]};
        if (_floorDelta > 0.75) then {_wallSearch set [2,(_wallSearch select 2)+1]};
        if (_distance <= 1.5 && {_floorDelta <= 0.75}) then {
            private _hits=lineIntersectsSurfaces [_pose vectorAdd [0,0,0.6],_target vectorAdd [0,0,0.6],objNull,objNull,true,8,"GEOM","NONE"];
            if (_hits findIf {(_x select 2) == _wallHouse || {(_x select 3) == _wallHouse}} >= 0) exitWith {_wallCandidate=[_outside,_room]};
            _wallSearch set [3,(_wallSearch select 3)+1];
        };
    } forEach _edges;
} forEach ((_wallHouse buildingPos -1) select [0,16]);
diag_log format ["WAIT WALL CONTROL SEARCH: model=%1 bounds=%2 rooms=%3 search=%4 candidate=%5",typeOf _wallHouse,_wallBounds,_wallHouse buildingPos -1,_wallSearch,_wallCandidate];
private _wallGroup=createGroup [east,true];
_wallGroup setVariable ["WAIT_AI_Exclude",true,true];
_wallGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_wallGroup setVariable ["acex_headless_blacklist",true,true];
private _wallActor=objNull;
private _wallPrerequisite=false;
if (_wallCandidate isNotEqualTo []) then {
    _wallActor=_wallGroup createUnit ["O_Soldier_F",_wallCandidate select 0,[],0,"NONE"];
    // Initial placement of an excluded negative-control actor only. Native spawn grid
    // snapping can move it outside the proximity prerequisite; settlement is checked below.
    _wallActor setPosASL (AGLToASL (_wallCandidate select 0));
    doStop _wallActor;
    _wallActor setVariable ["WAIT_CortexQA_Label","EXTERIOR WALL OBSERVER CONTROL",true];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[_wallActor],true];
    ["Room observer: exterior-wall control","This excluded actor spawns outside a house. The live pose must be close enough to satisfy the old distance/floor rule with an intervening wall. The independent observer must reject it. This does not validate production movement or room safety.",getPosATL _wallHouse] call _phase;
    // Allow native spawn/physics settlement; elapsed time grants no prerequisite.
    sleep 2;
    private _actual=getPosASL _wallActor;
    private _target=AGLToASL (_wallCandidate select 1);
    // The settled actor must actually be outside; the wall ray below independently
    // proves separation from the room rather than treating proximity as entry.
    private _outside=insideBuilding _wallActor == 0;
    private _hits=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.6],_target vectorAdd [0,0,0.6],_wallActor,objNull,true,8,"GEOM","NONE"];
    _wallPrerequisite=_outside && {_actual vectorDistance _target <= 1.5}
        && {abs ((_actual select 2)-(_target select 2)) <= 0.75}
        && {_hits findIf {(_x select 2) == _wallHouse || {(_x select 3) == _wallHouse}} >= 0};
};
["CLEAR-observer-wall-prerequisite",_wallPrerequisite,str [_wallCandidate,getPosATL _wallActor]] call _check;
["CLEAR-observer-wall-rejected",_wallPrerequisite && {!([_wallActor,_wallHouse,_wallCandidate select 1] call _observedRoomVisit)}] call _check;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
if (!isNull _wallActor) then {deleteVehicle _wallActor};
deleteGroup _wallGroup;
deleteVehicle _wallHouse;
// Additive normal-owner overflow acceptance; connected HCs cannot masquerade as owner coverage.
if (!_largeOnly && {!(missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false])}) then {
    private _site=[6350,5500,0];
    private _securityHouse=createVehicle ["Land_i_House_Small_01_V1_F",_site,[],0,"NONE"];
    _securityHouse enableSimulationGlobal true;
    [_securityHouse,"garrison-surplus"] call _validateNewFixturePlacement;
    [_securityHouse,"garrison-surplus"] call _recordFixture;
    private _capacity=count (_securityHouse buildingPos -1);
    private _fixtureReady=_capacity > 0 && {_capacity <= 8}
        && {((nearestObjects [_site,["House"],50,true])-[_securityHouse]) isEqualTo []};
    ["GARRISON-surplus-capacity-prerequisite",_fixtureReady,str [_capacity,getPosATL _securityHouse]] call _check;
    if (_fixtureReady) then {
        private _securityGroup=createGroup [east,true];
        _securityGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
        _securityGroup setVariable ["acex_headless_blacklist",true,true];
        private _members=[];
        for "_index" from 0 to (_capacity+1) do {
            private _actor=_securityGroup createUnit ["O_Soldier_F",_site vectorAdd [-12+(_index mod 4)*4,-35-floor(_index/4)*4,0],[],0,"NONE"];
            _actor setVariable ["WAIT_CortexQA_Label",format ["GARRISON / soldier %1",_index+1],true];
            _members pushBack _actor;
        };
        missionNamespace setVariable ["WAIT_CortexQA_Actors",_members,true];
        ["Garrison surplus security","This navigation/occupation case has two more soldiers than interior positions. Interior actors must physically occupy their posts; both surplus actors must reach distinct exterior positions and actually observe an exit approach. Labels and accepted assignments do not pass. No actor relocation, door assistance or completion injection is applied.",getPosATL _securityHouse] call _phase;
        private _accepted=[_securityGroup,getPosATL _securityHouse,20] call WAIT_fnc_CortexGarrison;
        ["GARRISON-surplus-order-accepted",_accepted] call _check;
        private _observedAll={
            private _exterior=0;
            private _valid=true;
            {
                private _actor=_x;
                private _assignment=_actor getVariable ["WAIT_AIPass_GarrisonPos",[]];
                private _purpose=_assignment param [4,"INTERIOR"];
                if (_assignment isEqualTo [] || {_actor getVariable ["WAIT_AIPass_GarrisonFailed",false]}) then {_valid=false} else {
                    if (_purpose == "INTERIOR") then {
                        if !([_actor,_securityHouse,_assignment select 0] call _observedRoomVisit) then {_valid=false};
                    } else {
                        if (_purpose != "EXTERIOR" || {count _assignment < 7}) then {_valid=false} else {
                            _exterior=_exterior+1;
                            private _watch=_assignment select 5;
                            private _bounds=boundingBoxReal _securityHouse;
                            private _pose=_securityHouse worldToModel (getPosATL _actor);
                            private _low=_bounds select 0;
                            private _high=_bounds select 1;
                            private _outside=(_pose select 0) < (_low select 0)-0.5 || {(_pose select 0) > (_high select 0)+0.5}
                                || {(_pose select 1) < (_low select 1)-0.5} || {(_pose select 1) > (_high select 1)+0.5};
                            private _heading=abs (((getDir _actor-(_actor getDir _watch)+540) mod 360)-180);
                            private _visible=!terrainIntersectASL [eyePos _actor,AGLToASL _watch]
                                && {(lineIntersectsSurfaces [eyePos _actor,AGLToASL _watch,_actor,objNull,true,1,"VIEW","NONE"]) isEqualTo []};
                            if (!_outside || {(getPosASL _actor) vectorDistance (AGLToASL (_assignment select 0)) > 2}
                                || {_heading > 75} || {!_visible} || {_actor distance2D (_assignment select 6) < 3}
                                || {_members findIf {_x != _actor && {_x distance2D _actor < 2.5}} >= 0}) then {_valid=false};
                        };
                    };
                };
            } forEach _members;
            _valid && {_exterior == 2}
        };
        private _occupied=[{call _observedAll},150] call _wait;
        {
            private _assignment=_x getVariable ["WAIT_AIPass_GarrisonPos",[]];
            diag_log format ["WAIT GARRISON SURPLUS ACTOR: %1",[netId _x,getPosASL _x,currentCommand _x,
                _x checkAIFeature "PATH",_x getVariable ["WAIT_AIPass_GarrisonFailed",false],_assignment]];
        } forEach _members;
        ["GARRISON-surplus-all-physical-roles",_occupied,str (_members apply {[netId _x,getPosATL _x,_x getVariable ["WAIT_AIPass_GarrisonPos",[]],_x getVariable ["WAIT_AIPass_GarrisonFailed",false]]})] call _check;
        private _poses=_members apply {getPosATL _x};
        sleep 5;
        private _held=true;
        {if (_x distance (_poses select _forEachIndex) > 1) then {_held=false}} forEach _members;
        ["GARRISON-surplus-stable-observation",_occupied && {call _observedAll} && {_held}] call _check;
        ["GARRISON-surplus-finite-search",_members findIf {(_x getVariable ["WAIT_Cortex_GarrisonExteriorAttempts",0]) > 3} < 0] call _check;
        // Real incoming-fire posture test on a physically occupied exterior post. This does not
        // call the duck handler or assign suppression/expiry state. No reaction is inferred from labels.
        private _postIndex=_members findIf {
            ((_x getVariable ["WAIT_AIPass_GarrisonPos",[]]) param [4,""]) == "EXTERIOR"
                && {unitPos _x != "DOWN"}
        };
        ["GARRISON-duck-live-prerequisite",_occupied && {_postIndex >= 0}] call _check;
        if (_occupied && {_postIndex >= 0}) then {
            private _defender=_members select _postIndex;
            private _priorPosture=unitPos _defender;
            private _assignment=+(_defender getVariable ["WAIT_AIPass_GarrisonPos",[]]);
            private _watch=_assignment select 5;
            private _attackPosition=_defender getPos [35,_defender getDir _watch];
            private _damagePolicies=_members apply {isDamageAllowed _x};
            {_x allowDamage false} forEach _members;
            private _attackGroup=createGroup [west,true];
            _attackGroup setVariable ["WAIT_AIPass_Exclude",true,true];
            _attackGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
            _attackGroup setVariable ["acex_headless_blacklist",true,true];
            private _attacker=_attackGroup createUnit ["B_Soldier_F",_attackPosition,[],0,"NONE"];
            _attacker allowDamage false;
            _attacker disableAI "PATH";
            _attacker setVariable ["acex_headless_blacklist",true,true];
            _attacker setVariable ["WAIT_CortexQA_PostureShots",0];
            _attacker addEventHandler ["FiredMan",{
                params ["_actor"];
                _actor setVariable ["WAIT_CortexQA_PostureShots",(_actor getVariable ["WAIT_CortexQA_PostureShots",0])+1];
            }];
            _attacker setDir (_attacker getDir _defender);
            _attackGroup setCombatMode "RED";
            _attacker setUnitCombatMode "RED";
            _attacker doTarget _defender;
            _attacker doFire _defender;
            missionNamespace setVariable ["WAIT_CortexQA_Actors",_members+[_attacker],true];
            ["Garrison posture under fire","Diagnostic invulnerable actors: a real hostile rifleman fires at an occupied exterior post. Require actual shots and the production duck reaction, followed by restoration of the prior posture. A second real burst must trigger a fresh reaction before a newer explicit stance order tests delayed recovery. No handler, suppression or completion state is injected.",getPosATL _defender] call _phase;
            private _ducked=[{
                (_attacker getVariable ["WAIT_CortexQA_PostureShots",0]) > 0
                    && {(_defender getVariable ["WAIT_AIPass_DuckUntil",-1]) > time}
                    && {(_defender getVariable ["WAIT_Cortex_GarrisonDuckStance",""]) != ""}
            },25] call _wait;
            private _shotCount=_attacker getVariable ["WAIT_CortexQA_PostureShots",0];
            private _until=_defender getVariable ["WAIT_AIPass_DuckUntil",-1];
            ["GARRISON-duck-real-fire",_ducked && {_shotCount > 0},str [_shotCount,_priorPosture,unitPos _defender,_until]] call _check;
            // Stop the hostile's real firing, without writing any defender recovery state.
            _attackGroup setCombatMode "BLUE";
            _attacker setUnitCombatMode "BLUE";
            _attacker doTarget objNull;
            private _recovered=false;
            if (_ducked) then {
                sleep 1;
                _until=_defender getVariable ["WAIT_AIPass_DuckUntil",_until];
                [{time > _until+1},12] call _wait;
                _recovered=time > _until && {unitPos _defender == _priorPosture}
                    && {(_defender getVariable ["WAIT_AIPass_GarrisonPos",[]]) isEqualTo _assignment};
            };
            ["GARRISON-duck-restores-prior-posture",_ducked && {_recovered},
                str [_priorPosture,unitPos _defender,_until]] call _check;
            // A fresh live burst must trigger the replacement case independently. Prior shots
            // and the expired first duck cannot satisfy this prerequisite.
            private _secondShotBaseline=_attacker getVariable ["WAIT_CortexQA_PostureShots",0];
            _attackGroup setCombatMode "RED";
            _attacker setUnitCombatMode "RED";
            _attacker doTarget _defender;
            _attacker doFire _defender;
            private _secondDuck=[{
                (_attacker getVariable ["WAIT_CortexQA_PostureShots",0]) > _secondShotBaseline
                    && {(_defender getVariable ["WAIT_AIPass_DuckUntil",-1]) > time}
                    && {(_defender getVariable ["WAIT_AIPass_DuckUntil",-1]) > _until}
                    && {(_defender getVariable ["WAIT_Cortex_GarrisonDuckStance",""]) != ""}
            },25] call _wait;
            _until=_defender getVariable ["WAIT_AIPass_DuckUntil",-1];
            ["GARRISON-duck-repeat-real-fire",_secondDuck,
                str [_secondShotBaseline,_attacker getVariable ["WAIT_CortexQA_PostureShots",0],_until]] call _check;
            deleteVehicle _attacker;
            deleteGroup _attackGroup;
            if (_secondDuck) then {
                // This is the deliberate replacement input, never the expected completion state.
                _defender setUnitPos "UP";
                private _replacementAt=time;
                [{time > _until+1},12] call _wait;
                ["GARRISON-duck-preserves-new-stance",time > _until && {unitPos _defender == "UP"}
                    && {(_defender getVariable ["WAIT_AIPass_GarrisonPos",[]]) isEqualTo _assignment},
                    str [_replacementAt,_until,unitPos _defender]] call _check;
            } else {
                ["GARRISON-duck-preserves-new-stance",false,"No real duck reaction; replacement case not exercised"] call _check;
            };
            {_x allowDamage (_damagePolicies select _forEachIndex)} forEach _members;
            missionNamespace setVariable ["WAIT_CortexQA_Actors",_members,true];
        };
        [_securityGroup] call WAIT_fnc_CortexGarrisonRelease;
        private _origins=_members apply {getPosATL _x};
        private _wp=_securityGroup addWaypoint [_site vectorAdd [75,-35,0],0];
        _wp setWaypointType "MOVE";
        private _departed=[{_members findIf {_x distance2D (_origins select (_members find _x)) < 20} < 0},60] call _wait;
        ["GARRISON-surplus-ordinary-handover",_departed && {_members findIf {!(_x checkAIFeature "PATH")
            || {(_x getVariable ["WAIT_AIPass_GarrisonPos",[]]) isNotEqualTo []}} < 0}] call _check;
        missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
        {deleteVehicle _x} forEach _members;
        deleteGroup _securityGroup;
    };
    deleteVehicle _securityHouse;
};
// Separate headless-batch acceptance: a real owner transfer during physical egress.
// Normal-owner fixtures below retain their original server-local assertions.
if (!_largeOnly && {missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false]}) then {
    [{count (missionNamespace getVariable ["WAIT_Headless_Clients",[]]) >= 2},30] call _wait;
    private _owners=(missionNamespace getVariable ["WAIT_Headless_Clients",[]]) apply {_x select 0};
    ["HC-CLEAR-EGRESS-two-registered",count _owners >= 2] call _check;
    if (count _owners >= 2) then {
        private _site=[6400,5400,0];
        private _house=createVehicle ["Land_i_House_Big_02_V1_F",_site,[],0,"NONE"];
        _house enableSimulationGlobal true;
        [_house,"hc-egress"] call _validateNewFixturePlacement;
        [_house,"hc-egress"] call _recordFixture;
        private _group=createGroup [east,true];
        _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
        _group setVariable ["acex_headless_blacklist",true,true];
        private _members=[];
        for "_i" from 0 to 3 do {
            private _unit=_group createUnit ["O_Soldier_F",_site vectorAdd [-12+4*_i,-35,0],[],0,"NONE"];
            _unit setVariable ["acex_headless_blacklist",true,true];
            _unit setVariable ["WAIT_CortexQA_Label",format ["HC EXIT TRANSFER / soldier %1",_i+1],true];
            _members pushBack _unit;
        };
        missionNamespace setVariable ["WAIT_CortexQA_Actors",_members,true];
        ["HC clearance: owner transfer during exit","A fresh four-soldier group clears a multi-storey house. Ownership transfers to a real HC during egress while workers still await exit planning inside the house. Original exit destinations, deadline and consumed retries must survive, followed by actual exit and ordinary movement. No actor relocation, door assistance, freezing or completion injection is applied.",_site] call _phase;
        private _accepted=[_group,_house] call WAIT_fnc_CortexClearBuilding;
        ["HC-CLEAR-EGRESS-order-accepted",_accepted] call _check;
        private _rooms=_house buildingPos -1;
        private _visits=_members apply {[]};
        private _before=[];
        private _midExit=[{
            {
                private _actor=_x;
                private _visited=_visits select _forEachIndex;
                {if ([_actor,_house,_x] call _observedRoomVisit) then {_visited pushBackUnique _forEachIndex}} forEach _rooms;
            } forEach _members;
            private _journal=_group getVariable ["WAIT_Cortex_ClearEgress",[]];
            private _inside=false;
            if (count _journal in [10,13]) then {
                private _bounds=boundingBoxReal _house;
                {
                    private _actor=_x select 0;
                    private _pose=_house worldToModel (getPosATL _actor);
                    private _low=_bounds select 0;
                    private _high=_bounds select 1;
                    if (!(_x select 2) && {currentCommand _actor == "MOVE"}
                        && {(_pose select 0) > (_low select 0)} && {(_pose select 0) < (_high select 0)}
                        && {(_pose select 1) > (_low select 1)} && {(_pose select 1) < (_high select 1)}
                        && {(_pose select 2) > (_low select 2)} && {(_pose select 2) < (_high select 2)}) then {_inside=true};
                } forEach (_journal select 3);
                // Pending-only egress is a real migration boundary too. Observe the actual
                // actor inside the house; no fixture timer or injected movement creates it.
                if (count _journal == 13 && {(_journal select 10) == 2}
                    && {(_journal select 11) isNotEqualTo []}) then {
                    {
                        private _actor=_x select 0;
                        private _pose=_house worldToModel (getPosATL _actor);
                        private _low=_bounds select 0;
                        private _high=_bounds select 1;
                        if ((_pose select 0) > (_low select 0) && {(_pose select 0) < (_high select 0)}
                            && {(_pose select 1) > (_low select 1)} && {(_pose select 1) < (_high select 1)}
                            && {(_pose select 2) > (_low select 2)} && {(_pose select 2) < (_high select 2)}) then {_inside=true};
                    } forEach (_journal select 11);
                } else {_inside=false};
                if (_inside) then {_before=+_journal};
            };
            _inside || {((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE","CANCELLED"]}
        },300] call _wait;
        ["HC-CLEAR-EGRESS-physical-mid-exit",_midExit && {count _before in [10,13]},str [_before,_visits]] call _check;
        if (count _before in [10,13]) then {
            private _pendingBefore=+(_before select 11);
            private _expectedActors=((_before select 3)+_pendingBefore) apply {_x select 0};
            private _rosterComplete=count _expectedActors == count _members
                && {count (_expectedActors arrayIntersect _expectedActors) == count _members}
                && {_members findIf {!(_x in _expectedActors)} < 0};
            ["HC-CLEAR-EGRESS-pending-observed",_pendingBefore isNotEqualTo [] && {_rosterComplete},
                str [_pendingBefore,_expectedActors]] call _check;
            private _targets=(_before select 3) apply {[_x select 0,+(_x select 1),_x select 4]};
            private _exitVisits=_targets apply {false};
            private _transferAt=serverTime;
            private _owner=_owners select 0;
            _group setVariable ["WAIT_Headless_ExcludeGroup",false,true];
            private _requested=[_group,_owner] call WAIT_fnc_HeadlessMigrateGroup;
            private _adopted=[{
                private _state=_group getVariable ["WAIT_BuildingBrain_State",[]];
                groupOwner _group == _owner && {count _state >= 4}
                    && {(_state select 0) == "EGRESS"} && {(_state select 3) > _transferAt}
            },20] call _wait;
            ["HC-CLEAR-EGRESS-owner-adopted",_requested && {_adopted},str [groupOwner _group,_owner,_group getVariable ["WAIT_BuildingBrain_State",[]]]] call _check;
            private _preserved=true;
            private _seenReplay=false;
            private _terminal=[{
                private _journal=_group getVariable ["WAIT_Cortex_ClearEgress",[]];
                if (count _journal in [10,13] && {groupOwner _group == _owner}) then {
                    _seenReplay=true;
                    if ((_journal select 7) != (_before select 7) || {(_journal select 6) != (_before select 6)}
                        || {(_journal select 5) isNotEqualTo (_before select 5)}) then {_preserved=false};
                    private _pending=if (count _journal == 13) then {_journal select 11} else {[]};
                    private _currentActors=((_journal select 3)+_pending) apply {_x select 0};
                    if (count _currentActors != count _expectedActors
                        || {count (_currentActors arrayIntersect _currentActors) != count _expectedActors}
                        || {_expectedActors findIf {!(_x in _currentActors)} >= 0}) then {_preserved=false};
                    // Every pending worker must retain its original leg until allocated.
                    // Afterwards preserve the selected target/retry record and observe its exit.
                    {
                        _x params ["_actor","_leg"];
                        private _waiting=_pending select {(_x select 0) == _actor};
                        if (_waiting isNotEqualTo []) then {
                            if (count _waiting != 1 || {((_waiting select 0) select 1) isNotEqualTo _leg}) then {_preserved=false};
                        };
                    } forEach _pendingBefore;
                    {
                        private _actor=_x select 0;
                        if (_targets findIf {(_x select 0) == _actor} < 0) then {
                            _targets pushBack [_actor,+(_x select 1),_x select 4];
                            _exitVisits pushBack false;
                        };
                    } forEach (_journal select 3);
                    {
                        _x params ["_actor","_target","_retries"];
                        private _rows=(_journal select 3) select {(_x select 0) == _actor};
                        if (count _rows != 1) then {_preserved=false} else {
                            private _row=_rows select 0;
                            if ((_row select 1) isNotEqualTo _target || {(_row select 4) < _retries}
                                || {(_row select 4) > 1}) then {_preserved=false};
                        };
                    } forEach _targets;
                };
                {
                    _x params ["_actor","_target"];
                    if ([_actor,_house,_target] call _observedExit) then {
                        _exitVisits set [_forEachIndex,true];
                    };
                } forEach _targets;
                ((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE","CANCELLED"]
            },(((_before select 7)-serverTime+8) max 0) min 55] call _wait;
            ["HC-CLEAR-EGRESS-journal-preserved",_seenReplay && {_preserved} && {_rosterComplete},str [_before,_group getVariable ["WAIT_Cortex_ClearEgress",[]]]] call _check;
            ["HC-CLEAR-EGRESS-physical-complete",_terminal && {_rosterComplete} && {count _targets == count _expectedActors}
                && {_exitVisits findIf {!_x} < 0}
                && {((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) == "COMPLETE"}
                && {_visits findIf {count _x < 2} < 0},str [_exitVisits,_visits,_group getVariable ["WAIT_Cortex_ClearResult",[]]]] call _check;
            [_group,2] call WAIT_fnc_HeadlessMigrateGroup;
            private _returned=[{local _group},20] call _wait;
            ["HC-CLEAR-EGRESS-return-server",_returned] call _check;
            if (_returned) then {
                _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
                private _departure=_members apply {getPosATL _x};
                private _destination=_site vectorAdd [75,-35,0];
                private _waypoint=_group addWaypoint [_destination,0];
                _waypoint setWaypointType "MOVE";
                _group setCurrentWaypoint _waypoint;
                private _handedBack=[{
                    private _allMoved=leader _group distance2D _destination <= 20;
                    {
                        if (!alive _x || {_x distance2D (_departure select _forEachIndex) < 20}) then {_allMoved=false};
                    } forEach _members;
                    _allMoved
                },75] call _wait;
                ["HC-CLEAR-EGRESS-successor-physical",_handedBack,
                    str (_members apply {[netId _x,getPosATL _x,currentCommand _x]})] call _check;
            };
        };
        if (local _group) then {[_group] call WAIT_fnc_CortexClearRelease};
        missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
        {deleteVehicle _x} forEach _members;
        deleteGroup _group;
        deleteVehicle _house;
    };
};

// Fresh groups distinguish clearance defects from state left by a previous garrison.
// Keep all original comparisons above, including their failures.
{
    _x params ["_size","_class"];
    private _site=[6550+_forEachIndex*200,5800,0];
    private _house=createVehicle [_class,_site,[],0,"NONE"];
    _house enableSimulationGlobal true;
    [_house,format ["fresh-%1",_size]] call _validateNewFixturePlacement;
    [_house,format ["fresh-%1",_size]] call _recordFixture;
    private _otherBuildings=(nearestObjects [_site,["House"],50,true])-[_house];
    [format ["CLEAR-fresh-%1-site-isolated",_size],_otherBuildings isEqualTo [],str [_site,_otherBuildings]] call _check;
    private _group=createGroup [east,true];
    _group setVariable ["WAIT_Cortex_ClearCaptureEntry",true];
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    private _members=[];
    for "_i" from 0 to (_size-1) do {
        private _unit=_group createUnit ["O_Soldier_F",_site vectorAdd [-15+(_i mod 4)*4,-40-floor(_i/4)*4,0],[],0,"NONE"];
        _unit setVariable ["acex_headless_blacklist",true,true];
        _unit setVariable ["WAIT_CortexQA_Label",format ["FRESH CLEAR %1 / soldier %2",_size,_i+1],true];
        _members pushBack _unit;
    };
    missionNamespace setVariable ["WAIT_CortexQA_Actors",_members,true];
    [format ["Fresh clearance: %1 soldiers / %2",_size,_class],"This new audit house has bounded placement validation before actors spawn. This fresh group has never garrisoned. Watch clearing pairs physically enter and continue through their assigned sector. The 2/6/12-person cases use progressively larger building models; a separate four-person case uses the same large model as the twelve-person case to distinguish building routing from concurrency. Markers are navigation positions, not proof that a hostile room is safe. No test-side teleport, door opening or forced completion is applied.",getPosATL _house] call _phase;
    private _allRooms=_house buildingPos -1;
    private _rooms=_allRooms select {
        private _origin=AGLToASL _x;
        (lineIntersectsSurfaces [_origin vectorAdd [0,0,0.5],_origin vectorAdd [0,0,10],objNull,objNull,true,1]) isNotEqualTo []
    };
    // Preserve all-position evidence independently of the production operation's claimed visits.
    private _exteriorRooms=_allRooms select {!(_x in _rooms)};
    private _exteriorVisits=_exteriorRooms apply {false};
    private _visits=_rooms apply {false};
    [format ["CLEAR-fresh-%1-interior-fixture",_size],_rooms isNotEqualTo [],
        str [typeOf _house,count _rooms,count _exteriorRooms]] call _check;
    // Every committed soldier, including the leader, owns a production clearance lane.
    // Audit exactly that set rather than preserving the superseded exterior-leader assumption.
    private _clearingMembers=+_members;
    private _memberVisits=_clearingMembers apply {[]};
    // Reuse the existing independent physical visit collector; add no geometry queries.
    private _entryTimingStart=diag_tickTime;
    private _memberFirstVisit=_clearingMembers apply {-1};
    private _reserveStageVisits=[];
    private _reserveObservationVisits=[];
    private _originalAttack=attackEnabled leader _group;
    private _originalSpeedLimits=_members apply {getForcedSpeed _x};
    // Observe the real actor's native route; do not spawn a predictive agent or alter its path.
    private _pathHandlers=[];
    {
        _x setVariable ["WAIT_CortexQA_PathCount",0];
        _x setVariable ["WAIT_CortexQA_PathNextAt",0];
        private _id=_x addEventHandler ["PathCalculated",{
            params ["_unit","_path"];
            if (!((group _unit) getVariable ["WAIT_AIPass_ClearBuilding",false])
                || {time < (_unit getVariable ["WAIT_CortexQA_PathNextAt",0])}
                || {(_unit getVariable ["WAIT_CortexQA_PathCount",0]) >= 24}) exitWith {};
            _unit setVariable ["WAIT_CortexQA_PathNextAt",time+8];
            _unit setVariable ["WAIT_CortexQA_PathCount",(_unit getVariable ["WAIT_CortexQA_PathCount",0])+1];
            diag_log format ["WAIT CLEAR NATIVE PATH: %1",[serverTime,netId _unit,getPosASL _unit,
                currentCommand _unit,expectedDestination _unit,count _path,_path select [0,24],
                _path param [((count _path)-1) max 0,[]],insideBuilding _unit,
                ["ACTOR_ATL",getPosATL _unit,"EXPECTED_ASL",AGLToASL ((expectedDestination _unit) select 0),
                    "TERRAIN_ASL",getTerrainHeightASL (getPosATL _unit)]]];
        }];
        _pathHandlers pushBack [_x,_id];
    } forEach (_members select [0,16]);
    private _accepted=[_group,_house] call WAIT_fnc_CortexClearBuilding;
    private _admissionJob=(_group getVariable ["WAIT_BuildingBrain",createHashMap]) getOrDefault ["job",createHashMap];
    private _admittedMembers=+(_admissionJob getOrDefault ["team",[]]);
    private _admissionPairs=(_admissionJob getOrDefault ["pairs",[]]) apply {+_x};
    [format ["CLEAR-fresh-%1-accepted",_size],_accepted] call _check;
    [format ["CLEAR-fresh-%1-owned-attack-delegation",_size],_accepted && {!attackEnabled leader _group},
        str [_originalAttack,attackEnabled leader _group]] call _check;
    private _entryEpoch=_group getVariable ["WAIT_AIPass_Epoch",0];
    private _entryGeneration=(_group getVariable ["WAIT_Operation",createHashMap]) getOrDefault ["generation",-1];
    private _entryOwnerStable=true;
    private _egressSeen=false;
    private _egressAssignments=[];
    private _egressVisits=[];
    private _nextRouteTrace=diag_tickTime;
    private _routeTraceCount=0;
    private _reserveHoldViolations=[];
    private _reserveHoldSamples=0;
    [format ["CLEAR-fresh-%1-owner-established",_size],_accepted && {_entryEpoch > 0}
        && {_group getVariable ["WAIT_AIPass_Adopted",false]} && {_entryGeneration >= 0},
        str [_entryEpoch,_entryGeneration]] call _check;
    private _settled=[{
        // Observe the live controller without injecting destinations or changing acceptance.
        // Ten-second samples and bounded actor/state slices keep diagnostics finite.
        if (diag_tickTime >= _nextRouteTrace && {_routeTraceCount < 26}) then {
            _nextRouteTrace=diag_tickTime+10;
            _routeTraceCount=_routeTraceCount+1;
            private _brain=_group getVariable ["WAIT_BuildingBrain",createHashMap];
            private _job=_brain getOrDefault ["job",createHashMap];
            private _operation=_group getVariable ["WAIT_Operation",createHashMap];
            private _traceHouse=_job getOrDefault ["building",objNull];
            diag_log format ["WAIT CLEAR LIVE DOORS: %1",[_size,_routeTraceCount,
                _traceHouse getVariable ["WAIT_Cortex_DoorDefinitions",[]],
                (_traceHouse getVariable ["WAIT_CortexQA_DoorProfile",[]]) apply {
                    [_x select 0,_traceHouse animationSourcePhase (_x select 1),
                        _traceHouse getVariable [format ["bis_disabled_Door_%1",_x select 0],0]]
                }]];
            {
                private _actor=_x;
                diag_log format ["WAIT CLEAR ACTOR: %1",[_size,_routeTraceCount,netId _actor,
                    local _actor,getPosASL _actor,currentCommand _actor,expectedDestination _actor,
                    _actor checkAIFeature "MOVE",_actor checkAIFeature "PATH",getForcedSpeed _actor,
                    getUnitState _actor,unitReady _actor,
                    _actor in (_job getOrDefault ["enteredActors",[]]),
                    _actor in (_operation getOrDefault ["unavailable",[]]),
                    (_job getOrDefault ["entryRecovery",createHashMap]) getOrDefault [netId _actor,[]],
                    insideBuilding _actor,_actor getVariable ["WAIT_Cortex_ClearReserve",[]],
                    _actor in (_job getOrDefault ["quarantineHeld",[]]),
                    (_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _actor,[]],
                    ["NATIVE_MOVE",moveToFailed _actor,moveToCompleted _actor,canMove _actor]]];
                private _reserveStage=(_job getOrDefault ["reserveStages",createHashMap]) getOrDefault [netId _actor,[]];
                // A generation-owned arrived reserve must retain its actual staging point.
                // Externally taken actors and retired jobs are outside this observation.
                if (count _reserveStage >= 2 && {_reserveStage param [1,false,[true]]}
                    && {!(_actor in (_job getOrDefault ["team",[]]))}
                    && {!(_job getOrDefault ["finished",false])}
                    && {alive _actor} && {local _actor} && {isNull objectParent _actor}
                    && {isNull remoteControlled _actor}
                    && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
                    && {currentCommand _actor in ["STOP","MOVE","FOLLOW",""]}) then {
                    _reserveHoldSamples=_reserveHoldSamples+1;
                    if ((getPosASL _actor) vectorDistance (AGLToASL (_reserveStage select 0)) > 3) then {
                        _reserveHoldViolations pushBackUnique (netId _actor);
                    };
                };
                // Observe actual exit watching only after physical stage arrival. A label,
                // rejected hold, or a watch destination alone cannot pass this behavior.
                if (count _reserveStage >= 6 && {(_reserveStage param [2,""]) == "ARRIVED"}
                    && {!(_actor in (_job getOrDefault ["team",[]]))}
                    && {!(_job getOrDefault ["finished",false])} && {alive _actor} && {local _actor}
                    && {isNull objectParent _actor} && {isNull remoteControlled _actor}
                    && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}) then {
                    private _watch=_reserveStage param [4,[],[[]]];
                    if (count _watch == 3) then {
                        private _arrived=(getPosASL _actor) vectorDistance (AGLToASL (_reserveStage select 0)) <= 2;
                        private _headingError=abs (((getDir _actor-(_actor getDir _watch)+540) mod 360)-180);
                        private _visible=!terrainIntersectASL [eyePos _actor,AGLToASL _watch]
                            && {(lineIntersectsSurfaces [eyePos _actor,AGLToASL _watch,
                                _actor,objNull,true,1,"VIEW","NONE"]) isEqualTo []};
                        if (_arrived && {_headingError <= 75} && {_visible}) then {
                            _reserveObservationVisits pushBackUnique netId _actor;
                        };
                        diag_log format ["WAIT CLEAR EXIT OBSERVATION AUDIT: %1",[
                            _size,netId _actor,_arrived,_headingError,_visible,+_watch,
                            _reserveStage param [6,false,[true]]]];
                    };
                };
                // Separate short records avoid truncating the movement receipt. These are
                // observations only: native formation must not masquerade as a CQB role.
                diag_log format ["WAIT CLEAR ROLE: %1",[_size,_routeTraceCount,netId _actor,
                    _actor == leader _group,formation _group,formationPosition _actor,
                    _actor in (_job getOrDefault ["team",[]]),
                    _actor in (_job getOrDefault ["securityActors",[]]),
                    (_job getOrDefault ["reserveStages",createHashMap]) getOrDefault [netId _actor,[]],
                    (_job getOrDefault ["roomHolds",createHashMap]) getOrDefault [netId _actor,[]],
                    _group getVariable ["WAIT_Cortex_ClearHold",[]],
                    _job getOrDefault ["finishReason",""],
                    _actor getVariable ["WAIT_Cortex_ClearRecall",[]]]];
            } forEach (_clearingMembers select [0,16]);
            diag_log format ["WAIT CLEAR LIVE ROUTE: %1",[
                _size,_routeTraceCount,diag_tickTime,
                _group getVariable ["WAIT_AIPass_Epoch",0],
                _brain getOrDefault ["generation",-1],_brain getOrDefault ["ownerEpoch",-1],
                _brain getOrDefault ["pending",false],_brain getOrDefault ["lastStepAt",-1],
                _operation getOrDefault ["generation",-1],_operation getOrDefault ["intent",""],
                _job getOrDefault ["phase",""],
                (_job getOrDefault ["pairStates",[]]) select [0,8],
                (_job getOrDefault ["pairRoutes",[]]) select [0,8],
                (_job getOrDefault ["assigned",[]]) select [0,16],
                (_clearingMembers select [0,16]) apply {
                    [str _x,local _x,getPosATL _x,currentCommand _x,expectedDestination _x,
                        _x checkAIFeature "MOVE",_x checkAIFeature "PATH",getForcedSpeed _x,
                        _x == leader _group,getUnitState _x,unitReady _x,simulationEnabled _x]
                }
            ]];
        };
        {
            private _receipt=_x getVariable ["WAIT_Cortex_ClearReserve",[]];
            if (count _receipt == 3 && {(_receipt select 1) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
                && {_x distance2D (_receipt select 2) <= 2}
                && {abs (((getPosATL _x) select 2)-((_receipt select 2) select 2)) <= 1.5}) then {
                _reserveStageVisits pushBackUnique netId _x;
            };
        } forEach _members;
        private _exit=_group getVariable ["WAIT_Cortex_ClearEgress",[]];
        if (count _exit in [4,10,13] && {(_exit select 0) == "EGRESS"}) then {
            {
                private _actor=_x select 0;
                if (_egressAssignments findIf {(_x select 0) == _actor} < 0) then {
                    _egressAssignments pushBack +_x;
                    _egressVisits pushBack false;
                };
            } forEach (_exit select 3);
            _egressSeen=_egressAssignments isNotEqualTo [];
        };
        {
            _x params ["_actor","_exitTarget"];
            if ([_actor,_house,_exitTarget] call _observedExit) then {
                _egressVisits set [_forEachIndex,true];
            };
        } forEach _egressAssignments;
        private _currentOperation=_group getVariable ["WAIT_Operation",createHashMap];
        if ((_group getVariable ["WAIT_AIPass_Epoch",0]) != _entryEpoch
            || {((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) == "CANCELLED"}
            || {count _currentOperation > 0 && {(_currentOperation getOrDefault ["generation",-1]) != _entryGeneration}}) then {
            _entryOwnerStable=false;
        };
        {private _room=_x; private _roomIndex=_forEachIndex; if (_clearingMembers findIf {[_x,_house,_room] call _observedRoomVisit} >= 0) then {_visits set [_roomIndex,true]}} forEach _rooms;
        {
            private _worker=_x;
            private _workerIndex=_forEachIndex;
            private _seen=_memberVisits select _workerIndex;
            {if ([_worker,_house,_x] call _observedRoomVisit) then {_seen pushBackUnique _forEachIndex}} forEach _rooms;
            if (_seen isNotEqualTo [] && {(_memberFirstVisit select _workerIndex) < 0}) then {
                private _elapsed=diag_tickTime-_entryTimingStart;
                _memberFirstVisit set [_workerIndex,_elapsed];
                diag_log format ["WAIT CLEAR FIRST PHYSICAL ENTRY: %1",[
                    _size,netId _worker,_elapsed,_seen select 0,
                    _worker in _admittedMembers,getPosASL _worker]];
            };
        } forEach _clearingMembers;
        {
            private _position=_x;
            if (_clearingMembers findIf {alive _x && {(getPosASL _x) vectorDistance (AGLToASL _position) <= 1.5}} >= 0) then {
                _exteriorVisits set [_forEachIndex,true];
            };
        } forEach _exteriorRooms;
        missionNamespace setVariable ["WAIT_CortexQA_Rooms",[_rooms,_visits],true];
        ((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE","CANCELLED"]
    },245] call _wait;
    // Cancellation is terminal, not a successful clearance. Stop sampling promptly; physical
    // visits and completion assertions below still fail rather than waiting four idle minutes.
    // Preserve the physical sampling budget. Allow only finite controller settlement afterward:
    // a queued owner-local finish may follow the audit deadline by one scheduler interval.
    // This does not count extra visits or force cleanup, and a missing terminal result still fails.
    if (!_settled) then {
        _settled=[{
            ((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE","CANCELLED"]
        },15] call _wait;
    };
    [format ["CLEAR-fresh-%1-terminal-settlement",_size],_settled,
        str (_group getVariable ["WAIT_Cortex_ClearResult",[]])] call _check;
    [format ["CLEAR-fresh-%1-owner-continuity",_size],_accepted && {_entryOwnerStable},
        str [_entryEpoch,_group getVariable ["WAIT_AIPass_Epoch",0],
            _entryGeneration,_group getVariable ["WAIT_OperationResult",[]]]] call _check;
    diag_log format ["WAIT CLEAR EXTERIOR EVIDENCE: %1 %2",_size,[_exteriorRooms,_exteriorVisits]];
    private _localResult=(_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""];
    private _sharedResult=_group getVariable ["WAIT_OperationResult",[]];
    private _expectedReason=["CLEAR_INCOMPLETE","CLEAR_COMPLETE"] select (_localResult == "COMPLETE");
    [format ["CLEAR-fresh-%1-shared-outcome-agrees",_size],
        _localResult in ["COMPLETE","INCOMPLETE"] && {count _sharedResult == 5}
            && {(_sharedResult select 0) == "CLEAR"} && {(_sharedResult select 1) == _localResult}
            && {(_sharedResult select 2) == _entryGeneration} && {(_sharedResult select 4) == _expectedReason},
        str [_localResult,_sharedResult]] call _check;
    [format ["CLEAR-fresh-%1-attack-delegation-restored",_size],
        _localResult in ["COMPLETE","INCOMPLETE"] && {attackEnabled leader _group == _originalAttack},
        str [_localResult,_originalAttack,attackEnabled leader _group]] call _check;
    private _physical=_rooms isNotEqualTo [] && {_visits findIf {!_x} < 0};
    [format ["CLEAR-fresh-%1-reserves-maintain-owned-stage",_size],
        _reserveHoldViolations isEqualTo [] && {_size <= 8 || {_reserveHoldSamples > 0}},
        str [_reserveHoldSamples,_reserveHoldViolations]] call _check;
    [format ["CLEAR-fresh-%1-physical-room-visits",_size],_physical,format ["visits=%1 units=%2",_visits,_members apply {[getPosATL _x,currentCommand _x,expectedDestination _x,_x checkAIFeature "PATH",_x checkAIFeature "MOVE",behaviour _x]}]] call _check;
    [format ["CLEAR-fresh-%1-physical-egress",_size],_egressSeen && {_egressVisits findIf {!_x} < 0},str [_egressAssignments,_egressVisits]] call _check;
    private _egressActors=_egressAssignments apply {_x select 0};
    private _crowded=[];
    {
        private _actor=_x;
        private _partners=_egressActors select {_x != _actor && {alive _x} && {_actor distance2D _x < 1.5}};
        if (_partners isNotEqualTo []) then {_crowded pushBack [netId _actor,_partners apply {netId _x}]};
    } forEach _egressActors;
    [format ["CLEAR-fresh-%1-egress-physical-separation",_size],_egressSeen && {_egressVisits findIf {!_x} < 0} && {_crowded isEqualTo []},str _crowded] call _check;

    private _egressRetries=_group getVariable ["WAIT_Cortex_ClearEgressRetries",[]];
    [format ["CLEAR-fresh-%1-egress-retry-budget",_size],_egressSeen && {_egressRetries findIf {(_x select 2) > 1} < 0},str _egressRetries] call _check;
    [format ["CLEAR-fresh-%1-result-agrees",_size],_physical && {((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) == "COMPLETE"}] call _check;
    if (_size == 12) then {["CLEAR-fresh-12-reserve-staging-physical",count _reserveStageVisits > 0,str _reserveStageVisits] call _check};
    if (_size == 12) then {
        private _exteriorMembers=_members select {!(_x in _admittedMembers) && {alive _x}};
        ["CLEAR-fresh-12-exterior-exit-observation-physical",
            _exteriorMembers isNotEqualTo [] && {_exteriorMembers findIf {
                !(netId _x in _reserveObservationVisits)
            } < 0},str [_exteriorMembers apply {netId _x},_reserveObservationVisits]] call _check;
    };
    [format ["CLEAR-fresh-%1-successive-positions",_size],_memberVisits findIf {count _x >= 2} >= 0,str _memberVisits] call _check;
    [format ["CLEAR-fresh-%1-all-admitted-progress-through-interior",_size],
        _admittedMembers isNotEqualTo [] && {_admittedMembers findIf {
            private _index=_clearingMembers find _x;
            _index < 0 || {count (_memberVisits select _index) < (2 min count _rooms)}
        } < 0},str [_admittedMembers apply {netId _x},_memberVisits]] call _check;
    if (_size == 2) then {
        ["CLEAR-fresh-2-both-participate",_memberVisits findIf {_x isEqualTo []} < 0,str _memberVisits] call _check;
        if (count _rooms >= 4) then {
            ["CLEAR-fresh-2-both-progress-through-interior",_memberVisits findIf {count _x < 2} < 0,str _memberVisits] call _check;
        };
    };
    // Timing is diagnostic, not a synthetic clearance receipt or a universal time-to-entry pass.
    // Retain absent entry as -1, and distinguish admitted workers from exterior-role soldiers.
    private _entryTiming=_clearingMembers apply {
        private _index=_clearingMembers find _x;
        [netId _x,_memberFirstVisit select _index,count (_memberVisits select _index),
            _x in _admittedMembers,-1,alive _x]
    };
    // Pair membership uses an explicit outer actor to avoid nested iterator shadowing.
    {
        private _worker=_clearingMembers select _forEachIndex;
        _x set [4,_admissionPairs findIf {_worker in _x}];
    } forEach _entryTiming;
    diag_log format ["WAIT CLEAR PHYSICAL ENTRY TIMING: %1",[_size,_entryTiming]];
    // Exercise natural completion/failure cleanup before invoking any explicit release.
    // A fresh ordinary waypoint must take control even when some rooms were unreachable.
    private _destination=_site vectorAdd [75,-30,0];
    private _holdHcTransfer=false;
    if (_size == 2 && {_localResult == "COMPLETE"}
        && {missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false]}) then {
        [{count (missionNamespace getVariable ["WAIT_Headless_Clients",[]]) >= 2},30] call _wait;
        private _holdOwners=(missionNamespace getVariable ["WAIT_Headless_Clients",[]]) apply {_x select 0};
        ["HC-CLEAR-HOLD-two-registered",count _holdOwners >= 2] call _check;
        _group setVariable ["WAIT_Headless_ExcludeGroup",false,true];
        {
            private _owner=_x;
            private _priorHold=_group getVariable ["WAIT_Cortex_ClearHold",[]];
            private _priorGeneration=_priorHold param [0,-1];
            private _requested=[_group,_owner] call WAIT_fnc_HeadlessMigrateGroup;
            private _adopted=[{
                private _currentHold=_group getVariable ["WAIT_Cortex_ClearHold",[]];
                groupOwner _group == _owner && {count _currentHold == 4}
                    && {(_currentHold select 0) > _priorGeneration}
            },20] call _wait;
            [format ["HC-CLEAR-HOLD-adopted-%1",_owner],_requested && {_adopted},
                str [_priorHold,_group getVariable ["WAIT_Cortex_ClearHold",[]],groupOwner _group]] call _check;
            _holdHcTransfer=_holdHcTransfer || {_adopted};
        } forEach (_holdOwners select [0,2]);
    };
    if (_localResult == "COMPLETE") then {
        private _heldPositions=_clearingMembers apply {getPosASL _x};
        // Observe without issuing orders: successful cleanup must not recall a formation wedge.
        sleep 8;
        private _holdEvidence=[];
        {
            _holdEvidence pushBack [netId _x,(getPosASL _x) vectorDistance (_heldPositions select _forEachIndex),currentCommand _x];
        } forEach _clearingMembers;
        [format ["CLEAR-fresh-%1-post-clear-hold",_size],
            _holdEvidence findIf {(_x select 1) > 3 || {(_x select 2) == "JOIN"}} < 0,str _holdEvidence] call _check;
    };
    // Preserve every observation-deadline finding above. Before a new waypoint interrupts
    // the episode, independently observe its immutable lifetime and finite egress budget.
    // Late settlement cannot replace missing visits, participation or the recorded outcome.
    private _episodeBoundary=_admissionJob getOrDefault ["hardDeadline",-1];
    if (!_settled && {_episodeBoundary >= 0}) then {
        [format ["Finite clearance episode: %1 soldiers",_size],"The original observation findings remain recorded. Observe whether the controller terminates within its absolute lifetime and finite exit budget. No destination, cleanup or room visit is injected; late settlement cannot pass the original clearance checks.",getPosATL _house] call _phase;
        private _finite=[{
            ((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE","CANCELLED"]
        },(0 max (_episodeBoundary-serverTime+55)) min 955] call _wait;
        [format ["CLEAR-fresh-%1-finite-episode-terminal",_size],_finite
            && {serverTime <= _episodeBoundary+55}
            && {(_admissionJob getOrDefault ["hardDeadline",-1]) == _episodeBoundary},
            str [_episodeBoundary,serverTime,_group getVariable ["WAIT_Cortex_ClearResult",[]]]] call _check;
    };
    private _beforeMove=_members apply {getPosATL _x};
    // One real external edit must survive cancellation; other actors must release
    // their unchanged indoor caps to the pre-operation baseline.
    private _editedActor=_members select ((count _members)-1);
    _editedActor forceSpeed 8;
    private _waypoint=_group addWaypoint [_destination,0];
    _waypoint setWaypointType "MOVE";
    _group setCurrentWaypoint _waypoint;
    [format ["Clearance handover: %1 soldiers",_size],"After the recorded clearance result, the same soldiers must follow an ordinary waypoint away from the building. No cleanup function or movement reset is injected before this check. One actor receives an external speed-limit edit; it must survive while unchanged WAIT indoor limits release.",_destination] call _phase;
    private _moved=[{
        private _allMoved=alive leader _group && {leader _group distance2D _destination <= 18};
        {
            private _formationPoint=formationPosition _x;
            if (!alive _x || {_x distance2D (_beforeMove select _forEachIndex) < 25}
                || {_formationPoint isEqualTo [0,0,0]}
                || {_x distance2D _formationPoint > 18}
                || {abs (((getPosASL _x) select 2)-((AGLToASL _formationPoint) select 2)) > 1.5}) then {_allMoved=false};
        } forEach _members;
        _allMoved
    },90] call _wait;
    private _handoverEvidence=[];
    {
        private _formationPoint=formationPosition _x;
        _handoverEvidence pushBack [netId _x,getPosATL _x,_formationPoint,currentCommand _x,expectedDestination _x,
            _beforeMove select _forEachIndex,_x distance2D (_beforeMove select _forEachIndex),
            _x distance2D _formationPoint,
            abs (((getPosASL _x) select 2)-((AGLToASL _formationPoint) select 2))];
        diag_log format ["WAIT CLEAR HANDBACK ACTOR: %1",[_size,netId _x,getPosATL _x,currentCommand _x,
            expectedDestination _x,(_admissionJob getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _x,[]],
            _x getVariable ["WAIT_Cortex_ClearRecall",[]],groupOwner _group,_entryEpoch,_group getVariable ["WAIT_AIPass_Epoch",0],
            local _x,lifeState _x,damage _x,_x checkAIFeature "MOVE",_x checkAIFeature "PATH",
            [_x] call WAIT_fnc_CortexCombatEffective,_x getVariable ["WAIT_Cortex_ActorMove",[]]]];
    } forEach _members;
    [format ["CLEAR-fresh-%1-handover-physical",_size],_moved,str [getPosATL leader _group,formation _group,_handoverEvidence]] call _check;
    private _speedReleased=true;
    {
        if (_x != _editedActor && {abs ((getForcedSpeed _x)-(_originalSpeedLimits select _forEachIndex)) > 0.1}) then {
            _speedReleased=false;
        };
    } forEach _members;
    [format ["CLEAR-fresh-%1-handover-owned-speed-release",_size],_speedReleased,
        str [_originalSpeedLimits,_members apply {getForcedSpeed _x}]] call _check;
    [format ["CLEAR-fresh-%1-handover-external-speed-preserved",_size],abs ((getForcedSpeed _editedActor)-8) <= 0.1,
        str [netId _editedActor,getForcedSpeed _editedActor]] call _check;

    // Repeat real clearance after ordinary movement, without resetting the surviving squad.
    // HC lifecycle is covered separately; this case retains the normal owner throughout.
    if (_size in [2,6] && {local _group} && {!_holdHcTransfer}) then {
        private _priorGeneration=_group getVariable ["WAIT_AIPass_ClearGeneration",-1];
        [format ["Repeated clearance: %1 soldiers",_size],"The same squad returns after ordinary movement. No cleanup, actor relocation or state reset occurs between episodes. Require new physical interior visits and a complete terminal result.",getPosATL _house] call _phase;
        private _repeatAccepted=[_group,_house] call WAIT_fnc_CortexClearBuilding;
        [format ["CLEAR-repeat-%1-accepted-new-generation",_size],_repeatAccepted
            && {(_group getVariable ["WAIT_AIPass_ClearGeneration",-1]) > _priorGeneration}] call _check;
        private _repeatVisits=_rooms apply {false};
        private _repeatActors=[];
        private _repeatTraceAt=diag_tickTime;
        private _repeatTraceCount=0;
        private _repeatEnded=[{
            // Observe before cleanup; shared coverage cannot explain an absent actor.
            // Separate bounded actor records keep RPT lines below truncation limits.
            if (diag_tickTime >= _repeatTraceAt && {_repeatTraceCount < 30}) then {
                _repeatTraceAt=diag_tickTime+8;
                _repeatTraceCount=_repeatTraceCount+1;
                private _repeatBrain=_group getVariable ["WAIT_BuildingBrain",createHashMap];
                private _repeatJob=_repeatBrain getOrDefault ["job",createHashMap];
                private _repeatOperation=_group getVariable ["WAIT_Operation",createHashMap];
                diag_log format ["WAIT CLEAR REPEAT STATE: %1",[_size,_repeatTraceCount,
                    _repeatJob getOrDefault ["generation",-1],_repeatJob getOrDefault ["phase",""],
                    _repeatJob getOrDefault ["deadline",-1],_repeatJob getOrDefault ["hardDeadline",-1],
                    _repeatJob getOrDefault ["pairStates",[]],_repeatJob getOrDefault ["pairRoutes",[]]]];
                {
                    private _key=netId _x;
                    diag_log format ["WAIT CLEAR REPEAT ACTOR: %1",[_size,_repeatTraceCount,_key,
                        getPosATL _x,currentCommand _x,expectedDestination _x,
                        (_repeatJob getOrDefault ["actorVisits",createHashMap]) getOrDefault [_key,[]],
                        _x in (_repeatJob getOrDefault ["enteredActors",[]]),
                        (_repeatJob getOrDefault ["entryRecovery",createHashMap]) getOrDefault [_key,[]],
                        (_repeatJob getOrDefault ["movementTargets",createHashMap]) getOrDefault [_key,[]],
                        (_repeatJob getOrDefault ["followThrough",createHashMap]) getOrDefault [_key,[]],
                        (_repeatOperation getOrDefault ["recoveryAttempts",createHashMap]) getOrDefault [_key,0]]];
                } forEach (_members select [0,16]);
            };
            {
                private _actor=_x;
                {
                    if ([_actor,_house,_x] call _observedRoomVisit) then {
                        _repeatVisits set [_forEachIndex,true];
                        _repeatActors pushBackUnique _actor;
                    };
                } forEach _rooms;
            } forEach _members;
            !(_group getVariable ["WAIT_AIPass_ClearBuilding",false])
        },240] call _wait;
        [format ["CLEAR-repeat-%1-new-physical-visits",_size],_repeatAccepted
            && {_repeatVisits findIf {!_x} < 0} && {count _repeatActors == count _members},str [_repeatVisits,_repeatActors]] call _check;
        [format ["CLEAR-repeat-%1-complete-terminal",_size],_repeatAccepted && {_repeatEnded}
            && {((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) == "COMPLETE"},
            str (_group getVariable ["WAIT_Cortex_ClearResult",[]])] call _check;
        // Repeated use also needs a second real handback, without injected cleanup.
        // A prior repeat failure remains recorded even if a new authored order cancels it.
        private _repeatDeparture=_members apply {getPosATL _x};
        private _repeatDestination=(getPosATL _house) getPos [75,270];
        private _repeatWaypoint=_group addWaypoint [_repeatDestination,0];
        _repeatWaypoint setWaypointType "MOVE";
        _group setCurrentWaypoint _repeatWaypoint;
        [format ["Repeated clearance handover: %1 soldiers",_size],"The same squad must leave on a fresh ordinary waypoint after its second clearance episode. No cleanup or movement reset is injected. Every original actor must physically travel and regain its normal formation; the external speed edit remains authoritative.",_repeatDestination] call _phase;
        private _repeatHandedBack=[{
            private _allMoved=alive leader _group && {leader _group distance2D _repeatDestination <= 18};
            {
                private _formationPoint=formationPosition _x;
                if (!alive _x || {_x distance2D (_repeatDeparture select _forEachIndex) < 25}
                    || {_formationPoint isEqualTo [0,0,0]} || {_x distance2D _formationPoint > 18}
                    || {abs (((getPosASL _x) select 2)-((AGLToASL _formationPoint) select 2)) > 1.5}) then {_allMoved=false};
            } forEach _members;
            _allMoved
        },90] call _wait;
        [format ["CLEAR-repeat-%1-handover-physical",_size],_repeatHandedBack,
            str (_members apply {[netId _x,getPosATL _x,currentCommand _x,formationPosition _x]})] call _check;
        [format ["CLEAR-repeat-%1-handover-external-speed-preserved",_size],abs ((getForcedSpeed _editedActor)-8) <= 0.1,
            str [netId _editedActor,getForcedSpeed _editedActor]] call _check;
    };
    sleep 8;
    if (_holdHcTransfer) then {
        ["HC-CLEAR-HOLD-successor-physical",_moved] call _check;
        [_group,2] call WAIT_fnc_HeadlessMigrateGroup;
        ["HC-CLEAR-HOLD-return-server",[{local _group},20] call _wait] call _check;
        _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    };
    [_group] call WAIT_fnc_CortexClearRelease;
    missionNamespace setVariable ["WAIT_CortexQA_Rooms",[],true];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
    {_x params ["_actor","_id"]; _actor removeEventHandler ["PathCalculated",_id]} forEach _pathHandlers;
    {deleteVehicle _x} forEach _members;
    deleteGroup _group;
    deleteVehicle _house;
} forEach (if (_largeOnly) then {
    [[4,"Land_i_House_Big_02_V1_F"],[12,"Land_i_House_Big_02_V1_F"]]
} else {
    [[2,"Land_i_House_Small_01_V1_F"],[6,"Land_i_House_Big_01_V1_F"],[12,"Land_i_House_Big_02_V1_F"],[4,"Land_i_House_Big_02_V1_F"]]
});

};
if (_largeOnly) exitWith {};

// Moving the building is the administrative stimulus; actors are never repositioned.
private _movedHouse=createVehicle ["Land_i_House_Small_01_V1_F",[7750,5800,0],[],0,"NONE"];
[_movedHouse,"transform"] call _validateNewFixturePlacement;
private _transformGroup=createGroup [east,true];
_transformGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_transformGroup setVariable ["acex_headless_blacklist",true,true];
private _transformActors=[];
for "_i" from 0 to 1 do {
    private _actor=_transformGroup createUnit ["O_Soldier_F",[7735+_i*4,5760,0],[],0,"NONE"];
    _actor setVariable ["WAIT_CortexQA_Label",format ["MOVED BUILDING %1",_i+1],true];
    _transformActors pushBack _actor;
};
missionNamespace setVariable ["WAIT_CortexQA_Actors",_transformActors,true];
["Clearance: building movement","A real clearance starts, then its target house moves and rotates. WAIT must cancel BUILDING_MOVED before stale room orders continue. A fresh explicit order must physically enter the new location; actors are not relocated.",getPosATL _movedHouse] call _phase;
private _transformAccepted=[_transformGroup,_movedHouse] call WAIT_fnc_CortexClearBuilding;
private _transformStarted=[{
    private _brain=_transformGroup getVariable ["WAIT_BuildingBrain",createHashMap];
    private _job=_brain getOrDefault ["job",createHashMap];
    (_job getOrDefault ["buildingTransform",[]]) isNotEqualTo []
},15] call _wait;
["CLEAR-transform-operation-started",_transformAccepted && {_transformStarted}] call _check;
private _movedPosition=(getPosATL _movedHouse) vectorAdd [30,0,0];
_movedHouse setDir 90;
_movedHouse setPosATL _movedPosition;
private _transformCancelled=[{
    private _result=_transformGroup getVariable ["WAIT_OperationResult",[]];
    (_result param [1,""]) == "CANCELLED" && {(_result param [4,""]) == "BUILDING_MOVED"}
        && {!(_transformGroup getVariable ["WAIT_AIPass_ClearBuilding",false])}
},15] call _wait;
["CLEAR-transform-stale-operation-cancelled",_transformStarted && {_transformCancelled},
    str (_transformGroup getVariable ["WAIT_OperationResult",[]])] call _check;
private _transformReordered=[_transformGroup,_movedHouse] call WAIT_fnc_CortexClearBuilding;
["CLEAR-transform-fresh-order-accepted",_transformCancelled && {_transformReordered}] call _check;
private _movedRooms=_movedHouse buildingPos -1;
private _transformEntry=[{
    _transformActors findIf {
        private _actor=_x;
        _movedRooms findIf {(getPosASL _actor) vectorDistance (AGLToASL _x) <= 1.5} >= 0
    } >= 0
},90] call _wait;
["CLEAR-transform-reorder-physical-entry",_transformCancelled && {_transformReordered} && {_transformEntry},
    str [_movedPosition,_movedRooms,_transformActors apply {getPosASL _x}]] call _check;
[_transformGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach _transformActors;
deleteGroup _transformGroup;
deleteVehicle _movedHouse;

if (_transformOnly) exitWith {};

// A casualty inside the clearing element must not strand the shared room queue. Use ten soldiers
// so the production room-limited entry element leaves genuine reserves available as replacements.
private _casualtySite=[7150,5800,0];
private _casualtyHouse=createVehicle ["Land_i_House_Big_01_V1_F",_casualtySite,[],0,"NONE"];
_casualtyHouse enableSimulationGlobal true;
[_casualtyHouse,"casualty"] call _validateNewFixturePlacement;
private _casualtyGroup=createGroup [east,true];
_casualtyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_casualtyGroup setVariable ["acex_headless_blacklist",true,true];
private _casualtyMembers=[];
for "_i" from 0 to 9 do {
    private _unit=_casualtyGroup createUnit ["O_Soldier_F",_casualtySite vectorAdd [-20+(_i mod 5)*4,-40-floor(_i/5)*4,0],[],0,"NONE"];
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["CQB CASUALTY / soldier %1",_i+1],true];
    _casualtyMembers pushBack _unit;
};
missionNamespace setVariable ["WAIT_CortexQA_Actors",_casualtyMembers,true];
["CQB casualty reinforcement","The ten-person squad starts with a room-limited clearing element and remaining reserves. One clearing soldier becomes a real casualty. A surviving reserve must join the clear, physically move toward the building and establish its own wall-aware interior visit; the remaining room queue must stay active.",getPosATL _casualtyHouse] call _phase;
private _casualtyAccepted=[_casualtyGroup,_casualtyHouse] call WAIT_fnc_CortexClearBuilding;
["CLEAR-casualty-order-accepted",_casualtyAccepted] call _check;
private _jobStarted=[{_casualtyGroup getVariable ["WAIT_AIPass_ClearBuilding",false]},15] call _wait;
["CLEAR-casualty-job-started",_jobStarted] call _check;
private _initialOperation=_casualtyGroup getVariable ["WAIT_Operation",createHashMap];
private _initialParticipants=+(_initialOperation getOrDefault ["participants",[]]);
private _casualty=_initialParticipants param [0,objNull];
private _reservePool=_casualtyMembers select {!(_x in _initialParticipants)};
private _reserveStarts=_reservePool apply {getPosATL _x};
private _reserve=objNull;
private _reserveStart=[];
["CLEAR-casualty-entry-and-reserve-fixture",!isNull _casualty && {_reservePool isNotEqualTo []},
    str [_initialParticipants,_reservePool]] call _check;
private _evidenceBefore=count (_casualtyGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]]);
_casualty setDamage 1;
private _reinforced=[{
    private _evidence=_casualtyGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]];
    private _replacementIndex=_evidence findIf {(_x param [1,""]) == netId _casualty};
    if (count _evidence > _evidenceBefore && {_replacementIndex >= 0}) then {
        private _replacementId=(_evidence select _replacementIndex) param [2,""];
        private _poolIndex=_reservePool findIf {netId _x == _replacementId};
        if (_poolIndex >= 0) then {
            _reserve=_reservePool select _poolIndex;
            _reserveStart=_reserveStarts select _poolIndex;
        };
    };
    !isNull _reserve
},30] call _wait;
["CLEAR-casualty-reserve-assigned",_reinforced,str (_casualtyGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]])] call _check;
private _reserveOperation=_casualtyGroup getVariable ["WAIT_Operation",createHashMap];
["CLEAR-casualty-shared-progress-roster",_reinforced
    && {_reserve in (_reserveOperation getOrDefault ["participants",[]])}
    && {!(_casualty in (_reserveOperation getOrDefault ["participants",[]]))}
    && {(_reserveOperation getOrDefault ["participantProgress",[]]) findIf {(_x select 0) == _reserve} >= 0},
    str [_reserveOperation getOrDefault ["participants",[]],_reserveOperation getOrDefault ["participantProgress",[]]]] call _check;
private _replacementMoved=[{
    !isNull _reserve && {alive _reserve}
        && {(_reserve distance2D _reserveStart >= 8
                && {_reserve distance2D _casualtyHouse <= (_reserveStart distance2D _casualtyHouse)-5})
            || {(_casualtyHouse buildingPos -1) findIf {(getPosASL _reserve) vectorDistance (AGLToASL _x) <= 1.5} >= 0}}
},60] call _wait;
["CLEAR-casualty-reserve-physical-movement",_replacementMoved,format ["start=%1 actual=%2 command=%3 expected=%4",_reserveStart,getPosATL _reserve,currentCommand _reserve,expectedDestination _reserve]] call _check;
// Movement toward a house is not replacement entry; use independent wall-aware evidence.
private _replacementEntry=false;
private _replacementRooms=(_casualtyHouse buildingPos -1) select {
    private _origin=AGLToASL _x;
    private _roof=lineIntersectsSurfaces [_origin vectorAdd [0,0,0.5],_origin vectorAdd [0,0,10],objNull,objNull,true,1,"GEOM","NONE"];
    _roof isNotEqualTo [] && {((_roof select 0) select 2) == _casualtyHouse || {((_roof select 0) select 3) == _casualtyHouse}}
};
// Observe replacement ownership without issuing movement or changing retry budgets.
private _replacementTraceNext=0;
private _replacementTraceCount=0;
private _replacementEntered=[{
    if (serverTime >= _replacementTraceNext && {_replacementTraceCount < 16}) then {
        _replacementTraceNext=serverTime+8;
        _replacementTraceCount=_replacementTraceCount+1;
        private _job=(_casualtyGroup getVariable ["WAIT_BuildingBrain",createHashMap]) getOrDefault ["job",createHashMap];
        private _operation=_casualtyGroup getVariable ["WAIT_Operation",createHashMap];
        diag_log format ["WAIT CLEAR REPLACEMENT TRACE: %1",[serverTime,netId _reserve,
            getPosATL _reserve,getPosASL _reserve,currentCommand _reserve,expectedDestination _reserve,
            _job getOrDefault ["pairs",[]],_job getOrDefault ["pairStates",[]],
            _job getOrDefault ["enteredActors",[]],_operation getOrDefault ["phase",""],
            _operation getOrDefault ["recovery",createHashMap],
            _casualtyGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]]]];
    };
    if (!isNull _reserve && {alive _reserve}) then {
        _replacementEntry=_replacementEntry || {_replacementRooms findIf {
            [_reserve,_casualtyHouse,_x] call _observedRoomVisit
        } >= 0};
    };
    _replacementEntry
},60] call _wait;
["CLEAR-casualty-reserve-physical-entry",_reinforced && {_replacementEntered},
    format ["replacement=%1 actual=%2 command=%3",_reserve,getPosATL _reserve,currentCommand _reserve]] call _check;
private _continuing=(_casualtyGroup getVariable ["WAIT_AIPass_ClearBuilding",false])
    || {((_casualtyGroup getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE"]};
["CLEAR-casualty-controller-continues",_continuing] call _check;
[_casualtyGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach _casualtyMembers;
deleteGroup _casualtyGroup;
deleteVehicle _casualtyHouse;

// Whole-lane loss after real entry must not let exterior reserves inherit entry evidence.
private _pairLossSite=[7150,6000,0];
private _pairLossHouse=createVehicle ["Land_i_House_Big_01_V1_F",_pairLossSite,[],0,"NONE"];
_pairLossHouse enableSimulationGlobal true;
[_pairLossHouse,"pair-loss"] call _validateNewFixturePlacement;
private _pairLossGroup=createGroup [east,true];
_pairLossGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_pairLossGroup setVariable ["acex_headless_blacklist",true,true];
private _pairLossMembers=[];
for "_i" from 0 to 11 do {
    private _actor=_pairLossGroup createUnit ["O_Soldier_F",_pairLossSite vectorAdd [-20+(_i mod 4)*4,-40-floor(_i/4)*4,0],[],0,"NONE"];
    _actor setVariable ["acex_headless_blacklist",true,true];
    _actor setVariable ["WAIT_CortexQA_Label",format ["PAIR LOSS / soldier %1",_i+1],true];
    _pairLossMembers pushBack _actor;
};
missionNamespace setVariable ["WAIT_CortexQA_Actors",_pairLossMembers,true];
["CQB whole-pair loss","After a real lane enters, both members become casualties. Both replacements must establish independent interior visits; shared coverage and inherited flags cannot pass.",getPosATL _pairLossHouse] call _phase;
private _pairLossAccepted=[_pairLossGroup,_pairLossHouse] call WAIT_fnc_CortexClearBuilding;
["CLEAR-pair-loss-accepted",_pairLossAccepted] call _check;
private _lostPair=[];
private _pairLossDeadline=-1;
private _pairLossReady=[{
    private _job=(_pairLossGroup getVariable ["WAIT_BuildingBrain",createHashMap]) getOrDefault ["job",createHashMap];
    private _entered=_job getOrDefault ["enteredActors",[]];
    private _pairs=_job getOrDefault ["pairs",[]];
    private _index=_pairs findIf {count _x == 2 && {_x findIf {_x in _entered} >= 0} && {_x findIf {!alive _x} < 0}};
    if (_index >= 0) then {_lostPair=+(_pairs select _index); _pairLossDeadline=_job getOrDefault ["hardDeadline",-1]};
    _index >= 0 && {_pairLossMembers select {!(_x in (_job getOrDefault ["team",[]]))} isNotEqualTo []}
},90] call _wait;
["CLEAR-pair-loss-entered-prerequisite",_pairLossReady && {count _lostPair == 2},str _lostPair] call _check;
private _pairLossReplacements=[];
if (_pairLossReady) then {
    {_x setDamage 1} forEach _lostPair;
    private _replaced=[{
        private _events=_pairLossGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]];
        _pairLossReplacements=[];
        {
            private _removed=netId _x;
            private _index=_events findIf {(_x param [1,""]) == _removed};
            if (_index >= 0) then {_pairLossReplacements pushBackUnique (objectFromNetId ((_events select _index) select 2))};
        } forEach _lostPair;
        count _pairLossReplacements == 2 && {_pairLossReplacements findIf {isNull _x} < 0}
    },30] call _wait;
    ["CLEAR-pair-loss-both-replaced",_replaced,str _pairLossReplacements] call _check;
    private _enteredReplacements=[];
    private _rooms=(_pairLossHouse buildingPos -1) select {
        private _origin=AGLToASL _x;
        private _roof=lineIntersectsSurfaces [_origin vectorAdd [0,0,0.5],_origin vectorAdd [0,0,10],objNull,objNull,true,1,"GEOM","NONE"];
        _roof isNotEqualTo [] && {((_roof select 0) select 2) == _pairLossHouse || {((_roof select 0) select 3) == _pairLossHouse}}
    };
    private _bothEntered=[{
        {private _actor=_x; if (_rooms findIf {[_actor,_pairLossHouse,_x] call _observedRoomVisit} >= 0) then {_enteredReplacements pushBackUnique _actor}} forEach _pairLossReplacements;
        count _enteredReplacements == 2
    },90] call _wait;
    ["CLEAR-pair-loss-both-physical-entry",_replaced && {_bothEntered},str _enteredReplacements] call _check;
    private _job=(_pairLossGroup getVariable ["WAIT_BuildingBrain",createHashMap]) getOrDefault ["job",createHashMap];
    ["CLEAR-pair-loss-original-deadline",_pairLossDeadline > 0 && {(_job getOrDefault ["hardDeadline",-2]) == _pairLossDeadline},str [_pairLossDeadline,_job getOrDefault ["hardDeadline",-2]]] call _check;
};
[_pairLossGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach _pairLossMembers;
deleteGroup _pairLossGroup;
deleteVehicle _pairLossHouse;

// Normal-only single-survivor regression. No reserve, lease or replacement movement is injected.
// The casualty is fault injection; only subsequent native movement can supply entry/progress.
if (!(missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false])) then {
    {
        private _lossSlot=_x;
        private _prefix=format ["CLEAR-single-survivor-slot-%1",_lossSlot];
        private _site=[7250+_lossSlot*100,6200,0];
        private _house=createVehicle ["Land_i_House_Big_01_V1_F",_site,[],0,"NONE"];
        _house enableSimulationGlobal true;
        [_house,_prefix] call _validateNewFixturePlacement;
        private _survivorGroup=createGroup [east,true];
        _survivorGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
        _survivorGroup setVariable ["acex_headless_blacklist",true,true];
        private _actors=[];
        for "_i" from 0 to 1 do {
            private _actor=_survivorGroup createUnit ["O_Soldier_F",_site vectorAdd [-8+_i*4,-30,0],[],0,"NONE"];
            _actor setVariable ["acex_headless_blacklist",true,true];
            _actor setVariable ["WAIT_CortexQA_Label",format ["SINGLE SURVIVOR %1 / soldier %2",_lossSlot,_i+1],true];
            _actors pushBack _actor;
        };
        missionNamespace setVariable ["WAIT_CortexQA_Actors",_actors,true];
        [format ["CQB single survivor: lose slot %1",_lossSlot],
            "After independently observed entry, one soldier becomes a casualty. No reserves exist. The survivor must physically enter and reach a new covered point through the original clearance job; no reset or movement assistance is injected.",getPosATL _house] call _phase;
        private _accepted=[_survivorGroup,_house] call WAIT_fnc_CortexClearBuilding;
        [_prefix+"-accepted",_accepted] call _check;
        private _rooms=(_house buildingPos -1) select {
            private _origin=AGLToASL _x;
            private _roof=lineIntersectsSurfaces [_origin vectorAdd [0,0,0.5],_origin vectorAdd [0,0,10],objNull,objNull,true,4,"GEOM","NONE"];
            _roof isNotEqualTo [] && {((_roof select 0) select 2) == _house || {((_roof select 0) select 3) == _house}}
        };
        private _pair=[];
        private _seen=createHashMap;
        private _originalDeadline=-1;
        private _originalGeneration=-1;
        private _ready=[{
            private _job=(_survivorGroup getVariable ["WAIT_BuildingBrain",createHashMap]) getOrDefault ["job",createHashMap];
            private _pairs=_job getOrDefault ["pairs",[]];
            if (_pair isEqualTo [] && {count _pairs == 1} && {count (_pairs select 0) == 2}) then {_pair=+(_pairs select 0)};
            {
                private _actor=_x;
                private _visits=_seen getOrDefault [netId _actor,[]];
                {
                    if ([_actor,_house,_x] call _observedRoomVisit) then {_visits pushBackUnique _forEachIndex};
                } forEach _rooms;
                _seen set [netId _actor,_visits];
            } forEach _pair;
            _originalDeadline=_job getOrDefault ["hardDeadline",-1];
            _originalGeneration=_job getOrDefault ["generation",-1];
            count _job > 0 && {_originalDeadline > 0} && {count _pair == 2} && {_pair findIf {!alive _x} < 0}
                && {_rooms findIf {[_pair select 0,_house,_x] call _observedRoomVisit} >= 0}
                && {_lossSlot != 0 || {count (_seen getOrDefault [netId (_pair select 1),[]]) == 0}}
        },90] call _wait;
        [_prefix+"-physical-prerequisite",_accepted && {_ready} && {_originalDeadline > 0},str [_pair,_seen]] call _check;
        if (_ready) then {
            private _casualty=_pair select _lossSlot;
            private _survivor=_pair select (1-_lossSlot);
            private _before=+(_seen getOrDefault [netId _survivor,[]]);
            private _start=getPosASL _survivor;
            private _episode=+(_survivorGroup getVariable ["WAIT_Cortex_ClearVisitContext",[]]);
            _casualty setDamage 1;
            private _deadlineChanged=false;
            private _newVisit=-1;
            private _progress=[{
                private _job=(_survivorGroup getVariable ["WAIT_BuildingBrain",createHashMap]) getOrDefault ["job",createHashMap];
                if (count _job > 0 && {(_job getOrDefault ["hardDeadline",-2]) != _originalDeadline}) then {_deadlineChanged=true};
                _newVisit=_rooms findIf {!((_rooms find _x) in _before) && {[_survivor,_house,_x] call _observedRoomVisit}};
                count _job > 0 && {(_job getOrDefault ["generation",-2]) == _originalGeneration}
                    && {alive _survivor} && {_newVisit >= 0}
                    && {(getPosASL _survivor) vectorDistance _start >= 3}
                    && {(_survivorGroup getVariable ["WAIT_Cortex_ClearVisitContext",[]]) isEqualTo _episode}
            },90] call _wait;
            [_prefix+"-independent-physical-progress",_progress,
                str [netId _survivor,_before,_newVisit,_start,getPosASL _survivor,currentCommand _survivor]] call _check;
            [_prefix+"-original-hard-deadline",!_deadlineChanged && {_originalDeadline > 0},str _originalDeadline] call _check;
            [_prefix+"-no-reserve-replacement",(_survivorGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]]) isEqualTo []] call _check;
        };
        [_survivorGroup] call WAIT_fnc_CortexClearRelease;
        missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
        {deleteVehicle _x} forEach _actors;
        deleteGroup _survivorGroup;
        deleteVehicle _house;
    } forEach [0,1];
};

// Exercise door handling through the real clearance job, never by calling its helper directly.
private _doorSite=[7350,5800,0];
private _doorHouse=createVehicle ["Land_i_House_Small_01_V1_F",_doorSite,[],0,"NONE"];
_doorHouse enableSimulationGlobal true;
[_doorHouse,"door"] call _validateNewFixturePlacement;
private _doorGroup=createGroup [east,true];
_doorGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_doorGroup setVariable ["acex_headless_blacklist",true,true];
private _doorMembers=[];
for "_i" from 0 to 1 do {
    private _unit=_doorGroup createUnit ["O_Soldier_F",_doorSite vectorAdd [_i*3,-30,0],[],0,"NONE"];
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["DOOR ORDER %1",_i+1],true];
    _doorMembers pushBack _unit;
};
missionNamespace setVariable ["WAIT_CortexQA_Actors",_doorMembers,true];
private _doorSource="Door_1_sound_source";
private _doorReady=isClass (configOf _doorHouse >> "AnimationSources" >> _doorSource)
    && {_doorHouse animationSourcePhase _doorSource < 0.1}
    && {(_doorHouse selectionPosition ["Door_1_trigger","Memory"]) isNotEqualTo [0,0,0]};
["CLEAR-door-fixture-closed-recognised",_doorReady] call _check;
// Isolate the entry stimulus: every recognised door stays locked except Door_1 after unlock.
private _fixtureDoors=[];
for "_doorIndex" from 1 to 64 do {
    private _source=format ["Door_%1_sound_source",_doorIndex];
    if (!isClass (configOf _doorHouse >> "AnimationSources" >> _source)) then {_source=format ["Door_%1_source",_doorIndex]};
    if (isClass (configOf _doorHouse >> "AnimationSources" >> _source)) then {
        _fixtureDoors pushBack [_doorIndex,_source];
        _doorHouse setVariable [format ["bis_disabled_Door_%1",_doorIndex],1,true];
    };
};
["CLEAR-door-all-entries-locked",count _fixtureDoors > 0 && {(_fixtureDoors findIf {_doorHouse animationSourcePhase (_x select 1) > 0.1}) < 0},str _fixtureDoors] call _check;
["Clearance: locked entry","The real clearance order must not unlock the front door. This phase checks the actual door phase and lock variable; it does not count an accepted order as entry.",getPosATL _doorHouse] call _phase;
private _doorAccepted=[_doorGroup,_doorHouse] call WAIT_fnc_CortexClearBuilding;
["CLEAR-door-order-accepted",_doorAccepted] call _check;
private _lockHeld=true;
private _lockedEntryEvidence=[];
private _lockedNodes=_doorHouse buildingPos -1;
private _lockedUntil=time+35;
waitUntil {
    sleep 1;
    if ((_fixtureDoors findIf {_doorHouse animationSourcePhase (_x select 1) > 0.1 || {(_doorHouse getVariable [format ["bis_disabled_Door_%1",_x select 0],0]) != 1}}) >= 0) then {_lockHeld=false};
    {
        private _actor=_x;
        private _node=_lockedNodes findIf {(getPosASL _actor) vectorDistance (AGLToASL _x) <= 1.5};
        if (alive _actor && {_node >= 0} && {_lockedEntryEvidence findIf {(_x select 0) == netId _actor} < 0}) then {
            _lockedEntryEvidence pushBack [netId _actor,_node,getPosASL _actor,time];
        };
    } forEach _doorMembers;
    time >= _lockedUntil
};
["CLEAR-door-lock-preserved",_doorReady && {_doorAccepted} && {_lockHeld}] call _check;
["CLEAR-door-locked-no-physical-entry",_doorReady && {_doorAccepted} && {_lockedEntryEvidence isEqualTo []},str _lockedEntryEvidence] call _check;
// Changing the lock is the test stimulus; opening and entry must be performed by production.
["Clearance: entry unlocked","The lock is now removed. Watch the same soldiers open the door and physically enter. The audit does not animate the door, teleport actors or reset their movement.",getPosATL _doorHouse] call _phase;
// The phase callback sleeps for presentation; apply the unlock only after it returns.
_doorHouse setVariable ["bis_disabled_Door_1",0,true];
private _doorPositions=_doorHouse buildingPos -1;
private _doorOpened=false;
private _entered=false;
private _entryEvidence=[];
private _unlockedDeadline=time+90;
private _nextDoorTrace=time;
diag_log format ["WAIT DOOR OBSERVER NODES: %1",_doorPositions apply {AGLToASL _x}];
waitUntil {
    sleep 0.25;
    if (_doorHouse animationSourcePhase _doorSource >= 0.8) then {_doorOpened=true};
    if (time >= _nextDoorTrace) then {
        _nextDoorTrace=time+5;
        {
            private _actor=_x;
            private _nearest=1e12;
            {_nearest=_nearest min ((getPosASL _actor) vectorDistance (AGLToASL _x))} forEach _doorPositions;
            diag_log format ["WAIT DOOR OBSERVER ACTOR: %1",[time,netId _actor,alive _actor,getPosASL _actor,
                _nearest,currentCommand _actor,_doorHouse animationSourcePhase _doorSource]];
        } forEach _doorMembers;
    };
    // Sample physical arrival throughout the unlocked phase; animation sources may lag traversal.
    if (!_entered) then {
        {
            private _actor=_x;
            private _node=_doorPositions findIf {(getPosASL _actor) vectorDistance (AGLToASL _x) <= 1.5};
            if (alive _actor && {_node >= 0}) then {
                _entered=true;
                _entryEvidence pushBack [netId _actor,_node,getPosASL _actor,time,_doorHouse animationSourcePhase _doorSource];
            };
        } forEach _doorMembers;
    };
    (_doorOpened && {_entered}) || {time >= _unlockedDeadline}
};
["CLEAR-door-unlocked-opens",_doorReady && {_doorOpened}] call _check;
["CLEAR-door-unlocked-physical-entry",_doorReady && {_doorOpened} && {_entered},str _entryEvidence] call _check;
[_doorGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach _doorMembers;
deleteGroup _doorGroup;
deleteVehicle _doorHouse;

// Natural building contact acceptance. This fixture supplies only live opposing actors and geometry:
// no reveal, direct clear call, target assignment or movement command is injected after spawning.
// The production contact brain must first acquire the hostile through the engine, identify that the
// fresh contact is physically inside the house, and hand the same squad to the building operation.
private _contactSite=[7550,5800,0];
private _contactHouse=createVehicle ["Land_i_House_Small_01_V1_F",_contactSite,[],0,"NONE"];
_contactHouse enableSimulationGlobal true;
[_contactHouse,"contact"] call _validateNewFixturePlacement;
private _contactRooms=_contactHouse buildingPos -1;
// Find an exterior approach with a genuine view through an opening before creating actors.
// A hidden room plus an arbitrary rear approach tests absent detection, not contact-to-clear.
private _contactRoom=[];
private _contactApproach=[];
{
    private _room=_x;
    for "_bearing" from 0 to 337.5 step 22.5 do {
        private _approach=_contactSite getPos [38,_bearing];
        private _from=AGLToASL (_approach vectorAdd [0,0,1.5]);
        private _to=AGLToASL (_room vectorAdd [0,0,1.5]);
        if ((lineIntersectsSurfaces [_from,_to,objNull,objNull,true,1,"VIEW","NONE"]) isEqualTo []) exitWith {
            _contactRoom=+_room; _contactApproach=+_approach;
        };
    };
    if (_contactRoom isNotEqualTo []) exitWith {};
} forEach (_contactRooms select [0,16]);
private _contactGeometryReady=_contactRoom isNotEqualTo [];
if (!_contactGeometryReady) then {_contactRoom=_contactRooms param [0,getPosATL _contactHouse]; _contactApproach=_contactSite vectorAdd [-12,-38,0]};
private _contactGroup=createGroup [east,true];
private _contactOpposition=createGroup [west,true];
{
    _x setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
} forEach [_contactGroup,_contactOpposition];
_contactOpposition setVariable ["WAIT_AIPass_Exclude",true,true];
private _contactMembers=[];
for "_i" from 0 to 5 do {
    private _rowOrigin=_contactApproach getPos [floor (_i/3)*3,(_contactApproach getDir _contactHouse)+180];
    private _unit=_contactGroup createUnit ["O_Soldier_F",_rowOrigin getPos [(_i mod 3)*3,(_contactApproach getDir _contactHouse)+90],[],0,"NONE"];
    _unit allowDamage false;
    _unit setDir (_unit getDir _contactHouse);
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["NATURAL CQB %1",_i+1],true];
    _contactMembers pushBack _unit;
};
private _contactEnemy=_contactOpposition createUnit ["B_Soldier_F",_contactRoom,[],0,"NONE"];
_contactEnemy allowDamage false;
// This contact-to-clear fixture requires a posted interior defender, not a pursuer that
// leaves the building before the squad acquires it. Native sensing, aiming and fire remain.
_contactEnemy disableAI "PATH";
_contactEnemy setDir (_contactEnemy getDir leader _contactGroup);
_contactEnemy setVariable ["acex_headless_blacklist",true,true];
_contactEnemy setVariable ["WAIT_CortexQA_Label","INDOOR LIVE HOSTILE",true];
_contactGroup setCombatMode "RED";
_contactOpposition setCombatMode "RED";
[createHashMapFromArray [
    ["WAIT_AIPass_BuildingCombat_Enable",true],
    ["WAIT_AIPass_BuildingCombat_Range",100],
    ["WAIT_AIPass_Contact_Enable",true]
]] call WAIT_fnc_CortexTuning;
private _contactSightline=_contactGeometryReady && {_contactMembers findIf {
    (lineIntersectsSurfaces [eyePos _x,eyePos _contactEnemy,_x,_contactEnemy,true,1,"VIEW","NONE"]) isEqualTo []
} >= 0};
["BUILD-CONTACT-visible-fixture",_contactSightline,str [_contactRoom,_contactApproach,_contactGeometryReady]] call _check;
missionNamespace setVariable ["WAIT_CortexQA_Actors",_contactMembers+[_contactEnemy],true];
["Natural building contact","The six-person squad faces a live hostile physically inside the house. Native knowledge must form first; WAIT should then transition directly from contact into its single building-clear operation and physically enter. The hostile is a posted interior defender with pathfinding disabled; native sensing and fire remain. The audit injects no reveal, clear order or route.",getPosATL _contactHouse] call _phase;
private _nativeContact=[{(units _contactGroup) findIf {_x knowsAbout _contactEnemy >= 1} >= 0},30] call _wait;
["BUILD-CONTACT-native-knowledge",_nativeContact,str (_contactMembers apply {_x knowsAbout _contactEnemy})] call _check;
private _interiorDefenderHeld=(getPosASL _contactEnemy) vectorDistance (AGLToASL _contactRoom) <= 1.5;
["BUILD-CONTACT-interior-defender-retained",_interiorDefenderHeld,
    str [getPosATL _contactEnemy,_contactRoom,currentCommand _contactEnemy]] call _check;
private _naturalClear=[{_contactGroup getVariable ["WAIT_AIPass_ClearBuilding",false]},20] call _wait;
["BUILD-CONTACT-natural-clear-started",_nativeContact && {_naturalClear},str [_contactGroup getVariable ["WAIT_Cortex_ClearStatus",[]],_contactGroup getVariable ["WAIT_OperationResult",[]]]] call _check;
private _contactTraceAt=diag_tickTime;
private _contactTraceCount=0;
private _naturalEntry=[{
    if (diag_tickTime >= _contactTraceAt && {_contactTraceCount < 12}) then {
        _contactTraceAt=diag_tickTime+8;
        _contactTraceCount=_contactTraceCount+1;
        private _brain=_contactGroup getVariable ["WAIT_BuildingBrain",createHashMap];
        private _job=_brain getOrDefault ["job",createHashMap];
        private _operation=_contactGroup getVariable ["WAIT_Operation",createHashMap];
        diag_log format ["WAIT BUILD CONTACT OWNER: %1",[_contactTraceCount,
            _operation getOrDefault ["intent",""],_operation getOrDefault ["generation",-1],
            _job getOrDefault ["phase",""],_brain getOrDefault ["lastStepAt",-1],
            attackEnabled leader _contactGroup,_contactGroup getVariable ["WAIT_Cortex_ClearStatus",[]]]];
        {
            private _key=netId _x;
            diag_log format ["WAIT BUILD CONTACT ACTOR: %1",[_contactTraceCount,_key,alive _x,
                getPosATL _x,currentCommand _x,expectedDestination _x,
                _x in (_job getOrDefault ["team",[]]),
                (_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [_key,[]],
                (_job getOrDefault ["actorVisits",createHashMap]) getOrDefault [_key,[]],
                _x getVariable ["WAIT_Cortex_ActorMove",[]],getUnitState _x]];
        } forEach (_contactMembers select [0,16]);
    };
    _contactRooms findIf {
    private _room=_x;
    _contactMembers findIf {alive _x && {(getPosASL _x) vectorDistance (AGLToASL _room) <= 1.5 && {abs (((getPosASL _x) select 2)-((AGLToASL _room) select 2)) <= 0.75}}} >= 0
} >= 0},90] call _wait;
["BUILD-CONTACT-physical-entry",_naturalClear && {_naturalEntry},str (_contactMembers apply {[getPosATL _x,currentCommand _x,expectedDestination _x]})] call _check;
[_contactGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach (_contactMembers+[_contactEnemy]);
deleteGroup _contactGroup;
deleteGroup _contactOpposition;
deleteVehicle _contactHouse;

// Independent natural-contact continuation case; original no-route acceptance above is retained.
// One plain patrol waypoint is established before enabling contact. After actual entry, the
// initially protected defender becomes vulnerable; only native gunfire may kill it. No later
// waypoint/actor movement/reset/clear request or result assignment can manufacture continuation.
if (!(missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false])) then {
private _routeContactSite=[7750,5800,0];
private _routeContactHouse=createVehicle ["Land_i_House_Small_01_V1_F",_routeContactSite,[],0,"NONE"];
_routeContactHouse enableSimulationGlobal true;
[_routeContactHouse,"contact-route"] call _validateNewFixturePlacement;
private _routeContactRooms=_routeContactHouse buildingPos -1;
// Find an exterior approach with a genuine view through an opening before creating actors.
// A hidden room plus an arbitrary rear approach tests absent detection, not contact-to-clear.
private _routeContactRoom=[];
private _routeContactApproach=[];
{
    private _room=_x;
    for "_bearing" from 0 to 337.5 step 22.5 do {
        private _approach=_routeContactSite getPos [38,_bearing];
        private _from=AGLToASL (_approach vectorAdd [0,0,1.5]);
        private _to=AGLToASL (_room vectorAdd [0,0,1.5]);
        if ((lineIntersectsSurfaces [_from,_to,objNull,objNull,true,1,"VIEW","NONE"]) isEqualTo []) exitWith {
            _routeContactRoom=+_room; _routeContactApproach=+_approach;
        };
    };
    if (_routeContactRoom isNotEqualTo []) exitWith {};
} forEach (_routeContactRooms select [0,16]);
private _routeContactGeometryReady=_routeContactRoom isNotEqualTo [];
if (!_routeContactGeometryReady) then {_routeContactRoom=_routeContactRooms param [0,getPosATL _routeContactHouse]; _routeContactApproach=_routeContactSite vectorAdd [-12,-38,0]};
private _routeContactGroup=createGroup [east,true];
private _routeContactOpposition=createGroup [west,true];
{
    _x setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
} forEach [_routeContactGroup,_routeContactOpposition];
_routeContactOpposition setVariable ["WAIT_AIPass_Exclude",true,true];
private _routeContactMembers=[];
for "_i" from 0 to 5 do {
    private _rowOrigin=_routeContactApproach getPos [floor (_i/3)*3,(_routeContactApproach getDir _routeContactHouse)+180];
    private _unit=_routeContactGroup createUnit ["O_Soldier_F",_rowOrigin getPos [(_i mod 3)*3,(_routeContactApproach getDir _routeContactHouse)+90],[],0,"NONE"];
    _unit allowDamage false;
    _unit setVariable ["WAIT_CortexQA_RouteShots",0];
    _unit addEventHandler ["FiredMan",{
        params ["_unit"];
        _unit setVariable ["WAIT_CortexQA_RouteShots",(_unit getVariable ["WAIT_CortexQA_RouteShots",0])+1];
    }];
    _unit setDir (_unit getDir _routeContactHouse);
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["NATURAL ROUTE CQB %1",_i+1],true];
    _routeContactMembers pushBack _unit;
};
private _routeContactEnemy=_routeContactOpposition createUnit ["B_Soldier_F",_routeContactRoom,[],0,"NONE"];
_routeContactEnemy allowDamage false;
// This contact-to-clear fixture requires a posted interior defender, not a pursuer that
// leaves the building before the squad acquires it. Native sensing, aiming and fire remain.
_routeContactEnemy disableAI "PATH";
_routeContactEnemy setDir (_routeContactEnemy getDir leader _routeContactGroup);
_routeContactEnemy setVariable ["acex_headless_blacklist",true,true];
_routeContactEnemy setVariable ["WAIT_CortexQA_Label","INDOOR LIVE HOSTILE",true];
private _routeDestination=_routeContactSite vectorAdd [0,170,0];
private _routeWaypoint=_routeContactGroup addWaypoint [_routeDestination,0];
_routeWaypoint setWaypointType "MOVE";
_routeWaypoint setWaypointSpeed "LIMITED";
_routeContactGroup setCurrentWaypoint _routeWaypoint;
private _routeReceipt=[_routeContactGroup] call WAIT_fnc_NativeOrderReceipt;
_routeContactEnemy addEventHandler ["Killed",{
    params ["_unit","_killer","_instigator"];
    _unit setVariable ["WAIT_CortexQA_RouteKilledBy",if (isNull _instigator) then {_killer} else {_instigator}];
}];
_routeContactGroup setCombatMode "RED";
_routeContactOpposition setCombatMode "RED";
[createHashMapFromArray [
    ["WAIT_AIPass_BuildingCombat_Enable",true],
    ["WAIT_AIPass_BuildingCombat_Range",100],
    ["WAIT_AIPass_Contact_Enable",true]
]] call WAIT_fnc_CortexTuning;
private _routeContactSightline=_routeContactGeometryReady && {_routeContactMembers findIf {
    (lineIntersectsSurfaces [eyePos _x,eyePos _routeContactEnemy,_x,_routeContactEnemy,true,1,"VIEW","NONE"]) isEqualTo []
} >= 0};
["BUILD-CONTINUE-visible-fixture",_routeContactSightline,str [_routeContactRoom,_routeContactApproach,_routeContactGeometryReady]] call _check;
missionNamespace setVariable ["WAIT_CortexQA_Actors",_routeContactMembers+[_routeContactEnemy],true];
["Natural CQB: original patrol route","The squad starts with one plain patrol waypoint. Native contact must trigger clearance and physical entry. Then the posted defender becomes vulnerable to real fire. Successful physical clearance must hand back to the original waypoint without any new test-side movement order. Protected attackers make this a controller-flow diagnostic, not combat-effectiveness proof.",getPosATL _routeContactHouse] call _phase;
private _routeNativeContact=[{(units _routeContactGroup) findIf {_x knowsAbout _routeContactEnemy >= 1} >= 0},30] call _wait;
["BUILD-CONTINUE-native-knowledge",_routeNativeContact,str (_routeContactMembers apply {_x knowsAbout _routeContactEnemy})] call _check;
private _routeDefenderHeld=(getPosASL _routeContactEnemy) vectorDistance (AGLToASL _routeContactRoom) <= 1.5;
["BUILD-CONTINUE-interior-defender-retained",_routeDefenderHeld,
    str [getPosATL _routeContactEnemy,_routeContactRoom,currentCommand _routeContactEnemy]] call _check;
private _routeNaturalClear=[{_routeContactGroup getVariable ["WAIT_AIPass_ClearBuilding",false]},20] call _wait;
["BUILD-CONTINUE-natural-clear-started",_routeNativeContact && {_routeNaturalClear},str [_routeContactGroup getVariable ["WAIT_Cortex_ClearStatus",[]],_routeContactGroup getVariable ["WAIT_OperationResult",[]]]] call _check;
private _routeContactTraceAt=diag_tickTime;
private _routeContactTraceCount=0;
private _routeVisitTargets=_routeContactRooms select {
    private _origin=AGLToASL _x;
    private _roof=lineIntersectsSurfaces [_origin vectorAdd [0,0,0.5],_origin vectorAdd [0,0,10],objNull,objNull,true,1,"GEOM","NONE"];
    _roof isNotEqualTo [] && {((_roof select 0) select 2) == _routeContactHouse || {((_roof select 0) select 3) == _routeContactHouse}}
};
private _routeVisits=_routeVisitTargets apply {false};
private _observeRouteRooms={
    {
        if (!(_routeVisits select _forEachIndex)) then {
            private _room=_x;
            if (_routeContactMembers findIf {[_x,_routeContactHouse,_room] call _observedRoomVisit} >= 0) then {
                _routeVisits set [_forEachIndex,true];
            };
        };
    } forEach _routeVisitTargets;
};
private _routeNaturalEntry=[{
    call _observeRouteRooms;
    if (diag_tickTime >= _routeContactTraceAt && {_routeContactTraceCount < 12}) then {
        _routeContactTraceAt=diag_tickTime+8;
        _routeContactTraceCount=_routeContactTraceCount+1;
        private _brain=_routeContactGroup getVariable ["WAIT_BuildingBrain",createHashMap];
        private _job=_brain getOrDefault ["job",createHashMap];
        private _operation=_routeContactGroup getVariable ["WAIT_Operation",createHashMap];
        diag_log format ["WAIT BUILD CONTINUE OWNER: %1",[_routeContactTraceCount,
            _operation getOrDefault ["intent",""],_operation getOrDefault ["generation",-1],
            _job getOrDefault ["phase",""],_brain getOrDefault ["lastStepAt",-1],
            attackEnabled leader _routeContactGroup,_routeContactGroup getVariable ["WAIT_Cortex_ClearStatus",[]]]];
        {
            private _key=netId _x;
            diag_log format ["WAIT BUILD CONTINUE ACTOR: %1",[_routeContactTraceCount,_key,alive _x,
                getPosATL _x,currentCommand _x,expectedDestination _x,
                _x in (_job getOrDefault ["team",[]]),
                (_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [_key,[]],
                (_job getOrDefault ["actorVisits",createHashMap]) getOrDefault [_key,[]],
                _x getVariable ["WAIT_Cortex_ActorMove",[]],getUnitState _x]];
        } forEach (_routeContactMembers select [0,16]);
    };
    _routeContactRooms findIf {
    private _room=_x;
    _routeContactMembers findIf {[_x,_routeContactHouse,_room] call _observedRoomVisit} >= 0
} >= 0},90] call _wait;
["BUILD-CONTINUE-physical-entry",_routeNaturalClear && {_routeNaturalEntry},str (_routeContactMembers apply {[getPosATL _x,currentCommand _x,expectedDestination _x]})] call _check;
// Enable real casualty resolution only after entry was independently observed. No setDamage,
// target/reveal or forced-fire call supplies a kill, room visit, result or movement outcome.
if (_routeNaturalEntry) then {_routeContactEnemy allowDamage true};
private _routeTerminal=[{
    call _observeRouteRooms;
    ((_routeContactGroup getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE","CANCELLED"]
},180] call _wait;
private _routeOutcome=(_routeContactGroup getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""];
private _routeShots=0;
{_routeShots=_routeShots+(_x getVariable ["WAIT_CortexQA_RouteShots",0])} forEach _routeContactMembers;
private _defenderKilled=!alive _routeContactEnemy
    && {(_routeContactEnemy getVariable ["WAIT_CortexQA_RouteKilledBy",objNull]) in _routeContactMembers}
    && {_routeShots > 0};
["BUILD-CONTINUE-real-defender-casualty",_routeNaturalEntry && {_defenderKilled},
    str [alive _routeContactEnemy,_routeShots,_routeContactEnemy getVariable ["WAIT_CortexQA_RouteKilledBy",objNull]]] call _check;
["BUILD-CONTINUE-clearance-complete",_routeNativeContact && {_routeNaturalClear} && {_routeNaturalEntry}
    && {_routeTerminal} && {_routeOutcome == "COMPLETE"},str (_routeContactGroup getVariable ["WAIT_Cortex_ClearResult",[]])] call _check;
private _routePhysicalClear=_routeVisits isNotEqualTo [] && {_routeVisits findIf {!_x} < 0};
["BUILD-CONTINUE-physical-room-coverage",_routeNaturalClear && {_routePhysicalClear},str [_routeVisitTargets,_routeVisits]] call _check;
private _continuationOrigins=_routeContactMembers apply {getPosATL _x};
private _continued=false;
if (_routeTerminal && {_routeOutcome == "COMPLETE"} && {_defenderKilled} && {_routePhysicalClear}) then {
    _continued=[{
        private _bounds=boundingBoxReal _routeContactHouse;
        private _low=_bounds select 0;private _high=_bounds select 1;
        _routeContactMembers findIf {
            private _index=_routeContactMembers find _x;
            private _origin=_continuationOrigins select _index;
            private _model=_routeContactHouse worldToModel (getPosATL _x);
            private _outside=(_model select 0) < (_low select 0)-0.5 || {(_model select 0) > (_high select 0)+0.5}
                || {(_model select 1) < (_low select 1)-0.5} || {(_model select 1) > (_high select 1)+0.5};
            !alive _x || {!simulationEnabled _x} || {isObjectHidden _x} || {!isNull objectParent _x}
                || {!_outside} || {_x distance2D _origin < 25}
                || {(_origin distance2D _routeDestination)-(_x distance2D _routeDestination) < 20}
        } < 0
    },90] call _wait;
};
["BUILD-CONTINUE-original-route-physical",_continued,
    str (_routeContactMembers apply {[netId _x,getPosATL _x,currentCommand _x,expectedDestination _x]})] call _check;
["BUILD-CONTINUE-authored-route-retained",_continued
    && {([_routeContactGroup] call WAIT_fnc_NativeOrderReceipt) isEqualTo _routeReceipt},
    str [_routeReceipt,[_routeContactGroup] call WAIT_fnc_NativeOrderReceipt]] call _check;
[_routeContactGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach (_routeContactMembers+[_routeContactEnemy]);
deleteGroup _routeContactGroup;
deleteGroup _routeContactOpposition;
deleteVehicle _routeContactHouse;

};

// A newer actor destination is distinct from the replaced group room route.
private _overrideSite=[7950,6100,0];
private _overrideHouse=createVehicle ["Land_i_House_Small_01_V1_F",_overrideSite,[],0,"NONE"];
[_overrideHouse,"actor-order"] call _validateNewFixturePlacement;
private _overrideGroup=createGroup [east,true];
_overrideGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_overrideGroup setVariable ["acex_headless_blacklist",true,true];
private _overrideMembers=[];
for "_index" from 0 to 1 do {
    private _unit=_overrideGroup createUnit ["O_Soldier_F",_overrideSite vectorAdd [_index*3,-30,0],[],0,"NONE"];
    _unit setVariable ["WAIT_CortexQA_Label",format ["NATIVE ORDER %1",_index+1],true];
    _overrideMembers pushBack _unit;
};
missionNamespace setVariable ["WAIT_CortexQA_Actors",_overrideMembers,true];
["Clearance: newer actor movement","After real clearance movement begins, one soldier receives a different native destination and the group receives a new waypoint. The old room operation must retire while that soldier physically follows its own newer destination. No movement reset or completion callback is injected.",getPosATL _overrideHouse] call _phase;
private _overrideAccepted=[_overrideGroup,_overrideHouse] call WAIT_fnc_CortexClearBuilding;
private _overrideActor=_overrideMembers select 1;
private _overrideReady=[{
    private _job=(_overrideGroup getVariable ["WAIT_BuildingBrain",createHashMap]) getOrDefault ["job",createHashMap];
    netId _overrideActor in (_job getOrDefault ["movementTargets",createHashMap])
        && {currentCommand _overrideActor == "MOVE"}
},20] call _wait;
["CLEAR-native-actor-order-owned-route-ready",_overrideAccepted && {_overrideReady}] call _check;
private _overrideStart=getPosATL _overrideActor;
private _actorDestination=_overrideSite vectorAdd [-45,-25,0];
_overrideActor doMove _actorDestination;
private _groupWaypoint=_overrideGroup addWaypoint [_overrideSite vectorAdd [75,-25,0],0];
_groupWaypoint setWaypointType "MOVE";
_overrideGroup setCurrentWaypoint _groupWaypoint;
private _overrideMoved=[{
    private _destination=(expectedDestination _overrideActor) param [0,[]];
    count _destination == 3 && {_destination vectorDistance _actorDestination <= 0.25}
        && {_overrideActor distance2D _overrideStart >= 8}
},30] call _wait;
["CLEAR-native-actor-order-preserved-physical",_overrideReady && {_overrideMoved},
    str [getPosATL _overrideActor,_actorDestination,currentCommand _overrideActor,expectedDestination _overrideActor]] call _check;
["CLEAR-native-actor-order-old-clear-retired",!(_overrideGroup getVariable ["WAIT_AIPass_ClearBuilding",false])
    && {((_overrideGroup getVariable ["WAIT_OperationResult",[]]) param [4,""]) == "NEW_ORDER"},
    str (_overrideGroup getVariable ["WAIT_OperationResult",[]])] call _check;
[_overrideGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach _overrideMembers;
deleteGroup _overrideGroup;
deleteVehicle _overrideHouse;

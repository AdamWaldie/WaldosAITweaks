/*
 * Author: WaldoTheWarfighter
 * Compares physical building entry using independent engine commands across small and large,
 * single- and multi-storey house models, then exercises production garrison and clearance.
 * Locality/authority: scheduled dedicated-server audit; all actors are pinned to this owner.
 * Clearance acceptance requires covered interior navigation positions; exposed positions remain
 * separately recorded as exterior evidence, rather than being counted as uncleared rooms.
 * Repeat/JIP: disposable actors and houses are removed; observer state is public for joining clients.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>; all required audit callbacks.
 * Return: Nothing. Current callers: cortexQA/runServer.sqf.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQABuildings.sqf";
 */
params ["_check","_phase","_wait"];
private _cases = [];
private _actors = [];
{
    private _class = _x;
    private _row = _forEachIndex;
    {
        private _method = _x;
        private _house = createVehicle [_class,[6250+_forEachIndex*60,5800+_row*60,0],[],0,"NONE"];
        _house enableSimulationGlobal true;
        private _group = createGroup [east,true];
        _group setVariable ["WAIT_AIPass_Exclude",true,true];
        _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
        _group setVariable ["acex_headless_blacklist",true,true];
        private _unit = _group createUnit ["O_Soldier_F",_house getPos [25,180],[],0,"NONE"];
        _unit setVariable ["acex_headless_blacklist",true,true];
        _unit allowDamage false;
        private _target = (_house buildingPos -1) param [0,[]];
        private _label = format ["%1 / model %2",_method,_row+1];
        _unit setVariable ["WAIT_CortexQA_Label",_label,true];
        _unit setVariable ["WAIT_CortexQA_Target",_target,true];
        _actors pushBack _unit;
        _cases pushBack [_group,_unit,_house,_target,_method,_label,false];
    } forEach ["DIRECT","HOUSE-WAYPOINT","REPLAN"];
} forEach ["Land_i_House_Small_03_V1_F","Land_i_House_Small_01_V1_F","Land_i_House_Big_01_V1_F","Land_i_House_Big_02_V1_F"];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_actors,true];
["Building entry: independent comparisons","Twelve excluded soldiers compare direct movement, a building-attached waypoint and forced path replanning across small and large, single- and multi-storey houses. Cyan trails show actual movement; targets show remaining distance. Each model reports independently and does not replace the production clearance cases.",[6280,5890,0]] call _phase;
{
    _x params ["_group","_unit","_house","_target","_method","_label"];
    private _valid = simulationEnabled _house && {simulationEnabled _unit} && {local _unit} && {_target isNotEqualTo []};
    [format ["BUILD-%1-ready",_label],_valid] call _check;
    if (_valid) then {
        if (_method in ["DIRECT","REPLAN"]) then {doStop _unit; _unit doMove _target; if (_method == "REPLAN") then {_unit setDestination [_target,"LEADER PLANNED",true]}} else {
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
} forEach _cases;
sleep 15;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{_x params ["_group","_unit","_house"]; deleteVehicle _unit; deleteGroup _group; deleteVehicle _house} forEach _cases;

// Fresh groups distinguish clearance defects from state left by a previous garrison.
// Keep all original comparisons above, including their failures.
{
    _x params ["_size","_class"];
    private _house=createVehicle [_class,[6250,5800,0],[],0,"NONE"];
    _house enableSimulationGlobal true;
    private _group=createGroup [east,true];
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    private _members=[];
    for "_i" from 0 to (_size-1) do {
        private _unit=_group createUnit ["O_Soldier_F",[6235+(_i mod 4)*4,5760-floor(_i/4)*4,0],[],0,"NONE"];
        _unit setVariable ["acex_headless_blacklist",true,true];
        _unit setVariable ["WAIT_CortexQA_Label",format ["FRESH CLEAR %1 / soldier %2",_size,_i+1],true];
        _members pushBack _unit;
    };
    missionNamespace setVariable ["WAIT_CortexQA_Actors",_members,true];
    [format ["Fresh clearance: %1 soldiers / %2",_size,_class],"This fresh group has never garrisoned. Watch clearing pairs physically enter and continue through their assigned sector. The 2/6/12-person cases use progressively larger building models. Markers are navigation positions, not proof that a hostile room is safe. No test-side teleport, door opening or forced completion is applied.",getPosATL _house] call _phase;
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
    private _accepted=[_group,_house] call WAIT_fnc_CortexClearBuilding;
    [format ["CLEAR-fresh-%1-accepted",_size],_accepted] call _check;
    private _entryEpoch=_group getVariable ["WAIT_AIPass_Epoch",0];
    private _entryGeneration=(_group getVariable ["WAIT_Operation",createHashMap]) getOrDefault ["generation",-1];
    private _entryOwnerStable=true;
    [format ["CLEAR-fresh-%1-owner-established",_size],_accepted && {_entryEpoch > 0}
        && {_group getVariable ["WAIT_AIPass_Adopted",false]} && {_entryGeneration >= 0},
        str [_entryEpoch,_entryGeneration]] call _check;
    [{
        private _currentOperation=_group getVariable ["WAIT_Operation",createHashMap];
        if ((_group getVariable ["WAIT_AIPass_Epoch",0]) != _entryEpoch
            || {count _currentOperation > 0 && {(_currentOperation getOrDefault ["generation",-1]) != _entryGeneration}}) then {
            _entryOwnerStable=false;
        };
        {private _room=_x; private _roomIndex=_forEachIndex; if (_clearingMembers findIf {alive _x && {(getPosASL _x) vectorDistance (AGLToASL _room) <= 1.5}} >= 0) then {_visits set [_roomIndex,true]}} forEach _rooms;
        {
            private _worker=_x;
            private _seen=_memberVisits select _forEachIndex;
            {if (alive _worker && {(getPosASL _worker) vectorDistance (AGLToASL _x) <= 1.5}) then {_seen pushBackUnique _forEachIndex}} forEach _rooms;
        } forEach _clearingMembers;
        {
            private _position=_x;
            if (_clearingMembers findIf {alive _x && {(getPosASL _x) vectorDistance (AGLToASL _position) <= 1.5}} >= 0) then {
                _exteriorVisits set [_forEachIndex,true];
            };
        } forEach _exteriorRooms;
        missionNamespace setVariable ["WAIT_CortexQA_Rooms",[_rooms,_visits],true];
        ((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE"]
    },245] call _wait;
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
    private _physical=_rooms isNotEqualTo [] && {_visits findIf {!_x} < 0};
    [format ["CLEAR-fresh-%1-physical-room-visits",_size],_physical,format ["visits=%1 units=%2",_visits,_members apply {[getPosATL _x,currentCommand _x,expectedDestination _x,_x checkAIFeature "PATH",_x checkAIFeature "MOVE",behaviour _x]}]] call _check;
    [format ["CLEAR-fresh-%1-result-agrees",_size],_physical && {((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) == "COMPLETE"}] call _check;
    [format ["CLEAR-fresh-%1-successive-positions",_size],_memberVisits findIf {count _x >= 2} >= 0,str _memberVisits] call _check;
    if (_size == 2) then {
        ["CLEAR-fresh-2-both-participate",_memberVisits findIf {_x isEqualTo []} < 0,str _memberVisits] call _check;
    };
    // Exercise natural completion/failure cleanup before invoking any explicit release.
    // A fresh ordinary waypoint must take control even when some rooms were unreachable.
    private _destination=[6325,5770,0];
    private _beforeMove=_members apply {getPosATL _x};
    private _waypoint=_group addWaypoint [_destination,0];
    _waypoint setWaypointType "MOVE";
    _group setCurrentWaypoint _waypoint;
    [format ["Clearance handover: %1 soldiers",_size],"After the recorded clearance result, the same soldiers must follow an ordinary waypoint away from the building. No cleanup function or movement reset is injected before this check.",_destination] call _phase;
    private _moved=[{
        private _allMoved=true;
        {
            if (!alive _x || {_x distance2D (_beforeMove select _forEachIndex) < 25} || {_x distance2D _destination > 18}) then {_allMoved=false};
        } forEach _members;
        _allMoved
    },90] call _wait;
    [format ["CLEAR-fresh-%1-handover-physical",_size],_moved,str (_members apply {getPosATL _x})] call _check;
    sleep 8;
    [_group] call WAIT_fnc_CortexClearRelease;
    missionNamespace setVariable ["WAIT_CortexQA_Rooms",[],true];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
    {deleteVehicle _x} forEach _members;
    deleteGroup _group;
    deleteVehicle _house;
} forEach [[2,"Land_i_House_Small_01_V1_F"],[6,"Land_i_House_Big_01_V1_F"],[12,"Land_i_House_Big_02_V1_F"]];

// A casualty inside the clearing element must not strand the shared room queue. Use ten soldiers
// so the production eight-worker cap leaves a genuine squad reserve available as a replacement.
private _casualtyHouse=createVehicle ["Land_i_House_Big_01_V1_F",[6250,5800,0],[],0,"NONE"];
_casualtyHouse enableSimulationGlobal true;
private _casualtyGroup=createGroup [east,true];
_casualtyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_casualtyGroup setVariable ["acex_headless_blacklist",true,true];
private _casualtyMembers=[];
for "_i" from 0 to 9 do {
    private _unit=_casualtyGroup createUnit ["O_Soldier_F",[6230+(_i mod 5)*4,5760-floor(_i/5)*4,0],[],0,"NONE"];
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["CQB CASUALTY / soldier %1",_i+1],true];
    _casualtyMembers pushBack _unit;
};
missionNamespace setVariable ["WAIT_CortexQA_Actors",_casualtyMembers,true];
["CQB casualty reinforcement","The ten-person squad starts with eight independent clearing workers and two reserves. One clearing soldier becomes a real casualty. A surviving reserve must join the clear and physically move toward the building; the remaining room queue must stay active.",getPosATL _casualtyHouse] call _phase;
private _casualtyAccepted=[_casualtyGroup,_casualtyHouse] call WAIT_fnc_CortexClearBuilding;
["CLEAR-casualty-order-accepted",_casualtyAccepted] call _check;
private _jobStarted=[{_casualtyGroup getVariable ["WAIT_AIPass_ClearBuilding",false]},15] call _wait;
["CLEAR-casualty-job-started",_jobStarted] call _check;
private _casualty=_casualtyMembers select 1;
private _reserve=_casualtyMembers select 9;
private _reserveStart=getPosATL _reserve;
private _evidenceBefore=count (_casualtyGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]]);
_casualty setDamage 1;
private _reinforced=[{
    private _evidence=_casualtyGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]];
    count _evidence > _evidenceBefore
        && {_evidence findIf {(_x param [1,""]) == netId _casualty && {(_x param [2,""]) == netId _reserve}} >= 0}
},30] call _wait;
["CLEAR-casualty-reserve-assigned",_reinforced,str (_casualtyGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]])] call _check;
private _reserveOperation=_casualtyGroup getVariable ["WAIT_Operation",createHashMap];
["CLEAR-casualty-shared-progress-roster",_reinforced
    && {_reserve in (_reserveOperation getOrDefault ["participants",[]])}
    && {!(_casualty in (_reserveOperation getOrDefault ["participants",[]]))}
    && {(_reserveOperation getOrDefault ["participantProgress",[]]) findIf {(_x select 0) == _reserve} >= 0},
    str [_reserveOperation getOrDefault ["participants",[]],_reserveOperation getOrDefault ["participantProgress",[]]]] call _check;
private _replacementMoved=[{
    alive _reserve
        && {_reserve distance2D _reserveStart >= 8
            || {(_casualtyHouse buildingPos -1) findIf {(getPosASL _reserve) vectorDistance (AGLToASL _x) <= 1.5} >= 0}}
},60] call _wait;
["CLEAR-casualty-reserve-physical-movement",_replacementMoved,format ["start=%1 actual=%2 command=%3 expected=%4",_reserveStart,getPosATL _reserve,currentCommand _reserve,expectedDestination _reserve]] call _check;
private _continuing=(_casualtyGroup getVariable ["WAIT_AIPass_ClearBuilding",false])
    || {((_casualtyGroup getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE"]};
["CLEAR-casualty-controller-continues",_continuing] call _check;
[_casualtyGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach _casualtyMembers;
deleteGroup _casualtyGroup;
deleteVehicle _casualtyHouse;

// Exercise door handling through the real clearance job, never by calling its helper directly.
private _doorHouse=createVehicle ["Land_i_House_Small_01_V1_F",[6250,5800,0],[],0,"NONE"];
_doorHouse enableSimulationGlobal true;
private _doorGroup=createGroup [east,true];
_doorGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_doorGroup setVariable ["acex_headless_blacklist",true,true];
private _doorMembers=[];
for "_i" from 0 to 1 do {
    private _unit=_doorGroup createUnit ["O_Soldier_F",[6250+_i*3,5770,0],[],0,"NONE"];
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
_doorHouse setVariable ["bis_disabled_Door_1",1,true];
["Clearance: locked entry","The real clearance order must not unlock the front door. This phase checks the actual door phase and lock variable; it does not count an accepted order as entry.",getPosATL _doorHouse] call _phase;
private _doorAccepted=[_doorGroup,_doorHouse] call WAIT_fnc_CortexClearBuilding;
["CLEAR-door-order-accepted",_doorAccepted] call _check;
private _lockHeld=true;
private _lockedUntil=time+35;
waitUntil {
    sleep 1;
    if (_doorHouse animationSourcePhase _doorSource > 0.1 || {(_doorHouse getVariable ["bis_disabled_Door_1",0]) != 1}) then {_lockHeld=false};
    time >= _lockedUntil
};
["CLEAR-door-lock-preserved",_doorReady && {_doorAccepted} && {_lockHeld}] call _check;
// Changing the lock is the test stimulus; opening and entry must be performed by production.
_doorHouse setVariable ["bis_disabled_Door_1",0,true];
["Clearance: entry unlocked","The lock is now removed. Watch the same soldiers open the door and physically enter. The audit does not animate the door, teleport actors or reset their movement.",getPosATL _doorHouse] call _phase;
private _doorOpened=[{_doorHouse animationSourcePhase _doorSource >= 0.8},45] call _wait;
["CLEAR-door-unlocked-opens",_doorReady && {_doorOpened}] call _check;
private _doorPositions=_doorHouse buildingPos -1;
private _entered=[{_doorPositions findIf {
    private _position=_x;
    _doorMembers findIf {(getPosASL _x) vectorDistance (AGLToASL _position) <= 1.5} >= 0
} >= 0},45] call _wait;
["CLEAR-door-unlocked-physical-entry",_doorReady && {_doorOpened} && {_entered}] call _check;
[_doorGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach _doorMembers;
deleteGroup _doorGroup;
deleteVehicle _doorHouse;

// Natural building contact acceptance. This fixture supplies only live opposing actors and geometry:
// no reveal, direct clear call, target assignment or movement command is injected after spawning.
// The production contact brain must first acquire the hostile through the engine, identify that the
// fresh contact is physically inside the house, and hand the same squad to the building operation.
private _contactHouse=createVehicle ["Land_i_House_Small_01_V1_F",[6250,5800,0],[],0,"NONE"];
_contactHouse enableSimulationGlobal true;
private _contactRooms=_contactHouse buildingPos -1;
private _contactGroup=createGroup [east,true];
private _contactOpposition=createGroup [west,true];
{
    _x setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
} forEach [_contactGroup,_contactOpposition];
_contactOpposition setVariable ["WAIT_AIPass_Exclude",true,true];
private _contactMembers=[];
for "_i" from 0 to 5 do {
    private _unit=_contactGroup createUnit ["O_Soldier_F",[6238+(_i mod 3)*3,5762-floor(_i/3)*3,0],[],0,"NONE"];
    _unit allowDamage false;
    _unit setDir (_unit getDir _contactHouse);
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["NATURAL CQB %1",_i+1],true];
    _contactMembers pushBack _unit;
};
private _contactEnemy=_contactOpposition createUnit ["B_Soldier_F",_contactRooms param [0,getPosATL _contactHouse],[],0,"NONE"];
_contactEnemy allowDamage false;
_contactEnemy setDir (_contactEnemy getDir leader _contactGroup);
_contactEnemy setVariable ["acex_headless_blacklist",true,true];
_contactEnemy setVariable ["WAIT_CortexQA_Label","INDOOR LIVE HOSTILE",true];
_contactGroup setCombatMode "RED";
_contactOpposition setCombatMode "RED";
missionNamespace setVariable ["WAIT_AIPass_BuildingCombat_Enable",true,true];
missionNamespace setVariable ["WAIT_AIPass_BuildingCombat_Range",100,true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_contactMembers+[_contactEnemy],true];
["Natural building contact","The six-person squad faces a live hostile physically inside the house. Native knowledge must form first; WAIT should then transition directly from contact into its single building-clear operation and physically enter. The audit injects no reveal, clear order or route.",getPosATL _contactHouse] call _phase;
private _nativeContact=[{(units _contactGroup) findIf {_x knowsAbout _contactEnemy >= 1} >= 0},30] call _wait;
["BUILD-CONTACT-native-knowledge",_nativeContact,str (_contactMembers apply {_x knowsAbout _contactEnemy})] call _check;
private _naturalClear=[{_contactGroup getVariable ["WAIT_AIPass_ClearBuilding",false]},20] call _wait;
["BUILD-CONTACT-natural-clear-started",_nativeContact && {_naturalClear},str [_contactGroup getVariable ["WAIT_Cortex_ClearStatus",[]],_contactGroup getVariable ["WAIT_OperationResult",[]]]] call _check;
private _naturalEntry=[{_contactRooms findIf {
    private _room=_x;
    _contactMembers findIf {alive _x && {(getPosASL _x) vectorDistance (AGLToASL _room) <= 1.5}} >= 0
} >= 0},90] call _wait;
["BUILD-CONTACT-physical-entry",_naturalClear && {_naturalEntry},str (_contactMembers apply {[getPosATL _x,currentCommand _x,expectedDestination _x]})] call _check;
[_contactGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach (_contactMembers+[_contactEnemy]);
deleteGroup _contactGroup;
deleteGroup _contactOpposition;
deleteVehicle _contactHouse;

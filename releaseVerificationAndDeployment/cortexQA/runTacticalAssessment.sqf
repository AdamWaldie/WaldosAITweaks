/*
 * Author: WaldoTheWarfighter
 * Purpose: Physically validates bounded tactical restraint and authored-order priority after real native contact.
 * Locality / Authority: Scheduled dedicated-server audit. Fixture groups stay server-local and are excluded from HC distribution.
 * Repeat/JIP: Creates fresh actors for each case, publishes observer labels, restores changed settings through the parent audit, and deletes every fixture.
 * Arguments: 0: result callback <CODE>; 1: phase callback <CODE>; 2: bounded wait callback <CODE>.
 * Return Value: Nothing.
 * Current callers: cortexQAServer.sqf for combat and tacticalassessment focuses.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQATacticalAssessment.sqf";
 */
params ["_check","_phase","_wait"];

[createHashMapFromArray [
    ["WAIT_AIPass_Enable",true],["WAIT_AIPass_Danger_Enable",true],["WAIT_AIPass_Contact_Enable",true],
    ["WAIT_AIPass_Flank_Enable",true],["WAIT_AIPass_Advance_Enable",true],["WAIT_AIPass_Assault_Enable",true],
    ["WAIT_AIPass_Morale_Enable",false],["WAIT_AIPass_Regroup_Enable",false],["WAIT_AIPass_Reinforce_Enable",false],
    ["WAIT_AIPass_CoordinatedAssault_Enable",false],["WAIT_AIPass_Artillery_Enable",false],
    ["WAIT_AIPass_ContactReports_Enable",false]
]] call WAIT_fnc_CortexTuning;

private _newGroup = {
    params ["_position","_label",["_count",6]];
    private _group=createGroup [east,true];
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setVariable ["WAIT_AIPass_Profile","ELITE",true];
    _group setGroupIdGlobal [_label];
    private _actors=[];
    for "_index" from 0 to (_count-1) do {
        private _offset=[[-3,0,0],[0,0,0],[3,0,0]] select (_index mod 3);
        _offset set [1,-3*floor (_index/3)];
        private _actor=_group createUnit [
            ["O_Soldier_SL_F","O_Soldier_AR_F","O_Soldier_F"] select (_index min 2),
            _position vectorAdd _offset,[],0,"NONE"
        ];
        _actor allowDamage false;
        _actor setDir 0;
        _actor setVariable ["acex_headless_blacklist",true,true];
        _actor setVariable ["WAIT_CortexQA_Label",format ["%1 / %2",_label,_index+1],true];
        _actor setVariable ["WAIT_CortexQA_Shots",0];
        _actor addEventHandler ["FiredMan",{
            params ["_actor","_weapon"];
            if !(_weapon in ["Throw","Put"]) then {
                _actor setVariable ["WAIT_CortexQA_Shots",(_actor getVariable ["WAIT_CortexQA_Shots",0])+1];
            };
        }];
        _actors pushBack _actor;
    };
    [_group,_actors]
};

private _deleteGroupActors = {
    params ["_group",["_objects",[]]];
    {deleteVehicle _x} forEach ((units _group)+_objects);
    deleteGroup _group;
};

private _assessmentMatches = {
    params ["_group","_intent","_reason",["_status",""]];
    private _assessment=_group getVariable ["WAIT_Cortex_TacticalAssessment",[]];
    count _assessment >= 6
        && {(_assessment select 0) == _intent}
        && {(_assessment select 1) == _reason}
        && {_status == "" || {(_assessment select 5) == _status}}
};

// An infantry group with no anti-armour weapon should retain native contact and fire-control
// opportunities, improve its position and seek support, but never rifle-assault protected armour.
private _armourFixture=[[1700,1700,0],"TACTICAL ARMOUR RESTRAINT",6] call _newGroup;
_armourFixture params ["_armourGroup","_armourActors"];
private _armour=createVehicle ["B_APC_Wheeled_01_cannon_F",[1700,2020,0],[],0,"NONE"];
createVehicleCrew _armour;
private _armourEnemyGroup=group effectiveCommander _armour;
_armourEnemyGroup setVariable ["WAIT_AIPass_Exclude",true,true];
_armourEnemyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_armour allowDamage false;
{_x allowDamage false; _x setVariable ["acex_headless_blacklist",true,true]} forEach crew _armour;
_armour setDir 180;
_armour setVariable ["WAIT_CortexQA_Label","LIVE ARMOURED THREAT",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_armourActors+[_armour],true];
private _armourOrigins=_armourActors apply {getPosATL _x};
["Tactical assessment: armour overmatch","Six riflemen face a live protected vehicle without anti-armour weapons. WAIT must make one short screened reposition, retain native engagement and support discovery, then reassess. It must not rifle-assault the vehicle or repeatedly fall back.",getPosATL leader _armourGroup] call _phase;
private _armourContact=[{
    private _knowledge=[_armourGroup] call WAIT_fnc_CortexKnowledge;
    ((_knowledge select 0) findIf {vehicle (_x select 0) == _armour}) >= 0
},35] call _wait;
private _armourDecision=[{[_armourGroup,"REPOSITION","ARMOUR_OVERMATCH","STARTED"] call _assessmentMatches},25] call _wait;
private _armourProgress=[{
    private _record=_armourGroup getVariable ["WAIT_Cortex_TacticalReposition",[]];
    count _record >= 6 && {(_record select 0) == "MOVING"}
        && {leader _armourGroup distance2D (_record select 4) >= 15}
},35] call _wait;
private _armourDrill=((_armourGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["drill",createHashMap]);
private _armourTravel=0;
{_armourTravel=_armourTravel max ((_armourOrigins select _forEachIndex) distance2D (getPosATL _x))} forEach _armourActors;
["TACTICAL-armour-real-contact",_armourContact,str ([_armourGroup] call WAIT_fnc_CortexKnowledge)] call _check;
["TACTICAL-armour-overmatch-reposition",_armourDecision && {_armourProgress} && {count _armourDrill == 0},str [_armourGroup getVariable ["WAIT_Cortex_TacticalAssessment",[]],_armourGroup getVariable ["WAIT_Cortex_TacticalReposition",[]],_armourDrill]] call _check;
["TACTICAL-armour-no-WAIT-rifle-rush",_armourTravel < 90,format ["maximum travel=%1",_armourTravel]] call _check;
private _armourCrew=crew _armour;
{deleteVehicle _x} forEach _armourCrew;
deleteVehicle _armour;
[_armourGroup] call WAIT_fnc_CortexReleaseGroup;
[_armourGroup] call _deleteGroupActors;
deleteGroup _armourEnemyGroup;

// The same class of contact must not veto a valid authored forward order. The objective remains
// authoritative and the live vehicle supplies fire context while the group physically advances.
private _orderFixture=[[1850,1700,0],"TACTICAL AUTHORED ADVANCE",6] call _newGroup;
_orderFixture params ["_orderGroup","_orderActors"];
private _orderVehicle=createVehicle ["B_APC_Wheeled_01_cannon_F",[1850,2020,0],[],0,"NONE"];
createVehicleCrew _orderVehicle;
private _orderEnemyGroup=group effectiveCommander _orderVehicle;
_orderEnemyGroup setVariable ["WAIT_AIPass_Exclude",true,true];
_orderEnemyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_orderVehicle allowDamage false;
{_x allowDamage false; _x setVariable ["acex_headless_blacklist",true,true]} forEach crew _orderVehicle;
_orderVehicle setDir 180;
_orderVehicle setVariable ["WAIT_CortexQA_Label","LIVE VEHICLE CONTACT / OBJECTIVE CONTEXT",true];
private _orderOrigin=getPosATL leader _orderGroup;
private _waypoint=_orderGroup addWaypoint [[1850,2160,0],0];
_waypoint setWaypointType "MOVE";
_waypoint setWaypointDescription "QA AUTHORED FORWARD ORDER";
_orderGroup setCurrentWaypoint _waypoint;
missionNamespace setVariable ["WAIT_CortexQA_Actors",_orderActors+[_orderVehicle],true];
["Tactical assessment: authored movement","An ordinary MOVE order exists beyond a live protected vehicle. WAIT must preserve that mission intent, select ADVANCE with AUTHORED_FORWARD_ORDER and make physical forward progress rather than treating armour restraint as a global stop.",getPosATL leader _orderGroup] call _phase;
private _orderContact=[{
    private _knowledge=[_orderGroup] call WAIT_fnc_CortexKnowledge;
    ((_knowledge select 0) findIf {vehicle (_x select 0) == _orderVehicle}) >= 0
},35] call _wait;
private _orderDecision=[{[_orderGroup,"ADVANCE","AUTHORED_FORWARD_ORDER","STARTED"] call _assessmentMatches},55] call _wait;
private _orderProgress=[{alive leader _orderGroup && {leader _orderGroup distance2D _orderOrigin >= 20}},55] call _wait;
["TACTICAL-authored-vehicle-contact",_orderContact,str ([_orderGroup] call WAIT_fnc_CortexKnowledge)] call _check;
["TACTICAL-authored-order-selected",_orderDecision,str (_orderGroup getVariable ["WAIT_Cortex_TacticalAssessment",[]])] call _check;
["TACTICAL-authored-order-physical-progress",_orderProgress,format ["travel=%1 destination=%2",leader _orderGroup distance2D _orderOrigin,waypointPosition [_orderGroup,currentWaypoint _orderGroup]]] call _check;
private _orderCrew=crew _orderVehicle;
{deleteVehicle _x} forEach _orderCrew;
deleteVehicle _orderVehicle;
[_orderGroup] call WAIT_fnc_CortexReleaseGroup;
[_orderGroup] call _deleteGroupActors;
deleteGroup _orderEnemyGroup;

// An exposed elevated firing position should produce one lateral screened improvement rather than
// an automatic uphill rush or indefinite idle. A real actor occupies a physical tower position.
private _tower=createVehicle ["Land_Cargo_Tower_V1_F",[2000,2020,0],[],0,"NONE"];
_tower setDir 0;
private _towerPositions=(_tower buildingPos -1) select {(_x select 2) > ((getPosATL _tower select 2)+15)};
private _elevatedReady=_towerPositions isNotEqualTo [];
["TACTICAL-elevated-fixture-position",_elevatedReady,str _towerPositions] call _check;
if (_elevatedReady) then {
    private _elevatedFixture=[[2000,1500,0],"TACTICAL ELEVATED RESTRAINT",6] call _newGroup;
    _elevatedFixture params ["_elevatedGroup","_elevatedActors"];
    private _elevatedEnemyGroup=createGroup [west,true];
    _elevatedEnemyGroup setVariable ["WAIT_AIPass_Exclude",true,true];
    _elevatedEnemyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    private _elevatedPosition=_towerPositions select 0;
    {_elevatedPosition=[_elevatedPosition,_x] select ((_x select 2) > (_elevatedPosition select 2))} forEach _towerPositions;
    private _elevatedEnemy=_elevatedEnemyGroup createUnit ["B_Soldier_F",_elevatedPosition,[],0,"NONE"];
    _elevatedEnemy allowDamage false;
    _elevatedEnemy disableAI "PATH";
    _elevatedEnemy setDir 180;
    _elevatedEnemy setVariable ["acex_headless_blacklist",true,true];
    _elevatedEnemy setVariable ["WAIT_CortexQA_Label","LIVE ELEVATED INFANTRY",true];
    private _elevatedRange=leader _elevatedGroup distance2D _elevatedEnemy;
    private _elevatedHeight=(getPosATL _elevatedEnemy select 2)-(getPosATL leader _elevatedGroup select 2);
    private _elevatedGeometry=_elevatedRange >= 300 && {_elevatedHeight >= 15};
    ["TACTICAL-elevated-fixture-geometry",_elevatedGeometry,str [_elevatedRange,_elevatedHeight,getPosATL leader _elevatedGroup,getPosATL _elevatedEnemy]] call _check;
    missionNamespace setVariable ["WAIT_CortexQA_Actors",_elevatedActors+[_elevatedEnemy],true];
    private _elevatedOrigins=_elevatedActors apply {getPosATL _x};
    ["Tactical assessment: elevated threat","A live hostile occupies a physical tower more than 300 metres away. WAIT must make one lateral screened reposition, retain native engagement and then reassess instead of rushing uphill or remaining inert.",getPosATL leader _elevatedGroup] call _phase;
    private _elevatedContact=[{
        private _knowledge=[_elevatedGroup] call WAIT_fnc_CortexKnowledge;
        ((_knowledge select 0) findIf {(_x select 0) == _elevatedEnemy}) >= 0
    },45] call _wait;
    private _elevatedDecision=[{_elevatedGeometry && {[_elevatedGroup,"REPOSITION","ELEVATED_FIRE_POSITION","STARTED"] call _assessmentMatches}},30] call _wait;
    private _elevatedProgress=[{
        private _record=_elevatedGroup getVariable ["WAIT_Cortex_TacticalReposition",[]];
        count _record >= 6 && {(_record select 0) == "MOVING"}
            && {leader _elevatedGroup distance2D (_record select 4) >= 15}
    },40] call _wait;
    private _elevatedDrill=((_elevatedGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["drill",createHashMap]);
    private _elevatedTravel=0;
    {_elevatedTravel=_elevatedTravel max ((_elevatedOrigins select _forEachIndex) distance2D (getPosATL _x))} forEach _elevatedActors;
    ["TACTICAL-elevated-real-contact",_elevatedContact,str ([_elevatedGroup] call WAIT_fnc_CortexKnowledge)] call _check;
    ["TACTICAL-elevated-reposition",_elevatedDecision && {_elevatedProgress} && {count _elevatedDrill == 0},str [_elevatedGroup getVariable ["WAIT_Cortex_TacticalAssessment",[]],_elevatedGroup getVariable ["WAIT_Cortex_TacticalReposition",[]],_elevatedDrill]] call _check;
    ["TACTICAL-elevated-no-WAIT-rush",_elevatedTravel < 95,format ["maximum travel=%1 shots=%2",_elevatedTravel,_elevatedActors apply {_x getVariable ["WAIT_CortexQA_Shots",0]}]] call _check;
    [_elevatedGroup] call WAIT_fnc_CortexReleaseGroup;
    [_elevatedGroup] call _deleteGroupActors;
    {deleteVehicle _x} forEach units _elevatedEnemyGroup;
    deleteGroup _elevatedEnemyGroup;
};
deleteVehicle _tower;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];

/*
 * Author: WaldoTheWarfighter
 * Purpose: Exercise the staged individual indoor executor through real script admission,
 * physical entry, independent destinations, repeat use and native-order interruption.
 * Locality/authority: Scheduled dedicated server, normal batch only; groups are server-pinned.
 * Repeat/JIP: Disposable fixtures; results/observer labels are public, production state is not forced.
 * Actors are never relocated after spawn. No test-side doors, path resets, cooldown resets or
 * completion flags assist positive cases. A synthetic conflicting lease is a negative fixture only.
 * Arguments: check CODE, phase CODE, wait CODE, required audit reporting callbacks.
 * Return: Nothing. Current caller: cortexQA/runServer.sqf, focused indooractors batch.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAIndoorActors.sqf";
 */
params ["_check","_phase","_wait"];
if (!isServer || {missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false]}) exitWith {
    ["INDOOR-normal-server-prerequisite",false] call _check;
};
private _site=[9000,9800,0];
private _house=createVehicle ["Land_i_House_Big_01_V1_F",_site,[],0,"NONE"];
_house enableSimulationGlobal true;
// New fixture placement only, before any actor exists. Retain a failed access prerequisite.
private _highestAccess=-1e12;
for "_index" from 0 to 15 do {
    private _entry=_house buildingExit _index;
    if (_entry isEqualTo [0,0,0]) exitWith {};
    _highestAccess=_highestAccess max (((AGLToASL _entry) select 2)-getTerrainHeightASL _entry);
};
private _lift=0;
if (_highestAccess < -0.05 && {_highestAccess >= -0.35}) then {
    _lift=(ceil ((0.15-_highestAccess)/0.05))*0.05;
    _house setPosATL ((getPosATL _house) vectorAdd [0,0,_lift]);
};
["INDOOR-placement-access",_highestAccess+_lift >= -0.05,str [_highestAccess,_lift]] call _check;
private _rooms=(_house buildingPos -1) select {
    private _point=AGLToASL _x;
    private _hits=lineIntersectsSurfaces [_point vectorAdd [0,0,0.4],_point vectorAdd [0,0,10],objNull,objNull,true,1,"GEOM","NONE"];
    _hits isNotEqualTo [] && {private _hit=_hits select 0; (_hit select 2) == _house || {(_hit select 3) == _house}}
};
["INDOOR-native-positions",count _rooms >= 2,str [typeOf _house,_rooms]] call _check;
if (count _rooms < 2) exitWith {deleteVehicle _house};
private _groups=[];
private _actors=[];
private _makeGroup={
    params ["_count","_offset","_label"];
    private _group=createGroup [east,true];
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setCombatMode "YELLOW";
    _groups pushBack _group;
    private _members=[];
    for "_i" from 0 to (_count-1) do {
        private _unit=_group createUnit ["O_Soldier_F",_site vectorAdd [_offset+_i*3,-30,0],[],0,"NONE"];
        _unit setVariable ["acex_headless_blacklist",true,true];
        _unit setVariable ["WAIT_CortexQA_Label",format ["%1 / %2",_label,_i+1],true];
        _members pushBack _unit; _actors pushBack _unit;
    };
    _members
};
private _pair=[2,-4,"INDOOR pair"] call _makeGroup;
private _negative=([1,30,"INDOOR negative"] call _makeGroup) select 0;
private _interrupted=([1,-30,"INDOOR interruption"] call _makeGroup) select 0;
missionNamespace setVariable ["WAIT_CortexQA_Actors",_actors,true];
{_x addCuratorEditableObjects [[_house]+_actors,true]} forEach allCurators;
private _ready={
    params ["_unit"];
    local _unit && {local group _unit} && {groupOwner group _unit == 2}
        && {(group _unit) getVariable ["WAIT_AIPass_Adopted",false]}
        && {((group _unit) getVariable ["WAIT_AIPass_Epoch",0]) > 0}
        && {currentCommand _unit == ""} && {getUnitState _unit != "BUSY"}
        && {_unit checkAIFeature "MOVE"} && {_unit checkAIFeature "PATH"}
        && {[_unit] call WAIT_fnc_CortexCombatEffective}
        && {[group _unit] call WAIT_fnc_CortexIsEligible}
        && {(_unit getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo []}
        && {serverTime >= (_unit getVariable ["WAIT_IndoorActor_Cooldown",-1])}
};
private _context={params ["_position"]; createHashMapFromArray [["building",_house],["belief",[+_position,serverTime]]]};
private _visit={
    params ["_unit","_target"];
    if (!alive _unit || {count _target != 3} || {!isNull objectParent _unit}) exitWith {false};
    private _actual=getPosASL _unit;
    private _goal=AGLToASL _target;
    if (_actual vectorDistance _goal > 1.5 || {abs ((_actual select 2)-(_goal select 2)) > 0.75}) exitWith {false};
    private _bounds=boundingBoxReal _house;
    private _model=_house worldToModel (getPosATL _unit);
    private _low=_bounds select 0; private _high=_bounds select 1;
    if ((_model select 0) <= (_low select 0) || {(_model select 0) >= (_high select 0)}
        || {(_model select 1) <= (_low select 1)} || {(_model select 1) >= (_high select 1)}
        || {(_model select 2) < (_low select 2)} || {(_model select 2) > (_high select 2)}) exitWith {false};
    private _segment=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.6],_goal vectorAdd [0,0,0.6],_unit,objNull,true,1,"GEOM","NONE"];
    private _roof=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.4],_actual vectorAdd [0,0,10],_unit,objNull,true,1,"GEOM","NONE"];
    _segment isEqualTo [] && {_roof isNotEqualTo []}
        && {private _hit=_roof select 0; (_hit select 2) == _house || {(_hit select 3) == _house}}
};
["Individual indoor actors: physical entry","Two independently owned investigations must choose separated native positions and physically enter. Accepted flags and VISITED results cannot replace live pose/geometry observations. No forced doors, actor relocation or completion assistance.",getPosATL _house] call _phase;
private _allReady=[{_pair findIf {!([_x] call _ready)} < 0},35] call _wait;
["INDOOR-idle-owner-prerequisite",_allReady,str (_actors apply {[local _x,currentCommand _x,getUnitState _x,(group _x) getVariable ["WAIT_AIPass_Epoch",0]]})] call _check;
private _starts=_pair apply {getPosATL _x};
private _accepted=_pair apply {["START",_x,[_rooms select 0] call _context] call WAIT_fnc_IndoorActorOperation};
["INDOOR-pair-start",_allReady && {_accepted findIf {!_x} < 0},str _accepted] call _check;
private _generations=_pair apply {(_x getVariable ["WAIT_IndoorActor_Order",[]]) param [0,-1]};
private _deadlines=_pair apply {(_x getVariable ["WAIT_IndoorActor_Order",[]]) param [4,-1]};
private _targets=[[],[]];
private _visits=[false,false];
private _travel=[0,0];
private _deadlineKept=true;
private _targetsStable=true;
private _ownerKept=true;
private _terminal=[{
    {
        private _order=_x getVariable ["WAIT_IndoorActor_Order",[]];
        if (count _order == 9) then {
            if ((_order select 4) != (_deadlines select _forEachIndex)) then {_deadlineKept=false};
            if (_order select 8) then {
                if ((_targets select _forEachIndex) isEqualTo []) then {
                    _targets set [_forEachIndex,+(_order select 6)];
                } else {
                    if ((_targets select _forEachIndex) isNotEqualTo (_order select 6)) then {_targetsStable=false};
                };
            };
        };
        if ([_x,_targets select _forEachIndex] call _visit) then {_visits set [_forEachIndex,true]};
        _travel set [_forEachIndex,(_travel select _forEachIndex) max ((getPosATL _x) vectorDistance (_starts select _forEachIndex))];
        if (!local _x || {groupOwner group _x != 2}) then {_ownerKept=false};
    } forEach _pair;
    _pair findIf {(_x getVariable ["WAIT_IndoorActor_Order",[]]) isNotEqualTo []} < 0
},55] call _wait;
private _results=_pair apply {_x getVariable ["WAIT_IndoorActor_Result",[]]};
private _resultsMatch=true;
{
    private _result=_results select _forEachIndex;
    if ((_result param [1,""]) != "VISITED" || {(_result param [0,-1]) != (_generations select _forEachIndex)}) then {_resultsMatch=false};
} forEach _pair;
["INDOOR-pair-destinations",_accepted findIf {!_x} < 0 && {count (_targets select 0) == 3}
    && {count (_targets select 1) == 3} && {(_targets select 0) vectorDistance (_targets select 1) >= 1.5},str _targets] call _check;
["INDOOR-pair-physical-entry",_terminal && {_accepted findIf {!_x} < 0}
    && {_visits findIf {!_x} < 0} && {_travel findIf {_x < 5} < 0}
    && {_targetsStable} && {_targets findIf {!(_x in _rooms)} < 0}
    && {_resultsMatch},str [_visits,_travel,_results]] call _check;
["INDOOR-original-deadlines",_deadlineKept && {_deadlines findIf {_x < 0} < 0},str _deadlines] call _check;
["INDOOR-normal-owner-retained",_ownerKept] call _check;
// Reuse the same actor through its real cooldown and ordinary cleanup, never a new actor substitute.
private _repeat=_pair select 0;
private _previousTarget=_targets select 0;
private _alternatives=_rooms select {count _previousTarget == 3 && {_x vectorDistance _previousTarget > 2}};
["Individual indoor actor: repeat","The same soldier must naturally finish cleanup and cooldown, then physically investigate a different native position. No reset of cooldowns, PATH or task state is injected.",getPosATL _house] call _phase;
private _repeatReady=[{[_repeat] call _ready},35] call _wait;
private _repeatAccepted=false;
private _repeatVisited=false;
private _repeatTarget=[];
if (_alternatives isNotEqualTo []) then {
    _repeatAccepted=["START",_repeat,[_alternatives select 0] call _context] call WAIT_fnc_IndoorActorOperation;
};
private _repeatGeneration=(_repeat getVariable ["WAIT_IndoorActor_Order",[]]) param [0,-1];
private _repeatDone=false;
if (_repeatAccepted) then {_repeatDone=[{
    private _order=_repeat getVariable ["WAIT_IndoorActor_Order",[]];
    if (count _order == 9 && {_order select 8}) then {_repeatTarget=+(_order select 6)};
    if ([_repeat,_repeatTarget] call _visit) then {_repeatVisited=true};
    _order isEqualTo []
},55] call _wait};
["INDOOR-same-actor-repeat",_repeatReady && {_repeatAccepted} && {_repeatDone} && {_repeatVisited}
    && {_repeatTarget isNotEqualTo _previousTarget}
    && {_repeatGeneration > (_generations select 0)}
    && {((_repeat getVariable ["WAIT_IndoorActor_Result",[]]) param [0,-1]) == _repeatGeneration}
    && {((_repeat getVariable ["WAIT_IndoorActor_Result",[]]) param [1,""]) == "VISITED"},str [_repeatTarget,_repeat getVariable ["WAIT_IndoorActor_Result",[]]]] call _check;
// Negative cases require a fresh idle eligible actor, so a previous cooldown cannot pass them.
["Individual indoor actor: refusal guards","A fresh idle actor must refuse stale belief and a conflicting actor reservation without changing that reservation or its native destination. These are negative fixtures, not combat outcomes.",getPosATL _negative] call _phase;
private _negativeReady=[{[_negative] call _ready},30] call _wait;
private _beforeDestination=expectedDestination _negative;
private _stale=createHashMapFromArray [["building",_house],["belief",[+(_rooms select 0),serverTime-6]]];
private _staleAccepted=["START",_negative,_stale] call WAIT_fnc_IndoorActorOperation;
["INDOOR-stale-belief-refused",_negativeReady && {!_staleAccepted}
    && {(_negative getVariable ["WAIT_IndoorActor_Order",[]]) isEqualTo []}
    && {(expectedDestination _negative) isEqualTo _beforeDestination}] call _check;
private _foreignLease=["AUDIT_OTHER_TASK",getPosATL _negative,time+60];
_negative setVariable ["WAIT_Cortex_ActorMove",[_foreignLease select 0,+(_foreignLease select 1),_foreignLease select 2]];
private _reservedAccepted=["START",_negative,[_rooms select 0] call _context] call WAIT_fnc_IndoorActorOperation;
["INDOOR-reservation-refused",_negativeReady && {!_reservedAccepted}
    && {(_negative getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo _foreignLease}
    && {(expectedDestination _negative) isEqualTo _beforeDestination}] call _check;
// Restore only this fixture's still-exact synthetic marker.
if ((_negative getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo _foreignLease) then {_negative setVariable ["WAIT_Cortex_ActorMove",nil]};
doStop _negative;
private _stopped=[{currentCommand _negative == "STOP"},3] call _wait;
private _stopAccepted=["START",_negative,[_rooms select 0] call _context] call WAIT_fnc_IndoorActorOperation;
["INDOOR-stop-refused",_negativeReady && {_stopped} && {!_stopAccepted}
    && {currentCommand _negative == "STOP"}
    && {(_negative getVariable ["WAIT_IndoorActor_Order",[]]) isEqualTo []}] call _check;
// Real native replacement while still outside. No authored waypoint edit is needed to exercise
// the individual expectedDestination boundary; the old cleanup must not issue follow over it.
["Individual indoor actor: native replacement","Once the actor is genuinely approaching, issue an ordinary move away. The old investigation must retire and the soldier must physically follow that new move. Missing APPROACH cannot pass interruption.",getPosATL _interrupted] call _phase;
private _interruptReady=[{[_interrupted] call _ready},30] call _wait;
private _interruptAccepted=["START",_interrupted,[_rooms select 0] call _context] call WAIT_fnc_IndoorActorOperation;
private _interruptGeneration=(_interrupted getVariable ["WAIT_IndoorActor_Order",[]]) param [0,-1];
private _approach=[{
    private _order=_interrupted getVariable ["WAIT_IndoorActor_Order",[]];
    private _bounds=boundingBoxReal _house;
    private _model=_house worldToModel (getPosATL _interrupted);
    private _low=_bounds select 0; private _high=_bounds select 1;
    private _outside=(_model select 0) < (_low select 0) || {(_model select 0) > (_high select 0)}
        || {(_model select 1) < (_low select 1)} || {(_model select 1) > (_high select 1)};
    count _order == 9 && {_order select 8} && {currentCommand _interrupted == "MOVE"}
        && {_outside} && {_interrupted distance (_order select 6) > 8}
},5] call _wait;
private _newGoal=(getPosATL _interrupted) vectorAdd [-35,-25,0];
private _replacementOrigin=getPosATL _interrupted;
if (_approach) then {_interrupted doMove _newGoal};
private _released=false;
private _followed=false;
private _destinationKept=true;
if (_approach) then {
    _released=[{
        private _destination=(expectedDestination _interrupted) param [0,[],[[]]];
        if (_interrupted distance _newGoal >= 2 && {count _destination != 3
            || {_destination vectorDistance _newGoal > 0.25}}) then {_destinationKept=false};
        (_interrupted getVariable ["WAIT_IndoorActor_Order",[]]) isEqualTo []
    },4] call _wait;
    _followed=[{
        private _destination=(expectedDestination _interrupted) param [0,[],[[]]];
        if (_interrupted distance _newGoal >= 2 && {count _destination != 3
            || {_destination vectorDistance _newGoal > 0.25}}) then {_destinationKept=false};
        _interrupted distance _newGoal < 2
    },55] call _wait;
};
["INDOOR-native-move-handover",_interruptReady && {_interruptAccepted} && {_approach} && {_released} && {_followed} && {_destinationKept}
    && {(getPosATL _interrupted) vectorDistance _replacementOrigin > 8}
    && {(_interrupted getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo []}
    && {((_interrupted getVariable ["WAIT_IndoorActor_Result",[]]) param [0,-1]) == _interruptGeneration}
    && {((_interrupted getVariable ["WAIT_IndoorActor_Result",[]]) param [1,""]) == "NATIVE_TASK"},
    str [_approach,_released,getPosATL _interrupted,expectedDestination _interrupted,_interrupted getVariable ["WAIT_IndoorActor_Result",[]]]] call _check;
{
    ["FINISH",_x,createHashMap] call WAIT_fnc_IndoorActorOperation;
    deleteVehicle _x;
} forEach _actors;
{deleteGroup _x} forEach _groups;
deleteVehicle _house;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];

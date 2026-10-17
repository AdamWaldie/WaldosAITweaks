/*
 * Author: WaldoTheWarfighter
 * Purpose: Exercise real provider transfer of a finite indoor actor to each of two HCs,
 * native movement on the new owner, return to the server and a fresh physical investigation.
 * Locality/authority: Scheduled server-only headless batch; the real companion migration funnel
 * owns transfers. Authenticated disposable owner helpers issue only the requested native MOVE.
 * Repeat/JIP: Fresh actors per HC; no task replay, fabricated owner, cooldown reset or completion.
 * Arguments: check CODE, phase CODE, wait CODE, required audit reporting callbacks.
 * Return: Nothing. Current caller: cortexQA/runServer.sqf, indooractorshc focus only.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAIndoorActorsHC.sqf";
 */
params ["_check","_phase","_wait"];
if (!isServer || {!(missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false])}
    || {isNil "Waldo_fnc_HeadlessMigrateGroup"} || {isNil "WAIT_CortexQA_IndoorActorOwner"}
    || {!(missionNamespace getVariable ["WAIT_CortexQA_OwnerHelpersInstalled",false])}) exitWith {
    ["HC-INDOOR-real-provider-prerequisite",false] call _check;
};
private _registered=[{
    private _native=(missionNamespace getVariable ["Waldo_Headless_Clients",[]]) apply {_x select 0};
    private _connected=(allPlayers select {_x isKindOf "HeadlessClient_F"}) apply {owner _x};
    count (_native arrayIntersect _connected) >= 2
},45] call _wait;
private _native=(missionNamespace getVariable ["Waldo_Headless_Clients",[]]) apply {_x select 0};
private _connected=(allPlayers select {_x isKindOf "HeadlessClient_F"}) apply {owner _x};
private _owners=(_native arrayIntersect _connected) select [0,2];
["HC-INDOOR-two-native-registered",_registered && {count _owners == 2},str _owners] call _check;
if (count _owners != 2) exitWith {};
private _serial=0;
private _request={
    params ["_actor","_mode","_owner",["_goal",[]]];
    _serial=_serial+1;
    private _id=_serial;
    private _expires=serverTime+8;
    _actor setVariable ["WAIT_CortexQA_IndoorAck",nil];
    _actor setVariable ["WAIT_CortexQA_IndoorPending",[_id,_mode,_owner,_expires]];
    if (_owner == 2) then {
        [_actor,_mode,_id,_owner,_expires,_goal] call WAIT_CortexQA_IndoorActorOwner;
    } else {
        [_actor,_mode,_id,_owner,_expires,_goal] remoteExecCall ["WAIT_CortexQA_IndoorActorOwner",_owner];
    };
    private _received=[{
        private _ack=_actor getVariable ["WAIT_CortexQA_IndoorAck",[]];
        count _ack == 5 && {(_ack select 0) == _id} && {(_ack select 1) == _mode} && {(_ack select 2) == _owner}
    },9] call _wait;
    if (_received) then {_actor getVariable ["WAIT_CortexQA_IndoorAck",[]]} else {[]}
};
private _physicalVisit={
    params ["_actor","_house","_target"];
    if (!alive _actor || {count _target != 3}) exitWith {false};
    private _actual=getPosASL _actor; private _goal=AGLToASL _target;
    if (_actual vectorDistance _goal > 1.5 || {abs ((_actual select 2)-(_goal select 2)) > 0.75}) exitWith {false};
    private _bounds=boundingBoxReal _house; private _model=_house worldToModel (getPosATL _actor);
    private _low=_bounds select 0; private _high=_bounds select 1;
    if ((_model select 0) <= (_low select 0) || {(_model select 0) >= (_high select 0)}
        || {(_model select 1) <= (_low select 1)} || {(_model select 1) >= (_high select 1)}
        || {(_model select 2) < (_low select 2)} || {(_model select 2) > (_high select 2)}) exitWith {false};
    private _segment=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.6],_goal vectorAdd [0,0,0.6],_actor,objNull,true,1,"GEOM","NONE"];
    private _roof=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.4],_actual vectorAdd [0,0,10],_actor,objNull,true,1,"GEOM","NONE"];
    _segment isEqualTo [] && {_roof isNotEqualTo []}
        && {private _hit=_roof select 0; (_hit select 2) == _house || {(_hit select 3) == _house}}
};
{
    private _owner=_x;
    private _label=format ["HC-INDOOR-%1",_forEachIndex+1];
    private _site=[9200+100*_forEachIndex,9800,0];
    private _house=createVehicle ["Land_i_House_Small_01_V1_F",_site,[],0,"NONE"];
    _house enableSimulationGlobal true;
    private _highest=-1e12;
    for "_index" from 0 to 15 do {
        private _entry=_house buildingExit _index;
        if (_entry isEqualTo [0,0,0]) exitWith {};
        _highest=_highest max (((AGLToASL _entry) select 2)-getTerrainHeightASL _entry);
    };
    private _lift=0;
    if (_highest < -0.05 && {_highest >= -0.35}) then {
        _lift=(ceil ((0.15-_highest)/0.05))*0.05;
        _house setPosATL ((getPosATL _house) vectorAdd [0,0,_lift]);
    };
    [_label+"-placement",_highest+_lift >= -0.05,str [_highest,_lift]] call _check;
    private _rooms=(_house buildingPos -1) select {
        private _point=AGLToASL _x;
        private _hits=lineIntersectsSurfaces [_point vectorAdd [0,0,0.4],_point vectorAdd [0,0,10],objNull,objNull,true,1,"GEOM","NONE"];
        _hits isNotEqualTo [] && {private _hit=_hits select 0; (_hit select 2) == _house || {(_hit select 3) == _house}}
    };
    private _group=createGroup [east,true];
    _group setVariable ["Waldo_Headless_ExcludeGroup",true,true];
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setCombatMode "YELLOW";
    private _actor=_group createUnit ["O_Soldier_F",_site vectorAdd [0,-35,0],[],0,"NONE"];
    _actor setVariable ["acex_headless_blacklist",true,true];
    _actor setVariable ["WAIT_CortexQA_Label",_label,true];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[_actor],true];
    { _x addCuratorEditableObjects [[_house,_actor],true] } forEach allCurators;
    [_label+" transfer and return","A real server-owned investigation must be in outside APPROACH before provider transfer. The HC must retire it, obey a fresh native move, then return the same actor for a new physical investigation. No journal reset, door assistance or actor relocation is injected.",getPosATL _house] call _phase;
    private _ready=[{
        local _group && {local _actor} && {_group getVariable ["WAIT_AIPass_Adopted",false]}
            && {(_group getVariable ["WAIT_AIPass_Epoch",0]) > 0}
            && {currentCommand _actor == ""} && {getUnitState _actor != "BUSY"}
    },30] call _wait;
    [_label+"-server-ready",_ready && {_rooms isNotEqualTo []}] call _check;
    private _accepted=false;
    if (_rooms isNotEqualTo []) then {
        _accepted=["START",_actor,createHashMapFromArray [["building",_house],["belief",[+(_rooms select 0),serverTime]]]] call WAIT_fnc_IndoorActorOperation;
    };
    private _approach=[{
        private _order=_actor getVariable ["WAIT_IndoorActor_Order",[]];
        private _bounds=boundingBoxReal _house; private _model=_house worldToModel (getPosATL _actor);
        private _low=_bounds select 0; private _high=_bounds select 1;
        private _outside=(_model select 0) < (_low select 0) || {(_model select 0) > (_high select 0)}
            || {(_model select 1) < (_low select 1)} || {(_model select 1) > (_high select 1)};
        count _order == 9 && {_order select 8} && {_outside}
            && {currentCommand _actor == "MOVE"} && {_actor distance (_order select 6) > 10}
    },5] call _wait;
    [_label+"-real-approach",_ready && {_accepted} && {_approach}] call _check;
    private _before=_actor getVariable ["WAIT_IndoorActor_Order",[]];
    private _oldGeneration=_before param [0,-1];
    private _oldDeadline=_before param [4,-1];
    private _requested=false; private _adopted=false; private _cancelled=false;
    private _deadlineKept=true; private _replayed=false;
    private _transferAt=serverTime;
    if (_approach) then {
        _group setVariable ["Waldo_Headless_ExcludeGroup",false,true];
        _group setVariable ["WAIT_Headless_ExcludeGroup",false,true];
        _requested=[_group,_owner] call WAIT_fnc_HeadlessMigrateGroup;
        _adopted=[{
            private _journal=_actor getVariable ["WAIT_IndoorActor_Order",[]];
            if (count _journal == 9 && {(_journal select 4) != _oldDeadline}) then {_deadlineKept=false};
            private _adoption=_group getVariable ["WAIT_AI_LastHeadlessAdoption",[]];
            count _adoption >= 7 && {groupOwner _group == _owner} && {owner _actor == _owner}
                && {(_adoption select 0) == _owner} && {(_adoption select 4) >= _transferAt}
                && {(_adoption select 5) == "COMPANION"} && {(_adoption select 6) >= 0}
        },20] call _wait;
    };
    [_label+"-provider-adopted",_requested && {_adopted},str [_owner,groupOwner _group,_group getVariable ["WAIT_AI_LastHeadlessAdoption",[]]]] call _check;
    if (_adopted) then {
        private _ack=[_actor,"STATUS",_owner] call _request;
        private _data=_ack param [3,[],[[]]];
        private _localRetired=count _data == 9 && {(_data select 1) == 0}
            && {(_data select 2) isEqualTo []} && {(_data select 3) isEqualTo []}
            && {(_data select 8) >= _transferAt};
        // Owner acknowledgements and public task fields are separate deliveries.
        // Require both rather than assuming either packet arrives first.
        if (_localRetired) then {
            _cancelled=[{
                (_actor getVariable ["WAIT_IndoorActor_Order",[]]) isEqualTo []
                    && {((_actor getVariable ["WAIT_IndoorActor_Result",[]]) param [0,-1]) == _oldGeneration}
                    && {(_actor getVariable ["WAIT_IndoorActor_Cooldown",-1]) >= _transferAt}
            },5] call _wait;
        };
    };
    [_label+"-owner-cancelled",_requested && {_adopted} && {_cancelled} && {_deadlineKept},
        str [_before,_actor getVariable ["WAIT_IndoorActor_Order",[]],_actor getVariable ["WAIT_IndoorActor_Result",[]]]] call _check;
    private _moveOrigin=getPosATL _actor;
    private _moveGoal=_moveOrigin vectorAdd [-12,-8,0];
    private _moveIssued=false; private _moved=false; private _ownerStable=true;
    if (_cancelled) then {
        private _ack=[_actor,"MOVE",_owner,_moveGoal] call _request;
        private _data=_ack param [3,[],[[]]];
        _moveIssued=count _data == 9 && {_data select 0};
        if (_moveIssued) then {
            _moved=[{
                if ((_actor getVariable ["WAIT_IndoorActor_Order",[]]) isNotEqualTo []) then {_replayed=true};
                if (groupOwner _group != _owner || {owner _actor != _owner}) then {_ownerStable=false};
                _actor distance _moveGoal <= 2 && {(getPosATL _actor) vectorDistance _moveOrigin > 8}
            },30] call _wait;
        };
    };
    [_label+"-hc-native-physical",_moveIssued && {_moved} && {_ownerStable} && {!_replayed},str [getPosATL _actor,_moveGoal]] call _check;
    private _returnAt=serverTime;
    private _returnRequested=[_group,2] call WAIT_fnc_HeadlessMigrateGroup;
    private _returned=[{
        private _adoption=_group getVariable ["WAIT_AI_LastHeadlessAdoption",[]];
        local _group && {local _actor} && {count _adoption >= 7}
            && {(_adoption select 0) == 2} && {(_adoption select 4) >= _returnAt}
            && {(_adoption select 5) == "COMPANION"}
    },20] call _wait;
    _group setVariable ["Waldo_Headless_ExcludeGroup",true,true];
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    private _pointerFree=count (_actor getVariable ["WAIT_IndoorActor_Brain",createHashMap]) == 0
        && {isNil {_actor getVariable "WAIT_IndoorActor_FSM"}};
    [_label+"-return-pointer-retired",_returnRequested && {_returned} && {_pointerFree},str [_returned,_pointerFree]] call _check;
    private _repeatReady=false;
    if (_returned) then {
        _repeatReady=[{
            if ((_actor getVariable ["WAIT_IndoorActor_Order",[]]) isNotEqualTo []) then {_replayed=true};
            serverTime >= (_actor getVariable ["WAIT_IndoorActor_Cooldown",-1])
                && {currentCommand _actor == ""} && {getUnitState _actor != "BUSY"}
                && {count (_actor getVariable ["WAIT_IndoorActor_Brain",createHashMap]) == 0}
                && {(_actor getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo []}
        },30] call _wait;
    };
    [_label+"-return-idle-cooldown-ready",_returned && {_repeatReady},
        str [serverTime,_actor getVariable ["WAIT_IndoorActor_Cooldown",-1],currentCommand _actor,
            getUnitState _actor,count (_actor getVariable ["WAIT_IndoorActor_Brain",createHashMap])]] call _check;
    private _overlap=serverTime < _oldDeadline;
    [_label+"-old-callback-overlap",_cancelled && {_returned} && {_repeatReady} && {_overlap},str [serverTime,_oldDeadline]] call _check;
    private _repeatAccepted=false; private _visited=false; private _done=false;
    private _target=[]; private _targetKept=true; private _repeatGeneration=-1; private _repeatDeadline=-1; private _generationKept=true;
    if (_repeatReady && {_rooms isNotEqualTo []}) then {
        _repeatAccepted=["START",_actor,createHashMapFromArray [["building",_house],["belief",[+(_rooms select 0),serverTime]]]] call WAIT_fnc_IndoorActorOperation;
        private _order=_actor getVariable ["WAIT_IndoorActor_Order",[]];
        _repeatGeneration=_order param [0,-1]; _repeatDeadline=_order param [4,-1];
        if (_repeatAccepted) then {
            _done=[{
                private _journal=_actor getVariable ["WAIT_IndoorActor_Order",[]];
                if (count _journal == 9) then {
                    if ((_journal select 0) != _repeatGeneration || {(_journal select 4) != _repeatDeadline}) then {_generationKept=false};
                    if (_journal select 8) then {
                        if (_target isEqualTo []) then {_target=+(_journal select 6)} else {
                            if (_target isNotEqualTo (_journal select 6)) then {_targetKept=false};
                        };
                    };
                };
                if ([_actor,_house,_target] call _physicalVisit) then {_visited=true};
                _journal isEqualTo []
            },45] call _wait;
        };
    };
    private _result=_actor getVariable ["WAIT_IndoorActor_Result",[]];
    [_label+"-returned-repeat-physical",_returnRequested && {_returned} && {_pointerFree}
        && {_repeatReady} && {_repeatAccepted} && {_done} && {_visited} && {_generationKept}
        && {_targetKept} && {_target in _rooms} && {!_replayed}
        && {_repeatGeneration > _oldGeneration} && {(_result param [0,-1]) == _repeatGeneration}
        && {(_result param [1,""]) == "VISITED"},str [_target,_result]] call _check;
    if (local _actor) then {["FINISH",_actor,createHashMap] call WAIT_fnc_IndoorActorOperation};
    private _cleanupOwner=groupOwner _group;
    deleteVehicle _actor;
    if (local _group) then {deleteGroup _group} else {
        if (_cleanupOwner >= 2) then {[_group] remoteExecCall ["WAIT_CortexQA_PerformanceDeleteGroup",_cleanupOwner]};
    };
    deleteVehicle _house;
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
} forEach _owners;

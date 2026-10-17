/*
 * Author: WaldoTheWarfighter
 * Purpose: Own one finite indoor investigation actor, independently of whole-group CLEAR.
 * Locality/authority: Actor and group owner only; the FSM queues bounded shared-scheduler work.
 * Native/Zeus/specialist tasks and overlapping operations preempt this controller. Proven disjoint
 * infantry rosters may coexist when they own no group waypoint. No firing is forced.
 * Repeat/JIP: One exact generation per actor; a public cancellation journal allows a new owner
 * to retire an unchanged native leg without replaying movement or renewing the original deadline.
 * Arguments: 0 mode <STRING>, START; 1 actor <OBJECT>, objNull; 2 context <HASHMAP>, empty.
 * START context: building OBJECT, belief [ATL ARRAY, server timestamp], optional contact OBJECT.
 * Idle/plain-route contexts may issue one leg. An unchanged same-contact native approach is
 * observed without a reset; after measured stagnation one alternate-node escalation is permitted.
 * Other modes carry the brain. Neither admission nor escalation renews the original deadline.
 * TRANSFER is locality cleanup only: an absent machine-local lease may use the public journal;
 * a different live actor reservation still forbids command cleanup.
 * Return: BOOL for START/QUEUE/FINISH/TRANSFER; NUMBER -1 for STEP (one shared-scheduler invocation).
 * Current callers: IndoorActorDispatch, indoorActor FSM, focused fixtures and locality/release cleanup.
 * Example: ["START",soldier1,createHashMapFromArray [["building",house1],
 * ["belief",[[100,100,2],serverTime]]]] call WAIT_fnc_IndoorActorOperation;
 */
params [["_mode","START",[""]],["_actor",objNull,[objNull]],
    ["_brain",createHashMap,[createHashMap]]];
_mode=toUpperANSI _mode;
private _migration=_mode == "TRANSFER";
if (_migration) then {_mode="FINISH"};
if (isNull _actor) exitWith {if (_mode == "STEP") then {-1} else {false}};
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {
    if (_mode == "STEP") then {-1} else {false}
};
private _group=group _actor;
// Keep proof arrays independent from actor markers and public cancellation journals.
private _copyArray={_this apply {if (_x isEqualType []) then {_x call _copyArray} else {_x}}};
private _vectorValid={
    _this isEqualType [] && {count _this == 3}
        && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
private _releaseAvailable={
    local _actor && {local _group} && {!isPlayer _actor} && {isNull remoteControlled _actor}
        && {isNull objectParent _actor} && {[_actor] call WAIT_fnc_CortexCombatEffective}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}
        && {([_actor] call WAIT_fnc_CortexExternalOwner) == ""}
        && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
        && {!([_group] call WAIT_fnc_CortexZeusHeld)}
};
private _available={
    local _actor && {local _group} && {!isNull _group} && {!isPlayer _actor}
        && {isNull remoteControlled _actor} && {isNull objectParent _actor}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {[_actor] call WAIT_fnc_CortexCombatEffective}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {getSuppression _actor < 0.5} && {currentWeapon _actor != ""}
        && {combatMode _group in ["YELLOW","RED","WHITE"]}
        && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}
        && {([_actor] call WAIT_fnc_CortexExternalOwner) == ""}
        && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
        && {!([_group] call WAIT_fnc_CortexZeusHeld)}
        && {[_group,false,true,false,_actor] call WAIT_fnc_CortexIsEligible}
        && {missionNamespace getVariable ["WAIT_AIPass_Active",false]}
        && {[_group,"WAIT_AIPass_BuildingCombat_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
        && {[_group,"WAIT_AIPass_Assault_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
        && {(_group getVariable ["WAIT_AIPass_Garrison",[]]) isEqualTo []}
        && {(_group getVariable ["WAIT_AIPass_Defend",[]]) isEqualTo []}
        && {!(_group getVariable ["WAIT_AIPass_ClearBuilding",false])}
};
if (_mode == "FINISH") exitWith {
    if (count _brain > 0) then {
        _brain set ["finished",true]; _brain set ["pending",false]; _brain set ["completed",true];
    };
    if (!local _actor || {!local _group}) exitWith {false};
    private _journal=_actor getVariable ["WAIT_IndoorActor_Order",[]];
    if (count _journal != 9) exitWith {
        if (count _brain > 0 && {(_actor getVariable ["WAIT_IndoorActor_Brain",createHashMap]) isEqualTo _brain}) then {
            _actor setVariable ["WAIT_IndoorActor_Brain",nil]; _actor setVariable ["WAIT_IndoorActor_FSM",nil];
        };
        false
    };
    private _valid=(_journal select 0) isEqualType 0 && {finite (_journal select 0)}
        && {(_journal select 1) isEqualType 0} && {finite (_journal select 1)}
        && {(_journal select 2) isEqualType grpNull} && {(_journal select 3) isEqualType 0}
        && {finite (_journal select 3)} && {(_journal select 4) isEqualType 0}
        && {finite (_journal select 4)} && {(_journal select 5) isEqualType []}
        && {(_journal select 6) isEqualType []} && {(_journal select 7) isEqualType []}
        && {(_journal select 8) isEqualType true};
    if (!_valid) exitWith {false};
    private _savedLease=_journal select 7;
    if (count _savedLease != 3 || {(_savedLease select 0) isNotEqualTo "INDOOR_INVESTIGATE"}
        || {!((_savedLease select 1) call _vectorValid)}
        || {!((_savedLease select 2) isEqualType 0)} || {!finite (_savedLease select 2)}
        || {(_journal select 0) < 1} || {(_journal select 0) != floor (_journal select 0)}
        || {(_journal select 1) < 0} || {(_journal select 1) != floor (_journal select 1)}
        || {(_journal select 8) && {!((_journal select 6) call _vectorValid)}}) exitWith {false};
    _journal params ["_generation","_epoch","_oldGroup","_operation","_deadline","_route","_target","_lease","_issued"];
    // A late old FSM cannot retire a successor's public journal or marker.
    if (count _brain > 0 && {(_brain getOrDefault ["generation",-1]) != _generation
        || {(_brain getOrDefault ["ownerEpoch",-1]) != _epoch}}) exitWith {false};
    private _destination=(expectedDestination _actor) param [0,[],[[]]];
    private _reservation=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
    private _ownsLeg=_issued && {_oldGroup == _group} && {call _releaseAvailable}
        && {_reservation isEqualTo _lease || {_migration && {_reservation isEqualTo []}}}
        && {(_group getVariable ["WAIT_OperationGeneration",0]) == _operation}
        && {[_actor] call WAIT_fnc_IndoorActorGroupAvailable}
        && {([_group] call WAIT_fnc_NativeOrderReceipt) isEqualTo _route}
        && {currentCommand _actor == "MOVE"}
        && {_destination call _vectorValid} && {_target call _vectorValid}
        && {_destination vectorDistance _target <= 0.25};
    if (_ownsLeg) then {
        private _index=currentWaypoint _group;
        private _waypoint=[_group,_index];
        if (_actor == leader _group && {_index > 0} && {_index < count waypoints _group}
            && {waypointType _waypoint == "MOVE"}) then {
            _actor doMove waypointPosition _waypoint;
        } else {_actor doFollow leader _group};
    };
    if ((_actor getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo _lease) then {
        _actor setVariable ["WAIT_Cortex_ActorMove",nil];
    };
    // A failed issued leg is a temporary observation for this actor, never an access verdict.
    if (!_migration && {_issued} && {_oldGroup == _group}
        && {(_brain getOrDefault ["reason",""]) == "NO_PROGRESS"}
        && {_epoch == (_group getVariable ["WAIT_AIPass_Epoch",0])}) then {
        private _house=_brain getOrDefault ["building",objNull];
        private _transform=_brain getOrDefault ["transform",[]];
        if (!isNull _house && {alive _house} && {_target call _vectorValid}
            && {[getPosWorld _house,vectorDir _house,vectorUp _house] isEqualTo _transform}) then {
            private _failed=(_actor getVariable ["WAIT_IndoorActor_NodeFailures",[]]) select [0,4];
            _failed=_failed select {_x isEqualType [] && {count _x == 5}
                && {(_x select 3) isEqualType 0} && {finite (_x select 3)} && {serverTime < (_x select 3)}
                && {(_x select 4) isEqualTo _epoch}
                && {!((_x select 0) isEqualTo _house && {(_x select 2) isEqualTo _target})}};
            if (count _failed >= 4) then {_failed deleteAt 0};
            _failed pushBack [_house,_transform call _copyArray,+_target,serverTime+60,_epoch];
            _actor setVariable ["WAIT_IndoorActor_NodeFailures",_failed];
        };
    };
    _actor setVariable ["WAIT_IndoorActor_Result",[_generation,
        _brain getOrDefault ["reason","RELEASED"],serverTime,+_target],true];
    _actor setVariable ["WAIT_IndoorActor_Order",nil,true];
    if (local _oldGroup) then {
        _oldGroup setVariable ["WAIT_IndoorActor_Actors",(_oldGroup getVariable ["WAIT_IndoorActor_Actors",[]])-[_actor]];
    };
    private _current=_actor getVariable ["WAIT_IndoorActor_Brain",createHashMap];
    if (count _brain == 0 || {_current isEqualTo _brain}) then {
        _actor setVariable ["WAIT_IndoorActor_Brain",nil];
        _actor setVariable ["WAIT_IndoorActor_FSM",nil];
    };
    _actor setVariable ["WAIT_IndoorActor_Cooldown",serverTime+20,true];
    true
};
if (_mode == "START") exitWith {
    private _building=_brain getOrDefault ["building",objNull];
    private _belief=_brain getOrDefault ["belief",[]];
    private _contact=_brain getOrDefault ["contact",objNull];
    if (!(_contact isEqualType objNull) || {!(_building isEqualType objNull)} || {isNull _building}
        || {!alive _building} || {!(_belief isEqualType [])} || {count _belief != 2}
        || {!((_belief select 0) call _vectorValid)} || {!((_belief select 1) isEqualType 0)}
        || {!finite (_belief select 1)} || {serverTime-(_belief select 1) < 0}
        || {serverTime-(_belief select 1) > 5}) exitWith {false};
    if !(call _available) exitWith {false};
    // Fresh scripted/Zeus-created groups may precede periodic discovery. Establish the
    // owner epoch before publishing an actor journal, never adopt over that new journal later.
    if (!(_group getVariable ["WAIT_AIPass_Adopted",false])) then {
        [_group,true] call WAIT_fnc_CortexLocality;
    };
    if (!(call _available) || {!(_group getVariable ["WAIT_AIPass_Adopted",false])}
        || {(_group getVariable ["WAIT_AIPass_Epoch",0]) <= 0}
        || {serverTime-(_belief select 1) > 5}) exitWith {false};
    private _admission=[_actor,_contact,_belief select 0,_building] call WAIT_fnc_IndoorActorNativeContext;
    if (_admission isEqualTo [] || {serverTime < (_actor getVariable ["WAIT_IndoorActor_Cooldown",-1])}
        || {(_actor getVariable ["WAIT_Cortex_ActorMove",[]]) isNotEqualTo []}
        || {(_actor getVariable ["WAIT_IndoorActor_Order",[]]) isNotEqualTo []}
        || {count (_actor getVariable ["WAIT_IndoorActor_Brain",createHashMap]) > 0}
        || {!([_actor] call WAIT_fnc_IndoorActorGroupAvailable)}) exitWith {false};
    // Native command, destination and actual engagement identity remain fixed until SELECT.
    // BUSY combat paths are observation-only; arbitrary individual MOVE tasks are never replaced.
    private _members=(units _group) select [0,16];
    private _investigators=_group getVariable ["WAIT_IndoorActor_Actors",[]];
    if (!(_investigators isEqualType []) || {count _investigators > 2}) exitWith {false};
    _investigators=_investigators select {
        _x isEqualType objNull && {!isNull _x} && {group _x == _group}
            && {count (_x getVariable ["WAIT_IndoorActor_Brain",createHashMap]) > 0}
            && {!((_x getVariable ["WAIT_IndoorActor_Brain",createHashMap]) getOrDefault ["finished",true])}
    };
    if (!(_actor in _members) || {count _investigators >= 2}) exitWith {false};
    private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
    if (_actor in ((_state getOrDefault ["drill",createHashMap]) getOrDefault ["units",[]])
        || {_actor in (_state getOrDefault ["supportHeld",[]])}) exitWith {false};
    private _generation=(_actor getVariable ["WAIT_IndoorActor_Generation",0])+1;
    private _epoch=_group getVariable ["WAIT_AIPass_Epoch",0];
    private _deadline=(serverTime+45) min ((_belief select 1)+30);
    private _lease=["INDOOR_INVESTIGATE",+(_belief select 0),time+(_deadline-serverTime)];
    private _serial=(missionNamespace getVariable ["WAIT_IndoorActor_Serial",0])+1;
    missionNamespace setVariable ["WAIT_IndoorActor_Serial",_serial];
    _brain=createHashMapFromArray [["jobKey",format ["WAIT_INDOOR_%1",_serial]],["actor",_actor],["group",_group],["generation",_generation],
        ["ownerEpoch",_epoch],["operationGeneration",_group getVariable ["WAIT_OperationGeneration",0]],
        ["deadline",_deadline],["route",[_group] call WAIT_fnc_NativeOrderReceipt],
        ["building",_building],["transform",[getPosWorld _building,vectorDir _building,vectorUp _building]],
        ["belief",[+(_belief select 0),_belief select 1]],["contact",_contact],
        ["contactRequired",!isNull _contact],["admission",_admission call _copyArray],["escalations",0],["escalate",false],["lease",_lease call _copyArray],["target",[]],["issued",false],
        ["phase","SELECT"],["finished",false],["pending",false],["completed",false],
        ["nextAt",time],["progressAt",serverTime],["progressPosition",getPosATL _actor]];
    _actor setVariable ["WAIT_IndoorActor_Generation",_generation];
    _actor setVariable ["WAIT_IndoorActor_Brain",_brain];
    _group setVariable ["WAIT_IndoorActor_Actors",_investigators+[_actor]];
    _actor setVariable ["WAIT_Cortex_ActorMove",_lease call _copyArray];
    _actor setVariable ["WAIT_IndoorActor_Order",[_generation,_epoch,_group,
        _brain get "operationGeneration",_deadline,(_brain get "route") call _copyArray,[],_lease call _copyArray,false],true];
    private _handle=[_actor,_brain] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\indoorActor.fsm";
    _actor setVariable ["WAIT_IndoorActor_FSM",_handle];
    true
};
private _current=(_actor getVariable ["WAIT_IndoorActor_Brain",createHashMap]) isEqualTo _brain
    && {count _brain > 0} && {(_brain getOrDefault ["group",grpNull]) == _group}
    && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])};
if (_mode == "QUEUE") exitWith {
    if (!_current || {_brain getOrDefault ["finished",false]}) exitWith {false};
    if (_brain getOrDefault ["pending",false]) exitWith {true};
    _brain set ["pending",true]; _brain set ["completed",false];
    [
        {params ["_job"]; ["STEP",_job get "actor",_job] call WAIT_fnc_IndoorActorOperation},
        _brain,0,_brain get "jobKey"
    ] call WAIT_fnc_CortexQueueJob;
    true
};
if (_mode != "STEP") exitWith {false};
_brain set ["pending",false]; _brain set ["completed",true]; _brain set ["nextAt",time+0.5];
private _finish={
    params ["_reason"];
    _brain set ["reason",_reason];
    ["FINISH",_actor,_brain] call WAIT_fnc_IndoorActorOperation;
    -1
};
if (!_current) exitWith {["OWNER_CHANGED"] call _finish};
if (_brain getOrDefault ["finished",false]) exitWith {-1};
// A new explicitly disjoint operation may coexist, but only while its live roster proves it.
// An unseen operation that already ended cannot be reconstructed as harmless after the fact.
private _operationGeneration=_group getVariable ["WAIT_OperationGeneration",0];
if (_operationGeneration != (_brain get "operationGeneration")
    && {count (_group getVariable ["WAIT_Operation",createHashMap]) > 0}
    && {[_actor] call WAIT_fnc_IndoorActorGroupAvailable}) then {
    private _journal=_actor getVariable ["WAIT_IndoorActor_Order",[]];
    if (count _journal == 9 && {(_journal select 0) == (_brain get "generation")}
        && {(_journal select 1) == (_brain get "ownerEpoch")}
        && {(_journal select 2) == _group}
        && {(_journal select 3) == (_brain get "operationGeneration")}
        && {(_journal select 7) isEqualTo (_brain get "lease")}
        && {(_actor getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo (_brain get "lease")}) then {
        _brain set ["operationGeneration",_operationGeneration];
        _journal=+_journal; _journal set [3,_operationGeneration];
        _actor setVariable ["WAIT_IndoorActor_Order",_journal,true];
    };
};
if (!(call _available) || {(_group getVariable ["WAIT_OperationGeneration",0]) != (_brain get "operationGeneration")}
    || {!([_actor] call WAIT_fnc_IndoorActorGroupAvailable)}
    || {([_group] call WAIT_fnc_NativeOrderReceipt) isNotEqualTo (_brain get "route")}
    || {(_actor getVariable ["WAIT_Cortex_ActorMove",[]]) isNotEqualTo (_brain get "lease")}) exitWith {
    ["PREEMPTED"] call _finish
};
private _building=_brain get "building";
if (isNull _building || {!alive _building}
    || {[getPosWorld _building,vectorDir _building,vectorUp _building] isNotEqualTo (_brain get "transform")}) exitWith {
    ["BUILDING_CHANGED"] call _finish
};
if (serverTime >= (_brain get "deadline")) exitWith {["DEADLINE"] call _finish};
private _contact=_brain getOrDefault ["contact",objNull];
private _engaging=getAttackTarget _actor;
private _assigned=assignedTarget _actor;
if ((!isNull _engaging && {_engaging != _contact}) || {!isNull _assigned && {_assigned != _contact}}) exitWith {
    ["OTHER_CONTACT"] call _finish
};
if ((_brain getOrDefault ["contactRequired",false] && {isNull _contact})
    || {!isNull _contact && {!alive _contact || {(side _group) getFriend (side _contact) >= 0.6}}}) exitWith {
    ["CONTACT_GONE"] call _finish
};
private _phase=_brain get "phase";
if (_phase == "SELECT") exitWith {
    private _admission=[_actor,_contact,(_brain get "belief") select 0,_building] call WAIT_fnc_IndoorActorNativeContext;
    if (_admission isEqualTo []) exitWith {["NATIVE_TASK"] call _finish};
    private _previous=_brain get "admission";
    // Native AI may start the same-contact path after START. Adopt that newer leg
    // without issuing movement; a new arbitrary native command still refuses above.
    if ((_previous select 0) == "ISSUE" && {(_admission select 0) == "OBSERVE"}
        && {!isNull _contact} && {(_admission select 3) == _contact}) then {
        _brain set ["admission",_admission call _copyArray];
    };
    if (_admission isNotEqualTo (_brain get "admission")) exitWith {["NATIVE_TASK"] call _finish};
    private _escalate=_brain getOrDefault ["escalate",false];
    if ((_admission select 0) == "OBSERVE" && {!_escalate}) exitWith {
        private _target=+(_admission select 2);
        _brain set ["target",_target]; _brain set ["phase","APPROACH"];
        private _journal=+(_actor getVariable ["WAIT_IndoorActor_Order",[]]);
        _journal set [6,+_target];
        _actor setVariable ["WAIT_IndoorActor_Order",_journal,true];
        -1
    };
    // A stall sample is not authority to reset a path that has since resumed.
    if (_escalate && {(getPosATL _actor) vectorDistance (_brain get "progressPosition") >= 1}) exitWith {
        _brain set ["progressPosition",getPosATL _actor]; _brain set ["progressAt",serverTime];
        _brain set ["escalate",false]; _brain set ["phase","APPROACH"];
        -1
    };
    if (_escalate && {(_brain getOrDefault ["escalations",0]) >= 1
        || {serverTime-(_brain get "progressAt") < 12}
        || {(_admission select 0) != "OBSERVE"}
        || {getUnitState _actor == "PLANNING"} || {currentCommand _actor == "FIRE"}}) exitWith {["ESCALATION_REFUSED"] call _finish};
    private _reserved=[];
    {private _order=_x getVariable ["WAIT_IndoorActor_Order",[]];
        if (count _order == 9 && {_order select 8}) then {_reserved pushBack (_order select 6)};
    } forEach ((_group getVariable ["WAIT_IndoorActor_Actors",[]]) select [0,2]);
    if (_escalate) then {_reserved pushBack +(_brain get "target")};
    private _node=[_actor,_building,(_brain get "belief") select 0,_reserved] call WAIT_fnc_IndoorActorNodeSelect;
    if (_node isEqualTo []) exitWith {["NO_CANDIDATE"] call _finish};
    // Geometry work grants no command authority; re-read actor, route and operation ownership.
    if (!(call _available)
        || {([_actor,_contact,(_brain get "belief") select 0,_building] call WAIT_fnc_IndoorActorNativeContext) isNotEqualTo _admission}
        || {(_actor getVariable ["WAIT_IndoorActor_Brain",createHashMap]) isNotEqualTo _brain}
        || {(_actor getVariable ["WAIT_Cortex_ActorMove",[]]) isNotEqualTo (_brain get "lease")}
        || {[getPosWorld _building,vectorDir _building,vectorUp _building] isNotEqualTo (_brain get "transform")}
        || {([_group] call WAIT_fnc_NativeOrderReceipt) isNotEqualTo (_brain get "route")}
        || {(_group getVariable ["WAIT_OperationGeneration",0]) != (_brain get "operationGeneration")}
        || {!([_actor] call WAIT_fnc_IndoorActorGroupAvailable)}) exitWith {["PREEMPTED"] call _finish};
    // A stall sample is not authority to reset a path that has since resumed.
    if (_escalate && {(getPosATL _actor) vectorDistance (_brain get "progressPosition") >= 1}) exitWith {
        _brain set ["progressPosition",getPosATL _actor]; _brain set ["progressAt",serverTime];
        _brain set ["escalate",false]; _brain set ["phase","APPROACH"];
        -1
    };
    _actor doMove _node;
    if (_escalate) then {_brain set ["escalations",1]};
    _brain set ["escalate",false]; _brain set ["progressAt",serverTime]; _brain set ["progressPosition",getPosATL _actor];
    _brain set ["target",+_node]; _brain set ["issued",true]; _brain set ["phase","APPROACH"];
    private _journal=+(_actor getVariable ["WAIT_IndoorActor_Order",[]]);
    _journal set [6,+_node]; _journal set [8,true];
    _actor setVariable ["WAIT_IndoorActor_Order",_journal,true];
    -1
};
private _target=_brain get "target";
private _destination=(expectedDestination _actor) param [0,[],[[]]];
private _combatCommand=currentCommand _actor in ["ATTACK","FIRE"] && {!isNull _contact} && {_engaging == _contact};
if (!(currentCommand _actor in ["","MOVE"] || {_combatCommand}) || {!(_destination call _vectorValid)}
    || {_destination vectorDistance _target > 0.25}) exitWith {["NATIVE_TASK"] call _finish};
if (_phase == "APPROACH") exitWith {
    [_actor,_building,["INDOOR",_brain get "generation"]] call WAIT_fnc_CortexBuildingDoor;
    private _position=getPosATL _actor;
    private _near=_position vectorDistance _target <= 1.5;
    private _inside=false;
    if (_near) then {
        private _model=_building worldToModel _position;
        private _bounds=boundingBoxReal _building;
        private _low=_bounds select 0; private _high=_bounds select 1;
        private _height=abs (((getPosASL _actor) select 2)-((AGLToASL _target) select 2));
        private _segment=lineIntersectsSurfaces [eyePos _actor,(AGLToASL _target) vectorAdd [0,0,1],_actor,objNull,true,1,"GEOM","NONE"];
        private _roof=lineIntersectsSurfaces [(getPosASL _actor) vectorAdd [0,0,0.4],
            (getPosASL _actor) vectorAdd [0,0,10],_actor,objNull,true,1,"GEOM","NONE"];
        _inside=(_model select 0) > (_low select 0) && {(_model select 0) < (_high select 0)}
            && {(_model select 1) > (_low select 1)} && {(_model select 1) < (_high select 1)}
            && {_height <= 1} && {_segment isEqualTo []} && {_roof isNotEqualTo []}
            && {private _hit=_roof select 0; (_hit select 2) == _building || {(_hit select 3) == _building}};
    };
    if (_inside) then {
        _brain set ["phase","OBSERVE"]; _brain set ["observeUntil",serverTime+2];
    } else {
        if (_position vectorDistance (_brain get "progressPosition") >= 1) then {
            _brain set ["progressPosition",_position]; _brain set ["progressAt",serverTime];
        };
        if (serverTime-(_brain get "progressAt") >= 12) then {
            if (!(_brain get "issued") && {(_brain get "escalations") == 0}
                && {getUnitState _actor != "PLANNING"} && {currentCommand _actor != "FIRE"}) then {
                private _admission=[_actor,_contact,(_brain get "belief") select 0,_building] call WAIT_fnc_IndoorActorNativeContext;
                if (_admission isNotEqualTo [] && {(_admission select 0) == "OBSERVE"}
                    && {(_admission select 2) isEqualTo _target}) then {
                    _brain set ["admission",_admission call _copyArray];
                    _brain set ["escalate",true]; _brain set ["phase","SELECT"];
                } else {["NO_PROGRESS"] call _finish};
            } else {["NO_PROGRESS"] call _finish};
        };
    };
    -1
};
if (_phase == "OBSERVE" && {serverTime >= (_brain get "observeUntil")}) exitWith {
    // This is a visit/investigation result, never a cleared-room or killed-enemy assertion.
    ["VISITED"] call _finish
};
-1

/*
 * Author: WaldoTheWarfighter
 * Purpose: Execute one bounded physical building-clearance step for the owner-local building FSM.
 * Locality / Authority: Runs through WAIT's shared scheduler where the group is local. It checks the
 * operation generation, Zeus and external ownership before issuing any movement command.
 * Repeat/JIP: One-shot callback. Durable room progress is public; owner-local actor assignments are
 * generation scoped and reconstructed after locality migration. Each room, entrance and egress
 * leg has one native doMove owner. WAIT never pairs it with setDestination, which can create a
 * second low-level route owner and leave an actor oscillating or stationary at a threshold.
 * Arguments: 0: building brain <HASHMAP> created by WAIT_fnc_BuildingOperationStart.
 * Return Value: Number - always -1 because the FSM schedules each later step separately.
 * Current caller: WAIT_fnc_BuildingOperationQueue through WAIT_fnc_CortexQueueJob.
 * Example: [_brain] call WAIT_fnc_BuildingOperationStep;
 */

params [["_brain",createHashMap,[createHashMap]]];
if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith {-1};
private _job=_brain getOrDefault ["job",createHashMap];
private _group=_brain getOrDefault ["group",grpNull];
private _delay=call {
    private _group = _job get "group";
    if (isNull _group || {!local _group}) exitWith {-1};
    if ((_group getVariable ["WAIT_AIPass_ClearGeneration", -1]) != (_job get "generation")) exitWith {-1};
    private _finish = {
        params [["_restore",true,[true]],["_reason","CANCELLED",[""]]];
        _group setVariable ["WAIT_Cortex_ClearEvidence",[+(_job get "cleared"),+(_job get "unreachable"),+(_job get "retryCounts"),+(_job get "failedBy"),_job get "deadline",_job get "lastProgressAt"],true];
        if (!isNull _group) then {
            private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;
            if (isNull _leader) then {_leader=leader _group};
            {
                if (local _x && {!isPlayer _x} && {group _x == _group}) then {
                    if (alive _x && {lifeState _x != "INCAPACITATED"}) then {
                        // Do not undo a replacement controller's stance or speed. The clear job
                        // restores temporary movement state only when it is returning to formation.
                        if (_restore && {unitPos _x == "UP"} && {!isNil {_x getVariable "WAIT_Cortex_ClearStance"}}) then {
                            _x setUnitPos (_x getVariable ["WAIT_Cortex_ClearStance","AUTO"]);
                        };
                        if (_restore && {!isNil {_x getVariable "WAIT_Cortex_ClearForcedSpeed"}} && {abs ((getForcedSpeed _x)-(_x getVariable ["WAIT_Cortex_ClearAppliedSpeed",getForcedSpeed _x])) <= 0.1}) then {
                            _x forceSpeed (_x getVariable ["WAIT_Cortex_ClearForcedSpeed",-1]);
                        };
                        if (_restore) then {
                            _x doWatch objNull;
                            _x doFollow _leader;
                        };
                    };
                    _x setVariable ["WAIT_Cortex_ClearForcedSpeed",nil];
                    _x setVariable ["WAIT_Cortex_ClearAppliedSpeed",nil];
                    _x setVariable ["WAIT_Cortex_ClearStance",nil];
                };
            } forEach (_job get "team");
            _group setVariable ["WAIT_AIPass_ClearBuilding", nil, true];
            _group setVariable ["WAIT_Cortex_ClearEgress",nil,true];
            _group setVariable ["WAIT_AIPass_ClearOrder", nil, true];
            _group setVariable ["WAIT_AIPass_ClearApplied", nil];
        };
        private _result = ["INCOMPLETE","COMPLETE"] select (count (_job get "cleared") == count (_job get "positions") && {!(_job getOrDefault ["egressFailed",false])});
        _group setVariable ["WAIT_Cortex_ClearResult",[_result,count (_job get "cleared"),count (_job get "positions")],true];
        _job set ["finished",true];
        _job set ["finishReason",_reason];
        _job set ["result",_result];
        _group setVariable ["WAIT_Cortex_ClearStatus",nil,true];
        private _operationGeneration=_job getOrDefault ["operationGeneration",-1];
        if (_operationGeneration >= 0) then {
            if (_result == "COMPLETE" && {_reason == "COMPLETE"}) then {
                [_group,_operationGeneration,"COMPLETE","CLEAR_COMPLETE"] call WAIT_fnc_OperationRelease;
            } else {
                [_group,_operationGeneration,_reason] call WAIT_fnc_OperationCancel;
            };
        };
        diag_log format ["[WAIT] %1 clear building %2 (%3 of %4 positions)",_group,_result,count (_job get "cleared"),count (_job get "positions")];
        -1
    };
    if (isNull _group || {!local _group} || {!(_group getVariable ["WAIT_AIPass_ClearBuilding", false])}
        || {!alive (_job get "building")} || {!(missionNamespace getVariable ["WAIT_AIPass_Active", false])}) exitWith {[true,"CANCELLED"] call _finish};
    private _operationGeneration=_job getOrDefault ["operationGeneration",-1];
    private _operationEndReason="";
    if (_operationGeneration >= 0) then {
        private _operationStatus=[_group,_operationGeneration,2,15] call WAIT_fnc_OperationStep;
        if (_operationStatus in ["LOST_OWNER","ZEUS","EXTERNAL","REPLACED"]) then {_operationEndReason=_operationStatus};
    };
    // Leave this callback before selecting lanes or issuing another room movement. The building
    // controller owns ordinary room/pair recovery, but it never owns a replaced or external order.
    if (_operationEndReason != "") exitWith {
        [false,_operationEndReason] call _finish
    };
    // Recovery belongs to the common operation lifecycle. A worker that has exhausted its
    // isolated recovery must not retain a clearance lane or keep receiving room orders.
    private _operation=_group getVariable ["WAIT_Operation",createHashMap];
    private _unavailable=if ((_operation getOrDefault ["generation",-1]) == _operationGeneration
        && {(_operation getOrDefault ["intent",""]) == "CLEAR"}) then {
        +(_operation getOrDefault ["unavailable",[]])
    } else {[]};
    // A fresh Zeus or script order immediately owns movement. Retire Cortex state without
    // a follow, stance or behaviour command that could overwrite that replacement order.
    if !([_group] call WAIT_fnc_CortexIsEligible) exitWith {[false,"EXTERNAL"] call _finish};
    // Check ownership at every local movement write as a Zeus, player or specialist controller
    // can take over during this queued callback after the operation-level eligibility check.
    private _actorAvailable={
        params ["_actor"];
        private _reservation=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
        private _free=_reservation isEqualTo []
            || {_reservation isEqualType [] && {count _reservation == 3} && {(_reservation param [2,1e12,[0]]) <= time}};
        [_actor] call WAIT_fnc_CortexCombatEffective && {local _actor} && {!isPlayer _actor}
            && {group _actor == _group} && {isNull objectParent _actor} && {_free}
            && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}
            && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _mayIssueMovement = {
        !([_group] call WAIT_fnc_CortexExternalTakeover)
    };
    if ((_job getOrDefault ["phase","CLEAR"]) == "EGRESS") exitWith {
        private _assignments=(_job get "egressAssignments") select {
            _x params ["_unit"];
            alive _unit && {local _unit} && {!isPlayer _unit} && {lifeState _unit != "INCAPACITATED"}
                && {group _unit == _group} && {isNull objectParent _unit}
        };
        private _arrived=_assignments findIf {(_x select 0) distance2D (_x select 1) > 5} < 0;
        if (_arrived || {_assignments isEqualTo []} || {time >= (_job get "egressDeadline")}) then {
            if (!_arrived && {_assignments isNotEqualTo []}) then {
                _job set ["egressFailed",true];
                diag_log format ["[WAIT] %1 clear egress incomplete (%2 still inside)",_group,{(_x select 0) distance2D (_x select 1) > 5} count _assignments];
            };
            [true,"COMPLETE"] call _finish
        } else {
            if (call _mayIssueMovement) then {
                {
                    _x params ["_unit","_target"];
                    private _openedDoor=[_unit,_job get "building"] call WAIT_fnc_CortexBuildingDoor;
                    if ((_openedDoor || {currentCommand _unit in ["","STOP"]} || {time >= (_job get "egressReissue")}) && {call _mayIssueMovement}) then {
                        _unit doMove _target;
                    };
                } forEach _assignments;
            };
            if (time >= (_job get "egressReissue")) then {_job set ["egressReissue",time+6]};
            1.5
        }
    };
    private _positions = _job get "positions";
    private _cleared = _job get "cleared";
    private _unreachable = _job get "unreachable";
    private _assigned = _job get "assigned";
    private _retryCounts = _job get "retryCounts";
    private _failedBy = _job get "failedBy";
    private _retryChanged = false;
    private _pairs=_job get "pairs";
    private _pairStates=_job get "pairStates";
    // Refill casualties from soldiers that were deliberately left on exterior security. This is
    // evaluated in the existing building job, so it adds no per-unit scheduler or event-handler cost.
    private _reserved=[];
    {_reserved append _x} forEach _pairs;
    private _leader=[_group] call WAIT_fnc_CortexGroupAnchor;
    if (isNull _leader) then {_leader=leader _group};
    private _rotatedOut=_job getOrDefault ["rotatedOut",[]];
    {_rotatedOut pushBackUnique _x} forEach (_reserved select {_x in _unavailable});
    _job set ["rotatedOut",_rotatedOut];
    private _reserveReady={
        params ["_candidate"];
        private _reservation=_candidate getVariable ["WAIT_Cortex_ActorMove",[]];
        private _reservationFree=_reservation isEqualTo []
            || {_reservation isEqualType [] && {count _reservation == 3} && {(_reservation param [2,1e12,[0]]) <= time}};
        [_candidate] call WAIT_fnc_CortexCombatEffective && {local _candidate} && {!isPlayer _candidate}
            && {isNull objectParent _candidate} && {!(_candidate in _reserved)} && {!(_candidate in _rotatedOut)}
            && {_reservationFree} && {!([_candidate] call WAIT_fnc_CompatibilityExternalControl)}
            && {!(currentCommand _candidate in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _reserves=(units _group) select {[_x] call _reserveReady && {_x != _leader}};
    if (_reserves isEqualTo [] && {[_leader] call _reserveReady}) then {
        _reserves pushBack _leader;
    };
    {
        private _pairIndex=_forEachIndex;
        private _pair=_x;
        private _state=_pairStates select _pairIndex;
        for "_slot" from 0 to ((count _pair)-1) do {
            private _member=_pair select _slot;
            if ((!([_member] call _actorAvailable) || {_member in _unavailable}) && {_reserves isNotEqualTo []}) then {
                private _replacement=_reserves deleteAt 0;
                _pair set [_slot,_replacement];
                _rotatedOut pushBackUnique _member;
                private _team=_job get "team";
                _team pushBackUnique _replacement;
                (_job get "assigned") pushBack [];
                private _lastPositions=_state select 2;
                _lastPositions set [_slot,getPosATL _replacement];
                _state set [2,_lastPositions];
                _state set [3,time];
                _state set [4,0];
                _state set [5,-1];
                private _evidence=_group getVariable ["WAIT_Cortex_ClearReinforcements",[]];
                _evidence pushBack [serverTime,netId _member,netId _replacement,_pairIndex,_slot];
                _group setVariable ["WAIT_Cortex_ClearReinforcements",_evidence,true];
                diag_log format ["[WAIT] Clear pair %1 reinforced: %2 replaced %3",_pairIndex,_replacement,_member];
            };
        };
    } forEach _pairs;
    _job set ["rotatedOut",_rotatedOut];
    // Release reservations before selection so another soldier can visit a casualty's room.
    // Reassigned units belong to their new commander and must receive no further orders here.
    private _activeWorkers=(_job get "team") select {[_x] call _actorAvailable
        && {!(_x in _rotatedOut)} && {!(_x in _unavailable)}};
    private _failureThreshold=(count (_job get "pairs")) min 2 max 1;
    {
        if (!([_x] call WAIT_fnc_CortexCombatEffective) || {!local _x} || {isPlayer _x} || {_x in _rotatedOut} || {_x in _unavailable} || {group _x != _group} || {!isNull objectParent _x}) then {
            _assigned set [_forEachIndex,[]];
        };
    } forEach (_job get "team");
    private _now = time;
    private _before = count _cleared;
    private _unreachableBefore = count _unreachable;
    // A worker may physically traverse another assigned position on the way to its own.
    // Check claimed rooms first, then rotate a fixed topology sample. This keeps physical arrival
    // authoritative without making every callback scale with every room and every worker.
    private _visitIndices=[];
    {
        private _claimed=(_x param [0,-1]);
        if (_claimed >= 0 && {_claimed < count _positions}) then {_visitIndices pushBackUnique _claimed};
    } forEach _assigned;
    private _visitBudget=(count _positions) min 24;
    private _visitCursor=(_job getOrDefault ["visitCursor",0]) mod (count _positions);
    for "_offset" from 0 to (_visitBudget-1) do {
        _visitIndices pushBackUnique ((_visitCursor+_offset) mod (count _positions));
    };
    _job set ["visitCursor",(_visitCursor+_visitBudget) mod (count _positions)];
    {
        private _visitor = _x;
        if (alive _visitor && {local _visitor} && {!isPlayer _visitor}
            && {lifeState _visitor != "INCAPACITATED"} && {group _visitor == _group}
            && {isNull objectParent _visitor}) then {
            private _actual = getPosASL _visitor;
            {
                private _positionIndex=_x;
                if !(_positionIndex in _cleared) then {
                    if (_actual vectorDistance (AGLToASL (_positions select _positionIndex)) <= 1.5) then {
                        _cleared pushBackUnique _positionIndex;
                        private _failedIndex = _unreachable find _positionIndex;
                        if (_failedIndex >= 0) then {_unreachable deleteAt _failedIndex};
                        private _pendingIndex = (_job get "pending") find _positionIndex;
                        if (_pendingIndex >= 0) then {(_job get "pending") deleteAt _pendingIndex};
                        _failedBy set [_positionIndex,[]];
                    };
                };
            } forEach _visitIndices;
        };
    } forEach _activeWorkers;
    private _pairRoutes=_job get "pairRoutes";
    {
        private _pairIndex=_forEachIndex;
        private _pair=_x select {[_x] call _actorAvailable && {!(_x in _unavailable)}};
        if (_pair isEqualTo []) then {
            private _state=_pairStates select _pairIndex;
            private _route=_pairRoutes select _pairIndex;
            private _cursor=_state select 0;
            if (_cursor < count _route) then {
                private _abandoned=_route select _cursor;
                if !(_abandoned in (_cleared+_unreachable)) then {(_job get "pending") pushBackUnique _abandoned};
                _state set [0,count _route];
            };
        };
        if (_pair isNotEqualTo []) then {
            private _state=_pairStates select _pairIndex;
            _state params ["_cursor","_approachingEntry","_lastPositions","_lastProgress","_retries","_lastTarget","_startAt","_moverIndex","_previousPositionIndex","_entryIndex","_triedEntries","_roomsCleared","_entered"];
            if (_now >= _startAt) then {
                private _route=_pairRoutes select _pairIndex;
                while {_cursor < count _route && {(_route select _cursor) in (_cleared+_unreachable)}} do {_cursor=_cursor+1};
                // Claim the nearest room that this pair has not already failed. Claims are removed
                // from the shared queue immediately, preventing several pairs from crowding one node.
                if (_cursor >= count _route) then {
                    private _pending=_job get "pending";
                    private _pairId=format ["PAIR_%1",_pairIndex];
                    private _candidates=_pending select {!(_pairId in (_failedBy select _x))};
                    if (_candidates isNotEqualTo []) then {
                        private _point=_pair select (_moverIndex mod count _pair);
                        private _ranked=_candidates apply {
                            private _candidate=_positions select _x;
                            [(_point distance2D _candidate)+(abs (((getPosATL _point) select 2)-(_candidate select 2))*2.5),_x]
                        };
                        _ranked sort true;
                        private _claimed=(_ranked select 0) select 1;
                        _pending deleteAt (_pending find _claimed);
                        _route pushBack _claimed;
                        _cursor=(count _route)-1;
                        _lastTarget=-1;
                        _retries=0;
                        _triedEntries=[];
                        _entryIndex=-1;
                        if ((_job get "entries") isNotEqualTo []) then {
                            private _entryRanks=(_job get "entries") apply {[_point distance2D _x,_forEachIndex]};
                            _entryRanks sort true;
                            _entryIndex=(_entryRanks select 0) select 1;
                        };
                        // Distant interior targets can leave Arma planning without moving. Stage at
                        // the nearest real entrance first, then commit through it. Workers already
                        // near the building keep the faster direct route.
                        private _entryTarget=if (_entryIndex >= 0) then {(_job get "entries") select _entryIndex} else {[]};
                        private _entryProbe=_pair select (_moverIndex mod count _pair);
                        _approachingEntry=_entryTarget isNotEqualTo [] && {_entryProbe distance2D _entryTarget > 8};
                    };
                };
                if (_cursor < count _route) then {
                    private _positionIndex=_route select _cursor;
                    private _entryTarget=if (_entryIndex >= 0 && {_entryIndex < count (_job get "entries")}) then {
                        (_job get "entries") select _entryIndex
                    } else {[]};
                    if (_approachingEntry && {_entryTarget isNotEqualTo []} && {_pair findIf {_x distance2D _entryTarget <= 3} >= 0}) then {
                        _approachingEntry=false;
                        _entered=true;
                        _triedEntries pushBackUnique _entryIndex;
                        _lastTarget=-1;
                        _retries=0;
                    };
                    private _target=[_positions select _positionIndex,_entryTarget] select _approachingEntry;
                    private _issue=_lastTarget != _positionIndex;
                    private _point=_pair select (_moverIndex mod count _pair);
                    private _supportTarget=[];
                    if (count _pair > 1) then {
                        _supportTarget=if (_approachingEntry) then {
                            private _outward=(getPosATL (_job get "building")) getDir _entryTarget;
                            _entryTarget getPos [3,_outward]
                        } else {
                            if (_previousPositionIndex >= 0) then {_positions select _previousPositionIndex} else {if (_entryTarget isEqualTo [] || {!_approachingEntry && {_entered}}) then {_target} else {_entryTarget}}
                        };
                        if (_supportTarget isEqualTo []) then {
                            private _outward=(getPosATL (_job get "building")) getDir _target;
                            _supportTarget=_target getPos [2.5,_outward];
                        };
                    };
                    {
                        private _unit=_x;
                        private _openedDoor=[_unit,_job get "building"] call WAIT_fnc_CortexBuildingDoor;
                        if ((_issue || {_openedDoor}) && {call _mayIssueMovement}) then {
                            private _started=_job get "started";
                            if !(_unit in _started) then {
                                doStop _unit;
                                _unit setVariable ["WAIT_Cortex_ClearStance",unitPos _unit];
                                _unit setVariable ["WAIT_Cortex_ClearForcedSpeed",getForcedSpeed _unit];
                                _unit setUnitPos "UP";
                                private _clearSpeed=[4.5,5] select (combatMode _group in ["YELLOW","RED"]);
                                _unit setVariable ["WAIT_Cortex_ClearAppliedSpeed",_clearSpeed];
                                _unit forceSpeed _clearSpeed;
                                _started pushBack _unit;
                            };
                            private _unitTarget=if (_unit == _point || {_supportTarget isEqualTo []}) then {_target} else {_supportTarget};
                            _unit doMove _unitTarget;
                        };
                        _assigned set [(_job get "team") find _unit,[_positionIndex,_lastProgress,getPosATL _unit,_retries,_approachingEntry]];
                    } forEach _pair;
                    if (_issue) then {_lastTarget=_positionIndex; _lastProgress=_now; _lastPositions=_pair apply {getPosATL _x}};
                    // Once inside, only the assigned room mover proves progress toward this room.
                    // The security partner is expected to adjust cover and follow the previous room;
                    // counting that movement hid doorway stalls and prevented recovery indefinitely.
                    private _moverSlot=_moverIndex mod count _pair;
                    private _moverPrevious=_lastPositions param [_moverSlot,getPosATL _point];
                    private _moved=_point distance2D _moverPrevious >= 1;
                    if (_approachingEntry && {!_moved}) then {
                        _moved=_pair findIf {
                            private _old=_lastPositions param [_forEachIndex,getPosATL _x];
                            _x distance2D _old >= 1
                        } >= 0;
                    };
                    if (_moved) then {
                        _lastPositions=_pair apply {getPosATL _x};
                        _lastProgress=_now;
                        _job set ["deadline",(_job get "deadline") max (serverTime+120)];
                        _job set ["lastProgressAt",serverTime];
                    };
                    if (_positionIndex in _cleared) then {
                        _previousPositionIndex=_positionIndex;
                        _cursor=_cursor+1;
                        _roomsCleared=_roomsCleared+1;
                        // Reserves replace casualties only. Routine rotation previously pulled a
                        // successful worker out mid-clear and introduced a new actor at the doorway,
                        // creating pauses and exterior congestion without improving room coverage.
                        if (count _pair > 1) then {_moverIndex=(_moverIndex+1) mod count _pair};
                        _lastTarget=-1;
                        _retries=0;
                        _lastProgress=_now;
                    } else {
                        // Only the assigned mover ending its order shortens the retry interval. A security partner may
                        // deliberately hold cover, so treating any pair member as stopped churns a working clear.
                        private _commandEnded=currentCommand _point in ["","STOP"];
                        private _retryDelay=[12,4] select _commandEnded;
                        if (_now-_lastProgress > _retryDelay) then {
                            if (_retries < 3 && {call _mayIssueMovement}) then {
                                {
                                    private _unitTarget=if (_x == _point || {_supportTarget isEqualTo []}) then {_target} else {_supportTarget};
                                    if (call _mayIssueMovement) then {
                                        _x doMove _unitTarget;
                                    };
                                } forEach _pair;
                                _retries=_retries+1;
                                _lastProgress=_now;
                                _retryCounts set [_positionIndex,(_retryCounts param [_positionIndex,0])+1];
                            } else {
                                private _changedEntry=false;
                                if (!_entered && {(_job get "entries") isNotEqualTo []}) then {
                                    if (_approachingEntry) then {_triedEntries pushBackUnique _entryIndex};
                                    private _entryRanks=[];
                                    {
                                        if !(_forEachIndex in _triedEntries) then {
                                            _entryRanks pushBack [(_pair select 0) distance2D _x,_forEachIndex];
                                        };
                                    } forEach (_job get "entries");
                                    if (_entryRanks isNotEqualTo []) then {
                                        _entryRanks sort true;
                                        _entryIndex=(_entryRanks select 0) select 1;
                                        _approachingEntry=true;
                                        _lastTarget=-1;
                                        _lastProgress=_now;
                                        _lastPositions=_pair apply {getPosATL _x};
                                        _retries=0;
                                        _changedEntry=true;
                                    };
                                };
                                if (!_changedEntry) then {
                                    // A stalled worker gets one recovery attempt through the common operation
                                    // lifecycle before this pair gives up its room. Recovery is actor-scoped and
                                    // bounded; the other workers keep sweeping rather than waiting for it.
                                    private _recovery = if (_operationGeneration >= 0) then {
                                        [_group,_operationGeneration,_point,_target] call WAIT_fnc_RecoveryStep
                                    } else {"EXHAUSTED"};
                                    if (_recovery == "RECOVERING") then {
                                        _lastProgress=_now;
                                        _lastPositions=_pair apply {getPosATL _x};
                                        _retries=0;
                                    } else {
                                        private _pairId=format ["PAIR_%1",_pairIndex];
                                        private _failures=_failedBy select _positionIndex;
                                        _failures pushBackUnique _pairId;
                                        _failedBy set [_positionIndex,_failures];
                                        if (count _failures >= _failureThreshold) then {
                                            _unreachable pushBackUnique _positionIndex;
                                        } else {
                                            // Return the room to the shared queue. Another pair must claim it;
                                            // this pair's failure identity prevents an immediate self-retry loop.
                                            (_job get "pending") pushBackUnique _positionIndex;
                                        };
                                        _cursor=_cursor+1;
                                        _lastTarget=-1;
                                        _retries=0;
                                        _triedEntries=[];
                                    };
                                };
                            };
                            _retryChanged=true;
                        };
                    };
                    _state set [0,_cursor]; _state set [1,_approachingEntry]; _state set [2,_lastPositions];
                    _state set [3,_lastProgress]; _state set [4,_retries]; _state set [5,_lastTarget];
                    _state set [7,_moverIndex]; _state set [8,_previousPositionIndex];
                    _state set [9,_entryIndex]; _state set [10,_triedEntries];
                    _state set [11,_roomsCleared];
                    _state set [12,_entered];
                };
            };
        };
    } forEach _pairs;
    private _madeProgress=count _cleared != _before || {count _unreachable != _unreachableBefore};
    if (_pairStates findIf {_x param [12,false]} >= 0 && {(_job getOrDefault ["phase","ENTRY"]) == "ENTRY"}) then {_job set ["phase","SWEEP"]};
    if (_madeProgress) then {_job set ["phase","SWEEP"]} else {if (_retryChanged) then {_job set ["phase","REPLAN"]}};
    if (_madeProgress) then {
        // The total lease is a safety net, not a performance assumption. Genuine physical
        // progress renews it so a busy server or delayed HC does not expire a working clear.
        _job set ["lastProgressAt",serverTime];
        _job set ["deadline",(_job get "deadline") max (serverTime+120)];
    };
    if (_madeProgress || {_retryChanged}) then {
        _group setVariable ["WAIT_AIPass_ClearOrder", [_job get "building", +_cleared, _job get "deadline", _job get "baseBehaviour", +_unreachable, +_retryCounts, +_failedBy, _job get "lastProgressAt"], true];
        _group setVariable ["WAIT_Cortex_ClearStatus",[_job getOrDefault ["phase","SWEEP"],count _cleared,count _unreachable,count (_job get "positions"),count (_job get "pairs"),_job get "lastProgressAt"],true];
    };
    if ((count _cleared + count _unreachable) >= count _positions || {serverTime > (_job get "deadline")} || {(_job get "team") findIf {alive _x && {local _x} && {!isPlayer _x} && {lifeState _x != "INCAPACITATED"} && {!(_x in _unavailable)} && {group _x == _group} && {isNull objectParent _x}} < 0}) exitWith {
        private _active=[];
        {_active append _x} forEach (_job get "pairs");
        _active=_active arrayIntersect _active;
        _active=_active select {alive _x && {local _x} && {!isPlayer _x} && {lifeState _x != "INCAPACITATED"}
            && {group _x == _group} && {isNull objectParent _x}};
        private _entries=_job get "entries";
        private _buildingPos=getPosATL (_job get "building");
        private _egressAssignments=_active apply {
            private _unit=_x;
            private _entry=_job get "entry";
            if (_entries isNotEqualTo []) then {
                private _ranked=_entries apply {[_unit distance2D _x,_x]};
                _ranked sort true;
                _entry=+((_ranked select 0) select 1);
            };
            if (_entry isEqualTo []) then {_entry=_buildingPos};
            private _outward=_buildingPos getDir _entry;
            [_unit,_entry getPos [10,_outward]]
        };
        _job set ["phase","EGRESS"];
        _job set ["egressAssignments",_egressAssignments];
        _job set ["egressDeadline",time+45];
        _job set ["egressReissue",time];
        if (call _mayIssueMovement) then {
            {
                _x params ["_unit","_target"];
                if (call _mayIssueMovement) then {
                    _unit doMove _target;
                };
            } forEach _egressAssignments;
        };
        _group setVariable ["WAIT_Cortex_ClearEgress",["EGRESS",_egressAssignments apply {_x select 1},serverTime],true];
        _group setVariable ["WAIT_Cortex_ClearStatus",["EGRESS",count (_job get "cleared"),count (_job get "unreachable"),count (_job get "positions"),count (_job get "pairs"),serverTime],true];
        1.5
    };
    1.5
};
if (isNil "_delay" || {!(_delay isEqualType 0)}) then {_delay=-1};
private _phase=toUpperANSI (_job getOrDefault ["phase","ENTRY"]);
_brain set ["phase",_phase];
_brain set ["lastStepAt",time];
_brain set ["lastDelay",_delay];
_brain set ["pending",false];
_brain set ["completed",true];
if (_delay < 0) then {
    _brain set ["finished",true];
    _brain set ["cancelReason",_job getOrDefault ["finishReason","FINISHED"]];
} else {
    _brain set ["nextAt",time+_delay];
};
if (!isNull _group) then {
    _group setVariable ["WAIT_BuildingBrain_State",[
        _phase,
        _brain getOrDefault ["generation",-1],
        _brain getOrDefault ["ownerEpoch",-1],
        serverTime,
        _brain getOrDefault ["cancelReason",""],
        count (_job getOrDefault ["cleared",[]]),
        count (_job getOrDefault ["unreachable",[]]),
        count (_job getOrDefault ["positions",[]])
    ],true];
};
-1

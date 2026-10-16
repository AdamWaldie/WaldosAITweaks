/*
 * Author: WaldoTheWarfighter
 * Purpose: Execute one bounded physical building-clearance step for the owner-local building FSM.
 * Exterior reserve staging/view service rotates at most eight actors per callback to prevent starvation.
 * Locality / Authority: Runs through WAIT's shared scheduler where the group is local. It checks the
 * operation generation, Zeus and external ownership before issuing any movement command.
 * Repeat/JIP: One-shot callback. Shared and individual physical room progress is public; owner-local actor assignments are
 * generation scoped and reconstructed after locality migration. Each room, entrance and egress
 * leg has one generation-owned movement writer. Entry, room and recovery movement each issue one
 * native doMove path request without a second formation-planner destination override.
 * Entry and floor-changing mover handoffs retain a covered checkpoint and at most one floor-access
 * checkpoint. Candidate native floor connectors retain a current-floor access leg before the
 * destination-floor landing only when no physically visited destination-floor access is available.
 * Connector sources prefer at most 24 physically visited current-floor room points before
 * at most 32 raw transit candidates; eight source-specific connector records bound geometry cost.
 * Already-entered movers request same-floor rooms without revisiting their buddy.
 * New claims wait for the lowest unfinished ASL room band, including rooms claimed by other lanes.
 * New lead/buddy destinations prefer nodes without another admitted worker's owned approach or
 * physical occupancy. This bounded preference does not reserve rooms or replan active paths.
 * Entry/support/egress floor comparisons use absolute ASL elevation, never differences
 * between heights relative to separate terrain cells. Native movement destinations remain ATL.
 * Idle waiting pairs retain owned current-position holds; waiting never renews the finite episode.
 * After shared coverage, a completed room holder may yield once to nearby free visited space
 * which no unfinished worker needs. One candidate check per callback shares the geometry budget.
 * If no interior point is available, one bounded exterior exit selection may vacate the holder.
 * Final egress plans one actor per callback (up to four proposals), journals pending
 * actors across owner migration and retains the original shared 45-second boundary.
 * Early exits use the same callback, retain their 45-second deadline and public episode receipt,
 * and are reused at group egress without restarting movement or granting synthetic arrival.
 * Physically arrived early exits observe their selected doorway only after a fresh eye ray;
 * one rotating check per callback maintains the watch without another scheduler or movement.
 * Later exterior assignments preserve these observation lanes and prefer uncovered exits.
 * New reserve posts spread across native exit bearings after failed/duplicate-exit ranking;
 * only task-ready, available actors with unchanged owned approaches or physically retained
 * posts influence allocation; dormant/quarantined actors never reserve an observation sector.
 * Terminal cleanup clears only matching generation/owner exit watches; actors without an owned
 * watch receipt retain their current observation command. Unchanged settings release independently
 * of movement diversion, and cleanup journals
 * only actors it physically stopped for later native-order handback. Successful natural clears
 * may return those actors to their unchanged plain authored MOVE after common-operation release. Early exits retire into
 * the terminal route evidence instead of remaining an active replay journal.
 * Eight seconds without actual motion permits the shared generation's one recovery attempt;
 * consumed retries survive owner adoption, while local observation never extends the exit budget.
 * Supported raw transit positions are kept separate from covered clearance targets;
 * checkpoint arrival never substitutes for visiting the assigned room.
 * An entered security partner yields a colliding mover checkpoint to a nearby physically visited
 * same-floor point. Selection is bounded and cached per partner/target/coverage/other destinations;
 * changed reservations invalidate a failed selection; only owned approaches or physical occupation
 * reserve historical destinations, and no visit is inferred.
 * Exhausted interior checkpoint recovery retires that checkpoint once before the assigned room
 * is classified. The room receives a direct attempt within its existing retry and hard deadline.
 * Interior access recovery precedes exterior entrance cycling, so changing entrances cannot
 * repeatedly reset a stalled checkpoint leg while retaining its failed target.
 * Exhausted room retries emit one compact record per classification, including the native target,
 * actor state and failed pair identities. Exhaustion is not proof of inaccessible model geometry.
 * Casualty promotion retains established exit coverage unless another capable local observer
 * physically holds the same exit and passes a fresh VIEW check. Settled early-exit workers count
 * alongside reserves; rotated observer order prevents a blocked first post starving substitutes.
 * One promotion ray per callback
 * and sixteen reserve candidates bound this check; deferral never renews the episode deadline.
 * Casualty selection prefers the nearest eligible reserve to a surviving buddy, or the
 * building when the whole lane is unavailable; no geometry scan or deadline renewal is added.
 * A single exterior replacement follows its healthy original surviving mover through bounded
 * partner entry recovery. Entered survivors have priority; exterior survivors keep approach
 * continuity. Whole-pair replacements still restart exterior entry without inherited receipts.
 * Partner entry recovery reads a provisional target when its cache is absent, without
 * committing the lead room before the distinct support-point planner can run. The finite
 * recovery receipt remains active even before a support target is selected.
 * A stalled recovered partner may select one alternate physically visited current-floor
 * entry point before full room coverage. A public episode/transform receipt bounds replay;
 * the same guarded clearance callback records the shared pair target and issues movement;
 * later pair steps preserve that active path and no progress deadline is renewed.
 * Empty partner alternative searches can be reconsidered only when physical coverage grows,
 * at most three searches per episode. Successful movement alternatives remain one-shot.
 * Public receipts retain the search count and coverage across owner replay.
 * The first entry-failure cause is recorded once per operation, with physical participation
 * at the failure boundary; terminal diagnostics retain it without changing acceptance.
 * Room receipts/holds require an unobstructed target-building segment, with at most sixteen
 * geometry probes per callback, cached at the current pose and rotating worker observation order.
 * Egress uses at most four native proposals per admitted worker across real entrances,
 * preserving distinct supported exterior
 * destinations and live security observation lanes; arrivals hold within one metre.
 * Successful egress additionally requires each active worker's successive physical visits.
 * Interior follow-through recovery requires both stalled target distance and eight seconds without
 * actual motion; native corridor/stair detours retain their path within the original episode budget.
 * Follow-through prefers free current-floor native points using one lazy snapshot of at most eight
 * admitted actors and their still-owned destinations. Occupancy ranks proposals; it proves no visit.
 * Reserve stages use bounded nearby cover selection with shared destination exclusions,
 * exterior building bounds and entrance clearance; no fixed fan layout is generated.
 * Exterior retries prefer untried real exits within the existing three-search budget; exit history
 * follows the transform-bound migration journal without renewing the operation deadline.
 * Reserves distribute observation across at most sixteen real exits using live assignment counts.
 * Validated exposed standing points are allowed when cover is unavailable and recorded as exposed.
 * A successful current-callback actual-eye ray and physical arrival precede a reserve watch.
 * A proposal ray alone cannot install observation; owner adoption waits for the rotating check.
 * Reserve selection retains up to sixteen native security exits; interior entry stays bounded to four.
 * This establishes exit-approach observation, not complete building isolation.
 * Casualty promotion retires the matching generation/epoch exit watch before interior movement.
 * Terminal settlement also retires that exact watch metadata; successor leases survive cleanup.
 * New room visits require the actual observer inside target bounds under target-owned roof,
 * plus a clear solid segment. Observer roof checks share the existing16-ray callback budget.
 * Egress admission, continued exit work and terminal movement require idle/STOP or a matching
 * owned MOVE; newer FOLLOW/ATTACK/WAIT tasks divert actors rather than authorizing recall.
 * Native tasks and newer authority remain protected at that transfer boundary.
 * Arrived exit observation installs once per local owner epoch after physical arrival checks,
 * independently of its public stage receipt; replay issues no new movement.
 * Stage receipts distinguish REJECTED current-position holds, APPROACH and physical ARRIVED.
 * A bounded episode/transform-scoped array journal preserves search counts and tried candidates on resume.
 * Rejected selection retries after five seconds, at most three searches per actor with tried targets excluded.
 * A still-owned approach times out after sixty seconds and yields to an alternate or EXHAUSTED hold.
 * Reserve stage selection processes at most one pending actor per callback; other attempts remain pending.
 * Retired ordinary movers and reserves with rejected stage geometry receive one hold,
 * never a recurring formation recall around an interior leader. A failed native path's automatic
 * formation fallback is held once per owned request until the existing finite retry or handover.
 * A stalled optional raw transit candidate yields once to its original room without claiming a visit.
 * Arguments: 0: building brain <HASHMAP> created by WAIT_fnc_BuildingOperationStart.
 * Return Value: Number - always -1 because the FSM schedules each later step separately.
 * Current caller: WAIT_fnc_BuildingOperationQueue through WAIT_fnc_CortexQueueJob.
 * Example: [_brain] call WAIT_fnc_BuildingOperationStep;
 */

params [["_brain",createHashMap,[createHashMap]]];
if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith {-1};
private _job=_brain getOrDefault ["job",createHashMap];
private _group=_brain getOrDefault ["group",grpNull];
// Retire obsolete scheduled work before route observations or room assignment. Only the
// obsolete brain is changed; the successor's public order and physical progress survive.
if (isNull _group || {!local _group}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}
    || {(_group getVariable ["WAIT_BuildingBrain",createHashMap]) isNotEqualTo _brain}) exitWith {
    _brain set ["pending",false];
    _brain set ["completed",true];
    _brain set ["cancelled",true];
    _brain set ["cancelReason","REPLACED_OR_LOST_OWNER"];
    -1
};
private _delay=call {
    private _group = _job get "group";
    if (isNull _group || {!local _group}) exitWith {-1};
    if ((_group getVariable ["WAIT_AIPass_ClearGeneration", -1]) != (_job get "generation")) exitWith {-1};
    private _actorAvailable={
        params ["_actor"];
        private _reservation=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
        private _free=_reservation isEqualTo []
            || {_reservation isEqualType [] && {count _reservation == 3} && {(_reservation param [2,1e12,[0]]) <= time}};
        [_actor] call WAIT_fnc_CortexCombatEffective && {local _actor} && {!isPlayer _actor}
            && {group _actor == _group} && {isNull objectParent _actor} && {_free}
            && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
            && {isNull (remoteControlled _actor)}
            && {([_actor] call WAIT_fnc_CortexExternalOwner) == ""}
            && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}
            && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _actorTaskFree={
        params ["_actor"];
        simulationEnabled _actor && {!isObjectHidden _actor}
            && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _rememberMove={
        params ["_actor","_target"];
        private _targets=_job getOrDefault ["movementTargets",createHashMap];
        _targets set [netId _actor,+_target];
        _job set ["movementTargets",_targets];
        // A new owned request retires the previous arrival hold, even when the next
        // leg fails before reaching another node. A historical hold is not a live stop.
        (_job getOrDefault ["roomHolds",createHashMap]) deleteAt (netId _actor);
        (_job getOrDefault ["formationFallbackHolds",createHashMap]) deleteAt (netId _actor);
    };
    private _ownsCurrentMove={
        params ["_actor"];
        private _issued=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _actor,[]];
        private _live=(expectedDestination _actor) param [0,[]];
        currentCommand _actor == "MOVE" && {count _issued == 3} && {count _live == 3}
            && {_live vectorDistance _issued <= 0.25}
    };
    // Native task ownership also applies when no MOVE destination changed. A newer
    // FOLLOW/ATTACK/WAIT is not permission to stop, recall or send an actor to an exit.
    private _exitMovementOwned={
        params ["_actor"];
        currentCommand _actor in ["","STOP"] || {[_actor] call _ownsCurrentMove}
    };
    private _activeOwnMove={
        params ["_actor"];
        if (!([_actor] call _ownsCurrentMove) || {unitReady _actor}) exitWith {false};
        private _issued=(_job get "movementTargets") get (netId _actor);
        (getPosASL _actor) vectorDistance (AGLToASL _issued) > 0.4
    };
    // Admission preference only: historical requests must not reserve rooms forever.
    // Inspect at most the eight admitted interior workers; never redirect an active path.
    private _occupiedRoomTargets={
        params ["_excluded"];
        private _occupied=[];
        private _moves=_job getOrDefault ["movementTargets",createHashMap];
        // The team list retains casualties for cleanup/evidence and appends replacements.
        // Its first eight entries are not the current eight workers after reinforcement.
        private _workers=[];
        {
            {_workers pushBackUnique _x} forEach (_x select [0,2]);
        } forEach ((_job getOrDefault ["pairs",[]]) select [0,4]);
        {
            private _actor=_x;
            private _issued=_moves getOrDefault [netId _actor,[]];
            if (!(_actor in _excluded) && {[_actor] call _actorAvailable}
                && {simulationEnabled _actor} && {!isObjectHidden _actor} && {count _issued == 3}
                && {[_actor] call _ownsCurrentMove
                    || {(getPosASL _actor) vectorDistance (AGLToASL _issued) < 2.5}}) then {
                _occupied pushBack (+_issued);
            };
        } forEach (_workers select [0,8]);
        _occupied
    };
    private _roomTargetOccupied={
        params ["_candidate","_occupied"];
        private _candidateASL=AGLToASL _candidate;
        (_occupied findIf {
            _candidate distance2D _x < 2.5
                && {abs ((_candidateASL select 2)-((AGLToASL _x) select 2)) <= 1.5}
        }) >= 0
    };
    // Callback-local geometry cache and hard ray budget; no persistent observer.
    private _roomGeometryResults=createHashMap;
    private _roomGeometryBudget=16;
    _job set ["roomGeometryChecksLast",0];
    private _interiorObservers=createHashMap;
    private _observerInside={
        params ["_actor"];
        private _actual=getPosASL _actor;
        private _key=str [netId _actor,_actual];
        if (_key in _interiorObservers) exitWith {_interiorObservers get _key};
        private _house=_job get "building";
        private _bounds=boundingBoxReal _house;
        private _model=_house worldToModel (getPosATL _actor);
        private _low=_bounds select 0;private _high=_bounds select 1;
        private _inside=(_model select 0) >= (_low select 0) && {(_model select 0) <= (_high select 0)}
            && {(_model select 1) >= (_low select 1)} && {(_model select 1) <= (_high select 1)}
            && {(_model select 2) >= (_low select 2)-0.5} && {(_model select 2) <= (_high select 2)};
        if (!_inside || {_roomGeometryBudget <= 0} || {!call _mayIssueMovement}) exitWith {false};
        _roomGeometryBudget=_roomGeometryBudget-1;
        private _roof=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.5],
            _actual vectorAdd [0,0,10],_actor,objNull,true,4,"GEOM","NONE"];
        private _ownedRoof=_roof isNotEqualTo [] && {
            private _nearest=_roof select 0;
            (_nearest select 2) == _house || {(_nearest select 3) == _house}
        };
        _interiorObservers set [_key,_ownedRoof];
        _job set ["roomGeometryChecksLast",16-_roomGeometryBudget];
        _ownedRoof
    };
    private _roomSegmentClear={
        params ["_actor","_targetASL"];
        private _actual=getPosASL _actor;
        private _key=str [diag_frameNo,netId _actor,_actual,_targetASL];
        private _cached=_key in _roomGeometryResults;
        // A negative answer cannot grant a receipt. Avoid group/config ownership
        // scans for exhausted or already-rejected queries; positives remain live-gated.
        if (!_cached && {_roomGeometryBudget <= 0}) exitWith {false};
        if (_cached && {!(_roomGeometryResults get _key)}) exitWith {false};
        if (!(call _mayIssueMovement)) exitWith {false};
        if (_cached) exitWith {_roomGeometryResults get _key};
        _roomGeometryBudget=_roomGeometryBudget-1;
        private _hits=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.6],
            _targetASL vectorAdd [0,0,0.6],_actor,objNull,true,8,"GEOM","NONE"];
        // A saturated result cannot prove that the target wall was examined.
        private _clear=_hits isEqualTo [];
        _roomGeometryResults set [_key,_clear];
        _job set ["roomGeometryChecksLast",16-_roomGeometryBudget];
        _clear
    };
    private _roomMovementPoint={
        params ["_index"];
        (_job get "positions") select _index
    };
    private _finish = {
        params [["_restore",true,[true]],["_reason","CANCELLED",[""]]];
        // Old-owner callbacks may finish their local FSM, but never retire a successor's
        // durable order, results, assignments or restoration evidence.
        if (isNull _group || {!local _group}
            || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}
            || {(_job getOrDefault ["generation",-1]) != (_group getVariable ["WAIT_AIPass_ClearGeneration",0])}) exitWith {
            _job set ["finished",true];
            _job set ["finishReason","OWNERSHIP_LOST"];
            -1
        };
        _restore=_restore && {!([_group] call WAIT_fnc_CortexExternalTakeover)};
        _group setVariable ["WAIT_Cortex_ClearEvidence",[+(_job get "cleared"),+(_job get "unreachable"),+(_job get "retryCounts"),+(_job get "failedBy"),_job get "deadline",_job get "lastProgressAt"],true];
        private _result = ["INCOMPLETE","COMPLETE"] select (count (_job get "cleared") == count (_job get "positions") && {!(_job getOrDefault ["egressFailed",false])} && {!(_job getOrDefault ["entryFailed",false])});
        if (_reason != "COMPLETE") then {_result="CANCELLED"};
        private _handbacks=[];
        private _settled=[];
        // One bounded terminal snapshot preserves the route which actually failed before cleanup
        // clears actors' destinations. No geometry query or recurring trace is added to the hot path.
        private _routeActors=(_job getOrDefault ["team",[]])+(_job getOrDefault ["securityActors",[]]);
        _routeActors=_routeActors arrayIntersect _routeActors;
        _routeActors resize ((count _routeActors) min 16);
        // Compact terminal causes remain readable when the longer route trace is truncated.
        // Counts are diagnostic only; they cannot add visits or clear failure flags.
        private _terminalVisits=_job getOrDefault ["actorVisits",createHashMap];
        private _terminalEntered=_job getOrDefault ["enteredActors",[]];
        diag_log format ["WAIT CLEAR TERMINAL CAUSES: %1",[_job get "generation",_result,_reason,
            _job getOrDefault ["entryFailed",false],_job getOrDefault ["egressFailed",false],
            _routeActors apply {[netId _x,count (_terminalVisits getOrDefault [netId _x,[]]),_x in _terminalEntered]},
            (_job getOrDefault ["egressAssignments",[]]) apply {[netId (_x select 0),_x param [2,false]]},
            _job getOrDefault ["entryFailureCause",[]]]];
        private _routeStates=+(_job getOrDefault ["pairStates",[]]);
        _routeStates resize ((count _routeStates) min 8);
        private _stageRecords=_job getOrDefault ["reserveStages",createHashMap];
        private _stageCounts=_job getOrDefault ["reserveStageSearchCounts",createHashMap];
        private _stageEntries=_job getOrDefault ["reserveStageTriedEntries",createHashMap];
        private _stageEvidence=(keys _stageRecords select [0,16]) apply {
            [_x,+(_stageRecords get _x),_stageCounts getOrDefault [_x,0],+(_stageEntries getOrDefault [_x,[]])]
        };
        private _routeEvidence=[serverTime,_result,_routeStates,_routeActors apply {
            [netId _x,getPosATL _x,currentCommand _x,expectedDestination _x,
                _x checkAIFeature "MOVE",_x checkAIFeature "PATH"]
        },_reason,_stageEvidence,(keys (_job getOrDefault ["earlyExits",createHashMap])) apply {
            +((_job get "earlyExits") get _x)
        }];
        _group setVariable ["WAIT_Cortex_ClearRouteEvidence",_routeEvidence,true];
        diag_log format ["WAIT CLEAR ROUTE END: %1",_routeEvidence];
        if (!isNull _group) then {
            private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;
            if (isNull _leader) then {_leader=leader _group};
            {
                if (local _x && {!isPlayer _x} && {group _x == _group}) then {
                    if ([_x] call _actorAvailable) then {
                        // Releasing an unchanged cap is separate from recalling formation.
                        // A temporary curator hold keeps its new destination; direct player,
                        // specialist and explicit external ownership still prohibit writes.
                        private _releaseOwnedSettings=!([_group,true,_x] call WAIT_fnc_CortexExternalTakeover)
                            && {!(currentCommand _x in ["ACTION","SCRIPTED","HEAL","REARM","REPAIR","REFUEL","SUPPORT","GET IN","GET OUT","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])};

                        // Preserve edited settings while releasing unchanged WAIT leases.
                        if (_releaseOwnedSettings && {unitPos _x == "UP"} && {!isNil {_x getVariable "WAIT_Cortex_ClearStance"}}) then {
                            _x setUnitPos (_x getVariable ["WAIT_Cortex_ClearStance","AUTO"]);
                        };
                        if (_releaseOwnedSettings && {!isNil {_x getVariable "WAIT_Cortex_ClearForcedSpeed"}} && {abs ((getForcedSpeed _x)-(_x getVariable ["WAIT_Cortex_ClearAppliedSpeed",getForcedSpeed _x])) <= 0.1}) then {
                            _x forceSpeed (_x getVariable ["WAIT_Cortex_ClearForcedSpeed",-1]);
                        };
                        // Native tasks keep movement ownership during terminal cleanup too.
                        // Releasing our unchanged settings must not cancel treatment, boarding
                        // or a specialist action with a formation recall.
                        if (_restore && {[_x] call _actorTaskFree}
                            && {!(_x in (_job getOrDefault ["egressDiverted",[]]))}
                            && {[_x] call _exitMovementOwned}) then {
                            private _exitWatch=_x getVariable ["WAIT_Cortex_ClearExitWatch",[]];
                            if (count _exitWatch == 3
                                && {(_exitWatch select 0) == (_job get "generation")}
                                && {(_exitWatch select 1) == (_brain get "ownerEpoch")}
                                && {(_x getVariable ["WAIT_Cortex_ClearExitWatchLocal",[]]) isEqualTo _exitWatch}) then {
                                _x doWatch objNull;
                            };
                            if (_reason == "COMPLETE") then {
                                // Settlement retains actual positions even when participation failed.
                                // Recalling an incomplete team around an interior leader creates a wedge.
                                // A later native/Zeus order replaces this one-shot hold; no loop rewrites it.
                                doStop _x;
                                _settled pushBackUnique _x;
                            } else {
                                _x setVariable ["WAIT_Cortex_ClearRecall",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],_leader,time+5]];
                                _x doFollow _leader;
                            };
                        };
                    };
                    _x setVariable ["WAIT_Cortex_ClearForcedSpeed",nil,true];
                    _x setVariable ["WAIT_Cortex_ClearAppliedSpeed",nil,true];
                    _x setVariable ["WAIT_Cortex_ClearStance",nil,true];
                    // A terminal stage is historical evidence, not an active watch lease.
                    // Retire only this generation/epoch; successor observations remain intact.
                    private _retiredWatch=_x getVariable ["WAIT_Cortex_ClearExitWatch",[]];
                    if (count _retiredWatch == 3 && {(_retiredWatch select 0) == (_job get "generation")}
                        && {(_retiredWatch select 1) == (_brain get "ownerEpoch")}) then {
                        _x setVariable ["WAIT_Cortex_ClearExitWatch",nil,true];
                        if ((_x getVariable ["WAIT_Cortex_ClearExitWatchLocal",[]]) isEqualTo _retiredWatch) then {
                            _x setVariable ["WAIT_Cortex_ClearExitWatchLocal",nil];
                        };
                    };
                    _x setVariable ["WAIT_Cortex_ClearReserve",nil];
                };
            // Settings leases must also be retired for diverted actors. Only the guarded
            // movement block above excludes them; a new destination does not own our old cap.
            } forEach (((_job get "team") + (_job getOrDefault ["securityActors",[]])) arrayIntersect ((_job get "team") + (_job getOrDefault ["securityActors",[]])));
            _group setVariable ["WAIT_AIPass_ClearBuilding", nil, true];
            _group setVariable ["WAIT_Cortex_ClearEgress",nil,true];
            _group setVariable ["WAIT_Cortex_ClearEarlyExits",nil,true];
            _group setVariable ["WAIT_AIPass_ClearOrder", nil, true];
            _group setVariable ["WAIT_Cortex_ClearFollowBudget",nil,true];
            _group setVariable ["WAIT_AIPass_ClearApplied", nil];
        };
        _group setVariable ["WAIT_Cortex_ClearHold",nil,true];
        if (_reason == "COMPLETE" && {_restore} && {_settled isNotEqualTo []}) then {
            // Record only actors this finish actually stopped. A diverted or service actor
            // must never inherit a later formation recall from a hold it did not receive.
            _group setVariable ["WAIT_Cortex_ClearHold",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],[_group] call WAIT_fnc_NativeOrderReceipt,+_settled],true];
        };
        if (_reason == "NEW_ORDER" && {!([_group] call WAIT_fnc_CortexExternalTakeover)}) then {
            // A native waypoint does not necessarily cancel an actor's explicit movement request.
            // Release only a MOVE still aimed at the destination this job actually issued.
            // A newer actor destination, service task or external controller remains untouched.
            private _targets=_job getOrDefault ["movementTargets",createHashMap];
            private _movers=(_job get "team")+(_job getOrDefault ["securityActors",[]]);
            {
                private _target=_targets getOrDefault [netId _x,[]];
                private _destination=(expectedDestination _x) param [0,[]];
                if (currentCommand _x == "MOVE" && {count _target == 3} && {count _destination == 3}
                    && {_destination vectorDistance _target <= 0.25}
                    && {[_x] call _actorAvailable} && {[_x] call _actorTaskFree}
                    && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}
                    && {([_group] call WAIT_fnc_NativeOrderReceipt) isNotEqualTo (_job getOrDefault ["nativeOrderReceipt",[]])}) then {
                    _handbacks pushBack [_x,"MOVE",+_target];
                };
            } forEach (_movers arrayIntersect _movers);
            // Native waypoint replacement must also release our finite pre-completion holds.
            // Release through this owner after cancellation; the ordinary group brain may
            // already have retired after a failed clearance and cannot be a required consumer.
            private _held=(_job getOrDefault ["accessHeld",[]])+(_job getOrDefault ["quarantineHeld",[]])+(_job getOrDefault ["securityActors",[]]);
            private _roomHolds=_job getOrDefault ["roomHolds",createHashMap];
            _held append ((_job get "team") select {netId _x in _roomHolds});
            private _fallbackHolds=_job getOrDefault ["formationFallbackHolds",createHashMap];
            _held append ((_job get "team") select {netId _x in _fallbackHolds});
            _held append ((_job getOrDefault ["egressAssignments",[]]) select {_x param [2,false,[true]]} apply {_x select 0});
            _held=(_held arrayIntersect _held) select {
                local _x && {group _x == _group} && {!isPlayer _x} && {currentCommand _x == "STOP"}
                    && {[_x] call _actorAvailable} && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}
            };
            {_handbacks pushBack [_x,"STOP",[]]} forEach _held;
        };
        _group setVariable ["WAIT_Cortex_ClearResult",[_result,count (_job get "cleared"),count (_job get "positions")],true];
        _job set ["finished",true];
        _job set ["finishReason",_reason];
        _job set ["result",_result];
        _group setVariable ["WAIT_Cortex_ClearStatus",nil,true];
        private _operationGeneration=_job getOrDefault ["operationGeneration",-1];
        if (_operationGeneration >= 0) then {
            if (_reason == "COMPLETE") then {
                private _outcomeReason=["CLEAR_INCOMPLETE","CLEAR_COMPLETE"] select (_result == "COMPLETE");
                [_group,_operationGeneration,_result,_outcomeReason] call WAIT_fnc_OperationRelease;
            } else {
                [_group,_operationGeneration,_reason] call WAIT_fnc_OperationCancel;
            };
        };
        // A natural clear is an interruption of an existing route, not a permanent hold.
        // Only actual successful participation/egress permits this opt-in continuation.
        // No waypoint reconstruction, scripted/gated shortcut or recalled individual MOVE.
        if (_reason == "COMPLETE" && {_result == "COMPLETE"}
            && {_job getOrDefault ["continueRoute",false]} && {_settled isNotEqualTo []}) then {
            private _index=currentWaypoint _group;
            private _waypoint=[_group,_index];
            private _plain=false;
            if (_index > 0 && {_index < count waypoints _group}) then {
                private _statements=waypointStatements _waypoint;
                private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
                _plain=waypointType _waypoint == "MOVE" && {_condition == "true"}
                    && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
                    && {waypointScript _waypoint == ""} && {(waypointTimeout _waypoint param [2,0]) <= 0}
                    && {isNull waypointAttachedVehicle _waypoint} && {isNull waypointAttachedObject _waypoint}
                    && {(synchronizedWaypoints _waypoint) isEqualTo []} && {(synchronizedTriggers _waypoint) isEqualTo []};
            };
            private _mayContinue={
                params ["_actor"];
                _plain && {_restore} && {local _group}
                    && {(_brain get "ownerEpoch") == (_group getVariable ["WAIT_AIPass_Epoch",0])}
                    && {(_job get "generation") == (_group getVariable ["WAIT_AIPass_ClearGeneration",0])}
                    && {(_group getVariable ["WAIT_BuildingBrain",createHashMap]) isEqualTo _brain}
                    && {count (_group getVariable ["WAIT_Operation",createHashMap]) == 0}
                    && {([_group] call WAIT_fnc_NativeOrderReceipt) isEqualTo (_job getOrDefault ["nativeOrderReceipt",[]])}
                    && {_actor in _settled} && {currentCommand _actor == "STOP"}
                    && {[_actor] call _actorAvailable} && {[_actor] call _actorTaskFree}
                    && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
            };
            private _leader=leader _group;
            if ([_leader] call _mayContinue) then {
                private _continued=[_leader];
                _leader doMove waypointPosition _waypoint;
                {
                    if (_x != _leader && {[_x] call _mayContinue}) then {
                        _x doFollow _leader;
                        _continued pushBack _x;
                    };
                } forEach _settled;
                private _remaining=_settled-_continued;
                if (_remaining isEqualTo []) then {_group setVariable ["WAIT_Cortex_ClearHold",nil,true]} else {
                    _group setVariable ["WAIT_Cortex_ClearHold",[_job get "generation",_brain get "ownerEpoch",[_group] call WAIT_fnc_NativeOrderReceipt,_remaining],true];
                };
            };
        };
        if (_reason == "NEW_ORDER" && {local _group}
            && {(_brain get "ownerEpoch") == (_group getVariable ["WAIT_AIPass_Epoch",0])}
            && {(_job get "generation") == (_group getVariable ["WAIT_AIPass_ClearGeneration",0])}
            && {(_group getVariable ["WAIT_BuildingBrain",createHashMap]) isEqualTo _brain}
            && {count (_group getVariable ["WAIT_Operation",createHashMap]) == 0}) then {
            _group setVariable ["WAIT_Cortex_ClearHold",nil,true];
            {
                _x params ["_actor","_command","_target"];
                private _destination=(expectedDestination _actor) param [0,[]];
                if (local _group && {(_brain get "ownerEpoch") == (_group getVariable ["WAIT_AIPass_Epoch",0])}
                    && {(_job get "generation") == (_group getVariable ["WAIT_AIPass_ClearGeneration",0])}
                    && {count (_group getVariable ["WAIT_Operation",createHashMap]) == 0}
                    && {currentCommand _actor == _command}
                    && {_command == "STOP" || {count _destination == 3 && {_destination vectorDistance _target <= 0.25}}}
                    && {[_actor] call _actorAvailable} && {[_actor] call _actorTaskFree}
                    && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
                    && {([_group] call WAIT_fnc_NativeOrderReceipt) isNotEqualTo (_job getOrDefault ["nativeOrderReceipt",[]])}) then {
                    (_job getOrDefault ["movementTargets",createHashMap]) deleteAt (netId _actor);
                    _actor setVariable ["WAIT_Cortex_ClearRecall",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],leader _group,time+5]];
                    if (_actor == leader _group) then {
                        // A stopped leader cannot resume an authored route by following itself.
                        // Only MOVE has a plain positional handback; other waypoint semantics
                        // remain with the engine and must not be replaced by a fabricated route.
                        private _waypointIndex=currentWaypoint _group;
                        private _waypoint=[_group,_waypointIndex];
                        if (_waypointIndex > 0 && {_waypointIndex < count waypoints _group}
                            && {waypointType _waypoint == "MOVE"}) then {
                            _actor doMove waypointPosition _waypoint;
                        };
                    } else {
                        _actor doFollow leader _group;
                    };
                };
            } forEach _handbacks;
        };
        diag_log format ["[WAIT] %1 clear building %2 (%3 of %4 positions)",_group,_result,count (_job get "cleared"),count (_job get "positions")];
        diag_log format ["WAIT CLEAR END TRACE: %1",[_reason,_operationGeneration,(_group getVariable ["WAIT_Operation",createHashMap]) getOrDefault ["generation",-1],_group getVariable ["WAIT_AIPass_Epoch",0],_brain getOrDefault ["ownerEpoch",-1]]];
        -1
    };
    if (isNull _group || {!local _group} || {!(_group getVariable ["WAIT_AIPass_ClearBuilding", false])}
        || {!alive (_job get "building")} || {!(missionNamespace getVariable ["WAIT_AIPass_Active", false])}) exitWith {[true,"CANCELLED"] call _finish};
    // This operation issues actor destinations, never native waypoints. Any authored
    // waypoint change supersedes it before observations, recovery or speed writes.
    private _nativeOrderReceipt=_job getOrDefault ["nativeOrderReceipt",[]];
    if (_nativeOrderReceipt isNotEqualTo []
        && {([_group] call WAIT_fnc_NativeOrderReceipt) isNotEqualTo _nativeOrderReceipt}) exitWith {
        private _result=[false,"NEW_ORDER"] call _finish;
        _group setVariable ["WAIT_OperationGeneration",(_group getVariable ["WAIT_OperationGeneration",0])+1,true];
        _result
    };
    private _building=_job get "building";
    private _buildingTransform=_job getOrDefault ["buildingTransform",[]];
    if (_buildingTransform isNotEqualTo []
        && {_buildingTransform isNotEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}) exitWith {
        [true,"BUILDING_MOVED"] call _finish
    };
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
    private _emptyOperation=createHashMap;
    private _mayIssueMovement = {
        private _currentOperation=_group getVariable ["WAIT_Operation",_emptyOperation];
        local _group && {!(_brain getOrDefault ["cancelled",false])}
            && {!(_brain getOrDefault ["finished",false])}
            && {(_group getVariable ["WAIT_BuildingBrain",_emptyOperation]) isEqualTo _brain}
            && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
            && {(_job get "generation") == (_group getVariable ["WAIT_AIPass_ClearGeneration",-1])}
            && {_operationGeneration < 0 || {(_currentOperation getOrDefault ["generation",-2]) == _operationGeneration}}
            && {!isNull _building} && {alive _building}
            && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
            && {_buildingTransform isEqualTo []
                || {_buildingTransform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}}
            && {_nativeOrderReceipt isEqualTo []
                || {([_group] call WAIT_fnc_NativeOrderReceipt) isEqualTo _nativeOrderReceipt}}
    };
    // Before exterior actors commit to their first room, honour wholly locked access.
    // Native doMove can traverse a closed door without changing its lock variable.
    // Existing interior occupants are not frozen by this exterior admission barrier.
    if !(_job getOrDefault ["accessAdmitted",false]) then {
        private _probe=(_job get "team") param [0,objNull];
        if (isNil {_building getVariable "WAIT_Cortex_DoorDefinitions"}) then {
            [_probe,_building,["CLEAR",_job get "generation"]] call WAIT_fnc_CortexBuildingDoor;
        };
        private _doors=_building getVariable ["WAIT_Cortex_DoorDefinitions",[]];
        private _allLocked=_doors isNotEqualTo [] && {_doors findIf {
            ((_building getVariable ["bis_disabled_Door",0]) isEqualTo 0
                && {(_building getVariable [format ["bis_disabled_Door_%1",_x select 0],0]) isEqualTo 0})
                || {_building animationSourcePhase (_x select 1) >= 0.8}
        } < 0};
        private _bounds=boundingBoxReal _building;
        private _inside=(_job get "team") findIf {
            private _position=_building worldToModel (getPosATL _x);
            private _minimum=_bounds select 0;
            private _maximum=_bounds select 1;
            (_position select 0) > (_minimum select 0) && {(_position select 0) < (_maximum select 0)}
                && {(_position select 1) > (_minimum select 1)} && {(_position select 1) < (_maximum select 1)}
                && {(_position select 2) > (_minimum select 2)} && {(_position select 2) < (_maximum select 2)}
        } >= 0;
        _job set ["accessBlocked",_allLocked && {!_inside} && {(_job getOrDefault ["phase",""]) != "EGRESS"}];
        if !(_job get "accessBlocked") then {
            _job set ["accessAdmitted",true];
            if (_job getOrDefault ["accessReported",false]) then {
                _group setVariable ["WAIT_Cortex_ClearStatus",["ENTRY",0,0,count (_job get "positions"),count (_job get "pairs"),serverTime],true];
            };
        };
    };
    if (_job getOrDefault ["accessBlocked",false]) exitWith {
        if (serverTime > ((_job get "deadline") min (_job getOrDefault ["hardDeadline",_job get "deadline"]))) exitWith {[true,"ACCESS_BLOCKED"] call _finish};
        private _held=_job getOrDefault ["accessHeld",[]];
        {
            if (!(_x in _held) && {[_x] call _actorAvailable} && {[_x] call _actorTaskFree}
                && {call _mayIssueMovement}) then {doStop _x; _held pushBackUnique _x};
        } forEach (_job get "team");
        _job set ["accessHeld",_held];
        if !(_job getOrDefault ["accessReported",false]) then {
            _job set ["accessReported",true];
            _group setVariable ["WAIT_Cortex_ClearStatus",["ACCESS_BLOCKED",0,0,count (_job get "positions"),count (_job get "pairs"),serverTime],true];
        };
        1.5
    };
    private _earlyExits=_job getOrDefault ["earlyExits",createHashMap];
    private _earlyMotion=_job getOrDefault ["earlyExitMotion",createHashMap];
    private _publishEarlyExits={
        if (count _earlyExits > 0 && {call _mayIssueMovement}) then {
            private _rows=(keys _earlyExits) apply {+(_earlyExits get _x)};
            private _receipt=[+(_job get "visitContext"),_rows];
            if ((_group getVariable ["WAIT_Cortex_ClearEarlyExits",[]]) isNotEqualTo _receipt) then {
                _group setVariable ["WAIT_Cortex_ClearEarlyExits",_receipt,true];
            };
        };
    };
    {
        private _record=_earlyExits get _x;
        _record params ["_actor","_target","_deadline","_state"];
        if (_state != "DIVERTED") then {
            if (!([_actor] call _actorAvailable) || {!([_actor] call _actorTaskFree)}
                || {_actor in _unavailable}
                || {!([_actor] call _exitMovementOwned)}) then {
                _record set [3,"DIVERTED"];
                private _diverted=_job getOrDefault ["egressDiverted",[]];
                _diverted pushBackUnique _actor;
                _job set ["egressDiverted",_diverted];
                (_job getOrDefault ["movementTargets",createHashMap]) deleteAt (netId _actor);
                _job set ["egressFailed",true];
            } else {
                if (_state == "MOVING" && {call _mayIssueMovement}) then {
                    if ((getPosASL _actor) vectorDistance (AGLToASL _target) <= 1
                        && {abs (((getPosASL _actor) select 2)-((AGLToASL _target) select 2)) <= 1.5}) then {
                        doStop _actor;
                        _record set [3,"ARRIVED"];
                    } else {
                        if (serverTime >= _deadline) then {
                            if ([_actor] call _ownsCurrentMove) then {doStop _actor};
                            _record set [3,"FAILED"];
                            _job set ["egressFailed",true];
                        } else {
                            [_actor,_building,["CLEAR",_job get "generation"]] call WAIT_fnc_CortexBuildingDoor;
                            // Actual motion, not decreasing straight-line distance, preserves a
                            // native stair/corridor detour. Observation is local; retry consumption
                            // is durable and never renews the original exit deadline.
                            private _key=netId _actor;
                            private _pose=getPosASL _actor;
                            private _motion=_earlyMotion getOrDefault [_key,[+_pose,serverTime]];
                            if (_pose vectorDistance (_motion select 0) >= 1) then {
                                _motion=[+_pose,serverTime];
                            };
                            _earlyMotion set [_key,_motion];
                            if (!(_record param [4,false,[true]]) && {serverTime-(_motion select 1) >= 8}
                                && {[_actor] call _actorAvailable} && {[_actor] call _actorTaskFree}
                                && {[_actor] call _exitMovementOwned}
                                && {call _mayIssueMovement}) then {
                                private _recovery=[_group,_operationGeneration,_actor,_target] call WAIT_fnc_RecoveryStep;
                                if (_recovery == "RECOVERING") then {[_actor,_target] call _rememberMove};
                                if (_recovery in ["RECOVERING","EXHAUSTED","INVALID"]) then {
                                    _record set [4,true];
                                };
                            };
                        };
                    };
                };
            };
        };
    } forEach (keys _earlyExits);
    _job set ["earlyExitMotion",_earlyMotion];
    // An early arrival supports ongoing clearance by watching its selected doorway.
    // One rotating actual-eye check per callback; observation never creates an entry receipt.
    private _earlyViewChecks=_job getOrDefault ["earlyExitViewChecks",createHashMap];
    private _watchKeys=(keys _earlyExits) select {
        private _row=_earlyExits get _x;
        (_row select 3) == "ARRIVED" && {count (_row param [6,[]]) == 3}
    };
    if (_watchKeys isNotEqualTo [] && {(_job getOrDefault ["phase",""]) != "EGRESS"}) then {
        private _cursor=_job getOrDefault ["earlyExitViewCursor",0];
        private _key=_watchKeys select (_cursor mod count _watchKeys);
        _job set ["earlyExitViewCursor",_cursor+1];
        private _row=_earlyExits get _key;
        _row params ["_actor","_post"];
        private _watch=_row select 6;
        private _check=_earlyViewChecks getOrDefault [_key,[0,-1]];
        if (serverTime >= (_check select 0) && {currentCommand _actor in ["","STOP"]}
            && {[_actor] call _actorAvailable} && {[_actor] call _actorTaskFree} && {call _mayIssueMovement}) then {
            private _eye=eyePos _actor;
            private _watchASL=AGLToASL _watch;
            private _visible=(getPosASL _actor) vectorDistance (AGLToASL _post) <= 1
                && {!terrainIntersectASL [_eye,_watchASL]}
                && {(lineIntersectsSurfaces [_eye,_watchASL,_actor,objNull,true,1,"VIEW","NONE"]) isEqualTo []};
            private _blockedSince=_check select 1;
            if (_visible) then {_blockedSince=-1} else {if (_blockedSince < 0) then {_blockedSince=serverTime}};
            _earlyViewChecks set [_key,[serverTime+2,_blockedSince]];
            private _lease=[_job get "generation",_brain get "ownerEpoch",+_watch];
            if (_visible && {(_actor getVariable ["WAIT_Cortex_ClearExitWatchLocal",[]]) isNotEqualTo _lease}
                && {call _mayIssueMovement}) then {
                _actor doWatch _watch;
                _actor setVariable ["WAIT_Cortex_ClearExitWatch",_lease,true];
                _actor setVariable ["WAIT_Cortex_ClearExitWatchLocal",_lease];
            };
            if (!_visible && {_blockedSince >= 0} && {serverTime-_blockedSince >= 3}
                && {(_actor getVariable ["WAIT_Cortex_ClearExitWatch",[]]) isEqualTo _lease}
                && {(_actor getVariable ["WAIT_Cortex_ClearExitWatchLocal",[]]) isEqualTo _lease}
                && {call _mayIssueMovement}) then {
                _actor doWatch objNull;
                _actor setVariable ["WAIT_Cortex_ClearExitWatch",nil,true];
                _actor setVariable ["WAIT_Cortex_ClearExitWatchLocal",nil];
            };
        };
    };
    _job set ["earlyExitViewChecks",_earlyViewChecks];
    call _publishEarlyExits;
    // Shared bounded planner: at most four proposals/entrances, existing geometry checks.
    // Selection grants no movement authority or physical arrival receipt.
    private _chooseExteriorExit={
        params ["_unit","_reservationsIn","_securityLanes","_exitUses",["_observation",false]];
        private _entries=_job get "entries";
        private _buildingPos=getPosATL _building;
        private _ranked=[];
        {
            _ranked pushBack [_exitUses getOrDefault [str _x,0],_unit distance2D _x,_forEachIndex,+_x];
        } forEach (_entries select [0,4]);
        _ranked sort true;
        // The fallback still receives geometry validation and cannot imply model access.
        if (_ranked isEqualTo []) then {
            _ranked pushBack [0,0,0,+_buildingPos];
        };
        private _taken=+_reservationsIn;
        private _tried=[];
        private _exitPoint=[];
        private _selectedEntry=[];
        private _selectedWatch=[];
        // Cover every retained entrance before rejecting: the old three-slot prefix
        // could never examine a fourth viable exit when the first three failed.
        // Keep three proposals for smaller sets; at most four for eight workers.
        private _proposalCount=3 max count _ranked;
        for "_proposalIndex" from 0 to (_proposalCount-1) do {
            if (_exitPoint isNotEqualTo []) exitWith {};
            private _entry=+((_ranked select (_proposalIndex mod count _ranked)) select 3);
            private _outward=_buildingPos getDir _entry;
            private _search=_entry getPos [10,_outward];
            private _watch=_entry getPos [2,_outward];
            _watch set [2,(_entry select 2)+1.2];
            private _reservations=_taken+_tried;
            private _candidate=[_unit,_search,_entry,_reservations,_securityLanes] call WAIT_fnc_BuildingExteriorProposal;
            private _valid=false;
            if (count _candidate == 3) then {
                _candidate set [2,0];
                _valid=[_unit,_building,_candidate,_entry,_watch,_entries,_reservations,_securityLanes] call WAIT_fnc_BuildingExteriorCandidate;
                _tried pushBackUnique +_candidate;
                if (_valid) then {_exitPoint=+_candidate; _selectedEntry=+_entry; _selectedWatch=+_watch};
            };
            diag_log format ["WAIT CLEAR EGRESS PROPOSAL: %1",[_job get "generation",netId _unit,_proposalIndex,+_entry,+_candidate,_valid]];
        };
        if (_selectedEntry isNotEqualTo []) then {
            private _exitKey=str _selectedEntry;
            _exitUses set [_exitKey,(_exitUses getOrDefault [_exitKey,0])+1];
        };
        if (_observation) exitWith {[_exitPoint,_selectedEntry,_selectedWatch]};
        _exitPoint
    };
    // End exterior planner; selection alone grants no command authority.
    if ((_job getOrDefault ["phase","CLEAR"]) == "EGRESS") exitWith {
        private _diverted=_job getOrDefault ["egressDiverted",[]];
        private _pending=_job getOrDefault ["egressPending",[]];
        if (_pending isNotEqualTo [] && {time < (_job get "egressDeadline")} && {call _mayIssueMovement}) then {
            private _row=_pending deleteAt 0;
            _row params ["_unit","_leg"];
            private _live=(expectedDestination _unit) param [0,[]];
            private _owned=currentCommand _unit in ["","STOP"]
                || {currentCommand _unit == "MOVE" && {count _leg == 3}
                    && {count _live == 3} && {_live vectorDistance _leg <= 0.25}};
            if ([_unit] call _actorAvailable && {!(_unit in _unavailable)} && {_owned}) then {
                private _claimedExitPoints=(keys _earlyExits) apply {+((_earlyExits get _x) select 1)};
                private _securityPoints=[];
                private _securityLanes=[];
                {
                    private _row=_earlyExits get _x;
                    if ((_row select 3) in ["MOVING","ARRIVED"] && {count (_row param [6,[]]) == 3}) then {
                        _securityLanes pushBack [+(_row select 1),+(_row select 6)];
                    };
                } forEach keys _earlyExits;
                // An egress slot must preserve live exterior security, not only other exit slots.
                {
                    private _security=_x;
                    private _securityStage=(_job getOrDefault ["reserveStages",createHashMap]) getOrDefault [netId _security,[]];
                    if (!(_security in (((_job get "egressAssignments")+_pending) apply {_x select 0}))
                        && {_security != _unit} && {[_security] call _actorAvailable}
                        && {simulationEnabled _security} && {!isObjectHidden _security}
                        && {(_securityStage param [2,""]) in ["APPROACH","ARRIVED"]}
                        && {count (_securityStage param [4,[],[[]]]) == 3}) then {
                        _securityPoints pushBack +(_securityStage select 0);
                        _securityLanes pushBack [+(_securityStage select 0),+(_securityStage select 4)];
                    };
                } forEach ((_job getOrDefault ["securityActors",[]]) select [0,64]);
                { _claimedExitPoints pushBackUnique +(_x select 1) } forEach (_job get "egressAssignments");
                private _exitUses=_job getOrDefault ["egressExitUses",createHashMap];
                private _target=[_unit,_claimedExitPoints+_securityPoints,_securityLanes,_exitUses] call _chooseExteriorExit;
                _job set ["egressExitUses",_exitUses];
                // A failed proposal cannot become an arrival at the actor's current position.
                if (count _target == 3 && {[_unit] call _actorAvailable}
                    && {[_unit] call _exitMovementOwned} && {call _mayIssueMovement}) then {
                    (_job get "egressAssignments") pushBack [_unit,+_target,false];
                    (_job get "egressProgress") pushBack [_unit,(getPosATL _unit) vectorDistance _target,time,0];
                    _unit doMove _target;
                    [_unit,_target] call _rememberMove;
                } else {_job set ["egressFailed",true]};
            } else {
                _job set ["egressFailed",true];
                _diverted pushBackUnique _unit;
                (_job getOrDefault ["movementTargets",createHashMap]) deleteAt (netId _unit);
            };
            _job set ["egressPending",_pending];
        };
        private _assignments=(_job get "egressAssignments") select {
            _x params ["_unit"];
            if !([_unit] call _exitMovementOwned) then {
                _diverted pushBackUnique _unit;
                (_job getOrDefault ["movementTargets",createHashMap]) deleteAt (netId _unit);
                _x set [2,false];
            };
            // A new individual destination can arrive without changing the group waypoint.
            // It owns the actor immediately, including when it passes our old arrival slot.
            // Never stop or retry that actor back to the retired clearance destination.
            [_unit] call _actorAvailable && {!(_unit in _unavailable)}
                && {!(_unit in _diverted)}
        };
        _job set ["egressDiverted",_diverted];
        // A diverted/unavailable actor is no longer ours to route, but its unfinished exit
        // must remain visible instead of counting an empty eligible set as successful egress.
        if (count _assignments < count (_job get "egressAssignments")) then {_job set ["egressFailed",true]};
        _job set ["egressAssignments",_assignments];
        private _outsideExit={
            params ["_assignment"];
            _assignment params ["_unit","_target"];
            // An earlier visit is historical progress, not current settlement. A collision,
            // native displacement or later movement can remove the actor from its post.
            // Retain STOP only while physically settled; displaced actors keep the original
            // exit/retry deadline and must arrive again before the group can finish.
            private _stillAtPost=_unit distance2D _target <= 1
                && {abs (((getPosASL _unit) select 2)-((AGLToASL _target) select 2)) <= 1.5};
            if (_assignment param [2,false,[true]] && {_stillAtPost}) exitWith {false};
            if (_assignment param [2,false,[true]]) then {_assignment set [2,false]};
            private _early=_earlyExits getOrDefault [netId _unit,[]];
            if ((_early param [3,""]) in ["FAILED","DIVERTED"]) exitWith {
                _job set ["egressFailed",true];
                false
            };
            // Retain observed arrivals, but frozen/hidden positions cannot establish a new exit.
            if (!(simulationEnabled _unit) || {isObjectHidden _unit}) exitWith {true};
            private _outside=_unit distance2D _target > 1
                || {abs (((getPosASL _unit) select 2)-((AGLToASL _target) select 2)) > 1.5};
            if (!_outside) then {
                _assignment set [2,true];
                if ([_unit] call _actorAvailable && {[_unit] call _actorTaskFree}
                    && {call _mayIssueMovement}) then {
                    doStop _unit;
                };
            };
            _outside
        };
        // Matching a ground exit horizontally is insufficient when still upstairs.
        private _arrived=_pending isEqualTo [] && {_assignments findIf {[_x] call _outsideExit} < 0};
        if (_arrived || {time >= (_job get "egressDeadline")}) then {
            if (_pending isNotEqualTo []) then {_job set ["egressFailed",true]};
            if (!_arrived && {_assignments isNotEqualTo []}) then {
                _job set ["egressFailed",true];
                diag_log format ["[WAIT] %1 clear egress incomplete (%2 still inside)",_group,{[_x] call _outsideExit} count _assignments];
                // Preserve the last owned exit request before terminal cleanup erases it.
                // One compact record per missing receipt, bounded by the admitted worker cap.
                {
                    _x params ["_actor","_target"];
                    if !(_x param [2,false,[true]]) then {
                        private _key=netId _actor;
                        private _progress=(_job get "egressProgress") select {(_x select 0) == _actor};
                        diag_log format ["WAIT CLEAR EGRESS STALL: %1",[_job get "generation",_key,
                            getPosATL _actor,+_target,currentCommand _actor,expectedDestination _actor,
                            unitReady _actor,getUnitState _actor,simulationEnabled _actor,isObjectHidden _actor,
                            (_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [_key,[]],
                            _progress apply {[_x select 1,_x select 2,_x select 3]}]];
                    };
                } forEach (_assignments select [0,8]);
            };
            [true,"COMPLETE"] call _finish
        } else {
            if (call _mayIssueMovement) then {
                {
                    _x params ["_unit","_target"];
                    if ([_x] call _outsideExit && {simulationEnabled _unit} && {!isObjectHidden _unit}
                        && {!(netId _unit in _earlyExits)}) then {
                        private _records=_job get "egressProgress";
                        private _recordIndex=_records findIf {(_x select 0) == _unit};
                        if (_recordIndex >= 0) then {
                            private _record=_records select _recordIndex;
                            // Stair and corridor detours can initially increase straight-line
                            // exit distance. Preserve a moving native path within the hard budget.
                            private _motionPose=_record param [6,getPosASL _unit,[[]]];
                            if (count _record < 7) then {_record set [5,time]; _record set [6,+_motionPose]};
                            if ((getPosASL _unit) vectorDistance _motionPose >= 1) then {
                                _record set [5,time];
                                _record set [6,getPosASL _unit];
                            };
                            private _motionStalled=time-(_record select 5) >= 8;
                            private _checkpoint=_record param [4,[],[[]]];
                            if (_checkpoint isNotEqualTo [] && {[_unit] call _actorAvailable}
                                && {[_unit] call _actorTaskFree} && {call _mayIssueMovement}) then {
                                private _atCheckpoint=(getPosASL _unit) vectorDistance (AGLToASL _checkpoint) <= 1.5
                                    && {abs (((getPosASL _unit) select 2)-((AGLToASL _checkpoint) select 2)) <= 0.75}
                                    && {[_unit,AGLToASL _checkpoint] call _roomSegmentClear};
                                if (_atCheckpoint || {time-(_record select 2) >= 8 && {_motionStalled}}) then {
                                    // A failed checkpoint also yields once to the original exit slot.
                                    // Neither case creates an exit receipt or renews the 45-second budget.
                                    _record set [4,[]];
                                    _unit doMove _target;
                                    [_unit,_target] call _rememberMove;
                                    _record set [1,(getPosATL _unit) vectorDistance _target];
                                    _record set [2,time];
                                    _checkpoint=[];
                                };
                            };
                            private _progressTarget=if (_checkpoint isEqualTo []) then {_target} else {_checkpoint};
                            private _remaining=(getPosATL _unit) vectorDistance _progressTarget;
                            if ((_record select 1)-_remaining >= 0.5) then {
                                _record set [1,_remaining];
                                _record set [2,time];
                            };
                            // Opening an unlocked door does not replace a moving route. The engine
                            // observes the opened door; only measured no-progress permits one retry.
                            [_unit,_job get "building",["CLEAR",_job get "generation"]] call WAIT_fnc_CortexBuildingDoor;
                            if (time-(_record select 2) >= 8 && {_motionStalled} && {(_record select 3) < 1}
                                && {[_unit] call _actorAvailable} && {[_unit] call _actorTaskFree} && {call _mayIssueMovement}) then {
                                // Try one physically visited current-floor point nearer the exit.
                                // Native room points remain candidates; selection itself proves no path.
                                private _exitRooms=_job get "positions";
                                private _candidates=if (insideBuilding _unit <= 0) then {[]} else {((_job get "cleared") select [0,24]) select {
                                    private _point=_exitRooms select _x;
                                    abs (((getPosASL _unit) select 2)-((AGLToASL _point) select 2)) <= 0.75
                                        && {_unit distance2D _point > 2}
                                }};
                                private _ranked=_candidates apply {
                                    private _point=_exitRooms select _x;
                                    [(_point distance2D _target)+0.25*(_unit distance2D _point),_x]
                                };
                                _ranked sort true;
                                private _retryTarget=+_target;
                                if (_ranked isNotEqualTo []) then {
                                    _retryTarget=+(_exitRooms select ((_ranked select 0) select 1));
                                    _record set [4,+_retryTarget];
                                    _record set [1,(getPosATL _unit) vectorDistance _retryTarget];
                                    _record set [2,time];
                                };
                                _unit doMove _retryTarget;
                                [_unit,_retryTarget] call _rememberMove;
                                _record set [3,1];
                                private _evidence=_group getVariable ["WAIT_Cortex_ClearEgressRetries",[]];
                                _evidence pushBack [serverTime,netId _unit,1,getPosATL _unit,+_target,_remaining];
                                _group setVariable ["WAIT_Cortex_ClearEgressRetries",_evidence,true];
                            };
                        };
                    };
                } forEach _assignments;
            };
            if (_pending isNotEqualTo []) then {0.1} else {1.5}
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
    // Exhausted ordinary room movers remain owned by this operation until handover.
    // Retiring their lane must not send them into native formation around an interior leader.
    private _quarantineHeld=_job getOrDefault ["quarantineHeld",[]];
    {
        if (_x in _unavailable && {!(_x in _quarantineHeld)} && {[_x] call _actorAvailable}
            && {[_x] call _actorTaskFree} && {call _mayIssueMovement}) then {
            doStop _x;
            _quarantineHeld pushBackUnique _x;
            // Continuing with replacements cannot erase an ordinary stranded worker.
            if !(_job getOrDefault ["entryFailed",false]) then {
                private _cause=["STRANDED_WORKER",netId _x,serverTime,getPosASL _x];
                _job set ["entryFailureCause",_cause];
                diag_log format ["WAIT CLEAR ENTRY FAILURE: %1",[_job get "generation",_cause]];
            };
            _job set ["entryFailed",true];
        };
    } forEach (_rotatedOut select [0,16]);
    _job set ["quarantineHeld",_quarantineHeld];
    private _reserveReady={
        params ["_candidate"];
        private _reservation=_candidate getVariable ["WAIT_Cortex_ActorMove",[]];
        private _reservationFree=_reservation isEqualTo []
            || {_reservation isEqualType [] && {count _reservation == 3} && {(_reservation param [2,1e12,[0]]) <= time}};
        // Once staging has claimed this reserve, a different individual MOVE/FOLLOW
        // is a replacement order. Do not promote it and overwrite that live command.
        private _stageReceipt=_candidate getVariable ["WAIT_Cortex_ClearReserve",[]];
        private _stagedHere=count _stageReceipt == 3
            && {(_stageReceipt select 0) == (_job get "generation")}
            && {(_stageReceipt select 1) == (_group getVariable ["WAIT_AIPass_Epoch",0])};
        private _stageCommandFree=!_stagedHere
            || {!(currentCommand _candidate in ["MOVE","FOLLOW"])}
            || {[_candidate] call _ownsCurrentMove};
        [_candidate] call WAIT_fnc_CortexCombatEffective && {simulationEnabled _candidate}
            && {!isObjectHidden _candidate} && {_stageCommandFree} && {local _candidate} && {!isPlayer _candidate}
            && {isNull objectParent _candidate} && {!(_candidate in _reserved)} && {!(_candidate in _rotatedOut)}
            && {!(_candidate in _unavailable)} && {isNull (remoteControlled _candidate)}
            && {([_candidate] call WAIT_fnc_CortexExternalOwner) == ""}
            && {_reservationFree} && {_candidate checkAIFeature "MOVE"} && {_candidate checkAIFeature "PATH"}
            && {!([_candidate] call WAIT_fnc_CompatibilityExternalControl)}
            && {!(currentCommand _candidate in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _reserves=(units _group) select {[_x] call _reserveReady && {_x != _leader}};
    if (_reserves isEqualTo [] && {[_leader] call _reserveReady}) then {
        _reserves pushBack _leader;
    };
    // Rotate the bounded service window: a small building can leave more than eight
    // eligible reserves, and a fixed prefix would never stage or recheck later actors.
    private _stageReserves=+_reserves;
    if (count _stageReserves > 8) then {
        private _cursor=(_job getOrDefault ["reserveStageCursor",0]) mod count _stageReserves;
        _stageReserves=(_stageReserves select [_cursor])+(_stageReserves select [0,_cursor]);
        _job set ["reserveStageCursor",(_cursor+8) mod count _stageReserves];
    };
    _stageReserves=_stageReserves select [0,8];
    // Reserves stage near the entry instead of following the native formation around the house.
    // This is one destination plus an arrival hold per actor, not a recurring movement rewrite.
    private _reserveStages=_job getOrDefault ["reserveStages",createHashMap];
    private _stageAttempts=_job getOrDefault ["reserveStageAttempts",[]];
    // Pending reserves do not consume attempts when another actor used this callback budget.
    private _stageSearchBudget=1;
    private _stageJournalChanged=false;
    private _stageSearchCounts=_job getOrDefault ["reserveStageSearchCounts",createHashMap];
    private _stageTriedTargets=_job getOrDefault ["reserveStageTriedTargets",createHashMap];
    private _stageTriedEntries=_job getOrDefault ["reserveStageTriedEntries",createHashMap];
    private _stageViewChecks=_job getOrDefault ["reserveStageViewChecks",createHashMap];
    private _stageViewBudget=1;
    private _stageViewKey="";
    private _earliestView=1e12;
    // Oldest due post wins; roster-first sampling would starve later observers.
    {
        private _candidateKey=netId _x;
        private _candidateStage=_reserveStages getOrDefault [_candidateKey,[]];
        if ((_candidateStage param [2,""]) == "ARRIVED"
            && {count (_candidateStage param [4,[],[[]]]) == 3}
            && {currentCommand _x in ["","STOP"]} && {[_x] call _reserveReady}) then {
            private _due=(_stageViewChecks getOrDefault [_candidateKey,[0,-1]]) select 0;
            if (_due < _earliestView) then {_earliestView=_due; _stageViewKey=_candidateKey};
        };
    } forEach _stageReserves;
    {
        private _reserve=_x;
        private _key=netId _reserve;
        private _stage=_reserveStages getOrDefault [_key,[]];
        private _searchCount=_stageSearchCounts getOrDefault [_key,0];
        private _searchPending=(_stage isEqualTo [] && {!(_key in _stageAttempts)})
            || {(_stage param [2,""]) == "REJECTED" && {_searchCount < 3}
                && {serverTime >= (_stage param [3,1e12])}};
        if (_searchPending && {_stageSearchBudget > 0} && {call _mayIssueMovement}) then {
            _stageSearchBudget=_stageSearchBudget-1;
            _stageAttempts pushBackUnique _key;
            _stageSearchCounts set [_key,(_searchCount+1) min 3];
            _stageJournalChanged=true;
            // A rejected staging ray must not leave a reserve following the interior leader.
            // Hold the actual position first; replace it only with the one validated stage leg.
            if ([_reserve] call _reserveReady && {call _mayIssueMovement}) then {
                private _hold=getPosATL _reserve;
                doStop _reserve;
                _reserve setVariable ["WAIT_Cortex_ClearReserve",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],+_hold]];
                _stage=[+_hold,true,"REJECTED"];
                _stage set [3,serverTime+5];
                if ((_searchCount+1) >= 3) then {_stage set [2,"EXHAUSTED"]};
                _reserveStages set [_key,_stage];
                private _securityActors=_job getOrDefault ["securityActors",[]];
                _securityActors pushBackUnique _reserve;
                _job set ["securityActors",_securityActors];
            };
            private _entry=_job get "entry";
            // Distribute observation among real exits using current live assignments.
            // This is capacity-aware selection, not a fixed ring or formation fan.
            private _entryRanks=[];
            private _triedEntries=+(_stageTriedEntries getOrDefault [_key,[]]);
            private _observationReserveKeys=_reserves apply {netId _x};
            private _bounds=boundingBoxReal _building;
            private _centre=_building modelToWorld (((_bounds select 0) vectorAdd (_bounds select 1)) vectorMultiply 0.5);
            _centre set [2,0];
            // Planned assignments guide distribution; they are never coverage proof.
            // Retired, diverted or physically departed posts must not bias a new choice.
            private _plannedEntries=[];
            {
                private _row=_earlyExits get _x;
                private _actor=objectFromNetId _x;
                private _postEntry=_row param [5,[],[[]]];
                if (count _postEntry == 3 && {[_actor] call _actorAvailable} && {[_actor] call _actorTaskFree}
                    && {!(_actor in _rotatedOut)} && {!(_actor in _unavailable)}
                    && {((_row select 3) == "MOVING" && {[_actor] call _ownsCurrentMove})
                        || {(_row select 3) == "ARRIVED" && {currentCommand _actor in ["","STOP"]}
                            && {(getPosASL _actor) vectorDistance (AGLToASL (_row select 1)) <= 2}}}) then {
                    _plannedEntries pushBack (+_postEntry);
                };
            } forEach ((keys _earlyExits) select [0,8]);
            {
                private _otherStage=_reserveStages getOrDefault [_x,[]];
                private _actor=objectFromNetId _x;
                private _postEntry=_otherStage param [5,[],[[]]];
                if (_x != _key && {_x in _observationReserveKeys} && {count _postEntry == 3}
                    && {[_actor] call _actorAvailable} && {[_actor] call _actorTaskFree}
                    && {!(_actor in _rotatedOut)} && {!(_actor in _unavailable)}
                    && {((_otherStage param [2,""]) == "APPROACH" && {[_actor] call _ownsCurrentMove})
                        || {(_otherStage param [2,""]) == "ARRIVED" && {currentCommand _actor in ["","STOP"]}
                            && {(getPosASL _actor) vectorDistance (AGLToASL (_otherStage select 0)) <= 2}}}) then {
                    _plannedEntries pushBack (+_postEntry);
                };
            } forEach (_observationReserveKeys select [0,8]);
            private _plannedBearings=_plannedEntries apply {_centre getDir _x};
            {
                private _candidateEntry=_x;
                private _assignedCount={_x isEqualTo _candidateEntry} count _plannedEntries;
                private _bearing=_centre getDir _candidateEntry;
                private _minimumBearingGap=180;
                {_minimumBearingGap=_minimumBearingGap min (abs (((_bearing-_x+540) mod 360)-180))} forEach _plannedBearings;
                // After failed/duplicate exits, prefer a different building face before distance.
                _entryRanks pushBack [[0,1] select (_candidateEntry in _triedEntries),_assignedCount,
                    -_minimumBearingGap,_reserve distance2D _candidateEntry,+_candidateEntry];
            } forEach ((_job getOrDefault ["securityEntries",_job getOrDefault ["entries",[]]]) select [0,16]);
            _entryRanks sort true;
            if (_entryRanks isNotEqualTo []) then {_entry=+((_entryRanks select 0) select 4)};
            if (_entry isNotEqualTo [] && {_searchCount < 3}) then {
                _triedEntries pushBackUnique +_entry;
                _stageTriedEntries set [_key,_triedEntries];
                private _outward=_centre getDir _entry;
                private _search=_entry getPos [7,_outward];
                private _watch=_entry getPos [2,_outward];
                _watch set [2,(_entry select 2)+1.2];
                private _taken=+(_stageTriedTargets getOrDefault [_key,[]]);
                private _liveReserveKeys=_reserves apply {netId _x};
                private _observerLanes=[];
                {
                    private _row=_earlyExits get _x;
                    if ((_row select 3) in ["MOVING","ARRIVED"] && {count (_row param [6,[]]) == 3}) then {
                        _taken pushBack +(_row select 1);
                        _observerLanes pushBack [+(_row select 1),+(_row select 6)];
                    };
                } forEach keys _earlyExits;
                // Historical stage receipts remain diagnostic, but promoted/unavailable actors
                // no longer reserve a destination. Physical occupancy is checked by the selector.
                {
                    if (_x != _key && {_x in _liveReserveKeys}) then {
                        private _otherStage=_reserveStages get _x;
                        _taken pushBack (_otherStage select 0);
                        private _otherWatch=_otherStage param [4,[],[[]]];
                        if ((_otherStage param [2,""]) in ["APPROACH","ARRIVED"]
                            && {count _otherWatch == 3}) then {
                            _observerLanes pushBack [+(_otherStage select 0),+_otherWatch];
                        };
                    };
                } forEach keys _reserveStages;
                private _cover=[_search,_centre,12,_taken,_group] call WAIT_fnc_CortexFindCover;
                private _target=_cover select 0;
                private _covered=_cover select 1;
                private _tried=+(_stageTriedTargets getOrDefault [_key,[]]);
                if (_covered) then {_tried pushBackUnique +_target};
                private _assessment=[_reserve,_building,_target,_entry,_watch,
                    _job getOrDefault ["securityEntries",_job getOrDefault ["entries",[]]],_taken,_observerLanes,true] call WAIT_fnc_BuildingExteriorCandidate;
                private _valid=_assessment select 0;
                diag_log format ["WAIT CLEAR RESERVE PROPOSAL: %1",[_job get "generation",_key,_searchCount+1,["SEARCH","COVER"] select _covered,+_target,+_entry,_valid,_assessment select 1]];
                if (!_valid) then {
                    private _empty=[_reserve,_search,_entry,_taken,_observerLanes] call WAIT_fnc_BuildingExteriorProposal;
                    if (count _empty == 3) then {
                        _empty set [2,0];
                        _tried pushBackUnique +_empty;
                        private _emptyAssessment=[_reserve,_building,_empty,_entry,_watch,
                            _job getOrDefault ["securityEntries",_job getOrDefault ["entries",[]]],_taken,_observerLanes,true] call WAIT_fnc_BuildingExteriorCandidate;
                        diag_log format ["WAIT CLEAR RESERVE PROPOSAL: %1",[_job get "generation",_key,_searchCount+1,"UNCOVERED",+_empty,+_entry,_emptyAssessment select 0,_emptyAssessment select 1]];
                        if (_emptyAssessment select 0) then {
                            _target=+_empty; _valid=true; _covered=false;
                        };
                    } else {
                        diag_log format ["WAIT CLEAR RESERVE PROPOSAL: %1",[_job get "generation",_key,_searchCount+1,"NO_NATIVE_PROPOSAL",[],+_entry,false,[]]];
                    };
                };
                // Two proposals per search, three searches; migration must not renew history.
                _stageTriedTargets set [_key,_tried select [0,6]];
                if (_valid) then {
                    if ([_reserve] call _reserveReady && {call _mayIssueMovement}) then {
                        _reserve setVariable ["WAIT_Cortex_ClearReserve",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],+_target]];
                        _reserve doMove _target;
                        [_reserve,_target] call _rememberMove;
                        _stage=[+_target,false,"APPROACH"];
                        _stage set [3,serverTime+60];
                        _stage set [4,+_watch];
                        _stage set [5,+_entry];
                        _stage set [6,_covered];
                        _reserveStages set [_key,_stage];
                        private _securityActors=_job getOrDefault ["securityActors",[]];
                        _securityActors pushBackUnique _reserve;
                        _job set ["securityActors",_securityActors];
                    };
                };
            };
        };
        // Arrival proximity does not authorize cancelling a different live MOVE.
        // Preserve floor-aware native commitment just as for interior room holds.
        if (_stage isNotEqualTo [] && {!(_stage select 1)}
            && {(getPosASL _reserve) vectorDistance (AGLToASL (_stage select 0)) <= 2}
            && {abs (((getPosASL _reserve) select 2)-((AGLToASL (_stage select 0)) select 2)) <= 0.75}
            && {currentCommand _reserve in ["", "STOP"] || {[_reserve] call _ownsCurrentMove}}
            && {!([_reserve] call _activeOwnMove)}
            && {[_reserve] call _reserveReady} && {call _mayIssueMovement}) then {
            doStop _reserve;
            _stage set [1,true];
            _stage set [2,"ARRIVED"];
            _stageJournalChanged=true;
        };
        // Revalidate one actual eye ray per callback, at most once per actor every two
        // seconds. A transient passing teammate cannot immediately cause another route.
        private _viewWatch=_stage param [4,[],[[]]];
        // Grant watch installation only to the reserve whose actual eye ray succeeds now.
        // Arrival/proposal geometry and a historical check are not current observation proof.
        private _viewConfirmed=false;
        private _viewCheck=_stageViewChecks getOrDefault [_key,[0,-1]];
        if ((_stage param [2,""]) == "ARRIVED" && {count _viewWatch == 3}
            && {_key == _stageViewKey} && {_stageViewBudget > 0} && {serverTime >= (_viewCheck select 0)}
            && {currentCommand _reserve in ["","STOP"]}
            && {[_reserve] call _reserveReady} && {call _mayIssueMovement}) then {
            _stageViewBudget=_stageViewBudget-1;
            private _eye=eyePos _reserve;
            private _watchASL=AGLToASL _viewWatch;
            private _viewValid=(getPosASL _reserve) vectorDistance (AGLToASL (_stage select 0)) <= 2
                && {!terrainIntersectASL [_eye,_watchASL]}
                && {(lineIntersectsSurfaces [_eye,_watchASL,_reserve,objNull,true,1,"VIEW","NONE"]) isEqualTo []};
            _viewConfirmed=_viewValid;
            private _blockedSince=_viewCheck select 1;
            if (_viewValid) then {_blockedSince=-1} else {
                if (_blockedSince < 0) then {_blockedSince=serverTime};
            };
            _stageViewChecks set [_key,[serverTime+2,_blockedSince]];
            if (!_viewValid && {_blockedSince >= 0} && {serverTime-_blockedSince >= 3}
                && {[_reserve] call _reserveReady} && {call _mayIssueMovement}
                && {currentCommand _reserve in ["","STOP"]}) then {
                private _ownedWatch=[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],+_viewWatch];
                if ((_reserve getVariable ["WAIT_Cortex_ClearExitWatch",[]]) isEqualTo _ownedWatch) then {
                    _reserve doWatch objNull;
                    _reserve setVariable ["WAIT_Cortex_ClearExitWatch",nil,true];
                    if ((_reserve getVariable ["WAIT_Cortex_ClearExitWatchLocal",[]]) isEqualTo _ownedWatch) then {
                        _reserve setVariable ["WAIT_Cortex_ClearExitWatchLocal",nil];
                    };
                };
                private _hold=getPosATL _reserve;
                // The actor already holds here; retire bookkeeping without a fresh move/stop.
                (_job getOrDefault ["movementTargets",createHashMap]) deleteAt _key;
                _reserve setVariable ["WAIT_Cortex_ClearReserve",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],+_hold]];
                _stage=[+_hold,true,"REJECTED",serverTime+5];
                if ((_stageSearchCounts getOrDefault [_key,0]) >= 3) then {_stage set [2,"EXHAUSTED"]};
                _reserveStages set [_key,_stage];
                _stageViewChecks deleteAt _key;
                _stageJournalChanged=true;
                diag_log format ["WAIT CLEAR EXIT VIEW LOST: %1",[_job get "generation",_key,_hold,_viewWatch,_blockedSince,_stage select 2]];
            };
        };
        // Public arrival does not replay owner-local watching. Install once on
        // this owner epoch after physical arrival, preserving native task authority.
        private _watch=_stage param [4,[],[[]]];
        private _watchLease=[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],+_watch];
        if ((_stage param [2,""]) == "ARRIVED" && {count _watch == 3} && {_viewConfirmed}
            && {(_reserve getVariable ["WAIT_Cortex_ClearExitWatchLocal",[]]) isNotEqualTo _watchLease}
            && {(getPosASL _reserve) vectorDistance (AGLToASL (_stage select 0)) <= 2}
            && {abs (((getPosASL _reserve) select 2)-((AGLToASL (_stage select 0)) select 2)) <= 0.75}
            && {currentCommand _reserve in ["","STOP"]}
            && {[_reserve] call _reserveReady} && {call _mayIssueMovement}) then {
            _reserve doWatch _watch;
            _reserve setVariable ["WAIT_Cortex_ClearExitWatch",_watchLease,true];
            _reserve setVariable ["WAIT_Cortex_ClearExitWatchLocal",_watchLease];
            diag_log format ["WAIT CLEAR EXIT OBSERVATION: %1",[
                _job get "generation",netId _reserve,+(_stage select 0),+_watch,
                _stage param [6,false,[true]]]];
        };
        // A deadline may retire only the movement request this stage still owns. It does not
        // renew the clearance lifetime or turn a blocked approach into an arrival receipt.
        if ((_stage param [2,""]) == "APPROACH" && {serverTime >= (_stage param [3,1e12])}
            && {[_reserve] call _ownsCurrentMove} && {[_reserve] call _reserveReady}
            && {call _mayIssueMovement}) then {
            private _hold=getPosATL _reserve;
            doStop _reserve;
            (_job getOrDefault ["movementTargets",createHashMap]) deleteAt _key;
            _reserve setVariable ["WAIT_Cortex_ClearReserve",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],+_hold]];
            _stage=[+_hold,true,"REJECTED"];
            _stage set [3,serverTime+5];
            if ((_stageSearchCounts getOrDefault [_key,0]) >= 3) then {_stage set [2,"EXHAUSTED"]};
            _reserveStages set [_key,_stage];
            _stageJournalChanged=true;
        };
    } forEach _stageReserves;
    _job set ["reserveStages",_reserveStages];
    _job set ["reserveStageViewChecks",_stageViewChecks];
    _job set ["reserveStageAttempts",_stageAttempts];
    _job set ["reserveStageSearchCounts",_stageSearchCounts];
    _job set ["reserveStageTriedTargets",_stageTriedTargets];
    _job set ["reserveStageTriedEntries",_stageTriedEntries];
    // Build the migration journal only after an owned stage transition. Idle callbacks
    // retain the published receipt without copying every actor record again.
    if (_stageJournalChanged && {call _mayIssueMovement}) then {
        private _budgetRows=(keys _stageSearchCounts select [0,64]) apply {
            [_x,_stageSearchCounts get _x,+(_stageTriedTargets getOrDefault [_x,[]]),+(_reserveStages getOrDefault [_x,[]]),+(_stageTriedEntries getOrDefault [_x,[]])]
        };
        private _stageBudget=[_building,_job get "hardDeadline",_job get "buildingTransform",_budgetRows];
        if ((_group getVariable ["WAIT_Cortex_ClearStageBudget",[]]) isNotEqualTo _stageBudget) then {
            _group setVariable ["WAIT_Cortex_ClearStageBudget",_stageBudget,true];
        };
    };
    // Promotion cannot spend an established exit observer without a physically settled
    // substitute. One fresh VIEW ray per callback bounds casualty-time confirmation.
    // A stale role label, an approaching actor or a previous clear ray is not coverage.
    private _promotionViewBudget=1;
    private _promotionCandidates=+(_reserves select [0,16]);
    if (_promotionCandidates isNotEqualTo []) then {
        private _cursor=(_job getOrDefault ["promotionCandidateCursor",0]) mod count _promotionCandidates;
        _promotionCandidates=(_promotionCandidates select [_cursor])+(_promotionCandidates select [0,_cursor]);
        _job set ["promotionCandidateCursor",(_cursor+1) mod count _promotionCandidates];
    };
    // Completed interior workers can hold the same exit as a reserve. Their real watch is
    // a valid substitute, even though they remain in the original lane roster, not _reserves.
    private _promotionObservers=+(_reserves select [0,16]);
    {
        private _row=_earlyExits get _x;
        if ((_row param [3,""]) == "ARRIVED") then {
            _promotionObservers pushBackUnique (_row param [0,objNull]);
        };
    } forEach (keys _earlyExits select [0,8]);
    if (_promotionObservers isNotEqualTo []) then {
        private _cursor=(_job getOrDefault ["promotionObserverCursor",0]) mod count _promotionObservers;
        _promotionObservers=(_promotionObservers select [_cursor])+(_promotionObservers select [0,_cursor]);
        _job set ["promotionObserverCursor",(_cursor+1) mod count _promotionObservers];
    };
    private _mayPromoteReserve={
        params ["_candidate"];
        if (!(_candidate in _reserves) || {!([_candidate] call _reserveReady)}) exitWith {false};
        private _stage=_reserveStages getOrDefault [netId _candidate,[]];
        if ((_stage param [2,""]) != "ARRIVED") exitWith {true};
        if (_promotionViewBudget <= 0) exitWith {false};
        private _exit=_stage param [5,[],[[]]];
        if (count _exit != 3) exitWith {false};
        private _covered=false;
        {
            private _observer=_x;
            private _otherStage=_reserveStages getOrDefault [netId _observer,[]];
            private _observerReady=_observer in _reserves && {[_observer] call _reserveReady};
            if (!(_observer in _reserves)) then {
                private _row=_earlyExits getOrDefault [netId _observer,[]];
                _observerReady=(_row param [0,objNull]) == _observer
                    && {(_row param [3,""]) == "ARRIVED"}
                    && {[_observer] call _actorAvailable} && {[_observer] call _actorTaskFree}
                    && {!(_observer in _unavailable)};
                _otherStage=[_row param [1,[]],true,_row param [3,""],0,
                    _row param [6,[]],_row param [5,[]]];
            };
            private _watch=_otherStage param [4,[],[[]]];
            private _post=_otherStage param [0,[],[[]]];
            private _watchLease=[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],+_watch];
            if (_observer != _candidate && {_observerReady}
                && {(_otherStage param [2,""]) == "ARRIVED"}
                && {(_otherStage param [5,[],[[]]]) isEqualTo _exit}
                && {count _post == 3} && {count _watch == 3}
                && {currentCommand _observer in ["","STOP"]}
                && {(_observer getVariable ["WAIT_Cortex_ClearExitWatch",[]]) isEqualTo _watchLease}
                && {(_observer getVariable ["WAIT_Cortex_ClearExitWatchLocal",[]]) isEqualTo _watchLease}
                && {(getPosASL _observer) vectorDistance (AGLToASL _post) <= 2}
                && {abs (((getPosASL _observer) select 2)-((AGLToASL _post) select 2)) <= 0.75}
                && {_promotionViewBudget > 0}) then {
                _promotionViewBudget=_promotionViewBudget-1;
                private _eye=eyePos _observer;
                private _watchASL=AGLToASL _watch;
                _covered=!terrainIntersectASL [_eye,_watchASL]
                    && {(lineIntersectsSurfaces [_eye,_watchASL,_observer,objNull,true,1,"VIEW","NONE"]) isEqualTo []};
            };
            if (_covered) exitWith {};
        } forEach _promotionObservers;
        _covered
    };
    private _pairRosterChanged=false;
    {
        private _pairIndex=_forEachIndex;
        private _pair=_x;
        private _state=_pairStates select _pairIndex;
        private _laneRosterChanged=false;
        private _laneReplacements=[];
        for "_slot" from 0 to ((count _pair)-1) do {
            private _member=_pair select _slot;
            if ((!([_member] call _actorAvailable) || {_member in _unavailable}) && {_reserves isNotEqualTo []}) then {
                // Reinforce the surviving buddy from the nearest eligible reserve rather
                // than roster order. With no available buddy, approach the building itself.
                // Candidate ranking shares the bounded promotion VIEW budget above.
                private _buddy=_pair select ((_slot+1) mod count _pair);
                private _reinforceAnchor=if (_buddy != _member && {[_buddy] call _actorAvailable}
                    && {!(_buddy in _unavailable)}) then {_buddy} else {_building};
                private _replacementIndex=-1;
                private _replacementDistance=1e12;
                {
                    private _distance=_x distance2D _reinforceAnchor;
                    if (_distance < _replacementDistance && {[_x] call _mayPromoteReserve}) then {
                        _replacementIndex=_reserves find _x;
                        _replacementDistance=_distance;
                    };
                } forEach _promotionCandidates;
                // Keep the casualty slot pending if the only replacements hold sole exit cover.
                // Neither this wait nor budget deferral renews the finite clearance deadline.
                if (_replacementIndex < 0) then {continue};
                private _replacement=_reserves deleteAt _replacementIndex;
                // Promotion changes this actor's purpose. Retire only the matching
                // exit watch before an interior movement leg can inherit it.
                private _exitWatch=_replacement getVariable ["WAIT_Cortex_ClearExitWatch",[]];
                if (count _exitWatch == 3
                    && {(_exitWatch select 0) == (_job get "generation")}
                    && {(_exitWatch select 1) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
                    && {[_replacement] call _actorTaskFree} && {call _mayIssueMovement}) then {
                    _replacement doWatch objNull;
                    _replacement setVariable ["WAIT_Cortex_ClearExitWatch",nil,true];
                    _replacement setVariable ["WAIT_Cortex_ClearExitWatchLocal",nil];
                    _replacement setVariable ["WAIT_Cortex_ClearReserve",nil];
                };
                _pair set [_slot,_replacement];
                _laneReplacements pushBack _replacement;
                _pairRosterChanged=true;
                _laneRosterChanged=true;
                _rotatedOut pushBackUnique _member;
                private _team=_job get "team";
                _team pushBackUnique _replacement;
                // The pair and common lifecycle must account for the same replacement.
                // A reserve's real travel cannot renew progress while absent from this roster.
                private _liveOperation=_group getVariable ["WAIT_Operation",createHashMap];
                if ((_liveOperation getOrDefault ["generation",-1]) == _operationGeneration
                    && {(_liveOperation getOrDefault ["intent",""]) == "CLEAR"}
                    && {(_liveOperation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}) then {
                    private _participants=+(_liveOperation getOrDefault ["participants",[]]);
                    _participants=_participants-[_member];
                    _participants pushBackUnique _replacement;
                    private _progressRecords=(_liveOperation getOrDefault ["participantProgress",[]]) select {(_x select 0) != _member};
                    if (_progressRecords findIf {(_x select 0) == _replacement} < 0) then {
                        _progressRecords pushBack [_replacement,getPosATL _replacement];
                    };
                    // Retire only the removed actor's active observation. Its retry budget and
                    // unavailable status remain generation-owned, preventing reserve rotation from
                    // making a failed actor eligible for unlimited recovery attempts.
                    private _recovery=_liveOperation getOrDefault ["recovery",createHashMap];
                    _recovery deleteAt (netId _member);
                    _liveOperation set ["recovery",_recovery];
                    _liveOperation set ["participants",_participants];
                    _liveOperation set ["participantProgress",_progressRecords];
                    _group setVariable ["WAIT_Operation",_liveOperation,true];
                };
                (_job get "assigned") pushBack [];
                private _lastPositions=_state select 2;
                _lastPositions set [_slot,getPosATL _replacement];
                _state set [2,_lastPositions];
                _state set [3,time];
                _state set [4,0];
                _state set [5,-1];
                // A reserve starts at its own physical position. Do not compare its travel
                // against the removed actor's nearer best-distance baseline.
                _state set [13,1e12];
                _state set [14,[]];
                private _evidence=_group getVariable ["WAIT_Cortex_ClearReinforcements",[]];
                _evidence pushBack [serverTime,netId _member,netId _replacement,_pairIndex,_slot];
                _group setVariable ["WAIT_Cortex_ClearReinforcements",_evidence,true];
                diag_log format ["[WAIT] Clear pair %1 reinforced: %2 replaced %3",_pairIndex,_replacement,_member];
            };
        };
        // A wholly replaced exterior lane must establish its own physical entry.
        // Retain the original route, room coverage and deadline; an entered survivor
        // keeps its current interior progress and is never rallied outside.
        if (_laneRosterChanged) then {
            private _enteredActors=_job getOrDefault ["enteredActors",[]];
            private _survivorIndex=_pair findIf {_x in _enteredActors};
            if (_survivorIndex < 0) then {
                _state set [0,0];
                _state set [8,-1];
                _state set [12,false];
            };
            // Early casualties may occur before either actor enters. Preserve the
            // healthy original buddy's approach rather than making the distant reserve
            // inherit the mover slot. A wholly replaced lane has no original survivor.
            if (_survivorIndex < 0) then {
                _survivorIndex=_pair findIf {!(_x in _laneReplacements) && {[_x] call _actorAvailable} && {!(_x in _unavailable)}};
            };
            if (_survivorIndex >= 0) then {
                private _currentMover=_pair select ((_state select 7) mod count _pair);
                if (_currentMover in _laneReplacements && {!(_currentMover in _enteredActors)}) then {
                    _state set [7,_survivorIndex];
                    _state set [5,-1];
                    diag_log format ["WAIT CLEAR REPLACEMENT ENTRY HANDOFF: %1",[
                        _job get "generation",_pairIndex,netId _currentMover,netId (_pair select _survivorIndex)]];
                };
            };
        };
    } forEach _pairs;
    _job set ["rotatedOut",_rotatedOut];
    if (_pairRosterChanged) then {
        // Publish the actual lane partners, without rebuilding an active lane's route.
        private _pairSnapshot=_pairs apply {+_x};
        _group setVariable ["WAIT_CombatPairs",_pairSnapshot,true];
        private _liveOperation=_group getVariable ["WAIT_Operation",createHashMap];
        if ((_liveOperation getOrDefault ["generation",-1]) == _operationGeneration
            && {(_liveOperation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}) then {
            _liveOperation set ["pairs",_pairSnapshot];
            _group setVariable ["WAIT_Operation",_liveOperation,true];
        };
    };
    // Release reservations before selection so another soldier can visit a casualty's room.
    // Reassigned units belong to their new commander and must receive no further orders here.
    private _activeWorkers=(_job get "team") select {[_x] call _actorAvailable
        && {!(_x in _rotatedOut)} && {!(_x in _unavailable)}};
    // Every assigned lane gets a chance before a room is declared exhausted.
    // A fixed two-lane threshold abandoned rooms while a third capable pair existed.
    // The operation deadline and finite per-room recovery budget still bound retries.
    private _failureThreshold=(count (_job get "pairs")) max 1;
    {
        if (!([_x] call _actorAvailable) || {_x in _rotatedOut} || {_x in _unavailable}) then {
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
    // Rotate first observer so budget exhaustion cannot always prefer one worker.
    private _actorCursor=(_job getOrDefault ["visitActorCursor",0]) mod ((count _activeWorkers) max 1);
    private _visitWorkers=(_activeWorkers select [_actorCursor]) + (_activeWorkers select [0,_actorCursor]);
    _job set ["visitActorCursor",(_actorCursor+1) mod ((count _activeWorkers) max 1)];
    private _visitChangedActors=[];
    {
        private _visitor = _x;
        if ([_visitor] call WAIT_fnc_CortexCombatEffective && {simulationEnabled _visitor}
            && {!isObjectHidden _visitor} && {local _visitor} && {!isPlayer _visitor}
            && {isNull (remoteControlled _visitor)}
            && {([_visitor] call WAIT_fnc_CortexExternalOwner) == ""}
            && {!([_visitor] call WAIT_fnc_CompatibilityExternalControl)} && {group _visitor == _group}
            && {isNull objectParent _visitor}) then {
            private _actual = getPosASL _visitor;
            {
                private _positionIndex=_x;
                private _positionASL=AGLToASL (_positions select _positionIndex);
                private _atPosition=_actual vectorDistance _positionASL <= 1.5
                    && {abs ((_actual select 2)-(_positionASL select 2)) <= 0.75}
                    && {[_visitor] call _observerInside}
                    && {[_visitor,_positionASL] call _roomSegmentClear};
                if (_atPosition) then {
                    private _enteredActors=_job getOrDefault ["enteredActors",[]];
                    _enteredActors pushBackUnique _visitor;
                    _job set ["enteredActors",_enteredActors];
                    private _actorVisits=_job getOrDefault ["actorVisits",createHashMap];
                    private _visited=_actorVisits getOrDefault [netId _visitor,[]];
                    if !(_positionIndex in _visited) then {
                        _visited pushBackUnique _positionIndex;
                        _visitChangedActors pushBackUnique _visitor;
                    };
                    _actorVisits set [netId _visitor,_visited];
                    _job set ["actorVisits",_actorVisits];
                };
                if !(_positionIndex in _cleared) then {
                    if (_atPosition) then {
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
    } forEach _visitWorkers;
    // Coalesce physical observations to one public receipt per changed actor per callback.
    // Index plus exact native position prevents replay against a reordered topology.
    // This is historical participation only, never current arrival or movement authority.
    if (_visitChangedActors isNotEqualTo [] && {call _mayIssueMovement}) then {
        private _visitContext=_job getOrDefault ["visitContext",[]];
        if (count _visitContext == 4) then {
            {
                private _actor=_x;
                if (local _actor && {group _actor == _group}) then {
                    private _visits=(_job get "actorVisits") getOrDefault [netId _actor,[]];
                    private _rows=(_visits select [0,512]) apply {[_x,+(_positions select _x)]};
                    _actor setVariable ["WAIT_Cortex_ClearVisits",[_group,+_visitContext,_rows],true];
                };
            } forEach (_visitChangedActors select [0,8]);
        };
    };
    // Claimed rooms are still unfinished. Floor priority must include them until a
    // physical visit or bounded failure, rather than advancing when the queue removes a claim.
    private _floorWave=_job getOrDefault ["unfinishedFloorWave",[-1,-1,1e12]];
    if ((_floorWave select 0) != count _cleared || {(_floorWave select 1) != count _unreachable}) then {
        private _lowestUnfinished=1e12;
        for "_roomIndex" from 0 to ((count _positions)-1) do {
            if !(_roomIndex in (_cleared+_unreachable)) then {
                _lowestUnfinished=_lowestUnfinished min ((AGLToASL (_positions select _roomIndex)) select 2);
            };
        };
        _floorWave=[count _cleared,count _unreachable,_lowestUnfinished];
        _job set ["unfinishedFloorWave",_floorWave];
    };
    private _lowestUnfinishedFloor=_floorWave select 2;
    private _pairRoutes=_job get "pairRoutes";
    {
        private _pairIndex=_forEachIndex;
        private _pair=_x select {[_x] call _actorAvailable && {!(_x in _unavailable)} && {!(netId _x in _earlyExits)}};
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
                // Shared coverage may retire work only after this lane has physically entered.
                private _laneEntered=_entered || {_pair findIf {_x in (_job getOrDefault ["enteredActors",[]])} >= 0};
                while {_cursor < count _route && {(_route select _cursor) in _unreachable || {(_route select _cursor) in _cleared && {_laneEntered} && {!([_pair select (_moverIndex mod count _pair)] call _activeOwnMove)}}}} do {
                    private _completedRoom=_route select _cursor;
                    // Physical visits are collected before this loop. Apply the room handoff
                    // here before skipping it, otherwise the mover never rotates and its
                    // partner keeps exterior security even after the first interior visit.
                    // Shared completion can belong to another lane. Only this pair's
                    // physical arrival proves its entry and interior support handoff.
                    if (_completedRoom in _cleared && {_pair findIf {
                        _completedRoom in ((_job getOrDefault ["actorVisits",createHashMap]) getOrDefault [netId _x,[]])
                    } >= 0}) then {
                        _entered=true;
                        _previousPositionIndex=_completedRoom;
                        _roomsCleared=_roomsCleared+1;
                        if (count _pair > 1) then {
                            private _nextMover=(_moverIndex+1) mod count _pair;
                            // Entry receipts come only from the floor-aware visit collector above.
                            private _enteredActors=_job getOrDefault ["enteredActors",[]];
                            // A security partner still outside cannot inherit an interior leg.
                            // Keep the successful entrant moving while its partner follows the
                            // preceding room through the native entrance. Alternate only after
                            // that partner physically reaches the lane's first interior node.
                            if ((_pair select _nextMover) in _enteredActors) then {
                                _moverIndex=_nextMover;
                            };
                        };
                        _lastTarget=-1;
                        _retries=0;
                        _lastProgress=_now;
                    };
                    _cursor=_cursor+1;
                };
                // Partner entry recovery is independent of the lead's current room.
                // A finished room queue must not strand an unentered partner with an ended order.
                if (count _pair > 1 && {_route isNotEqualTo []}) then {
                    private _partner=_pair select ((_moverIndex+1) mod count _pair);
                    if !(_partner in (_job getOrDefault ["enteredActors",[]])) then {
                        // Entry handling can precede support-target cache creation.
                        // A missing cache must not suppress this actor's finite recovery.
                        private _entryTargets=_job getOrDefault ["pairEntryTargets",createHashMap];
                        private _entryKey=str _pairIndex;
                        private _entryTarget=_entryTargets getOrDefault [_entryKey,_positions select (_route select 0)];
                        // Publish the map, but not this provisional fallback: initial support
                        // planning still needs to choose its separate connected interior point.
                        _job set ["pairEntryTargets",_entryTargets];
                        if (_entryTarget isEqualTo (_positions select (_route select 0))) then {
                            _entryTarget=[_route select 0] call _roomMovementPoint;
                        };
                        private _entryRecovery=_job getOrDefault ["entryRecovery",createHashMap];
                        private _key=netId _partner;
                        private _distance=(getPosASL _partner) vectorDistance (AGLToASL _entryTarget);
                        private _receipt=_entryRecovery getOrDefault [_key,[_distance,_now,false]];
                        if ((_receipt select 0)-_distance >= 1) then {
                            _receipt set [0,_distance]; _receipt set [1,_now];
                        };
                        if (!(_receipt select 2) && {_now-(_receipt select 1) >= 12}
                            && {[_partner] call _actorAvailable} && {[_partner] call _actorTaskFree}
                            && {call _mayIssueMovement}) then {
                            // A nearby candidate can have clear geometry but still lack a native
                            // entrance path. Once its lead has physically visited the lane anchor,
                            // retry the partner through that proven anchor rather than repeating
                            // the same unvisited candidate. This consumes the existing one-shot
                            // entry recovery; it cannot retire a room or fabricate partner entry.
                            private _anchorIndex=_route select 0;
                            private _anchor=_positions select _anchorIndex;
                            if (_anchorIndex in _cleared && {_entryTarget isNotEqualTo _anchor}) then {
                                _entryTarget=+_anchor;
                                (_job get "pairEntryTargets") set [str _pairIndex,+_anchor];
                                diag_log format ["WAIT CLEAR PARTNER ACCESS: %1",[_job get "generation",_pairIndex,netId _partner,+_anchor]];
                            };
                            private _recovery=[_group,_operationGeneration,_partner,_entryTarget] call WAIT_fnc_RecoveryStep;
                            if (_recovery == "RECOVERING") then {[_partner,_entryTarget] call _rememberMove};
                            if (_recovery in ["RECOVERING","EXHAUSTED","INVALID"]) then {
                                _receipt set [2,true];
                            };
                        };
                        // Do not wait for an unrelated final room before giving an exterior
                        // partner one alternative. The same owner-local callback records the
                        // shared pair target before issuing it, even if this lane's room queue
                        // has ended. Later pair steps recognize and preserve the active path.
                        private _alternativeReceipt=_partner getVariable ["WAIT_Cortex_ClearEntryAlternative",[]];
                        private _sameAlternativeEpisode=count _alternativeReceipt >= 4
                            && {(_alternativeReceipt select 0) == _building}
                            && {(_alternativeReceipt select 1) == (_job get "hardDeadline")}
                            && {(_alternativeReceipt select 2) isEqualTo (_job get "buildingTransform")};
                        private _alternativeSearches=if (_sameAlternativeEpisode) then {
                            _alternativeReceipt param [4,1,[0]]
                        } else {0};
                        private _alternativeCoverage=if (_sameAlternativeEpisode) then {
                            _alternativeReceipt param [5,count _cleared,[0]]
                        } else {-1};
                        // A failed selection can become useful after another lane proves a
                        // new point. Reassess only on increased coverage, at most three times.
                        // A successful alternative still consumes the one movement alternative.
                        private _alternativeUsed=_sameAlternativeEpisode && {
                            (_alternativeReceipt select 3) isNotEqualTo []
                                || {_alternativeSearches >= 3}
                                || {_alternativeCoverage >= count _cleared}
                        };
                        if ((_receipt select 2) && {_now-(_receipt select 1) >= 24}
                            && {!_alternativeUsed} && {_cleared isNotEqualTo []}
                            && {[_partner] call _actorAvailable} && {[_partner] call _actorTaskFree}
                            && {call _mayIssueMovement}) then {
                            private _pose=getPosASL _partner;
                            private _alternatives=[];
                            {
                                private _candidate=_positions select _x;
                                private _candidateASL=AGLToASL _candidate;
                                if (_candidate vectorDistance _entryTarget >= 2.5
                                    && {abs ((_candidateASL select 2)-(_pose select 2)) <= 0.75}
                                    && {_candidateASL vectorDistance _pose <= 30}) then {
                                    _alternatives pushBack [_candidateASL vectorDistance _pose,+_candidate];
                                };
                            } forEach (_cleared select [0,24]);
                            _alternatives sort true;
                            private _alternative=if (_alternatives isNotEqualTo []) then {+((_alternatives select 0) select 1)} else {[]};
                            _partner setVariable ["WAIT_Cortex_ClearEntryAlternative",[
                                _building,_job get "hardDeadline",_job get "buildingTransform",
                                +_alternative,_alternativeSearches+1,count _cleared],true];
                            diag_log format ["WAIT CLEAR PARTNER ENTRY SEARCH: %1",[
                                _job get "generation",_pairIndex,netId _partner,
                                _alternativeSearches+1,count _cleared,+_alternative]];
                            if (_alternative isNotEqualTo []) then {
                                (_job get "pairEntryTargets") set [str _pairIndex,+_alternative];
                                _receipt set [0,_pose vectorDistance (AGLToASL _alternative)];
                                _partner doMove _alternative;
                                [_partner,_alternative] call _rememberMove;
                                _lastTarget=-1;
                                diag_log format ["WAIT CLEAR PARTNER ENTRY ALTERNATIVE: %1",[
                                    _job get "generation",_pairIndex,netId _partner,+_entryTarget,+_alternative]];
                            };
                        };
                        _entryRecovery set [_key,_receipt];
                        _job set ["entryRecovery",_entryRecovery];
                    };
                };
                // Persist retirement even when no pending room can be claimed this step.
                _state set [0,_cursor]; _state set [3,_lastProgress];
                _state set [4,_retries]; _state set [5,_lastTarget];
                _state set [7,_moverIndex]; _state set [8,_previousPositionIndex];
                _state set [11,_roomsCleared]; _state set [12,_entered];
                // Claim the nearest room that this pair has not already failed. Claims are removed
                // from the shared queue immediately, preventing several pairs from crowding one node.
                if (_cursor >= count _route) then {
                    private _pending=_job get "pending";
                    private _pairId=format ["PAIR_%1",_pairIndex];
                    private _availableCandidates=_pending select {!(_pairId in (_failedBy select _x))};
                    private _candidates=_availableCandidates select {
                        abs (((AGLToASL (_positions select _x)) select 2)-_lowestUnfinishedFloor) < 1.8
                    };
                    private _waitingForFloor=_availableCandidates isNotEqualTo [] && {_candidates isEqualTo []};
                    if (_waitingForFloor || {_availableCandidates isEqualTo []}) then {
                        // Hold idle completed workers when the queue ends, as well as workers
                        // waiting for lower rooms. Otherwise native formation following resumes
                        // around the leader and these actors never acquire a yieldable room hold.
                        // Unfinished partners retain their entry/follow-through path.
                        private _holds=_job getOrDefault ["roomHolds",createHashMap];
                        {
                            private _waitingActor=_x;
                            private _key=netId _waitingActor;
                            private _completedWorker=count ((_job getOrDefault ["actorVisits",createHashMap]) getOrDefault [_key,[]]) >= (2 min count _positions);
                            if ((_waitingForFloor || {_completedWorker})
                                && {[_waitingActor] call _actorAvailable} && {[_waitingActor] call _actorTaskFree}
                                && {call _mayIssueMovement} && {!([_waitingActor] call _activeOwnMove)}
                                && {currentCommand _waitingActor in ["","STOP","FOLLOW"]}
                                && {!(_key in _holds) || {currentCommand _waitingActor != "STOP"}}) then {
                                private _hold=getPosATL _waitingActor;
                                doStop _waitingActor;
                                _holds set [_key,+_hold];
                                diag_log format ["WAIT CLEAR FLOOR QUEUE HOLD: %1",[_job get "generation",_pairIndex,_key,_lowestUnfinishedFloor,+_hold,["COMPLETED_QUEUE","LOWER_FLOOR"] select _waitingForFloor]];
                            };
                        } forEach _pair;
                        _job set ["roomHolds",_holds];
                    };
                    if (_candidates isNotEqualTo []) then {
                        // Prefer free room destinations before model-order/distance ranking.
                        // If every candidate is occupied, retain the finite native attempt;
                        // support occupancy must not empty the pending queue or create a deadlock.
                        private _occupied=[_pair] call _occupiedRoomTargets;
                        private _freeCandidates=_candidates select {
                            !([_positions select _x,_occupied] call _roomTargetOccupied)
                        };
                        if (_freeCandidates isNotEqualTo []) then {_candidates=_freeCandidates};
                        private _point=_pair select (_moverIndex mod count _pair);
                        private _ranked=_candidates apply {
                            private _candidate=_positions select _x;
                            [(_point distance2D _candidate)+(abs (((getPosASL _point) select 2)-((AGLToASL _candidate) select 2))*2.5),_x]
                        };
                        _ranked sort true;
                        // Start an unentered lane in the model's interior-position order.
                        // Nearest Euclidean nodes can be windows behind a wall; they do not
                        // describe the native doorway route. Rank by distance only after a
                        // physical interior visit has established this lane's entry.
                        private _claimed=if (_entered) then {(_ranked select 0) select 1} else {
                            private _modelOrder=+_candidates;
                            _modelOrder sort true;
                            _modelOrder select 0
                        };
                        _pending deleteAt (_pending find _claimed);
                        _route pushBack _claimed;
                        _cursor=(count _route)-1;
                        _lastTarget=-1;
                        _retries=0;
                        _triedEntries=[];
                        // Keep this lane's chosen entrance between room claims. Re-select only
                        // when it has no valid entry; an entered lane must not rally outside again.
                        if ((_entryIndex < 0 || {_entryIndex >= count (_job get "entries")})
                            && {(_job get "entries") isNotEqualTo []}) then {
                            private _entryRanks=[];

                            {
                                _entryRanks pushBack [_point distance2D _x,_forEachIndex];
                            } forEach (_job get "entries");
                            _entryRanks sort true;
                            _entryIndex=(_entryRanks select 0) select 1;
                        };
                        // Let native interior planning choose its entrance for the first
                        // committed room. buildingExit nodes are recovery choices, not
                        // compulsory staging stops that can strand actors outside a wall.
                        _approachingEntry=false;
                    };
                };
                if (_cursor < count _route) then {
                    private _positionIndex=_route select _cursor;
                    private _entryTarget=if (_entryIndex >= 0 && {_entryIndex < count (_job get "entries")}) then {
                        (_job get "entries") select _entryIndex
                    } else {[]};
                    private _entryMover=_pair select (_moverIndex mod count _pair);
                    // Pair handoff may change the mover while an exterior approach is pending.
                    // A physically entered successor must retain interior progression, not
                    // inherit its buddy's entrance staging leg.
                    if (_approachingEntry && {_entryMover in (_job getOrDefault ["enteredActors",[]])}) then {
                        _approachingEntry=false;
                        _lastTarget=-1;
                    };
                    // The security partner deliberately holds outside the doorway. Its
                    // proximity cannot complete the assigned mover's physical approach.
                    if (_approachingEntry && {_entryTarget isNotEqualTo []}
                        && {_entryMover distance2D _entryTarget <= 3}
                        && {abs (((getPosASL _entryMover) select 2)-((AGLToASL _entryTarget) select 2)) <= 1.5}) then {
                        _approachingEntry=false;
                        // Reaching the entrance only completes approach staging. Interior entry
                        // is established by a physically visited room below, never doorway proximity.
                        _triedEntries pushBackUnique _entryIndex;
                        _lastTarget=-1;
                        _retries=0;
                    };
                    private _target=[_positions select _positionIndex,_entryTarget] select _approachingEntry;
                    private _point=_pair select (_moverIndex mod count _pair);
                    // Native building positions remain the room destinations. A geometry-supported
                    // offset can project onto another navigation floor; do not cache it as a route.
                    // Preserve a physically established interior route across mover changes.
                    // A ground-level partner should regain the pair's visited target-floor node
                    // before requesting its next room, rather than approaching an upstairs window.
                    // One checkpoint per claimed room; ordinary recovery still bounds the leg.
                    private _approaches=_job getOrDefault ["interiorApproaches",createHashMap];
                    private _approachKey=format ["%1:%2",_pairIndex,netId _point];
                    private _approach=_approaches getOrDefault [_approachKey,[]];
                    private _targetFloor=(AGLToASL _target) select 2;
                    private _pointFloor=(getPosASL _point) select 2;
                    if (!_approachingEntry && {_entered || {abs (_pointFloor-_targetFloor) > 1.5}}
                        && {(_approach param [0,-1]) != _positionIndex}) then {
                        // Retain actor-specific entry and vertical access history. An actor
                        // already inside on the destination floor need not revisit its buddy's
                        // occupied security node before requesting the next room.
                        private _chain=[];
                        private _ownVisits=(_job getOrDefault ["actorVisits",createHashMap]) getOrDefault [netId _point,[]];
                        if (_previousPositionIndex >= 0 && {_previousPositionIndex != _positionIndex}
                            && {!(_previousPositionIndex in _ownVisits)}
                            && {!(_point in (_job getOrDefault ["enteredActors",[]]))
                                || {abs (_pointFloor-_targetFloor) > 1.5}}) then {
                            _chain pushBack (+(_positions select _previousPositionIndex));
                        };
                        private _checkpoint=if (_previousPositionIndex >= 0 && {_previousPositionIndex != _positionIndex}) then {
                            _positions select _previousPositionIndex
                        } else {[]};
                        // Pair history may contain only ground-floor nodes although another
                        // lane has physically reached the destination floor. Share that access
                        // evidence instead of repeatedly approaching an upstairs window outside.
                        // Search once per changed coverage snapshot, at most 24 proven nodes.
                        private _probeKey=format ["%1:%2",_approachKey,_positionIndex];
                        private _probes=_job getOrDefault ["interiorAccessProbes",createHashMap];
                        if ((_checkpoint isEqualTo [] || {abs (((AGLToASL _checkpoint) select 2)-_targetFloor) > 1.5})
                            && {abs (_pointFloor-_targetFloor) > 1.5}
                            && {(_probes getOrDefault [_probeKey,-1]) != count _cleared}) then {
                            _probes set [_probeKey,count _cleared];
                            _job set ["interiorAccessProbes",_probes];
                            private _accessNodes=_cleared select [0,24];
                            private _nearest=1e12;
                            {
                                private _node=_positions select _x;
                                private _distance=_node vectorDistance _target;
                                if (_x != _positionIndex && {abs (((AGLToASL _node) select 2)-_targetFloor) <= 1.5}
                                    && {_distance < _nearest}) then {
                                    _checkpoint=+_node;
                                    _nearest=_distance;
                                };
                            } forEach _accessNodes;
                        };
                        // A target-floor balcony alone is not an access route. Candidate
                        // connectors start at an existing current-floor transit node, then
                        // the nearest native landing on the requested floor. No model map,
                        // synthetic coordinate or geometry-only room receipt is introduced.
                        // Preserve a physically visited destination-floor checkpoint selected
                        // above. A cached geometry candidate must not replace that evidence
                        // and send an entered actor back through an exterior source node.
                        private _provenFloorAccess=count _checkpoint == 3 && {
                            _cleared findIf {(_positions select _x) isEqualTo _checkpoint} >= 0
                        } && {abs (((AGLToASL _checkpoint) select 2)-_targetFloor) <= 1.5};
                        if (abs (_pointFloor-_targetFloor) > 1.5 && {!_provenFloorAccess}) then {
                            private _bridges=_job getOrDefault ["nativeFloorBridges",createHashMap];
                            // This runs only while constructing a changed room approach.
                            // A proven interior source prevents unnecessary exterior backtracking.
                            // Physical source access does not prove the next floor connection.
                            private _sourceRanks=[];
                            {
                                private _node=_positions select _x;
                                if (abs (((AGLToASL _node) select 2)-_pointFloor) <= 0.75) then {
                                    _sourceRanks pushBack [0,(getPosASL _point) vectorDistance (AGLToASL _node),+_node];
                                };
                            } forEach (_cleared select [0,24]);
                            {
                                if (abs (((AGLToASL _x) select 2)-_pointFloor) <= 0.75) then {
                                    _sourceRanks pushBack [1,(getPosASL _point) vectorDistance (AGLToASL _x),+_x];
                                };
                            } forEach ((_job getOrDefault ["transitPositions",[]]) select [0,32]);
                            _sourceRanks sort true;
                            private _sourceNode=if (_sourceRanks isNotEqualTo []) then {+((_sourceRanks select 0) select 2)} else {[]};
                            private _bridgeKey=str [_entryIndex,round (_pointFloor/1.5),round (_targetFloor/1.5),_sourceNode];
                            if (_targetFloor > _pointFloor+1.5 && {!(_bridgeKey in _bridges)} && {count _bridges < 8}) then {
                                private _bridge=[];
                                if (_sourceNode isNotEqualTo []) then {
                                    private _landingNodes=(_job getOrDefault ["navigationPositions",[]]) select [0,32];
                                    _landingNodes=_landingNodes select {abs (((AGLToASL _x) select 2)-_targetFloor) <= 0.75};
                                    private _landingRanks=_landingNodes apply {[_sourceNode vectorDistance _x,_x]};
                                    _landingRanks sort true;
                                    if (_landingRanks isNotEqualTo []) then {
                                        private _landing=+((_landingRanks select 0) select 1);
                                        // At most two support probes per new connector; eight
                                        // cached entrance/floor pairs per operation. Support is
                                        // only a candidate filter, never proof of a native route.
                                        private _supported={
                                            params ["_node"];
                                            private _origin=AGLToASL _node;
                                            private _surfaces=lineIntersectsSurfaces [_origin vectorAdd [0,0,0.5],_origin vectorAdd [0,0,-1],_point,objNull,true,4,"GEOM","NONE"];
                                            _surfaces findIf {((_x select 1) select 2) >= 0.7
                                                && {(_x select 2) == _building || {(_x select 3) == _building}}
                                                && {abs (((_x select 0) select 2)-(_origin select 2)) <= 0.75}} >= 0
                                        };
                                        if ([_sourceNode] call _supported && {[_landing] call _supported}) then {_bridge=[_sourceNode,_landing]};
                                    };
                                };
                                _bridges set [_bridgeKey,_bridge];
                                _job set ["nativeFloorBridges",_bridges];
                            };
                            private _bridge=_bridges getOrDefault [_bridgeKey,[]];
                            // Reuse a candidate connector in reverse for descent, rather than
                            // deriving a different route from an arbitrary upper balcony.
                            if (_targetFloor < _pointFloor-1.5) then {
                                private _reverseRanks=[];
                                {
                                    if (count _y == 2
                                        && {abs (((AGLToASL (_y select 1)) select 2)-_pointFloor) <= 0.75}
                                        && {abs (((AGLToASL (_y select 0)) select 2)-_targetFloor) <= 0.75}) then {
                                        _reverseRanks pushBack [(getPosASL _point) vectorDistance (AGLToASL (_y select 1)),[_y select 1,_y select 0]];
                                    };
                                } forEach _bridges;
                                _reverseRanks sort true;
                                if (_reverseRanks isNotEqualTo []) then {_bridge=+((_reverseRanks select 0) select 1)};
                            };
                            if (count _bridge == 2) then {
                                _chain=[+(_bridge select 0)];
                                _checkpoint=+(_bridge select 1);
                                diag_log format ["WAIT CLEAR FLOOR CONNECTOR CANDIDATE: %1",[_job get "generation",_pairIndex,netId _point,_positionIndex,+_bridge]];
                            };
                        };
                        // Exposed balconies/access positions are not rooms, but removing them
                        // from the coverage set must not erase possible native floor access.
                        // Use a supported transit candidate only when no visited same-floor access
                        // is available. Probe each floor bucket once.
                        if (abs (_pointFloor-_targetFloor) > 1.5
                            && {_checkpoint isEqualTo [] || {abs (((AGLToASL _checkpoint) select 2)-_targetFloor) > 1.5}}) then {
                            private _floorKey=str round (_targetFloor*2);
                            private _accessCache=_job getOrDefault ["transitAccessCache",createHashMap];
                            if (!(_floorKey in _accessCache) && {count _accessCache < 8}) then {
                                private _access=[];
                                private _transit=(_job getOrDefault ["transitPositions",[]]) select [0,32];
                                {
                                    if (_access isNotEqualTo []) exitWith {};
                                    if (abs (((AGLToASL _x) select 2)-_targetFloor) <= 0.75) then {
                                        private _origin=AGLToASL _x;
                                        private _surfaces=lineIntersectsSurfaces [_origin vectorAdd [0,0,0.5],_origin vectorAdd [0,0,-1],_point,objNull,true,4,"GEOM","NONE"];
                                        private _supported=_surfaces findIf {
                                            ((_x select 1) select 2) >= 0.7
                                                && {(_x select 2) == _building || {(_x select 3) == _building}}
                                                && {abs (((_x select 0) select 2)-(_origin select 2)) <= 0.75}
                                        } >= 0;
                                        if (_supported) then {_access=+_x};
                                    };
                                } forEach _transit;
                                _accessCache set [_floorKey,_access];
                                _job set ["transitAccessCache",_accessCache];
                            };
                            private _access=_accessCache getOrDefault [_floorKey,[]];
                            if (_access isNotEqualTo []) then {_checkpoint=+_access};
                        };
                        if (abs (_pointFloor-_targetFloor) > 1.5
                            && {count _checkpoint == 3}
                            && {abs (((AGLToASL _checkpoint) select 2)-_targetFloor) <= 1.5}) then {
                            _chain pushBackUnique (+_checkpoint);
                        };
                        // At most two legs: the preceding covered node, then destination-floor
                        // access. Neither leg marks the assigned room visited.
                        if (_chain isNotEqualTo []) then {
                            private _first=_chain deleteAt 0;
                            _approach=[_positionIndex,+_first,false,_chain];
                            _approaches set [_approachKey,_approach];
                            _job set ["interiorApproaches",_approaches];
                            _lastTarget=-1;
                            diag_log format ["WAIT CLEAR INTERIOR ACCESS: %1",[_job get "generation",_pairIndex,netId _point,_positionIndex,+_first,+_target,+_chain]];
                        };
                    };
                    // A supported raw access point is a candidate, not a proven native route.
                    // Retire one stalled optional raw checkpoint for this actor/room claim,
                    // then let the original room request use the same movement writer.
                    // Covered buddy handoffs remain mandatory; no visit or progress lease
                    // is granted for retirement, and the existing retry count is preserved.
                    private _checkpointCommand=currentCommand _point;
                    private _checkpointDelay=[12,4] select (_checkpointCommand == "" || {_checkpointCommand == "STOP"});
                    private _checkpointCandidate=_approach param [1,[],[[]]];
                    private _checkpointReached=count _checkpointCandidate == 3
                        && {(getPosASL _point) vectorDistance (AGLToASL _checkpointCandidate) <= 1.5}
                        && {abs (((getPosASL _point) select 2)-((AGLToASL _checkpointCandidate) select 2)) <= 0.75}
                        && {!([_point] call _activeOwnMove)};
                    private _fallbackHold=(_job getOrDefault ["formationFallbackHolds",createHashMap]) getOrDefault [netId _point,[]];
                    private _issuedCheckpoint=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _point,[]];
                    private _ownedCheckpointStop=_checkpointCommand == "STOP" && {count _fallbackHold == 3}
                        && {_issuedCheckpoint isEqualTo _checkpointCandidate}
                        && {(getPosASL _point) vectorDistance (AGLToASL _fallbackHold) <= 1.5};
                    if (!_approachingEntry && {count _approach >= 3}
                        && {(_approach select 0) == _positionIndex} && {!(_approach select 2)}
                        && {(_approach select 1) in (_job getOrDefault ["transitPositions",[]])}
                        && {!_checkpointReached} && {_now-_lastProgress > _checkpointDelay}
                        && {[_point] call _actorAvailable} && {[_point] call _actorTaskFree}
                        && {_checkpointCommand == "" || {_checkpointCommand == "MOVE" && {[_point] call _ownsCurrentMove}} || {_ownedCheckpointStop}}
                        && {!([_group,false,_point] call WAIT_fnc_CortexExternalTakeover)}
                        && {call _mayIssueMovement}) then {
                        private _retired=+(_approach select 1);
                        // This tombstone prevents immediate recreation for the same claim.
                        // Its arrival flag stays false: an abandoned point was not visited.
                        _approach=[_positionIndex,[],false,[],"ABANDONED_TRANSIT"];
                        _approaches set [_approachKey,_approach];
                        _job set ["interiorApproaches",_approaches];
                        _lastTarget=-1;
                        diag_log format ["WAIT CLEAR TRANSIT RETIRED: %1",[_job get "generation",_pairIndex,netId _point,_positionIndex,_retired,+_target]];
                    };
                    if (!_approachingEntry && {count _approach >= 3}
                        && {(_approach select 0) == _positionIndex} && {!(_approach select 2)}
                        && {count (_approach select 1) == 3}) then {
                        private _checkpoint=_approach select 1;
                        if ((getPosASL _point) vectorDistance (AGLToASL _checkpoint) <= 1.5
                            && {abs (((getPosASL _point) select 2)-((AGLToASL _checkpoint) select 2)) <= 0.75}
                            && {!([_point] call _activeOwnMove)}) then {
                            private _remaining=_approach param [3,[]];
                            if (_remaining isEqualTo []) then {
                                _approach set [2,true];
                            } else {
                                private _next=_remaining deleteAt 0;
                                _approach set [1,+_next];
                                _approach set [3,_remaining];
                                _target=+_next;
                            };
                            _lastTarget=-1;
                            _retries=0;
                            _lastProgress=_now;
                        } else {
                            _target=+_checkpoint;
                        };
                    };
                    private _issue=_lastTarget != _positionIndex;
                    private _bestDistance=_state param [13,1e12,[0]];
                    private _bestTarget=_state param [14,[],[[]]];
                    if (_bestTarget isNotEqualTo _target) then {
                        _bestTarget=+_target;
                        _bestDistance=(getPosATL _point) vectorDistance _target;
                    };
                    private _supportTarget=[];
                    private _partner=_pair select ((_moverIndex+1) mod count _pair);
                    private _partnerEntered=_partner in (_job getOrDefault ["enteredActors",[]]);
                    if (count _pair > 1 && {!_partnerEntered} && {!_approachingEntry}) then {
                        // Commit both actors at initial entry. Select a nearby same-floor node
                        // connected by clear interior geometry, rather than holding outside until a visit.
                        private _entryTargets=_job getOrDefault ["pairEntryTargets",createHashMap];
                        private _entryKey=str _pairIndex;
                        _supportTarget=_entryTargets getOrDefault [_entryKey,[]];
                        if (_supportTarget isEqualTo []) then {
                            private _anchor=_positions select (_route select 0);
                            private _candidates=_positions select {
                                _x isNotEqualTo _anchor && {abs (((AGLToASL _x) select 2)-((AGLToASL _anchor) select 2)) <= 1.5}
                                    && {_x distance2D _anchor >= 1.2} && {_x distance2D _anchor <= 8}
                            };
                            private _occupied=[[_partner]] call _occupiedRoomTargets;
                            // Prefer non-conflicting native nodes, but keep blocked alternatives
                            // behind them when the free nodes have no clear interior connection.
                            private _freeCandidates=_candidates select {
                                !([_x,_occupied] call _roomTargetOccupied)
                            };
                            private _busyCandidates=_candidates-_freeCandidates;
                            // Wider native nodes remain preferred. A compact interior may have no
                            // 2.5m-separated point; try its distinct >=1.2m native nodes before
                            // falling back to the lead's exact entry destination. No offsets.
                            private _entryRank={
                                params ["_node"];
                                private _distance=_node distance2D _anchor;
                                [_distance+([10,0] select (_distance >= 2.5)),_node]
                            };
                            private _freeRanks=_freeCandidates apply {[_x] call _entryRank};
                            private _busyRanks=_busyCandidates apply {[_x] call _entryRank};
                            _freeRanks sort true;
                            _busyRanks sort true;
                            private _ranked=_freeRanks+_busyRanks;
                            _ranked resize ((count _ranked) min 24);
                            private _origin=(AGLToASL _anchor) vectorAdd [0,0,0.8];
                            private _connected=_ranked findIf {
                                (lineIntersectsSurfaces [_origin,(AGLToASL (_x select 1)) vectorAdd [0,0,0.8],objNull,objNull,true,1,"GEOM","NONE"]) isEqualTo []
                            };
                            _supportTarget=if (_connected >= 0) then {+((_ranked select _connected) select 1)} else {+_anchor};
                            _entryTargets set [_entryKey,+_supportTarget];
                            _job set ["pairEntryTargets",_entryTargets];
                        };
                    };
                    if (_supportTarget isEqualTo (_positions select (_route select 0))) then {
                        _supportTarget=[_route select 0] call _roomMovementPoint;
                    };
                    if (count _pair > 1 && {_supportTarget isEqualTo []}) then {
                        _supportTarget=if (_approachingEntry) then {
                            private _outward=(getPosATL (_job get "building")) getDir _entryTarget;
                            _entryTarget getPos [3,_outward]
                        } else {
                            if (_previousPositionIndex >= 0) then {[_previousPositionIndex] call _roomMovementPoint} else {
                                if (_entryTarget isEqualTo [] || {_entered}) then {_target} else {
                                    // Keep first-room security clear of the threshold. Standing on
                                    // the entrance can physically block the partner's only path inside.
                                    private _outward=(getPosATL (_job get "building")) getDir _entryTarget;
                                    _entryTarget getPos [3,_outward+60]
                                }
                            }
                        };
                        if (_supportTarget isEqualTo []) then {
                            private _outward=(getPosATL (_job get "building")) getDir _target;
                            _supportTarget=_target getPos [2.5,_outward];
                        };
                    };
                    // A covered handoff cannot ask the mover to occupy the stationary
                    // buddy's exact checkpoint. Keep security on a distinct proven node,
                    // without inventing offsets inside walls or recalling exterior actors.
                    private _legStart=getPosASL _point;
                    private _legEnd=AGLToASL _target;
                    private _supportPose=getPosASL _partner;
                    private _blocksLeg={
                        params ["_pose"];
                        private _axis=_legEnd vectorDiff _legStart;
                        private _lengthSquared=_axis vectorDotProduct _axis;
                        if (_lengthSquared < 0.01) exitWith {false};
                        private _fraction=((_pose vectorDiff _legStart) vectorDotProduct _axis)/_lengthSquared;
                        _fraction > 0 && {_fraction < 1}
                            && {_pose vectorDistance (_legStart vectorAdd (_axis vectorMultiply _fraction)) < 1.2}
                    };
                    // Actual stationary bodies can obstruct a visible approach even when
                    // their destination is far from the mover's target. Wall-crossing straight
                    // lines are not native-route evidence and cannot authorize this yield.
                    private _partnerBlocksApproach=count _pair > 1 && {_partnerEntered} && {!_approachingEntry}
                        && {currentCommand _partner == "STOP"}
                        && {[_supportPose] call _blocksLeg}
                        && {[_point,_legEnd] call _roomSegmentClear};
                    private _routeContext=[+_legStart,+_supportPose];
                    if (count _pair > 1 && {_partnerEntered} && {!_approachingEntry}
                        && {count _supportTarget == 3}
                        && {_supportTarget vectorDistance _target < 2.5 || {_partnerBlocksApproach}}) then {
                        private _separations=_job getOrDefault ["pairSupportSeparation",createHashMap];
                        private _separationKey=netId _partner;
                        private _separation=_separations getOrDefault [_separationKey,[]];
                        private _otherTargets=[];
                        {
                            private _otherActor=objectFromNetId _x;
                            // Issued destinations are history, not permanent reservations.
                            // Keep an actual owned approach or physically occupied node; a
                            // dead, removed or handed-over actor cannot lock it indefinitely.
                            if (_x != netId _partner && {!isNull _otherActor} && {alive _otherActor}
                                && {group _otherActor == _group} && {count _y == 3}
                                && {[_otherActor] call _ownsCurrentMove
                                    || {(getPosASL _otherActor) vectorDistance (AGLToASL _y) < 2.5}}) then {
                                _otherTargets pushBack (+_y);
                            };
                        } forEach (_job getOrDefault ["movementTargets",createHashMap]);
                        if (count _separation != 5 || {(_separation select 0) isNotEqualTo _target}
                            || {(_separation select 1) != count _cleared}
                            || {(_separation select 3) isNotEqualTo _otherTargets}
                            || {(_separation select 2) isEqualTo [] && {(_separation select 4) isNotEqualTo _routeContext}}
                            || {(_separation select 2) isNotEqualTo [] && {[AGLToASL (_separation select 2)] call _blocksLeg}}) then {
                            private _partnerPose=getPosASL _partner;
                            private _ranked=[];
                            {
                                private _candidate=_positions select _x;
                                private _candidateASL=AGLToASL _candidate;
                                if (_candidate vectorDistance _target >= 2.5
                                    && {abs ((_candidateASL select 2)-(_partnerPose select 2)) <= 0.75}
                                    && {_candidateASL vectorDistance _partnerPose <= 8}
                                    && {!([_candidateASL] call _blocksLeg)}
                                    && {_otherTargets findIf {count _x == 3 && {_x vectorDistance _candidate < 2.5}} < 0}) then {
                                    _ranked pushBack [_candidateASL vectorDistance _partnerPose,+_candidate];
                                };
                            } forEach (_cleared select [0,24]);
                            _ranked sort true;
                            private _separate=if (_ranked isNotEqualTo []) then {+((_ranked select 0) select 1)} else {[]};
                            // A current physical interior hold may already be clear of the mover.
                            if (_separate isEqualTo [] && {insideBuilding _partner > 0}
                                && {_partnerPose vectorDistance (AGLToASL _target) >= 2.5}
                                && {!([_partnerPose] call _blocksLeg)}) then {
                                _separate=getPosATL _partner;
                            };
                            _separation=[+_target,count _cleared,+_separate,+_otherTargets,+_routeContext];
                            _separations set [_separationKey,_separation];
                            _job set ["pairSupportSeparation",_separations];
                            diag_log format ["WAIT CLEAR SUPPORT SEPARATION: %1",[_job get "generation",_pairIndex,netId _point,netId _partner,+_target,+_separate]];
                        };
                        if ((_separation select 2) isNotEqualTo []) then {
                            _supportTarget=+(_separation select 2);
                            private _partnerCommitted=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _partner,[]];
                            if (_partnerCommitted isNotEqualTo _supportTarget) then {_issue=true};
                        };
                    };
                    {
                        private _unit=_x;
                        // Alternate entrance recovery belongs to exterior actors only. A
                        // physically entered buddy retains its current interior order and hold.
                        private _entryWorkerAllowed=!_approachingEntry || {_unit == _point}
                            || {!(_unit in (_job getOrDefault ["enteredActors",[]]))};
                        if (_entryWorkerAllowed) then {
                        // Opening a door does not replace an already committed native path.
                        [_unit,_job get "building",["CLEAR",_job get "generation"]] call WAIT_fnc_CortexBuildingDoor;
                        if (_issue && {call _mayIssueMovement} && {[_unit] call _actorTaskFree}) then {
                            private _started=_job get "started";
                            if !(_unit in _started) then {
                                doStop _unit;
                                // Preserve the original baseline across owner-local worker rebuilds.
                                // A later different setting becomes the new baseline, not old WAIT state.
                                private _priorStance=_unit getVariable ["WAIT_Cortex_ClearStance",unitPos _unit];
                                if (toUpperANSI (unitPos _unit) != "UP") then {_priorStance=unitPos _unit};
                                private _priorSpeed=_unit getVariable ["WAIT_Cortex_ClearForcedSpeed",getForcedSpeed _unit];
                                if (abs ((getForcedSpeed _unit)-(_unit getVariable ["WAIT_Cortex_ClearAppliedSpeed",getForcedSpeed _unit])) > 0.1) then {
                                    _priorSpeed=getForcedSpeed _unit;
                                };
                                _unit setVariable ["WAIT_Cortex_ClearStance",_priorStance,true];
                                _unit setVariable ["WAIT_Cortex_ClearForcedSpeed",_priorSpeed,true];
                                _unit setUnitPos "UP";
                                private _clearSpeed=4;
                                _unit setVariable ["WAIT_Cortex_ClearAppliedSpeed",_clearSpeed,true];
                                _unit forceSpeed _clearSpeed;
                                _started pushBack _unit;
                            };
                            private _unitTarget=if (_unit == _point || {_supportTarget isEqualTo []}) then {_target} else {_supportTarget};
                            private _committedTarget=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _unit,[]];
                            private _sameActiveTarget=count _committedTarget == 3
                                && {_committedTarget vectorDistance _unitTarget <= 0.25}
                                && {[_unit] call _activeOwnMove};
                            if (!_sameActiveTarget && {call _mayIssueMovement} && {[_unit] call _actorTaskFree}) then {
                                // An unchanged active path or support hold already satisfies this handoff.
                                if (((_job getOrDefault ["roomHolds",createHashMap]) getOrDefault [netId _unit,[]]) isNotEqualTo _unitTarget
                                    || {currentCommand _unit != "STOP"}
                                    || {(getPosASL _unit) vectorDistance (AGLToASL _unitTarget) > 1.5}) then {
                                    _unit doMove _unitTarget;
                                    [_unit,_unitTarget] call _rememberMove;
                                };
                            };
                        };
                        // Slow the final indoor approach without replacing its destination.
                        // Update only our unchanged cap; an externally edited speed remains owned
                        // by that controller. Distance checks reuse the existing bounded pair step.
                        if (_unit in (_job get "started") && {call _mayIssueMovement}
                            && {[_unit] call _actorAvailable} && {[_unit] call _actorTaskFree}) then {
                            private _speedTarget=if (_unit == _point || {_supportTarget isEqualTo []}) then {_target} else {_supportTarget};
                            private _applied=_unit getVariable ["WAIT_Cortex_ClearAppliedSpeed",-1];
                            private _desiredSpeed=[4,2] select (_unit distance2D _speedTarget < 5);
                            if (abs ((getForcedSpeed _unit)-_applied) <= 0.1
                                && {abs (_desiredSpeed-_applied) > 0.1}) then {
                                _unit forceSpeed _desiredSpeed;
                                _unit setVariable ["WAIT_Cortex_ClearAppliedSpeed",_desiredSpeed,true];
                            };
                            // A failed native path can silently return a worker to formation:
                            // command becomes empty and the planner reports its
                            // formation destination (planned or direct formation mode). Arrest that fallback once per owned request;
                            // the existing finite room retry is still the only recovery writer.
                            // Do not touch explicit FOLLOW, a newer MOVE or specialist commands.
                            private _nativeDestination=expectedDestination _unit;
                            private _fallbackHolds=_job getOrDefault ["formationFallbackHolds",createHashMap];
                            private _issued=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _unit,[]];
                            if (!_issue && {currentCommand _unit == ""}
                                && {(_nativeDestination param [1,"",[""]]) in ["DoNotPlanFormation","FORMATION PLANNED"]}
                                && {count _issued == 3} && {!(netId _unit in _fallbackHolds)}) then {
                                private _hold=getPosATL _unit;
                                doStop _unit;
                                _fallbackHolds set [netId _unit,+_hold];
                                _job set ["formationFallbackHolds",_fallbackHolds];
                            };
                            // Native formation must not reclaim a physically arrived room or
                            // support actor between pair handoffs. Hold once per target; a new
                            // room request replaces it through the existing movement writer.
                            private _roomHolds=_job getOrDefault ["roomHolds",createHashMap];
                            private _holdKey=netId _unit;
                            if ((_roomHolds getOrDefault [_holdKey,[]]) isNotEqualTo _speedTarget
                                && {(getPosASL _unit) vectorDistance (AGLToASL _speedTarget) <= 1.5}
                                && {abs (((getPosASL _unit) select 2)-((AGLToASL _speedTarget) select 2)) <= 0.75}
                                && {[_unit,AGLToASL _speedTarget] call _roomSegmentClear}
                                && {currentCommand _unit != "MOVE" || {[_unit] call _ownsCurrentMove}}
                                && {!([_unit] call _activeOwnMove)}) then {
                                doStop _unit;
                                _roomHolds set [_holdKey,+_speedTarget];
                                _job set ["roomHolds",_roomHolds];
                            };
                        };
                        _assigned set [(_job get "team") find _unit,[_positionIndex,_lastProgress,getPosATL _unit,_retries,_approachingEntry]];
                        };
                    } forEach _pair;
                    if (_issue) then {_lastTarget=_positionIndex; _lastProgress=_now; _lastPositions=_pair apply {getPosATL _x}};
                    // Once inside, only the assigned room mover proves progress toward this room.
                    // The security partner is expected to adjust cover and follow the previous room;
                    // counting that movement hid doorway stalls and prevented recovery indefinitely.
                    private _moverSlot=_moverIndex mod count _pair;
                    private _moverPrevious=_lastPositions param [_moverSlot,getPosATL _point];
                    private _moved=(getPosATL _point) vectorDistance _moverPrevious >= 1;
                    if (_approachingEntry && {!_moved}) then {
                        _moved=_pair findIf {
                            private _old=_lastPositions param [_forEachIndex,getPosATL _x];
                            (getPosATL _x) vectorDistance _old >= 1
                        } >= 0;
                    };
                    if (_moved) then {
                        _lastPositions=_pair apply {getPosATL _x};
                        // Walking can be legitimate navigation without approaching this node.
                        // Only new best approach progress renews retry and operation budgets;
                        // circles must eventually reach the bounded retry/recovery path.
                        private _targetDistance=(getPosATL _point) vectorDistance _target;
                        if (_bestDistance-_targetDistance >= 1) then {
                            _bestDistance=_targetDistance;
                            _lastProgress=_now;
                            _job set ["lastProgressAt",serverTime];
                            _job set ["deadline",(_job get "deadline") max (serverTime+120)];
                        };
                    };
                    if (_positionIndex in _cleared && {_laneEntered} && {!([_point] call _activeOwnMove)}) then {
                        _entered=true;
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
                        if (_now-_lastProgress > _retryDelay && {[_point] call _actorTaskFree}) then {
                            if (_retries < 3 && {call _mayIssueMovement}) then {
                                {
                                    private _unitTarget=if (_x == _point || {_supportTarget isEqualTo []}) then {_target} else {_supportTarget};
                                    // Interior recovery belongs to the room mover. Keep the security
                                    // partner at its committed position instead of restarting its path.
                                    if ((_x == _point || {_approachingEntry && {!(_x in (_job getOrDefault ["enteredActors",[]]))}}) && {[_x] call _actorAvailable}
                                        && {call _mayIssueMovement} && {[_x] call _actorTaskFree}) then {
                                        _x doMove _unitTarget;
                                        [_x,_unitTarget] call _rememberMove;
                                    };
                                } forEach _pair;
                                _retries=_retries+1;
                                _lastProgress=_now;
                                _retryCounts set [_positionIndex,(_retryCounts param [_positionIndex,0])+1];
                            } else {
                                // An interior access leg already owns this destination. Exterior
                                // entrance cycling would retain the same failed checkpoint while
                                // resetting its local retry clock. Exhaust its existing recovery
                                // first, then retire it once and request the assigned room directly.
                                private _recoverAccess=!_approachingEntry && {count _approach >= 3}
                                    && {(_approach select 0) == _positionIndex}
                                    && {count (_approach select 1) == 3} && {!(_approach select 2)};
                                private _changedEntry=false;
                                if (!_recoverAccess && {!(_point in (_job getOrDefault ["enteredActors",[]]))}
                                    && {(_job get "entries") isNotEqualTo []}) then {
                                    if (_approachingEntry) then {_triedEntries pushBackUnique _entryIndex};
                                    private _entryRanks=[];

                                    {
                                        if !(_forEachIndex in _triedEntries) then {
                                            _entryRanks pushBack [_point distance2D _x,_forEachIndex];
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
                                    // Durable room retries survive reserve replacement and owner replay.
                                    // A new actor must not reopen an exhausted room recovery budget.
                                    private _roomRetryBudget=3*_failureThreshold;
                                    private _recovery = if (_operationGeneration >= 0
                                        && {(_retryCounts param [_positionIndex,0]) <= _roomRetryBudget}) then {
                                        [_group,_operationGeneration,_point,_target] call WAIT_fnc_RecoveryStep
                                    } else {"EXHAUSTED"};
                                    if (_recovery in ["RECOVERING","YIELDED"]) then {
                                        if (_recovery == "RECOVERING") then {[_point,_target] call _rememberMove};
                                        _lastProgress=_now;
                                        _lastPositions=_pair apply {getPosATL _x};
                                        // A native task owns movement while yielding. Do not restart
                                        // its route or mark the room unreachable during that task.
                                        _retries=[0,3] select (_recovery == "YIELDED");
                                    } else {
                                        private _failedCheckpoint=!_approachingEntry && {count _approach >= 3}
                                            && {(_approach select 0) == _positionIndex}
                                            && {count (_approach select 1) == 3}
                                            && {!(_approach select 2)};
                                        if (_failedCheckpoint) then {
                                            // A failed access leg is not a failed room request.
                                            // Retire it once; this claim-scoped tombstone prevents
                                            // recreation. Existing room counts and deadlines remain.
                                            _approach=[_positionIndex,[],false,[],"ABANDONED_ACCESS"];
                                            _approaches set [_approachKey,_approach];
                                            _job set ["interiorApproaches",_approaches];
                                            _lastTarget=-1;
                                            _retries=0;
                                            _lastProgress=_now;
                                            diag_log format ["WAIT CLEAR ACCESS RECOVERY EXHAUSTED: %1",[
                                                _job get "generation",_pairIndex,netId _point,
                                                _positionIndex,+_target,+(_positions select _positionIndex)]];
                                        } else {
                                        private _pairId=format ["PAIR_%1",_pairIndex];
                                        private _failures=_failedBy select _positionIndex;
                                        _failures pushBackUnique _pairId;
                                        _failedBy set [_positionIndex,_failures];
                                        // A failed entry lane cannot undo another worker's physical room visit.
                                        if (count _failures >= _failureThreshold && {!(_positionIndex in _cleared)}) then {
                                            if !(_positionIndex in _unreachable) then {
                                                // A configured building point is only a candidate. Preserve the
                                                // actual failed request without calling it physically cleared or
                                                // claiming that controller/path failure proves bad model geometry.
                                                diag_log format ["WAIT CLEAR ROOM RETRY EXHAUSTED: %1",[
                                                    _job get "generation",typeOf (_job get "building"),
                                                    netId (_job get "building"),_positionIndex,+_target,
                                                    _retryCounts param [_positionIndex,0],+_failures,
                                                    netId _point,getPosASL _point,currentCommand _point,
                                                    expectedDestination _point,unitReady _point,
                                                    _point checkAIFeature "MOVE",_point checkAIFeature "PATH"]];
                                            };
                                            _unreachable pushBackUnique _positionIndex;
                                        } else {
                                            // Return the room to the shared queue. Another pair must claim it;
                                            // this pair's failure identity prevents an immediate self-retry loop.
                                            if !(_positionIndex in _cleared) then {(_job get "pending") pushBackUnique _positionIndex};
                                        };
                                        _cursor=_cursor+1;
                                        _lastTarget=-1;
                                        _retries=0;
                                        _triedEntries=[];
                                        };
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
                    _state set [13,_bestDistance]; _state set [14,_bestTarget];
                };
            };
        };
    } forEach _pairs;
    private _madeProgress=count _cleared != _before || {count _unreachable != _unreachableBefore};
    if (_pairStates findIf {_x param [12,false]} >= 0 && {(_job getOrDefault ["phase","ENTRY"]) == "ENTRY"}) then {_job set ["phase","SWEEP"]};
    if (_madeProgress) then {_job set ["phase","SWEEP"]} else {if (_retryChanged) then {_job set ["phase","REPLAN"]}};
    if (count _cleared != _before) then {
        // Physical room visits renew the safety lease. An unreachable classification advances
        // the finite queue but is not successful physical progress and cannot extend its budget.
        _job set ["lastProgressAt",serverTime];
        _job set ["deadline",(_job get "deadline") max (serverTime+120)];
    };
    if (_madeProgress || {_retryChanged}) then {
        _group setVariable ["WAIT_AIPass_ClearOrder", [_job get "building", +_cleared, _job get "deadline", _job get "baseBehaviour", +_unreachable, +_retryCounts, +_failedBy, _job get "lastProgressAt",_job getOrDefault ["baseAttack",true],_job getOrDefault ["nativeOrderReceipt",[]],_job getOrDefault ["hardDeadline",_job get "deadline"],_job getOrDefault ["contactBelief",[]],_job getOrDefault ["continueRoute",false]], true];
        _group setVariable ["WAIT_Cortex_ClearStatus",[_job getOrDefault ["phase","SWEEP"],count _cleared,count _unreachable,count (_job get "positions"),count (_job get "pairs"),_job get "lastProgressAt"],true];
    };
    private _allWorkersEntered=_activeWorkers findIf {!(_x in (_job getOrDefault ["enteredActors",[]]))} < 0;
    private _actorVisits=_job getOrDefault ["actorVisits",createHashMap];
    private _requiredVisits=2 min count _positions;
    private _allWorkersProgressed=_activeWorkers findIf {
        count (_actorVisits getOrDefault [netId _x,[]]) < _requiredVisits
    } < 0;
    // Shared room coverage must not release a partner still parked at its first node.
    // Finish each active actor's finite interior follow-through before successful egress.
    if (count _cleared == count _positions && {!_allWorkersProgressed}
        && {serverTime <= (_job get "deadline")}
        && {serverTime <= (_job getOrDefault ["hardDeadline",_job get "deadline"])}
        && {call _mayIssueMovement}) then {
        private _follow=_job getOrDefault ["followThrough",createHashMap];
        private _followFailures=_job getOrDefault ["followThroughFailures",createHashMap];
        private _followExhausted=_job getOrDefault ["followThroughExhausted",[]];
        private _followBudgetChanged=false;
        private _followReservations=[];
        private _followReservationsReady=false;
        // One completed worker may yield per callback, once per original episode.
        // The public attempt receipt survives locality adoption without renewing deadlines.
        private _yieldReceipt=_group getVariable ["WAIT_Cortex_ClearYield",[]];
        private _yieldContext=[_job get "building",_job get "buildingTransform",_job get "hardDeadline"];
        private _yielded=if (count _yieldReceipt == 4 && {(_yieldReceipt select [0,3]) isEqualTo _yieldContext}) then {
            +(_yieldReceipt select 3)
        } else {[]};
        private _yieldConsidered=false;
        {
            private _unit=_x;
            private _key=netId _unit;
            if (_key in _earlyExits) then {continue};
            private _visited=_actorVisits getOrDefault [_key,[]];
            private _arrived=_follow getOrDefault [_key,[]];
            if (_arrived isNotEqualTo [] && {(_arrived select 0) in _visited}
                && {!(_arrived param [4,false,[true]])} && {[_unit] call _actorAvailable}
                && {[_unit] call _actorTaskFree} && {call _mayIssueMovement}
                && {currentCommand _unit != "MOVE" || {[_unit] call _ownsCurrentMove}}
                && {!([_unit] call _activeOwnMove)}
                // A yield can revisit a historical node; that old visit cannot stop its new leg.
                && {(getPosASL _unit) vectorDistance (AGLToASL (_positions select (_arrived select 0))) <= 1.5}
                && {[_unit,AGLToASL (_positions select (_arrived select 0))] call _roomSegmentClear}
            ) then {
                doStop _unit;
                _arrived set [4,true];
            };
            // Keep an unentered actor's useful entry path intact. Once its one-shot entry
            // recovery has made no progress for 24 seconds, shared physical coverage offers
            // alternative native anchors. These use the same durable three-target budget;
            // choosing another destination never invents entry or renews common recovery.
            private _entryReceipt=(_job getOrDefault ["entryRecovery",createHashMap]) getOrDefault [_key,[]];
            private _entryExhausted=count _entryReceipt >= 3 && {_entryReceipt select 2}
                && {_now-(_entryReceipt select 1) >= 24};
            if (count _visited < _requiredVisits && {!(_unit in _followExhausted)}
                && {_unit in (_job getOrDefault ["enteredActors",[]]) || {_entryExhausted}}
                && {[_unit] call _actorAvailable}
                && {[_unit] call _actorTaskFree} && {call _mayIssueMovement}) then {
                private _record=_follow getOrDefault [_key,[]];
                if (_record isEqualTo [] || {(_record select 0) in _visited}) then {
                    // Select once per actual visit; native planning still owns the path.
                    // Prefer the current floor without inventing a building-specific route.
                    private _failedTargets=_followFailures getOrDefault [_key,[]];
                    private _candidates=if (count _failedTargets >= 3) then {[]} else {
                        (_cleared select {!(_x in _visited) && {!(_x in _failedTargets)}}) select [0,24]
                    };
                    // Snapshot only when an actor actually needs a new target. Physical
                    // bodies remain obstacles; historical destinations reserve nothing unless
                    // their native MOVE still belongs to this operation.
                    if (_candidates isNotEqualTo [] && {!_followReservationsReady}) then {
                        {
                            private _actor=_x;
                            private _ownedTarget=[];
                            if ([_actor] call _ownsCurrentMove) then {
                                _ownedTarget=AGLToASL ((_job get "movementTargets") get (netId _actor));
                            };
                            _followReservations pushBack [netId _actor,getPosASL _actor,_ownedTarget];
                        } forEach (_activeWorkers select [0,8]);
                        _followReservationsReady=true;
                    };
                    private _unitFloor=(getPosASL _unit) select 2;
                    private _ranked=_candidates apply {
                        private _position=_positions select _x;
                        private _positionASL=AGLToASL _position;
                        private _occupied=_followReservations findIf {
                            (_x select 0) != _key && {
                                (_x select 1) vectorDistance _positionASL < 1.5
                                || {(_x select 2) isNotEqualTo []
                                    && {(_x select 2) vectorDistance _positionASL < 1.5}}
                            }
                        } >= 0;
                        // A free visited destination outranks a blocked same-floor node.
                        // Floor preference only breaks ties after live occupancy/reservations.
                        [[0,1] select _occupied,
                            [0,1] select (abs (_unitFloor-(_positionASL select 2)) > 1.5),
                            (getPosASL _unit) vectorDistance _positionASL,_x]
                    };
                    _ranked sort true;
                    if (_ranked isNotEqualTo [] && {((_ranked select 0) select 0) == 1}) then {
                        // Every destination is occupied. Do not spend a path/recovery attempt
                        // by ordering another actor into the same body or reserved destination.
                        // A completed, still-owned room holder can vacate into shared visited
                        // space which no unfinished participant needs for its remaining visits.
                        if (!_yieldConsidered) then {
                            _yieldConsidered=true;
                            private _blockedASL=AGLToASL (_positions select ((_ranked select 0) select 3));
                            private _blockers=_activeWorkers select {
                                _x != _unit && {!(netId _x in _yielded)}
                                    && {count (_actorVisits getOrDefault [netId _x,[]]) >= _requiredVisits}
                                    && {(getPosASL _x) vectorDistance _blockedASL < 1.5}
                                    && {currentCommand _x in ["","STOP"]}
                                    && {[_x] call _actorTaskFree} && {[_x] call _actorAvailable}
                                    && {netId _x in (_job getOrDefault ["roomHolds",createHashMap])
                                        || {(_follow getOrDefault [netId _x,[]]) param [4,false,[true]]}}
                            };
                            if (_blockers isNotEqualTo []) then {
                                private _cursor=_job getOrDefault ["followYieldCursor",0];
                                private _blocker=_blockers select (_cursor mod count _blockers);
                                _job set ["followYieldCursor",_cursor+1];
                                private _blockerKey=netId _blocker;
                                private _needed=[];
                                {
                                    private _visits=_actorVisits getOrDefault [netId _x,[]];
                                    if (count _visits < _requiredVisits) then {
                                        {_needed pushBackUnique _x} forEach ((_cleared select [0,24])-_visits);
                                    };
                                } forEach _activeWorkers;
                                private _spots=(_cleared select [0,24]) select {
                                    private _spot=AGLToASL (_positions select _x);
                                    !(_x in _needed)
                                        && {abs (((getPosASL _blocker) select 2)-(_spot select 2)) <= 0.75}
                                        && {(getPosASL _blocker) vectorDistance _spot >= 2}
                                        && {(getPosASL _blocker) vectorDistance _spot <= 8}
                                        && {_followReservations findIf {
                                            (_x select 0) != _blockerKey && {
                                                (_x select 1) vectorDistance _spot < 1.5
                                                    || {(_x select 2) isNotEqualTo [] && {(_x select 2) vectorDistance _spot < 1.5}}
                                            }
                                        } < 0}
                                };
                                private _spotRanks=_spots apply {[(getPosASL _blocker) vectorDistance (AGLToASL (_positions select _x)),_x]};
                                _spotRanks sort true;
                                if (_spotRanks isNotEqualTo []) then {
                                    private _yieldIndex=(_spotRanks select 0) select 1;
                                    private _yieldTarget=+(_positions select _yieldIndex);
                                    if ([_blocker,AGLToASL _yieldTarget] call _roomSegmentClear
                                        && {[_blocker] call _actorAvailable} && {[_blocker] call _actorTaskFree}
                                        && {currentCommand _blocker in ["","STOP"]} && {call _mayIssueMovement}) then {
                                        _blocker doMove _yieldTarget;
                                        [_blocker,_yieldTarget] call _rememberMove;
                                        _follow set [_blockerKey,[_yieldIndex,0,_now,false,false,[],_now,getPosASL _blocker]];
                                        _yielded pushBackUnique _blockerKey;
                                        _group setVariable ["WAIT_Cortex_ClearYield",_yieldContext+[+_yielded],true];
                                        private _slot=_followReservations findIf {(_x select 0) == _blockerKey};
                                        if (_slot >= 0) then {(_followReservations select _slot) set [2,AGLToASL _yieldTarget]};
                                    };
                                } else {
                                    // One exterior selection per completed worker per episode.
                                    // Preserve security posts/lanes and previously selected exit slots.
                                    private _taken=(keys _earlyExits) apply {+((_earlyExits get _x) select 1)};
                                    private _lanes=[];
                                    private _uses=createHashMap;
                                    {
                                        private _other=_earlyExits get _x;
                                        if ((_other select 3) in ["MOVING","ARRIVED"] && {count (_other param [6,[]]) == 3}) then {
                                            _lanes pushBack [+(_other select 1),+(_other select 6)];
                                            private _entryKey=str (_other select 5);
                                            _uses set [_entryKey,(_uses getOrDefault [_entryKey,0])+1];
                                        };
                                    } forEach keys _earlyExits;
                                    {
                                        private _security=_x;
                                        private _stage=(_job getOrDefault ["reserveStages",createHashMap]) getOrDefault [netId _security,[]];
                                        if ([_security] call _reserveReady && {(_stage param [2,""]) in ["APPROACH","ARRIVED"]}
                                            && {count (_stage param [4,[],[[]]]) == 3}) then {
                                            _taken pushBack +(_stage select 0);
                                            _lanes pushBack [+(_stage select 0),+(_stage select 4)];
                                            private _entryKey=str (_stage param [5,[]]);
                                            _uses set [_entryKey,(_uses getOrDefault [_entryKey,0])+1];
                                        };
                                    } forEach ((_job getOrDefault ["securityActors",[]]) select [0,64]);
                                    private _exitPlan=[_blocker,_taken,_lanes,_uses,true] call _chooseExteriorExit;
                                    private _exitTarget=_exitPlan select 0;
                                    if (call _mayIssueMovement) then {
                                        _yielded pushBackUnique _blockerKey;
                                        _group setVariable ["WAIT_Cortex_ClearYield",_yieldContext+[+_yielded],true];
                                    };
                                    if (count _exitTarget == 3 && {[_blocker] call _actorAvailable}
                                        && {[_blocker] call _actorTaskFree} && {currentCommand _blocker in ["","STOP"]}
                                        && {call _mayIssueMovement}) then {
                                        _earlyExits set [_blockerKey,[_blocker,+_exitTarget,serverTime+45,"MOVING",false,+(_exitPlan select 1),+(_exitPlan select 2)]];
                                        _job set ["earlyExits",_earlyExits];
                                        _follow deleteAt _blockerKey;
                                        _blocker doMove _exitTarget;
                                        [_blocker,_exitTarget] call _rememberMove;
                                        call _publishEarlyExits;
                                    };
                                };
                            };
                        };
                        continue;
                    };
                    if (_ranked isNotEqualTo []) then {
                        private _index=(_ranked select 0) select 3;
                        private _target=[_index] call _roomMovementPoint;
                        private _accessPoint=[];
                        if (!(_unit in (_job getOrDefault ["enteredActors",[]])) && {_failedTargets isNotEqualTo []}) then {
                            // Changing room alone may keep native planning on the same blocked door.
                            // Stage a later attempt at another existing entrance before its room leg.
                            // This is transit only, never an entry or room-clearance receipt.
                            private _entryRanks=(_job get "entries") apply {[_unit distance2D _x,_x]};
                            _entryRanks sort true;
                            if (count _entryRanks > 1) then {
                                _accessPoint=+((_entryRanks select ((count _failedTargets) mod count _entryRanks)) select 1);
                                _target=+_accessPoint;
                            };
                        };
                        _record=[_index,(getPosASL _unit) vectorDistance (AGLToASL _target),_now,false,false,_accessPoint,_now,getPosASL _unit];
                        _follow set [_key,_record];
                        _unit doMove _target;
                        [_unit,_target] call _rememberMove;
                        private _reservationIndex=_followReservations findIf {(_x select 0) == _key};
                        if (_reservationIndex >= 0) then {
                            (_followReservations select _reservationIndex) set [2,AGLToASL _target];
                        };
                    } else {
                        _followExhausted pushBackUnique _unit;
                        _followFailures set [_key,+_failedTargets];
                        _followBudgetChanged=true;
                        if !(_job getOrDefault ["entryFailed",false]) then {
                            private _cause=["FOLLOW_THROUGH_EXHAUSTED",_key,serverTime,+_visited,+_failedTargets];
                            _job set ["entryFailureCause",_cause];
                            diag_log format ["WAIT CLEAR ENTRY FAILURE: %1",[_job get "generation",_cause]];
                        };
                        _job set ["entryFailed",true];
                    };
                } else {
                    private _target=[_record select 0] call _roomMovementPoint;
                    private _accessPoint=_record param [5,[],[[]]];
                    if (_accessPoint isNotEqualTo []) then {
                        if (_unit distance2D _accessPoint <= 3
                            && {abs (((getPosASL _unit) select 2)-((AGLToASL _accessPoint) select 2)) <= 1.5}) then {
                            // Arrival at an entrance only releases the real interior movement leg.
                            _record set [5,[]];
                            _record set [1,(getPosASL _unit) vectorDistance (AGLToASL _target)];
                            _record set [2,_now];
                            _unit doMove _target;
                            [_unit,_target] call _rememberMove;
                        } else {_target=+_accessPoint};
                    };
                    // A native stair/corridor detour may increase direct room distance.
                    // Observe motion separately before retiring a still-useful owned leg.
                    // Older local records receive only a bounded observation grace; neither
                    // the actor recovery budget nor either operation deadline is renewed.
                    private _motionPose=_record param [7,getPosASL _unit,[[]]];
                    if (count _record < 8) then {_record set [6,_now]; _record set [7,+_motionPose]};
                    if ((getPosASL _unit) vectorDistance _motionPose >= 1) then {
                        _record set [6,_now];
                        _record set [7,getPosASL _unit];
                    };
                    private _motionStalled=_now-(_record select 6) >= 8;
                    private _remaining=(getPosASL _unit) vectorDistance (AGLToASL _target);
                    if ((_record select 1)-_remaining >= 1) then {
                        _record set [1,_remaining]; _record set [2,_now];
                    };
                    if (!(_record select 3) && {_now-(_record select 2) >= 12} && {_motionStalled}) then {
                        private _recovery=[_group,_operationGeneration,_unit,_target] call WAIT_fnc_RecoveryStep;
                        if (_recovery == "RECOVERING") then {[_unit,_target] call _rememberMove};
                        if (_recovery in ["RECOVERING","EXHAUSTED","INVALID"]) then {_record set [3,true]};
                    };
                    // Retire this actor's failed destination, not the actor or a real visit.
                    // Changing room does not renew the common generation recovery budget.
                    if ((_record select 3) && {_now-(_record select 2) >= 24} && {_motionStalled}) then {
                        private _failedTargets=_followFailures getOrDefault [_key,[]];
                        _failedTargets pushBackUnique (_record select 0);
                        _followFailures set [_key,_failedTargets];
                        _followBudgetChanged=true;
                        _follow set [_key,[]];
                    };
                };
            };
        } forEach _activeWorkers;
        _job set ["followThrough",_follow];
        _job set ["followThroughFailures",_followFailures];
        _job set ["followThroughExhausted",_followExhausted];
        if (_followBudgetChanged && {call _mayIssueMovement}) then {
            private _exhaustedIds=_followExhausted apply {netId _x};
            private _rows=(keys _followFailures select [0,64]) apply {
                [_x,+(_followFailures get _x),_x in _exhaustedIds]
            };
            _group setVariable ["WAIT_Cortex_ClearFollowBudget",[
                _building,_job get "hardDeadline",_job get "buildingTransform",_rows],true];
        };
    };
    // Complete physical coverage and participation retire obsolete owned room legs.
    // Egress is the next generation-owned request; native planner BUSY is not extra clearance evidence.
    if (((count _cleared + count _unreachable) >= count _positions && {_allWorkersProgressed || {_unreachable isNotEqualTo []}}) || {serverTime > (_job get "deadline")} || {serverTime > (_job getOrDefault ["hardDeadline",_job get "deadline"])} || {_activeWorkers isEqualTo []}) exitWith {
        // Room coverage does not prove that every active clearing actor entered.
        // A deadline may release the operation, but cannot convert missing participation to success.
        if (!(_job getOrDefault ["entryFailed",false]) && {!_allWorkersEntered || {!_allWorkersProgressed}}) then {
            private _cause=["SWEEP_PARTICIPATION",serverTime,_job get "deadline",_job get "hardDeadline",
                (_activeWorkers select [0,16]) apply {[netId _x,_x in (_job getOrDefault ["enteredActors",[]]),count (_actorVisits getOrDefault [netId _x,[]])]}];
            _job set ["entryFailureCause",_cause];
            diag_log format ["WAIT CLEAR ENTRY FAILURE: %1",[_job get "generation",_cause]];
        };
        _job set ["entryFailed",(_job getOrDefault ["entryFailed",false]) || {!_allWorkersEntered} || {!_allWorkersProgressed}];
        private _active=[];
        {_active append _x} forEach (_job get "pairs");
        _active=_active arrayIntersect _active;
        _active=_active select {[_x] call _actorAvailable && {!(_x in _unavailable)}};
        // Admission must honour replacement orders before the first exit leg is issued.
        // The EGRESS callback cannot detect an order that this transition already overwrote.
        private _diverted=_job getOrDefault ["egressDiverted",[]];
        _active=_active select {
            private _actor=_x;
            if !([_actor] call _exitMovementOwned) then {
                _diverted pushBackUnique _actor;
                (_job getOrDefault ["movementTargets",createHashMap]) deleteAt (netId _actor);
            };
            !(_actor in _diverted)
        };
        if (_diverted isNotEqualTo []) then {_job set ["egressFailed",true]};
        _job set ["egressDiverted",_diverted];
        // Defer expensive exterior planning; pending actors retain their owned room leg.
        private _moves=_job getOrDefault ["movementTargets",createHashMap];
        private _pending=[];
        private _egressAssignments=[];
        {
            private _unit=_x;
            private _early=_earlyExits getOrDefault [netId _unit,[]];
            if (_early isNotEqualTo []) then {
                _egressAssignments pushBack [_unit,+(_early select 1),(_early select 3) == "ARRIVED"];
            } else {
                _pending pushBack [_unit,+(_moves getOrDefault [netId _unit,[]])];
            };
        } forEach _active;
        _job set ["egressPending",_pending];
        _job set ["egressExitUses",createHashMap];
        _job set ["phase","EGRESS"];
        _job set ["egressAssignments",_egressAssignments];
        _job set ["egressDeadline",time+45];
        _job set ["egressDeadlineServer",serverTime+45];
        _job set ["egressStartedServer",serverTime];
        _job set ["egressProgress",_egressAssignments apply {
            [_x select 0,(getPosATL (_x select 0)) vectorDistance (_x select 1),time,0]
        }];
        _group setVariable ["WAIT_Cortex_ClearEgressRetries",[],true];
        _group setVariable ["WAIT_Cortex_ClearStatus",["EGRESS",count (_job get "cleared"),count (_job get "unreachable"),count (_job get "positions"),count (_job get "pairs"),serverTime],true];
        0.1
    };
    1.5
};
if (isNil "_delay" || {!(_delay isEqualType 0)}) then {_delay=-1};
private _phase=toUpperANSI (_job getOrDefault ["phase","ENTRY"]);
private _currentOperation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _currentOperation > 0 && {local _group}
    && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {(_currentOperation getOrDefault ["generation",-1]) == (_job getOrDefault ["operationGeneration",-2])}
    && {(_currentOperation getOrDefault ["intent",""]) == "CLEAR"}
    && {(_currentOperation getOrDefault ["phase",""]) != _phase}) then {
    _currentOperation set ["phase",_phase];
    _group setVariable ["WAIT_Operation",_currentOperation,true];
};
// Publish only material egress changes. All timestamps binding this journal use the
// server clock; owner adoption retains routes/retries and the original exit boundary.
if (_phase == "EGRESS" && {!(_job getOrDefault ["finished",false])}
    && {local _group} && {(_group getVariable ["WAIT_BuildingBrain",createHashMap]) isEqualTo _brain}
    && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {(_job get "generation") == (_group getVariable ["WAIT_AIPass_ClearGeneration",-1])}
    && {(_currentOperation getOrDefault ["generation",-1]) == (_job get "operationGeneration")}
    && {(_currentOperation getOrDefault ["intent",""]) == "CLEAR"}) then {
    private _moves=_job getOrDefault ["movementTargets",createHashMap];
    private _progress=_job getOrDefault ["egressProgress",[]];
    private _rows=(_job getOrDefault ["egressAssignments",[]]) apply {
        _x params ["_actor","_target",["_arrived",false]];
        private _recordIndex=_progress findIf {(_x select 0) == _actor};
        private _record=if (_recordIndex < 0) then {[]} else {_progress select _recordIndex};
        [_actor,+_target,_arrived,+(_moves getOrDefault [netId _actor,[]]),
            _record param [3,0],+(_record param [4,[],[[]]])]
    };
    private _journal=["EGRESS",_rows apply {_x select 1},_job get "egressStartedServer",_rows,
        _job get "building",_job get "buildingTransform",_job get "hardDeadline",
        _job get "egressDeadlineServer",_job getOrDefault ["egressFailed",false],
        _job getOrDefault ["entryFailed",false],2,
        +(_job getOrDefault ["egressPending",[]]),
        ((keys (_job getOrDefault ["egressExitUses",createHashMap])) apply {[_x,(_job get "egressExitUses") get _x]})];
    if ((_group getVariable ["WAIT_Cortex_ClearEgress",[]]) isNotEqualTo _journal) then {
        _group setVariable ["WAIT_Cortex_ClearEgress",_journal,true];
    };
};
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
if (!isNull _group && {local _group}
    && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {(_job getOrDefault ["generation",-1]) == (_group getVariable ["WAIT_AIPass_ClearGeneration",0])}) then {
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

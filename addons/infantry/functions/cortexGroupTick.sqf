/*
 * Author: WaldoTheWarfighter
 * Locality / Authority: Executes on the caller; world changes are limited to locally owned objects or groups, or to server-published state, as guarded below.
 * Pending remounts yield to a replacement vehicle assignment; cleanup only cancels the original seat order.
 * Runs one Cortex step for one locally owned group: reads the situation, moves it along the
 * group state ladder and calls each enabled behaviour. A targetless hit, explosion or suppression
 * may grant only a bounded passenger safe-dismount lease; it does not grant target, route or
 * manoeuvre authority. Casualty succession selects a living,
 * conscious local successor by rank before leader-dependent tactics; combat-effective leaders are preserved.
 *
 * State ladder with post-contact search and hysteresis:
 * CALM -> CONTACT when an enemy was seen in the last 10 s.
 * CALM -> INVESTIGATE when the squad knows about an enemy within
 *   WAIT_AIPass_Investigate_Range that it has not seen, for example one revealed by a contact report
 *   or heard firing, and the behaviour profile permits investigation. This is a deterministic tactical
 *   eligibility decision rather than a random permission to act. Within 150 m, two riflemen check
 *   the believed position while the rest watch it; a small
 *   squad, or any farther contact, has the whole squad move up together. It ends after
 *   WAIT_AIPass_Investigate_Seconds or on arrival, back in CALM.
 * CONTACT -> SECURITY after WAIT_AIPass_PostContact_LostSeconds without a sighting and after any
 *   bounded flank, advance or coordinated assault has finished (or straight back to CALM when
 *   post-contact is off). Temporary occlusion therefore cannot revoke an active manoeuvre.
 * A targetless danger wake returns directly to CALM when its finite danger lease expires. It does
 *   not spend the full lost-contact interval in COMBAT unless native enemy knowledge appears.
 * SECURITY (hold) -> SEARCH (two riflemen check the last known enemy position) -> REGROUP (wait for
 *   the squad to close up) -> CALM, which restores the recorded behaviour and speed (a squad that
 *   was SAFE before a real firefight returns AWARE).
 * RETREAT (morale broken or a damaged vehicle withdrawing) -> REGROUP. A garrison, defence or
 * building-clear order is released before the same retreat transition; releasing the prior order
 * alone never counts as withdrawal.
 * Any sighting during SECURITY, SEARCH or REGROUP returns the group to CONTACT. State handovers
 * preserve a live actor-level grenade-evasion or anti-armour move instead of issuing formation
 * commands over it. REGROUP only recalls separated members, never clears their combat targets,
 * and waits for a short owned actor move before declaring the squad cohesive.
 * Disabling investigation or post-contact while its phase is active immediately uses the normal
 * CALM restoration path; a runtime switch cannot leave old search movement alive until timeout.
 * A reinforcement responder whose requester returns to CALM rejects its server reservation and
 * releases only its SUPPORT_RALLY or COORDINATED_ASSAULT movement lease and its matching COMPAT
 * movement handover; no stale token survives.
 * CARELESS groups are left entirely to the mission maker.
 * WAIT_AIPass_ReactionSpeed (AI Tuning) divides the step interval, so squads re-assess faster or slower.
 * Each returned interval receives a small zero-mean random jitter. This prevents newly created squads
 * from repeatedly thinking and firing in the same frame, while adding no scheduler job or polling loop.
 * A squad riding as cargo in an AI-flown aircraft is handled by airborne insertion instead
 * (WAIT_fnc_CortexAirborneCheck) until it has parachuted and landed.
 *
 * Cadence (distance tiers measured to the nearest player): WAIT_AIPass_TickContact for a group with
 * fresh native hostile knowledge or a finite danger response; WAIT_AIPass_TickNear within
 * WAIT_AIPass_NearRange; WAIT_AIPass_TickMid within WAIT_AIPass_FarRange; WAIT_AIPass_TickFar
 * beyond. A distant calm group remains cheap, while a distant group actually seeing an enemy uses
 * the same bounded group decision path as nearby combat instead of pausing between 20-second scans.
 * In CONTACT near players, immediate posture, morale, stance and vehicle safety remain available
 * after a validated danger event. Target-dependent work (anti-armour, artillery, reinforcement,
 * coordination, flanking and advance) starts only after native knowledge contains an enemy. A hit
 * or explosion can therefore wake the finite combat state without manufacturing a target, consuming
 * tactical cooldowns or dispatching squads toward the danger sample. With target knowledge, each
 * enabled behaviour runs: fire control, stance, anti-armour, vehicles, flanking (with final assault),
 * bounding advance, contact reports, ammo sharing, artillery, reinforcement and coordinated assault.
 * Garrison and defence orders run their own break and reserve logic instead of flanking or retreating.
 * Soldiers left holding ground by a drill rejoin when the leader comes within 30 m. Reinforcement
 * rallies are optional fallback positions; an acknowledged responder with a safe shared-contact
 * approach may enter a coordinated assault immediately.
 * WAIT's configured engine danger FSM owns immediate unit reactions. This group brain owns bounded
 * tactics and expensive planning through the shared scheduler; it does not wait on another danger
 * controller or start a second movement worker.
 * Zeus always wins: a group Zeus is commanding is ineligible (WAIT_fnc_CortexZeusHeld), so it is
 * released, including WAIT garrison, defence and clear orders. An authored HOLD or SENTRY waypoint
 * also blocks every autonomous WAIT movement owner while leaving native observation, stance and
 * fire control available. Stance cleanup preserves a later different externally assigned posture
 * instead of unconditionally resetting it.
 * Locality and authority: runs as a scheduler job on the group owner. When the group stops being
 * local the job retires and the new owner's discovery sweep starts a fresh one.
 * A running tactical drill has a separate scheduler heartbeat. If it stays silent for 30 seconds,
 * this owner ends it through common cleanup and restores its engine leases.
 * SafeStart and ENDEX provide a one-minute resumption grace instead of causing a false stall.
 *
 * Review contract: Waypoint completion compares tagged indices with currentWaypoint; completed waypoints may remain in the engine list. This allows optional rally arrival and retreat completion to be detected.
 *
 * Repeat/JIP: current feature gates and eligibility are rechecked, including active phase gates;
 * owner jobs are retired on migration.
 * Arguments:
 * 0: job <HASHMAP> - contains "group"
 *
 * Return Value:
 * Number - seconds until the next step, or -1 to retire the job
 *
 * Example:
 * [WAIT_fnc_CortexGroupTick, createHashMapFromArray [["group", _group]], 1] call WAIT_fnc_CortexQueueJob;
 * Result: the group is managed by the pass on this machine.
 *
 * Current caller: WAIT_fnc_GroupBrainStep, as a one-shot callback selected by the owner-local
 * groupTactics FSM. Discovery starts the FSM and never queues this function persistently.
 */

params [["_job", createHashMap, [createHashMap]]];
private _group = _job getOrDefault ["group", grpNull];
_job set ["lastRunAt",time];
if (isNull _group) exitWith {-1};
if (!local _group || {!(missionNamespace getVariable ["WAIT_AIPass_Active", false])}) exitWith {
    _group setVariable ["WAIT_AIPass_Managed", nil];
    -1
};
// A periodic lease expiry must never reset posture after Zeus, a player or a specialist controller
// claims any member of the group.
private _dangerYield=[_group] call WAIT_fnc_CortexExternalTakeover;
if (!_dangerYield) then {
    private _dangerActor=[_group] call WAIT_fnc_CortexGroupAnchor;
    if (isNull _dangerActor) then {_dangerActor=leader _group};
    [_dangerActor,"RESTORE"] call WAIT_fnc_DangerReact
};

{
    if (local _x && {_x getVariable ["WAIT_AIPass_StanceSet",false]} && {!([_group,"WAIT_AIPass_Stance_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) then {
        if (toUpperANSI (unitPos _x) == (_x getVariable ["WAIT_Cortex_AppliedStance",""])) then {_x setUnitPos "AUTO"};
        _x setVariable ["WAIT_Cortex_AppliedStance",nil,true];
        _x setVariable ["WAIT_AIPass_StanceSet",nil,true];
    };
    private _target = _x getVariable ["WAIT_AIPass_VehicleTarget",objNull];
    if (local _x && {!isNull _target} && {!([_group,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled) || {!([_group,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled)} || {!(combatMode _group in ["YELLOW","RED"] && {unitCombatMode _x in ["YELLOW","RED"]})}}) then {
        if (assignedTarget _x == _target) then {_x doTarget objNull};
        _x setVariable ["WAIT_AIPass_VehicleTarget",nil,true];
        _x setVariable ["WAIT_AIPass_TargetHold",nil];
    };
} forEach units _group;
private _alive = (units _group) select {alive _x};
if (_alive isEqualTo []) exitWith {
    _group setVariable ["WAIT_AIPass_Managed", nil];
    -1
};
// The generic group loop owns infantry and ground-vehicle behaviour only. Aircraft occupants retain
// ordinary eligibility for the dedicated flight systems, but this job must retire immediately if a
// group boards an aircraft so CONTACT cleanup and tactical jobs cannot fight the pilot controller.
private _generallyEligible=[_group] call WAIT_fnc_CortexIsEligible;
private _groundPassEligible=[_group,false,true] call WAIT_fnc_CortexIsEligible;
if (!_groundPassEligible && {_generallyEligible}) exitWith {
    [_group,true,"AIRCRAFT_DEDICATED"] call WAIT_fnc_CortexReleaseGroup;
    -1
};
if (!_generallyEligible) exitWith {
    if (count (_group getVariable ["WAIT_AIPass_State", createHashMap]) > 0 || {(_group getVariable ["WAIT_Cortex_Remount",[]]) isNotEqualTo []}) then {[_group, false] call WAIT_fnc_CortexReleaseGroup};
    // Any active Zeus takeover outranks explicit holding orders, including target,
    // stance and ZEN commands that do not create a waypoint.
    if ([_group] call WAIT_fnc_CortexZeusHeld) then {
        if ((_group getVariable ["WAIT_AIPass_Garrison", []]) isNotEqualTo []) then {[_group,false] call WAIT_fnc_CortexGarrisonRelease};
        if ((_group getVariable ["WAIT_AIPass_Defend", []]) isNotEqualTo []) then {[_group,false] call WAIT_fnc_CortexDefendRelease};
        if (_group getVariable ["WAIT_AIPass_ClearBuilding", false]) then {[_group,false] call WAIT_fnc_CortexClearRelease};
    };
    [20, 5] select ([_group] call WAIT_fnc_CortexZeusHeld)
};
// A group tick can complete bounded assessment and planning after a curator or specialist
// controller has claimed the group. Check immediately before actor-level commands so old
// search, rejoin and regroup work cannot overwrite that newer order.
private _mayIssueMovement = {
    !([_group] call WAIT_fnc_CortexExternalTakeover)
};
// Survivor regroup owns a remnant while it is being merged.
if (_group getVariable ["WAIT_AIPass_RegroupQueued", false]) exitWith {5};
// Resolve casualty succession before reading leader knowledge or issuing group orders.
// Only eligible, locally owned AI groups reach this point. An incapacitated leader cannot drive
// withdrawal, bounds or contact state, so appoint an acting leader instead of waiting for recovery.
private _leader = leader _group;
if ((isNull _leader || {!([_leader] call WAIT_fnc_CortexCombatEffective)}) && {[_group,"WAIT_AIPass_Contact_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) then {
    private _successors = _alive select {local _x && {[_x] call WAIT_fnc_CortexCombatEffective}};
    if (_successors isNotEqualTo []) then {
        private _successor = _successors select 0;
        {if (rankId _x > rankId _successor) then {_successor = _x}} forEach _successors;
        _group selectLeader _successor;
        _leader = leader _group;
    };
};
// Never drive leader-dependent tactics through an incapacitated actor while succession settles.
if (isNull _leader || {!([_leader] call WAIT_fnc_CortexCombatEffective)}) exitWith {5};
// Ordinary vehicle safety is independent of contact tactics. It samples only every four seconds,
// keeps the engine route intact and releases before a convoy's dedicated controller takes over.
[_group] call WAIT_fnc_DrivingAssistStart;
if (behaviour _leader == "CARELESS") exitWith {10};
// Airborne insertion owns a squad while it rides an aircraft or is parachuting down.
if (_group getVariable ["WAIT_AIPass_Dropping", false]) exitWith {3};
private _airborneDelay = [_group, [_group] call WAIT_fnc_CortexGroupState] call WAIT_fnc_CortexAirborneCheck;
if (_airborneDelay >= 0) exitWith {_airborneDelay};

private _state = [_group] call WAIT_fnc_CortexGroupState;
// A short calm/security treatment action uses the common operation lifecycle and is deliberately
// evaluated before contact planning. It never delays a contact, retreat, direct order or an existing
// movement/building operation; the next state tick cancels it when any of those conditions appears.
if ([_group,_state,_state getOrDefault ["phase","CALM"]] call WAIT_fnc_CortexMedicalStep) exitWith {3};
// Danger assessment has already validated locality, eligibility and Zeus ownership. Consume its
// short-lived context here rather than introducing a second movement loop. The context never
// identifies a shooter, changes a route or converts a report into target knowledge.
private _dangerResponse=_group getVariable ["WAIT_Danger_Response",[]];
private _dangerActive=false;
if (count _dangerResponse == 5) then {
    _dangerResponse params ["_dangerCause","_dangerPosition","_dangerObservedAt","_dangerUntil","_dangerGeneration"];
    if (_dangerGeneration == (_group getVariable ["WAIT_Danger_Generation",-1]) && {time < _dangerUntil}) then {
        _state set ["dangerResponse",+_dangerResponse];
        _dangerActive=true;
        // A mounted group may know that its vehicle has been hit before the engine identifies a
        // shooter. Preserve that distinction: this lease permits only the existing stop-and-exit
        // handshake. Target selection, withdrawal and manoeuvre still require native knowledge.
        private _vehicleContext=_group getVariable ["WAIT_Danger_VehicleContext",[]];
        private _vehicleProfile=if (count _vehicleContext in [7,8]
            && {(_vehicleContext select 6) == _dangerGeneration}
            && {time < (_vehicleContext select 5)}) then {_vehicleContext select 0} else {""};
        _state set ["dangerVehicleProfile",_vehicleProfile];
        // A transport or fighting vehicle can move its passengers into the fight without ejecting
        // operating crew. Aircraft, batteries and static weapons remain with their dedicated owner;
        // a generic danger callback cannot turn them into an infantry dismount operation.
        if (_vehicleProfile != "") then {
            private _dangerVehicle=_vehicleContext param [1,objNull,[objNull]];
            private _dangerSource=_vehicleContext param [7,objNull,[objNull]];
            _state set ["dangerDismount",[+_dangerPosition,time+30,_vehicleProfile,_dangerCause,_dangerVehicle,_dangerSource,_dangerGeneration]];
        };
    } else {
        _state deleteAt "dangerResponse";
        _state deleteAt "dangerVehicleProfile";
        _group setVariable ["WAIT_Danger_Response",nil,true];
        _group setVariable ["WAIT_Danger_Action",nil,true];
        _group setVariable ["WAIT_Danger_VehicleContext",nil,true];
    };
} else {
    _state deleteAt "dangerResponse";
    _state deleteAt "dangerVehicleProfile";
};
// The engine FSM owns the immediate posture. This already-budgeted group step may additionally
// move one idle exposed actor into nearby physical cover. The helper refuses every active operation,
// native command and external owner, so contact reaction cannot interrupt a committed route.
// Preserve the actor selected by the native danger FSM. Falling back to the group anchor made a
// wingman's hit or near-round response move the leader instead, disconnecting the visible reaction
// from the physical event. The observation timestamp binds this identity to the live response; a
// stale, dead or migrated observer still falls back safely to the current combat-effective anchor.
private _dangerAction=_group getVariable ["WAIT_Danger_Action",[]];
private _dangerCoverActor=objNull;
if (count _dangerAction >= 6
    && {(_dangerAction param [1,"",[""]]) == (_dangerResponse param [0,"",[""]])}
    && {(_dangerAction param [2,-1,[0]]) == (_dangerResponse param [2,-2,[0]])}
    && {(_dangerAction param [4,-1,[0]]) == (_dangerResponse param [4,-2,[0]])}) then {
    private _observedActor=_dangerAction param [5,objNull,[objNull]];
    if (!isNull _observedActor && {alive _observedActor} && {local _observedActor}
        && {group _observedActor == _group}) then {_dangerCoverActor=_observedActor};
};
if (isNull _dangerCoverActor) then {_dangerCoverActor=[_group] call WAIT_fnc_CortexGroupAnchor};
if (isNull _dangerCoverActor) then {_dangerCoverActor=_leader};
private _dangerActionName=if (count _dangerAction >= 5
    && {(_dangerAction select 4) == (_group getVariable ["WAIT_Danger_Generation",-1])}
    && {time < (_dangerAction select 3)}) then {_dangerAction select 0} else {""};
// Observation, mounted safety and infantry tactical authority are separate. A vehicle hit can stop
// for its passengers without authorising an on-foot CONTACT operation; a concrete native FORCED task
// receives neither. This defensive FORCED exclusion also protects an older packaged response during
// a same-frame task handover even though DangerStep normally clears it before this tick.
// A casualty or scream is useful alerting evidence, but it does not identify an attacker. Keep the
// response available to morale, remount cancellation and diagnostics without promoting the group
// into CONTACT or the expensive tactical tier. Immediate hazards and validated hostile observations
// retain that authority.
private _dangerTactical=_dangerActive
    && {!(_dangerActionName in ["FORCED","VEHICLE"])}
    && {!(combatMode _group in ["BLUE","GREEN"])}
    && {private _responseCause=_dangerResponse param [0,"",[""]];
        _responseCause in ["HIT","EXPLOSION","SUPPRESSED"]
            || {_responseCause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"] && {_dangerActionName != "HIDE"}}};
private _dangerAlert=_dangerActive && {
    combatMode _group in ["BLUE","GREEN"]
    || {(_dangerResponse param [0,"",[""]]) in ["CASUALTY","BODY_FOUND","SCREAM"]}
    || {(_dangerResponse param [0,"",[""]]) in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"] && {_dangerActionName == "HIDE"}}
};
private _dangerVehicleSafety=_dangerActive && {_dangerActionName == "VEHICLE"};
// Casualty and scream observations raise awareness but are not incoming-fire geometry. Treating
// their reported position as a physical threat sent soldiers away from bodies or voices and made
// harmless evidence look like suppression. Only immediate hazards may own this cover reflex.
private _physicalCoverCause=(_dangerResponse param [0,"",[""]]) in ["HIT","EXPLOSION","SUPPRESSED","GUNFIRE"];
if (_dangerActive && {_dangerActionName == "HIDE"} && {_physicalCoverCause}) then {
    [_group,_dangerCoverActor,_dangerResponse select 1,_dangerResponse select 4] call WAIT_fnc_DangerCoverStep;
    [_group,_dangerResponse select 4,true,_dangerResponse select 0] call WAIT_fnc_DangerGroupHideStep;
} else {
    private _coverLease=_group getVariable ["WAIT_Danger_CoverLease",[]];
    if (count _coverLease >= 2) then {
        [_group,_coverLease select 0,[],_coverLease select 1] call WAIT_fnc_DangerCoverStep;
    };
    [_group,-1,false,""] call WAIT_fnc_DangerGroupHideStep;
};
// Smoke is a supporting reflex, never another movement phase. One unreserved local actor may throw
// while cover selection and the current operation continue; the helper's generation context cancels
// the queued release if Zeus, a specialist owner or a newer danger response takes over next frame.
if (_dangerActive && {_dangerActionName == "HIDE"} && {_physicalCoverCause}) then {
    [_group,_dangerResponse] call WAIT_fnc_DangerSmokeStep;
};
[_group,_state] call WAIT_fnc_CortexSupportMaintain;
// The drill controller is a separate scheduled job. If it is lost or starved, leaving the
// drill HashMap in place blocks replacement tactics and can leave Cortex-owned PATH,
// AUTOCOMBAT, behaviour and ROE leases active indefinitely. End through the common cleanup
// path after a bounded silence. SafeStart/ENDEX continually extend ResumeGraceUntil, so a
// deliberately paused mission gets one minute for its deferred job to resume first.
private _activeDrill=_state getOrDefault ["drill",createHashMap];
if (count _activeDrill > 0) then {
    private _lastDrillStep=_activeDrill getOrDefault ["lastStep",_activeDrill getOrDefault ["started",time]];
    private _drillWatchdog=30;
    private _resumeGrace=missionNamespace getVariable ["WAIT_AIPass_ResumeGraceUntil",-1];
    if (time-_lastDrillStep > _drillWatchdog && {time >= _resumeGrace}) then {
        [_group,_state,"SCHEDULER_STALLED"] call WAIT_fnc_CortexFlankEnd;
        _activeDrill=createHashMap;
    };
};
private _reverseRecord=_group getVariable ["WAIT_VehicleReverse",[]];
if (count _reverseRecord == 9) then {
    private _reverseResult=[_group,_state,_reverseRecord select 0,_reverseRecord select 4,"STEP",_reverseRecord select 1] call WAIT_fnc_CortexVehicleReverseStep;
    if (_reverseResult in ["COMPLETE","FALLBACK"] && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
        && {(_state getOrDefault ["phase",""]) == "RETREAT"}
        && {private _current=_group getVariable ["WAIT_Operation",createHashMap];
            (_current getOrDefault ["generation",-1]) == (_reverseRecord select 1)
                && {(_current getOrDefault ["intent",""]) == "VEHICLE_WITHDRAW"}}) then {
        private _escape=_state getOrDefault ["retreatTarget",[]];
        if (count _escape >= 2) then {[_group,_escape,40] call WAIT_fnc_CortexGroupMove};
    };
};
private _movementLease = _state getOrDefault ["movementLease",[]];
private _movementOwner = _movementLease param [0,""];
private _groupMovementOwned = count _movementLease == 2 && {time < (_movementLease select 1)} && {
    switch (_movementOwner) do {
        case "TACTICAL_DRILL": {count (_state getOrDefault ["drill",createHashMap]) > 0};
        case "COORDINATED_ASSAULT": {
            _state getOrDefault ["assaulting",false]
                && {(_state getOrDefault ["supportToken",""]) != ""}
        };
        case "VEHICLE_WITHDRAW": {
            (_group getVariable ["WAIT_VehicleReverse",[]]) isNotEqualTo []
                || {(waypoints _group) findIf {waypointDescription _x == "WAIT AI PASS" && {(_x select 1) >= currentWaypoint _group}} >= 0}
        };
        case "VEHICLE_ORIENT": {
            private _vehicle=(_state getOrDefault ["vehicleDangerOrient",[]]) param [1,objNull,[objNull]];
            private _marker=if (isNull _vehicle) then {[]} else {_vehicle getVariable ["WAIT_Danger_VehicleOrient",[]]};
            private _target=_marker param [2,[],[[]]];
            count _marker == 5 && {(_marker param [1,grpNull]) == _group}
                && {serverTime < (_marker param [3,0])} && {count _target >= 2}
                && {alive _vehicle} && {canMove _vehicle}
                && {private _relative=_vehicle getRelDir _target; _relative > 20 && {_relative < 340}}
        };
        default {
            (waypoints _group) findIf {
                (_x select 1) >= currentWaypoint _group && {waypointDescription _x == "WAIT AI PASS"}
            } >= 0
        };
    }
};
if (!_groupMovementOwned && {_movementLease isNotEqualTo []}) then {
    private _operationKey = switch (_movementOwner) do {
        case "VEHICLE_WITHDRAW": {"vehicleOperationGeneration"};
        case "VEHICLE_STANDOFF": {"vehicleOperationGeneration"};
        case "VEHICLE_JINK": {"vehicleOperationGeneration"};
        case "VEHICLE_ORIENT": {"vehicleOperationGeneration"};
        case "ARTILLERY_SCOOT": {"artilleryScootOperationGeneration"};
        case "SUPPORT_RALLY": {"supportOperationGeneration"};
        case "TACTICAL_REPOSITION": {"tacticalRepositionOperationGeneration"};
        default {""};
    };
    if (_operationKey != "") then {
        private _generation=_state getOrDefault [_operationKey,-1];
        private _movementResult="COMPLETE";
        private _movementReason=_movementOwner+"_FINISHED";
        if (_movementOwner == "VEHICLE_ORIENT") then {
            private _vehicle=(_state getOrDefault ["vehicleDangerOrient",[]]) param [1,objNull,[objNull]];
            private _marker=if (isNull _vehicle) then {[]} else {_vehicle getVariable ["WAIT_Danger_VehicleOrient",[]]};
            private _target=_marker param [2,[],[[]]];
            private _aligned=!isNull _vehicle && {alive _vehicle} && {count _target >= 2}
                && {private _relative=_vehicle getRelDir _target; _relative <= 20 || {_relative >= 340}};
            _movementResult=["INCOMPLETE","COMPLETE"] select _aligned;
            _movementReason=["VEHICLE_ORIENT_TIMEOUT","VEHICLE_ORIENT_ALIGNED"] select _aligned;
        };
        if (_movementOwner in ["VEHICLE_WITHDRAW","VEHICLE_STANDOFF","VEHICLE_JINK","ARTILLERY_SCOOT"]) then {
            private _intent=_group getVariable ["WAIT_Cortex_GroupMoveIntent",createHashMap];
            private _position=_intent getOrDefault ["position",[]];
            private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;
            private _arrived=count _position >= 2 && {!isNull _anchor}
                && {vehicle _anchor distance2D _position <= (_intent getOrDefault ["radius",25])};
            _movementResult=["INCOMPLETE","COMPLETE"] select _arrived;
            _movementReason=["MOVEMENT_NO_ARRIVAL","OBJECTIVE_REACHED"] select _arrived;
        };
        if (_movementOwner == "TACTICAL_REPOSITION") then {
            private _record=_group getVariable ["WAIT_Cortex_TacticalReposition",[]];
            private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;
            private _arrived=count _record >= 8 && {(_record select 7) == _generation}
                && {!isNull _anchor} && {_anchor distance2D (_record select 5) <= 12};
            _movementResult=["INCOMPLETE","COMPLETE"] select _arrived;
            _movementReason=["REPOSITION_NO_ARRIVAL","OBJECTIVE_REACHED"] select _arrived;
        };
        if (_generation >= 0) then {[_group,_generation,_movementResult,_movementReason] call WAIT_fnc_OperationRelease};
        if (_movementOwner == "TACTICAL_REPOSITION") then {
            private _reposition=_group getVariable ["WAIT_Cortex_TacticalReposition",[]];
            if (count _reposition >= 8 && {(_reposition select 7) == _generation}) then {
                _reposition set [0,_movementResult];
                _reposition pushBack serverTime;
                _group setVariable ["WAIT_Cortex_TacticalReposition",_reposition,true];
            };
        };
        _state deleteAt _operationKey;
    };
    if (_movementOwner == "VEHICLE_JINK") then {
        private _jinkState=_state getOrDefault ["vehicleDangerJink",[]];
        private _jinkVehicle=_jinkState param [1,objNull,[objNull]];
        if (!isNull _jinkVehicle && {local _jinkVehicle}) then {
            private _marker=_jinkVehicle getVariable ["WAIT_Danger_VehicleJink",[]];
            if (_marker param [1,grpNull,[grpNull]] == _group) then {
                _jinkVehicle setVariable ["WAIT_Danger_VehicleJink",nil,true];
            };
        };
    };
    if (_movementOwner == "VEHICLE_ORIENT") then {
        private _orientState=_state getOrDefault ["vehicleDangerOrient",[]];
        private _orientVehicle=_orientState param [1,objNull,[objNull]];
        if (!isNull _orientVehicle && {local _orientVehicle}) then {
            private _marker=_orientVehicle getVariable ["WAIT_Danger_VehicleOrient",[]];
            if (_marker param [1,grpNull,[grpNull]] == _group) then {
                if !([_group] call WAIT_fnc_CortexExternalTakeover) then {
                    _orientVehicle sendSimpleCommand "STOPTURNING";
                };
                _orientVehicle setVariable ["WAIT_Danger_VehicleOrient",nil,true];
            };
        };
        _state deleteAt "vehicleDangerOrient";
    };
    if (_movementOwner != "") then {[_group,_movementOwner,false] call WAIT_fnc_CortexOwnershipLease};
    _state deleteAt "movementLease";
};
private _now = time;
private _hasLiveActorMove = {
    private _actorMove = _this getVariable ["WAIT_Cortex_ActorMove",[]];
    count _actorMove == 3 && {_now < (_actorMove select 2)}
};
private _get = {
    _this params ["_name", "_fallback"];
    if (_fallback isEqualType true) then {[_group, _name, _fallback] call WAIT_fnc_CortexFeatureEnabled} else {missionNamespace getVariable _this}
};

// Combined-arms roles are public finite intent. Reapply once when a group moves to a new owner;
// the token prevents an obsolete owner or an older opportunity from reviving work.
private _combinedRole=_group getVariable ["WAIT_Cortex_CombinedRole",[]];
if (count _combinedRole == 7 && {serverTime < (_combinedRole select 5)}) then {
    private _combinedApplied=_group getVariable ["WAIT_Cortex_CombinedApplied",[]];
    if ((_combinedApplied param [0,""]) != (_combinedRole select 0)
        || {(_combinedApplied param [1,-1]) != clientOwner}) then {
        [_group,_combinedRole] call WAIT_fnc_CortexCombinedArmsLocal;
    };
};

private _nearest = 1e6;
{_nearest = _nearest min (_leader distance2D _x)} forEach (missionNamespace getVariable ["WAIT_AIPass_PlayerPositions", []]);
private _farRange = ["WAIT_AIPass_FarRange", 2500] call _get;
private _nearTier = _nearest <= _farRange;
// Local danger is an event-driven exception to the normal player-distance cadence. It promotes
// only this already-scheduled group decision while the finite response lease is live, so combat
// logic can use existing engine knowledge immediately without adding a global combat scan or a
// second route/movement owner.
private _tacticalTier=_nearTier || _dangerTactical;
private _delay = switch (true) do {
    case (_nearest <= (["WAIT_AIPass_NearRange", 1000] call _get)): {["WAIT_AIPass_TickNear", 4] call _get};
    case (_nearTier): {["WAIT_AIPass_TickMid", 8] call _get};
    default {["WAIT_AIPass_TickFar", 20] call _get};
};
if !(["WAIT_AIPass_Contact_Enable", true] call _get) exitWith {[_group,false] call WAIT_fnc_CortexReleaseGroup; _delay};

([_group] call WAIT_fnc_CortexKnowledge) params ["_enemies", "_seenCount"];
// Native hostile knowledge is the durable continuation of a short engine danger callback. The
// danger FSM wakes the shared group brain immediately; once that finite record expires, a group
// which is still seeing an enemy must retain combat cadence from its own engine knowledge. Without
// this handoff a distant firefight fell back to the ordinary 20-second discovery cadence, producing
// visible pauses between otherwise valid fire, manoeuvre and casualty decisions. This promotes only
// the already-scheduled bounded group job, adds no scan or worker, and stops as soon as the engine's
// five-second fresh-sighting window ends.
private _nativeCombatResponsive=_seenCount > 0;
_tacticalTier=_tacticalTier || {_nativeCombatResponsive};
if (_nativeCombatResponsive) then {
    _delay=_delay min (["WAIT_AIPass_TickContact",2] call _get);
};
// Naval delivery is a composable movement layer inside this existing group job. It runs before
// state selection so an embarked passenger group waits for the crew's finite approach and a boat
// crew cannot be given an infantry flank, retreat or investigation destination on land.
private _navalOwnsMovement=[_group,_state,_enemies] call WAIT_fnc_CortexNavalAssault;
_groupMovementOwned=_groupMovementOwned || {_navalOwnsMovement};
private _visible = _enemies select {(_x select 2) <= 10};
// Danger geometry is deliberately approximate and carries no hostile identity. It may drive the
// immediate finite response and local safety layers, but it is never sufficient authority for a
// route, support request, artillery request or target-specific weapon order.
private _hasTargetKnowledge = _enemies isNotEqualTo [];
// The engine danger FSM preserves a hostile object only when the native callback supplied it and
// the observer already knew it. Revalidate that short lease against current group knowledge before
// allowing mounted danger to become combat. This keeps a targetless blast, stale unrelated contact
// or friendly event in the passenger-safety path while restoring prompt effective-commander response.
private _dangerContact=_group getVariable ["WAIT_Danger_Contact",[]];
private _dangerContactSource=objNull;
if (count _dangerContact == 4
    && {(_dangerContact select 3) == (_group getVariable ["WAIT_Danger_Generation",-1])}
    && {time < (_dangerContact select 2)}) then {
    _dangerContactSource=_dangerContact select 0;
};
private _dangerConfirmed=!isNull _dangerContactSource && {alive _dangerContactSource}
    && {(side _group) getFriend (side _dangerContactSource) < 0.6}
    && {_enemies findIf {(_x select 0) == _dangerContactSource} >= 0};
if (!_dangerConfirmed && {_dangerContact isNotEqualTo []}) then {
    _group setVariable ["WAIT_Danger_Contact",nil,true];
};
private _dangerVehicleContact=_dangerVehicleSafety && {_dangerConfirmed}
    && {(_dangerResponse param [0,"",[""]]) in ["HIT","SUPPRESSED","DETECTED","PROXIMITY","CANFIRE","GUNFIRE"]};
_tacticalTier=_tacticalTier || {_dangerVehicleContact};
private _holdFire=combatMode _group in ["BLUE","GREEN"];
// Run only the bounded vehicle/passenger safety slice for a targetless mounted danger event. With an
// empty enemy list CortexVehicles exits immediately after its safe-stop/dismount handshake, so this
// cannot select a target, withdrawal, standoff or infantry phase.
if (_dangerVehicleSafety && {["WAIT_AIPass_Vehicles_Enable",true] call _get}) then {
    [_group,_state,[]] call WAIT_fnc_CortexVehicles;
};
private _garrisoned = (_group getVariable ["WAIT_AIPass_Garrison", []]) isNotEqualTo [];
private _defending = (_group getVariable ["WAIT_AIPass_Defend", []]) isNotEqualTo [];
// HOLD and SENTRY are concrete mission intent even when they were authored before Zeus connected
// or created by a script rather than a curator. They may continue to observe and fire, but WAIT must
// not replace them with investigation, reinforcement, coordinated movement, CQB entry, flank,
// advance, assault, remount or post-contact search. WAIT-generated waypoints use distinct types and
// descriptions, so this gate does not mistake its own finite route for external ownership.
private _waypointIndex=currentWaypoint _group;
private _waypointCount=count waypoints _group;
private _authoredStationary=_waypointIndex < _waypointCount
    && {waypointType [_group,_waypointIndex] in ["HOLD","SENTRY"]}
    && {waypointDescription [_group,_waypointIndex] != "WAIT AI PASS"};
private _ordered = _garrisoned || {_defending}
    || {_group getVariable ["WAIT_AIPass_ClearBuilding", false]}
    || {_authoredStationary};
// Passenger squads can hear their own vehicle crew without acquiring exact target knowledge.
// Run this lightweight own-vehicle check at every distance tier: the far cadence is already
// bounded, and suppressing it outside FarRange made separate passenger squads unable to react.
if (!_ordered && {_visible isEqualTo []}
    && {(_state getOrDefault ["phase",""]) in ["CALM","CONTACT"]}) then {
    [_group,_state] call WAIT_fnc_CortexOnboardContact;
};
// Retry calm boarding on the current owner only; a different assigned vehicle retires our intent. A missing seat or moving
// vehicle is temporary, not grounds to forget the passenger after one attempt.
private _remount = _group getVariable ["WAIT_Cortex_Remount",[]];
if (_remount isNotEqualTo []) then {
    _remount params ["_deadline","_passengers"];
    private _pending = _passengers select {alive (_x select 0) && {group (_x select 0) == _group} && {alive (_x select 1)} && {vehicle (_x select 0) != (_x select 1)} && {isNull assignedVehicle (_x select 0) || {assignedVehicle (_x select 0) == (_x select 1)}}};
    private _cancel = _visible isNotEqualTo [] || {_dangerActive} || {_ordered}
        || {!([] call _mayIssueMovement)}
        || {!(["WAIT_AIPass_Vehicles_Enable",true] call _get)}
        || {!(["WAIT_AIPass_VehicleRemount_Enable",true] call _get)};
    if (_cancel || {serverTime >= _deadline} || {_pending isEqualTo []}) then {
        // A danger response can exist before native knowledge produces a visible enemy. Preserve
        // the still-dismounted passengers and cancel boarding now so the same tick can enter its
        // combat response without losing task ownership or issuing another GET IN command.
        if (_visible isNotEqualTo [] || {_dangerActive}) then {_state set ["dismounted",+_pending]};
        {
            private _unit=_x select 0;
            if ([] call _mayIssueMovement && {local _unit} && {isNull objectParent _unit}
                && {assignedVehicle _unit == (_x select 1)}) then {
                [_unit] orderGetIn false;
                unassignVehicle _unit;
            };
        } forEach _pending;
        private _reason = if (_visible isNotEqualTo [] || {_dangerActive}) then {"CONTACT"} else {
            if (_ordered) then {"ORDERED"} else {
                if (!([] call _mayIssueMovement)) then {"EXTERNAL_OWNER"} else {
                    if (_cancel) then {"DISABLED"} else {
                        if (_pending isEqualTo []) then {"RESOLVED_OR_REASSIGNED"} else {"DEADLINE"}
                    }
                }
            }
        };
        // Record this finite transition, not a polling stream. Speed and assignment distinguish
        // unavailable boarding geometry from contact, external orders and actual seat completion.
        private _evidence = _pending apply {
            _x params ["_unit","_vehicle"];
            [netId _unit,netId _vehicle,abs speed _vehicle,_unit distance2D _vehicle,
                netId assignedVehicle _unit,currentCommand _unit]
        };
        _state set ["lastRemountEnd",[serverTime,_reason,_evidence]];
        if (_pending isNotEqualTo []) then {
            diag_log format ["[WAIT] Remount ended group=%1 reason=%2 evidence=%3",_group,_reason,_evidence];
        };
        _group setVariable ["WAIT_Cortex_Remount",nil,true];
    } else {
        // Publish progress only when membership changes. Completed/reassigned passengers must
        // not consume the vehicle owner's bounded boarding window ahead of remaining actors.
        if (_pending isNotEqualTo _passengers) then {
            _group setVariable ["WAIT_Cortex_Remount",[_deadline,+_pending],true];
        };
        {
            _x params ["_unit","_vehicle"];
            // Boarding needs the vehicle owner's cooperation too. Keep the request bounded
            // by this remount episode; its owner verifies the public passenger record.
            if ([] call _mayIssueMovement && {local _unit} && {_unit distance2D _vehicle <= 100}) then {
                _vehicle setVariable ["WAIT_Cortex_DismountStopRequest",
                    [_group,groupOwner _group,(serverTime+30) min _deadline],true];
            };
            if ([] call _mayIssueMovement && {[_unit,_vehicle,true] call WAIT_fnc_CortexPassengerReady}) then {
                // Preserve an in-progress boarding path; retry only a missing/interrupted order.
                if (assignedVehicle _unit != _vehicle) then {_unit assignAsCargo _vehicle};
                if ([] call _mayIssueMovement && {toUpperANSI (currentCommand _unit) != "GET IN"}) then {[_unit] orderGetIn true};
            };
        } forEach _pending;
    };
};
private _contactDelay = if (_tacticalTier) then {["WAIT_AIPass_TickContact", 2] call _get} else {_delay};
// A local danger event wakes this existing job. Do not wait for the distance-tier cadence before
// it re-evaluates native knowledge, but do not create an additional job or issue movement here.
if (_dangerTactical || {_dangerVehicleSafety} || {_dangerAlert}) then {_contactDelay=_contactDelay min 0.5; _delay=_delay min 0.5};

private _areaMode = _state getOrDefault ["areaInvestigation",""];
if (_areaMode != "" && {(!([_group,"WAIT_AIPass_Investigate_Enable",true] call WAIT_fnc_CortexFeatureEnabled))
    || {!([_group,["WAIT_AIPass_ContactReports_Enable","WAIT_AIPass_Hearing_Enable"] select (_areaMode == "SOUND"),true] call WAIT_fnc_CortexFeatureEnabled)}}) then {
    [_group,_state,true,false,"INVESTIGATION_GATE_CLOSED"] call WAIT_fnc_CortexRestoreCalm;
    _state deleteAt "areaInvestigation";
};
// Runtime switches are authoritative permissions, not start-only preferences. A feature
// disabled while it owns an investigation or post-contact search must relinquish that work
// immediately through the same cleanup used by a normal completion. This returns search
// actors, clears only Cortex waypoints/settings and prevents a disabled phase lingering until
// its ordinary timeout. CONTACT is deliberately unaffected: its independent behaviours are
// gated where they run, while the core contact state remains responsible for handover.
private _activePhase = _state getOrDefault ["phase","CALM"];
private _phaseGateClosed = (_activePhase == "INVESTIGATE"
        && {!(["WAIT_AIPass_Investigate_Enable",true] call _get)})
    || {_activePhase in ["SECURITY","SEARCH","REGROUP"]
        && {!(["WAIT_AIPass_PostContact_Enable",true] call _get)}};
if (_phaseGateClosed) then {
    private _closedReason=["POSTCONTACT_DISABLED","INVESTIGATION_DISABLED"] select (_activePhase == "INVESTIGATE");
    [_group,_state,true,false,_closedReason] call WAIT_fnc_CortexRestoreCalm;
    _activePhase = "CALM";
};

// Soldiers holding ground from a finished drill rejoin once the leader has caught up with them.
// A previous completed bound must not issue doFollow over a replacement drill.
// Transfer these actors out of old holding ownership before considering reunion.
private _ownedMovers = _activeDrill getOrDefault ["units",[]];
private _holders = (_state getOrDefault ["holders", []]) select {alive _x && {local _x} && {group _x == _group} && {!(_x in _ownedMovers)}};
_state set ["holders",_holders];
// A completed coordinated bound still belongs to the squad-level MOVE/COVER cycle.
// Keep its hold record for release, but do not regroup between successive bounds.
if (_holders isNotEqualTo [] && {!(_state getOrDefault ["assaulting",false])}) then {
    private _rejoin = _holders select {_x distance2D _leader < 30};
    if ([] call _mayIssueMovement) then {{_x doFollow _leader} forEach _rejoin};
    _state set ["holders", _holders - _rejoin];
};

// A reported coordinated objective permits safe covering fire before personal contact.
// Use the existing group tick; CONTACT already invokes this pass below.
if (_tacticalTier && {!_holdFire} && {(_state getOrDefault ["phase",""]) != "CONTACT"}
    && {_state getOrDefault ["assaulting",false]}) then {
    [_group,_state,_enemies] call WAIT_fnc_CortexFireControl;
};

private _enterContact = {
    // Retire a public post-contact continuation immediately. Waiting for the next checkpoint
    // leaves a migration race where a new owner could rebuild an obsolete search over live contact.
    _group setVariable ["WAIT_Cortex_TransitionIntent",nil,true];
    _state deleteAt "areaInvestigation";
    private _contactPosition=if (_visible isNotEqualTo []) then {(_visible select 0) select 1} else {
        // A hit, explosion or suppression may legitimately wake CONTACT before native target
        // knowledge contains a visible actor. Preserve the bounded engine danger position until
        // CortexKnowledge supplies a believed enemy position; selecting an empty visible array
        // previously aborted the group step and left the brain apparently idle.
        _dangerResponse param [1,getPosATL _leader]
    };
    private _contactReason=["DANGER_CONTACT","VISIBLE_CONTACT"] select (_visible isNotEqualTo []);
    [_group,_state,"CONTACT",_contactReason,_now] call WAIT_fnc_CortexSetPhase;
    _state set ["lastSeen", _now];
    _state set ["hadContact", true];
    _state set ["enemyPos", _contactPosition];
    // Preserve whether this engagement ever contained native enemy knowledge. A danger-only wake
    // may use its approximate position for immediate safety, but post-contact SEARCH must not turn
    // that hazard sample into a movement objective after the finite response expires.
    _state set ["contactKnowledge",(_state getOrDefault ["contactKnowledge",false]) || {_hasTargetKnowledge}];
    _state set ["contactLeader", _leader];
    // Contact does not revoke a server-reserved rally. SupportMaintain owns its
    // deadline and arrival; otherwise responders abandon the rendezvous on sighting.
};
private _beginContact = {
    if !("baseBehaviour" in _state) then {
        _state set ["baseBehaviour", behaviour _leader];
        _state set ["baseSpeed", speedMode _group];
        _state set ["behaviourChanged", false];
        _state set ["speedChanged", false];
    };
    if ([] call _mayIssueMovement) then {
        {
            private _actorMove = _x getVariable ["WAIT_Cortex_ActorMove",[]];
            if (alive _x && {local _x} && {count _actorMove != 3 || {_now >= (_actorMove select 2)}}) then {
                _x doFollow _leader
            };
        } forEach (_state getOrDefault ["searchTeam", []]);
    };
    _state set ["searchTeam", []];
    if (!_groupMovementOwned && {!(_state getOrDefault ["responding", false])} && {!(_state getOrDefault ["assaulting", false])}) then {[_group] call WAIT_fnc_CortexGroupMoveClear};
    call _enterContact;
    // A coordinated responder already has a finite assault movement order. Do not
    // lock the entire approach into script-forced COMBAT bounding; native
    // AUTOCOMBAT remains enabled and can still react to threats normally.
    if (!(_state getOrDefault ["assaulting", false]) && {behaviour _leader in ["SAFE", "AWARE"]}) then {
        _group setBehaviour "COMBAT";
        _state set ["behaviourChanged", true];
    };
    if (_visible isNotEqualTo [] && {_tacticalTier}
        && {["WAIT_AIPass_ContactReports_Enable", true] call _get}) then {
        [_group, _state, _visible] call WAIT_fnc_CortexContactReport;
    };
    // The first fresh contact may occur outside the player-proximity cadence. Publish one bounded
    // combined-arms opportunity here so distant AI can cooperate naturally; ongoing refreshes remain
    // in the near CONTACT tier below and the request cooldown rejects a duplicate in this tick.
    if (!_holdFire && {_visible isNotEqualTo []}
        && {["WAIT_AIPass_ContactReports_Enable",true] call _get}) then {
        [_group,_state,_visible] call WAIT_fnc_CortexCombinedArmsRequest;
    };
    // Shared support discovery is needed by either ordinary reinforcement or coordinated assault.
    // It is a bounded once-per-engagement request, so first contact may publish it outside the
    // player-detail tier without enabling the expensive near-tier combat loop.
    if (!_holdFire && {_visible isNotEqualTo []} && {!_ordered} && {(["WAIT_AIPass_Reinforce_Enable",true] call _get)
        || {["WAIT_AIPass_CoordinatedAssault_Enable",true] call _get}}) then {
        [_group, _state] call WAIT_fnc_CortexReinforce;
    };
    if (["WAIT_AIPass_Debug", false] call _get) then {
        diag_log format ["[WAIT] %1 CONTACT enemies=%2 seen=%3", _group, count _enemies, _seenCount];
    };
    _delay = _contactDelay;
};

switch (_state get "phase") do {
    case "CALM": {
        if (_state getOrDefault ["responding", false]) then {
            private _requester = _state getOrDefault ["respondingTo", grpNull];
            // Read only: never create pass state on the requester's group from here.
            private _requesterPhase = if (isNull _requester) then {"CALM"} else {
                _requester getVariable ["WAIT_AIPass_PublicPhase", "CALM"]
            };
            if (isNull _requester || {({alive _x} count units _requester) == 0} || {_requesterPhase == "CALM"}
                || {_now > (_state getOrDefault ["respondUntil", 0])}) then {
                private _supportLease = _group getVariable ["WAIT_AIPass_SupportLease",[]];
                private _supportToken = _state getOrDefault ["supportToken",""];
                if (count _supportLease == 6 && {_supportToken == (_supportLease select 0)}) then {
                    [_group,_supportToken,false,_supportLease,clientOwner] remoteExecCall ["WAIT_fnc_CortexSupportAck",2];
                };
                private _ownedMovement = _state getOrDefault ["movementLease",[]];
                if (count _ownedMovement == 2
                    && {(_ownedMovement select 0) in ["SUPPORT_RALLY","COORDINATED_ASSAULT"]}) then {
                    [_group] call WAIT_fnc_CortexGroupMoveClear;
                    _state deleteAt "movementLease";
                    _movementLease = [];
                    _groupMovementOwned = false;
                };
                [_group,"SUPPORT",false] call WAIT_fnc_CortexOwnershipLease;
                {_state deleteAt _x} forEach [
                    "supportHeld","supportBoundSequence","supportToken","responding","respondingTo",
                    "respondUntil","arrivedAt","assaulting"
                ];
            } else {
                // Arrival is measured by SupportMaintain in every contact phase.
            };
        };
        // A validated native danger event is itself a combat-state trigger. It carries no shooter
        // identity or target knowledge, but leaving the public phase at CALM after a hit, explosion,
        // suppression or hostile near-fire response delayed withdrawal, support and cleanup until a
        // separate visual contact arrived. Enter the same finite CONTACT state now; native knowledge
        // remains the only source of enemies and target positions.
        if (_dangerTactical || {_dangerVehicleContact} || {_visible isNotEqualTo []}) exitWith {call _beginContact};
        private _area = _group getVariable ["WAIT_AIPass_AreaReport",[]];
        if (_area isNotEqualTo [] && {serverTime >= (_area select 2)}) then {_group setVariable ["WAIT_AIPass_AreaReport",nil,true]; _area = []};
        private _investigationPreference=[_group, "investigateChance"] call WAIT_fnc_CortexProfile;
        private _investigationRange=(["WAIT_AIPass_Investigate_Range",300] call _get) * (0.5 + 0.5 * _investigationPreference);
        if (!_ordered && {!_groupMovementOwned} && {!(_state getOrDefault ["responding",false])} && {_enemies isEqualTo []} && {_area isNotEqualTo []}
            && {["WAIT_AIPass_Investigate_Enable",true] call _get} && {!([_state,"investigate"] call WAIT_fnc_CortexCooldown)}
            && {_investigationPreference > 0}
            && {leader _group distance2D (_area select 0) <= _investigationRange}
            && {[_group, ["WAIT_AIPass_ContactReports_Enable","WAIT_AIPass_Hearing_Enable"] select ((_area select 3) == "SOUND"),true] call WAIT_fnc_CortexFeatureEnabled}) then {
            [_state,"investigate",120] call WAIT_fnc_CortexCooldown;
            private _target = _area select 0;
            [_group,_target getPos [30,_target getDir leader _group],25] call WAIT_fnc_CortexGroupMove;
            [_group,_state,"INVESTIGATE","AREA_REPORT",_now] call WAIT_fnc_CortexSetPhase;
            _state set ["enemyPos",_target];
            _state set ["areaInvestigation",_area select 3];
            _group setVariable ["WAIT_AIPass_AreaReport",nil,true];
        };

        if (!_ordered && {!_groupMovementOwned} && {!(_state getOrDefault ["responding", false])} && {_enemies isNotEqualTo []}
            && {["WAIT_AIPass_Investigate_Enable", true] call _get}
            && {_investigationPreference > 0}
            && {((_enemies select 0) select 3) <= _investigationRange}
            && {!([_state, "investigate"] call WAIT_fnc_CortexCooldown)}) then {
            if (_investigationPreference > 0) then {
                [_state, "investigate", 120] call WAIT_fnc_CortexCooldown;
                private _target = (_enemies select 0) select 1;
                _state set ["baseBehaviour", behaviour _leader];
                _state set ["baseSpeed", speedMode _group];
                _state set ["behaviourChanged", false];
                _state set ["speedChanged", false];
                if (behaviour _leader == "SAFE") then {
                    _group setBehaviour "AWARE";
                    _state set ["behaviourChanged", true];
                };
                private _onFoot = _alive select {local _x && {isNull objectParent _x}};
                private _team = [];
                // A two-man team only checks out nearby contacts; a farther one takes the whole squad.
                if (count _onFoot >= 4 && {(_leader distance2D _target) <= 150}) then {
                    _team = (_onFoot select {_x != _leader && {([_x] call WAIT_fnc_CortexUnitRole) == "RIFLE"}}) select [0, 2];
                };
                if (_team isEqualTo []) then {
                    [_group, _target getPos [30, _target getDir _leader], 25] call WAIT_fnc_CortexGroupMove;
                } else {
                    if ([] call _mayIssueMovement) then {
                        {_x doMove (_target getPos [4 + _forEachIndex * 4, random 360])} forEach _team;
                    };
                    {if (!(_x in _team) && {local _x}) then {_x doWatch _target}} forEach _alive;
                };
                _state set ["searchTeam", _team];
                _state set ["enemyPos", _target];
                [_group,_state,"INVESTIGATE","KNOWN_CONTACT",_now] call WAIT_fnc_CortexSetPhase;
                missionNamespace setVariable ["WAIT_AIPass_Investigations", (missionNamespace getVariable ["WAIT_AIPass_Investigations", 0]) + 1];
                _delay = 3;
            };
        };
    };
    case "INVESTIGATE": {
        if (_visible isNotEqualTo []) exitWith {
            {if (local _x) then {_x doWatch objNull}} forEach _alive;
            call _beginContact;
        };
        private _team = (_state getOrDefault ["searchTeam", []]) select {alive _x && {local _x}};
        private _target = _state getOrDefault ["enemyPos", getPosATL _leader];
        private _moving = (waypoints _group) findIf {(_x select 1) >= currentWaypoint _group && {waypointDescription _x == "WAIT AI PASS"}} >= 0;
        private _done = (_team isNotEqualTo [] && {_team findIf {_x distance2D _target > 15} < 0})
            || {_team isEqualTo [] && {!_moving}}
            || {_now - (_state get "phaseStart") > (["WAIT_AIPass_Investigate_Seconds", 60] call _get)};
        if (_done) then {
            if (_alive findIf {_x call _hasLiveActorMove} >= 0) then {
                _delay = 2;
            } else {
                {if (local _x) then {_x doWatch objNull}} forEach _alive;
                [_group, _state, true, false, ["INVESTIGATION_COMPLETE","INVESTIGATION_TIMEOUT"] select (_now - (_state get "phaseStart") > (["WAIT_AIPass_Investigate_Seconds", 60] call _get))] call WAIT_fnc_CortexRestoreCalm;
            };
        } else {
            _delay = 3;
        };
    };
    case "CONTACT": {
        _delay = _contactDelay;
        if (_visible isNotEqualTo []) then {
            _state set ["lastSeen", _now];
            _state set ["enemyPos", (_visible select 0) select 1];
            _state set ["contactKnowledge",true];
        };
        // Native knowledge may arrive after a targetless engine danger wake while terrain still
        // occludes the enemy. Preserve that real contact before the short danger lease expires so
        // the group can continue finite tactics and the ordinary lost-contact flow.
        if (_hasTargetKnowledge) then {
            _state set ["contactKnowledge",true];
            if (_visible isEqualTo []) then {_state set ["enemyPos",+((_enemies select 0) select 1)]};
        };
        private _outcome = "";
        if (["WAIT_AIPass_Morale_Enable", true] call _get) then {
            _outcome = [_group, _state, _enemies] call WAIT_fnc_CortexMorale;
        };
        if (_outcome == "SURRENDER") exitWith {[_group] call WAIT_fnc_CortexSurrender};
        if (_garrisoned || {_defending}) then {
            private _order = if (_garrisoned) then {_group getVariable ["WAIT_AIPass_Garrison", []]} else {_group getVariable ["WAIT_AIPass_Defend", []]};
            private _orderStrength = (_order param [[3, 2] select _garrisoned, count _alive]) max 1;
            if (count _alive / _orderStrength <= (["WAIT_AIPass_Garrison_BreakFraction", 0.5] call _get)) then {
                if (_garrisoned) then {[_group] call WAIT_fnc_CortexGarrisonRelease} else {[_group] call WAIT_fnc_CortexDefendRelease};
                _garrisoned = false;
                _defending = false;
                _ordered = _group getVariable ["WAIT_AIPass_ClearBuilding", false];
            } else {
                if (_defending) then {[_group, _state, _enemies] call WAIT_fnc_CortexDefendStep};
            };
        };
        private _retreatStarted=false;
        // Surrender remains an immediate survival outcome, but an automatic morale withdrawal is
        // still movement ownership. Preserve the authored stationary order and let its native fire,
        // suppression and posture continue instead of replacing it with a WAIT fallback route.
        if (_outcome == "RETREAT" && {!_authoredStationary}) then {
            if (_now >= (_state getOrDefault ["retreatRetryAt",0])) then {
                switch (true) do {
                    case (_garrisoned): {[_group] call WAIT_fnc_CortexGarrisonRelease};
                    case (_defending): {[_group] call WAIT_fnc_CortexDefendRelease};
                    case (_group getVariable ["WAIT_AIPass_ClearBuilding", false]): {[_group] call WAIT_fnc_CortexClearRelease};
                };
                // The release above only relinquishes the previous movement owner. Every broken
                // non-surrendering squad still attempts the common physical withdrawal state.
                _retreatStarted=[_group, _state] call WAIT_fnc_CortexRetreat;
                if (!_retreatStarted) then {
                    // A dry route may genuinely not exist. Do not spend every contact tick planning
                    // the same impossible move, and do not skip fire control/tactics while waiting.
                    _state set ["retreatRetryAt",_now+10];
                } else {
                    _state deleteAt "retreatRetryAt";
                };
            };
        };
        if (_retreatStarted) exitWith {};
        // A useful empty emplacement is an actor-level support opportunity, not a competing group
        // operation. One nonleader may take its real gunner seat while the remaining squad retains
        // fire, manoeuvre and casualty decisions. The helper samples only once per contact episode.
        if (_hasTargetKnowledge && {!_holdFire}) then {
            [_group,_state,_enemies] call WAIT_fnc_CortexStaticSupport;
        } else {
            [_group,_state,[]] call WAIT_fnc_CortexStaticSupport;
        };
        _state set ["armourSeen", (_state getOrDefault ["armourSeen", false]) || {_enemies findIf {
            private _enemy = vehicle (_x select 0);
            (_enemy isKindOf "Tank" || {_enemy isKindOf "Wheeled_APC_F"}) && {(_x select 2) <= 60} && {(_x select 3) <= 800}
        } >= 0}];
        if (_tacticalTier) then {
            private _vehicleOwnsMovement = _groupMovementOwned;
            {
                if (local _x && {!(_x getVariable ["WAIT_AIPass_Spotter", false])} && {binocular _x != ""} && {currentWeapon _x == binocular _x} && {primaryWeapon _x != ""}) then {
                    _x selectWeapon (primaryWeapon _x);
                };
            } forEach _alive;
            if (!_holdFire && {["WAIT_AIPass_FireControl_Enable", true] call _get}) then {[_group, _state, _enemies] call WAIT_fnc_CortexFireControl};
            if (["WAIT_AIPass_Stance_Enable", true] call _get) then {[_group, _state, _enemies] call WAIT_fnc_CortexStance};
            if (!_holdFire && {_hasTargetKnowledge} && {["WAIT_AIPass_AntiArmour_Enable", true] call _get}) then {[_group, _state, _enemies] call WAIT_fnc_CortexAntiArmour};
            if (["WAIT_AIPass_Vehicles_Enable", true] call _get) then {
                _vehicleOwnsMovement = [_group, _state, _enemies] call WAIT_fnc_CortexVehicles;
            };
            if ((["WAIT_AIPass_ContactReports_Enable", true] call _get) && {_now - (_state getOrDefault ["lastReport", -1e6]) >= 20}) then {
                [_group, _state, _visible] call WAIT_fnc_CortexContactReport;
            };
            // A fresh observed contact is also a short-lived combined-arms opportunity. This
            // only shares the target with a bounded number of independently capable assets;
            // it creates no rally, readiness barrier or replacement infantry movement order.
            if (!_holdFire && {["WAIT_AIPass_ContactReports_Enable",true] call _get}) then {
                [_group,_state,_visible] call WAIT_fnc_CortexCombinedArmsRequest;
            };
            if (!_holdFire && {_hasTargetKnowledge} && {["WAIT_AIPass_Artillery_Enable", false] call _get}) then {[_group, _state, _enemies] call WAIT_fnc_CortexArtilleryRequest};
            if (!_holdFire && {_hasTargetKnowledge} && {!_ordered} && {(["WAIT_AIPass_Reinforce_Enable",true] call _get)
                || {["WAIT_AIPass_CoordinatedAssault_Enable",true] call _get}}) then {[_group, _state] call WAIT_fnc_CortexReinforce};
            // Select one movement owner. A coordinated assault keeps this requester as the
            // base of fire while its responders manoeuvre; it must be decided before a local
            // flank or advance can acquire the same group's movement state.
            private _coordinatedOwnsMovement = _vehicleOwnsMovement;
            if (!_holdFire && {_hasTargetKnowledge} && {!_ordered} && {!_vehicleOwnsMovement} && {["WAIT_AIPass_CoordinatedAssault_Enable", true] call _get}) then {
                _coordinatedOwnsMovement = [_group, _state] call WAIT_fnc_CortexCoordinatedAssault;
            };
            // A fresh, confirmed hostile physically inside a usable building changes the next
            // manoeuvre from open-ground flank/advance into the same finite clearance controller
            // used by explicit orders. Cross-squad support gets first refusal; the building entry
            // never replaces an accepted support/manoeuvre role or an authored Zeus order.
            private _buildingOwnsMovement=false;
            if (!_holdFire && {_hasTargetKnowledge} && {!_ordered} && {!_coordinatedOwnsMovement}) then {
                _buildingOwnsMovement=[_group,_state,_enemies] call WAIT_fnc_CortexBuildingContact;
                if (_buildingOwnsMovement) then {_ordered=true};
            };
            if (!_holdFire && {_hasTargetKnowledge} && {!_ordered} && {!_coordinatedOwnsMovement} && {!_buildingOwnsMovement}) then {
                [_group, _state, _enemies,
                    ["WAIT_AIPass_Flank_Enable", true] call _get,
                    ["WAIT_AIPass_Advance_Enable", true] call _get,
                    ["WAIT_AIPass_Assault_Enable", true] call _get
                ] call WAIT_fnc_CortexTacticalStart;
            };
            if (["WAIT_AIPass_AmmoShare_Enable", true] call _get) then {[_group, _state] call WAIT_fnc_CortexAmmoShare};
        };
        // Full fire-control and route selection remain proximity tiered unless a finite local danger
        // response is active. Once the server has
        // published a bounded responder list, however, the lightweight asynchronous handoff must
        // still complete for distant AI or the valid operation remains permanently half-created.
        if (!_holdFire && {!_nearTier} && {!_ordered} && {["WAIT_AIPass_CoordinatedAssault_Enable",true] call _get}
            && {(_group getVariable ["WAIT_Cortex_SupportResponders",[]]) isNotEqualTo []}) then {
            [_group,_state] call WAIT_fnc_CortexCoordinatedAssault;
        };
        // Smoke, terrain and buildings can briefly hide a target while a bounded manoeuvre is still
        // making physical progress. Post-contact may take ownership only after that manoeuvre has
        // completed or explicitly aborted; each drill/support lease already has its own finite timeout.
        private _manoeuvreActive = count (_state getOrDefault ["drill",createHashMap]) > 0
            || {_state getOrDefault ["assaulting",false]}
            || {_state getOrDefault ["responding",false]};
        // A hit, explosion or suppression event is useful immediate safety information, but it is
        // not a thirty-second contact. Release the temporary COMBAT posture as soon as the finite
        // danger context ends unless native knowledge or an already-committed manoeuvre justifies it.
        if (!_manoeuvreActive && {!_dangerActive}
            && {!(_state getOrDefault ["contactKnowledge",false])}) exitWith {
            [_group,_state,true,false,"DANGER_EXPIRED"] call WAIT_fnc_CortexRestoreCalm;
            _delay=1;
        };
        if (!_manoeuvreActive
            && {(_state getOrDefault ["phase",""]) == "CONTACT"}
            && {_now - (_state getOrDefault ["lastSeen", _now]) > (["WAIT_AIPass_PostContact_LostSeconds", 30] call _get)}) then {
            if (["WAIT_AIPass_PostContact_Enable", true] call _get) then {
                [_group,_state,"SECURITY","CONTACT_LOST",_now] call WAIT_fnc_CortexSetPhase;
            } else {
                [_group, _state, true, false, "CONTACT_ENDED"] call WAIT_fnc_CortexRestoreCalm;
            };
        };
    };
    case "SECURITY": {
        if (_visible isNotEqualTo []) exitWith {call _beginContact};
        // A carried emplacement deployed by this group may be recovered during the finite security
        // pause. Only its original pair is reserved; the rest of the squad keeps native security.
        // Authored movement cancels packing instead of being delayed or replaced.
        private _staticPack=[_group,_state,[],!_ordered] call WAIT_fnc_CortexStaticDeployStep;
        if (_staticPack in ["PACK_MOVING","PACKING","TAKING"]) exitWith {_delay=1};
        // Responders may finish rallying just as smoke, terrain or a building hides the target.
        // Preserve the prepared action across CONTACT -> SECURITY, then resume the normal search
        // chain as soon as every matching responder has released its finite assault lease.
        private _coordinatedOwnsSecurity = false;
        if (!_holdFire && {!_ordered} && {["WAIT_AIPass_CoordinatedAssault_Enable", true] call _get}) then {
            _coordinatedOwnsSecurity = [_group, _state] call WAIT_fnc_CortexCoordinatedAssault;
        };
        if (_coordinatedOwnsSecurity) exitWith {_delay = 2};
        if (_now - (_state get "phaseStart") < (["WAIT_AIPass_PostContact_SecuritySeconds", 10] call _get)) exitWith {_delay = 2};
        private _searchPos = _state getOrDefault ["enemyPos", []];
        private _team = [];
        if (!_ordered && {count _searchPos >= 2}) then {
            private _riflemen = _alive select {local _x && {_x != _leader} && {isNull objectParent _x} && {([_x] call WAIT_fnc_CortexUnitRole) == "RIFLE"}};
            private _ranked = [];
            {_ranked pushBack [_x distance2D _searchPos, _forEachIndex]} forEach _riflemen;
            _ranked sort true;
            _team = (_ranked select [0, 2]) apply {_riflemen select (_x select 1)};
        };
        if (_team isEqualTo []) exitWith {
            [_group,_state,"REGROUP","NO_SEARCH_TEAM",_now] call WAIT_fnc_CortexSetPhase;
            _delay = 3;
        };
        if ([] call _mayIssueMovement) then {
            {_x doMove (_searchPos getPos [4 + _forEachIndex * 4, random 360])} forEach _team;
        };
        _state set ["searchTeam", _team];
        [_group,_state,"SEARCH","SEARCH_TEAM_SENT",_now] call WAIT_fnc_CortexSetPhase;
        _delay = 3;
    };
    case "SEARCH": {
        private _team = (_state getOrDefault ["searchTeam", []]) select {alive _x && {local _x}};
        private _searchPos = _state getOrDefault ["enemyPos", []];
        private _done = _visible isNotEqualTo [] || {_team isEqualTo []}
            || {_team findIf {_x distance2D _searchPos > 15} < 0}
            || {_now - (_state get "phaseStart") > (["WAIT_AIPass_PostContact_SearchSeconds", 45] call _get)};
        if (_done) then {
            if ([] call _mayIssueMovement) then {
                {_x doFollow _leader} forEach (_team select {!(_x call _hasLiveActorMove)});
            };
            _state set ["searchTeam", []];
            if (_visible isNotEqualTo []) then {call _beginContact} else {
                [_group,_state,"REGROUP","SEARCH_COMPLETE",_now] call WAIT_fnc_CortexSetPhase;
                _delay = 3;
            };
        } else {
            _delay = 3;
        };
    };
    case "REGROUP": {
        if (_visible isNotEqualTo []) exitWith {
            _state deleteAt "consolidationRoutes";
            _group setVariable ["WAIT_Cortex_Consolidation", ["CONTACT", 0, 0, 0], true];
            call _beginContact;
        };
        // Explicit holding orders and the post-contact gate outrank automatic consolidation.
        if (_ordered || {!(["WAIT_AIPass_PostContact_Enable", true] call _get)}) exitWith {
            [_group, _state, true, false, ["POSTCONTACT_DISABLED","AUTHORED_ORDER"] select _ordered] call WAIT_fnc_CortexRestoreCalm;
        };
        if (["WAIT_AIPass_AmmoShare_Enable", true] call _get) then {[_group, _state] call WAIT_fnc_CortexAmmoShare};
        private _members = _alive select {
            local _x && {isNull objectParent _x} && {lifeState _x != "INCAPACITATED"}
                && {_x checkAIFeature "PATH"} && {_x checkAIFeature "MOVE"}
        };
        private _reserved = _members select {_x call _hasLiveActorMove};
        // Preserve authored waypoints and combat targets. Each separated member receives one committed
        // local destination. Progress updates the record without issuing another command; the same
        // destination is retried once only after measured no-progress. Reaching that destination while
        // the living leader has moved is the meaningful event that permits a new short destination.
        // This avoids the old eight-second destination churn that repeatedly restarted engine planning.
        private _routes = _state getOrDefault ["consolidationRoutes", createHashMap];
        private _eligible = (_members - _reserved) select {_x != _leader};
        private _eligibleKeys = _eligible apply {
            private _key = netId _x;
            if (_key == "") then {_key = str _x};
            _key
        };
        {
            if !(_x in _eligibleKeys) then {_routes deleteAt _x};
        } forEach keys _routes;
        {
            private _unit = _x;
            private _key = netId _unit;
            if (_key == "") then {_key = str _unit};
            private _record = _routes getOrDefault [_key, []];
            if (_unit distance2D _leader <= 8) then {
                _routes deleteAt _key;
            } else {
                if (_record isEqualTo []) then {
                    private _slot = 4 + ((_forEachIndex mod 3) * 2);
                    private _target = (getPosATL _leader) getPos [_slot, (_forEachIndex * 137) mod 360];
                    if ([] call _mayIssueMovement) then {
                        _unit doMove _target;
                        _routes set [_key, [_target, getPosATL _unit, _now, 0]];
                        _state set ["holders", []];
                    };
                } else {
                    _record params ["_target", "_lastPos", "_lastProgressAt", "_retries"];
                    if (_unit distance2D _lastPos >= 2) then {
                        _record set [1, getPosATL _unit];
                        _record set [2, _now];
                        _routes set [_key, _record];
                    } else {
                        if (_unit distance2D _target <= 4) then {
                            _routes deleteAt _key;
                        } else {
                            if (_now - _lastProgressAt >= 10 && {_retries < 1} && {[] call _mayIssueMovement}) then {
                                _unit doMove _target;
                                _record set [2, _now];
                                _record set [3, _retries + 1];
                                _routes set [_key, _record];
                            };
                        };
                    };
                };
            };
        } forEach _eligible;
        _state set ["consolidationRoutes", _routes];
        private _radius = (12 + 2 * count _members) min 30;
        private _gathered = {_x distance2D _leader <= _radius} count _members;
        private _furthest = 0;
        {_furthest = _furthest max (_x distance2D _leader)} forEach _members;
        private _closed = _reserved isEqualTo [] && {_gathered == count _members};
        private _expired = _now - (_state get "phaseStart") > (["WAIT_AIPass_PostContact_RegroupSeconds", 30] call _get);
        private _status = if (_closed) then {"COHESIVE"} else {["CONSOLIDATING", "INCOMPLETE"] select _expired};
        private _snapshot = [_status, _gathered, count _members, round _furthest];
        if (_snapshot isNotEqualTo (_group getVariable ["WAIT_Cortex_Consolidation", []])) then {
            _group setVariable ["WAIT_Cortex_Consolidation", _snapshot, true];
        };
        if (_closed || {_expired}) then {
            // Expiry releases control but remains INCOMPLETE; it is never reported as arrival.
            [_group, _state, true, false, ["REGROUP_TIMEOUT","REGROUP_COHESIVE"] select _closed] call WAIT_fnc_CortexRestoreCalm;
        } else {
            _delay = 3;
        };
    };
    case "RETREAT": {
        _delay = 3;
        if ((["WAIT_AIPass_Morale_Enable", true] call _get)
            && {([_group, _state, _enemies] call WAIT_fnc_CortexMorale) == "SURRENDER"}) exitWith {[_group] call WAIT_fnc_CortexSurrender};
        // Withdrawal uses the same participant progress record as every other manoeuvre. One
        // lagging survivor gets a single physical follow-up but never holds the surviving element
        // in place or causes a fresh group-wide route churn.
        private _operation=_group getVariable ["WAIT_Operation",createHashMap];
        private _generation=_state getOrDefault ["withdrawOperationGeneration",-1];
        private _operationState="ACTIVE";
        if (count _operation > 0 && {(_operation getOrDefault ["intent",""]) == "WITHDRAW"}
            && {(_operation getOrDefault ["generation",-2]) == _generation}) then {
            _operationState=[_group,_generation,3,15] call WAIT_fnc_OperationStep;
            // OperationStep can quarantine a previous straggler. Re-read the record before choosing
            // another actor so one exhausted recovery cannot monopolise every withdrawal check.
            _operation=_group getVariable ["WAIT_Operation",createHashMap];
            if (time-(_operation getOrDefault ["startedAt",time]) >= 8) then {
                private _unavailable=_operation getOrDefault ["unavailable",[]];
                private _recovery=_operation getOrDefault ["recovery",createHashMap];
                private _straggler=(_operation getOrDefault ["participants",[]]) findIf {
                    private _recoveryRecord=_recovery getOrDefault [netId _x,[]];
                    alive _x && {local _x} && {isNull objectParent _x}
                        && {!(_x in _unavailable)}
                        && {!(_recoveryRecord isEqualType [] && {count _recoveryRecord >= 2} && {(_recoveryRecord select 0) > 0})}
                        && {_x distance2D _leader > 35} && {speed _x < 1}
                };
                if (_straggler >= 0) then {
                    [_group,_generation,(_operation get "participants") select _straggler,getPosATL _leader] call WAIT_fnc_RecoveryStep;
                };
            };
        };
        // A replacement generation owns the route now. This exits only the RETREAT phase scope,
        // leaving the new finite controller intact and avoiding any old-route cleanup or replan.
        if (_operationState in ["ZEUS","EXTERNAL","LOST_OWNER","REPLACED"]) exitWith {
            _delay=1;
        };
        private _reversing=(_group getVariable ["WAIT_VehicleReverse",[]]) isNotEqualTo [];
        private _moving = _reversing || {(waypoints _group) findIf {(_x select 1) >= currentWaypoint _group && {waypointDescription _x == "WAIT AI PASS"}} >= 0};
        private _start = _state getOrDefault ["retreatStart",getPosATL _leader];
        private _travel = _leader distance2D _start;
        private _progress = _state getOrDefault ["retreatProgress",[_now,0,0]];
        _progress params ["_progressAt","_bestTravel","_replans"];
        // Only net withdrawal counts. Sideways or back-and-forth motion must not keep a
        // broken route alive forever merely because the actor crossed a three-metre circle.
        if (_travel >= _bestTravel+3) then {
            _progressAt = _now;
            _bestTravel = _travel;
        };
        private _shortWithdrawal = !_moving && {_travel < 30};
        private _stalled = _moving && {_now-_progressAt >= 15};
        if ((_shortWithdrawal || {_stalled}) && {_replans < 4}) then {
            private _enemyPos = _state getOrDefault ["enemyPos",[]];
            private _target = _state getOrDefault ["retreatTarget",getPosATL _leader];
            private _distance = ((_leader distance2D _target) max 80) min 250;
            private _away = if (count _enemyPos >= 2) then {_enemyPos getDir _leader} else {(getDir _leader)+180};
            private _origin=getPosATL _leader;
            private _candidateRoutes=[];
            {
                private _candidate=_origin getPos [_distance,_away+_x];
                // A confirmed obstruction must not select the same failed destination again.
                if (_candidate distance2D _target >= 20) then {_candidateRoutes pushBack [_candidate]};
            } forEach [30,-30,60,-60];
            private _legs=if (count _enemyPos >= 2) then {
                [_origin,_candidateRoutes,_enemyPos] call WAIT_fnc_CortexSelectAvenue
            } else {
                _candidateRoutes param [0,[]]
            };
            if (_legs isNotEqualTo []) then {
                private _candidate=+(_legs select ((count _legs)-1));
                [_group,_candidate,30] call WAIT_fnc_CortexGroupMove;
                _state set ["retreatTarget",_candidate];
                _replans = _replans+1;
                _progressAt = _now;
                _bestTravel = _travel;
                _moving = true;
            };
        };
        _state set ["retreatProgress",[_progressAt,_bestTravel,_replans]];
        private _intent = _group getVariable ["WAIT_Cortex_WithdrawalIntent",[]];
        if (count _intent == 7) then {
            _intent set [2,+(_state getOrDefault ["retreatTarget",_intent select 2])];
            _intent set [5,_replans];
            _intent set [6,_bestTravel];
            _group setVariable ["WAIT_Cortex_WithdrawalIntent",_intent,true];
        };
        private _timedOut = _now - (_state get "phaseStart") > 120;
        private _status = if (_timedOut) then {"INCOMPLETE"} else {["MOVING","WITHDRAWN"] select (!_moving && {_travel >= 30})};
        _group setVariable ["WAIT_Cortex_Withdrawal",[_status,round _travel,_replans],true];
        if ((!_moving && {_travel >= 30}) || {_timedOut}) then {
            _operation=_group getVariable ["WAIT_Operation",createHashMap];
            _generation=_state getOrDefault ["withdrawOperationGeneration",-1];
            if (count _operation > 0 && {(_operation getOrDefault ["intent",""]) == "WITHDRAW"}) then {
                [_group,_generation,["COMPLETE","INCOMPLETE"] select _timedOut,["OBJECTIVE_REACHED","TIMEOUT"] select _timedOut] call WAIT_fnc_OperationRelease;
            };
            [_group,"INFANTRY_WITHDRAW",false] call WAIT_fnc_CortexOwnershipLease;
            [_group] call WAIT_fnc_CortexGroupMoveClear;
            _group setVariable ["WAIT_Cortex_WithdrawalIntent",nil,true];
            [_group,_state,"REGROUP",["WITHDRAWAL_COMPLETE","WITHDRAWAL_TIMEOUT"] select _timedOut,_now] call WAIT_fnc_CortexSetPhase;
        };
    };
};
// Reaction speed (AI Tuning): above 1 squads re-assess more often, below 1 less often. A small,
// zero-mean jitter keeps groups off the same scheduler frame and spreads both CPU work and fire orders.
private _reaction = (missionNamespace getVariable ["WAIT_AIPass_ReactionSpeed", 1]) max 0.25;
private _cadence = _delay / _reaction;
(_cadence + random 0.7 - 0.35) max 0.5

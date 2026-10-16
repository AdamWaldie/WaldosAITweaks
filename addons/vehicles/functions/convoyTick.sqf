/*
 * Author: WaldoTheWarfighter
 * Gate approach: current forward gate/barrier geometry contributes to the existing safety cap;
 * it suppresses queue recovery; nearby opening requests are server-validated and never grant passage.
 * Drives mixed convoys along each predecessor trail, detects arrival and requests a persistent halt after pinned contact.
 * Locality/authority: server owns phase; group owner drives and reports, each cargo/turret owner applies crew work.
 * Spacing uses a size-aware target with a 20 percent tolerance band (at least 3 m).
 * Aligned vehicles use unit horizontal bearings for forward separation, so pitch cannot shrink
 * the measured gap and lateral spread cannot satisfy it or stabilize a wedge.
 * Speed corrects toward the target; the tolerance band bounds catch-up and stronger close-gap braking.
 * Excess stretch beyond the upper band adds a nonlinear catch-up correction capped at 8 km/h.
 * Native acceleration, shared cruise/terrain limits, immediate closing caps and reverse yields remain authoritative.
 * Follower curve/grade caps persist between path refreshes until fresh trail geometry replaces them;
 * disabling convoy driving assist clears that local cap without changing native route ownership.
 * Acceleration is bounded; outside contact the lead slows to let stretched followers catch up.
 * Lead catch-up pacing reuses the same aligned longitudinal gap as stretch assessment, so
 * lateral drift alone does not create a false rearward gap or feed acceleration lag forward.
 * The lead alone uses registered corridor approach/crossing through this same callback. Active
 * corridors suppress lead route recovery; followers keep measured predecessor trails and spacing.
 * Finite static-obstacle bypass shares this lead writer. Followers yield only the exact source
 * cap after fresh committed-trail leg validation (at most 15 rays per affected follower/tick).
 * That relaxation requires exactly one same-floor capture cluster among at most eleven points;
 * ambiguous self-near trails retain the obstacle constraint without changing the path.
 * Follower cursors advance through a contiguous same-floor route prefix near the latest
 * at-most-three-second observed sweep; initial joining approaches only the next retained point.
 * Whole-column checkpoint/tail evidence retains the original deadline; lead success is insufficient.
 * Fixed follower paths retain a driver/operator/epoch/native-command receipt for guarded handback.
 * The receipt is ownership evidence only; it cannot establish actual path travel.
 * A replacement individual MOVE on a recorded follower operator yields the entire current
 * revision before crew/trail writes. A public revision receipt survives migration; a fresh server
 * task revision is required to re-admit. Cleanup restores exact caps but cannot recall movement.
 * Path refreshes do not repeatedly stop drivers, and tracked vehicles receive longer look-ahead targets.
 * A three-second lead-vehicle road sample anticipates sharp curves, junctions and grades. Speed changes
 * accelerate gradually while safety, contact, arrival and close-gap braking remain immediate.
 * Brief predecessor dips below 2 km/h do not disable smoothing when longitudinal room remains;
 * raw closing-distance limits and reverse/ordered/pedestrian stops remain authoritative.
 * With convoy driving assist enabled, each vehicle samples unrelated forward-lane hulls once per
 * tick (64 candidates, eight corners each). Only its exact registered predecessor is excluded
 * from this observer because size-aware convoy spacing already owns that gap. Up to 20 vehicles
 * are admitted; dense observations stop rather than authorize a recovery through unseen traffic.
 * The route watchdog remembers only the unchanged final MOVE waypoint. If the engine marks it complete
 * more than 75 m early, the same metadata-checked ungated waypoint is selected again; no waypoint is synthesized or rewritten.
 * Repeat/JIP: ordered snapshots carry phase/cargo/baselines; a five-second contact checkpoint survives HC migration.
 * Arguments: 0: group <GROUP>; 1: configuration <ARRAY> [revision, km/h, gap, pushThrough, vehicles, phase, cargo, restore, halt reason, believed threat ATL, expiry].
 * Return Value: Nothing.
 * Current caller: WAIT_fnc_ConvoyOperationStep through the shared owner-local scheduler.
 * Example: [_group, _configuration] call WAIT_fnc_ConvoyTick;
 */
params ["_group", "_configuration"];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {};
if (isNull _group) exitWith {};
_configuration params ["_revision", "_speed", "_separation", "_pushThrough", "_registered", "_phase", "_cargo", "_restore"];
if (time < (_group getVariable ["WAIT_Convoy_NextTick", -1])) exitWith {};
_group setVariable ["WAIT_Convoy_NextTick", time + 1];
private _state = _group getVariable ["WAIT_Convoy_LocalState", createHashMap];
// Convoy may own its own active marker, but must otherwise yield before it reaches crew, route or
// formation commands. A later eligible tick starts from the current native route rather than
// cancelling a possibly newer external order.
if !([_group,false,false,true] call WAIT_fnc_CortexIsEligible) exitWith {
    _state set ["ownerSuspended",true];
    _group setVariable ["WAIT_Convoy_LocalState",_state];
    _group setVariable ["WAIT_Convoy_Suspended",true];
};
if (_state getOrDefault ["ownerSuspended",false]) then {
    // Eligibility can return after another explicit operation has claimed the group.
    // A historical suspended convoy generation cannot erase that successor.
    private _suspendedGeneration=_state getOrDefault ["operationGeneration",-1];
    private _liveOperation=_group getVariable ["WAIT_Operation",createHashMap];
    if (_suspendedGeneration >= 0
        && {(_liveOperation getOrDefault ["intent",""]) == "CONVOY"}
        && {(_liveOperation getOrDefault ["generation",-2]) == _suspendedGeneration}
        && {(_liveOperation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}) then {
        _group setVariable ["WAIT_Operation",nil,true];
    };
    _state set ["ownerSuspended",false];
    _state set ["revision",-1];
    _state set ["reacquire",true];
};
private _externalCrew = _registered findIf {(crew _x) findIf {[_x] call WAIT_fnc_CortexExternalOwner != ""} >= 0} >= 0;
private _globalPaused = [] call WAIT_fnc_CortexIsPaused;
private _paused = _globalPaused || {[_group] call WAIT_fnc_CompatibilityExternalControl} || {_externalCrew} || {"ALL" in (_group getVariable ["WAIT_AIPass_DisabledFeatures",[]])};
private _playerCrew = _registered findIf {(crew _x) findIf {isPlayer _x || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner", objNull])}} >= 0} >= 0;
private _zeus = [_group] call WAIT_fnc_CortexZeusHeld;
if (_paused || {_playerCrew} || {_zeus}) exitWith {
    [_group,_configuration,true] call WAIT_fnc_ConvoyDismountLocal;
    if (!(_group getVariable ["WAIT_Convoy_Suspended", false])) then {
        private _reason = if (_zeus) then {"ZEUS"} else {if (_playerCrew) then {"PLAYER"} else {
            if (_globalPaused && {!_externalCrew} && {!([_group] call WAIT_fnc_CompatibilityExternalControl)}) then {"PAUSED"} else {"EXTERNAL_OWNER"}
        }};
        [_group, false, _restore, [], _reason] call WAIT_fnc_ConvoyReleaseLocal;
        _group setVariable ["WAIT_Convoy_Suspended", true];
        if (local _group) then {_group setVariable ["WAIT_Convoy_ContactProgress", nil, true]};
    };
};
_group setVariable ["WAIT_Convoy_Suspended", false];
// A new individual MOVE is a replacement order, not a stalled convoy leg. Keep this
// revision yielded across later ticks and owner migration; only a new server revision may re-admit.
private _commandYield=_group getVariable ["WAIT_Convoy_CommandYield",[]];
if ((_commandYield param [0,-1]) != _revision) then {
    private _diverted=objNull;private _diversion=[];
    {
        private _vehicle=_x;private _receipt=_vehicle getVariable ["WAIT_Convoy_MovementReceipt",[]];
        private _operator=effectiveCommander _vehicle;
        if (isNull _diverted && {local _vehicle} && {count _receipt == 5}
            && {(_receipt select 0) == _group} && {(_receipt select 1) == _revision}
            && {(_receipt select 2) == driver _vehicle} && {(_receipt select 3) == _operator}
            && {!isNull _operator} && {local _operator} && {currentCommand _operator == "MOVE"}) then {
            private _was=(_receipt select 4) param [0,[]];private _now=(expectedDestination _operator) param [0,[]];
            if (count _was == 3 && {count _now == 3} && {_was vectorDistance _now > 0.25}) then {
                _diverted=_vehicle;_diversion=+_now;
            };
        };
    } forEach _registered;
    if (!isNull _diverted) then {
        _commandYield=[_revision,_diverted,_diversion,serverTime];
        _group setVariable ["WAIT_Convoy_CommandYield",_commandYield,true];
        [_group,false,_restore,[],"NEW_NATIVE_ORDER"] call WAIT_fnc_ConvoyReleaseLocal;
    };
};
if ((_commandYield param [0,-1]) == _revision) exitWith {
    _state=_group getVariable ["WAIT_Convoy_LocalState",createHashMap];
    _state set ["ownerSuspended",true];_group setVariable ["WAIT_Convoy_LocalState",_state];
    _group setVariable ["WAIT_Convoy_Suspended",true];
};
[_group, _configuration] call WAIT_fnc_ConvoyCrewLocal;
if (_phase == "HALT") exitWith {
    _state set ["reacquire",true];
    _group setVariable ["WAIT_Convoy_LocalState",_state];
    if (local _group) then {
        private _generation = _state getOrDefault ["operationGeneration",-1];
        private _reason = toUpperANSI (_configuration param [8,"MANUAL"]);
        if (_generation >= 0) then {
            if (_reason == "ARRIVED") then {[_group,_generation,"COMPLETE","ARRIVED"] call WAIT_fnc_OperationRelease}
            else {[_group,_generation,_reason] call WAIT_fnc_OperationCancel};
        };
    };
};
if (!local _group) exitWith {};
// The convoy tick performs bounded route and gap calculations before it writes any driver command.
// Recheck ownership at each command boundary so a curator or specialist controller that arrives
// during that work receives an immediate clean handover rather than a stale speed or route update.
private _mayIssueDriving = {
    !([_group] call WAIT_fnc_CortexExternalTakeover)
};
// Recovery must not replay authored scripts, conditions, timers or trigger waits.
// These values are inspected, never compiled or executed by the convoy controller.
private _mayRecoverWaypoint={
    params ["_waypoint"];
    private _statements=waypointStatements _waypoint;
    private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
    (_waypoint select 1) > 0 && {waypointType _waypoint == "MOVE"} && {_condition == "true"}
        && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
        && {waypointScript _waypoint == ""}
        && {(waypointTimeout _waypoint param [2,0]) <= 0}
        && {(synchronizedTriggers _waypoint) findIf {!isNull _x && {!triggerActivated _x}} < 0}
};
// A stalled engine route and a deliberate physical roadblock require different Zeus advice.
// This bounded check runs only after the existing recovery attempts are exhausted; it never
// changes the route, collision, vehicle position or the stopped vehicle.  The frontal cone
// deliberately excludes the registered column so a predecessor inside normal convoy spacing
// cannot be misreported as an obstruction.
private _classifyStall = {
    params ["_vehicle"];
    private _origin = getPosATL _vehicle;
    private _bearing=getDir _vehicle;
    private _forward = [sin _bearing,cos _bearing,0];
    private _blocker = (nearestObjects [_vehicle, ["LandVehicle", "Static"], 20, true]) findIf {
        private _candidate = _x;
        !isNull _candidate && {_candidate != _vehicle} && {!(_candidate in _registered)} && {
            private _delta = (getPosATL _candidate) vectorDiff _origin;
            _delta set [2, 0];
            private _distance = vectorMagnitude _delta;
            _distance > 2 && {_distance < 20} && {
                private _forwardDistance = _delta vectorDotProduct _forward;
                private _lateralSquared = ((_distance * _distance) - (_forwardDistance * _forwardDistance)) max 0;
                _forwardDistance > (_distance * 0.45) && {sqrt _lateralSquared < 8}
            }
        }
    };
    ["STALLED", "OBSTRUCTION"] select (_blocker >= 0)
};
// Eligibility and locality are separate questions. An incapacitated driver must
// not count as a remotely owned capable vehicle and freeze every convoy step.
private _mobile = _registered select {alive _x && {canMove _x}
    && {[driver _x] call WAIT_fnc_CortexCombatEffective} && {group driver _x == _group}};
private _vehicles = _mobile select {local _x && {local driver _x}};
// Only a real split among eligible vehicles defers local movement.
if (count _vehicles < count _mobile) exitWith {};
if (_vehicles isEqualTo []) exitWith {
    if (time >= (_state getOrDefault ["haltRequest", -1])) then {
        [_group, _revision, "IMMOBILE"] remoteExecCall ["WAIT_fnc_ConvoyHaltServer", 2];
        _state set ["haltRequest", time + 5];
        _group setVariable ["WAIT_Convoy_LocalState", _state];
    };
};
private _lead = _vehicles select 0;
private _previousLead=_state getOrDefault ["lead",objNull];
if (!isNull _previousLead && {_previousLead != _lead} && {local _previousLead}) then {
    // Stop only the old lead's exact-owned corridor; its replacement/follower acquires its own path.
    [_previousLead,_group,"CONVOY_LEAD_CHANGED",false,true] call WAIT_fnc_DrivingCorridorRelease;
    [_previousLead,_group,"CONVOY_LEAD_CHANGED",false,true] call WAIT_fnc_DrivingBypassRelease;
    [_group,[_revision],"CONVOY_LEAD_CHANGED"] call WAIT_fnc_ConvoyBypassStep;
};
private _leadOperator=effectiveCommander _lead;
if (isNull _leadOperator) then {_leadOperator=driver _lead};
if (!(vehicle leader _group in _vehicles)) then {_group selectLeader driver _lead};
if ((_state getOrDefault ["revision", -1]) != _revision || {(_state getOrDefault ["lead", objNull]) != _lead} || {_vehicles isNotEqualTo (_state getOrDefault ["vehicles", []])}) then {
    // A local halt/resume or speed edit must not discard the predecessor route.
    // Only a changed vehicle order or a new owner needs fresh trail acquisition.
    private _sameLine = _vehicles isEqualTo (_state getOrDefault ["vehicles",[]]);
    private _reacquire=!_sameLine || {_state getOrDefault ["reacquire",false]};
    private _resumePathOwners=if (_reacquire) then {createHashMap} else {_state getOrDefault ["pathOwners",createHashMap]};
    private _resumeSpeedLimits=if (_reacquire) then {createHashMap} else {_state getOrDefault ["speedLimits",createHashMap]};
    private _resumeTrails = if (_sameLine) then {_state getOrDefault ["frontTrails",createHashMap]} else {createHashMap};
    private _resumeFollowers = if (_sameLine) then {_state getOrDefault ["followers",createHashMap]} else {createHashMap};
    // Only a real restart stops/reacquires followers. Preserve the predecessor trail and cursor,
    // but invalidate command commitments so an unchanged endpoint cannot hide that stopped command.
    if (_reacquire) then {
    {private _v=_x; private _key=netId _v; private _record=_resumeFollowers getOrDefault [_key,[]]; if (_record isNotEqualTo []) then {_record set [0,getPosATL _v]; _record set [1,time]; _record set [2,-1]; _record set [5,[]]; _record set [6,[]]; _record set [7,false]}} forEach _vehicles;
    };
    // A revision alone does not relinquish driving authority to native formation.
    if (count _state > 0 && {!_sameLine}) then {[_group, false, _restore, _registered] call WAIT_fnc_ConvoyReleaseLocal};
    private _savedProgress = _group getVariable ["WAIT_Convoy_ContactProgress", []];
    private _progress = if (_savedProgress isNotEqualTo [] && {(_savedProgress select 0) == _revision}) then {+(_savedProgress select 1)} else {[]};
    if !([] call _mayIssueDriving) exitWith {
        [_group,false,_restore,_registered,"EXTERNAL"] call WAIT_fnc_ConvoyReleaseLocal;
    };
    _state = createHashMapFromArray [["revision", _revision], ["lead", _lead], ["frontTrails", _resumeTrails],
        ["heading", getDir _lead], ["vehicles", +_vehicles], ["followers", _resumeFollowers], ["speedLimits", _resumeSpeedLimits], ["contactProgress", _progress]];
    private _objective = if (count waypoints _group > 0) then {waypointPosition [_group,(count waypoints _group)-1]} else {getPosATL _lead};
    private _operation = [_group,"CONVOY",_objective,[],[_objective],"TRAVEL"] call WAIT_fnc_OperationStart;
    _state set ["operationGeneration",_operation getOrDefault ["generation",-1]];
    _state set ["operationDue",time];
    _group setVariable ["WAIT_Convoy_LocalState", _state];
    private _specs = createHashMap;
    {
        private _bounds = boundingBoxReal _x;
        _specs set [netId _x, [getNumber (configOf _x >> "maxSpeed"), abs (((_bounds select 1) select 1) - ((_bounds select 0) select 1))]];
    } forEach _vehicles;
    _state set ["specs", _specs];
    _group setFormation "COLUMN";
    // Vehicle movement remains a convoy task. Mounted gunners can fire without breaking formation.
    _group enableAttack false;
    // Clear a previous HALT doStop on the lead driver without deleting or replacing route waypoints.
    if (_reacquire && {currentWaypoint _group > 0} && {currentWaypoint _group < count waypoints _group}) then {
        // Do not make the lead's native movement operator follow itself or another seat.
        // A same-vehicle subordinate may rejoin; route recovery belongs to the operator.
        if (driver _lead != leader _group && {driver _lead != _leadOperator}
            && {vehicle leader _group == _lead}) then {(driver _lead) doFollow leader _group};
        // Tracked HALT explicitly replaced vehicle movement with a current-position move.
        // Following the commander cannot supersede that vehicle-level destination reliably.
        // Restart only our matching halt once, toward the unchanged ordinary route waypoint.
        private _haltOwner=_lead getVariable ["WAIT_Convoy_HaltOwner",[]];
        private _resumeWaypoint=[_group,currentWaypoint _group];
        if (count _haltOwner == 3 && {(_haltOwner select 0) == _group}
            && {(_haltOwner select 2) == clientOwner} && {waypointType _resumeWaypoint == "MOVE"}
            && {[] call _mayIssueDriving}) then {
            _lead move waypointPosition _resumeWaypoint;
            _lead setVariable ["WAIT_Convoy_HaltOwner",nil];
        };
    };
    {[_x,_group,"ACQUIRE",_revision] call WAIT_fnc_ConvoyUnloadPolicy} forEach _vehicles;
    private _initialPathOwners=_resumePathOwners;
    {
        if (_forEachIndex > 0) then {
            if (_reacquire) then {
            if (isAISteeringComponentEnabled _x && {effectiveCommander _x == driver _x}) then {
                // Relinquish formation before the predecessor has recorded its first trail segment.
                // Waiting for a large gap lets native formation compress/overtake during startup.
                doStop driver _x;
                _initialPathOwners set [netId _x,true];
            } else {
                // Native followers also acquire column control before a forward trail
                // exists. Formation following here can overtake the predecessor.
                private _initialOperator=effectiveCommander _x;
                if (isNull _initialOperator) then {_initialOperator=driver _x};
                doStop _initialOperator;
                private _initialKey=netId _x;
                private _initialProgress=_resumeFollowers getOrDefault [_initialKey,
                    [getPosATL _x,time,-1,0,0,[],[]]];
                _initialProgress set [7,true];
                _resumeFollowers set [_initialKey,_initialProgress];
            };
            };
            _x setConvoySeparation _separation;
        };
    } forEach _vehicles;
    _state set ["pathOwners",_initialPathOwners];
};
private _operationGeneration = _state getOrDefault ["operationGeneration",-1];
private _operationEndReason = "";
if (_operationGeneration >= 0 && {time >= (_state getOrDefault ["operationDue",time])}) then {
    private _operationState = [_group,_operationGeneration,3,120,true] call WAIT_fnc_OperationStep;
    _state set ["operationDue",time+5];
    if (_operationState in ["ZEUS","EXTERNAL","LOST_OWNER","REPLACED"]) then {_operationEndReason = _operationState};
};
// Leave the function before formation, contact or movement can be written. An exitWith nested
// inside the cadence block only left that block and allowed a released convoy to keep driving.
if (_operationEndReason != "") exitWith {
    [_group,false,_restore,_registered,_operationEndReason] call WAIT_fnc_ConvoyReleaseLocal;
};
// Active waypoints can change formation after initial setup. Enforce the convoy
// formation only while this owner controls travel; suspension above preserves Zeus control.
if ([] call _mayIssueDriving && {formation _group != "COLUMN"}) then {_group setFormation "COLUMN"};
// Query existing group knowledge at most every five seconds; never reveal hidden attackers.
if (time >= (_state getOrDefault ["contactDue", -1])) then {
    private _report = [];
    // A rear escort can be under fire while the lead vehicle has no endangered target.
    // One observer per vehicle, at most the registered 20 vehicles, every five seconds.
    {
        private _observer = gunner _x;
        if (isNull _observer || {!local _observer} || {!alive _observer}) then {_observer = driver _x};
        private _candidate = [_observer] call WAIT_fnc_ConvoyThreat;
        if (_candidate isNotEqualTo []) then {
            if (_report isEqualTo [] || {_candidate select 2}) then {_report = _candidate};
        };
        if (_report isNotEqualTo [] && {_report select 2}) exitWith {};
    } forEach _registered;
    private _contact = _report isNotEqualTo [] && {_report select 2};
    _contact = _contact || {_registered findIf {serverTime - (_x getVariable ["WAIT_Convoy_HitAt", -1e9]) <= 15} >= 0}
        || {(units _group) findIf {alive _x && {getSuppression _x > 0.2}} >= 0};
    _state set ["contact", _contact];
    _state set ["threat", if (_report isEqualTo []) then {[]} else {+(_report select 1)}];
    _state set ["contactDue", time + 5];
};
private _contact = _state getOrDefault ["contact", false];
private _pinned = false;
private _contactProgress = _state getOrDefault ["contactProgress", []];
if (_contact) then {
    {
        private _vehicle = _x;
        if (alive _vehicle) then {
            private _index = _contactProgress findIf {(_x select 0) == _vehicle};
            if (_index < 0) then {_contactProgress pushBack [_vehicle, getPosATL _vehicle, serverTime]; _index = count _contactProgress - 1};
            private _entry = _contactProgress select _index;
            if (_vehicle distance2D (_entry select 1) >= 3) then {_entry = [_vehicle, getPosATL _vehicle, serverTime]; _contactProgress set [_index, _entry]};
            if (serverTime - (_entry select 2) >= 15 && {abs speed _vehicle < 3}) then {_pinned = true};
        };
    } forEach _registered;
} else {_contactProgress = []};
_state set ["contactProgress", _contactProgress];
if (time >= (_state getOrDefault ["checkpointDue", -1])) then {
    private _checkpoint = [_revision, _contactProgress apply {+_x}];
    if (_checkpoint isNotEqualTo (_group getVariable ["WAIT_Convoy_ContactProgress", []])) then {_group setVariable ["WAIT_Convoy_ContactProgress", _checkpoint, true]};
    _state set ["checkpointDue", time + 5];
};
if (_contact && {!_pushThrough || {_pinned}} && {[_group,"WAIT_Convoy_ContactHalt_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) exitWith {
    if (time >= (_state getOrDefault ["haltRequest", -1])) then {
        [_group, _revision, "AMBUSH", _state getOrDefault ["threat", []]] remoteExecCall ["WAIT_fnc_ConvoyHaltServer", 2];
        _state set ["haltRequest", time + 5];
    };
};
// Size-aware gaps prevent a long IFV and a truck from being treated like two short cars.
private _gaps = [0];
private _maximum = _speed;
private _specs = _state get "specs";
for "_i" from 0 to (count _vehicles - 1) do {
    private _vehicle = _vehicles select _i;
    private _topSpeed = (_specs get (netId _vehicle)) select 0;
    if (_topSpeed > 0) then {_maximum = _maximum min (_topSpeed * 0.8)};
    if (_i > 0) then {
        private _front = _vehicles select (_i - 1);
        private _lengths = ((_specs get (netId _vehicle)) select 1) + ((_specs get (netId _front)) select 1);
        _gaps pushBack (_separation max (_lengths * 0.5 + 5));
    };
};
private _hadBypass=!isNil {_lead getVariable "WAIT_DrivingBypass_Work"};
private _bypass=[false,1e6,"",false];
private _hadBypassPassage=!isNil {_group getVariable "WAIT_Convoy_BypassPassage"};
private _bypassPassage=[_group,_configuration] call WAIT_fnc_ConvoyBypassStep;
private _bypassPassageActive=_bypassPassage select 0;
private _bypassCaps=_bypassPassage select 1;
if (_hadBypassPassage && {!_bypassPassageActive}) then {
    [_lead,_group,"CONVOY_PASSAGE_ENDED",true,false,_revision] call WAIT_fnc_DrivingBypassRelease;
};
private _corridor=[false,1e6,""];
private _hadCorridor=!isNil {_lead getVariable "WAIT_DrivingCorridor_Work"};
if ([_group,"WAIT_Convoy_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled
    && {!_hadBypass} && {!_bypassPassageActive} && {[] call _mayIssueDriving}) then {
    _corridor=[_group,_lead,_group getVariable ["WAIT_Convoy_Brain",createHashMap],"CONVOY"] call WAIT_fnc_DrivingCorridorStep;
} else {
    if (_hadCorridor) then {[_lead,_group,"CONVOY_ASSIST_RELEASED"] call WAIT_fnc_DrivingCorridorRelease};
};
private _corridorActive=_corridor select 0;
_state set ["corridorPhase",_corridor select 2];
private _passage=[_group,_configuration] call WAIT_fnc_ConvoyCorridorStep;
private _passageActive=_passage select 0;
private _passageCaps=_passage select 1;
if (!_corridorActive && {_passageActive}) then {_state set ["corridorPhase","CORRIDOR_TAIL"]};
private _lastWaypoint = [_group, (count waypoints _group) - 1];
if (count waypoints _group > 1 && {currentWaypoint _group < count waypoints _group}
    && {waypointType _lastWaypoint == "MOVE"}) then {
    _state set ["routeWatch",[(count waypoints _group)-1,waypointPosition _lastWaypoint,waypointCompletionRadius _lastWaypoint,
        [_group,"",false,_lastWaypoint select 1] call WAIT_fnc_AuthoredRouteReceipt]];
};
private _routeWatch=_state getOrDefault ["routeWatch",[]];
if (!_corridorActive && {!_hadCorridor} && {!_hadBypass} && {!_bypassPassageActive} && {[_group,"WAIT_Convoy_RouteRecovery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {_routeWatch isNotEqualTo []} && {currentWaypoint _group >= count waypoints _group}
    && {time >= (_state getOrDefault ["routeRecoveryAt",-1])}) then {
    _routeWatch params ["_watchedIndex","_watchedPosition","_watchedRadius",["_watchedReceipt",[]]];
    // A Zeus edit changes or deletes the stored waypoint and therefore fails this identity check.
    // The Zeus suspension path above also clears local state before WAIT may resume.
    if (_watchedIndex < count waypoints _group) then {
        private _watchedWaypoint=[_group,_watchedIndex];
        if (_watchedReceipt isNotEqualTo []
            && {([_group,"",false,_watchedIndex] call WAIT_fnc_AuthoredRouteReceipt) isEqualTo _watchedReceipt}
            && {[_watchedWaypoint] call _mayRecoverWaypoint}
            && {waypointType _watchedWaypoint == "MOVE"}
            && {waypointPosition _watchedWaypoint distance2D _watchedPosition < 2}
            && {_lead distance2D _watchedPosition > (_watchedRadius max 20)+75}) then {
            if ([] call _mayIssueDriving) then {
                _group setCurrentWaypoint _watchedWaypoint;
                _leadOperator doMove _watchedPosition;
                _state set ["routeRecoveryAt",time+15];
                private _recoveries=(_group getVariable ["WAIT_Convoy_RouteRecoveries",0])+1;
                _group setVariable ["WAIT_Convoy_RouteRecoveries",_recoveries,true];
            };
        };
    };
};
private _routeDone = !_corridorActive && {!_hadBypass} && {count waypoints _group > 1} && {currentWaypoint _group >= count waypoints _group}
    && {_lead distance2D waypointPosition _lastWaypoint <= (waypointCompletionRadius _lastWaypoint max 20)};
private _settled = !_passageActive && {!_bypassPassageActive} && {_routeDone} && {_vehicles findIf {abs speed _x >= 1} < 0};
for "_i" from 1 to (count _vehicles - 1) do {
    if ((_vehicles select _i) distance2D (_vehicles select (_i - 1)) > (_gaps select _i) * 1.5) then {_settled = false};
};
if (!_settled) then {_state set ["arrivalAt", time + 5]};
if (_settled && {time >= (_state getOrDefault ["arrivalAt", time + 5])}) exitWith {
    if (time >= (_state getOrDefault ["haltRequest", -1])) then {
        [_group, _revision, "ARRIVED"] remoteExecCall ["WAIT_fnc_ConvoyHaltServer", 2];
        _state set ["haltRequest", time + 5];
    };
};
if (isNil {_state get "arrivalAt"}) then {_state set ["arrivalAt", time + 5]};
// Record each predecessor's actual route. Followers must not converge on the group leader.
private _frontTrails = _state get "frontTrails";
{
    private _key = netId _x;
    private _record = _frontTrails getOrDefault [_key, [[getPosATL _x], 0]];
    private _trail = _record select 0;
    if ((_trail select (count _trail - 1)) distance2D _x >= 5) then {_trail pushBack getPosATL _x};
    if (count _trail > 128) then {
        private _remove = count _trail - 128;
        _trail deleteRange [0, _remove];
        _record set [1, (_record select 1) + _remove];
    };
    _frontTrails set [_key, _record];
} forEach _vehicles;
private _turn = abs (((getDir _lead - (_state get "heading") + 540) mod 360) - 180);
_state set ["heading", getDir _lead];
private _stretch = 0;private _spacingGaps=[0];
for "_i" from 1 to (count _vehicles - 1) do {
    private _follower=_vehicles select _i;
    private _front=_vehicles select (_i-1);
    private _pairGap=_follower distance2D _front;
    private _headingDifference=abs (((getDir _follower-getDir _front+540) mod 360)-180);
    // On a common heading, Euclidean distance rewards lateral spread: a 40 m
    // side-by-side offset looks like a perfect 40 m convoy gap. Measure the
    // forward component instead. Turning pairs retain normal distance so the
    // controller does not mistake a legitimate corner for compression.
    if (_headingDifference <= 25 && {_pairGap <= (_gaps select _i)*1.8}) then {
        private _bearing=getDir _front;
        private _direction=[sin _bearing,cos _bearing,0];
        private _delta=(getPosATL _front) vectorDiff (getPosATL _follower);
        _delta set [2,0];
        _pairGap=(_delta vectorDotProduct _direction) max 0;
    };
    _spacingGaps pushBack _pairGap;
    _stretch = _stretch max (_pairGap / (_gaps select _i));
};
// One bounded road walk per convoy every three seconds is enough to anticipate geometry without
// multiplying raycasts or schedulers per vehicle. It influences speed only: Arma retains route
// choice, collision handling and the ability to remain stopped behind a deliberate roadblock.
private _roadCap = _maximum;
private _trafficAssistEnabled=[_group,"WAIT_Convoy_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled;
if (_trafficAssistEnabled) then {
    if (time >= (_state getOrDefault ["roadLookAt",-1])) then {
        private _roadObservation=[_lead,_maximum] call WAIT_fnc_DrivingRoadCap;
        _roadCap=_roadObservation select 0;
        _state set ["roadAssist",_roadObservation];
        _state set ["roadLookAt",time+3];
    } else {_roadCap=(_state getOrDefault ["roadAssist",[_maximum]]) select 0};
};
// During contact, keep the front moving instead of waiting inside the ambush for a disabled rear vehicle.
private _leadLimit = ((_maximum - ((_stretch - 1.2) max 0) * 5 - (_turn min 60) * 0.4) max 5) min _roadCap;
// A stretched but mobile convoy slows progressively; a hard zero here creates stop/start waves.
// Actual arrival, pinned contact and pedestrian safety still request a full stop.
// Outside contact, do not let the lead outrun a follower still acquiring its path.
// Use measured progress, retain a walking-speed floor, and recover the requested speed
// as the line closes. Real obstruction recovery remains a separate bounded halt path.
if (!_contact) then {
    for "_i" from 1 to (count _vehicles - 1) do {
        private _follower=_vehicles select _i;
        private _gap=_spacingGaps select _i;
        private _target=_gaps select _i;
        private _catchupThreshold=_target+((_target*0.05) max 1);
        // Followers share the cruise speed cap. Waiting until the outer band before
        // pacing the lead leaves no speed reserve to close a persistent gap inside it.
        if (_gap > _catchupThreshold) then {
            // Within the spacing band, reserve speed from cruise rather than from
            // instantaneous follower speed. Feeding acceleration lag back into the
            // leader here ratchets the whole convoy down on every small gap change.
            private _catchup=(_maximum - (((_gap-_target)*0.4) min 8)) max 5;
            // Ordinary outer-band error must not feed each follower's transient
            // acceleration lag back into the lead. That ratchets a mobile column
            // down to walking speed. Actual-speed pacing is reserved for a
            // substantially stretched column; normal closure uses cruise reserve.
            if (_gap > _target*2) then {
                _catchup=_catchup min ((abs speed _follower - (((_gap-_target*1.2)*0.15) min 8)) max 5);
            };
            _leadLimit=_leadLimit min _catchup;
        };
    };
};
_leadLimit=_leadLimit min ((_corridor select 1)*3.6);
if (_routeDone) then {_leadLimit = 0};
// Avoid converting small one-second spacing corrections into a visible throttle pulse. Acceleration
// is gradual; arrival remains an immediate stop and the infantry corridor below can still stop now.
private _leadSpeedState=_state getOrDefault ["leadSpeedLimit",[_leadLimit,time-1]];
private _leadElapsed=((time-(_leadSpeedState select 1)) max 0.1) min 3;
if (!_routeDone && {_leadLimit > (_leadSpeedState select 0)}) then {
    _leadLimit=_leadLimit min ((_leadSpeedState select 0)+6*_leadElapsed);
};
private _leadTraffic=if (_trafficAssistEnabled) then {
    [_lead,_leadLimit/3.6] call WAIT_fnc_DrivingFollowingCap
} else {[_leadLimit/3.6,objNull,-1,time,0]};
private _geometryTracks=_state getOrDefault ["geometryTracks",createHashMap];
private _geometryContext=[_group,_revision,_group getVariable ["WAIT_AIPass_Epoch",0],[_group] call WAIT_fnc_DrivingRouteReceipt];
private _leadTurn=[_lead,_geometryTracks getOrDefault [netId _lead,[]],_geometryContext] call WAIT_fnc_DrivingTurnTrack;
_geometryTracks set [netId _lead,_leadTurn select 1];_state set ["geometryTracks",_geometryTracks];
private _leadNativeHint=if (_trafficAssistEnabled) then {
    [_lead,_group,["CONVOY",_revision,_geometryContext]] call WAIT_fnc_DrivingNativePathWatch
} else {[_lead,_group,["CONVOY"],true] call WAIT_fnc_DrivingNativePathWatch};
private _leadCurveHint=if (_leadNativeHint isEqualTo []) then {[_leadTurn select 0]} else {_leadNativeHint};
private _leadGeometry=if (_trafficAssistEnabled) then {[_lead,_leadLimit/3.6,false,_leadCurveHint] call WAIT_fnc_DrivingGeometryCap} else {[[],[]]};
private _leadGate=_leadGeometry select 0;private _leadObstacle=_leadGeometry select 1;
if (_leadGate isNotEqualTo [] && {(_leadGate select 0) < (_leadTraffic select 0)}) then {_leadTraffic=_leadGate};
private _leadWithoutObstacle=+_leadTraffic;
private _leadObstacleLimited=_leadObstacle isNotEqualTo [] && {(_leadObstacle select 0) < (_leadTraffic select 0)};
if (_leadObstacleLimited) then {
    _leadTraffic=_leadObstacle select [0,5];
    if (isNull (_leadTraffic select 1)) then {_leadTraffic set [1,_lead]};
};
// One lead writer; existing trail writers remain solely responsible for followers.
private _bypassAuthority={[] call _mayIssueDriving && {[[_group,currentWaypoint _group]] call _mayRecoverWaypoint}};
if (!_corridorActive && {!_hadCorridor} && {!_passageActive} && {[] call _mayIssueDriving}) then {
    _bypass=[_group,_lead,_group getVariable ["WAIT_Convoy_Brain",createHashMap],_leadObstacle,_bypassAuthority,"CONVOY"] call WAIT_fnc_DrivingBypassStep;
} else {
    if (_hadBypass) then {[_lead,_group,"CONVOY_ASSIST_RELEASED"] call WAIT_fnc_DrivingBypassRelease};
};
private _bypassActive=_bypass select 0;
// Existing episodes were advanced once above. Only newly committed lead work needs admission here.
if (!_bypassPassageActive && {!_hadBypassPassage}) then {
    _bypassPassage=[_group,_configuration] call WAIT_fnc_ConvoyBypassStep;
};
_bypassPassageActive=_bypassPassage select 0;_bypassCaps=_bypassPassage select 1;
_state set ["bypassPhase",if (_bypassActive) then {_bypass select 2} else {if (_bypassPassageActive) then {"BYPASS_TAIL"} else {""}}];
if (_bypassActive && {_bypass select 3} && {count _leadObstacle == 9}) then {
    private _work=_lead getVariable ["WAIT_DrivingBypass_Work",createHashMap];
    if ((_leadObstacle select 1) == (_work getOrDefault ["obstacle",objNull])
        && {(_leadObstacle select 8) isEqualTo (_work getOrDefault ["transform",[]])}) then {
        _leadTraffic=+_leadWithoutObstacle;_leadObstacleLimited=false;
    };
};
_leadLimit=_leadLimit min ((_bypass select 1)*3.6);
_leadLimit=_leadLimit min ((_bypassCaps getOrDefault [netId _lead,1e6])*3.6);
_state set ["obstacleLimited",_leadObstacleLimited];
private _leadTrafficBlocked=!isNull (_leadTraffic select 1);
_leadLimit=_leadLimit min ((_leadTraffic select 0)*3.6);
_leadLimit = [_lead,_leadLimit,_group] call WAIT_fnc_CortexInfantrySpeed;
_state set ["leadSpeedLimit",[_leadLimit,time]];
if ([] call _mayIssueDriving) then {
    private _ownedSpeed=_leadLimit/3.6;
    _lead forceSpeed _ownedSpeed;
    if (_leadGate isNotEqualTo [] && {[] call _mayIssueDriving}) then {[_group,_lead,_leadGate,_revision] call WAIT_fnc_DrivingGateRequest};
    _lead setVariable ["WAIT_Convoy_OwnedSpeed",[_group,_revision,_ownedSpeed]];
};
// Speed limits cannot restart an engine movement order that stopped short. Retry only
// after ten seconds without progress, while a real route destination remains active.
private _leadProgress = _state getOrDefault ["leadProgress", [getPosATL _lead, time, 0]];
private _waypointIndex = currentWaypoint _group;
private _leadRouteReceipt=[_group,"",false,_waypointIndex] call WAIT_fnc_AuthoredRouteReceipt;
if (_leadRouteReceipt isNotEqualTo (_state getOrDefault ["leadRouteReceipt",[]])) then {
    _leadProgress=[getPosATL _lead,time,0];
    _state set ["leadRouteReceipt",_leadRouteReceipt];
};
if (_lead distance2D (_leadProgress select 0) > 3 || {_leadLimit <= 0} || {_leadTrafficBlocked} || {_corridorActive} || {_hadCorridor} || {_bypassActive} || {_hadBypass}) then {_leadProgress = [getPosATL _lead, time, 0]};
if (!_routeDone && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {!_leadTrafficBlocked} && {_leadLimit > 0} && {_waypointIndex > 0} && {_waypointIndex < count waypoints _group}
    && {time - (_leadProgress select 1) >= 10} && {abs speed _lead < 1}) then {
    private _waypoint = [_group, _waypointIndex];
    private _destination = waypointPosition _waypoint;
    if ([_waypoint] call _mayRecoverWaypoint && {_lead distance2D _destination > (waypointCompletionRadius _waypoint max 20)}) then {
        private _attempts=(_leadProgress param [2,0])+1;
        if (_attempts > 3) then {
            [_group,_revision,([_lead] call _classifyStall),[],_lead] remoteExecCall ["WAIT_fnc_ConvoyHaltServer",2];
        } else {if ([] call _mayIssueDriving && {currentWaypoint _group == _waypointIndex}
            && {([_group,"",false,_waypointIndex] call WAIT_fnc_AuthoredRouteReceipt) isEqualTo _leadRouteReceipt}) then {_leadOperator doMove _destination}};
        _leadProgress set [2,_attempts];
    };
    _leadProgress set [0,getPosATL _lead]; _leadProgress set [1,time];
};
_state set ["leadProgress", _leadProgress];
private _followers = _state get "followers";
private _speedLimits = _state get "speedLimits";
private _pathOwners = _state getOrDefault ["pathOwners",createHashMap];
private _pathAssistEnabled=[_group,"WAIT_Convoy_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled;
_state set ["pathOwners",_pathOwners];
for "_i" from 1 to (count _vehicles - 1) do {
    private _vehicle = _vehicles select _i;
    private _front = _vehicles select (_i - 1);
    private _record = _frontTrails get (netId _front);
    private _trail = _record select 0;
    private _trailBase = _record select 1;
    private _gap = _vehicle distance2D _front;
    private _desiredGap = _gaps select _i;
    private _movementOperator=effectiveCommander _vehicle;
    if (isNull _movementOperator) then {_movementOperator=driver _vehicle};
    // Fixed steering takes a driver out of a separate commander's native movement chain.
    // Such vehicles retain native planning through the effective commander instead.
    private _native = !isAISteeringComponentEnabled _vehicle
        || {_movementOperator != driver _vehicle};
    private _key = netId _vehicle;
    private _progress = _followers getOrDefault [_key, [getPosATL _vehicle, time, -1, _trailBase, 0, [], []]];
    // Field 7 remains the existing one-shot native hold receipt. Field 8 is a
    // local speed constraint; older records have no retained path cap.
    private _retainedPathCap=_progress param [8,-1,[0]];
    if (!_pathAssistEnabled) then {_retainedPathCap=-1; _progress set [8,-1]};
    private _tolerance = (_desiredGap * 0.2) max 3;
    private _bodyGap = (((_specs get (netId _vehicle)) select 1) + ((_specs get (netId _front)) select 1))*0.5+5;
    private _gapLow = (_desiredGap - _tolerance) max _bodyGap;
    private _gapHigh = _desiredGap + _tolerance;
    private _controlGap = _gap;
    private _lateralOffset = 0;
    private _headingDifference=abs (((getDir _vehicle-getDir _front+540) mod 360)-180);
    if (_headingDifference <= 25 && {_gap <= _desiredGap*1.8}) then {
        private _bearing=getDir _front;
        private _direction=[sin _bearing,cos _bearing,0];
        private _delta=(getPosATL _front) vectorDiff (getPosATL _vehicle);
        _delta set [2,0];
        _controlGap=(_delta vectorDotProduct _direction) max 0;
        _lateralOffset=sqrt ((_gap*_gap-_controlGap*_controlGap) max 0);
    };
    // Absolute speed cannot distinguish forward progress from a predecessor
    // backing into this follower during native obstacle recovery.
    private _frontReversing=(velocityModelSpace _front select 1) < -0.5;
    private _frontSpeed = [((velocityModelSpace _front select 1) max 0)*3.6,0] select _frontReversing;
    private _previous = _speedLimits getOrDefault [_key,[_frontSpeed,time-1]];
    // Match predecessor speed at the requested gap; proportional correction avoids drifting along a band edge.
    // Acceleration remains bounded below, while compression still applies an immediate braking cap.
    private _limit = (_frontSpeed + (_controlGap-_desiredGap)*0.4) max 0;
    if (_controlGap > _gapHigh) then {
        // Restore the column after a slow step-off or path-acquisition gap. A
        // bounded nonlinear outer-band correction gives a stretched follower
        // more convergence than a small linear correction, without tightening
        // the normal band or adding another stop/start threshold.
        private _excess=_controlGap-_gapHigh;
        private _catchupBoost=((_excess*sqrt _excess)*0.15) min 8;
        _limit=(_limit+_catchupBoost) max 5;
    };
    if (_controlGap < _gapLow) then {_limit = _limit min ((_frontSpeed-(_gapLow-_controlGap)*1.2) max 0)};
    // A stationary/braking predecessor must still constrain us inside the tolerance band.
    // Match the ordinary driving model in SI units, then convert its closing allowance
    // to the convoy's km/h caps. Heavy followers receive earlier provisional braking.
    // This assumes measured predecessor velocity, not its future braking capability.
    private _massFactor=((1+(((getMass _vehicle)-3000)/7000)) max 1) min 2.5;
    private _deceleration=4/_massFactor;
    private _reactionSpeed=4*_deceleration;
    private _closingRoom=(_controlGap-_gapLow) max 0;
    private _closingAllowance=(sqrt ((_reactionSpeed*_reactionSpeed)+2*_deceleration*_closingRoom)-_reactionSpeed) max 0;
    private _closingCap = (_frontSpeed+3.6*_closingAllowance) min _maximum;
    private _elapsed = ((time-(_previous select 1)) max 0.1) min 3;
    // Tracks accelerate and brake unevenly. Do not propagate each brief speed dip
    // into an immediate follower throttle drop anywhere within the safe tolerance band.
    // Compression and the raw closing cap still brake immediately. A brief predecessor
    // dip below 2 km/h must not flip the pacing policy while spare longitudinal room remains.
    if (_controlGap >= _gapLow && {_closingCap > 0} && {!_frontReversing}) then {
        _limit=_limit max (((_previous select 0)-4*_elapsed) max 0);
    };
    _limit = ((_limit min ((_previous select 0)+4*_elapsed)) min _closingCap) max 0;
    // Keep enough motion to steer back onto the recorded predecessor track.
    // Recover only within the closing cap: lateral clearance does not authorize
    // moving past safe longitudinal space beside a stopped predecessor.
    if (_lateralOffset > _tolerance && {_gap > _gapLow} && {_pathOwners getOrDefault [_key,false]}) then {_limit=(_limit max 5) min _closingCap};
    // Reverse yield overrides smoothing and lateral recapture; neither is
    // permission to advance into a reversing predecessor. Keep route identity.
    if (_frontReversing) then {_limit=0};
    if (_retainedPathCap >= 0) then {_limit=_limit min _retainedPathCap};
    // Preserve normal aligned predecessor spacing. Its turning/reversing hull and
    // contact-range occupancy still constrain us, as do all other occupied vehicles.
    private _traffic=if (_trafficAssistEnabled) then {
        [_vehicle,_limit/3.6,_front] call WAIT_fnc_DrivingFollowingCap
    } else {[_limit/3.6,objNull,-1,time,0]};
    private _turn=[_vehicle,_geometryTracks getOrDefault [netId _vehicle,[]],_geometryContext] call WAIT_fnc_DrivingTurnTrack;
    _geometryTracks set [netId _vehicle,_turn select 1];
    private _nativeHint=if (_trafficAssistEnabled) then {
        [_vehicle,_group,["CONVOY",_revision,_geometryContext]] call WAIT_fnc_DrivingNativePathWatch
    } else {[_vehicle,_group,["CONVOY"],true] call WAIT_fnc_DrivingNativePathWatch};
    private _curveHint=if (_nativeHint isEqualTo []) then {[_turn select 0]} else {_nativeHint};
    private _vehicleGeometry=if (_trafficAssistEnabled) then {[_vehicle,_limit/3.6,false,_curveHint] call WAIT_fnc_DrivingGeometryCap} else {[[],[]]};
    private _vehicleGate=_vehicleGeometry select 0;private _vehicleObstacle=_vehicleGeometry select 1;
    if (_vehicleGate isNotEqualTo [] && {(_vehicleGate select 0) < (_traffic select 0)}) then {_traffic=_vehicleGate};
    // Source-constraint yielding requires this follower's unchanged committed trail, actual
    // alignment and a fresh hull-sized next segment, never merely the lead's successful proposal.
    private _bypassLegClear=false;
    private _episode=_group getVariable ["WAIT_Convoy_BypassPassage",createHashMap];
    if (_bypassPassageActive && {count _vehicleObstacle == 9}
        && {(_vehicleObstacle select 1) == (_episode get "obstacle")}
        && {(_vehicleObstacle select 8) isEqualTo (_episode get "transform")}) then {
        private _receipt=_progress param [10,[]];private _committed=_progress param [9,[]];
        if (count _receipt == 4 && {count _committed >= 2} && {count _committed <= 11}
            && {(_receipt select 0) == driver _vehicle} && {(_receipt select 1) == _movementOperator}
            && {(expectedDestination driver _vehicle) isEqualTo (_receipt select 2)}
            && {(expectedDestination _movementOperator) isEqualTo (_receipt select 3)}) then {
            private _origin=getPosASL _vehicle;private _nearest=-1;private _distance=4;
            private _captureRuns=0;private _inCapture=false;
            {
                private _pointASL=ATLToASL _x;
                private _d=_origin distance2D _pointASL;
                private _captured=_d < 4 && {abs ((_origin select 2)-(_pointASL select 2)) <= 1.5};
                if (_captured && {!_inCapture}) then {_captureRuns=_captureRuns+1};
                if (_captured && {_d < _distance}) then {_nearest=_forEachIndex;_distance=_d};
                _inCapture=_captured;
            } forEach _committed;
            // A self-near trail can offer more than one unrelated next leg. A nearby
            // point alone cannot identify the native path's current leg or waive safety.
            if (_captureRuns != 1) then {_nearest=-1};
            if (_nearest >= 0 && {_nearest+1 < count _committed}) then {
                private _next=ATLToASL (_committed select (_nearest+1));private _delta=_next vectorDiff _origin;_delta set [2,0];
                private _forward=vectorDir _vehicle;_forward set [2,0];_forward=vectorNormalized _forward;
                if (vectorMagnitude _delta > 0.1 && {_delta vectorDotProduct _forward > (vectorMagnitude _delta)*0.5}) then {
                    private _bounds=boundingBoxReal _vehicle;private _low=_bounds select 0;private _high=_bounds select 1;
                    private _width=(abs (_low select 0)) max (abs (_high select 0));
                    private _length=(abs (_low select 1)) max (abs (_high select 1));
                    private _health=[_vehicle,[_origin,_next],sqrt ((_width^2)+(_length^2))+1,(_high select 2)-(_low select 2)] call WAIT_fnc_DrivingPathGeometry;
                    _bypassLegClear=_health select 0;
                };
            };
        };
    };
    if (!_bypassLegClear && {_vehicleObstacle isNotEqualTo []} && {(_vehicleObstacle select 0) < (_traffic select 0)}) then {
        _traffic=_vehicleObstacle select [0,5];
        if (isNull (_traffic select 1)) then {_traffic set [1,_vehicle]};
        _state set ["obstacleLimited",true];
    };
    private _trafficBlocked=!isNull (_traffic select 1);
    _limit=_limit min ((_traffic select 0)*3.6);
    _limit=_limit min ((_passageCaps getOrDefault [netId _vehicle,1e6])*3.6);
    _limit=_limit min ((_bypassCaps getOrDefault [netId _vehicle,1e6])*3.6);
    _limit = [_vehicle,_limit,_group] call WAIT_fnc_CortexInfantrySpeed;
    if ([] call _mayIssueDriving) then {
        private _ownedSpeed=_limit/3.6;
        _vehicle forceSpeed _ownedSpeed;
        if (_vehicleGate isNotEqualTo [] && {[] call _mayIssueDriving}) then {[_group,_vehicle,_vehicleGate,_revision] call WAIT_fnc_DrivingGateRequest};
        _vehicle setVariable ["WAIT_Convoy_OwnedSpeed",[_group,_revision,_ownedSpeed]];
    };
    _speedLimits set [_key,[_limit,time]];
    // Keep the committed native and steering-path destinations when progress is made. Rebuilding
    // this record as the former four-field array erased both commitments every few metres, so the
    // next one-second trail sample looked like a new order and restarted engine planning.
    if (_vehicle distance2D (_progress select 0) > 3 || {_trafficBlocked} || {_limit <= 0}) then {
        _progress set [0,getPosATL _vehicle];
        _progress set [1,time];
        _progress set [4,0];
    };
    // Let the normal engine route around an obstruction after a bounded timeout. Never teleport.
    if (!_trafficBlocked && {time - (_progress select 1) > 20} && {_limit > 2} && {_gap > _gapLow+3}
        && {_frontSpeed > 1 || {_gap > _gapHigh}}) then {
        private _attempts=(_progress param [4,0])+1;
        if (_attempts > 3) then {
            [_group,_revision,([_vehicle] call _classifyStall),[],_vehicle] remoteExecCall ["WAIT_fnc_ConvoyHaltServer",2];
        } else {
            if ([] call _mayIssueDriving) then {
                // Recovery must retain predecessor intent, not re-enter native group formation.
                // Formation following can overtake an escort and obstruct its weapon sector.
                private _recoveryTarget=+(_progress param [5,[],[[]]]);
                if (_recoveryTarget isEqualTo []) then {_recoveryTarget=+(_progress param [6,[],[[]]])};
                if (count _recoveryTarget == 3) then {
                    // A turn changes the predecessor's heading, not the validity of
                    // its recorded route. Reuse only a real retained trail point;
                    // this bounded lookup runs on the existing stalled-actor cadence.
                    private _recorded=_trail findIf {(_x vectorDistance _recoveryTarget) <= 1};
                    if (_recorded >= 0) then {
                        // Navigation endpoints may lie inside the spacing band; the
                        // speed controller remains responsible for the physical gap.
                        // Keep one movement controller during bounded recovery.
                        if (_native) then {
                            _movementOperator doMove _recoveryTarget;
                        } else {
                            // A native doMove competes with the retained steering path.
                            // Invalidate only its commitment so path refresh below
                            // resubmits one segment without another doStop acquisition.
                            _progress set [6,[]];
                        };
                    };
                };
                _vehicle setConvoySeparation _desiredGap;
            };
        };
        // Keep the follower's route/hold identity across recovery. Native
        // doMove gets its existing observation window; fixed steering must refresh
        // the invalidated path now rather than sit on a stalled segment for ten seconds.
        _progress set [0,getPosATL _vehicle];
        _progress set [1,time];
        _progress set [2,[time,time+10] select _native];
        _progress set [4,_attempts];
    };
    if (time >= (_progress select 2) && {count _trail >= 1} && {_gap > _desiredGap * 0.8 || {_pathOwners getOrDefault [_key,false]}}) then {
        private _nearest = -1;
        private _distance = 18;
        private _frontIndex = count _trail - 1;
        private _start = ((_progress select 3) - _trailBase) max 0;
        // Advance only through a contiguous prefix of the recorded route. A later
        // return leg near the vehicle is not evidence that intervening bends were travelled.
        // The short observed sweep allows normal one-second travel past several samples.
        private _pose=getPosASL _vehicle;
        private _sample=_progress param [11,[],[[]]];
        private _previous=+_pose;
        if (count _sample == 2 && {time-(_sample select 1) <= 3}
            && {time >= (_sample select 1)} && {(_sample select 0) vectorDistance _pose <= 100}) then {
            _previous=+(_sample select 0);
        };
        private _sweep=_pose vectorDiff _previous;
        private _sweepXY=+_sweep;_sweepXY set [2,0];
        private _sweepSquared=_sweepXY vectorDotProduct _sweepXY;
        for "_j" from _start to _frontIndex do {
            private _pointASL=ATLToASL (_trail select _j);
            private _offset=_pointASL vectorDiff _previous;_offset set [2,0];
            private _fraction=if (_sweepSquared > 0.01) then {
                ((_offset vectorDotProduct _sweepXY)/_sweepSquared) max 0 min 1
            } else {1};
            private _capture=_previous vectorAdd (_sweep vectorMultiply _fraction);
            if (_capture distance2D _pointASL >= 18
                || {abs ((_capture select 2)-(_pointASL select 2)) > 1.5}) exitWith {};
            private _d=_pose distance2D _pointASL;
            if (_nearest < 0 || {_d < _distance}) then {_distance=_d;_nearest=_j};
        };
        _progress set [11,[+_pose,time]];
        private _joining = false;
        // The first recorded predecessor point starts a full gap ahead. A fixed
        // 18 m capture circle strands 30/50 m starts in native formation forever.
        // Acquire an ahead point in a forward cone, never an old point behind us.
        if (_nearest < 0) then {
            private _origin=getPosATL _vehicle;
            private _bearing=getDir _vehicle;
            private _heading=[sin _bearing,cos _bearing,0];
            private _best=150;
            // Joining may approach only the next retained route point. Searching
            // farther ahead here would bypass the ordered capture guard at crossings.
            // Relative terrain height permits an uphill ground start while refusing
            // a first point on a substantially different elevated deck.
            for "_j" from _start to (_start min _frontIndex) do {
                private _point=_trail select _j;
                private _delta=_point vectorDiff _origin;
                _delta set [2,0];
                private _length=vectorMagnitude _delta;
                if (_length > 3 && {_length < _best} && {(_delta vectorDotProduct _heading) > _length*0.5}
                    && {abs ((_point select 2)-(_origin select 2)) <= 1.5}) then {
                    _nearest=_j; _best=_length; _joining=true;
                };
            };
        };
        if (_nearest >= 0) then {
            private _path = [];
            _progress set [3, _nearest + _trailBase];
            private _end = (_nearest + 10) min _frontIndex min (count _trail - 1);
            for "_j" from (_nearest + ([1,0] select _joining)) to _end do {
                private _point = _trail select _j;
                // The trail is navigation, not a second spacing brake. Trimming its endpoint to
                // the requested gap leaves only a few metres of driveable path at short spacing.
                // The speed controller above maintains the physical gap independently.
                _path pushBack _point;
            };
            // The predecessor trail is already available, so followers can anticipate its curve
            // without another road/object query. Retain this cap across spacing-only ticks.
            if (_pathAssistEnabled && {count _path >= 3}) then {
                private _pathTurn=0;
                private _pathGrade=0;
                for "_j" from 1 to (count _path-2) do {
                    private _a=_path select (_j-1);
                    private _b=_path select _j;
                    private _c=_path select (_j+1);
                    private _segment=_b distance2D _c;
                    if (_segment >= 1) then {
                        _pathTurn=_pathTurn max (abs ((((_b getDir _c)-(_a getDir _b)+540) mod 360)-180));
                        private _heightB=(ATLToASL _b) select 2;
                        private _heightC=(ATLToASL _c) select 2;
                        _pathGrade=_pathGrade max (abs (_heightC-_heightB)/_segment);
                    };
                };
                private _pathCap=if (_pathTurn > 70) then {18} else {if (_pathTurn > 45) then {25} else {if (_pathTurn > 25) then {35} else {_maximum}}};
                if (_pathGrade > 0.2) then {_pathCap=_pathCap min 18} else {if (_pathGrade > 0.12) then {_pathCap=_pathCap min 25}};
                _progress set [8,_pathCap];
                _limit=_limit min _pathCap;
                if ([] call _mayIssueDriving) then {
                    private _ownedSpeed=_limit/3.6;
                    _vehicle forceSpeed _ownedSpeed;
                    _vehicle setVariable ["WAIT_Convoy_OwnedSpeed",[_group,_revision,_ownedSpeed]];
                };
                _speedLimits set [_key,[_limit,time]];
            };
            if (_native && {_path isNotEqualTo []}) then {
                // Vehicles without steering support retain native pathfinding.
                // A long straight look-ahead keeps tracks moving; stop the destination at a bend
                // so native pathfinding cannot cut across the predecessor's right-angle corner.
                private _destination = _path select (count _path - 1);
                private _straightPath=true;
                if (count _path >= 3) then {
                    for "_j" from 1 to (count _path - 2) do {
                        private _before = (_path select (_j-1)) getDir (_path select _j);
                        private _after = (_path select _j) getDir (_path select (_j+1));
                        private _turn = abs (((_after-_before+540) mod 360)-180);
                        if (_turn > 5) then {_straightPath=false};
                        if (_turn > 25) exitWith {_destination = _path select _j};
                    };
                };
                // A moving predecessor is not a stopping destination. On an observed
                // straight MOVE leg, give native planning room beyond that short trail.
                // Keep bends, holds and waypoint arrival on the actual recorded route.
                private _routeIndex=currentWaypoint _group;
                if (_straightPath && {count _path >= 2} && {_frontSpeed > 2}
                    && {_routeIndex > 0} && {_routeIndex < count waypoints _group}) then {
                    private _routeWaypoint=[_group,_routeIndex];
                    private _routeEnd=waypointPosition _routeWaypoint;
                    private _trailHeading=(_path select 0) getDir _destination;
                    private _routeHeading=_destination getDir _routeEnd;
                    private _alignment=abs (((_routeHeading-_trailHeading+540) mod 360)-180);
                    private _remaining=_destination distance2D _routeEnd;
                    if (!_bypassPassageActive && {waypointType _routeWaypoint == "MOVE"} && {_alignment <= 5}
                        && {_remaining > (waypointCompletionRadius _routeWaypoint max 20)+40}) then {
                        _destination=_destination getPos [40 min (_remaining-20),_routeHeading];
                    };
                };
                // Native steering does not tolerate a fresh doMove every path-refresh tick: it
                // cancels braking and steering decisions, producing the visible stop/turn/start
                // cycle. Retask only when the committed point advances materially or the driver
                // has actually stopped.
                private _committedDestination=_progress param [5,[]];
                if (count _committedDestination < 2
                    || {_committedDestination distance2D _destination > 8}) then {
                    if ([] call _mayIssueDriving) then {
                        _movementOperator doMove _destination;
                        _progress set [5,+_destination];
                        _progress set [9,+_path];
                        _progress set [10,[driver _vehicle,_movementOperator,+(expectedDestination driver _vehicle),+(expectedDestination _movementOperator)]];
                        _vehicle setVariable ["WAIT_Convoy_MovementReceipt",[_group,_revision,driver _vehicle,_movementOperator,+(expectedDestination _movementOperator)],true];
                        _progress set [7,false];
                    };
                };
                _progress set [2, time + 1];
            } else {
                if (count _path >= 2) then {
                    // Normal AI must relinquish its formation movement before path driving.
                    // Stop once per acquisition, not on every refreshed path (which would cancel it).
                    if (!(_pathOwners getOrDefault [_key,false])) then {
                        if ([] call _mayIssueDriving) then {
                            doStop driver _vehicle;
                            _pathOwners set [_key,true];
                        };
                    };
                    // Commit a useful predecessor segment and refresh only when its endpoint advances.
                    // forceSpeed above owns continuous spacing/braking; embedding a new speed in a
                    // replacement path every second restarted steering and produced stop/start waves.
                    private _pathDestination=_path select ((count _path)-1);
                    private _committedPathDestination=_progress param [6,[]];
                    if (count _committedPathDestination < 2
                        || {_committedPathDestination distance2D _pathDestination > 8}) then {
                        if ([] call _mayIssueDriving) then {
                            _vehicle setDriveOnPath _path;
                            // This is movement ownership evidence, never proof the path executed.
                            // Capture the native command state after the sole path write so release
                            // cannot cancel a later native destination or a changed driver/operator.
                            _vehicle setVariable ["WAIT_Convoy_PathLease",[_group,_revision,
                                _group getVariable ["WAIT_AIPass_Epoch",0],driver _vehicle,_movementOperator,
                                +(expectedDestination _movementOperator),+_pathDestination],true];
                            _progress set [6,+_pathDestination];
                            _progress set [9,+_path];
                            _progress set [10,[driver _vehicle,_movementOperator,+(expectedDestination driver _vehicle),+(expectedDestination _movementOperator)]];
                        _vehicle setVariable ["WAIT_Convoy_MovementReceipt",[_group,_revision,driver _vehicle,_movementOperator,+(expectedDestination _movementOperator)],true];
                        };
                    };
                    _progress set [2, time + 1];
                };
            };
        } else {
            // A steering-capable follower waits for a forward trail; never hand it back to
            // formation merely because its predecessor has not yet travelled five metres.
            // Native formation here recreates side-by-side traffic and can close the gap first.
            if (_native) then {
                _pathOwners set [_key,false];
                // No forward predecessor trail is not permission to rejoin formation.
                // Retain an existing native destination. Before the first commitment,
                // hold once so the leader's formation cannot pull us alongside it.
                if (count (_progress param [5,[]]) < 2
                    && {!(_progress param [7,false])} && {[] call _mayIssueDriving}) then {
                    doStop _movementOperator;
                    _vehicle setConvoySeparation _desiredGap;
                    _progress set [7,true];
                };
            } else {
                if (!(_pathOwners getOrDefault [_key,false]) && {[] call _mayIssueDriving}) then {doStop driver _vehicle};
                _pathOwners set [_key,true];
            };
            _progress set [2, time + 1];
        };
    };
    _followers set [_key, _progress];
};

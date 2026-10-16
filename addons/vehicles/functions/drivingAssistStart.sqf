/*
 * Author: WaldoTheWarfighter
 * Purpose: Applies a sparse, owner-local safety speed cap and bounded physical recovery to an
 * ordinary AI ground vehicle that is already following a native waypoint. This is the standalone
 * driving layer; registered convoys retain their separate predecessor-spacing controller. Terrain
 * thresholds are expressed in km/h for settings and diagnostics, then converted to the metres per
 * second required by forceSpeed before the command and ownership lease are recorded.
 * Locality / Authority: Runs only where the vehicle is local. It never creates, replaces or
 * deletes a waypoint and yields to players, Zeus remote control, convoy ownership and specialist
 * driving ownership. Ineffective drivers and immobilized vehicles receive no recovery commands.
 * An authored zero forced-speed hold is retained without recovery commands.
 * Persistent stationary traffic admits at most three native route retries in one eighty-second
 * public episode; collision caps remain active and newer seat/command ownership ends retries.
 * Traffic dwell restarts after a six-second observation gap or either hull moving more than
 * 1.5 metres in ASL from its dwell anchor; low-speed motion beyond that bound restarts dwell.
 * Native individual MOVE destinations and deliberate STOP commands block new route recovery;
 * an exact owned reverse journal alone permits its finite handback to the authored route.
 * Native boarding, service, medical and assembly tasks release the exact speed lease;
 * both driver and effective commander are rechecked at each cap/recovery command boundary.
 * The authored waypoint identity includes conditions, timeouts, synchronized triggers, speed,
 * combat mode and formation. Same-index edits retire the old recovery stage. Every cap/recovery
 * command rechecks that identity; the implicit spawn waypoint never authorizes assistance.
 * Road bends, junctions and absolute road grade share the convoy observer at existing cadence.
 * Finite ordinary-lead bypass planning/following also uses this callback, excludes corridor/rear
 * work and requires fresh next-leg geometry before yielding its exact source obstacle constraint.
 * Registered navigation areas use finite approach/crossing work in this same callback; current
 * traffic caps still win, and active corridor legs suppress ordinary route recovery.
 * Friendly pedestrian hulls constrain ordinary driving as well as opted-in convoys.
 * Forward-lane vehicle hulls constrain speed regardless of heading; aligned predecessors use
 * current hull gaps and actual velocity for continuous following caps. Other occupied hulls
 * receive no assumed forward-speed allowance. This does not establish crossing right-of-way.
 * Recognised forward gate/barrier geometry also constrains approach at the existing cadence.
 * Gate animation or damage does not grant passage; nearby openings use server validation, and no closing command is issued.
 * Close stable static blockage may use the same finite rear recovery after fresh dwell;
 * independent traffic, gate and pedestrian constraints still suppress its admission.
 * Owned traffic stops remain sampled; congestion suppresses reverse. Only bounded native-route
 * retries may reconsider persistent blockage. No crossing priority or passing is inferred here.
 * The owned rear leg resamples its body corridor once per second on the existing scheduler,
 * stopping for new obstructions without extending its six-second deadline. Intended direction
 * is checked while stopped; an expired rear leg observes the forward retry before issuing it.
 * Reverse admission uses a fresh body-sized rear corridor observation shared with tracked
 * withdrawal. Actor and solid-geometry clearance does not prove native reverse execution.
 * Only the current leader vehicle can refresh/reverse the shared route. Followers keep native
 * formation movement; a leader/seat/locality change invalidates delayed recovery commands.
 * Deliberate native waits near the completion envelope suppress recovery without evaluating
 * waypoint statement code. Recovery also refuses distant scripted, timed, synchronized or
 * object-attached MOVE orders; native execution and ordinary safety caps remain available.
 * New or newly progressing routes get a 20-second planning/observation grace. A route refresh
 * gets 30 seconds before cautious reverse admission; the reverse leg remains six seconds and
 * the final authored-route retry gets 60 seconds. No new order inherits a spent retry window.
 * One group driving FSM admits the existing executor through the shared
 * scheduler; group decisions never issue these commands directly.
 * Repeat/JIP: State is stored on the vehicle and is idempotent. The next local group step resumes
 * it after a locality change; route changes reset finite recovery; release restores only the forced speed captured by this function.
 * Arguments:
 * 0: group <GROUP> - local AI group commanding the vehicle.
 * 1: operation brain <HASHMAP, empty> - internal current-owner executor receipt.
 * Return Value: Nothing.
 * Current callers: WAIT_fnc_CortexGroupTick (admission), DrivingOperationStep (execution).
 * Example: [group driver truck1] call WAIT_fnc_DrivingAssistStart;
 */

params [["_group",grpNull,[grpNull]],["_brain",createHashMap,[createHashMap]]];
if (isNull _group || {!local _group}) exitWith {};
// Normal group decisions admit/reuse the FSM; only its current queued callback writes commands.
if (count _brain == 0) exitWith {[_group] call WAIT_fnc_DrivingOperationStart};
if ((_group getVariable ["WAIT_Driving_Brain",createHashMap]) isNotEqualTo _brain
    || {_brain getOrDefault ["cancelled",false]}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {};
private _enabled=[_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled;
// Read only the current authored waypoint. Conditions and trigger identities belong to the order,
// just as its position does. A same-index edit must not inherit a reverse request for the old order.
private _readRouteIdentity={[_group] call WAIT_fnc_DrivingRouteReceipt};
private _vehicles=[];
{
    private _vehicle=vehicle _x;
    if (_vehicle != _x && {_vehicle isKindOf "LandVehicle"} && {!(_vehicle isKindOf "StaticWeapon")} && {!(_vehicle in _vehicles)}
        && {!isNull driver _vehicle} && {group driver _vehicle == _group}) then {
        _vehicles pushBack _vehicle;
    };
} forEach units _group;
// A group can leave its previous vehicle, board an aircraft or become a convoy between sparse
// scheduler steps. Release only the vehicles we previously owned; never touch another group's cap.
private _previous=_group getVariable ["WAIT_DrivingAssist_Vehicles",[]];
{
    if !(_x in _vehicles) then {[_x,_group] call WAIT_fnc_DrivingAssistRelease};
} forEach _previous;
_group setVariable ["WAIT_DrivingAssist_Vehicles",_vehicles];
// Rebuild only the current roster's private measurement map; departed vehicles retain no history.
private _priorTracks=_brain getOrDefault ["geometryTracks",createHashMap];
private _geometryTracks=createHashMap;
{_geometryTracks set [netId _x,_priorTracks getOrDefault [netId _x,[]]]} forEach _vehicles;
_brain set ["geometryTracks",_geometryTracks];
{
    private _vehicle=_x;
    private _driver=driver _vehicle;
    private _movementOperator=effectiveCommander _vehicle;
    if (isNull _movementOperator) then {_movementOperator=_driver};
    private _nativeTaskFree={
        params ["_actor"];
        !isNull _actor && {!(currentCommand _actor in [
            "GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
            "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED",
            "ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"
        ])}
    };
    private _routeIdentity=call _readRouteIdentity;
    private _recoveryWork=_vehicle getVariable ["WAIT_DrivingRecovery_Work",createHashMap];
    private _recoveryOwned=count _recoveryWork > 0 && {(_recoveryWork get "group") == _group}
        && {(_recoveryWork get "route") isEqualTo _routeIdentity}
        && {(_recoveryWork get "driver") == _driver} && {(_recoveryWork get "operator") == _movementOperator}
        && {(expectedDestination _driver) isEqualTo (_recoveryWork get "driverCommand")}
        && {(expectedDestination _movementOperator) isEqualTo (_recoveryWork get "command")}
        && {currentCommand _movementOperator != "STOP"}
        && {[_driver,_movementOperator] findIf {
            !(toUpperANSI currentCommand _x in ["","MOVE","WAIT"])
        } < 0};
    if (count _recoveryWork > 0 && {(_recoveryWork get "group") == _group} && {!_recoveryOwned}) then {
        if ((_recoveryWork get "route") isEqualTo _routeIdentity) then {
            _group setVariable ["WAIT_DrivingRecovery_Yield",_routeIdentity,true];
        };
        [_vehicle,_group,"ORDER_OR_SEATS_CHANGED",false] call WAIT_fnc_DrivingRecoveryRelease;
        _recoveryWork=createHashMap;
    };
    private _release=(_group getVariable ["WAIT_DrivingRecovery_Yield",[]]) isEqualTo _routeIdentity;

    // Driving must make the same ownership decision as every other delayed controller. A group
    // member becoming player-controlled or specialist-owned is enough to retire the sparse speed
    // cap before it can issue a recovery move; the individual driver checks below retain the
    // vehicle-specific local/remote-control safety boundary.
    private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;
    if (!_enabled || {!local _vehicle} || {!alive _vehicle} || {!canMove _vehicle}
        || {!([_driver] call WAIT_fnc_CortexCombatEffective)} || {isPlayer _driver}
        || {!isNull (_driver getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[_driver] call WAIT_fnc_CortexExternalOwner != ""}
        || {_yieldToOwner}
        || {!([_driver] call _nativeTaskFree)}
        || {!([_movementOperator] call _nativeTaskFree)}
        || {getForcedSpeed _vehicle == 0 && {
            private _heldState=_vehicle getVariable ["WAIT_DrivingAssist_State",[]];
            !((_recoveryOwned && {(_recoveryWork get "cap") == 0}) || {(_heldState param [0,-1]) == 0 && {(_heldState param [3,grpNull]) == _group}
                && {!isNull ((_vehicle getVariable ["WAIT_DrivingAssist_Traffic",[]]) param [1,objNull])}})
        }}
        || {_vehicle getVariable ["WAIT_Convoy_Active",false]}
        || {!isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
        || {behaviour leader _group == "CARELESS"}
        || {_routeIdentity isEqualTo []}) then {_release=true};
    if (_release) then {[_vehicle,_group] call WAIT_fnc_DrivingAssistRelease} else {
        // Terrain sampling is deliberately sparse but may still overlap a newer Zeus or specialist
        // order. Preserve that order at the actual cap/recovery command boundary.
        private _mayIssueDriving = {
            local _group && {local _vehicle}
                && {[_group] call WAIT_fnc_DrivingMovementAvailable}
                && {driver _vehicle isEqualTo _driver}
                && {(effectiveCommander _vehicle) in [_movementOperator,objNull]}
                && {vehicle _movementOperator isEqualTo _vehicle}
                && {local _driver} && {group _driver == _group}
                && {!isPlayer _driver} && {isNull remoteControlled _driver}
                && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
                && {alive _vehicle} && {canMove _vehicle}
                && {[_driver] call WAIT_fnc_CortexCombatEffective}
                && {[_movementOperator] call WAIT_fnc_CortexCombatEffective}
                && {local _movementOperator} && {group _movementOperator == _group}
                && {!isPlayer _movementOperator} && {isNull remoteControlled _movementOperator}
                && {_driver checkAIFeature "MOVE"} && {_driver checkAIFeature "PATH"}
                && {_movementOperator checkAIFeature "MOVE"} && {_movementOperator checkAIFeature "PATH"}
                && {[_driver] call _nativeTaskFree} && {[_movementOperator] call _nativeTaskFree}
                && {_routeIdentity isNotEqualTo []}
                && {(call _readRouteIdentity) isEqualTo _routeIdentity}
        };
        // A shared group waypoint authorizes the leader vehicle's route, not independent
        // follower manoeuvres. Keep this separate from the safety cap: followers can still
        // receive a terrain cap while their formation movement stays native.
        private _nativeWaiting = {
            private _index=currentWaypoint _group;
            if (_index <= 0 || {_index >= count waypoints _group}) exitWith {false};
            private _waypoint=[_group,_index];
            if (abs speed _vehicle >= 1 || {!unitReady _vehicle}
                || {_vehicle distance2D (waypointPosition _waypoint) > ((waypointCompletionRadius _waypoint max 0)+50)}) exitWith {false};
            private _condition=toLowerANSI (((waypointStatements _waypoint) param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
            waypointType _waypoint == "HOLD"
                || {(synchronizedTriggers _waypoint) findIf {!isNull _x && {!triggerActivated _x}} >= 0}
                || {(waypointTimeout _waypoint param [2,0]) > 0}
                || {_condition != "true"}
        };
        // A distant script/timer/synchronization gate is still authored intent. Recovery
        // may refresh only a plain MOVE, never bypass a gate merely because it is far away.
        private _recoveryOrderFree = {
            private _index=currentWaypoint _group;
            if (_index <= 0 || {_index >= count waypoints _group}) exitWith {false};
            private _waypoint=[_group,_index];
            private _statements=waypointStatements _waypoint;
            private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
            waypointType _waypoint == "MOVE" && {_condition == "true"}
                && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
                && {waypointScript _waypoint == ""}
                && {(waypointTimeout _waypoint param [2,0]) <= 0}
                && {isNull waypointAttachedVehicle _waypoint} && {isNull waypointAttachedObject _waypoint}
                && {(synchronizedWaypoints _waypoint) isEqualTo []}
                && {(synchronizedTriggers _waypoint) findIf {!isNull _x && {!triggerActivated _x}} < 0}
        };
        private _mayRecoverRoute = {
            call _mayIssueDriving && {vehicle leader _group isEqualTo _vehicle} && {!(call _nativeWaiting)}
                && {call _recoveryOrderFree}
        };
        private _nativeRouteIntent={
            private _command=toUpperANSI currentCommand _movementOperator;
            if (_command == "STOP") exitWith {false};
            if (!(_command in ["MOVE","WAIT"])) exitWith {_command == ""};
            private _native=expectedDestination _movementOperator;
            private _waypoint=[_group,currentWaypoint _group];
            if (_command == "MOVE" && {(_native param [0,[]]) distance2D waypointPosition _waypoint <= 3}) exitWith {true};
            // The rear leg intentionally differs from the waypoint. Only an unchanged
            // current journal can authorize its own finite forward handback (including owned WAIT),
            // not another MOVE or an unowned WAIT.
            private _owned=_vehicle getVariable ["WAIT_DrivingRecovery_Work",createHashMap];
            count _owned > 0 && {(_owned get "group") == _group}
                && {(_owned get "route") isEqualTo _routeIdentity}
                && {(_owned get "driver") == _driver} && {(_owned get "operator") == _movementOperator}
                && {(expectedDestination _driver) isEqualTo (_owned get "driverCommand")}
                && {_native isEqualTo (_owned get "command")}
        };
        private _mayRecoverOrdinaryRoute={call _mayRecoverRoute && {call _nativeRouteIntent}
            && {toUpperANSI currentCommand _driver in ["","MOVE","WAIT"]}};
        private _priorOwner=(_vehicle getVariable ["WAIT_DrivingAssist_State",[]]) param [3,grpNull];
        if (!isNull _priorOwner && {_priorOwner != _group}) then {
            // A new driver group adopts only after retiring the old group's exact cap lease.
            [_vehicle,_priorOwner] call WAIT_fnc_DrivingAssistRelease;
        };
        if (time >= (_vehicle getVariable ["WAIT_DrivingAssist_Next",-1])) then {
            // A new Zeus, mission or specialist cap may not advertise an ownership marker. The
            // last cap we applied is therefore the narrowest reliable lease check: once another
            // value replaces it, release without restoring the stale pre-WAIT value.
            private _previous=_vehicle getVariable ["WAIT_DrivingAssist_Restore",[]];
            private _state=_vehicle getVariable ["WAIT_DrivingAssist_State",[]];
            if (_state isEqualTo [] && {_recoveryOwned}
                && {abs ((getForcedSpeed _vehicle)-(_recoveryWork get "cap")) <= 0.1}) then {
                private _kind=_recoveryWork get "kind";
                private _stage=switch (_kind) do {case "REFRESH":{1};case "FINAL":{3};default {2}};
                private _deadline=_recoveryWork get "deadline";
                if (_stage == 1 && {serverTime >= (_recoveryWork get "hardDeadline")-60}) then {_stage=2};
                _state=[_recoveryWork get "cap",0,time,_group,+(_recoveryWork get "origin"),
                    time-(serverTime-(_recoveryWork get "started")),_stage,time+(_deadline-serverTime),
                    "ADOPTED_RECOVERY",_routeIdentity,_kind == "REVERSE"];
                _previous=+(_recoveryWork get "baseline");
                _vehicle setVariable ["WAIT_DrivingAssist_Restore",_previous];
            };
            private _ownedCap=_state param [0,-1];
            if (_previous isNotEqualTo [] && {_ownedCap >= 0} && {abs ((getForcedSpeed _vehicle)-_ownedCap) > 0.1}) then {
                [_vehicle,_group] call WAIT_fnc_DrivingAssistRelease;
            } else {
            // Recovery belongs to this authored route, not merely to this vehicle.
            // Same-index waypoint replacement must not inherit an old reverse stage
            // or exhausted timer, nor receive an immediate recovery command.
            _routeIdentity=call _readRouteIdentity;
            if (_state isNotEqualTo [] && {(_state param [9,[]]) isNotEqualTo _routeIdentity}) then {
                _state set [4,getPosATL _vehicle];
                _state set [5,time];
                _state set [6,0];
                _state set [7,-1];
                _state set [8,"NEW_ROUTE"];_state set [10,false];
            };
            // A follower must not retain the cautious-reverse stage of a former leader.
            // Start a fresh observation interval if it later becomes the leader again.
            if (_state isNotEqualTo [] && {vehicle leader _group isNotEqualTo _vehicle}) then {
                // Retire the former leader's exact rear command before returning to formation.
                // Clearing only the stage would leave that native destination running.
                [_vehicle,_group,"NATIVE_FOLLOWER"] call WAIT_fnc_DrivingRecoveryRelease;
                _state set [4,getPosATL _vehicle];
                _state set [5,time];
                _state set [6,0];
                _state set [7,-1];
                _state set [8,"NATIVE_FOLLOWER"];_state set [10,false];
            };
            if (_state isNotEqualTo [] && {call _nativeWaiting}) then {
                _state set [4,getPosATL _vehicle];_state set [5,time];
                _state set [6,0];_state set [7,-1];_state set [8,"INTENTIONAL_WAIT"];_state set [10,false];
            };
            private _origin=getPosASL _vehicle;
            private _direction=vectorDir _vehicle;
            _direction set [2,0];
            if (vectorMagnitude _direction < 0.1) then {_direction=[sin (getDir _vehicle),cos (getDir _vehicle),0]};
            _direction=vectorNormalized _direction;
            private _maximumGrade=0;
            private _last=_origin;
            {
                private _sample=_origin vectorAdd (_direction vectorMultiply _x);
                _sample set [2,getTerrainHeightASL _sample];
                private _horizontal=(_sample distance2D _last) max 1;
                _maximumGrade=_maximumGrade max (abs ((_sample select 2)-(_last select 2))/_horizontal);
                _last=_sample;
            } forEach [20,45,70];
            private _cap=(missionNamespace getVariable ["WAIT_AIPass_DrivingAssist_MaxSpeed",70]) max 15 min 120;
            if (_maximumGrade > 0.2) then {_cap=_cap min 18} else {if (_maximumGrade > 0.12) then {_cap=_cap min 28}};
            // The shared read-only road walk anticipates bends/junctions without choosing a route.
            // It runs at this vehicle's existing sparse cadence; mission and traffic caps still win.
            private _roadObservation=[_vehicle,_cap] call WAIT_fnc_DrivingRoadCap;
            _cap=_cap min (_roadObservation select 0);
            // The short rear leg must not inherit the normal road-speed cap. Retain
            // this cautious cap through reverse observation and the final retry handoff.
            if ((_state param [6,0]) in [1,2]) then {_cap=_cap min 10};
            private _previous=_vehicle getVariable ["WAIT_DrivingAssist_Restore",[]];
            if (_previous isEqualTo []) then {
                _previous=[getForcedSpeed _vehicle];
                _vehicle setVariable ["WAIT_DrivingAssist_Restore",_previous];
            };
            private _saved=_previous param [0,-1];
            // Arma forceSpeed/getForcedSpeed values are metres per second. Keep the policy value
            // readable in km/h, but keep the actual lease in engine units so another controller's
            // cap is detected and the pre-WAIT value can be restored exactly.
            private _capMps=_cap/3.6;
            if (_saved > 0) then {_capMps=_capMps min _saved};
            private _recordRecovery={
                params ["_kind"];
                private _old=_vehicle getVariable ["WAIT_DrivingRecovery_Work",createHashMap];
                private _hard=if (count _old > 0 && {(_old get "group") == _group} && {(_old get "route") isEqualTo _routeIdentity}) then {
                    _old get "hardDeadline"
                } else {serverTime+96};
                private _deadline=switch (_kind) do {case "REFRESH":{_hard-66};case "FINAL":{_hard};default {_hard-60}};
                private _work=createHashMapFromArray [["group",_group],["route",_routeIdentity],["driver",_driver],["operator",_movementOperator],
                    ["driverCommand",+(expectedDestination _driver)],["command",+(expectedDestination _movementOperator)],
                    ["kind",_kind],["started",serverTime],["deadline",_deadline],["hardDeadline",_hard],
                    ["origin",getPosATL _vehicle],["baseline",+_previous],["cap",_capMps]];
                _vehicle setVariable ["WAIT_DrivingRecovery_Work",_work,true];
                time+(_deadline-serverTime)
            };
            private _reverseIssued=_state param [10,(_state param [8,""]) == "CAUTIOUS_REVERSE"];
            private _reverseLeg=(_state param [6,0]) == 2 && {_reverseIssued}
                && {time < (_state param [7,-1])};
            private _reverseExpired=(_state param [6,0]) == 2 && {_reverseIssued} && {!_reverseLeg};
            private _retryAllowed=!_reverseExpired || {
                [_group,"WAIT_AIPass_DrivingAssist_Recovery_Enable",true] call WAIT_fnc_CortexFeatureEnabled
                    && {!(behaviour leader _group in ["COMBAT","STEALTH"])} && {getSuppression _driver <= 0.1}
                    && {call _mayRecoverOrdinaryRoute}
            };
            private _traffic=if (!_reverseLeg) then {
                [_vehicle,_capMps] call WAIT_fnc_DrivingFollowingCap
            } else {[_capMps,objNull,-1,time,0]};
            private _turn=[_vehicle,_geometryTracks getOrDefault [netId _vehicle,[]],[_routeIdentity,_brain getOrDefault ["ownerEpoch",-1]]] call WAIT_fnc_DrivingTurnTrack;
            _geometryTracks set [netId _vehicle,_turn select 1];
            private _nativeHint=[_vehicle,_group,["ORDINARY",_routeIdentity,_brain getOrDefault ["ownerEpoch",-1]]] call WAIT_fnc_DrivingNativePathWatch;
            private _curveHint=if (_nativeHint isEqualTo []) then {[_turn select 0]} else {_nativeHint};
            private _geometry=if (!_reverseLeg) then {[_vehicle,_capMps,false,_curveHint] call WAIT_fnc_DrivingGeometryCap} else {[[],[]]};
            private _gateObservation=_geometry select 0;
            private _obstacleObservation=_geometry select 1;
            if (_gateObservation isNotEqualTo [] && {(_gateObservation select 0) < (_traffic select 0)}) then {_traffic=_gateObservation};
            private _withoutObstacle=+_traffic;
            private _obstacleLimited=_obstacleObservation isNotEqualTo []
                && {(_obstacleObservation select 0) < (_traffic select 0)};
            if (_obstacleLimited) then {
                _traffic=_obstacleObservation select [0,5];
                if (isNull (_traffic select 1)) then {_traffic set [1,_vehicle]};
            };
            _vehicle setVariable ["WAIT_DrivingAssist_Obstacle",_obstacleObservation];
            // Share the convoy observer without adding a second speed writer. Its zero cap
            // uses the existing traffic lease and faster sampling, and cannot trigger recovery.
            // Check the intended rear direction even while stopped. At the finite rear-leg
            // deadline observe the forward retry, so a rear-only obstacle cannot trap handback.
            private _travelIntent=if (_reverseLeg) then {-1} else {[0,1] select ((_state param [6,0]) == 2)};
            private _pedestrianCap=[_vehicle,_capMps*3.6,_group,true,_travelIntent] call WAIT_fnc_CortexInfantrySpeed;
            if (_reverseLeg) then {
                private _rearObservation=[_vehicle,8] call WAIT_fnc_DrivingRearClear;
                if !(_rearObservation select 0) then {_traffic=[0,_vehicle,-1,time,0]};
            };
            if (_pedestrianCap/3.6 < (_traffic select 0)) then {
                _traffic=[_pedestrianCap/3.6,_vehicle,-1,time,0];
            };
            // An expired owned rear command cannot keep moving just because combat or a
            // recovery feature change currently prevents the forward retry. Hold its exact
            // speed lease until normal retry admission or a newer order/controller takes over.
            if (_reverseExpired && {!_retryAllowed}) then {_traffic=[0,_vehicle,-1,time,0]};
            // Corridor execution is part of this same owner callback, never a second controller.
            // Do not take over an issued/expired rear leg. Existing traffic and pedestrian caps win.
            private _hadBypass=!isNil {_vehicle getVariable "WAIT_DrivingBypass_Work"};
            private _hadCorridor=!isNil {_vehicle getVariable "WAIT_DrivingCorridor_Work"};
            private _corridor=[false,1e6,""];
            if (!_reverseLeg && {!_reverseExpired} && {!_hadBypass} && {call _mayRecoverRoute}) then {
                _corridor=[_group,_vehicle,_brain] call WAIT_fnc_DrivingCorridorStep;
            } else {
                if (_hadCorridor) then {
                    [_vehicle,_group,"ROUTE_AUTHORITY_ENDED"] call WAIT_fnc_DrivingCorridorRelease;
                };
            };
            private _corridorActive=_corridor select 0;
            private _bypass=[false,1e6,"",false];
            if (!_corridorActive && {!_hadCorridor} && {!_reverseLeg} && {!_reverseExpired}
                && {call _mayRecoverRoute}) then {
                _bypass=[_group,_vehicle,_brain,_obstacleObservation,_mayRecoverRoute] call WAIT_fnc_DrivingBypassStep;
            } else {
                if (_hadBypass) then {[_vehicle,_group,"ROUTE_AUTHORITY_ENDED"] call WAIT_fnc_DrivingBypassRelease};
            };
            private _bypassActive=_bypass select 0;
            // Only a freshly validated active leg can yield this exact source object's forward
            // constraint. Other gates, occupied hulls and pedestrians keep their current caps.
            private _bypassWork=_vehicle getVariable ["WAIT_DrivingBypass_Work",createHashMap];
            if (_bypassActive && {_bypass select 3} && {_obstacleObservation isNotEqualTo []}
                && {(_obstacleObservation select 1) isEqualTo (_bypassWork getOrDefault ["obstacle",objNull])}
                && {(_obstacleObservation select 8) isEqualTo (_bypassWork getOrDefault ["transform",[]])}) then {
                _traffic=+_withoutObstacle;
                if (_pedestrianCap/3.6 < (_traffic select 0)) then {_traffic=[_pedestrianCap/3.6,_vehicle,-1,time,0]};
                _obstacleLimited=false;
            };
            _capMps=_capMps min (_bypass select 1);
            _capMps=_capMps min (_corridor select 1);
            // A closer pedestrian/rear constraint can supersede the solid-obstacle sample.
            _obstacleLimited=_obstacleLimited && {abs ((_traffic select 0)-(_obstacleObservation select 0)) <= 0.001};
            private _trafficLimited=!isNull (_traffic select 1);
            // A close static body can stop us before there is room for a bypass proposal.
            // It is not a traffic queue: permit the existing finite rear recovery only after
            // continuous fresh observation, with independent vehicle/gate/pedestrian caps clear.
            private _solidCandidate=_obstacleLimited && {count _obstacleObservation == 9}
                && {(_obstacleObservation select 5) == "STATIC"} && {(_obstacleObservation select 2) <= 8}
                && {!isNull (_obstacleObservation select 1)} && {abs speed _vehicle < 1}
                && {(_withoutObstacle select 0) > 0} && {_pedestrianCap > 0}
                && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass};
            private _solidSeen=_vehicle getVariable ["WAIT_DrivingSolidSeen",[]];
            private _solidObserver=[clientOwner,_brain getOrDefault ["ownerEpoch",-1],_routeIdentity];
            private _solidReady=false;
            if (_solidCandidate) then {
                private _contact=[_obstacleObservation select 1,_obstacleObservation select 8,_solidObserver];
                private _continuous=count _solidSeen == 3 && {(_solidSeen select 0) isEqualTo _contact}
                    && {serverTime >= (_solidSeen select 2)} && {serverTime-(_solidSeen select 2) <= 6};
                private _since=if (_continuous) then {_solidSeen select 1} else {serverTime};
                _solidReady=serverTime-_since >= 3;
                _vehicle setVariable ["WAIT_DrivingSolidSeen",[_contact,_since,serverTime]];
            } else {_vehicle setVariable ["WAIT_DrivingSolidSeen",nil]};
            _capMps=_capMps min (_traffic select 0);
            if !(call _mayIssueDriving) then {
                // An initial admission has not applied a cap or created an owning state yet.
                // Discard only that unapplied snapshot; established leases use normal release.
                if (_state isEqualTo []) then {_vehicle setVariable ["WAIT_DrivingAssist_Restore",nil]};
                [_vehicle,_group] call WAIT_fnc_DrivingAssistRelease;
            } else {
            _vehicle forceSpeed _capMps;
            if (_gateObservation isNotEqualTo [] && {call _mayIssueDriving}) then {
                [_group,_vehicle,_gateObservation] call WAIT_fnc_DrivingGateRequest;
            };
            _vehicle setVariable ["WAIT_DrivingAssist_Traffic",_traffic];
            // Retain the owning group for diagnostics only. The lease remains the forced-speed
            // value: this reference never grants route or movement ownership to WAIT.
            // Native vehicles can abandon an otherwise valid MOVE command after a small collision
            // or navigation fault.  Recovery remains subordinate to that authored waypoint:
            // refresh it once, reverse only into a checked-clear rear area, then retry once.
            // It never adds/replaces a waypoint, changes collision or moves the vehicle directly.
            private _progressPosition=_state param [4,getPosATL _vehicle];
            private _progressAt=_state param [5,time];
            private _recoveryStage=_state param [6,0];
            private _recoveryUntil=_state param [7,-1];
            private _recoveryResult=_state param [8,"IDLE"];
            if (call _nativeWaiting) then {_recoveryResult="INTENTIONAL_WAIT"};
            // Bounded traffic replan: keep collision caps, never recreate the authored waypoint.
            // The public budget survives owner changes; interrupted dwell is not accumulated.
            private _jam=_vehicle getVariable ["WAIT_DrivingTrafficRetry",createHashMap];
            private _jamChanged=false;
            if (count _jam > 0 && {(_jam get "route") isNotEqualTo _routeIdentity
                || {(_jam get "group") != _group}
                || {(_vehicle distance2D (_jam get "origin")) >= 15
                    && {((_jam get "origin") distance2D waypointPosition [_group,currentWaypoint _group])
                        -(_vehicle distance2D waypointPosition [_group,currentWaypoint _group]) >= 15}}}) then {
                _jam=createHashMap;_jamChanged=true;
            };
            private _jamPeer=_traffic select 1;
            private _jamEligible=_trafficLimited && {!isNull _jamPeer} && {_jamPeer != _vehicle}
                && {_jamPeer isKindOf "LandVehicle"} && {abs speed _jamPeer < 1} && {abs speed _vehicle < 1}
                && {_recoveryStage == 0} && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass}
                && {behaviour leader _group in ["SAFE","AWARE"]} && {getSuppression _driver <= 0.1}
                && {[_group,"WAIT_AIPass_DrivingAssist_Recovery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
                && {call _mayRecoverOrdinaryRoute};
            private _jamObserver=[clientOwner,_brain getOrDefault ["ownerEpoch",-1],_routeIdentity,_driver,_movementOperator];
            private _jamSeen=_vehicle getVariable ["WAIT_DrivingTrafficSeen",[]];
            private _jamOwnPose=getPosASL _vehicle;
            private _jamPeerPose=getPosASL _jamPeer;
            private _jamContinuous=count _jamSeen == 5 && {(_jamSeen select 0) isEqualTo _jamObserver}
                && {(_jamSeen select 1) == _jamPeer} && {serverTime >= (_jamSeen select 2)}
                && {serverTime-(_jamSeen select 2) <= 6}
                && {_jamOwnPose vectorDistance (_jamSeen select 3) <= 1.5}
                && {_jamPeerPose vectorDistance (_jamSeen select 4) <= 1.5};
            // Anchors belong to the whole dwell, not just the preceding sample: otherwise
            // a slow queue could creep indefinitely while every adjacent displacement is small.
            private _jamOwnAnchor=if (_jamContinuous) then {+(_jamSeen select 3)} else {+_jamOwnPose};
            private _jamPeerAnchor=if (_jamContinuous) then {+(_jamSeen select 4)} else {+_jamPeerPose};
            // This local observation receipt is not replayed or broadcast. Migration/gaps/motion
            // restart only stationary dwell, never the public attempt count or hard deadline.
            _vehicle setVariable ["WAIT_DrivingTrafficSeen",if (_jamEligible) then {[_jamObserver,_jamPeer,serverTime,_jamOwnAnchor,_jamPeerAnchor]} else {nil}];
            if (_jamEligible) then {
                if (count _jam == 0) then {
                    _jam=createHashMapFromArray [["group",_group],["route",_routeIdentity],["driver",_driver],["operator",_movementOperator],
                        ["driverCommand",+(expectedDestination _driver)],["command",+(expectedDestination _movementOperator)],
                        ["origin",getPosATL _vehicle],["deadline",serverTime+80],["next",serverTime+20],
                        ["attempts",0],["peer",_jamPeer],["since",serverTime],["yielded",false]];
                    _jamChanged=true;
                };
                if ((_jam get "driver") != _driver || {(_jam get "operator") != _movementOperator}
                    || {(expectedDestination _driver) isNotEqualTo (_jam get "driverCommand")}
                    || {(expectedDestination _movementOperator) isNotEqualTo (_jam get "command")}) then {
                    if !(_jam get "yielded") then {_jam set ["yielded",true];_jamChanged=true};
                };
                if (!_jamContinuous || {(_jam get "peer") != _jamPeer} || {(_jam get "since") < 0}) then {
                    _jam set ["peer",_jamPeer];_jam set ["since",serverTime];_jamChanged=true;
                };
                if (!(_jam get "yielded") && {(_jam get "attempts") < 3} && {serverTime < (_jam get "deadline")}
                    && {serverTime >= (_jam get "next")} && {serverTime-(_jam get "since") >= 20}
                    && {call _mayRecoverOrdinaryRoute}) then {
                    _movementOperator doMove waypointPosition [_group,currentWaypoint _group];
                    _jam set ["attempts",(_jam get "attempts")+1];_jam set ["next",serverTime+20];
                    _jam set ["driverCommand",+(expectedDestination _driver)];
                    _jam set ["command",+(expectedDestination _movementOperator)];_jamChanged=true;
                };
            } else {
                if (count _jam > 0 && {(_jam get "since") >= 0}) then {
                    _jam set ["since",-1];_jamChanged=true;
                };
            };
            if (_jamChanged) then {_vehicle setVariable ["WAIT_DrivingTrafficRetry",_jam,true]};

            // Waiting behind traffic is not a route fault. Keep the last progress sample current so
            // clearing the queue does not immediately inherit a stale reverse deadline.
            if ((_trafficLimited && {!_solidCandidate}) || {_corridorActive} || {_hadCorridor} || {_bypassActive} || {_hadBypass}) then {
                _progressPosition=getPosATL _vehicle;_progressAt=time;
                // Keep an already-issued rear leg finite. After the pedestrian clears,
                // its expired deadline returns to the authored route instead of losing
                // the rear-leg receipt and treating backward travel as ordinary progress.
                if (_recoveryStage != 2) then {
                    [_vehicle,_group,"RECOVERY_PAUSED",false] call WAIT_fnc_DrivingRecoveryRelease;
                    _recoveryStage=0;_recoveryUntil=-1;_reverseIssued=false
                };
                _recoveryResult=if (_bypassActive) then {_bypass select 2} else {if (_corridorActive) then {_corridor select 2} else {
                    if (_obstacleLimited) then {["OBSTACLE_WAIT","OBSTACLE_APPROACH"] select (abs speed _vehicle >= 1)} else {
                        ["CORRIDOR_HANDBACK","TRAFFIC_FOLLOW"] select _trafficLimited
                    }
                }};
            };
            private _routeProgress=true;
            if (_recoveryStage > 0) then {
                private _progressWaypoint=currentWaypoint _group;
                _routeProgress=false;
                if (_progressWaypoint < count waypoints _group) then {
                    private _progressDestination=waypointPosition [_group,_progressWaypoint];
                    _routeProgress=(_progressPosition distance2D _progressDestination)
                        -(_vehicle distance2D _progressDestination) >= 3;
                };
            };
            // Reversing is a recovery leg, not proof that the original route resumed.
            // Do not reset its finite stages merely because the vehicle moved backwards.
            if (_recoveryStage != 2 && {!_trafficLimited} && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {_vehicle distance2D _progressPosition >= 3} && {_routeProgress}) then {
                _progressPosition=getPosATL _vehicle;
                _progressAt=time;
                _recoveryStage=0;
                _recoveryUntil=-1;
                _recoveryResult="PROGRESS";_reverseIssued=false;
                [_vehicle,_group,"ROUTE_PROGRESS",false] call WAIT_fnc_DrivingRecoveryRelease;
            };
            private _waypointIndex=currentWaypoint _group;
            private _hasRoute=_waypointIndex < count waypoints _group;
            private _inCombat=behaviour leader _group in ["COMBAT","STEALTH"] || {getSuppression _driver > 0.1};
            // A reverse leg has its own finite deadline. It must return to the authored
            // route even while still moving; the ordinary stall timer is not another hold.
            private _scheduledRecovery=_vehicle getVariable ["WAIT_DrivingRecovery_Work",createHashMap];
            // A delayed callback must not start an already-expired rear window.
            if (_recoveryStage == 1 && {count _scheduledRecovery > 0}
                && {serverTime >= (_scheduledRecovery get "hardDeadline")-60}) then {
                _recoveryStage=2;_recoveryUntil=time;_reverseIssued=false;
            };
            private _finalExpired=_recoveryStage == 3 && {count _scheduledRecovery > 0}
                && {serverTime >= (_scheduledRecovery get "hardDeadline")};
            private _reverseComplete=_recoveryStage == 2 && {time >= _recoveryUntil};
            // Retiring an expired exact rear command does not grant movement through the
            // blocked forward lane: its already-applied current safety cap remains intact.
            private _reverseHandback=_reverseComplete && {_reverseIssued};
            // Preserve native planning time rather than repeatedly restarting a difficult route.
            // Real progress, a replaced order, follower ownership or an intentional wait already
            // resets this stage and its progress clock above. A rear leg keeps its finite expiry.
            private _observationWindow=[20,30,0,60] param [_recoveryStage,60];
            if (_hasRoute && {[_group,"WAIT_AIPass_DrivingAssist_Recovery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
                && {!_inCombat} && {!_trafficLimited || {_solidReady} || {_reverseHandback}} && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {abs speed _vehicle < 1 || {_reverseComplete}}
                && {time-_progressAt >= _observationWindow || {_reverseComplete} || {_finalExpired}} && {time >= _recoveryUntil}
                && {call _mayIssueDriving} && {call _mayRecoverOrdinaryRoute}) then {
                private _waypoint=[_group,_waypointIndex];
                private _destination=waypointPosition _waypoint;
                if (waypointType _waypoint == "MOVE" && {_vehicle distance2D _destination > (waypointCompletionRadius _waypoint max 20)}) then {
                    switch (_recoveryStage) do {
                        case 0: {
                            if !(call _mayRecoverOrdinaryRoute) exitWith {};
                            _movementOperator doMove _destination;
                            _recoveryStage=1;
                            _recoveryUntil=["REFRESH"] call _recordRecovery;
                            _recoveryResult="ROUTE_REFRESH";_reverseIssued=false;
                        };
                        case 1: {
                            private _rear=_vehicle getPos [8,(getDir _vehicle)+180];
                            // Fresh shared body-width observation; no fixed-width centre probe.
                            private _clearance=[_vehicle,8] call WAIT_fnc_DrivingRearClear;
                            private _rearSafe=(_clearance select 0) && {!surfaceIsWater _rear}
                                && {((surfaceNormal _rear) select 2) >= 0.7};
                            if (_rearSafe && {call _mayIssueDriving} && {call _mayRecoverOrdinaryRoute}) then {
                                _movementOperator doMove _rear;
                                _recoveryResult="CAUTIOUS_REVERSE";_reverseIssued=true;
                            } else {
                                _recoveryResult="REAR_BLOCKED";_reverseIssued=false;
                            };
                            _recoveryStage=2;
                            _recoveryUntil=[["BLOCKED","REVERSE"] select _reverseIssued] call _recordRecovery;
                        };
                        case 2: {
                            if !(call _mayRecoverOrdinaryRoute) exitWith {};
                            _movementOperator doMove _destination;
                            _recoveryStage=3;
                            _recoveryUntil=["FINAL"] call _recordRecovery;
                            _recoveryResult="FINAL_ROUTE_RETRY";_reverseIssued=false;
                        };
                        default {
                            _recoveryResult="EXHAUSTED";_reverseIssued=false;
                            _recoveryUntil=time+60;
                        };
                    };
                    _progressPosition=getPosATL _vehicle;
                    _progressAt=time;
                };
            };
            private _liveRecovery=_vehicle getVariable ["WAIT_DrivingRecovery_Work",createHashMap];
            if (count _liveRecovery > 0 && {(_liveRecovery get "group") == _group}
                && {(_liveRecovery get "cap") != _capMps}) then {
                _liveRecovery set ["cap",_capMps];_vehicle setVariable ["WAIT_DrivingRecovery_Work",_liveRecovery,true];
            };
            _vehicle setVariable ["WAIT_DrivingAssist_State",[_capMps,_maximumGrade,time,_group,
                _progressPosition,_progressAt,_recoveryStage,_recoveryUntil,_recoveryResult,_routeIdentity,_reverseIssued]];
            _vehicle setVariable ["WAIT_DrivingAssist_Next",time+([4,1] select (_trafficLimited || {_corridorActive} || {_bypassActive} || {_recoveryStage == 2}))];
            };
            };
        };
    };
} forEach _vehicles;

/*
 * Author: WaldoTheWarfighter
 * Maintains one finite ground-vehicle manoeuvre issued by a combined-arms contact opportunity.
 * Arrival fire rechecks actual loaded gunner-station ammunition against the target platform class.
 * The vehicle uses one temporary Cortex waypoint to move to a safe-side firing position. It does
 * not wait for another arm, teleport, repeatedly replace the route or force progress through an
 * obstruction. Arrival, target loss, expiry, locality migration, feature closure or direct Zeus
 * influence releases only the Cortex waypoint and movement lease. A stalled vehicle gets one
 * bounded route replan; a second stall ends the role so gameplay roadblocks remain meaningful.
 * Locality/authority: runs only where the vehicle group is local after a server-authenticated role.
 * Repeat/JIP: the complete admitted opportunity rejects stale jobs, including same-token edits.
 * Locality replay queues one replacement job; legacy jobs without a snapshot retire safely.
 * Arrival fire requests require a combat-effective local gunner; arrival alone never proves fire effect.
 * Cleanup requires the matching operation generation, so a late role cannot delete a newer route.
 * Failed arrival fire, asset loss, immobility and exhausted movement retire the exact admitted
 * opportunity through the authenticated server fallback after owned cleanup. Original contact/expiry
 * never renew; a fire request remains an order, not proof of shots or effect.
 * Arguments: 0: job state <HASHMAP> containing group, asset, target, token, expiry and destination.
 * Return Value: Number of seconds before the next scheduler step, or -1 when complete.
 * Current callers: WAIT_fnc_CortexCombinedArmsLocal through WAIT_fnc_CortexQueueJob.
 * Example: [WAIT_fnc_CortexCombinedGroundStep,_job,1] call WAIT_fnc_CortexQueueJob;
 */
params [["_job",createHashMap,[createHashMap]]];
private _group=_job getOrDefault ["group",grpNull];
private _asset=_job getOrDefault ["asset",objNull];
private _target=_job getOrDefault ["target",objNull];
private _token=_job getOrDefault ["token",""];
private _destination=_job getOrDefault ["destination",[]];
private _operationGeneration=_job getOrDefault ["operationGeneration",-1];
private _ownerEpoch=_job getOrDefault ["ownerEpoch",-1];
private _snapshot=_job getOrDefault ["opportunity",[]];
private _roleCurrent={
    (count _snapshot) in [7,8] && {(_snapshot select 0) isEqualTo _token}
        && {(_snapshot select 2) isEqualTo _target} && {(_snapshot select 4) == "GROUND_MANOEUVRE"}
        && {(_snapshot select 5) isEqualTo (_job getOrDefault ["expiry",-1])}
        && {(_group getVariable ["WAIT_Cortex_CombinedRole",[]]) isEqualTo _snapshot}
};
private _finish={
    params ["_reason"];
    if (!isNull _group && {local _group}
        && {_ownerEpoch == (_group getVariable ["WAIT_AIPass_Epoch",0])}) then {
        private _operation=_group getVariable ["WAIT_Operation",createHashMap];
        private _operationMatches=count _operation > 0
            && {(_operation getOrDefault ["generation",-2]) == _operationGeneration}
            && {(_operation getOrDefault ["intent",""]) == "COMBINED_GROUND"}
            && {(_operation getOrDefault ["ownerEpoch",-1]) == _ownerEpoch};
        if (_operationMatches) then {
            if (_reason == "POSITION_REACHED") then {
                [_group,_operationGeneration,"COMPLETE","FIRING_POSITION_REACHED"] call WAIT_fnc_OperationRelease;
            } else {
                [_group,_operationGeneration,_reason] call WAIT_fnc_OperationCancel;
            };
        };
        if (_operationMatches && {_operationGeneration >= 0}) then {[_group,_operationGeneration] call WAIT_fnc_CortexGroupMoveClear;};
        private _state=[_group] call WAIT_fnc_CortexGroupState;
        private _lease=_state getOrDefault ["movementLease",[]];
        // The label alone is not ownership. A late callback from an older role can observe the
        // same label on its replacement, so only the still-matching operation may release it.
        if (_operationMatches && {(_lease param [0,""]) == "COMBINED_GROUND"}) then {
            [_group,"COMBINED_GROUND",false] call WAIT_fnc_CortexOwnershipLease;
            _state deleteAt "movementLease";
        };
        if (call _roleCurrent) then {
            private _progress=_group getVariable ["WAIT_Cortex_CombinedGroundProgress",[]];
            if (_operationMatches && {_progress isEqualType []} && {count _progress == 10}
                && {(_progress select 0) isEqualTo _snapshot} && {(_progress select 1) isEqualTo _asset}) then {
                _progress=+_progress;
                _progress set [9,["FAILED","COMPLETE"] select (_reason == "POSITION_REACHED")];
                _group setVariable ["WAIT_Cortex_CombinedGroundProgress",_progress,true];
            };
            _group setVariable ["WAIT_Cortex_CombinedResult",[_token,"GROUND_MANOEUVRE",_reason,serverTime,_target,_destination],true];
            // Only this admitted snapshot may spend a fallback slot. New roles, owners,
            // expiry, target loss and administrative cancellation cannot dispatch replacements.
            if (_operationMatches && {(count _snapshot) in [7,8]}
                && {(_group getVariable ["WAIT_Cortex_CombinedRole",[]]) isEqualTo _snapshot}
                && {serverTime < (_snapshot select 5)}
                && {_reason in ["NO_KNOWN_CONTACT","NO_FIRE_OPERATOR","NO_FIRE_PLATFORM","NO_STATION_AMMO","NO_TARGET_AMMO","BLOCKED_FIRE_LANE","ASSET_LOST","ASSET_IMMOBILE","BLOCKED","MOVEMENT_REJECTED","OWNER_LOST"]}) then {
                [_group,_snapshot,_reason,clientOwner] remoteExecCall ["WAIT_fnc_CortexCombinedRejectServer",2];
            };
        };
    };
    -1
};
if (isNull _group || {isNull _asset} || {!alive _asset}) exitWith {["ASSET_LOST"] call _finish};
if (!local _group || {_ownerEpoch != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {-1};
if !(call _roleCurrent) exitWith {["ROLE_RELEASED"] call _finish};
if ([_group] call WAIT_fnc_CortexZeusHeld) exitWith {["ZEUS_HANDOVER"] call _finish};
if (!([_group] call WAIT_fnc_CortexIsEligible)
    || {!([_group,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!([_group,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) exitWith {["FEATURE_CLOSED"] call _finish};
private _currentOperation=_group getVariable ["WAIT_Operation",createHashMap];
if ((_currentOperation getOrDefault ["generation",-2]) != _operationGeneration
    || {(_currentOperation getOrDefault ["intent",""]) != "COMBINED_GROUND"}
    || {(_currentOperation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {["REPLACED"] call _finish};
private _driver=driver _asset;
private _operator=effectiveCommander _asset;if (isNull _operator) then {_operator=_driver};
if (isNull _driver || {isNull _operator}
    || {_driver isNotEqualTo (_job getOrDefault ["driver",objNull])}
    || {_operator isNotEqualTo (_job getOrDefault ["operator",objNull])}
    || {group _driver != _group && {group _operator != _group}}) exitWith {["OWNER_LOST"] call _finish};
// A waypoint description alone cannot preserve authority over edited native orders.
private _routeCurrent={
    private _waypoint=_job getOrDefault ["moveWaypoint",[]];
    private _receipt=_job getOrDefault ["moveReceipt",[]];
    if (count _waypoint != 2 || {(_waypoint select 0) != _group}
        || {count _receipt != 3} || {(_waypoint select 1) < 0}
        || {(_waypoint select 1) >= count waypoints _group}) exitWith {false};
    private _intent=_group getVariable ["WAIT_Cortex_GroupMoveIntent",createHashMap];
    if ((_intent getOrDefault ["operationGeneration",-2]) != _operationGeneration
        || {(_intent getOrDefault ["waypoint",[]]) isNotEqualTo _waypoint}) exitWith {false};
    private _owned=[_group,"",false,_waypoint select 1] call WAIT_fnc_AuthoredRouteReceipt;
    if (_owned isNotEqualTo (_receipt select 2)) exitWith {false};
    if (count waypoints _group == (_receipt select 0)
        && {currentWaypoint _group == (_receipt select 1)}) exitWith {true};
    private _live=[_group] call WAIT_fnc_NativeOrderReceipt;
    // Engine completion may advance to the original next node before this callback.
    // The owned waypoint must still exist unchanged; deletion cannot masquerade as arrival.
    if (_asset distance2D _destination > 70 || {(_live select 0) != (_receipt select 0)}
        || {currentWaypoint _group != (_waypoint select 1)+1}) exitWith {false};
    private _native=_job getOrDefault ["nativeOrder",[]];
    if (count _native == 2 && {(_native select 1) == -1}) exitWith {
        currentWaypoint _group >= count waypoints _group
    };
    if (count _native != 3 || {count _live != 3}) exitWith {false};
    private _oldRows=_native select 2;private _liveRows=_live select 2;
    count _oldRows == 1 && {count _liveRows == 1}
        && {((_oldRows select 0) select [1]) isEqualTo ((_liveRows select 0) select [1])}
};
if !(call _routeCurrent) exitWith {["NATIVE_ORDER_CHANGED"] call _finish};
if (isNull _target || {!alive _target}) exitWith {["TARGET_LOST"] call _finish};
if (captive _target || {_target getVariable ["ace_captives_isSurrendering",false]}
    || {_target getVariable ["ace_captives_isHandcuffed",false]}
    || {(side _group) getFriend (side _target) >= 0.6}) exitWith {["TARGET_NO_LONGER_HOSTILE"] call _finish};
if (serverTime >= (_job getOrDefault ["expiry",serverTime])) exitWith {["EXPIRED"] call _finish};
// Dormancy/locality convergence cannot manufacture capability loss or renew this expiry.
if (!simulationEnabled _asset || {isObjectHidden _asset}) exitWith {1};
private _stationOperator=gunner _asset;
if (!isNull _stationOperator && {group _stationOperator == _group}
    && {[_stationOperator] call WAIT_fnc_CortexCombatEffective}
    && {!local _stationOperator || {!simulationEnabled _stationOperator} || {isObjectHidden _stationOperator}}) exitWith {1};
private _capabilityFailure="";
if (serverTime >= (_job getOrDefault ["capabilityAt",serverTime])) then {
    _job set ["capabilityAt",serverTime+4];
    if (!canFire _asset) then {_capabilityFailure="NO_FIRE_PLATFORM"};
    if (isNull _stationOperator || {group _stationOperator != _group}
        || {!([_stationOperator] call WAIT_fnc_CortexCombatEffective)}
        || {isPlayer _stationOperator} || {!isNull remoteControlled _stationOperator}
        || {([_stationOperator] call WAIT_fnc_CortexExternalOwner) != ""}
        || {[_stationOperator] call WAIT_fnc_CompatibilityExternalControl}
        || {!([_stationOperator] call WAIT_fnc_CortexActorFireTaskAvailable)}) then {
        _capabilityFailure="NO_FIRE_OPERATOR";
    };
    if (_capabilityFailure == "" && {!([_asset,_stationOperator] call WAIT_fnc_CortexGroundFireReady)}) then {
        _capabilityFailure="NO_STATION_AMMO";
    };
    if (_capabilityFailure == "" && {!([_asset,_stationOperator,_target] call WAIT_fnc_CortexGroundFireReady)}) then {
        _capabilityFailure="NO_TARGET_AMMO";
    };
};
if (_capabilityFailure != "") exitWith {[_capabilityFailure] call _finish};
if (_asset distance2D _destination > 70
    && {simulationEnabled _asset && {!isObjectHidden _asset} && {!canMove _asset}}) exitWith {["ASSET_IMMOBILE"] call _finish};
if (_asset distance2D _destination <= 70) exitWith {
    // Arrival grants no new observation. Preserve native/shared knowledge; do not refresh
    // an unseen moving target merely because the vehicle reached its firing position.
    private _gunner=gunner _asset;
    private _knownTarget=(_group knowsAbout _target) > 0;
    private _fireDecision=["NO_KNOWN_CONTACT","NO_FIRE_OPERATOR"] select _knownTarget;
    private _fireAllowed=_knownTarget && {!isNull _gunner} && {[_gunner] call WAIT_fnc_CortexCombatEffective} && {local _gunner}
        && {group _gunner == _group}
        && {simulationEnabled _asset} && {!isObjectHidden _asset}
        && {simulationEnabled _gunner} && {!isObjectHidden _gunner}
        && {!isPlayer _gunner} && {isNull remoteControlled _gunner}
        && {([_gunner] call WAIT_fnc_CortexExternalOwner) == ""}
        && {!([_gunner] call WAIT_fnc_CompatibilityExternalControl)}
        && {[_gunner] call WAIT_fnc_CortexActorFireTaskAvailable}
        && {combatMode _group in ["YELLOW","RED"]} && {unitCombatMode _gunner in ["YELLOW","RED"]}
        && {!([_group] call WAIT_fnc_CortexExternalTakeover)};
    if (_fireAllowed && {!canFire _asset}) then {_fireAllowed=false;_fireDecision="NO_FIRE_PLATFORM"};
    if (_fireAllowed && {!([_asset,_gunner] call WAIT_fnc_CortexGroundFireReady)}) then {
        _fireAllowed=false; _fireDecision="NO_STATION_AMMO";
    };
    if (_fireAllowed && {!([_asset,_gunner,_target] call WAIT_fnc_CortexGroundFireReady)}) then {
        _fireAllowed=false; _fireDecision="NO_TARGET_AMMO";
    };
    if (_fireAllowed) then {
        _fireDecision="BLOCKED_FIRE_LANE";
        private _laneClear=[_gunner,aimPos _target] call WAIT_fnc_CortexLineOfFireClear;
        if !(call _routeCurrent) then {_fireDecision="NATIVE_ORDER_CHANGED"} else {
            if (_laneClear && {call _roleCurrent}) then {
                _gunner doTarget _target;
                _gunner doFire _target;
                _fireDecision="ORDER_ISSUED";
            };
        };
    };
    // Physical arrival completes the move, not the requested fire effect. Fired-event and
    // target-damage evidence are still required by combat acceptance.
    _group setVariable ["WAIT_Cortex_CombinedFireDecision",[_token,_fireDecision,serverTime,_gunner,_target],true];
    [[_fireDecision,"POSITION_REACHED"] select (_fireDecision == "ORDER_ISSUED")] call _finish
};
if (time >= (_job getOrDefault ["progressAt",time])+10) then {
    private _travel=_asset distance2D (_job getOrDefault ["lastPosition",getPosATL _asset]);
    if (_travel < 8) then {
        private _stalls=_job getOrDefault ["stalls",0];
        if (_stalls >= 1) exitWith {_job set ["terminal","BLOCKED"]};
        // Reacquire a missing route once; a still-owned destination remains committed.
        // This cannot create an obstacle-avoidance spiral around a deliberate roadblock.
        if (!([_group] call WAIT_fnc_CortexExternalTakeover) && {call _routeCurrent}) then {
            // Spend before route reacquisition so transfer cannot refund this attempt.
            _job set ["stalls",_stalls+1];
            if (call _roleCurrent) then {
                _group setVariable ["WAIT_Cortex_CombinedGroundProgress",[+_snapshot,_asset,_stalls+1,
                    serverTime-(time-(_job get "progressAt")),+(_job get "lastPosition"),+_destination,
                    +(_job get "nativeOrder"),_job get "driver",_job get "operator","ACTIVE"],true];
            };
            private _waypoint=[_group,_destination,55,"MOVE",_operationGeneration] call WAIT_fnc_CortexGroupMove;
            if (isNull (_waypoint param [0,grpNull,[grpNull]]) || {(_waypoint param [1,-1,[0]]) < 0}) then {
                _job set ["terminal","MOVEMENT_REJECTED"];
            };
        };
    };
    _job set ["lastPosition",getPosATL _asset];
    _job set ["progressAt",time];
    if (call _roleCurrent) then {
        _group setVariable ["WAIT_Cortex_CombinedGroundProgress",[+_snapshot,_asset,
            _job getOrDefault ["stalls",0],serverTime,+(getPosATL _asset),+_destination,
            +(_job get "nativeOrder"),_job get "driver",_job get "operator","ACTIVE"],true];
    };
};
if ((_job getOrDefault ["terminal",""]) != "") exitWith {[_job get "terminal"] call _finish};
1

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
 * Repeat/JIP: the public role token rejects stale jobs; locality replay queues one replacement job.
 * Arrival fire requests require a combat-effective local gunner; arrival alone never proves fire effect.
 * Cleanup requires the matching operation generation, so a late role cannot delete a newer route.
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
        if (((_group getVariable ["WAIT_Cortex_CombinedRole",[]]) param [0,""]) == _token) then {
            _group setVariable ["WAIT_Cortex_CombinedResult",[_token,"GROUND_MANOEUVRE",_reason,serverTime,_target,_destination],true];
        };
    };
    -1
};
if (isNull _group || {isNull _asset} || {!alive _asset}) exitWith {["ASSET_LOST"] call _finish};
if (!local _group || {_ownerEpoch != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {-1};
private _role=_group getVariable ["WAIT_Cortex_CombinedRole",[]];
if (!((count _role) in [7,8]) || {(_role select 0) != _token} || {(_role select 4) != "GROUND_MANOEUVRE"}) exitWith {["ROLE_RELEASED"] call _finish};
if ([_group] call WAIT_fnc_CortexZeusHeld) exitWith {["ZEUS_HANDOVER"] call _finish};
if (!([_group] call WAIT_fnc_CortexIsEligible)
    || {!([_group,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!([_group,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) exitWith {["FEATURE_CLOSED"] call _finish};
private _currentOperation=_group getVariable ["WAIT_Operation",createHashMap];
if ((_currentOperation getOrDefault ["generation",-2]) != _operationGeneration
    || {(_currentOperation getOrDefault ["intent",""]) != "COMBINED_GROUND"}
    || {(_currentOperation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {["REPLACED"] call _finish};
if (isNull _target || {!alive _target}) exitWith {["TARGET_LOST"] call _finish};
if (captive _target || {_target getVariable ["ace_captives_isSurrendering",false]}
    || {_target getVariable ["ace_captives_isHandcuffed",false]}
    || {(side _group) getFriend (side _target) >= 0.6}) exitWith {["TARGET_NO_LONGER_HOSTILE"] call _finish};
if (serverTime >= (_job getOrDefault ["expiry",serverTime])) exitWith {["EXPIRED"] call _finish};
if (_asset distance2D _destination <= 70) exitWith {
    // Arrival grants no new observation. Preserve native/shared knowledge; do not refresh
    // an unseen moving target merely because the vehicle reached its firing position.
    private _gunner=gunner _asset;
    private _knownTarget=(_group knowsAbout _target) > 0;
    private _fireDecision=["NO_KNOWN_CONTACT","NO_FIRE_OPERATOR"] select _knownTarget;
    private _fireAllowed=_knownTarget && {!isNull _gunner} && {[_gunner] call WAIT_fnc_CortexCombatEffective} && {local _gunner}
        && {simulationEnabled _asset} && {!isObjectHidden _asset}
        && {simulationEnabled _gunner} && {!isObjectHidden _gunner}
        && {!isPlayer _gunner} && {isNull remoteControlled _gunner}
        && {([_gunner] call WAIT_fnc_CortexExternalOwner) == ""}
        && {!([_gunner] call WAIT_fnc_CompatibilityExternalControl)}
        && {combatMode _group in ["YELLOW","RED"]} && {unitCombatMode _gunner in ["YELLOW","RED"]}
        && {!([_group] call WAIT_fnc_CortexExternalTakeover)};
    if (_fireAllowed && {!([_asset,_gunner] call WAIT_fnc_CortexGroundFireReady)}) then {
        _fireAllowed=false; _fireDecision="NO_STATION_AMMO";
    };
    if (_fireAllowed && {!([_asset,_gunner,_target] call WAIT_fnc_CortexGroundFireReady)}) then {
        _fireAllowed=false; _fireDecision="NO_TARGET_AMMO";
    };
    if (_fireAllowed) then {
        _fireDecision="BLOCKED_FIRE_LANE";
        if ([_gunner,aimPos _target] call WAIT_fnc_CortexLineOfFireClear) then {
            _gunner doTarget _target;
            _gunner doFire _target;
            _fireDecision="ORDER_ISSUED";
        };
    };
    // Physical arrival completes the move, not the requested fire effect. Fired-event and
    // target-damage evidence are still required by combat acceptance.
    _group setVariable ["WAIT_Cortex_CombinedFireDecision",[_token,_fireDecision,serverTime,_gunner,_target],true];
    ["POSITION_REACHED"] call _finish
};
if (time >= (_job getOrDefault ["progressAt",time])+10) then {
    private _travel=_asset distance2D (_job getOrDefault ["lastPosition",getPosATL _asset]);
    if (_travel < 8) then {
        private _stalls=_job getOrDefault ["stalls",0];
        if (_stalls >= 1) exitWith {_job set ["terminal","BLOCKED"]};
        // Reacquire a missing route once; a still-owned destination remains committed.
        // This cannot create an obstacle-avoidance spiral around a deliberate roadblock.
        if !([_group] call WAIT_fnc_CortexExternalTakeover) then {
            private _waypoint=[_group,_destination,55,"MOVE",_operationGeneration] call WAIT_fnc_CortexGroupMove;
            _job set ["stalls",_stalls+1];
            if (isNull (_waypoint param [0,grpNull,[grpNull]]) || {(_waypoint param [1,-1,[0]]) < 0}) then {
                _job set ["terminal","MOVEMENT_REJECTED"];
            };
        };
    };
    _job set ["lastPosition",getPosATL _asset];
    _job set ["progressAt",time];
};
if ((_job getOrDefault ["terminal",""]) != "") exitWith {[_job get "terminal"] call _finish};
1

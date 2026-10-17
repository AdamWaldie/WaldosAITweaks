/*
 * Author: WaldoTheWarfighter
 * Machine-local discovery sweep for Cortex, run as a scheduler job every
 * WAIT_AIPass_DiscoveryInterval seconds (default 10) on the server and each headless client.
 *
 * One sweep caches candidates and installs repeat-safe ground-group ownership handlers:
 * - caches player positions for the distance tiers (one allPlayers read per sweep, not per group);
 * - starts one generation-scoped owner-local group tactics FSM for each newly local, eligible
 *   non-aircraft group and records its peak strength. The FSM submits bounded decisions to the shared
 *   scheduler, so headless handover cannot leave a second persistent group worker behind;
 * - re-applies garrison orders on the new owner after a locality change, because disableAI and
 *   event handlers are stored per machine;
 * - reconciles finite movement ownership for independent alternative controllers;
 * - retires inherited exact pass-leg receipts in the existing sixteen-vehicle chunk, including
 *   vehicle locality that arrives after group adoption, without replaying the old pass;
 * - caches locally owned, eligible artillery for fire support and counter-battery;
 * - re-applies defence-line orders after a locality change;
 * - installs the missile-warning handler on every locally owned, eligible AI aircraft. A warning
 *   starts one finite, threat-tracked countermeasure sequence with two energy-preserving break
 *   impulses; a later missile replaces and extends that response. It never injects a waypoint,
 *   stops the aircraft or rewrites the native planner every frame.
 * - reserves aircraft crews from the generic group domain, then queues proactive attack-run flare
 *   sampling and the finite adaptive attack controller only for a
 *   currently eligible, crewed AI aircraft with an assigned or naturally known hostile contact;
 *   empty, player, UAV and excluded aircraft are reconsidered on later sweeps without job churn.
 * Locality and authority: discovery is machine-local; orders, restoration checkpoints and COMPAT markers are public.
 *
 * Review contract: Live COMPAT mode changes apply to already managed groups. The restoration marker is public so a new owner can return COMPAT control; aircraft event IDs are tracked for stop cleanup.
 *
 * Repeat/JIP: current feature gates and eligibility are rechecked; owner jobs are retired on migration.
 * Missile-warning bursts carry an owner-local generation token, so handler replacement, locality
 * migration or a stop/restart cannot revive countermeasures queued by an earlier Cortex run.
 * Arguments:
 * 0: job <HASHMAP>, default empty - persistent discovery cursors and completed-cycle caches.
 *
 * Return Value:
 * Number - 0.05 while bounded chunks remain, configured sweep interval after completion, or -1 when stopped.
 *
 * Example:
 * [WAIT_fnc_CortexDiscover, createHashMap, 1] call WAIT_fnc_CortexQueueJob;
 * Result: local AI groups are brought under the pass within one sweep.
 *
 * Current caller: WAIT_fnc_CortexInit.
 * Danger assessment: bounded member events use generation-scoped finite FSMs and only wake the current
 * group tactics brain; handlers retire on membership/owner changes and shutdown. No second movement owner.
 */

params [["_job",createHashMap,[createHashMap]]];
if !(missionNamespace getVariable ["WAIT_AIPass_Active", false]) exitWith {
    missionNamespace setVariable ["WAIT_AIPass_DiscoveryQueued", false];
    -1
};
if !(_job getOrDefault ["scanActive",false]) then {
    _job set ["scanGroups",allGroups];
    _job set ["scanVehicles",vehicles];
    _job set ["groupCursor",0];
    _job set ["vehicleCursor",0];
    _job set ["spotters",[]];
    _job set ["artillery",[]];
    _job set ["allArtillery",[]];
    _job set ["scanActive",true];
    missionNamespace setVariable ["WAIT_AIPass_PlayerPositions",(allPlayers select {alive _x && {!(_x isKindOf "HeadlessClient_F")}}) apply {getPosATL _x}];
};
private _scanGroups=_job get "scanGroups";
private _scanVehicles=_job get "scanVehicles";
private _groupCursor=_job get "groupCursor";
private _vehicleCursor=_job get "vehicleCursor";

private _spotters=_job get "spotters";
{
    private _group = _x;
    // Aircraft occupants remain eligible for the dedicated air systems below, but the generic
    // infantry/ground-vehicle domain must not install hearing, locality adoption or a group tick.
    // If a previously managed ground group boards an aircraft, release that old owner immediately.
    private _groundEligible = [_group,false,true] call WAIT_fnc_CortexIsEligible;
    if (_groundEligible) then {
        [_group] call WAIT_fnc_CortexHearingLocal;
        [_group] call WAIT_fnc_DangerSetup;
        if (isNil {_group getVariable "WAIT_AIPass_LocalHandler"}) then {
            _group setVariable ["WAIT_AIPass_LocalHandler", _group addEventHandler ["Local", {
                _this call WAIT_fnc_CortexLocality;
            }]];
        };
        if (local _group && {!(_group getVariable ["WAIT_AIPass_Adopted", false])}) then {
            [_group, true] call WAIT_fnc_CortexLocality;
        };
    } else {
        // Hearing decides observation eligibility independently of movement ownership. A Zeus
        // waypoint can retain uncertain sound reports without waking this group controller.
        [_group] call WAIT_fnc_CortexHearingLocal;
        [_group,true] call WAIT_fnc_DangerSetup;
        if (local _group && {_group getVariable ["WAIT_AIPass_Managed",false]}) then {
            [_group,true,"AIRCRAFT_DEDICATED"] call WAIT_fnc_CortexReleaseGroup;
        };
    };
    // "Applied" flags are machine-local. Clear them while another machine owns the group, so a group
    // that comes back (for example server to headless client and back) has its order re-applied here.
    if (!local _group) then {
        _group setVariable ["WAIT_AIPass_GarrisonApplied", nil];
        _group setVariable ["WAIT_AIPass_DefendApplied", nil];
        // Clearance has a durable public order but a machine-local route worker. If this owner
        // loses the group, its worker ends on locality loss; clear the local replay marker as
        // well so a later return to this HC/server reconstructs the remaining room queue rather
        // than believing an old callback is still sweeping the building.
        _group setVariable ["WAIT_AIPass_ClearApplied", nil];
    };
    if (local _group && {(units _group) findIf {alive _x} >= 0}) then {
        _spotters append ((units _group) select {alive _x && {_x getVariable ["WAIT_AIPass_Spotter", false]}});
        if ((_group getVariable ["WAIT_AIPass_Garrison", []]) isNotEqualTo [] && {!(_group getVariable ["WAIT_AIPass_GarrisonApplied", false])}) then {
            [_group] call WAIT_fnc_CortexGarrisonApplyLocal;
        };
        if ((_group getVariable ["WAIT_AIPass_Defend", []]) isNotEqualTo [] && {!(_group getVariable ["WAIT_AIPass_DefendApplied", false])}) then {
            [_group] call WAIT_fnc_CortexDefendApplyLocal;
        };
        private _clear = _group getVariable ["WAIT_AIPass_ClearOrder", []];
        if (_clear isNotEqualTo [] && {!(_group getVariable ["WAIT_AIPass_ClearApplied", false])}) then {
            [_group, _clear select 0, createHashMapFromArray [["resume", true]]] call WAIT_fnc_CortexClearBuilding;
        };
        // Aircraft occupants have dedicated flight, flare, missile-reaction and airborne controllers.
        // They may remain generally Cortex-eligible for those systems, but must never acquire the
        // generic ground-group loop as a second movement/behaviour owner.
        private _eligible = _groundEligible;
        private _movementLease = _group getVariable ["WAIT_Cortex_MovementLease", []];
        // Observation cannot manufacture authority, renew a deadline or erase unknown state.
        // Only a complete finite expired lease may be retired through its recorded owner.
        private _typedMovementLease=_movementLease isEqualType [] && {count _movementLease == 2}
            && {(_movementLease select 0) isEqualType ""} && {(_movementLease select 0) != ""}
            && {(_movementLease select 1) isEqualType 0} && {finite (_movementLease select 1)};
        if (_typedMovementLease && {serverTime >= (_movementLease select 1)}) then {
            [_group,_movementLease select 0,false] call WAIT_fnc_CortexOwnershipLease;
        };
        if (_eligible) then {
            _group setVariable ["WAIT_AIPass_PeakSize", (_group getVariable ["WAIT_AIPass_PeakSize", 0]) max ({alive _x} count units _group)];
            [_group,false] call WAIT_fnc_GroupBrainStart;
        };
    };
} forEach (_scanGroups select [_groupCursor,12]);
_job set ["groupCursor",_groupCursor+12];

private _wantArtillery = (missionNamespace getVariable ["WAIT_AIPass_Artillery_Enable", false])
    || {missionNamespace getVariable ["WAIT_AIPass_CounterBattery_Enable", false]};
// Cleanup uses the existing bounded vehicle slice even when air/artillery features are disabled.
{
    if (local _x && {!isNil {_x getVariable "WAIT_DrivingPass_Leg"}}) then {
        [_x] call WAIT_fnc_DrivingPassRetireInherited;
    };
} forEach (_scanVehicles select [_vehicleCursor,16]);
private _wantFlares = (missionNamespace getVariable ["WAIT_AIPass_AircraftFlares_Enable", true])
    || {missionNamespace getVariable ["WAIT_AIPass_AircraftBreak_Enable", true]};
private _wantAttackFlares=missionNamespace getVariable ["WAIT_Cortex_AttackRunFlares_Enable",true];
private _wantAirAttack=missionNamespace getVariable ["WAIT_Cortex_AirAttack_Enable",true];
if (_wantArtillery || _wantFlares || _wantAttackFlares || _wantAirAttack) then {
    private _artillery=_job get "artillery";
    private _allArtillery=_job get "allArtillery";
    {
        private _vehicle = _x;
        if (isServer && {alive _vehicle} && {getNumber (configOf _vehicle >> "artilleryScanner") == 1}) then {_allArtillery pushBack _vehicle};
        if (local _vehicle && {alive _vehicle}) then {
            private _pilot = driver _vehicle;
            private _attackFlareEligible = _wantAttackFlares && {_vehicle isKindOf "Air"}
                && {!isNull _pilot} && {alive _pilot} && {!isPlayer _pilot} && {!unitIsUAV _vehicle}
                && {[group _pilot,"WAIT_Cortex_AttackRunFlares_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
                && {[group _pilot] call WAIT_fnc_CortexIsEligible || {[_vehicle] call WAIT_fnc_CortexAircraftEligible}};
            if (_attackFlareEligible && {!(_vehicle getVariable ["WAIT_Cortex_AttackFlareJob",false])}) then {
                _vehicle setVariable ["WAIT_Cortex_AttackFlareJob",true];
                [WAIT_fnc_CortexAttackRunFlares,createHashMapFromArray [["aircraft",_vehicle]],1] call WAIT_fnc_CortexQueueJob;
            };
            private _airAttackEligible=_wantAirAttack && {_vehicle isKindOf "Air"}
                && {!isNull _pilot} && {alive _pilot} && {!isPlayer _pilot} && {!unitIsUAV _vehicle}
                && {!isTouchingGround _vehicle} && {!(_vehicle isKindOf "Plane") || {speed _vehicle >= 40}}
                && {combatMode group _pilot in ["YELLOW","RED"]}
                && {serverTime >= (_vehicle getVariable ["WAIT_Cortex_AirAttackBlockedUntil",0])}
                && {[group _pilot,"WAIT_Cortex_AirAttack_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
                && {[group _pilot] call WAIT_fnc_CortexIsEligible};
            private _airAttackTarget=objNull;
            if (_airAttackEligible) then {
                {
                    private _candidate=assignedTarget _x;
                    if (!isNull _candidate && {!(_candidate isKindOf "Logic")} && {!(_candidate isKindOf "HeadlessClient_F")} && {alive _candidate} && {!captive _candidate}
                        && {!(_candidate getVariable ["ace_captives_isSurrendering",false])}
                        && {!(_candidate getVariable ["ace_captives_isHandcuffed",false])}
                        && {(side group _pilot) getFriend side _candidate < 0.6}
                        && {(group _pilot knowsAbout _candidate) > 0}) exitWith {_airAttackTarget=_candidate};
                } forEach ([effectiveCommander _vehicle,driver _vehicle,gunner _vehicle,commander _vehicle]+crew _vehicle);
                // A contact can be detected and shared before the engine assigns it to a particular
                // seat. Requiring assignedTarget or the pilot's transient current-target list made
                // the adaptive attack wait for native AI to start the engagement it was intended to
                // improve. Read the bounded known-contact table used by the planner and pass that
                // concrete contact into the finite job.
                if (isNull _airAttackTarget) then {
                    private _knownTargets=(_pilot nearTargets ([8000,5000] select !(_vehicle isKindOf "Plane"))) select [0,16];
                    private _knownIndex=_knownTargets findIf {
                        private _knownObject=_x param [4,objNull];
                        !isNull _knownObject && {!(_knownObject isKindOf "Logic")} && {!(_knownObject isKindOf "HeadlessClient_F")} && {alive _knownObject} && {!captive _knownObject}
                            && {!(_knownObject getVariable ["ace_captives_isSurrendering",false])}
                            && {!(_knownObject getVariable ["ace_captives_isHandcuffed",false])}
                            && {(side group _pilot) getFriend side _knownObject < 0.6}
                            && {(group _pilot knowsAbout _knownObject) > 0}
                    };
                    if (_knownIndex >= 0) then {_airAttackTarget=(_knownTargets select _knownIndex) param [4,objNull]};
                };
            };
            if (_airAttackEligible && {!isNull _airAttackTarget} && {!(_vehicle getVariable ["WAIT_Cortex_AirAttackJob",false])}) then {
                [createHashMapFromArray [
                    ["aircraft",_vehicle],["group",group _pilot],["target",_airAttackTarget]
                ],0] call WAIT_fnc_AirAttackOperationStart;
            };
            if (_wantArtillery && {getNumber (configOf _vehicle >> "artilleryScanner") == 1}) then {
                private _gunner = gunner _vehicle;
                if (alive _gunner && {!isPlayer _gunner} && {[group _gunner] call WAIT_fnc_CortexIsEligible}) then {_artillery pushBack _vehicle};
            };
            if (_wantFlares && {_vehicle isKindOf "Air"} && {!(_vehicle getVariable ["WAIT_AIPass_FlaresInstalled", false])}
                && {[_vehicle] call WAIT_fnc_CortexAircraftEligible}) then {
                _vehicle setVariable ["WAIT_AIPass_FlaresInstalled", true];
                // The value is intentionally owner-local. A newly installed owner handler advances it,
                // permanently invalidating callbacks left by an earlier handler on this machine.
                _vehicle setVariable ["WAIT_Cortex_FlareBurstGeneration",
                    (_vehicle getVariable ["WAIT_Cortex_FlareBurstGeneration",0])+1];
                private _handler = _vehicle addEventHandler ["IncomingMissile", {
                    params ["_vehicle", "", "_shooter", "", ["_missile",objNull,[objNull]]];
                    if !([_vehicle] call WAIT_fnc_CortexAircraftEligible) exitWith {};
                    // A newer warning replaces the earlier finite response so salvos extend the threat
                    // window instead of starting competing workers. The missile object (available since
                    // Arma 3 2.10) lets the response stop once guidance has ended; older/unknown projectiles
                    // retain the same bounded maximum duration.
                    private _generation=(_vehicle getVariable ["WAIT_Cortex_FlareBurstGeneration",0])+1;
                    _vehicle setVariable ["WAIT_Cortex_FlareBurstGeneration",_generation];
                    _vehicle setVariable ["WAIT_Cortex_LastIncomingMissile",_missile];
                    private _threat=[_shooter,_missile] select (!isNull _missile);
                    private _side=if (isNull _threat) then {selectRandom [1,-1]}
                        else {[1,-1] select ((_vehicle getRelDir _threat) < 180)};
                    _vehicle setVariable ["WAIT_Cortex_MissileDefenceActive",_generation];
                    [WAIT_fnc_CortexMissileDefenceStep,createHashMapFromArray [
                        ["aircraft",_vehicle],
                        ["missile",_missile],
                        ["projectileKnown",!isNull _missile],
                        ["generation",_generation],
                        ["side",_side],
                        ["step",0],
                        ["subsystem","TACTICS"],
                        ["jobKey",format ["MISSILE_DEFENCE:%1",netId _vehicle]]
                    ],0] call WAIT_fnc_CortexQueueJob;
                }];
                _vehicle setVariable ["WAIT_AIPass_FlaresHandler", _handler];
                private _tracked = missionNamespace getVariable ["WAIT_AIPass_FlareVehicles", []];
                _tracked pushBackUnique _vehicle;
                missionNamespace setVariable ["WAIT_AIPass_FlareVehicles", _tracked];
            };
        };
    } forEach (_scanVehicles select [_vehicleCursor,16]);

};
_job set ["vehicleCursor",_vehicleCursor+16];
if ((_job get "groupCursor") < count _scanGroups
    || {(_job get "vehicleCursor") < count _scanVehicles}) exitWith {0.05};
missionNamespace setVariable ["WAIT_AIPass_LocalSpotters",_spotters];
missionNamespace setVariable ["WAIT_AIPass_LocalArtillery",_job get "artillery"];
if (isServer) then {missionNamespace setVariable ["WAIT_AIPass_AllArtillery",_job get "allArtillery"]};
_job set ["scanActive",false];
missionNamespace getVariable ["WAIT_AIPass_DiscoveryInterval",10]

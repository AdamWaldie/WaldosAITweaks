/*
 * Author: WaldoTheWarfighter
 * Locality / Authority: Executes on the caller; world changes are limited to locally owned objects or groups, or to server-published state, as guarded below.
 * Executes one finite Cortex aircraft attack as ingress, attack and egress phases. Against an
 * airborne hostile these phases mean intercept, engage and disengage/rejoin: the first two
 * destinations lead the contact's measured velocity while egress remains finite and returns the
 * aircraft to its unchanged authored route. This provides responsive air-to-air contact handling
 * without pretending that fixed script geometry implements full basic fighter manoeuvring.
 * It flies physical route legs, presents the live target only to the retained weapon operator, records real
 * non-countermeasure shots and requests finite approach/departure countermeasures. Every pattern
 * uses a compatible loaded weapon and opens fire only inside a live range and alignment envelope.
 * On attack entry an independently aimed turret, helicopter pilot weapon or air-to-air operator
 * receives one native target instruction using only knowledge the aircraft group already possessed
 * when the finite plan was selected. A fixed-wing pilot surface station relies on the attached
 * native DESTROY order so WAIT does not create a second ATTACK movement owner.
 * Fixed-wing pilots prosecute the object-attached native attack order. Once the live delivery basket
 * is valid, Cortex issues one bounded native doFire request to the selected pilot; independently
 * aimed turrets use fireAtTarget. This joins route geometry to the engine's weapon FSM instead of
 * treating an ATTACK label as an attack.
 * The engine remains the flight controller; Cortex owns one named temporary
 * waypoint for the finite lease and one terrain-relative altitude hint when each leg changes. Once a
 * fixed-wing aircraft reaches its selected approach, the same owned waypoint becomes an object-attached
 * DESTROY order. Arma's native combat flight controller therefore owns the roll-in, pitch and release
 * geometry across real terrain; Cortex does not repeatedly rotate, move or velocity-lock the aircraft.
 * The immutable approach still distinguishes standoff, oblique, hook, bomb and strafe setup, while the
 * finite egress prevents an unsuccessful native attack from orbiting forever. Bomb
 * release uses a short config-driven ballistic integration instead of a fixed angle or height. Native
 * fireAtTarget still owns independently aimed turret release. A pilot-operated fixed-wing surface
 * weapon receives one native doFire request only after the same live release checks; Cortex records
 * its real Fired event and never spawns, steers or corrects a projectile. A pass which physically
 * crosses the target without releasing proceeds
 * to egress instead of circling back around an unreachable delivery point. Rotorcraft and independently
 * aimed turrets retain the bounded native fire request because their abeam and standoff attacks do not
 * use a fixed-wing dive. Egress, abort and Zeus interruption detach and delete the order. The real hostile remains the
 * fire-control, guidance and damage/result target; Cortex does not insert a friendly laser proxy
 * that can invalidate native seeker guidance.
 * Each leg updates the one Cortex-owned native waypoint once. A fixed-wing ATTACK also checks two
 * short velocity-projected terrain samples; an imminent low clearance causes one recovery-height
 * request and a finite abort. This is active-job safety, not a per-unit terrain-following loop.
 * Progress is measured toward
 * that leg, so broad turns are accepted while hovering, local circles and repeated replans cannot keep
 * an attack alive. Non-progress in any phase aborts rather than fabricating a transition; a validly
 * released attack exits after a bounded weapon-class delivery: a paired bomb ripple, a short guided/rocket
 * salvo or a gun burst. It never waits indefinitely for a single engine fire callback.
 * A lack of travel, solution or fire aborts the run; elapsed time alone
 * never completes it. Zeus priority, locality loss, explicit exclusions, runtime disablement or a
 * changed curator waypoint end the lease immediately. Cleanup deletes only that named temporary
 * waypoint. A successful run hands the aircraft back toward its unchanged original waypoint.
 * During direct Zeus handover, cleanup clears this attack's target commands, restores the native
 * attack policy and selects the authenticated curator waypoint. One non-forced height request uses
 * the waypoint's AGL altitude when meaningful, or the live aircraft height for a normal ground-level
 * map click; this cancels the otherwise persistent Cortex flight-height hint without inventing a
 * route. For an authenticated MOVE waypoint only, the group receives the same destination once
 * after selection. This wakes native helicopter movement observed retaining the deleted Cortex leg;
 * it creates no timed guard, replacement route, pilot order or delayed semantic restoration.
 * Locality/authority: aircraft owner only. Public summary/outcome arrays support Zeus diagnostics;
 * movement commands and Fired handlers remain owner-local.
 * Repeat/JIP: one finite FSM brain per aircraft. Cleanup removes the owned handler,
 * named waypoint, speed limit and public plan; a short owner-local re-attack interval prevents immediate duplicate runs.
 * Arguments: 0: scheduler job <HASHMAP>; aircraft <OBJECT> is required; target <OBJECT> is optional
 * when an authenticated combined-arms opportunity already selected it.
 * Return Value: NUMBER delay for the owning FSM, or -1 after cleanup.
 * Current caller: WAIT_fnc_AirAttackOperationStep through the shared scheduler.
 * Example: [createHashMapFromArray [["aircraft",_plane]]] call WAIT_fnc_CortexAirAttack;
 */
params [["_job",createHashMap,[createHashMap]]];
private _aircraft=_job getOrDefault ["aircraft",objNull];
if (isNull _aircraft) exitWith {-1};
private _finish={
    params ["_reason",["_resume",false]];
    // A kill completes the weapon phase, not the flight lease. Preserve that semantic result after
    // the aircraft has flown its real egress instead of ending control over the target wreck.
    if (_reason == "COMPLETE") then {
        if (_job getOrDefault ["targetDestroyed",false]) then {
            _reason="TARGET_DESTROYED";
        } else {
            if (_job getOrDefault ["deliveryMissed",false]) then {_reason="DELIVERY_MISSED"};
        };
    };
    private _finishGroup=group driver _aircraft;
    if (!isNull _finishGroup && {"token" in _job}) then {[_finishGroup,_job,"ENDED",_reason] call WAIT_fnc_CortexDrillSetStage};
    private _handler=_job getOrDefault ["firedHandler",-1];
    if (_handler >= 0) then {_aircraft removeEventHandler ["Fired",_handler]};
    private _guidanceTarget=_job getOrDefault ["guidanceTarget",objNull];
    if (!isNull _guidanceTarget) then {deleteVehicle _guidanceTarget};
    if (local _aircraft) then {
        _aircraft limitSpeed -1;
        // Remove exactly the lease-owned waypoint before selecting any authored route. Searching
        // by name remains correct when Zeus added or removed other waypoints and shifted indices.
        private _ownedWaypointName=_job getOrDefault ["ownedWaypointName",""];
        if (!isNull _finishGroup && {_ownedWaypointName != ""}) then {
            private _ownedWaypointIndex=(waypoints _finishGroup) findIf {waypointName _x == _ownedWaypointName};
            if (_ownedWaypointIndex >= 0) then {deleteWaypoint ((waypoints _finishGroup) select _ownedWaypointIndex)};
        };
        if (!isNull _finishGroup) then {_finishGroup enableAttack (_job getOrDefault ["previousAttackEnabled",true])};
        private _finishPilot=driver _aircraft;
        if (!isNull _finishPilot && {alive _finishPilot}) then {
            {_finishPilot enableAI _x} forEach (_job getOrDefault ["lateralPilotFeatures",[]]);
        };
        // Direct Zeus input owns the aircraft immediately. Do not clear target or watch state here:
        // the curator or external controller may have replaced it before this scheduled cleanup ran.
        // Restore the native attack policy, reselect the authenticated waypoint and leave. A timed
        // guard was observed to suppress the new route for 90 seconds and violated this boundary.
        if (_reason in ["CONTROL_RELEASED","AUTHORED_ROUTE_CHANGED"]) then {
            private _handoverPilot=driver _aircraft;
            private _handoverGroup=group _handoverPilot;
            private _snapshot=_handoverGroup getVariable ["WAIT_Cortex_ZeusOrderSnapshot",[]];
            private _handoverPosition=+(_snapshot param [1,[]]);
            private _handoverWaypoints=waypoints _handoverGroup;
            private _authoredWaypointOffset=_handoverWaypoints findIf {
                count _handoverPosition >= 2 && {waypointPosition _x distance2D _handoverPosition <= 2}
            };
            // Re-select the exact curator waypoint and immediately apply its own movement semantics.
            // This is a one-time replay of authenticated Zeus intent, not a Cortex route. Without
            // it Arma retained the pre-attack RED/COMBAT state and ignored AWARE/FULL movement.
            // Use the actual waypoint handle:
            // deleting the Cortex waypoint leaves engine-ID gaps, so a findIf list offset is not a
            // valid waypoint ID and previously selected the deleted slot/waypoint zero.
            private _authoredWaypoint=if (_authoredWaypointOffset >= 0) then {
                _handoverWaypoints select _authoredWaypointOffset
            } else {
                [_handoverGroup,_snapshot param [5,currentWaypoint _handoverGroup]]
            };
            if ((_authoredWaypoint select 1) >= 0) then {
                // flyInHeight persists after its owning MOVE waypoint is deleted. The completed
                // handover audit showed the helicopter still climbing to Cortex's old hint, then
                // hovering despite facing Zeus' selected MOVE point. Replace that stale hint once
                // with curator altitude when the waypoint carries one; ordinary 2D map clicks retain
                // the aircraft's live AGL. `false` preserves native collision avoidance and this
                // does not move, accelerate or continuously supervise the aircraft.
                private _handoverHeight=if (count _handoverPosition >= 3
                    && {(_handoverPosition select 2) >= 20}) then {
                    _handoverPosition select 2
                } else {
                    ((getPosATL _aircraft) select 2) max 30
                };
                _aircraft flyInHeight [_handoverHeight,false];
                _handoverGroup setCurrentWaypoint _authoredWaypoint;
                private _authoredBehaviour=_snapshot param [2,waypointBehaviour _authoredWaypoint];
                private _authoredSpeed=_snapshot param [3,waypointSpeed _authoredWaypoint];
                private _authoredCombatMode=_snapshot param [6,waypointCombatMode _authoredWaypoint];
                if (_authoredBehaviour != "NO CHANGE") then {_handoverGroup setBehaviourStrong _authoredBehaviour};
                if (_authoredSpeed != "UNCHANGED") then {_handoverGroup setSpeedMode _authoredSpeed};
                if (_authoredCombatMode != "NO CHANGE") then {_handoverGroup setCombatMode _authoredCombatMode};
                // Selecting the correct waypoint was insufficient in the live audit: the native
                // helicopter kept climbing toward the deleted Cortex ingress and then hovered with
                // MOVE displayed. Replay only the authenticated MOVE destination once. The Zeus
                // waypoint remains authoritative and Cortex leaves no scheduled repair behind.
                if ((_snapshot param [4,waypointType _authoredWaypoint]) == "MOVE"
                    && {count _handoverPosition >= 2}) then {
                    _handoverGroup move _handoverPosition;
                };
            };
            _aircraft setVariable ["WAIT_Cortex_AirHandoverLease",nil,true];
            _aircraft setVariable ["WAIT_Cortex_AirHandoverRecovery",nil,true];
            _aircraft setVariable ["WAIT_Cortex_AirHandoverResult",[
                serverTime,if (count _handoverPosition >= 2) then {_aircraft distance2D _handoverPosition} else {-1},
                behaviour _handoverPilot,unitCombatMode _handoverPilot,currentCommand _handoverPilot,
                "ZEUS_IMMEDIATE_HANDOVER",expectedDestination _handoverPilot
            ],true];
        };
        // On an ordinary finite end, retire only the exact hostile WAIT assigned and only while no
        // player, curator or specialist has claimed the group. A newer target survives cleanup.
        if (!(_reason in ["CONTROL_RELEASED","AUTHORED_ROUTE_CHANGED"])) then {
            private _ownedTarget=_job getOrDefault ["fireTarget",objNull];
            private _cleanupExternal=[_finishGroup] call WAIT_fnc_CortexExternalTakeover
                || {[_finishGroup] call WAIT_fnc_CortexZeusHeld};
            if (!_cleanupExternal && {!isNull _ownedTarget}) then {
                {
                    if (alive _x && {!isPlayer _x} && {assignedTarget _x isEqualTo _ownedTarget}) then {
                        _x doTarget objNull;
                        _x doWatch objNull;
                    };
                } forEach crew _aircraft;
            };
        };
        if (_resume) then {
            private _resumePosition=_job getOrDefault ["resumePosition",[]];
            private _resumeGroup=group driver _aircraft;
            private _resumeWaypointIndex=(waypoints _resumeGroup) findIf {
                waypointPosition _x distance2D _resumePosition <= 2
            };
            // The shared takeover boundary includes player occupants, Zeus and specialist markers
            // on every crew group. A completed attack must not re-form the aircraft over any one
            // of those newer owners merely because its own operation reached a normal release.
            private _resumeExternal = [_resumeGroup] call WAIT_fnc_CortexExternalTakeover
                || {(crew _aircraft) findIf {[group _x] call WAIT_fnc_CortexExternalTakeover} >= 0};
            if (count _resumePosition >= 2 && {!_resumeExternal}) then {
                {if (alive _x && {!isPlayer _x}) then {_x doFollow leader _resumeGroup}} forEach crew _aircraft;
                if (_resumeWaypointIndex >= 0 && {_resumeWaypointIndex < count waypoints _resumeGroup}
                    && {waypointPosition [_resumeGroup,_resumeWaypointIndex] distance2D _resumePosition <= 2}) then {
                    _resumeGroup setCurrentWaypoint [_resumeGroup,_resumeWaypointIndex];
                };
            };
        };
    };
    _aircraft setVariable ["WAIT_Cortex_AirAttackOutcome",[
        _reason,serverTime,_job getOrDefault ["pattern",""],_job getOrDefault ["shots",0],
        _job getOrDefault ["releaseDetail",[]],getPosATL _aircraft,velocity _aircraft
    ],true];
    // Prevent immediate rediscovery of the same known contact after a finite run. This is a short
    // re-attack interval, not a movement controller or Zeus order guard.
    _aircraft setVariable ["WAIT_Cortex_AirAttackBlockedUntil",serverTime+(
        if (_reason in ["CONTROL_RELEASED","AUTHORED_ROUTE_CHANGED"]) then {5}
        else {if (_reason in ["COMPLETE","TARGET_DESTROYED"]) then {20}
            else {if (_reason == "DELIVERY_SAFETY_FLOOR") then {120} else {35}}}
    )];
    _aircraft setVariable ["WAIT_Cortex_AirAttackPlan",nil,true];
    _aircraft setVariable ["WAIT_Cortex_AirFireSolution",nil,true];
    _aircraft setVariable ["WAIT_Cortex_AirAttackTarget",nil];
    _aircraft setVariable ["WAIT_Cortex_AirAttackGuidedWeapon",nil];
    _aircraft setVariable ["WAIT_Cortex_AirAttackGuidanceTarget",nil];
    _aircraft setVariable ["WAIT_Cortex_AirAttackSelectedWeapon",nil];
    _aircraft setVariable ["WAIT_Cortex_AirAttackSelectedMagazine",nil];
    _aircraft setVariable ["WAIT_Cortex_AirAttackJob",nil];
    _aircraft setVariable ["WAIT_Cortex_AirAttackToken",nil];
    // The flight waypoint has already been removed above. The common operation result records
    // whether that finite native attempt completed; stale or externally cancelled generations
    // are intentionally a no-op.
    private _operationGeneration=_job getOrDefault ["operationGeneration",-1];
    if (!isNull _finishGroup && {local _finishGroup} && {_operationGeneration >= 0}) then {
        if (_reason in ["COMPLETE","TARGET_DESTROYED"]) then {
            [_finishGroup,_operationGeneration,"COMPLETE",_reason] call WAIT_fnc_OperationRelease;
        } else {
            [_finishGroup,_operationGeneration,_reason] call WAIT_fnc_OperationCancel;
        };
    };
    -1
};
private _pilot=driver _aircraft;
private _group=group _pilot;
private _stage=_job getOrDefault ["stage",""];
private _flightLeaseToken=_job getOrDefault ["flightLeaseToken",""];
// Air operations share the same generation contract as ground operations, but retain their own
// native flight lease. The common record makes replacement, locality and Zeus diagnostics
// explicit without asking an infantry movement helper to fly an aircraft.
private _setOperationPhase={
    params ["_phase"];
    private _generation=_job getOrDefault ["operationGeneration",-1];
    if (_generation < 0 || {isNull _group} || {!local _group}) exitWith {};
    private _operation=_group getVariable ["WAIT_Operation",createHashMap];
    if (count _operation > 0 && {(_operation getOrDefault ["generation",-2]) == _generation}) then {
        _operation set ["phase",_phase];
        _group setVariable ["WAIT_Operation",_operation,true];
    };
};
// Generic eligibility is a start gate. Re-evaluating every broad filter during a finite owned run
// allowed a transient locality/filter marker to cancel a valid attack just before weapon release.
// Runtime master/feature changes, locality, explicit exclusions and Zeus still release immediately.
private _explicitlyExcluded=[_group] call WAIT_fnc_CompatibilityExternalControl
    || {"ALL" in (_group getVariable ["WAIT_AIPass_DisabledFeatures",[]])}
    || {_group getVariable ["WAIT_AI_Exclude",false]}
    || {_group getVariable ["WAIT_AIPass_Exclude",false]};
// Planning can inspect weapon and terrain facts for a full scheduler slice.  Keep ownership cheap
// to recheck at each native-command boundary so that a curator, player controller or specialist
// that claims the aircraft during planning receives an immediate release rather than one stale
// flight, targeting or fire request.
private _mayControlAircraft = {
    local _aircraft && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
        && {!([_group] call WAIT_fnc_CortexZeusHeld)}
};
if (_job getOrDefault ["flightLeaseLost",false]
    || {!([_aircraft,"AIR_ATTACK",_flightLeaseToken] call WAIT_fnc_FlightLeaseValid)}) exitWith {
    _job set ["releaseDetail",["flightLease",_aircraft getVariable ["WAIT_FlightLease",createHashMap]]];
    ["FLIGHT_OWNER_CHANGED"] call _finish
};
private _allowed=local _aircraft && {alive _aircraft} && {!isNull _pilot} && {alive _pilot} && {!isPlayer _pilot}
    && {!unitIsUAV _aircraft} && {missionNamespace getVariable ["WAIT_AIPass_Active",false]}
    && {!([] call WAIT_fnc_CortexIsPaused)}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
    && {!([_group] call WAIT_fnc_CortexZeusHeld)}
    && {[_group,"WAIT_Cortex_AirAttack_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {!_explicitlyExcluded}
    && {_stage != "" || {[_group] call WAIT_fnc_CortexIsEligible}};
if (!_allowed) exitWith {
    // Preserve the exact authority/control gate which ended the run. Without this, locality loss,
    // a curator interruption and an explicit exclusion all appeared as the same opaque failure in
    // the WAIT diagnostics and audit overlay.
    _job set ["releaseDetail",[
        "local",local _aircraft,"aircraftAlive",alive _aircraft,"pilotAlive",!isNull _pilot && {alive _pilot},
        "runtime",missionNamespace getVariable ["WAIT_AIPass_Active",false],
        "paused",[] call WAIT_fnc_CortexIsPaused,"zeus",[_group] call WAIT_fnc_CortexZeusHeld,
        "feature",[_group,"WAIT_Cortex_AirAttack_Enable",true] call WAIT_fnc_CortexFeatureEnabled,
        "excluded",_explicitlyExcluded,"stage",_stage,"vehicleOwner",owner _aircraft,"groupOwner",groupOwner _group
    ]];
    ["CONTROL_RELEASED"] call _finish
};
private _isPlane=_aircraft isKindOf "Plane";
// A helicopter may validly begin an attack from a hover. Planes still need enough energy to enter a
// finite run; accepting a stationary plane would make its own spawn/ground state look like tactics.
if (isTouchingGround _aircraft || {_isPlane && {speed _aircraft < 40}} || {combatMode _group in ["BLUE","GREEN"]}) exitWith {["NOT_ATTACKING"] call _finish};

private _startFailure="";
if (_stage == "") then {
    private _target=_job getOrDefault ["target",objNull];
    if (isNull _target || {!alive _target} || {(side _group) getFriend side _target >= 0.6}) then {
        _target=objNull;
        {
            private _candidate=assignedTarget _x;
            if (!isNull _candidate && {alive _candidate} && {(side _group) getFriend side _candidate < 0.6}) exitWith {_target=_candidate};
        } forEach ([effectiveCommander _aircraft,driver _aircraft,gunner _aircraft,commander _aircraft]+crew _aircraft);
    };
    if (isNull _target) then {_startFailure="NO_TARGET"};
    private _plan=if (_startFailure == "") then {[_aircraft,_target] call WAIT_fnc_CortexAirAttackPlan} else {createHashMap};
    if (_startFailure == "" && {count _plan == 0}) then {_startFailure="NO_PLAN"};
    if (_startFailure == "" && {!([] call _mayControlAircraft)}) then {_startFailure="CONTROL_RELEASED"};
    if (_startFailure == "") then {
    private _waypointIndex=currentWaypoint _group;
    private _resumePosition=[];
    if (_waypointIndex >= 0 && {_waypointIndex < count waypoints _group}) then {_resumePosition=waypointPosition [_group,_waypointIndex]};
    // Capture authored route content rather than currentWaypoint. The engine advances that index as
    // an aircraft flies, which previously looked like a replacement order and cancelled valid runs.
    private _routeSignature=waypoints _group apply {[waypointPosition _x,waypointType _x]};
    _job set ["target",_target]; _job set ["points",_plan get "points"];
    _job set ["pattern",_plan get "pattern"]; _job set ["token",_plan get "token"];
    if ((_plan get "pattern") == "LATERAL") then {
        private _lateralPilotFeatures=["AUTOCOMBAT","TARGET","AUTOTARGET"] select {_pilot checkAIFeature _x};
        _job set ["lateralPilotFeatures",_lateralPilotFeatures];
        {_pilot disableAI _x} forEach _lateralPilotFeatures;
        _pilot doTarget objNull;
        _pilot doWatch objNull;
    };
    _job set ["aaPositions",_plan get "aaPositions"];
    _job set ["lateralTurret",_plan getOrDefault ["lateralTurret",false]];
    _job set ["lateralTurretPath",_plan getOrDefault ["lateralTurretPath",[]]];
    _job set ["lateralWeapon",_plan getOrDefault ["lateralWeapon",""]];
    _job set ["lateralSimulation",_plan getOrDefault ["lateralSimulation",""]];
    _job set ["standoffWeapon",_plan getOrDefault ["standoffWeapon",""]];
    _job set ["standoffTurret",_plan getOrDefault ["standoffTurret",[]]];
    _job set ["standoffSimulation",_plan getOrDefault ["standoffSimulation",""]];
    _job set ["groundWeapon",_plan getOrDefault ["groundWeapon",""]];
    _job set ["groundTurret",_plan getOrDefault ["groundTurret",[]]];
    _job set ["groundSimulation",_plan getOrDefault ["groundSimulation",""]];
    _job set ["airToAir",_plan getOrDefault ["airToAir",false]];
    _job set ["airWeapon",_plan getOrDefault ["airWeapon",""]];
    _job set ["airWeaponTurret",_plan getOrDefault ["airWeaponTurret",[]]];
    _job set ["airSimulation",_plan getOrDefault ["airSimulation",""]];
    _job set ["selectedWeapon",_plan getOrDefault ["selectedWeapon",""]];
    _job set ["selectedTurret",_plan getOrDefault ["selectedTurret",[]]];
    _job set ["selectedSimulation",_plan getOrDefault ["selectedSimulation",""]];
    _job set ["selectedWeaponClass",_plan getOrDefault ["selectedWeaponClass",""]];
    _job set ["selectedMagazine",_plan getOrDefault ["selectedMagazine",""]];
    // Keep the real hostile as both the semantic and engine fire-control target. An attached laser
    // proxy gave fireAtTarget a friendly-side object and missiles flew their launch vector without
    // useful guidance. The Fired handler reinforces this exact hostile on guided projectiles.
    private _guidanceTarget=objNull;
    _job set ["guidanceTarget",_guidanceTarget];
    _job set ["fireTarget",_target];
    _job set ["altitude",_plan get "altitude"]; _job set ["speed",_plan get "speed"];
    _job set ["stageAltitudes",_plan getOrDefault ["stageAltitudes",[_plan get "altitude",_plan get "altitude",_plan get "altitude"]]];
    _job set ["stageSpeeds",_plan getOrDefault ["stageSpeeds",[_plan get "speed",_plan get "speed",_plan get "speed"]]];
    _job set ["captureRadii",_plan getOrDefault ["captureRadii",[450,450,450]]];
    _job set ["attackMinimum",_plan getOrDefault ["attackMinimum",2]];
    _job set ["terrainLift",_plan getOrDefault ["terrainLift",0]];
    _job set ["terrainClearanceMinimum",_plan getOrDefault ["terrainClearanceMinimum",0]];
    _job set ["terrainSampleCount",_plan getOrDefault ["terrainSampleCount",0]];
    _job set ["terrainCorridor",_plan getOrDefault ["terrainCorridor",0]];
    _job set ["terrainRequiredLift",_plan getOrDefault ["terrainRequiredLift",0]];
    _job set ["terrainViable",_plan getOrDefault ["terrainViable",true]];
    _job set ["targetPosition",+(_plan getOrDefault ["targetPosition",getPosATL _target])];
    _job set ["type","AIR_ATTACK"]; _job set ["stage",""]; _job set ["deadline",serverTime+75]; _job set ["shots",0];
    _job set ["origin",getPosATL _aircraft]; _job set ["resumePosition",_resumePosition];
    _job set ["resumeWaypointIndex",_waypointIndex]; _job set ["routeSignature",_routeSignature];
    // The temporary waypoint belongs to this finite WAIT lease. A namespace-specific name keeps
    // route-diff and cleanup ownership unambiguous when an unrelated controller adds waypoints.
    _job set ["ownedWaypointName",format ["WAIT_AIR_%1",_plan get "token"]];
    _job set ["previousAttackEnabled",attackEnabled _group];
    private _participants=(crew _aircraft) select {
        alive _x && {local _x} && {!isPlayer _x} && {lifeState _x != "INCAPACITATED"}
    };
    private _operation=[_group,format ["AIR_%1",_plan get "pattern"],_target,_participants,
        +(_plan get "points"),"INGRESS"] call WAIT_fnc_OperationStart;
    if (count _operation == 0) then {
        _startFailure="OPERATION_UNAVAILABLE";
    } else {
        _job set ["operationGeneration",_operation get "generation"];
    };
    // Record the authored policy for exact cleanup, but do not disable it. Disabling group attacks
    // prevented native pilots and turrets from building a valid solution while Cortex waited to fire.
    _aircraft setVariable ["WAIT_Cortex_AirAttackToken",_plan get "token"];
    _aircraft setVariable ["WAIT_Cortex_AirAttackTarget",_target];
    // simulation=shotMissile also covers unguided rockets and bombs. Only a planner-classified
    // GUIDED station may receive missile target commands; assigning them to bombs prevented normal
    // fuzing, while assigning them to fixed rockets contradicted their delivery geometry.
    _aircraft setVariable ["WAIT_Cortex_AirAttackGuidedWeapon",
        ["",_plan getOrDefault ["selectedWeapon",""]] select ((_plan getOrDefault ["selectedWeaponClass",""]) == "GUIDED")];
    _aircraft setVariable ["WAIT_Cortex_AirAttackGuidanceTarget",_target];
    // A native group may fire other weapons while it is approaching the finite attack leg. Only
    // the exact loaded station selected by this plan may advance its delivery counter: accepting
    // any non-countermeasure Fired event let defensive or unrelated native fire make a failed
    // rocket, bomb or guided pass look complete and begin egress early.
    _aircraft setVariable ["WAIT_Cortex_AirAttackSelectedWeapon",_plan getOrDefault ["selectedWeapon",""]];
    _aircraft setVariable ["WAIT_Cortex_AirAttackSelectedMagazine",_plan getOrDefault ["selectedMagazine",""]];
    private _handler=_aircraft addEventHandler ["Fired",{
        params ["_aircraft","_weapon","","","","_magazine","_projectile"];
        private _selectedWeapon=_aircraft getVariable ["WAIT_Cortex_AirAttackSelectedWeapon",""];
        private _selectedMagazine=_aircraft getVariable ["WAIT_Cortex_AirAttackSelectedMagazine",""];
        private _selectedRelease=_weapon == _selectedWeapon
            && {_selectedMagazine != ""} && {_magazine == _selectedMagazine};
        if (_selectedRelease) then {
            _aircraft setVariable ["WAIT_Cortex_AirAttackShots",(_aircraft getVariable ["WAIT_Cortex_AirAttackShots",0])+1];
            // Preserve native ballistics and seeker behaviour, but give the projectile the hostile
            // already selected by its operator. fireAtTarget alone can launch a guided pylon round
            // without a missile target, producing the observed straight-line ground and A2A misses.
            private _guidedWeapon=_aircraft getVariable ["WAIT_Cortex_AirAttackGuidedWeapon",""];
            private _guidedTarget=_aircraft getVariable ["WAIT_Cortex_AirAttackGuidanceTarget",objNull];
            if (_weapon == _guidedWeapon && {!isNull _projectile} && {!isNull _guidedTarget} && {alive _guidedTarget}) then {
                private _targetAccepted=_projectile setMissileTarget [_guidedTarget,true];
                // Air seekers track the object directly. Ground seekers also need one immutable
                // aim point when their ammo explicitly supports manual point guidance. This is one
                // release-time assignment, not a scripted homing loop or an airframe correction.
                if (!(_guidedTarget isKindOf "Air")) then {
                    _projectile setMissileTargetPos (aimPos _guidedTarget);
                };
                _aircraft setVariable ["WAIT_Cortex_AirGuidanceAssignment",[
                    serverTime,_weapon,_targetAccepted,missileTarget _projectile,missileTargetPos _projectile
                ],true];
            };
        };
    }];
    _aircraft setVariable ["WAIT_Cortex_AirAttackShots",0];
    _job set ["firedHandler",_handler];
    [_group,_job,"INGRESS","PLAN_ACCEPTED"] call WAIT_fnc_CortexDrillSetStage;
        _stage="INGRESS";
    };
};
if (_startFailure != "") exitWith {[_startFailure] call _finish};
private _ownedWaypointName=_job getOrDefault ["ownedWaypointName",""];
private _currentRoute=(waypoints _group select {waypointName _x != _ownedWaypointName}) apply {
    [waypointPosition _x,waypointType _x]
};
if (_currentRoute isNotEqualTo (_job getOrDefault ["routeSignature",_currentRoute])) exitWith {["AUTHORED_ROUTE_CHANGED"] call _finish};
private _target=_job getOrDefault ["target",objNull];
if (!isNull _target) then {_job set ["lastTargetPosition",getPosATL _target]};
// Destroying the target must not strand the aircraft at the firing point. Complete the full
// INGRESS -> ATTACK -> EGRESS contract, using the wreck's stable position for departure geometry.
// A target lost before an actual attack remains a failed run and hands native control back at once.
// Some missions delete a killed vehicle immediately. In that case the object is already objNull by
// the next budgeted tick, so use the attack-stage shot baseline as the durable distinction between
// a pre-attack disappearance and a target removed after this aircraft physically fired.
private _targetUnavailable=isNull _target || {!alive _target};
if (_targetUnavailable && {!(_job getOrDefault ["targetDestroyed",false])}) then {
    // The engine may report the kill after the shot has already moved the finite plan into EGRESS.
    // Treat a destroyed target as this run's result when the aircraft physically fired during the
    // attack, without requiring the damage event and the ATTACK label to land on the same scheduler
    // tick. A target lost before real weapon fire remains a failed run.
    private _liveShots=_aircraft getVariable ["WAIT_Cortex_AirAttackShots",0];
    // A present wreck is an unambiguous successful end condition even when another friendly
    // weapon lands the final blow between scheduler ticks. Requiring this controller's Fired EH
    // to win that race mislabeled a destroyed objective as TARGET_LOST and could strand the
    // aircraft in ingress. A deleted/null contact remains ambiguous and still needs durable
    // evidence that this aircraft physically fired before it is treated as destroyed.
    if ((!isNull _target && {!alive _target}) || {_liveShots > 0}) then {
        _job set ["targetDestroyed",true];
        // A turret can validly destroy a contact while the pilot is still closing. Record that
        // physical fire as ATTACK before beginning egress so a real kill is not labelled TARGET_LOST.
        if (_stage == "INGRESS") then {
            [_group,_job,"ATTACK","ACTUAL_FIRE"] call WAIT_fnc_CortexDrillSetStage;
            _stage="ATTACK";
            ["ATTACK"] call _setOperationPhase;
        };
        if (_stage == "ATTACK") then {
            [_group,_job,"EGRESS","TARGET_DESTROYED"] call WAIT_fnc_CortexDrillSetStage;
            _job set ["commandedStage",""];
            _job set ["egressStartPosition",getPosATL _aircraft];
            _job set ["egressStartedAt",serverTime];
            _job set ["deadline",serverTime+75];
            _stage="EGRESS";
            ["EGRESS"] call _setOperationPhase;
        };
    };
};
if (_targetUnavailable && {!(_job getOrDefault ["targetDestroyed",false])}) exitWith {["TARGET_LOST",true] call _finish};
if ((getPosATL _aircraft select 2) < 25) exitWith {["GROUND_CLEARANCE"] call _finish};
// A failed fixed-wing solution must never continue into rising terrain. Current AGL alone only
// catches a descent after the aircraft is already low, so sample the velocity-projected position at
// 1.5 and 3 seconds. This runs only for an active fixed-wing ATTACK, costs two terrain lookups per
// scheduler visit, and never steers a healthy run. An unsafe projection receives one recovery-height
// hint before the lease is retired; no teleport, repeated correction or projectile manipulation is
// used.
private _currentAGL=(getPosATL _aircraft) select 2;
private _verticalSpeed=(velocity _aircraft) select 2;
private _lookaheadClearances=[];
if (_isPlane && {_stage == "ATTACK"}) then {
    private _positionASL=getPosASL _aircraft;
    private _currentVelocity=velocity _aircraft;
    _lookaheadClearances=[1.5,3] apply {
        private _futurePosition=_positionASL vectorAdd (_currentVelocity vectorMultiply _x);
        (_futurePosition select 2)-(getTerrainHeightASL _futurePosition)
    };
};
private _unsafeDelivery=_isPlane && {_stage == "ATTACK"} && {
    (_currentAGL < 90 && {_verticalSpeed < -3})
        || {_lookaheadClearances isNotEqualTo [] && {selectMin _lookaheadClearances < 120}}
};
if (_unsafeDelivery && {!([] call _mayControlAircraft)}) exitWith {["CONTROL_RELEASED"] call _finish};
if (_unsafeDelivery) exitWith {
    private _safeRecoveryHeight=((_job getOrDefault ["stageAltitudes",[450,450,450]]) select 0) max 450;
    _aircraft flyInHeight _safeRecoveryHeight;
    _job set ["releaseDetail",[
        "agl",_currentAGL,"verticalSpeed",_verticalSpeed,
        "lookaheadClearances",_lookaheadClearances,"recoveryHeight",_safeRecoveryHeight,
        "position",getPosATL _aircraft,"velocity",velocity _aircraft
    ]];
    ["DELIVERY_SAFETY_FLOOR",true] call _finish
};
private _points=_job get "points";
private _stageIndex=["INGRESS","ATTACK","EGRESS"] find _stage;
if (_stageIndex < 0) exitWith {["BAD_STAGE"] call _finish};
private _destination=_points select _stageIndex;
// Air contacts do not remain at the point captured when the plan was built. Refresh only the
// intercept and engagement points from current target velocity; disengagement stays immutable so
// the lease has a real end and cannot orbit indefinitely.
if (_job getOrDefault ["airToAir",false] && {_stage in ["INGRESS","ATTACK"]}) then {
    private _leadSeconds=[16,5] select (_stage == "ATTACK");
    _destination=(getPosATL _target) vectorAdd ((velocity _target) vectorMultiply _leadSeconds);
    _destination set [2,(_job getOrDefault ["stageAltitudes",[_job get "altitude",_job get "altitude",_job get "altitude"]]) select _stageIndex];
    _points set [_stageIndex,_destination];
    _job set ["points",_points];
};
// Fixed guns, rockets and bombs cross the objective, so a target-attached DESTROY waypoint gives
// the native flight controller a useful roll-in. Guided stand-off weapons instead retain their
// inbound release point: attaching that phase to the target overwrites its safe launch distance and
// forces the aircraft through the objective before it can fire.
private _nativeAttackWaypoint=_isPlane && {_stage == "ATTACK"} && {!isNull _target}
    && {(_job getOrDefault ["pattern",""]) != "STANDOFF"};
if (_nativeAttackWaypoint) then {_destination=getPosATL _target};
private _stageDistance=_aircraft distance2D _destination;
private _closestKey="closest"+_stage;
private _stageClosest=(_job getOrDefault [_closestKey,_stageDistance]) min _stageDistance;
_job set [_closestKey,_stageClosest];
private _shots=_aircraft getVariable ["WAIT_Cortex_AirAttackShots",0];
_job set ["shots",_shots];
// Surface profiles deliberately place the ATTACK waypoint beyond the objective so native flight
// remains smooth through release. Measure the aircraft against that immutable delivery axis as
// well as against the waypoint: once a plane has crossed the objective it has missed this pass and
// must egress. Chasing the endpoint after the useful basket has closed caused the repeated circles
// seen in the live audit. This is two vector operations for an active attack only.
private _deliveryAlong=-1e10;
private _deliveryPassed=false;
if (_isPlane && {_stage == "ATTACK"} && {!(_job getOrDefault ["airToAir",false])}) then {
    private _plannedTarget=+(_job getOrDefault ["targetPosition",getPosATL _target]);
    private _deliveryOrigin=+(_points select 0);
    private _deliveryAxis=_plannedTarget vectorDiff _deliveryOrigin;
    _deliveryAxis set [2,0];
    if (vectorMagnitude _deliveryAxis > 1) then {
        _deliveryAxis=vectorNormalized _deliveryAxis;
        private _relativeToTarget=(getPosATL _aircraft) vectorDiff _plannedTarget;
        _relativeToTarget set [2,0];
        _deliveryAlong=_relativeToTarget vectorDotProduct _deliveryAxis;
        _deliveryPassed=_deliveryAlong >= 350;
    };
};
private _stageAltitudes=_job getOrDefault ["stageAltitudes",[_job get "altitude",_job get "altitude",_job get "altitude"]];
private _stageSpeeds=_job getOrDefault ["stageSpeeds",[_job get "speed",_job get "speed",_job get "speed"]];
// A durable named waypoint is cheaper and smoother than restarting the engine flight planner on
// every scheduler tick. Update it only on a real stage transition. The attack-stage target order
// lets the native air-combat FSM handle subsequent contact movement without Cortex chasing it.
private _commandedStage=_job getOrDefault ["commandedStage",""];
if (_commandedStage != _stage && {!([] call _mayControlAircraft)}) exitWith {["CONTROL_RELEASED"] call _finish};
if (_commandedStage != _stage) then {
    _aircraft limitSpeed (_stageSpeeds select _stageIndex);
    // MOVE waypoint height is not a reliable flight-profile input for native aircraft. Apply one
    // terrain-relative height hint when the leg changes, then leave the flight model alone. The
    // terminal delivery assist below supplies only final weapon alignment; it does not become a
    // second route planner or continuously chase terrain.
    // This is deliberately not refreshed by the scheduler. Zeus handover deletes the lease waypoint
    // and does not issue a replacement movement command or delayed repair after curator ownership.
    _aircraft flyInHeight (_stageAltitudes select _stageIndex);
    private _ownedWaypointIndex=(waypoints _group) findIf {waypointName _x == _ownedWaypointName};
    private _ownedWaypoint=if (_ownedWaypointIndex < 0) then {
        private _created=_group addWaypoint [_destination,0];
        _created setWaypointName _ownedWaypointName;
        _created setWaypointType "MOVE";
        _created setWaypointBehaviour "COMBAT";
        _created setWaypointSpeed "FULL";
        _created setWaypointCompletionRadius ([450,220] select !_isPlane);
        _created
    } else {(waypoints _group) select _ownedWaypointIndex};
    _ownedWaypoint setWaypointPosition [_destination,0];
    // Object-attached DESTROY is the supported native attack association for both air and surface
    // targets. It lets the aircraft FSM form the actual attack angle instead of Cortex forcing an
    // attitude that is only safe over flat VR terrain.
    if (_nativeAttackWaypoint) then {
        _ownedWaypoint setWaypointPosition [getPosATL _target,0];
        _ownedWaypoint setWaypointType "DESTROY";
        _ownedWaypoint setWaypointCombatMode "RED";
        _ownedWaypoint waypointAttachVehicle _target;
    } else {
        _ownedWaypoint waypointAttachVehicle objNull;
        _ownedWaypoint setWaypointType "MOVE";
    };
    _group setCurrentWaypoint _ownedWaypoint;
    _job set ["commandedStage",_stage];
    _job set ["commandedDestination",+_destination];
    _job set ["commandedAt",serverTime];
    _job set ["stageBestDistance",_stageDistance];
    _job set ["stageProgressAt",serverTime];
};

// Measure useful approach to the active leg rather than raw displacement. Orbiting 300 metres and
// returning to the same range is not progress. A single threshold update is cheap and lets the
// engine use a broad turn without Cortex continuously rewriting its path.
private _stageBest=_job getOrDefault ["stageBestDistance",_stageDistance];
if (_stageDistance <= _stageBest-40) then {
    _stageBest=_stageDistance;
    _job set ["stageBestDistance",_stageBest];
    _job set ["stageProgressAt",serverTime];
};
private _routeStalled=serverTime >= (_job getOrDefault ["stageProgressAt",serverTime])+([35,24] select !_isPlane);
if (_stage == "ATTACK" && {!([] call _mayControlAircraft)}) exitWith {["CONTROL_RELEASED"] call _finish};
if (_stage == "ATTACK") then {
    // This flag is live for one scheduler pass only. It selects a faster cadence while a fixed
    // weapon is inside its terminal basket without turning every aircraft job into a high-rate
    // controller.
    _job set ["deliveryAssistActive",false];
    private _pattern=_job getOrDefault ["pattern",""];
    private _airContact=_job getOrDefault ["airToAir",false];
    private _weapon=_job getOrDefault ["selectedWeapon",""];
    private _turret=_job getOrDefault ["selectedTurret",[]];
    private _simulation=_job getOrDefault ["selectedSimulation",""];
    private _weaponClass=_job getOrDefault ["selectedWeaponClass",""];
    private _operator=if (_turret isEqualTo [-1]) then {_pilot} else {_aircraft turretUnit _turret};
    private _fireTarget=_job getOrDefault ["fireTarget",_target];
    if (isNull _fireTarget) then {_fireTarget=_target};
    private _pilotSurfaceStation=_isPlane && {!_airContact} && {_turret isEqualTo [-1]};
    // Select the retained station once for this attack phase. Re-selecting it on every scheduler
    // callback restarts native weapon handling while the pilot or gunner is still acquiring the
    // same target, producing the observed pause/fire/pause cycle and refused releases.
    if (_weapon != "" && {!(_job getOrDefault ["weaponSelected",false])}) then {
        _aircraft selectWeaponTurret [_weapon,_turret];
        _job set ["weaponSelected",true];
    };
    if (!isNull _operator && {alive _operator} && {!(_job getOrDefault ["targetCommanded",false])}) then {
        // The object-attached DESTROY waypoint is already the fixed-wing pilot's native attack
        // owner. A duplicate doTarget on that pilot can replace the committed run with ATTACK pursuit
        // and produce a circle before release. Turrets, helicopters and air-to-air engagements do
        // not have that surface-run association, so their actual operator receives one target order.
        if (!_pilotSurfaceStation) then {
            _operator doWatch _fireTarget;
            _operator doTarget _fireTarget;
        };
        _job set ["targetCommanded",true];
    };
    private _range=_aircraft distance _target;
    private _horizontalRange=_aircraft distance2D _target;
    // The plan-time corridor and live safety floor may veto an unsafe run. They do not manufacture
    // a pitch correction. Native attack flight retains the continuous terrain and obstacle picture
    // that a sparse scheduled script cannot reproduce cheaply or safely.
    private _deliveryTerrainClear=_job getOrDefault ["terrainViable",true];
    private _weaponVector=if (_weapon == "") then {[0,0,0]} else {_aircraft weaponDirection _weapon};
    private _targetVector=(aimPos _target) vectorDiff (getPosASL _aircraft);
    private _alignment=if (vectorMagnitude _weaponVector > 0.01 && {vectorMagnitude _targetVector > 0.01}) then {
        (vectorNormalized _weaponVector) vectorDotProduct (vectorNormalized _targetVector)
    } else {-1};
    private _aimed=if (_weapon == "") then {0} else {_aircraft aimedAtTarget [_target,_weapon]};
    private _selectedMagazine=_job getOrDefault ["selectedMagazine",""];
    private _magazineConfig=configFile >> "CfgMagazines" >> _selectedMagazine;
    private _ammoClass=getText (_magazineConfig >> "ammo");
    private _muzzleSpeed=getNumber (_magazineConfig >> "initSpeed");
    if (_muzzleSpeed <= 0 && {_ammoClass != ""}) then {
        _muzzleSpeed=getNumber (configFile >> "CfgAmmo" >> _ammoClass >> "typicalSpeed");
    };
    if (_muzzleSpeed <= 0) then {
        _muzzleSpeed=switch _weaponClass do {
            case "ROCKET": {180};
            case "BOMB": {0};
            default {900};
        };
    };
    private _predictedLaunchVelocity=((vectorNormalized _weaponVector) vectorMultiply _muzzleSpeed)
        vectorAdd (velocity _aircraft);
    private _launchAlignment=if (vectorMagnitude _predictedLaunchVelocity > 0.01
        && {vectorMagnitude _targetVector > 0.01}) then {
        (vectorNormalized _predictedLaunchVelocity) vectorDotProduct (vectorNormalized _targetVector)
    } else {-1};
    // The planner selected a concrete magazine/weapon/turret tuple. A different compatible
    // magazine can carry a different seeker or delivery family on the same launcher, so treating
    // it as interchangeable here can release the wrong ordnance at a ground target. Refuse the
    // finite release when that exact station is depleted and let native combat decide what to do.
    private _loaded=(magazinesAllTurrets _aircraft) findIf {
        (_x select 1) isEqualTo _turret && {(_x select 2) > 0}
            && {(_x select 0) == _selectedMagazine}
    } >= 0;
    private _envelope=switch _weaponClass do {
        case "GUN": {if (_airContact) then {[100,2200,0.999]} else {[120,1400,0.9995]}};
        // Native CAS opens fixed gun and rocket fire close to the aim point. A 3.6 km rocket basket
        // let the engine accept a request while the aircraft was merely pointed into the broad
        // target sector; real rounds then passed 500-950 metres away. Retain the long ingress but
        // reserve release for the final 1.8 km of a measured delivery line.
        case "ROCKET": {[400,1800,0.998]};
        // A guided seeker needs a clean forward launch sector, not a gun-quality boresight solution.
        // The Fired handler assigns the selected hostile to the real projectile after release.
        // Fixed forward weapons release synchronously below. Keep a clean seeker launch cone so the
        // target remains inside its acquisition basket without scripting projectile flight.
        case "GUIDED": {if (_airContact) then {[800,9000,0.96]} else {[1100,9000,0.97]}};
        case "BOMB": {[700,6500,0.9]};
        default {[0,0,1]};
    };
    _envelope params ["_minimumRange","_maximumRange","_minimumAlignment"];
    private _guided=_weaponClass == "GUIDED";
    private _bomb=_weaponClass == "BOMB";
    private _airForward=vectorDir _aircraft;
    private _horizontalTarget=+_targetVector;
    _horizontalTarget set [2,0];
    private _horizontalForward=+_airForward;
    _horizontalForward set [2,0];
    private _forwardAlignment=if (vectorMagnitude _horizontalTarget > 0.01 && {vectorMagnitude _horizontalForward > 0.01}) then {
        (vectorNormalized _horizontalForward) vectorDotProduct (vectorNormalized _horizontalTarget)
    } else {-1};
    private _deliveryAngle=acos ((_alignment max -1) min 1);
    // A bomb rack points with the airframe and cannot be validated by comparing weaponDirection to
    // the target. Integrate the selected ammunition's configured drag from the live aircraft state.
    // This does not steer the bomb or guarantee a hit; it only creates a terrain-relative release
    // basket rather than assuming flat ground, constant horizontal speed and vacuum ballistics.
    private _horizontalVelocity=velocity _aircraft;
    _horizontalVelocity set [2,0];
    private _heightAGL=(getPosATL _aircraft select 2) max 1;
    private _verticalSpeed=velocity _aircraft select 2;
    private _fallTime=(_verticalSpeed+sqrt ((_verticalSpeed*_verticalSpeed)+(2*9.81*_heightAGL)))/9.81;
    private _bombReleaseDistance=(vectorMagnitude _horizontalVelocity)*_fallTime;
    private _predictedBombImpact=(getPosASL _aircraft) vectorAdd (_horizontalVelocity vectorMultiply _fallTime);
    if (_bomb) then {
        // ASL is required for a ballistic path between terrain cells. ATL zero follows the local
        // ground and would make a valley-to-ridge or ridge-to-valley release solve against a false
        // vertical plane even though the horizontal coordinates looked correct.
        private _integrationPosition=getPosASL _aircraft;
        private _integrationVelocity=velocity _aircraft;
        if (_muzzleSpeed > 0) then {
            _integrationVelocity=_integrationVelocity vectorAdd ((vectorDir _aircraft) vectorMultiply _muzzleSpeed);
        };
        private _airFriction=getNumber (configFile >> "CfgAmmo" >> _ammoClass >> "airFriction");
        private _targetAltitude=aimPos _target select 2;
        private _integrationTime=0;
        private _integrationStep=0.2;
        for "_integrationIndex" from 0 to 119 do {
            if ((_integrationPosition select 2) > _targetAltitude) then {
                private _dragAcceleration=_integrationVelocity vectorMultiply
                    (_airFriction*(vectorMagnitude _integrationVelocity));
                _integrationVelocity=_integrationVelocity vectorAdd (_dragAcceleration vectorMultiply _integrationStep);
                _integrationVelocity set [2,(_integrationVelocity select 2)-(9.81*_integrationStep)];
                _integrationPosition=_integrationPosition vectorAdd (_integrationVelocity vectorMultiply _integrationStep);
                _integrationTime=_integrationTime+_integrationStep;
            };
        };
        _fallTime=_integrationTime;
        _predictedBombImpact=_integrationPosition;
        _bombReleaseDistance=(getPosASL _aircraft) distance2D _predictedBombImpact;
    };
    private _bombImpactError=_predictedBombImpact distance2D getPosASL _target;
    private _bombWindow=_bombImpactError <= 55 && {_forwardAlignment >= 0.92};
    // A nose-mounted weapon needs forward closure. A retained lateral turret is specifically
    // selected to fire abeam, so forcing the helicopter nose onto the target defeats that pattern.
    private _closing=_pattern == "LATERAL" || {_forwardAlignment > 0.35};
    private _fixedUnguided=_turret isEqualTo [-1] && {_weaponClass in ["GUN","ROCKET"]};
    // aimedAtTarget is useful telemetry but is not a reliable release gate for fixed-wing pilot
    // stations. The native attached attack owns that release; this basket remains useful for
    // diagnostics and for independently aimed turret requests.
    private _minimumAim=0;
    // The native DESTROY order now forms the fixed-wing attack attitude. Keep this as a telemetry
    // basket for the real operator rather than replacing native flight with a scripted rotation.
    private _nativeFixedBasket=!_fixedUnguided || {
        _forwardAlignment >= ([0.985,0.975] select (_weaponClass == "ROCKET"))
    };
    private _validSolution=_loaded && {!isNull _operator} && {alive _operator}
        && {_range >= _minimumRange} && {_range <= _maximumRange}
        && {_closing} && {_nativeFixedBasket} && {_deliveryTerrainClear}
        && {_bombWindow || {!_bomb && {!_fixedUnguided || {_forwardAlignment >= 0.94}}}}
        && {!_bomb || {(getPosATL _aircraft select 2) >= 250}};
    private _solution=[_validSolution,_range,_alignment,_aimed,_weapon,_simulation,_loaded,
        _weaponClass,_envelope,_deliveryAngle,_forwardAlignment,_minimumAim,_closing,
        _horizontalRange,_bombReleaseDistance,_bombWindow,_muzzleSpeed,_launchAlignment,
        _predictedBombImpact,_bombImpactError,_job getOrDefault ["deliveryAssistSamples",[]],
        _job getOrDefault ["deliveryAssistActive",false],_deliveryTerrainClear,
        _deliveryAlong,_deliveryPassed];
    _job set ["fireSolution",_solution];
    _job set ["deliveryLoaded",_loaded];
    _aircraft setVariable ["WAIT_Cortex_AirFireSolution",_solution,true];
    // Turrets use fireAtTarget after their operator has tracked the hostile. Fixed-wing pilot
    // stations retain the native attached DESTROY order for flight, then receive one doFire request
    // once a real delivery basket exists. The Fired handler is the sole proof of either release
    // path; no projectile is created, steered or corrected here.
    private _requestAt=_job getOrDefault ["fireRequestAt",-1];
    private _requestShotBaseline=_job getOrDefault ["fireRequestShotBaseline",-1];
    private _requestProducedShot=_requestAt >= 0 && {_shots > _requestShotBaseline};
    if (_requestProducedShot) then {
        _job set ["fireRequestAttempts",0];
    };
    // A native doFire/fireAtTarget request is asynchronous. Give the operator three seconds to
    // accept or refuse it instead of submitting the same command every scheduler pass. Permit at
    // most one no-shot retry during this delivery; real Fired events reset the counter so a finite
    // rocket ripple or gun burst can continue without command spam.
    private _requestAttempts=_job getOrDefault ["fireRequestAttempts",0];
    private _requestPending=_requestAt >= 0 && {!_requestProducedShot}
        && {serverTime < _requestAt+3};
    private _requestAvailable=_requestProducedShot || {_requestAt < 0}
        || {!_requestPending && {_requestAttempts < 2}};
    private _pilotSurfaceRelease=_pilotSurfaceStation;
    if (_validSolution && {_pilotSurfaceRelease} && {_requestAvailable}
        && {serverTime >= (_job getOrDefault ["nextWeaponFire",0])}) then {
        // The attached DESTROY waypoint establishes the run but does not consistently ask a
        // pilot-operated fixed station to release. Request native fire once; a Fired event remains
        // mandatory evidence, so an unavailable weapon or refused command cannot pass this run.
        _operator doFire _fireTarget;
        _job set ["releaseDetail",["NATIVE_PILOT_REQUEST",_weapon,_range,_forwardAlignment,
            _deliveryAlong,_deliveryTerrainClear,waypointType [_group,currentWaypoint _group]]];
        _job set ["fireRequestAt",serverTime];
        _job set ["fireRequestShotBaseline",_shots];
        _job set ["fireRequestAttempts",[1,_requestAttempts+1] select !_requestProducedShot];
        private _pilotFireDelay=switch _weaponClass do {
            case "GUN": {0.18+random 0.22};
            case "ROCKET": {0.5+random 0.5};
            case "BOMB": {1.2+random 0.8};
            default {1.8+random 1.2};
        };
        _job set ["nextWeaponFire",serverTime+_pilotFireDelay];
    };
    if (_validSolution && {!_pilotSurfaceRelease} && {_requestAvailable}
        && {serverTime >= (_job getOrDefault ["nextWeaponFire",0])}) then {
        // One native request at a time for an independently aimed turret. Fixed-wing pilots are
        // already controlled by the native attached DESTROY order above.
        private _fired=_aircraft fireAtTarget [_fireTarget,_weapon];
        if (_fired) then {
            _job set ["releaseDetail",["NATIVE_TURRET",_weapon,_range,_alignment,_aimed]];
        };
        if (_fired) then {
            _job set ["fireRequestAt",serverTime];
            _job set ["fireRequestShotBaseline",_shots];
            _job set ["fireRequestAttempts",[1,_requestAttempts+1] select !_requestProducedShot];
        };
        private _fireDelay=if (!_fired) then {0.7+random 0.8} else {
            switch _weaponClass do {
                case "GUN": {0.15+random 0.25};
                case "ROCKET": {0.45+random 0.55};
                default {2+random 1.5};
            }
        };
        _job set ["nextWeaponFire",serverTime+_fireDelay];
    };
};

private _flareSetting=[_group,"WAIT_Cortex_AttackRunFlares_Enable",true] call WAIT_fnc_CortexFeatureEnabled;
private _flareKey="flare"+_stage;
private _flareCount=_job getOrDefault [_flareKey,0];
private _flareNextKey="flareNext"+_stage;
private _flareNext=_job getOrDefault [_flareNextKey,serverTime];
if (_flareSetting && {_stage in ["INGRESS","EGRESS"]} && {_flareCount < 3} && {serverTime >= _flareNext}) then {
    _aircraft setVariable ["WAIT_Cortex_AttackFlarePhase",["APPROACH","DEPARTURE"] select (_stage == "EGRESS"),true];
    if ([_aircraft] call WAIT_fnc_CortexFireCountermeasure) then {
        _job set [_flareKey,_flareCount+1];
    };
    // Avoid synchronized salvos across aircraft and respect launcher cycle time.
    _job set [_flareNextKey,serverTime+0.8+random 0.8];
};
_aircraft setVariable ["WAIT_Cortex_AirAttackPlan",[
    _job get "token",_job get "pattern",_stage,_target,_destination,_aircraft distance2D _destination,
    _shots,count ((_job getOrDefault ["aaPositions",[]])),speed _aircraft,getPosATL _aircraft select 2,
    _job getOrDefault ["flareINGRESS",0],_job getOrDefault ["flareEGRESS",0],
    ["HELICOPTER","PLANE"] select _isPlane,_job getOrDefault ["lateralTurret",false]
    ,_job getOrDefault ["standoffWeapon",""],_job getOrDefault ["standoffTurret",[]],
    _job getOrDefault ["fireSolution",[]],
    _job getOrDefault ["stageAltitudes",[]],_job getOrDefault ["stageSpeeds",[]],
    _job getOrDefault ["captureRadii",[]],_job getOrDefault ["attackMinimum",0],
    +(_job getOrDefault ["points",[]]),
    _job getOrDefault ["selectedWeapon",""],_job getOrDefault ["selectedSimulation",""],
    _job getOrDefault ["selectedTurret",[]],_job getOrDefault ["selectedWeaponClass",""],
    _job getOrDefault ["selectedMagazine",""],
    _job getOrDefault ["terrainLift",0],_job getOrDefault ["terrainClearanceMinimum",0],
    _job getOrDefault ["terrainSampleCount",0],_job getOrDefault ["terrainCorridor",0],
    +(_job getOrDefault ["targetPosition",getPosATL _target]),
    _job getOrDefault ["terrainRequiredLift",0],_job getOrDefault ["terrainViable",true]
],true];

private _attackShots=_shots-(_job getOrDefault ["attackShotBaseline",0]);
if (_stage == "ATTACK" && {_attackShots > 0} && {(_job getOrDefault ["firstAttackShotAt",-1]) < 0}) then {
    _job set ["firstAttackShotAt",serverTime];
};
if ((_job getOrDefault ["pattern",""]) == "STANDOFF" && {_stage == "ATTACK"} && {_attackShots <= 0}
    && {serverTime > (_job getOrDefault ["attackStartedAt",serverTime])+25}) exitWith {
    _aircraft setVariable ["WAIT_Cortex_AirStandoffBlockedUntil",serverTime+90];
    ["NO_FIRE_SOLUTION",true] call _finish
};
if (serverTime > (_job get "deadline")) exitWith {["STAGE_TIMEOUT"] call _finish};
private _captureRadii=_job getOrDefault ["captureRadii",[if (_isPlane) then {700} else {450},if (_isPlane) then {700} else {450},if (_isPlane) then {700} else {450}]];
private _captureRadius=_captureRadii select _stageIndex;
// Rotorcraft do not capture exact three-dimensional move points under native combat flight. A
// modest approach tolerance advances into the real attack instruction before the pilot starts a
// local orbit; fixed-wing profiles retain their larger authored capture radii unchanged.
private _effectiveCapture=_captureRadius+([0,150] select !_isPlane);
private _stagePassed=_stageClosest <= _captureRadius && {_stageDistance >= _stageClosest+([120,75] select !_isPlane)};
// Discovery can acquire a fast jet after it has already flown past the nominal ingress point.
// Continue into the firing leg when that point is physically behind the jet; ordering a turn back
// creates the observed pre-run loop and can never improve a fixed-wing attack solution.
private _ingressBehind=_isPlane && {_stage == "INGRESS"}
    && {(velocity _aircraft) vectorDotProduct (_destination vectorDiff getPosATL _aircraft) <= 0}
    && {_aircraft distance2D _target <= 9500}
    && {(velocity _aircraft) vectorDotProduct ((getPosATL _target) vectorDiff getPosATL _aircraft) > 0};
// A lateral helicopter ingress is complete when the live aircraft enters its turret's practical
// engagement range. Native rotary-wing combat flight does not reliably capture an arbitrary offset
// point while a gunner is tracking a contact; waiting for that coordinate caused useful flight and
// gunfire to be labelled INGRESS_NONPROGRESS instead of beginning the abeam attack.
private _lateralWeaponEntry=!_isPlane && {_stage == "INGRESS"}
    && {(_job getOrDefault ["pattern",""]) == "LATERAL"}
    && {_aircraft distance2D _target <= 1800};
if (_stage == "EGRESS" && {(_stageDistance <= _effectiveCapture || {_stagePassed})}
    && {_aircraft distance2D (_points select 1) >= 400}) exitWith {["COMPLETE",true] call _finish};
private _egressTravel=if (_stage == "EGRESS") then {
    _aircraft distance2D (_job getOrDefault ["egressStartPosition",getPosATL _aircraft])
} else {0};
private _awayFromTarget=(velocity _aircraft) vectorDotProduct ((getPosATL _aircraft) vectorDiff
    (_job getOrDefault ["lastTargetPosition",getPosATL _aircraft])) > 0;
// Fast fixed-wing aircraft do not reliably capture an exact doMove point after a weapon release.
// Physical travel away from the target is an equally valid egress and avoids holding the aircraft
// under Cortex until a timeout after the attack has already succeeded.
if (_stage == "EGRESS" && {_egressTravel >= ([350,900] select _isPlane)}
    && {_awayFromTarget || {_egressTravel >= ([700,1400] select _isPlane)}}) exitWith {["COMPLETE",true] call _finish};
if (_stage == "EGRESS" && {_routeStalled}) exitWith {["EGRESS_NONPROGRESS",true] call _finish};
if (_stage in ["INGRESS","ATTACK"] && {_routeStalled}) exitWith {
    [["INGRESS_NONPROGRESS","ATTACK_NONPROGRESS"] select (_stage == "ATTACK"),true] call _finish
};
switch _stage do {
    case "INGRESS": {
        // Aircraft rarely hit an exact doMove coordinate, especially at fixed-wing turn radius.
        // Accept entering or physically passing a bounded capture area; elapsed time alone still
        // cannot advance the state.
        if (_stageDistance <= _effectiveCapture || {_stagePassed} || {_ingressBehind} || {_lateralWeaponEntry}) then {
            [_group,_job,"ATTACK","INGRESS_ARRIVAL"] call WAIT_fnc_CortexDrillSetStage;
            _stage="ATTACK";
            ["ATTACK"] call _setOperationPhase;
            _job set ["commandedStage",""];
            _job set ["weaponSelected",false];
            _job set ["fireRequestAt",-1];
            _job set ["fireRequestShotBaseline",-1];
            _job set ["fireRequestAttempts",0];
            _job set ["deadline",serverTime+50];
            _job set ["attackStartedAt",serverTime];
            _job set ["attackShotBaseline",_shots];
            // The public plan drives diagnostics and Fired-event attribution. Publish the accepted
            // transition immediately instead of leaving it one budget tick behind the real job;
            // otherwise successful rounds are incorrectly labelled as ingress fire.
            private _publishedPlan=_aircraft getVariable ["WAIT_Cortex_AirAttackPlan",[]];
            if (_publishedPlan isNotEqualTo []) then {
                _publishedPlan set [2,"ATTACK"];
                _publishedPlan set [4,_points select 1];
                _aircraft setVariable ["WAIT_Cortex_AirAttackPlan",_publishedPlan,true];
            };
        };
    };
    case "ATTACK": {
        private _attackDwell=serverTime-(_job getOrDefault ["attackStartedAt",serverTime]);
        private _weaponClass=_job getOrDefault ["selectedWeaponClass",""];
        private _standoffPass=(_job getOrDefault ["pattern",""]) == "STANDOFF" && {_weaponClass == "GUIDED"};
        private _desiredShots=if (_standoffPass) then {1} else {switch _weaponClass do {
            // The Comanche emits about ninety rounds from one accepted cannon burst. That left a
            // soft military truck mobile in the live audit, so allow a second bounded burst before
            // egress. Dispersion and damage remain wholly native; no hit or kill is fabricated.
            case "GUN": {120};
            case "ROCKET": {8};
            // Other guided runs can use a finite salvo. A stand-off pass releases one actual missile
            // and leaves the threat sector instead of crossing the target to manufacture a salvo.
            case "GUIDED": {3};
            // Release the paired bomb rack when fitted. One verified direct pass in the audit left
            // the tracked target untouched; a two-weapon ripple is the credible finite delivery.
            case "BOMB": {2};
            default {1};
        }};
        // The release basket is the delivery point. Let finite gun/rocket/guided salvos develop
        // across a few native fire-control cycles, then leave promptly. A one-round rack and an
        // engine that refuses a follow-up cannot strand the aircraft: empty ammunition or six
        // bounded class-specific interval after the first real shot closes the delivery. A turreted
        // cannon needs longer than a missile rail because dispersion is intentionally applied to
        // vehicle crews. Target destruction still ends the attack immediately at the top of the
        // next scheduler tick; no hit or kill is fabricated here.
        private _deliveryWindow=switch _weaponClass do {
            case "GUN": {18};
            case "ROCKET": {12};
            default {10};
        };
        private _deliveryComplete=_attackShots >= _desiredShots
            || {_attackShots > 0 && {!(_job getOrDefault ["deliveryLoaded",true])}}
            || {_attackShots > 0 && {serverTime >= (_job getOrDefault ["firstAttackShotAt",serverTime])+_deliveryWindow}};
        // Overflight profiles close their delivery once the aircraft passes the objective. Guided
        // stand-off profiles close earlier, at their minimum launch range: continuing beyond that
        // window would cross the target and reintroduce the loop the standoff route avoids.
        // This case runs after the earlier release-basket scope has ended. Re-measure only the
        // small geometry needed to close an unused guided pass; do not retain a per-frame flight
        // controller or borrow stale basket values from a previous scheduler step.
        private _standoffRange=_aircraft distance _target;
        private _standoffTargetVector=(aimPos _target) vectorDiff (getPosASL _aircraft);
        _standoffTargetVector set [2,0];
        private _standoffForward=vectorDir _aircraft;
        _standoffForward set [2,0];
        private _standoffForwardAlignment=if (vectorMagnitude _standoffTargetVector > 0.01
            && {vectorMagnitude _standoffForward > 0.01}) then {
            (vectorNormalized _standoffForward) vectorDotProduct (vectorNormalized _standoffTargetVector)
        } else {-1};
        private _standoffMinimumRange=if (_job getOrDefault ["airToAir",false]) then {800} else {1100};
        private _standoffWindowClosed=_standoffPass && {_attackShots <= 0}
            && {_standoffRange <= _standoffMinimumRange+150} && {_standoffForwardAlignment > 0.75};
        if (_attackShots <= 0 && {_deliveryPassed || {_standoffWindowClosed}}) then {
            _job set ["deliveryMissed",true];
            [_group,_job,"EGRESS","DELIVERY_WINDOW_PASSED"] call WAIT_fnc_CortexDrillSetStage;
            _stage="EGRESS";
            ["EGRESS"] call _setOperationPhase;
            _job set ["commandedStage",""];
            _job set ["egressStartPosition",getPosATL _aircraft];
            _job set ["egressStartedAt",serverTime];
            _job set ["deadline",serverTime+75];
            private _publishedPlan=_aircraft getVariable ["WAIT_Cortex_AirAttackPlan",[]];
            if (_publishedPlan isNotEqualTo []) then {
                _publishedPlan set [2,"EGRESS"];
                _publishedPlan set [4,_points select 2];
                _aircraft setVariable ["WAIT_Cortex_AirAttackPlan",_publishedPlan,true];
            };
        };
        if (_attackShots > 0 && {_attackDwell >= (_job getOrDefault ["attackMinimum",2])}
            && {_deliveryComplete}) then {
            [_group,_job,"EGRESS","ACTUAL_FIRE"] call WAIT_fnc_CortexDrillSetStage;
            _stage="EGRESS";
            ["EGRESS"] call _setOperationPhase;
            _job set ["commandedStage",""];
            _job set ["egressStartPosition",getPosATL _aircraft];
            _job set ["egressStartedAt",serverTime];
            _job set ["deadline",serverTime+75];
            private _publishedPlan=_aircraft getVariable ["WAIT_Cortex_AirAttackPlan",[]];
            if (_publishedPlan isNotEqualTo []) then {
                _publishedPlan set [2,"EGRESS"];
                _publishedPlan set [4,_points select 2];
                _aircraft setVariable ["WAIT_Cortex_AirAttackPlan",_publishedPlan,true];
            };
        };
    };
    case "EGRESS": {};
};
0.5

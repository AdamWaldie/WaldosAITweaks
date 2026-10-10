/*
 * Author: WaldoTheWarfighter
 * Stops Cortex on this machine and hands every affected group back to its own orders.
 *
 * Removes tactical event handlers and discards tactical jobs. The shared scheduler and skill jobs
 * remain while skill adjustment is enabled. Every locally managed
 * group is released (WAIT_fnc_CortexReleaseGroup): drills end with only the AI features they
 * disabled re-enabled, pass waypoints are removed, behaviour and speed are restored and COMPAT group AI
 * is handed back. Survivors still walking to a host get doFollow. Defence, garrison and clear
 * orders are released on their owner so restarting cannot revive an order superseded while off.
 * Completed merges and surrenders are not undone.
 * Locality and authority: a direct server call requests disable through the CBA server layer.
 * CBA callbacks clean up on each owner; joining owners receive the disabled value from CBA.
 * Remote calls from anything other than the server are refused. Each machine handles its local groups.
 *
 * Repeat/JIP: Repeat calls clear pending startup and abandoned jobs. Owner-local release clears
 * public defence/garrison assignments and restores only Cortex-owned movement restrictions.
 * Restart and ownership adoption cannot replay cancelled orders; tracked aircraft handlers are removed.
 * Public support request/responder state, delayed artillery-relocation tokens and attack-run
 * presentation state are invalidated. An active aircraft lease restores its recorded native group
 * attack policy, deletes its finite native guidance target and named movement waypoint, and removes
 * its firing-solution telemetry and re-attack cooldown before the job is discarded.
 * Vehicle safe-stop handshakes restore their prior forced speed only while their exact zero-speed
 * lease remains current; a newer vehicle controller's cap is preserved when tokens are cleared.
 * Ordinary unload-in-combat leases likewise restore only their exact unchanged applied value.
 * Targetless onboard danger reports are also retracted before the scheduler is discarded.
 * Owner-local missile-warning generations are advanced before handlers are removed; an
 * old CBA callback cannot become valid again after a quick restart.
 * Civilian event handlers and their EntityCreated installer are removed; external addon state is
 * never cleared. external controller and COMPAT movement leases restore their captured baseline through group release.
 * Danger assessment: bounded member events use generation-scoped finite FSMs and only wake the existing
 * group decision job; handlers retire on membership/owner changes and shutdown. No second movement owner.
 *
 * Arguments: None.
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [] call WAIT_fnc_CortexStop;
 * Result: no further pass behaviour runs anywhere until WAIT_fnc_CortexInit is called again.
 *
 * Current callers: CBA setting callbacks.
 */

if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {};
if (isServer && {missionNamespace getVariable ["WAIT_AIPass_Enable", false]}) exitWith {
    [createHashMapFromArray [["WAIT_AIPass_Enable", false]]] call WAIT_fnc_CortexTuning;
};
if (isServer) then {
    {
        private _job = _y;
        private _requester=_job getOrDefault ["requester",grpNull];
        if (!isNull _requester) then {
            private _brain=_requester getVariable ["WAIT_Support_Brain",createHashMap];
            if (count _brain > 0) then {
                _brain set ["cancelled",true];
                _brain set ["cancelReason","CORTEX_STOPPED"];
            };
            _requester setVariable ["WAIT_Cortex_SupportResponders",nil,true];
            _requester setVariable ["WAIT_Cortex_SupportRequestState",nil,true];
        };
        {(_x select 0) setVariable ["WAIT_AIPass_SupportLease",nil,true]} forEach (_job get "leases");
    } forEach (missionNamespace getVariable ["WAIT_AIPass_SupportRequests",createHashMap]);
    missionNamespace setVariable ["WAIT_AIPass_SupportRequests",createHashMap];
    missionNamespace setVariable ["WAIT_AIPass_CounterGeneration", (missionNamespace getVariable ["WAIT_AIPass_CounterGeneration", 0]) + 1];
    {
        private _battery = _y get "battery";
        private _brain=_battery getVariable ["WAIT_Artillery_Brain",createHashMap];
        if (count _brain > 0) then {
            _brain set ["cancelled",true];
            _brain set ["cancelReason","CORTEX_STOPPED"];
        };
        _battery setVariable ["WAIT_AIPass_FireToken", nil, true];
        _battery setVariable ["WAIT_AIPass_BusyUntil", nil, true];
    } forEach (missionNamespace getVariable ["WAIT_AIPass_FireMissions", createHashMap]);
    missionNamespace setVariable ["WAIT_AIPass_FireMissions", createHashMap];
    // Stop is a rare administrative action, so one bounded-by-world vehicle pass is preferable to
    // maintaining another runtime registry. Clearing the public token makes every already queued
    // shoot-and-scoot callback fail its first identity check, including after Cortex restarts.
    {
        [_x] call WAIT_fnc_DrivingAssistRelease;
        private _unloadLease=_x getVariable ["WAIT_Cortex_UnloadPolicyLease",[]];
        if (count _unloadLease == 5 && {local _x}) then {
            [_x,_unloadLease select 0,"RELEASE",true] call WAIT_fnc_CortexVehicleUnloadPolicy;
        };
        private _savedStopSpeed=_x getVariable ["WAIT_Cortex_DismountForcedSpeed",[]];
        private _ownedStop=_savedStopSpeed param [1,-2];
        if (_savedStopSpeed isNotEqualTo [] && {local _x} && {_ownedStop >= 0}
            && {abs ((getForcedSpeed _x)-_ownedStop) <= 0.1}) then {
            _x forceSpeed (_savedStopSpeed param [0,-1]);
        };
        _x setVariable ["WAIT_Cortex_DismountForcedSpeed",nil];
        _x setVariable ["WAIT_Cortex_DismountStopOrder",nil,true];
        _x setVariable ["WAIT_Cortex_DismountStopRequest",nil,true];
        _x setVariable ["WAIT_Cortex_OnboardDanger",nil,true];
        _x setVariable ["WAIT_Cortex_ArtilleryScootToken",nil,true];
        _x setVariable ["WAIT_Cortex_ArtilleryScootDeadline",nil,true];
        _x setVariable ["WAIT_Cortex_ArtilleryScootPurpose",nil,true];
        if (_x isKindOf "Air") then {
            private _guidanceTarget=_x getVariable ["WAIT_Cortex_AirAttackGuidanceTarget",objNull];
            if (!isNull _guidanceTarget) then {deleteVehicle _guidanceTarget};
            _x setVariable ["WAIT_Cortex_AttackFlarePhase",nil,true];
            _x setVariable ["WAIT_Cortex_AttackFlareCooldown",nil,true];
            _x setVariable ["WAIT_Cortex_AirAttackPlan",nil,true];
            _x setVariable ["WAIT_Cortex_AirFireSolution",nil,true];
            _x setVariable ["WAIT_Cortex_AirAttackTarget",nil];
            _x setVariable ["WAIT_Cortex_AirAttackGuidedWeapon",nil];
            _x setVariable ["WAIT_Cortex_AirAttackGuidanceTarget",nil];
            _x setVariable ["WAIT_Cortex_AirAttackBlockedUntil",nil];
        };
    } forEach vehicles;
};
if (hasInterface && {!isServer}) exitWith {};
missionNamespace setVariable ["WAIT_AIPass_Active", false];
missionNamespace setVariable ["WAIT_AIPass_InitPending", false];

{
    private _handler = _x getVariable ["WAIT_AIPass_FlaresHandler", -1];
    if (_handler >= 0) then {_x removeEventHandler ["IncomingMissile", _handler]};
    _x setVariable ["WAIT_Cortex_FlareBurstGeneration",
        (_x getVariable ["WAIT_Cortex_FlareBurstGeneration",0])+1];
    _x setVariable ["WAIT_Cortex_MissileDefenceActive",nil];
    _x setVariable ["WAIT_AIPass_FlaresHandler", nil];
    _x setVariable ["WAIT_AIPass_FlaresInstalled", nil];
} forEach (missionNamespace getVariable ["WAIT_AIPass_FlareVehicles", []]);
missionNamespace setVariable ["WAIT_AIPass_FlareVehicles", []];

// Aircraft attack persistence now lives outside the recurring scheduler queue. Retire each local
// brain explicitly and let its bounded implementation perform the same owned-waypoint, handler,
// speed and operation cleanup it uses for every other authority loss.
{
    private _aircraft=_x;
    private _brain=_aircraft getVariable ["WAIT_AirAttack_Brain",createHashMap];
    if (local _aircraft && {count _brain > 0}) then {
        _brain set ["cancelled",true];
        _brain set ["cancelReason","CORTEX_STOPPED"];
        private _attackJob=_brain getOrDefault ["job",createHashMap];
        if (count _attackJob > 0) then {[_attackJob] call WAIT_fnc_CortexAirAttack};
        _aircraft setVariable ["WAIT_AirAttack_BrainGeneration",(_aircraft getVariable ["WAIT_AirAttack_BrainGeneration",0])+1];
        _aircraft setVariable ["WAIT_AirAttack_Brain",nil];
        _aircraft setVariable ["WAIT_AirAttack_Brain_FSM",nil];
        _aircraft setVariable ["WAIT_Cortex_AirAttackJob",nil];
    };
} forEach (vehicles select {_x isKindOf "Air"});

{
    _x params ["_variable", "_event"];
    private _handler = missionNamespace getVariable _variable;
    if (!isNil "_handler") then {
        removeMissionEventHandler [_event, _handler];
        missionNamespace setVariable [_variable, nil];
    };
} forEach [
    ["WAIT_AIPass_KilledHandler", "EntityKilled"],
    ["WAIT_AIPass_ProjectileHandler", "ProjectileCreated"],
    ["WAIT_AIPass_ArtilleryHandler", "ArtilleryShellFired"]
];
private _civilianCreated=missionNamespace getVariable "WAIT_Cortex_CivilianCreatedHandler";
if (!isNil "_civilianCreated") then {
    removeMissionEventHandler ["EntityCreated",_civilianCreated];
    missionNamespace setVariable ["WAIT_Cortex_CivilianCreatedHandler",nil];
};
{
    [_x,true] call WAIT_fnc_CortexCivilianSetup;
    private _local=_x getVariable ["WAIT_Cortex_CivilianLocalHandler",-1];
    if (_local >= 0) then {_x removeEventHandler ["Local",_local]};
    _x setVariable ["WAIT_Cortex_CivilianLocalHandler",nil];
} forEach (allUnits select {side group _x == civilian});
{
    [_x,true] call WAIT_fnc_CortexHearingLocal;
    [_x,true] call WAIT_fnc_DangerSetup;
    private _brain=_x getVariable ["WAIT_GroupBrain",createHashMap];
    if (count _brain > 0) then {
        _brain set ["cancelled",true];
        _brain set ["cancelReason","CORTEX_STOPPED"];
        _brain set ["wakeAt",time];
    };
    _x setVariable ["WAIT_GroupBrain_Generation",(_x getVariable ["WAIT_GroupBrain_Generation",0])+1];
    _x setVariable ["WAIT_GroupBrain",nil];
    _x setVariable ["WAIT_GroupBrain_FSM",nil];
    _x setVariable ["WAIT_Cortex_GroupJob",nil];
    private _buildingBrain=_x getVariable ["WAIT_BuildingBrain",createHashMap];
    if (count _buildingBrain > 0) then {
        _buildingBrain set ["cancelled",true];
        _buildingBrain set ["cancelReason","CORTEX_STOPPED"];
        _buildingBrain set ["completed",true];
    };
    _x setVariable ["WAIT_BuildingBrain",nil];
    _x setVariable ["WAIT_BuildingBrain_FSM",nil];
    if (local _x) then {_x setVariable ["WAIT_AIPass_AreaReport",nil,true]};
    if (local _x && {count (_x getVariable ["WAIT_AIPass_State", createHashMap]) > 0 || {_x getVariable ["WAIT_AIPass_Managed", false]} || {(_x getVariable ["WAIT_Cortex_Remount",[]]) isNotEqualTo []}
        || {(_x getVariable ["WAIT_AIPass_Defend",[]]) isNotEqualTo []}
        || {(_x getVariable ["WAIT_AIPass_Garrison",[]]) isNotEqualTo []}
        || {_x getVariable ["WAIT_AIPass_ClearBuilding",false]}}) then {
        [_x,true,"CORTEX_STOPPED"] call WAIT_fnc_CortexReleaseGroup;
    };
    if (local _x) then {
        [_x] call WAIT_fnc_CortexDefendRelease;
        [_x] call WAIT_fnc_CortexGarrisonRelease;
        [_x] call WAIT_fnc_CortexClearRelease;
    };
    {
        private _unit = _x;
        {_unit removeEventHandler _x} forEach (_unit getVariable ["WAIT_AIPass_GarrisonHandlerIds", []]);
        _unit setVariable ["WAIT_AIPass_GarrisonHandlerIds", nil];
        _unit setVariable ["WAIT_AIPass_GarrisonHandlers", nil];
        _unit setVariable ["WAIT_AIPass_DuckUntil", nil];
    } forEach units _x;
    private _localHandler = _x getVariable ["WAIT_AIPass_LocalHandler", -1];
    if (_localHandler >= 0) then {_x removeEventHandler ["Local", _localHandler]};
    _x setVariable ["WAIT_AIPass_LocalHandler", nil];
    _x setVariable ["WAIT_AIPass_Adopted", nil];
    _x setVariable ["WAIT_AIPass_Epoch", (_x getVariable ["WAIT_AIPass_Epoch", 0]) + 1];
} forEach allGroups;

private _jobs = (missionNamespace getVariable ["WAIT_AIPass_Jobs", []]) + (missionNamespace getVariable ["WAIT_AIPass_PendingJobs", []]);
{
    private _state=_x select 2;
    private _flareAircraft=_state getOrDefault ["aircraft",objNull];
    if (!isNull _flareAircraft) then {
        private _guidanceTarget=_flareAircraft getVariable ["WAIT_Cortex_AirAttackGuidanceTarget",objNull];
        if (!isNull _guidanceTarget) then {deleteVehicle _guidanceTarget};
        _flareAircraft setVariable ["WAIT_Cortex_AttackFlareJob",nil];
        _flareAircraft setVariable ["WAIT_Cortex_AirAttackJob",nil];
        _flareAircraft setVariable ["WAIT_Cortex_AirAttackToken",nil];
        _flareAircraft setVariable ["WAIT_Cortex_AirAttackTarget",nil];
        _flareAircraft setVariable ["WAIT_Cortex_AirAttackGuidedWeapon",nil];
        _flareAircraft setVariable ["WAIT_Cortex_AirAttackGuidanceTarget",nil];
        _flareAircraft setVariable ["WAIT_Cortex_AirAttackBlockedUntil",nil];
        private _airHandler=_state getOrDefault ["firedHandler",-1];
        if (_airHandler >= 0 && {local _flareAircraft}) then {_flareAircraft removeEventHandler ["Fired",_airHandler]};
        if (local _flareAircraft) then {
            // Negative limits can command helicopter reverse; restore the native positive default.
        _flareAircraft limitSpeed (2 * getNumber (configOf _flareAircraft >> "maxSpeed"));
            private _airGroup=group driver _flareAircraft;
            if (!isNull _airGroup) then {
                private _ownedWaypointName=_state getOrDefault ["ownedWaypointName",""];
                private _ownedWaypointIndex=(waypoints _airGroup) findIf {
                    _ownedWaypointName != "" && {waypointName _x == _ownedWaypointName}
                };
                if (_ownedWaypointIndex >= 0) then {
                    private _ownedWaypoint=(waypoints _airGroup) select _ownedWaypointIndex;
                    private _snapshot=_airGroup getVariable ["WAIT_Cortex_ZeusOrderSnapshot",[]];
                    private _hold=_airGroup getVariable ["WAIT_AIPass_ZeusHold",[]];
                    private _claimed=count _snapshot == 7 && {count _hold == 2}
                        && {(_snapshot select 0) == (_hold select 0)}
                        && {(_snapshot select 5) == (_ownedWaypoint select 1)};
                    if (_claimed) then {
                        _ownedWaypoint setWaypointName "";
                    } else {deleteWaypoint _ownedWaypoint};
                };
                _airGroup enableAttack (_state getOrDefault ["previousAttackEnabled",true]);
            };
        };
    };
    private _group = (_x select 2) getOrDefault ["group", grpNull];
    if (!isNull _group) then {
        // Shutdown clears only WAIT work. A curator, player or external controller can claim a
        // group between the broad release above and this delayed-job cleanup, so never use a
        // stale regroup/clear record to issue formation or behaviour commands over that owner.
        private _canRestoreGroup=local _group && {[_group,false,false,true] call WAIT_fnc_CortexIsEligible};
        if (_canRestoreGroup && {!isNull (_group getVariable ["WAIT_AIPass_RegroupHost", grpNull])}) then {
            {
                if (alive _x && {local _x}) then {_x doFollow leader _group};
            } forEach units _group;
        };
        _group setVariable ["WAIT_AIPass_Dropping", nil];
        if (_canRestoreGroup && {"team" in (_x select 2)} && {_group getVariable ["WAIT_AIPass_ClearBuilding", false]}) then {
            private _clearJob = _x select 2;
            {if (alive _x && {local _x}) then {_x doFollow leader _group}} forEach (_clearJob getOrDefault ["team", []]);
            if ("baseBehaviour" in _clearJob && {behaviour leader _group == "COMBAT"}) then {
                _group setBehaviour (_clearJob get "baseBehaviour");
            };
            _group setVariable ["WAIT_AIPass_ClearBuilding", nil, true];
            _group setVariable ["WAIT_AIPass_ClearOrder", nil, true];
            _group setVariable ["WAIT_AIPass_ClearApplied", nil];
        };
        _group setVariable ["WAIT_AIPass_GarrisonApplied", nil];
        _group setVariable ["WAIT_AIPass_DefendApplied", nil];
        private _aircraft = (_x select 2) getOrDefault ["aircraft", objNull];
        if (!isNull _aircraft) then {_aircraft setVariable ["WAIT_AIPass_DropUntil", nil]};
        _group setVariable ["WAIT_AIPass_RegroupQueued", nil];
        _group setVariable ["WAIT_AIPass_RegroupHost", nil];
    };
} forEach _jobs;
[] call WAIT_fnc_SchedulerReconcile;
missionNamespace setVariable ["WAIT_AIPass_DiscoveryQueued", false];
diag_log "[WAIT] Stopped.";

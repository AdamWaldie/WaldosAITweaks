/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Read-only on demand; does not install handlers or mutate JIP state.
 * Reports whether WAIT's AI profile is active and whether ordinary AI groups currently owned by
 * headless clients have acknowledged profile adoption and resumed their applicable WAIT work. Also reports the Cortex scheduler and
 * survivor-regroup counters, per-feature gates/tuning, coordinated support outcomes,
 * active drill heartbeats, durable transition/remount/support/combined-arms ownership, pending artillery
 * relocation, bounded action/order snapshots, detected external providers and queue health
 * for the server (headless-client private counters stay on those machines). This is independent of which scheduler moved
 * the groups: ACE Headless may be active while WAIT's optional HC distributor is disabled.
 *
 * Locality and authority:
 * Read-only and server-only. It compares engine HeadlessClient_F owners with current groupOwner and
 * authenticated adoption records. No state is changed or broadcast; repeat/JIP behaviour is not
 * applicable. The shared diagnostics runner publishes the resulting report normally.
 *
 * Arguments: None. On-demand snapshots cap groups/controllers at 20 and members at 8.
 * Return Value: HashMap - standalone AI diagnostic report for area "ai".
 *
 * Example:
 * [] call WAIT_fnc_AIGetDiagnostics;
 * Result: reports active profile/mode and any HC-owned groups lacking verified adoption.
 *
 * Current callers: mission diagnostics and the addon audit.
 */

if !(isServer) exitWith {["ai", []] call WAIT_fnc_AITweaksDiagnosticReport};
private _groups = allGroups;
private _enabled = missionNamespace getVariable ["WAIT_AIRebalance_Enable", true];
private _hcOwners = (entities "HeadlessClient_F") apply {owner _x};
private _hcGroups = _groups select {
    groupOwner _x in _hcOwners
    && {(units _x) findIf {isPlayer _x} < 0}
    && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
};
private _includedSides = missionNamespace getVariable ["WAIT_AI_IncludedSides", []];
private _includedSideKeys = (_includedSides select {_x isEqualType ""}) apply {toUpperANSI _x};
private _includedFactions = missionNamespace getVariable ["WAIT_AI_IncludedFactions", []];
private _excludedFactions = missionNamespace getVariable ["WAIT_AI_ExcludedFactions", []];
private _excludedClasses = missionNamespace getVariable ["WAIT_AI_ExcludedClasses", []];
private _eligibleAI = {
    params ["_unit"];
    private _sideKey = switch (side group _unit) do {
        case west: {"WEST"}; case east: {"EAST"}; case independent: {"GUER"}; default {"CIV"};
    };
    !isPlayer _unit
    && {!([_unit] call WAIT_fnc_CompatibilityExternalControl)}
    && {!(_unit getVariable ["WAIT_AI_Exclude", false])}
    && {count _includedSides == 0 || {_sideKey in _includedSideKeys}}
    && {count _includedFactions == 0 || {faction _unit in _includedFactions}}
    && {!(faction _unit in _excludedFactions)}
    && {!(typeOf _unit in _excludedClasses)}
    && {[_unit] call WAIT_fnc_CortexExternalOwner == ""}
};
// A group made entirely of specialist actors has no WAIT-managed unit to adopt. Leaving it in
// this set turns deliberate compatibility-only ownership into a false HC-adoption fault.
_hcGroups = _hcGroups select {
    ({[_x] call _eligibleAI} count units _x) > 0
};
private _missing = _hcGroups select {
    private _owner = groupOwner _x;
    private _aceResult = _x getVariable ["WAIT_AI_LastHeadlessAdoption", []];
    // The compatibility adapter validates the provider record before WAIT compares its restart state.
    private _companionResult = [_x, _owner] call WAIT_fnc_CompatibilityHeadlessRecord;
    private _eligibleCount = {_x call _eligibleAI} count units _x;
    private _aceValid = count _aceResult >= 2
        && {(_aceResult select 0) == _owner}
        && {(_aceResult select 1) >= _eligibleCount};
    private _companionValid = count _companionResult >= 4
        && {(_companionResult select 1) == _owner}
        && {_companionResult select 2}
        && {(!_enabled) || {(_companionResult select 3) >= _eligibleCount}};
    !(_aceValid || {_companionValid})
};
private _helicopters = (allMissionObjects "Helicopter") select {alive _x};
private _activeLanding = _helicopters select {_x getVariable ["WAIT_ImprovedHelicopterLanding_Active", false]};
private _orphanedMovementControl = _helicopters select {
    (_x getVariable ["WAIT_ImprovedHelicopterLanding_GroundAnchored", false])
    || {_x getVariable ["WAIT_ImprovedHelicopterLanding_Active", false]}
};
private _staleLanding = _helicopters select {
    _x getVariable ["WAIT_ImprovedHelicopterLanding_GroundAnchored", false]
    && {!(_x getVariable ["WAIT_ImprovedHelicopterLanding_Active", false])}
};
private _groupedLanding = _activeLanding select {
    private _aircraft = _x;
    private _pilot = currentPilot _aircraft;
    if (isNull _pilot) exitWith {false};
    private _aircraftInGroup = [];
    {
        private _vehicle = vehicle _x;
        if (_vehicle isKindOf "Helicopter") then {_aircraftInGroup pushBackUnique _vehicle};
    } forEach (units (group _pilot));
    count _aircraftInGroup > 1
};
private _decelerationEnabled = missionNamespace getVariable ["WAIT_HelicopterDeceleration_Enable", false];
private _decelerationAircraft = vehicles select {
    _x getVariable ["WAIT_HelicopterDeceleration_LocalHandlerInstalled", false]
};
private _decelerationActive = _decelerationAircraft select {
    _x getVariable ["WAIT_HelicopterDeceleration_Active", false]
};
private _decelerationLandingConflict = _decelerationActive select {
    _x getVariable ["WAIT_ImprovedHelicopterLanding_Active", false]
};
private _passEnabled = missionNamespace getVariable ["WAIT_AIPass_Enable", true];
private _passActive = missionNamespace getVariable ["WAIT_AIPass_Active", false];
private _passJobs = count (missionNamespace getVariable ["WAIT_AIPass_Jobs", []]) + count (missionNamespace getVariable ["WAIT_AIPass_PendingJobs", []]);
// The scheduler keeps these values on each queued operation already. Sample only twenty jobs here,
// on demand, so diagnostics expose backlog and stale progress without becoming a background scan.
private _schedulerQueue=(missionNamespace getVariable ["WAIT_AIPass_Jobs", []]) select [0,20];
private _schedulerCallbackMs=0;
private _schedulerLatency=0;
private _schedulerStaleProgress=0;
{
    _x params ["_dueAt","","_state"];
    _schedulerCallbackMs=_schedulerCallbackMs+(_state getOrDefault ["lastCallbackMs",0]);
    _schedulerLatency=_schedulerLatency max (_state getOrDefault ["queueLatency",0]);
    private _progressAt=_state getOrDefault ["lastProgressAt",_dueAt];
    if (time-_progressAt > 20) then {_schedulerStaleProgress=_schedulerStaleProgress+1};
} forEach _schedulerQueue;
private _externalActors=(allUnits select {alive _x}) apply {[_x,[_x] call WAIT_fnc_CortexExternalOwner]};
_externalActors=_externalActors select {(_x select 1) != ""};
private _movementLeases={_x getVariable ["WAIT_Cortex_MovementLease",[]] isNotEqualTo []} count _groups;
private _civilianActors=allUnits select {alive _x && {side group _x == civilian}
    && {primaryWeapon _x == ""} && {secondaryWeapon _x == ""} && {handgunWeapon _x == ""}};
private _civilianReactions={serverTime < (_x getVariable ["WAIT_Cortex_CivilianReactionUntil",0])} count _civilianActors;
private _passState = if (!_passEnabled) then {"DISABLED"} else {if (_passActive && {!isNil {missionNamespace getVariable "WAIT_AIPass_SchedulerHandle"}}) then {"ACTIVE"} else {"ERROR"}};
private _passHint = if (_passState == "ERROR") then {"WAIT_AIPass_Enable is true but the server scheduler is not running; check RPT for [WAIT] and that CBA is loaded."} else {""};
private _regroupEnabled = missionNamespace getVariable ["WAIT_AIPass_Regroup_Enable", true];
private _medicalEnabled = missionNamespace getVariable ["WAIT_AIPass_MedicalAssist_Enable", true];
private _medicalAidGroups = _groups select {(_x getVariable ["WAIT_Cortex_MedicalAid",[]]) isNotEqualTo []};
private _dangerFsmPaths=["SoldierWB","SoldierEB","SoldierGB"] apply {
    [_x,toLowerANSI getText (configFile >> "CfgVehicles" >> _x >> "fsmDanger")]
};
private _dangerFsmOwned=_dangerFsmPaths findIf {
    (_x select 1) find "\z\waldo_ai_tweaks\addons\infantry\fsm\danger.fsm" < 0
} < 0;
// Danger response contexts are public, bounded and short-lived. This on-demand diagnostic reads
// the existing group list only; it installs no handlers and adds no scheduler work.
private _dangerResponses=_groups select {
    private _response=_x getVariable ["WAIT_Danger_Response",[]];
    count _response == 5 && {time < (_response select 3)}
};
private _dangerResponseSummary=(_dangerResponses select [0,20]) apply {
    private _response=_x getVariable ["WAIT_Danger_Response",[]];
    private _action=_x getVariable ["WAIT_Danger_Action",[]];
    private _actionName=if (count _action >= 5 && {(_action select 4) == (_response select 4)} && {time < (_action select 3)}) then {_action select 0} else {"ASSESS"};
    format ["%1:%2/%3/%4s",groupId _x,_actionName,_response select 0,(((_response select 3)-time) max 0) toFixed 1]
};
private _dangerEngineEvents=0;
{_dangerEngineEvents=_dangerEngineEvents+(_x getVariable ["WAIT_Danger_EngineEvents",0])} forEach _groups;
private _dangerEngineSubmissions=0;
private _dangerEngineRecords=0;
private _dangerEngineReflexOnly=0;
private _dangerEngineBootstraps=0;
private _dangerEngineCoverMoves=0;
private _dangerEngineSmokeResponses=0;
private _dangerEngineRecycles=0;
private _dangerEngineBoundedEnds=0;
private _dangerEngineLastRecycleCycles=0;
private _dangerEngineModes=createHashMap;
private _dangerVehicleProfiles=createHashMap;
{
    private _stats=_x getVariable ["WAIT_Danger_EngineStats",createHashMap];
    _dangerEngineSubmissions=_dangerEngineSubmissions+(_stats getOrDefault ["submissions",0]);
    _dangerEngineRecords=_dangerEngineRecords+(_stats getOrDefault ["acceptedRecords",0]);
    _dangerEngineReflexOnly=_dangerEngineReflexOnly+(_stats getOrDefault ["reflexOnlyRecords",0]);
    _dangerEngineBootstraps=_dangerEngineBootstraps+(_stats getOrDefault ["bootstraps",0]);
    _dangerEngineCoverMoves=_dangerEngineCoverMoves+(_stats getOrDefault ["coverMoves",0]);
    _dangerEngineSmokeResponses=_dangerEngineSmokeResponses+(_stats getOrDefault ["smokeResponses",0]);
    _dangerEngineRecycles=_dangerEngineRecycles+(_stats getOrDefault ["recycles",0]);
    _dangerEngineBoundedEnds=_dangerEngineBoundedEnds+(_stats getOrDefault ["boundedRecycleEnds",0]);
    _dangerEngineLastRecycleCycles=_dangerEngineLastRecycleCycles max (_stats getOrDefault ["lastRecycleCycles",0]);
    private _modes=_stats getOrDefault ["modes",createHashMap];
    {
        _dangerEngineModes set [_x,(_dangerEngineModes getOrDefault [_x,0])+(_modes getOrDefault [_x,0])];
    } forEach (keys _modes);
    private _vehicleProfile=_stats getOrDefault ["lastVehicleProfile",""];
    if (_vehicleProfile != "") then {
        _dangerVehicleProfiles set [_vehicleProfile,(_dangerVehicleProfiles getOrDefault [_vehicleProfile,0])+1];
    };
} forEach _groups;
private _dangerEngineModeSummary=(keys _dangerEngineModes) apply {
    format ["%1=%2",_x,_dangerEngineModes getOrDefault [_x,0]]
};
private _dangerVehicleProfileSummary=(keys _dangerVehicleProfiles) apply {
    format ["%1=%2",_x,_dangerVehicleProfiles getOrDefault [_x,0]]
};
// Immediate stance leases are machine-local by design. Count only server-local actors during this
// requested snapshot; headless owners report their equivalent state through their own runtime log.
private _dangerStanceLeases={
    local _x && {alive _x} && {
        private _lease=_x getVariable ["WAIT_Danger_EngineStanceLease",[]];
        count _lease >= 3 && {time < (_lease select 2)}
    }
} count allUnits;
// Engine-confirmed contacts are local candidate records, never a public targeting channel. Show
// only their bounded group/count summary so an operator can diagnose a leader-in-cover contact
// handoff without exposing target identity or adding background work.
private _dangerObservedGroups=_groups select {
    private _contacts=_x getVariable ["WAIT_Danger_ObservedContacts",[]];
    _contacts findIf {
        _x isEqualType [] && {count _x in [2,3]} && {(_x select 0) isEqualType objNull}
            && {alive (_x select 0)} && {(_x select 1) > time}
    } >= 0
};
private _dangerObservedSummary=(_dangerObservedGroups select [0,20]) apply {
    private _contacts=_x getVariable ["WAIT_Danger_ObservedContacts",[]];
    private _live={
        _x isEqualType [] && {count _x in [2,3]} && {(_x select 0) isEqualType objNull}
            && {alive (_x select 0)} && {(_x select 1) > time}
    } count _contacts;
    format ["%1:%2",groupId _x,_live]
};
private _dangerConfirmedGroups=_groups select {
    private _contact=_x getVariable ["WAIT_Danger_Contact",[]];
    count _contact == 4
        && {(_contact select 0) isEqualType objNull}
        && {alive (_contact select 0)}
        && {(_contact select 2) > time}
        && {(_contact select 3) == (_x getVariable ["WAIT_Danger_Generation",-1])}
};
private _dangerConfirmedSummary=(_dangerConfirmedGroups select [0,20]) apply {
    private _contact=_x getVariable ["WAIT_Danger_Contact",[]];
    format ["%1/%2s",groupId _x,(((_contact select 2)-time) max 0) toFixed 1]
};
private _operatingCrew=allUnits select {
    !isPlayer _x && {vehicle _x != _x}
        && {toUpperANSI ((assignedVehicleRole _x) param [0,""]) != "CARGO"}
};
private _precisionExcludedCrew=_operatingCrew select {
    [_x] call WAIT_fnc_CompatibilityPrecisionExcluded
};
private _crewAimAdjusted={
    !isNil {_x getVariable "WAIT_AI_OriginalAimCoef"}
        && {abs (getCustomAimCoef _x - (_x getVariable ["WAIT_AI_OriginalAimCoef",getCustomAimCoef _x])) > 0.01}
} count _operatingCrew;
private _activeAirAttacks=vehicles select {(_x getVariable ["WAIT_Cortex_AirAttackPlan",[]]) isNotEqualTo []};
private _fireMissions=missionNamespace getVariable ["WAIT_AIPass_FireMissions",createHashMap];
private _dangerMortarMissions=values _fireMissions select {
    (_x getOrDefault ["purpose",""]) == "DANGER"
};
// Standalone driving and convoy driving deliberately have different owners. Keep this snapshot
// bounded and on-demand so diagnostics do not turn routine vehicle safety into a global worker.
private _drivingAssistVehicles=(vehicles select {
    private _state=_x getVariable ["WAIT_DrivingAssist_State",[]];
    local _x && {count _state >= 3} && {!(_x getVariable ["WAIT_Convoy_Active",false])}
}) select [0,20];
private _drivingAssistSnapshot=_drivingAssistVehicles apply {
    private _state=_x getVariable ["WAIT_DrivingAssist_State",[]];
    private _owner=_state param [3,grpNull,[grpNull]];
    private _capMps=_state param [0,-1];
    private _capKmh=if (_capMps < 0) then {-1} else {_capMps*3.6};
    format ["%1 capKmh=%2 grade=%3 owner=%4 age=%5 recovery=%6",typeOf _x,_capKmh toFixed 1,(_state param [1,0]) toFixed 2,[groupId _owner,"unknown"] select (isNull _owner),(time-(_state param [2,time])) max 0 toFixed 1,_state param [8,"IDLE"]]
};
private _unloadPolicyVehicles=vehicles select {count (_x getVariable ["WAIT_Cortex_UnloadPolicyLease",[]]) == 5};
private _unloadPolicyBlocked=vehicles select {count (_x getVariable ["WAIT_Cortex_UnloadPolicyBlocked",[]]) == 2};
private _unloadPolicyInvalid=_unloadPolicyVehicles select {
    private _lease=_x getVariable ["WAIT_Cortex_UnloadPolicyLease",[]];
    private _ownerGroup=_lease select 0;
    isNull _ownerGroup || {_x getVariable ["WAIT_Convoy_Active",false]}
        || {!((effectiveCommander _x) in units _ownerGroup)}
};
private _unloadPolicySnapshot=(_unloadPolicyVehicles select [0,20]) apply {
    private _lease=_x getVariable ["WAIT_Cortex_UnloadPolicyLease",[]];
    format ["%1 owner=%2 epoch=%3 locality=%4",typeOf _x,groupId (_lease select 0),_lease select 1,owner _x]
};
private _convoyRegistry=missionNamespace getVariable ["WAIT_Convoy_Registry",[]];
private _convoyGroups=_convoyRegistry apply {_x select 0};
private _convoyVehicles=[];
{_convoyVehicles append (((_x select 1) param [4,[]]) select {!isNull _x})} forEach _convoyRegistry;
private _convoyRecoveries=0;
{_convoyRecoveries=_convoyRecoveries+(_x getVariable ["WAIT_Convoy_RouteRecoveries",0])} forEach _convoyGroups;
private _convoyBrains=(_convoyGroups select {local _x && {count (_x getVariable ["WAIT_Convoy_Brain",createHashMap]) > 0}}) select [0,20];
private _convoyBrainSnapshot=_convoyBrains apply {
    private _brain=_x getVariable ["WAIT_Convoy_Brain",createHashMap];
    format ["%1 phase=%2 revision=%3 registry=%4 pending=%5 spacingPairs=%6 recoveryActors=%7 age=%8 schedulerWatchdogs=%9 cancel=%10",
        groupId _x,_brain getOrDefault ["phase","UNKNOWN"],(_brain getOrDefault ["configuration",[]]) param [0,-1],
        _brain getOrDefault ["registryRevision",-1],_brain getOrDefault ["pending",false],
        _brain getOrDefault ["spacingPairs",0],_brain getOrDefault ["recoveryActors",0],
        ((time-(_brain getOrDefault ["lastStepAt",time])) max 0) toFixed 1,_brain getOrDefault ["watchdogCount",0],_brain getOrDefault ["cancelReason",""]]
};
// A convoy needs its own local scheduler restart after a compatible transfer. Compare the
// validated adoption record with the companion restart record, rather than treating owner
// change alone as proof that spacing/passenger maintenance resumed.
private _convoyHandoffMissing=_convoyGroups select {
    private _companion=[_x,groupOwner _x] call WAIT_fnc_CompatibilityHeadlessRecord;
    private _wait=_x getVariable ["WAIT_Convoy_LastHeadlessAdoption",[]];
    count _companion >= 3
    && {(_companion select 1) == groupOwner _x}
    && {_companion select 2}
    && {(count _wait < 2) || {(_wait select 1) != groupOwner _x}}
};
private _navalGroups=_groups select {(_x getVariable ["WAIT_Cortex_NavalStatus",[]]) isNotEqualTo []};
private _checks = [
    ["ai", "cortex", _passState, format ["enabled=%1 serverActive=%2 serverJobs=%3 paused=%4 includedSides=%5. %6", _passEnabled, _passActive, _passJobs, [] call WAIT_fnc_CortexIsPaused, missionNamespace getVariable ["WAIT_AIPass_IncludedSides", []], _passHint]],
    ["ai", "cortex-scheduler", if (!_passEnabled) then {"DISABLED"} else {"LOADED"}, format ["sampledJobs=%1 callbackMs=%2 maxQueueLatency=%3 staleProgress=%4",count _schedulerQueue,_schedulerCallbackMs toFixed 3,_schedulerLatency toFixed 2,_schedulerStaleProgress]],
    ["ai", "cortex-regroup", if (_passEnabled && {_regroupEnabled}) then {"LOADED"} else {"DISABLED"}, format ["enabled=%1 serverRegroupsCompleted=%2 serverUnitsJoined=%3", _regroupEnabled, missionNamespace getVariable ["WAIT_AIPass_RegroupsCompleted", 0], missionNamespace getVariable ["WAIT_AIPass_RegroupJoined", 0]]],
    ["ai", "cortex-medical", if (!_passEnabled || {!_medicalEnabled}) then {"DISABLED"} else {if (_medicalAidGroups isEqualTo []) then {"LOADED"} else {"ACTIVE"}}, format ["enabled=%1 activeAidGroups=%2 completed=%3. WAIT owns ordinary medical assistance and issues one bounded native treatment command during CALM or SECURITY; combat, Zeus, a direct order or specialist ownership cancels it without changing health.",_medicalEnabled,count _medicalAidGroups,missionNamespace getVariable ["WAIT_AIPass_MedicalAssists",0]]],
    ["ai", "cortex-groups", if (!_passEnabled) then {"DISABLED"} else {"LOADED"}, format ["serverManaged=%1 inContact=%2 retreating=%3 garrisons=%4 flanksCompleted=%5 retreats=%6 surrenders=%7 reinforcementsSent=%8 grenadeReactions=%9",
        {local _x && {_x getVariable ["WAIT_AIPass_Managed", false]}} count _groups,
        {local _x && {((_x getVariable ["WAIT_AIPass_State", createHashMap]) getOrDefault ["phase", ""]) == "CONTACT"}} count _groups,
        {local _x && {((_x getVariable ["WAIT_AIPass_State", createHashMap]) getOrDefault ["phase", ""]) == "RETREAT"}} count _groups,
        {(_x getVariable ["WAIT_AIPass_Garrison", []]) isNotEqualTo []} count _groups,
        missionNamespace getVariable ["WAIT_AIPass_FlanksCompleted", 0], missionNamespace getVariable ["WAIT_AIPass_Retreats", 0],
        missionNamespace getVariable ["WAIT_AIPass_Surrenders", 0], missionNamespace getVariable ["WAIT_AIPass_ReinforcementsSent", 0],
        missionNamespace getVariable ["WAIT_AIPass_GrenadeReactions", 0]]],
    ["ai", "cortex-drills", if (!_passEnabled) then {"DISABLED"} else {"LOADED"}, format ["assaults=%1 advances=%2 investigations=%3 coordinatedAssaults=%4 magazinesShared=%5 defences=%6",
        missionNamespace getVariable ["WAIT_AIPass_Assaults", 0], missionNamespace getVariable ["WAIT_AIPass_AdvancesCompleted", 0],
        missionNamespace getVariable ["WAIT_AIPass_Investigations", 0], missionNamespace getVariable ["WAIT_AIPass_CoordinatedAssaults", 0],
        missionNamespace getVariable ["WAIT_AIPass_MagazinesShared", 0],
        {(_x getVariable ["WAIT_AIPass_Defend", []]) isNotEqualTo []} count _groups]],
    ["ai", "cortex-zeus", if (!_passEnabled) then {"DISABLED"} else {"LOADED"}, format ["heldByZeus=%1 zeusWaypointGroups=%2 excluded=%3 holdSeconds=%4",
        {local _x && {time < (_x getVariable ["WAIT_AIPass_ZeusLocalUntil",-1]) || {_x getVariable ["WAIT_AIPass_ZeusWaypoints",false]}}} count _groups,
        {_x getVariable ["WAIT_AIPass_ZeusWaypoints", false]} count _groups,
        {_x getVariable ["WAIT_AIPass_Exclude", false]} count _groups,
        missionNamespace getVariable ["WAIT_AIPass_ZeusHoldSeconds", 120]]],
    ["ai", "cortex-support", if (!_passEnabled) then {"DISABLED"} else {"LOADED"}, format ["artillery=%1 counterBattery=%2 serverBatteries=%3 missions=%4 dangerMortarMissions=%12 radars=%5 airborne=%6 drops=%7 reactiveFlares=%8 attackRunFlares=%9 adaptiveAirAttacks=%10 activeAirAttacks=%11",
        missionNamespace getVariable ["WAIT_AIPass_Artillery_Enable", false], missionNamespace getVariable ["WAIT_AIPass_CounterBattery_Enable", false],
        count (missionNamespace getVariable ["WAIT_AIPass_LocalArtillery", []]), missionNamespace getVariable ["WAIT_AIPass_ArtilleryMissions", 0],
        count (missionNamespace getVariable ["WAIT_AIPass_CounterBatteryRadars", []]), missionNamespace getVariable ["WAIT_AIPass_Airborne_Enable", false],
        missionNamespace getVariable ["WAIT_AIPass_AirborneDrops", 0],
        missionNamespace getVariable ["WAIT_AIPass_AircraftFlares_Enable", true],
        missionNamespace getVariable ["WAIT_Cortex_AttackRunFlares_Enable", true],
        missionNamespace getVariable ["WAIT_Cortex_AirAttack_Enable", true],count _activeAirAttacks,count _dangerMortarMissions]],
    ["ai", "cortex-tuning", if (!_passEnabled) then {"DISABLED"} else {"LOADED"}, format ["profile=%1 aggression=%2 cohesion=%3 reaction=%4 artilleryRole=%5 counterBatteryMode=%6",
        [missionNamespace getVariable ["WAIT_AIPass_BehaviourProfile", ""], "FOLLOW"] select ((missionNamespace getVariable ["WAIT_AIPass_BehaviourProfile", ""]) == ""),
        missionNamespace getVariable ["WAIT_AIPass_Aggression", 1.2], missionNamespace getVariable ["WAIT_AIPass_Cohesion", 1],
        missionNamespace getVariable ["WAIT_AIPass_ReactionSpeed", 1], missionNamespace getVariable ["WAIT_AIPass_Artillery_DefaultRole", "BOTH"],
        missionNamespace getVariable ["WAIT_AIPass_CounterBattery_Mode", "AUTO"]]],
    ["ai","danger-assessment",if (!_passEnabled || {!(missionNamespace getVariable ["WAIT_AIPass_Danger_Enable",true])}) then {"DISABLED"} else {"LOADED"},format ["The configured engine danger FSM exits without issuing WAIT commands while the runtime or danger feature is disabled. When enabled, tactical handoff drains at most 12 native records per step and maps relevant observations into a 16-record expiring group queue; new native records accumulate until the finite response ends unless saturation requires early re-evaluation. Close hostile foot contact and effective-command vehicle contact receive bounded, revalidated follow-up samples without movement or target commands. Infantry admits at most two follow-ups and vehicle command at most three before handing continuing contact back to native AI and the group brain. Same-cause callbacks throttle to 0.25 s and wake the existing group job at most twice per second. Fresh native sightings then retain contact cadence after the short callback expires, using the same bounded group job rather than another worker. Engine events=%1 submissions=%2 acceptedRecords=%3 reflexOnlyRecords=%4 first-contactBootstraps=%5 finiteCoverMoves=%6 responseRecycles=%7 boundedRecycleEnds=%18 lastRecycleCycles=%19 modes=[%8]; mounted domains=[%16]; published responses=%9 [action/cause/remaining: %10]; local observed contacts=%11 [group/count: %12]; confirmed handoffs=%13 [group/remaining: %14]; server-local stance leases=%15; finiteSmokeResponses=%17. Mounted danger is classified as air, artillery, static, armoured, armed or transport before handoff; aircraft, batteries and static weapons stay with their dedicated owner, while only eligible transport/fighting-vehicle passengers receive the bounded safe-dismount path. Friendly near-fire can produce a short local reflex but cannot create group CONTACT; engage causes require a live hostile source. Boarding, action, healing, rearm, join, fleeing and vehicle owners receive no posture or movement command. Native ATTACK remains eligible because it is also Arma's ordinary autonomous combat command; WAIT leaves native targeting and movement intact. Immediate stances are weak, finite and exact-owned; committed operation movers are never forced prone. An idle authored STEALTH element under BLUE/GREEN may take one weak finite low-profile stance without gaining movement or fire authority. Casualty and scream evidence remains a mobile local alert: it cannot change group behaviour or ROE, enter CONTACT or authorise a cover move without separate hostile knowledge. The exact living local soldier selected by the native event receives the one bounded physical cover attempt after hit, explosion or suppression; only a stale or unavailable observer falls back safely. Severe incoming danger may queue one carried smoke screen per generation and cooldown; the operation never waits for the throw, and the next-frame release rechecks the feature, generation and external owner. Any current command, operation or newer owner blocks cover movement. No target reveal or second persistent movement owner. Physical/latency and mixed-group performance acceptance pending.",_dangerEngineEvents,_dangerEngineSubmissions,_dangerEngineRecords,_dangerEngineReflexOnly,_dangerEngineBootstraps,_dangerEngineCoverMoves,_dangerEngineRecycles,_dangerEngineModeSummary joinString ",",count _dangerResponses,_dangerResponseSummary joinString ",",count _dangerObservedGroups,_dangerObservedSummary joinString ",",count _dangerConfirmedGroups,_dangerConfirmedSummary joinString ",",_dangerStanceLeases,_dangerVehicleProfileSummary joinString ",",_dangerEngineSmokeResponses,_dangerEngineBoundedEnds,_dangerEngineLastRecycleCycles]],
    ["ai","cortex-danger-ownership",["ERROR","ACTIVE"] select _dangerFsmOwned,format ["exclusiveEngineFSM=%1 basePaths=%2. WAIT must own all west, east and independent soldier danger slots. It owns immediate danger response and submits expensive group planning to the shared scheduler; another fsmDanger replacement is unsupported.",_dangerFsmOwned,_dangerFsmPaths]],
    ["ai","cortex-compatibility","LOADED",format ["movementLeases=%1 meleeBackendLoaded=%2 specialistBackendLoaded=%3 externallyOwnedActors=%4 reasons=%5. WAIT owns ordinary AI domains; specialist and active melee actors are excluded without changing external state.",_movementLeases,missionNamespace getVariable ["WAIT_AIPass_MeleeBackendLoaded",false],missionNamespace getVariable ["WAIT_AIPass_SpecialistBackendLoaded",false],count _externalActors,_externalActors apply {_x select 1}]],
    ["ai","general-driving",if !(missionNamespace getVariable ["WAIT_AIPass_DrivingAssist_Enable",true]) then {"DISABLED"} else {if (_drivingAssistVehicles isEqualTo []) then {"LOADED"} else {"ACTIVE"}},format ["serverLocalOrdinaryVehicles=%1 samples=[%2]. Applies terrain-grade safety only while a native waypoint is active; a non-combat vehicle receives at most one route refresh, clear-rear reverse and final route retry. Registered convoys are excluded and reported separately. Snapshot caps at 20 server-local vehicles; each state includes cap in km/h, grade, owner group, sample age and recovery state. Headless owners retain local state without repeated network publication.",count _drivingAssistVehicles,_drivingAssistSnapshot joinString "; "]],
    ["ai","vehicle-passenger-ownership",if (_unloadPolicyInvalid isNotEqualTo []) then {"ERROR"} else {if (_unloadPolicyVehicles isEqualTo []) then {"LOADED"} else {"ACTIVE"}},format ["ordinaryUnloadLeases=%1 blockedExternalMutations=%2 invalidLeases=%3 samples=[%4]. Each lease belongs to the exact effective-command group and vehicle epoch, is separate from convoy control and restores only an unchanged WAIT-applied value. The snapshot is on-demand and capped at 20 vehicles.",count _unloadPolicyVehicles,count _unloadPolicyBlocked,count _unloadPolicyInvalid,_unloadPolicySnapshot joinString "; "]],
    ["ai","convoy-driving",if (_convoyHandoffMissing isNotEqualTo []) then {"ERROR"} else {if (_convoyRegistry isEqualTo []) then {"LOADED"} else {"ACTIVE"}},format ["controlledGroups=%1 vehicles=%2 drivingAssist=%3 routeRecoveryEnabled=%4 recoveries=%5 missingHeadlessRestart=%6 brains=[%7]. WAIT owns eligible convoy movement through one finite owner-local brain exposing cruise, spacing, contact, recovery, ordered hold, obstruction and arrival. Physical control remains one bounded shared-scheduler step; WAIT never teleports, repairs or ignores a physical roadblock.",count _convoyGroups,count _convoyVehicles,missionNamespace getVariable ["WAIT_Convoy_DrivingAssist_Enable",true],missionNamespace getVariable ["WAIT_Convoy_RouteRecovery_Enable",true],_convoyRecoveries,count _convoyHandoffMissing,_convoyBrainSnapshot joinString "; "]],
    ["ai","cortex-naval",if !(missionNamespace getVariable ["WAIT_AIPass_NavalAssault_Enable",true]) then {"DISABLED"} else {if (_navalGroups isEqualTo []) then {"LOADED"} else {"ACTIVE"}},format ["enabled=%1 activeGroups=%2 statuses=%3. WAIT owns eligible naval delivery through the shared scheduler, a bounded shore comparison and one finite native approach; Zeus, player and neutral external-control ownership still take precedence.",missionNamespace getVariable ["WAIT_AIPass_NavalAssault_Enable",true],count _navalGroups,_navalGroups apply {_x getVariable ["WAIT_Cortex_NavalStatus",[]]}]],
    ["ai","cortex-civilian-reactions",if !(missionNamespace getVariable ["WAIT_AIPass_CivilianReaction_Enable",true]) then {"DISABLED"} else {"LOADED"},format ["eligibleUnarmedCivilians=%1 reactingNow=%2 radius=%3 distance=%4 cooldown=%5. FiredNear, Explosion and Hit events create one priority-aware finite escape on the shared scheduler. Stronger danger may replace a weaker active route; duplicate noise cannot churn it. One stalled route retry is allowed. Player, Zeus and neutral external-control ownership still take precedence.",count _civilianActors,_civilianReactions,missionNamespace getVariable ["WAIT_AIPass_CivilianReaction_Radius",45],missionNamespace getVariable ["WAIT_AIPass_CivilianReaction_Distance",180],missionNamespace getVariable ["WAIT_AIPass_CivilianReaction_Cooldown",20]]],
    ["ai", "ai-profile", if (_enabled) then {"ACTIVE"} else {"DISABLED"}, format ["profile=%1 mode=%2 serverActive=%3", missionNamespace getVariable ["WAIT_AIRebalance_Profile", "LINE"], missionNamespace getVariable ["WAIT_AIRebalance_Mode", "AUTO"], missionNamespace getVariable ["WAIT_AI_RebalanceActive", false]]],
    ["ai", "ai-weapon-dispersion", if (!_enabled) then {"DISABLED"} else {"ACTIVE"}, format ["operatingCrew=%1 precisionExcluded=%2 infantry=%3 crewSkillMultiplier=%4 groundVehicle=%5 aircraft=%6 locallyAdjusted=%7. WAIT applies the script coefficient only to eligible AI; the neutral precision-exclusion contract prevents stacking with independently owned weapon systems.",count _operatingCrew,count _precisionExcludedCrew,missionNamespace getVariable ["WAIT_AI_InfantryDispersion",1.35],missionNamespace getVariable ["WAIT_AI_VehicleCrewAimMultiplier",0.6],missionNamespace getVariable ["WAIT_AI_VehicleCrewDispersion",3.5],missionNamespace getVariable ["WAIT_AI_AirCrewDispersion",4.25],_crewAimAdjusted]],
    ["ai", "ai-headless-adoption", if (!_enabled) then {"DISABLED"} else {if (_missing isNotEqualTo [] || {_convoyHandoffMissing isNotEqualTo []}) then {"ERROR"} else {if (_hcGroups isNotEqualTo []) then {"ACTIVE"} else {"UNCONFIGURED"}}}, format ["connectedHCs=%1 hcOwnedGroups=%2 missingVerifiedAdoption=%3 activeConvoysMissingCompatibilityRestart=%4", count _hcOwners, count _hcGroups, count _missing, count _convoyHandoffMissing]],
    ["ai", "improved-helicopter-landing", if !(missionNamespace getVariable ["WAIT_ImprovedHelicopterLanding_Enable", true]) then {"DISABLED"} else {if (count _staleLanding > 0 || {count _groupedLanding > 0}) then {"ERROR"} else {if (count _activeLanding > 0) then {"ACTIVE"} else {"LOADED"}}}, format ["helicopters=%1 movementOwned=%2 activeControllers=%3 staleGroundAnchors=%4 groupedControllers=%5", count _helicopters, count _orphanedMovementControl, count _activeLanding, count _staleLanding, count _groupedLanding]],
    ["ai", "helicopter-deceleration", if (!_decelerationEnabled) then {"DISABLED"} else {if (count _decelerationLandingConflict > 0) then {"ERROR"} else {"ACTIVE"}}, format ["enabled=%1 tracked=%2 activelyCorrecting=%3 landingConflicts=%4 includeVTOL=%5", _decelerationEnabled, count _decelerationAircraft, count _decelerationActive, count _decelerationLandingConflict, missionNamespace getVariable ["WAIT_HelicopterDeceleration_IncludeVTOL", false]]]
];
// Shared tuning metadata supplies current values and defaults; feature notes explain execution prerequisites.
// Build diagnostics from the same canonical key set used by Cortex Control. This keeps a stale
// mission extension from showing the same setting, gate and trigger explanation more than once.
private _tuningSpec=[];
private _seenTuningKeys=createHashMap;
{
    private _key=_x param [0,"",[""]];
    if (_key != "" && {!(_seenTuningKeys getOrDefault [_key,false])}) then {
        _seenTuningKeys set [_key,true];
        _tuningSpec pushBack _x;
    };
} forEach ([] call WAIT_fnc_CortexTuningSpec);
private _featureNotes=createHashMapFromArray [
    ["Regroup","Requires casualty survivors and a compatible nearby host; inspect living leader, travel before merge, and replacement-order ownership."],
    ["Contact","Uses natural engine knowledge. Check last-seen age and group phase; known enemies are not necessarily visible."],
    ["PostContact","Requires lost contact; inspect phase age, search members and return to the authored route."],
    ["Flank","Requires eligible contact and a viable movement element. Inspect drill stage/bound, covering roles and actual commands; elapsed time alone is not a stall."],
    ["StreetCrossing","Requires a manoeuvre crossing an engine road; inspect approach/crossing stages, smoke inventory and far-side travel."],
    ["FireControl","Requires known threats and permitted ROE. Ordered suppression alternates within a squad and uses a short random delay per squad; assigned targets are not shots. Check BLUE mode, ammunition and friendly obstruction."],
    ["Morale","Uses casualties, pressure and leader state; inspect morale value/state and physical retreat, not only RETREAT phase."],
    ["Surrender","Requires broken isolated survivors and surrender enabled; check captive state and real weapon removal. ACE captivity is optional."],
    ["GrenadeEvasion","Requires a qualifying live projectile and eligible observer. Check projectile handler, movement ownership and evasion release."],
    ["AntiArmour","Requires a known armoured threat, capable launcher/ammunition and clear backblast; targeting alone does not prove firing."],
    ["Vehicles","Inspect crew versus passengers, vehicle mobility and contact. Separate cargo squads retain their own order authority."],
    ["ContactReports","Requires a deliverable report; jamming/voice range and freshness can prevent delivery. A radio inventory item is not required."],
    ["Reinforce","Requires an eligible idle helper and a report/request; inspect reservation, responding state and physical approach."],
    ["Artillery","Requires an explicitly assigned spotter and eligible same-side battery with range/ammunition. Inspect fire mission phase, warning and confirmed shots."],
    ["CounterBattery","Requires an enemy artillery emission and eligible counter-role battery. Radar shortens delay but is not required; inspect pending/uncertain missions and friendly clearance."],
    ["Airborne","Requires eligible passengers in a suitable flying aircraft; inspect altitude, chute configuration, operating crew and post-landing orders."],
    ["AttackRunFlares","Assigned hostile target, airborne speed at least 40 km/h, closing within 1500 m then opening past closest approach. Two requests per leg; inspect actual countermeasure fire and finite ammunition. Phase is intent, not proof of release."],
    ["AirAttack","Requires a moving airborne AI aircraft, hostile assigned target and attack ROE. Inspect pattern/stage, observed AA, physical ingress/egress, real weapon fire, clearance, outcome and Zeus handover."],
    ["AircraftFlares","Applies to eligible AI aircraft under missile threat; inspect countermeasure ammunition and actual Fired events."],
    ["Investigate","Requires a known uncertain area; inspect area source, search team and actual travel without revealing hidden targets."],
    ["Assault","Requires a viable approach transition; inspect assault/frag/clear/consolidate stages. Live frag clearance must precede movement."],
    ["Advance","Requires a contact manoeuvre and viable fire teams; inspect team roles, successive bounds, stragglers and physical forward progress."],
    ["CoordinatedAssault","Requires supporting squads and a valid lease; inspect role sequence, rally areas, readiness and moving/covering elements."],
    ["Stance","Only eligible stationary actors should take cover stances; inspect applied stance and firing clearance. Movers must retain movement."],
    ["AmmoShare","Requires compatible spare magazines, a needy recipient and range; compare real inventories and conserved rounds, not a transfer counter."],
    ["VehicleGunnery","Requires an armed crew and permitted ROE; inspect actual target priority, ammunition and AT separation."],
    ["ArtillerySmoke","Requires artillery support and a valid retreat requester; smoke missions must not receive lethal red warning smoke."],
    ["AircraftBreak","Applies to eligible AI aircraft; inspect missile response, ground clearance and return to route."],
    ["VehicleDismount","Requires vehicle drills and a safely stopped vehicle on dry ground; unload passengers, retain operating crew."],
    ["VehicleRemount","Requires owned dismount intent and safe reboarding; a new Zeus order must cancel old remount intent."],
    ["VehicleWithdraw","Requires a damaged mobile vehicle and vehicle drills; inspect actual increased separation, existing smoke and retained crew."],
    ["CoverValidation","Checks candidate slope and body clearance; a valid cover candidate is not physical arrival or a usable firing position."],
    ["Hearing","Requires an installed local hearing handler and a real nearby shot; records an uncertain area, not target revelation."],
    ["MountedFire","Convoy weapon crew engage within existing ROE; cargo and crew roles must remain distinct."],
    ["Cover","Convoy passengers move clear after dismount; inspect threat-relative positions and newer squad orders."],
    ["AvoidInfantry","Requires a convoy and a friendly pedestrian in its driving corridor; inspect yielding, clearance and resumed travel."],
    ["ContactHalt","Requires convoy contact/pinning; inspect halt reason. Player roadblocks must remain effective; no teleport recovery."],
    ["Unload","Requires a convoy halt/arrival with cargo; inspect actual passenger exits and operating crew retention."]
];
private _dependencies=createHashMapFromArray [
    ["AttackRunFlares",["WAIT_AIPass_Enable"]],
    ["Surrender",["WAIT_AIPass_Morale_Enable"]],
    ["ArtillerySmoke",["WAIT_AIPass_Artillery_Enable"]],
    ["VehicleDismount",["WAIT_AIPass_Vehicles_Enable"]],
    ["VehicleRemount",["WAIT_AIPass_Vehicles_Enable"]],
    ["VehicleWithdraw",["WAIT_AIPass_Vehicles_Enable"]]
];
{
    _x params ["_key","_label","","_kind","","_default"];
    if (_kind == "CHECKBOX") then {
        private _value=missionNamespace getVariable [_key,_default];
        private _parts=_key splitString "_";
        private _name=_parts param [2,""];
        private _parents=+(_dependencies getOrDefault [_name,[]]);
        if (_key find "WAIT_AIPass_" == 0 && {_key != "WAIT_AIPass_Enable"} && {_name != "CoverValidation"}) then {_parents pushBackUnique "WAIT_AIPass_Enable"};
        private _parentValues=_parents apply {[_x,missionNamespace getVariable [_x,false]]};
        private _blockedParents=_parentValues select {!(_x select 1)};
        private _prefix=(_parts select [0,3]) joinString "_";
        private _related=(_tuningSpec select {(_x select 0) find (_prefix+"_") == 0 && {(_x select 3) != "CHECKBOX"}}) apply {[_x select 1,missionNamespace getVariable [_x select 0,_x select 5],_x select 5]};
        private _scope=if (_key find "WAIT_Convoy_" == 0) then {"Convoy owner; independent of Cortex master. Registry rows below."} else {"Owner-local execution; server counters do not include HC-private activity. Master, pause, group exclusions and compatibility can prevent automatic actions."};
        private _status=if (!_value) then {"DISABLED"} else {if (_blockedParents isNotEqualTo []) then {"UNCONFIGURED"} else {"LOADED"}};
        _checks pushBack ["ai","cortex-setting-"+_key,_status,format ["%1: selected=%2 default=%3; prerequisites=%4; related tuning [label,current,default]=%5. %6 Expected evidence: %7 A selected switch only permits the feature; it is not an action trigger or success result.",_label,_value,_default,_parentValues,_related,_scope,_featureNotes getOrDefault [_name,"Inspect the corresponding controller/profile rows; no dedicated activity counter is available for this option."]]];
    };
} forEach _tuningSpec;
// Queue health is measured locally once per requested report, without executing or rescheduling jobs.
private _queue=+(missionNamespace getVariable ["WAIT_AIPass_Jobs",[]]);
_queue append (missionNamespace getVariable ["WAIT_AIPass_PendingJobs",[]]);
private _overdue=0;
private _oldest=0;
private _staleOwners=0;
private _keyedJobs=0;
private _earliestQueued=-1;
private _maxCallbackMs=0;
private _maxRecordedLatency=0;
private _skippedJobs=0;
private _skipReasons=createHashMap;
private _aircraftJobs=0;
private _landingObserverJobs=0;
private _decelerationObserverJobs=0;
private _aircraftOverdue=0;
private _aircraftOldest=0;
private _aircraftMaxCallbackMs=0;
private _aircraftMaxLatency=0;
{
    _x params ["_due","","_jobState"];
    if (_earliestQueued < 0 || {_due < _earliestQueued}) then {_earliestQueued=_due};
    if (_due < time) then {_overdue=_overdue+1; _oldest=_oldest max (time-_due)};
    if ((_jobState getOrDefault ["jobKey",""]) != "") then {_keyedJobs=_keyedJobs+1};
    _maxCallbackMs=_maxCallbackMs max (_jobState getOrDefault ["lastCallbackMs",0]);
    _maxRecordedLatency=_maxRecordedLatency max (_jobState getOrDefault ["queueLatency",0]);
    private _skipReason=_jobState getOrDefault ["skippedReason",""];
    if (_skipReason != "") then {
        _skippedJobs=_skippedJobs+1;
        _skipReasons set [_skipReason,(_skipReasons getOrDefault [_skipReason,0])+1];
    };
    private _jobGroup=_jobState getOrDefault ["group",grpNull];
    if (!isNull _jobGroup && {!local _jobGroup || {(_jobState getOrDefault ["ownerEpoch",-1]) != (_jobGroup getVariable ["WAIT_AIPass_Epoch",0])}}) then {_staleOwners=_staleOwners+1};
    if ((_jobState getOrDefault ["subsystem",""]) == "AIRCRAFT") then {
        _aircraftJobs=_aircraftJobs+1;
        private _aircraftKey=_jobState getOrDefault ["jobKey",""];
        if (_aircraftKey find "WAIT_LANDING_" == 0) then {_landingObserverJobs=_landingObserverJobs+1};
        if (_aircraftKey find "WAIT_DECEL_" == 0) then {_decelerationObserverJobs=_decelerationObserverJobs+1};
        if (_due < time) then {
            _aircraftOverdue=_aircraftOverdue+1;
            _aircraftOldest=_aircraftOldest max (time-_due);
        };
        _aircraftMaxCallbackMs=_aircraftMaxCallbackMs max (_jobState getOrDefault ["lastCallbackMs",0]);
        _aircraftMaxLatency=_aircraftMaxLatency max (_jobState getOrDefault ["queueLatency",0]);
    };
} forEach _queue;
private _cachedNextDue=missionNamespace getVariable ["WAIT_AIPass_NextJobDue",-1];
private _cacheConsistent=(_queue isEqualTo [] && {_cachedNextDue < 0})
    || {_queue isNotEqualTo [] && {_cachedNextDue >= 0} && {_cachedNextDue <= (_earliestQueued+0.001)}};
private _queueState=if (_cacheConsistent) then {"LOADED"} else {"ERROR"};
private _queueHint=if (_cacheConsistent) then {
    "Due jobs and stale jobs may await the next scheduler tick; repeat the report before diagnosing starvation."
} else {
    "The scheduler deadline cache is missing or later than the earliest queued job. Restart Cortex or inspect queue mutation paths before trusting idle scheduling."
};
_checks pushBack ["ai","cortex-queue-health",_queueState,format ["serverJobs=%1 keyedJobs=%2 dueNow=%3 oldestDueSeconds=%4 staleOwnerJobs=%5 cachedNextDueSeconds=%6 earliestQueuedDueSeconds=%7 deadlineCacheConsistent=%8 fps=%9 budgetMs=%10 paused=%11 maxCallbackMs=%12 maxRecordedQueueLatencySeconds=%13 skippedJobs=%14 skipReasons=%15. %16",count _queue,_keyedJobs,_overdue,_oldest,_staleOwners,if (_cachedNextDue < 0) then {-1} else {_cachedNextDue-time},if (_earliestQueued < 0) then {-1} else {_earliestQueued-time},_cacheConsistent,diag_fps,missionNamespace getVariable ["WAIT_AIPass_TickBudgetMs",1],[] call WAIT_fnc_CortexIsPaused,_maxCallbackMs,_maxRecordedLatency,_skippedJobs,_skipReasons,_queueHint]];
private _aircraftQueueState=if (_aircraftOverdue > 0 && {_aircraftOldest > 5}) then {"ERROR"} else {if (_aircraftJobs > 0) then {"ACTIVE"} else {"LOADED"}};
_checks pushBack ["ai","aircraft-scheduler-health",_aircraftQueueState,format ["serverLocalJobs=%1 landingObservers=%2 decelerationObservers=%3 dueNow=%4 oldestDueSeconds=%5 maxCallbackMs=%6 maxRecordedQueueLatencySeconds=%7 schedulerActive=%8 landingSchedulerActive=%9 decelerationSchedulerActive=%10. This owner-local snapshot excludes aircraft currently owned by clients or headless clients; repeat it on the affected owner before diagnosing a missing observer.",_aircraftJobs,_landingObserverJobs,_decelerationObserverJobs,_aircraftOverdue,_aircraftOldest,_aircraftMaxCallbackMs,_aircraftMaxLatency,missionNamespace getVariable ["WAIT_Aircraft_SchedulerActive",false],missionNamespace getVariable ["WAIT_Aircraft_LandingSchedulerActive",false],missionNamespace getVariable ["WAIT_Aircraft_DecelerationSchedulerActive",false]]];
// Coordinated work is server-owned, so expose the lease/turn state which an HC-only
// group snapshot cannot explain. This is calculated only for an on-demand report.
private _supportRequests=missionNamespace getVariable ["WAIT_AIPass_SupportRequests",createHashMap];
private _activeSupportBounds=0;
private _supportFailures=0;
private _retiredSupportTeams=0;
{
    private _request=_y;
    if ((_request getOrDefault ["boundActive",[]]) isNotEqualTo []) then {_activeSupportBounds=_activeSupportBounds+1};
    {_supportFailures=_supportFailures+_y} forEach (_request getOrDefault ["boundFailuresByToken",createHashMap]);
    _retiredSupportTeams=_retiredSupportTeams+count (_request getOrDefault ["boundRetired",[]]);
} forEach _supportRequests;
_checks pushBack ["ai","cortex-coordination-health",if (_retiredSupportTeams > 0) then {"ERROR"} else {"LOADED"},format ["requests=%1 activeBounds=%2 recordedBoundFailures=%3 retiredTeams=%4. A NOT_READY result yields immediately; TIMEOUT or repeated failures identify a movement/controller fault rather than successful support.",count _supportRequests,_activeSupportBounds,_supportFailures,_retiredSupportTeams]];
{
    private _request=_supportRequests get _x;
    private _requester=_request getOrDefault ["requester",grpNull];
    _checks pushBack ["ai","cortex-coordination-"+_x,"LOADED",format ["requester=%1 leases=%2 active=%3 completed=%4 retired=%5 failuresByToken=%6 secondsRemaining=%7",if (isNull _requester) then {"NULL"} else {groupId _requester},count (_request getOrDefault ["leases",[]]),_request getOrDefault ["boundActive",[]],_request getOrDefault ["boundCompleted",[]],_request getOrDefault ["boundRetired",[]],_request getOrDefault ["boundFailuresByToken",createHashMap],((_request getOrDefault ["expiry",serverTime])-serverTime) max 0]];
    private _brain=if (isNull _requester) then {createHashMap} else {_requester getVariable ["WAIT_Support_Brain",createHashMap]};
    private _brainHealthy=count _brain > 0 && {(_brain getOrDefault ["serial",-1]) == (_request getOrDefault ["serial",-2])}
        && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])};
    _checks pushBack ["ai","wait-support-fsm-"+_x,["ERROR","LOADED"] select _brainHealthy,format ["requester=%1 phase=%2 generation=%3 pending=%4 secondsSinceStep=%5 dueInSeconds=%6 leases=%7 cursor=%8 schedulerWatchdogs=%9. The server FSM owns discovery and coordination persistence; responder movement remains owner-local.",if (isNull _requester) then {"NULL"} else {groupId _requester},_brain getOrDefault ["phase","MISSING"],_brain getOrDefault ["generation",-1],_brain getOrDefault ["pending",false],if ((_brain getOrDefault ["lastStepAt",-1]) < 0) then {-1} else {(time-(_brain get "lastStepAt")) max 0},((_brain getOrDefault ["nextAt",time])-time) max 0,count (_request getOrDefault ["leases",[]]),_request getOrDefault ["cursor",0],_brain getOrDefault ["watchdogCount",0]]];
} forEach ((keys _supportRequests) select [0,20]);
private _localGroups=_groups select {local _x && {_x getVariable ["WAIT_AIPass_Managed",false]}};
_checks pushBack ["ai","cortex-snapshot-scope","LOADED",format ["Snapshot serverTime=%1; server-local managed groups=%2, sampled=%3 (limit 20); HC-owned groups=%4. HC private action/queue state is unavailable here, not zero. Stationary or PATH-disabled units may be covering; one snapshot cannot prove a stall.",serverTime,count _localGroups,(count _localGroups) min 20,count _hcGroups]];
{
    private _group=_x;
    {
        _x params ["_type","_variable"];
        private _refusal=_group getVariable [_variable,[]];
        if (_refusal isNotEqualTo []) then {
            _checks pushBack ["ai",format ["cortex-tactical-refusal-%1-%2",toLowerANSI _type,netId leader _group],"LOADED",format ["group=%1 owner=%2 type=%3 lastRefusal=[reason,time,detail]=%4. This is the latest changed start gate, not a permanent error; a later accepted lease clears it.",groupId _group,groupOwner _group,_type,_refusal]];
        };
    } forEach [["FLANK","WAIT_Cortex_FlankRefusal"],["ADVANCE","WAIT_Cortex_AdvanceRefusal"]];
} forEach (_localGroups select [0,20]);
{
    private _group=_x;
    private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
    private _brain=_group getVariable ["WAIT_GroupBrain",createHashMap];
    private _brainPhase=_brain getOrDefault ["phase","MISSING"];
    private _brainHealthy=count _brain > 0
        && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {(_brain getOrDefault ["generation",-1]) == (_group getVariable ["WAIT_GroupBrain_Generation",0])}
        && {!(_brain getOrDefault ["cancelled",false])};
    _checks pushBack ["ai",format ["wait-group-brain-%1",netId leader _group],["ERROR","LOADED"] select _brainHealthy,format ["group=%1 owner=%2 semanticPhase=%3 legacyPhase=%4 generation=%5 ownerEpoch=%6 pending=%7 secondsSinceStep=%8 secondsUntilDue=%9 schedulerWatchdogs=%10 cancelReason=%11. The FSM is the persistent decision owner; after fifteen unpaused seconds and the resume grace, a watchdog only wakes the same keyed shared-scheduler job and never creates another decision owner. Physical results still require route, movement, firing or room evidence.",groupId _group,groupOwner _group,_brainPhase,_brain getOrDefault ["legacyPhase","UNKNOWN"],_brain getOrDefault ["generation",-1],_brain getOrDefault ["ownerEpoch",-1],_brain getOrDefault ["pending",false],if ((_brain getOrDefault ["lastStepAt",-1]) < 0) then {-1} else {time-(_brain get "lastStepAt")},((_brain getOrDefault ["nextAt",time])-time) max 0,_brain getOrDefault ["watchdogCount",0],_brain getOrDefault ["cancelReason",""]]];
    private _phaseTransition=_group getVariable ["WAIT_Cortex_PhaseTransition",[]];
    if (count _phaseTransition == 5) then {
        private _phaseCurrent=_state getOrDefault ["phase","UNKNOWN"];
        private _phaseExpected=_phaseTransition select 2;
        _checks pushBack ["ai",format ["cortex-phase-transition-%1",netId leader _group],["ERROR","LOADED"] select (_phaseCurrent == _phaseExpected),format ["group=%1 owner=%2 current=%3 latest=[serverTime,from,to,reason,owner]=%4 historyEntries=%5. A mismatch means phase state changed outside the atomic transition path.",groupId _group,groupOwner _group,_phaseCurrent,_phaseTransition,count (_group getVariable ["WAIT_Cortex_PhaseTransitions",[]])]];
    };
    private _drill=_state getOrDefault ["drill",createHashMap];
    private _members=(units _group) select [0,8];
    if (count _drill > 0) then {
        private _lastStep=_drill getOrDefault ["lastStep",_drill getOrDefault ["started",time]];
        private _heartbeatAge=(time-_lastStep) max 0;
        private _watchdog=30;
        private _resumeGrace=((missionNamespace getVariable ["WAIT_AIPass_ResumeGraceUntil",-1])-time) max 0;
        private _movementLease=_state getOrDefault ["movementLease",[]];
        private _healthy=_heartbeatAge <= _watchdog || {_resumeGrace > 0};
        private _drillFsmJob=_group getVariable ["WAIT_Cortex_DrillFSMJob",createHashMap];
        _checks pushBack ["ai",format ["cortex-drill-health-%1",netId _group],["ERROR","LOADED"] select _healthy,format ["group=%1 type=%2 stage=%3 token=%4 heartbeatAgeSeconds=%5 watchdogSeconds=%6 movementLease=%7 resumeGraceSeconds=%8 schedulerWatchdogs=%9. An overdue controller wakes its same keyed scheduler callback; a stored drill or waypoint is not completion evidence.",groupId _group,_drill getOrDefault ["type","UNKNOWN"],_drill getOrDefault ["stage","UNKNOWN"],_drill getOrDefault ["token",""],_heartbeatAge,_watchdog,_movementLease,_resumeGrace,_drillFsmJob getOrDefault ["watchdogCount",0]]];
    };
    private _remount=_group getVariable ["WAIT_Cortex_Remount",[]];
    if (count _remount == 2) then {
        private _remountDeadline=_remount select 0;
        private _remountPassengers=_remount select 1;
        private _remountConflicts=_remountPassengers select {
            _x params ["_unit","_vehicle"];
            alive _unit && {!isNull assignedVehicle _unit} && {assignedVehicle _unit != _vehicle}
        };
        private _remountPending=_remountPassengers select {
            _x params ["_unit","_vehicle"];
            alive _unit && {alive _vehicle} && {vehicle _unit != _vehicle}
        };
        private _remountHealthy=serverTime < _remountDeadline && {_remountConflicts isEqualTo []};
        _checks pushBack ["ai",format ["cortex-remount-ownership-%1",netId _group],["ERROR","LOADED"] select _remountHealthy,format ["group=%1 secondsRemaining=%2 passengers=%3 pending=%4 assignmentConflicts=%5. The stored list is boarding intent, not proof that passengers stayed aboard or re-entered; a different assignment must cancel the affected actor.",groupId _group,(_remountDeadline-serverTime) max 0,count _remountPassengers,count _remountPending,count _remountConflicts]];
    };
    private _transition=_group getVariable ["WAIT_Cortex_TransitionIntent",[]];
    if (count _transition == 6) then {
        _transition params ["_transitionPhase","_transitionTarget","_transitionStarted","_transitionDeadline","_transitionSource","_transitionTeam"];
        private _transitionGateOpen=switch (_transitionPhase) do {
            case "INVESTIGATE": {
                private _sourceGate=["WAIT_AIPass_ContactReports_Enable","WAIT_AIPass_Hearing_Enable"] select (_transitionSource == "SOUND");
                [_group,"WAIT_AIPass_Investigate_Enable",true] call WAIT_fnc_CortexFeatureEnabled
                    && {_transitionSource == "" || {[_group,_sourceGate,true] call WAIT_fnc_CortexFeatureEnabled}}
            };
            case "SEARCH": {[_group,"WAIT_AIPass_PostContact_Enable",true] call WAIT_fnc_CortexFeatureEnabled};
            default {false};
        };
        private _transitionCurrent=_state getOrDefault ["phase","UNKNOWN"];
        private _transitionHealthy=serverTime < _transitionDeadline && {_transitionGateOpen} && {_transitionCurrent == _transitionPhase};
        _checks pushBack ["ai",format ["cortex-transition-ownership-%1",netId _group],["ERROR","LOADED"] select _transitionHealthy,format ["group=%1 intentPhase=%2 currentPhase=%3 source=%4 gateOpen=%5 ageSeconds=%6 secondsRemaining=%7 teamAlive=%8 target=%9. A durable transition exists only to resume INVESTIGATE or SEARCH after locality migration; it must not survive its gate, deadline or phase.",groupId _group,_transitionPhase,_transitionCurrent,_transitionSource,_transitionGateOpen,(serverTime-_transitionStarted) max 0,(_transitionDeadline-serverTime) max 0,{alive _x} count _transitionTeam,_transitionTarget]];
    };
    private _supportLease=_group getVariable ["WAIT_AIPass_SupportLease",[]];
    private _supportToken=_state getOrDefault ["supportToken",""];
    private _supportRole=_group getVariable ["WAIT_Cortex_SupportRole",[]];
    if (_supportLease isNotEqualTo [] || {_supportToken != ""} || {_supportRole isNotEqualTo []}) then {
        private _leaseToken=_supportLease param [0,""];
        private _leaseExpiry=_supportLease param [2,0];
        private _roleToken=_supportRole param [0,""];
        private _supportHealthy=count _supportLease == 6 && {serverTime < _leaseExpiry}
            && {_supportToken in ["",_leaseToken]} && {_roleToken in ["",_leaseToken]};
        _checks pushBack ["ai",format ["cortex-support-ownership-%1",netId _group],["ERROR","LOADED"] select _supportHealthy,format ["group=%1 leaseToken=%2 localToken=%3 roleToken=%4 secondsRemaining=%5 responding=%6 assaulting=%7 movementLease=%8. Token disagreement or an expired retained lease identifies overlapping or orphaned coordinated work.",groupId _group,_leaseToken,_supportToken,_roleToken,(_leaseExpiry-serverTime) max 0,_state getOrDefault ["responding",false],_state getOrDefault ["assaulting",false],_state getOrDefault ["movementLease",[]]]];
    };
    private _combinedRole=_group getVariable ["WAIT_Cortex_CombinedRole",[]];
    if (_combinedRole isNotEqualTo []) then {
        private _combinedRequester=_combinedRole param [1,grpNull];
        private _combinedTarget=_combinedRole param [2,objNull];
        private _combinedName=_combinedRole param [4,""];
        private _combinedExpiry=_combinedRole param [5,0];
        private _combinedHealthy=count _combinedRole == 7 && {serverTime < _combinedExpiry}
            && {!isNull _combinedRequester} && {!isNull _combinedTarget} && {alive _combinedTarget}
            && {side _combinedRequester == side _group} && {_combinedName in ["GROUND_FIRE","GROUND_MANOEUVRE","AIR_ATTACK"]};
        _checks pushBack ["ai",format ["cortex-combined-role-%1",netId _group],["ERROR","LOADED"] select _combinedHealthy,format ["group=%1 token=%2 role=%3 requester=%4 target=%5 secondsRemaining=%6 applied=%7 result=%8. Combined roles share an opportunity only; they contain no assembly readiness or infantry movement gate.",groupId _group,_combinedRole param [0,""],_combinedName,groupId _combinedRequester,_combinedTarget,(_combinedExpiry-serverTime) max 0,_group getVariable ["WAIT_Cortex_CombinedApplied",[]],_group getVariable ["WAIT_Cortex_CombinedResult",[]]]];
    };
    private _buildingBrain=_group getVariable ["WAIT_BuildingBrain",createHashMap];
    if (count _buildingBrain > 0) then {
        private _buildingJob=_buildingBrain getOrDefault ["job",createHashMap];
        _checks pushBack ["ai",format ["wait-building-fsm-%1",netId _group],"ACTIVE",format ["group=%1 phase=%2 generation=%3 ownerEpoch=%4 pending=%5 nextStepSeconds=%6 progressAgeSeconds=%7 visited=%8 unreachable=%9 rooms=%10 schedulerWatchdogs=%11 cancellation=%12. Physical visits remain the clearance authority; the FSM state is intent and ownership evidence only.",groupId _group,_buildingBrain getOrDefault ["phase","UNKNOWN"],_buildingBrain getOrDefault ["generation",-1],_buildingBrain getOrDefault ["ownerEpoch",-1],_buildingBrain getOrDefault ["pending",false],((_buildingBrain getOrDefault ["nextAt",time])-time) max 0,(serverTime-(_buildingJob getOrDefault ["lastProgressAt",serverTime])) max 0,count (_buildingJob getOrDefault ["cleared",[]]),count (_buildingJob getOrDefault ["unreachable",[]]),count (_buildingJob getOrDefault ["positions",[]]),_buildingBrain getOrDefault ["watchdogCount",0],_buildingBrain getOrDefault ["cancelReason",""]]];
    };
    private _operation=_group getVariable ["WAIT_Operation",createHashMap];
    if (count _operation > 0) then {
        _checks pushBack ["ai",format ["wait-operation-%1",netId _group],"LOADED",format ["group=%1 intent=%2 generation=%3 ownerEpoch=%4 phase=%5 participants=%6 routePoints=%7 progressAgeSeconds=%8 replans=%9 recoveryAttempts=%10 unavailableActors=%11 cancellation=%12. Operation status records WAIT ownership only; a physical result still requires travel, firing or room-visit evidence.",groupId _group,_operation getOrDefault ["intent","UNKNOWN"],_operation getOrDefault ["generation",-1],_operation getOrDefault ["ownerEpoch",-1],_operation getOrDefault ["phase","UNKNOWN"],count (_operation getOrDefault ["participants",[]]),count (_operation getOrDefault ["route",[]]),time-(_operation getOrDefault ["lastProgressAt",time]),_operation getOrDefault ["replans",0],count (keys (_operation getOrDefault ["recovery",createHashMap])),count (_operation getOrDefault ["unavailable",[]]),_operation getOrDefault ["cancelReason",""]]];
    };
    _checks pushBack ["ai",format ["cortex-group-context-%1",netId _group],"LOADED",format ["group=%1 phaseAgeSeconds=%2 lastSeenAgeSeconds=%3 morale=%4 moraleState=%5 investigating=%6 searchMembers=%7 reinforcementResponding=%8 dismounted=%9 withdrawnVehicles=%10 disabledFeatures=%11 externalControl=%12. Ages are owner-local; unknown uses -1. Stored intentions are not physical completion.",groupId _group,if ("phaseStart" in _state) then {time-(_state get "phaseStart")} else {-1},if ("lastSeen" in _state) then {time-(_state get "lastSeen")} else {-1},_state getOrDefault ["morale",-1],_state getOrDefault ["moraleState","UNKNOWN"],_state getOrDefault ["areaInvestigation",""],count (_state getOrDefault ["searchTeam",[]]),_state getOrDefault ["responding",false],count (_state getOrDefault ["dismounted",[]]),count (_state getOrDefault ["withdrawn",[]]),_group getVariable ["WAIT_AIPass_DisabledFeatures",[]],[_group] call WAIT_fnc_CompatibilityExternalControl]];
    private _actors=_members apply {[_x,currentCommand _x,round speed _x,_x checkAIFeature "PATH",_x checkAIFeature "MOVE",behaviour _x,unitCombatMode _x]};
    _checks pushBack ["ai",format ["cortex-group-%1",netId _group],"LOADED",format ["group=%1 owner=%2 phase=%3 drill=%4 stage=%5 bound=%6 recoveryActors=%7 groupSpeed=%8 excluded=%9 ZeusWaypoints=%10 ZeusHoldRemaining=%11 supportRole=%12 supportResult=%13 supportAbort=%14 combinedRole=%15 withdrawal=[status,travel,replans]=%16; first 8 members [unit,command,km/h,PATH,MOVE,behaviour,ROE]=%17",
        groupId _group,groupOwner _group,_state getOrDefault ["phase","UNKNOWN"],_drill getOrDefault ["type","NONE"],_drill getOrDefault ["stage","NONE"],_drill getOrDefault ["index",-1],count (_drill getOrDefault ["recovery",[]]),speedMode _group,_group getVariable ["WAIT_AIPass_Exclude",false],_group getVariable ["WAIT_AIPass_ZeusWaypoints",false],((_group getVariable ["WAIT_AIPass_ZeusLocalUntil",time])-time) max 0,_group getVariable ["WAIT_Cortex_SupportRole",[]],_group getVariable ["WAIT_Cortex_SupportBoundResult",[]],_group getVariable ["WAIT_Cortex_SupportAbort",[]],_combinedRole,_group getVariable ["WAIT_Cortex_Withdrawal",[]],_actors]];
} forEach (_localGroups select [0,20]);
// Explicit orders publish assignments, so their physical distances can be inspected for any owner.
private _orderedGroups=_groups select {(_x getVariable ["WAIT_AIPass_Garrison",[]]) isNotEqualTo [] || {(_x getVariable ["WAIT_AIPass_Defend",[]]) isNotEqualTo []} || {(_x getVariable ["WAIT_AIPass_ClearOrder",[]]) isNotEqualTo []} || {(_x getVariable ["WAIT_Cortex_ClearResult",[]]) isNotEqualTo []}};
{
    private _group=_x;
    private _clearOrder=_group getVariable ["WAIT_AIPass_ClearOrder",[]];
    private _clearResult=_group getVariable ["WAIT_Cortex_ClearResult",[]];
    private _clearStatus=_group getVariable ["WAIT_Cortex_ClearStatus",[]];
    private _clearEvidence=if (_clearOrder isEqualTo []) then {
        _group getVariable ["WAIT_Cortex_ClearEvidence",[]]
    } else {
        [_clearOrder param [1,[]],_clearOrder param [4,[]],_clearOrder param [5,[]],_clearOrder param [6,[]],_clearOrder param [2,serverTime],_clearOrder param [7,serverTime]]
    };
    if (_clearResult isNotEqualTo []) then {
        _checks pushBack ["ai",format ["cortex-clearance-%1",netId _group],if ((_clearResult param [0,""]) == "INCOMPLETE") then {"ERROR"} else {"LOADED"},format ["group=%1 owner=%2 result=%3 visitedIndices=%4 exhaustedIndices=%5 retryCounts=%6 failedBy=%7 secondsRemaining=%8 secondsSinceProgress=%9 companionHandoff=%10 waitOperation=%11. Position visits measure traversal, not hostile-room clearance. A finished failed order remains visible after its controller releases.",groupId _group,groupOwner _group,_clearResult,_clearEvidence param [0,[]],_clearEvidence param [1,[]],_clearEvidence param [2,[]],_clearEvidence param [3,[]],if (_clearEvidence isEqualTo []) then {-1} else {((_clearEvidence param [4,serverTime])-serverTime) max 0},if (_clearEvidence isEqualTo []) then {-1} else {(serverTime-(_clearEvidence param [5,serverTime])) max 0},[_group,groupOwner _group] call WAIT_fnc_CompatibilityHeadlessRecord,_group getVariable ["WAIT_Operation",createHashMap]]];
    };
    if (_clearStatus isNotEqualTo []) then {
        _clearStatus params ["_clearPhase","_visited","_exhausted","_roomCount","_laneCount","_statusAt"];
        _checks pushBack ["ai",format ["cortex-clearance-active-%1",netId _group],"ACTIVE",format ["group=%1 owner=%2 phase=%3 visited=%4 exhausted=%5 rooms=%6 lanes=%7 secondsSinceMeaningfulChange=%8. Status changes only at setup, room/retry progress or egress; pair movement stays local to avoid network churn.",groupId _group,groupOwner _group,_clearPhase,_visited,_exhausted,_roomCount,_laneCount,(serverTime-_statusAt) max 0]];
    };
    private _positions=((units _group) select [0,8]) apply {
        private _slot=_x getVariable ["WAIT_AIPass_GarrisonPos",_x getVariable ["WAIT_AIPass_DefendPos",[]]];
        [_x,alive _x,if (_slot isEqualTo []) then {-1} else {_x distance (_slot select 0)},getPosATL _x]
    };
    _checks pushBack ["ai",format ["cortex-orders-%1",netId _group],"LOADED",format ["group=%1 owner=%2 garrison=%3 defend=%4 clearResult=%5; first 8 [unit,alive,3D-assignment-distance-or-minus1,actualATL]=%6. Reaching an assigned point does not prove usable cover, interior pathing or a cleared room. Check building simulation, accessible positions and actual firing clearance; no teleport correction is performed.",groupId _group,groupOwner _group,_group getVariable ["WAIT_AIPass_Garrison",[]],_group getVariable ["WAIT_AIPass_Defend",[]],_group getVariable ["WAIT_Cortex_ClearResult",[]],_positions]];
} forEach (_orderedGroups select [0,20]);
_checks pushBack ["ai","cortex-order-snapshot-scope","LOADED",format ["Explicit-order groups=%1 sampled=%2. Assignment/clear-result data is public; HC-private controllers remain unavailable.",count _orderedGroups,(count _orderedGroups) min 20]];
private _missions=missionNamespace getVariable ["WAIT_AIPass_FireMissions",createHashMap];
{
    private _mission=_missions get _x;
    private _phase=_mission getOrDefault ["phase","UNKNOWN"];
    _checks pushBack ["ai","cortex-fire-"+_x,if (_phase == "UNCERTAIN") then {"ERROR"} else {"LOADED"},format ["purpose=%1 phase=%2 confirmedShots=%3 remaining=%4 burstsLeft=%5 dueInSeconds=%6 owner=%7. PENDING is awaiting a firing event, not confirmed fire; UNCERTAIN must not be retried blindly.",_mission getOrDefault ["purpose","UNKNOWN"],_phase,_mission getOrDefault ["fired",0],_mission getOrDefault ["remaining",0],_mission getOrDefault ["burstsLeft",0],(_mission getOrDefault ["due",time])-time,owner (_mission getOrDefault ["battery",objNull])]];
    private _battery=_mission getOrDefault ["battery",objNull];
    private _brain=if (isNull _battery) then {createHashMap} else {_battery getVariable ["WAIT_Artillery_Brain",createHashMap]};
    private _brainState=if (isNull _battery) then {[]} else {_battery getVariable ["WAIT_Artillery_Brain_State",[]]};
    private _brainHealthy=count _brain > 0 && {(_brain getOrDefault ["token",""]) == (_mission getOrDefault ["token",""])}
        && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])};
    _checks pushBack ["ai","wait-artillery-fsm-"+_x,["ERROR","LOADED"] select _brainHealthy,format ["phase=%1 generation=%2 pending=%3 dueInSeconds=%4 lastStepAge=%5 nativePhase=%6 token=%7 schedulerWatchdogs=%8 state=%9. The FSM owns persistence; shot, observer and warning work remains bounded.",_brain getOrDefault ["phase","MISSING"],_brain getOrDefault ["generation",-1],_brain getOrDefault ["pending",false],((_brain getOrDefault ["nextAt",time])-time) max 0,if ((_brain getOrDefault ["lastStepAt",-1]) < 0) then {-1} else {(time-(_brain get "lastStepAt")) max 0},_phase,_mission getOrDefault ["token",""],_brain getOrDefault ["watchdogCount",0],_brainState]];
} forEach ((keys _missions) select [0,20]);
private _convoys=missionNamespace getVariable ["WAIT_Convoy_Registry",[]];
{
    _x params ["_group","_configuration"];
    private _companionHandoff=[_group,groupOwner _group] call WAIT_fnc_CompatibilityHeadlessRecord;
    private _waitHandoff=_group getVariable ["WAIT_Convoy_LastHeadlessAdoption",[]];
    private _handoffMissing=count _companionHandoff >= 3 && {(_companionHandoff select 1) == groupOwner _group} && {_companionHandoff select 2} && {(count _waitHandoff < 2) || {(_waitHandoff select 1) != groupOwner _group}};
    _checks pushBack ["ai",format ["cortex-convoy-%1",netId _group],if (_handoffMissing) then {"ERROR"} else {"LOADED"},format ["group=%1 owner=%2 revision=%3 phase=%4 haltReason=%5 vehicles=%6 companionHandoff=%7 waitHandoff=%8. A halt reason records the controller decision, not proof of physical unloading or recovery.",groupId _group,groupOwner _group,_configuration param [0,-1],_configuration param [5,"UNKNOWN"],_configuration param [8,""],count (_configuration param [4,[]]),_companionHandoff,_waitHandoff]];
} forEach (_convoys select [0,20]);
private _scoots=vehicles select {(_x getVariable ["WAIT_Cortex_ArtilleryScootToken",""]) != ""};
{
    private _purpose=_x getVariable ["WAIT_Cortex_ArtilleryScootPurpose",""];
    private _counter=_purpose == "COUNTER";
    private _feature=["WAIT_AIPass_Artillery_Enable","WAIT_AIPass_CounterBattery_Enable"] select _counter;
    private _setting=["WAIT_AIPass_Artillery_ShootAndScoot","WAIT_AIPass_CounterBattery_ShootAndScoot"] select _counter;
    private _crewGroup=if (isNull driver _x) then {grpNull} else {group driver _x};
    private _deadline=_x getVariable ["WAIT_Cortex_ArtilleryScootDeadline",0];
    private _gateOpen=!isNull _crewGroup && {_purpose in ["SUPPORT","COUNTER"]}
        && {missionNamespace getVariable [_setting,true]}
        && {[_crewGroup,_feature,false] call WAIT_fnc_CortexFeatureEnabled};
    private _healthy=serverTime < _deadline && {_gateOpen};
    _checks pushBack ["ai",format ["cortex-artillery-scoot-ownership-%1",netId _x],["ERROR","LOADED"] select _healthy,format ["class=%1 owner=%2 group=%3 token=%4 purpose=%5 secondsRemaining=%6 gateOpen=%7 mobile=%8 speed=%9. A pending token owns one delayed relocation; it must disappear when its gate closes or deadline expires.",typeOf _x,owner _x,if (isNull _crewGroup) then {"NULL"} else {groupId _crewGroup},_x getVariable ["WAIT_Cortex_ArtilleryScootToken",""],_purpose,(_deadline-serverTime) max 0,_gateOpen,canMove _x,speed _x]];
} forEach (_scoots select [0,20]);
_checks pushBack ["ai","cortex-controller-snapshot-limits","LOADED",format ["Fire missions total=%1 sampled=%2; convoys total=%3 sampled=%4; pending artillery relocations total=%5 sampled=%6; limits 20 each. Counters are server-local unless explicitly described as registry state. No diagnostics poller is installed.",count _missions,(count _missions) min 20,count _convoys,(count _convoys) min 20,count _scoots,(count _scoots) min 20]];
private _attackAircraft=vehicles select {_x isKindOf "Air" && {(_x getVariable ["WAIT_Cortex_AttackFlarePhase",""]) != ""}};
{
    _checks pushBack ["ai",format ["cortex-attack-flares-%1",netId _x],"LOADED",format ["class=%1 owner=%2 phase=%3 cooldownRemaining=%4 speed=%5 alive=%6. Phase describes the last requested leg, not actual release; inspect Fired events and countermeasure ammunition. No flight commands are issued.",typeOf _x,owner _x,_x getVariable ["WAIT_Cortex_AttackFlarePhase",""],((_x getVariable ["WAIT_Cortex_AttackFlareCooldown",0])-serverTime) max 0,speed _x,alive _x]];
} forEach (_attackAircraft select [0,20]);
private _adaptiveAircraft=vehicles select {_x isKindOf "Air" && {
    count (_x getVariable ["WAIT_AirAttack_Brain",createHashMap]) > 0
        || {(_x getVariable ["WAIT_Cortex_AirAttackPlan",[]]) isNotEqualTo []}
        || {(_x getVariable ["WAIT_Cortex_AirAttackOutcome",[]]) isNotEqualTo []}
}};
{
    private _aircraft=_x;
    private _plan=_aircraft getVariable ["WAIT_Cortex_AirAttackPlan",[]];
    private _outcome=_aircraft getVariable ["WAIT_Cortex_AirAttackOutcome",[]];
    private _request=_aircraft getVariable ["WAIT_Cortex_CountermeasureLastRequest",[]];
    private _brainState=_aircraft getVariable ["WAIT_AirAttack_Brain_State",[]];
    private _airBrain=_aircraft getVariable ["WAIT_AirAttack_Brain",createHashMap];
    private _reason=_outcome param [0,""];
    private _healthy=alive _aircraft && {(getPosATL _aircraft select 2) >= 25}
        && {_reason in ["","COMPLETE","CONTROL_RELEASED","TARGET_LOST","AUTHORED_ROUTE_CHANGED","NOT_ATTACKING"]};
    _checks pushBack ["ai",format ["cortex-air-attack-%1",netId _aircraft],["ERROR","LOADED"] select _healthy,
        format ["class=%1 owner=%2 brain=[phase,generation,time,reason,delay]=%3 schedulerWatchdogs=%4 current=[token,pattern,stage,target,destination,remaining,actualShots,observedAA,speed,altitude,approachCM,egressCM,platform,lateralTurret,standoffWeapon,standoffTurret,fireSolution,stageAltitudes,stageSpeeds,captureRadii,attackMinimum,points,selectedWeapon,selectedSimulation,selectedTurret]=%5 lastOutcome=[reason,time,pattern,actualShots]=%6 lastCountermeasureRequest=%7 standoffBlockedSeconds=%8 crewRetained=%9. A Fired event is not an effective attack by itself; inspect the live solution, release geometry, projectile result and physical egress.",
            typeOf _aircraft,owner _aircraft,_brainState,_airBrain getOrDefault ["watchdogCount",0],_plan,_outcome,_request,((_aircraft getVariable ["WAIT_Cortex_AirStandoffBlockedUntil",0])-serverTime) max 0,(crew _aircraft) findIf {!alive _x || {vehicle _x != _aircraft}} < 0]];
} forEach (_adaptiveAircraft select [0,20]);
_checks pushBack ["ai","cortex-air-attack-snapshot-limits","LOADED",format ["Adaptive aircraft total=%1 sampled=%2 (limit 20). Active plans and retained outcomes are included; physical travel, Fired events and explicit transitions remain the acceptance evidence.",count _adaptiveAircraft,(count _adaptiveAircraft) min 20]];
private _flightLeased=vehicles select {_x isKindOf "Air" && {count (_x getVariable ["WAIT_FlightLease",createHashMap]) > 0}};
{
    private _lease=_x getVariable ["WAIT_FlightLease",createHashMap];
    private _leaseOwner=_lease getOrDefault ["owner",-1];
    private _healthy=alive _x && {_leaseOwner == owner _x};
    _checks pushBack ["ai",format ["wait-flight-lease-%1",netId _x],["ERROR","ACTIVE"] select _healthy,format [
        "class=%1 aircraftOwner=%2 controller=%3 token=%4 priority=%5 leaseOwner=%6 revision=%7 age=%8 lastRelease=%9. Exactly one WAIT controller may mutate flight; player, Zeus and specialist ownership invalidate it.",
        typeOf _x,owner _x,_lease getOrDefault ["controller",""],_lease getOrDefault ["token",""],
        _lease getOrDefault ["priority",0],_leaseOwner,_lease getOrDefault ["revision",-1],
        serverTime-(_lease getOrDefault ["startedAt",serverTime]),_x getVariable ["WAIT_FlightLeaseLast",[]]
    ]];
} forEach (_flightLeased select [0,20]);
_checks pushBack ["ai","wait-flight-lease-snapshot-limits","LOADED",format ["Flight leases total=%1 sampled=%2 (limit 20).",count _flightLeased,(count _flightLeased) min 20]];
private _compat = missionNamespace getVariable ["WAIT_AITweaks_Compatibility", createHashMap];
private _providers = (keys _compat) select {_compat get _x};
_providers sort true;
_checks pushBack ["ai", "ai-external-providers", "LOADED", format [
    "Detected=%1. Specialist and independent-domain providers may reserve actors through active operation markers. They do not share WAIT's engine danger or building progression. Any other fsmDanger replacement is unsupported.", _providers
]];
["ai", _checks] call WAIT_fnc_AITweaksDiagnosticReport

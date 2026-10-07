/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Machine-local start guard prevents duplicate scheduler and handlers. Joining owners install their own local runtime.
 * Starts the Smart AI Pass on this machine if it owns AI: the server or a headless client.
 *
 * Installs, once per machine:
 * - one CBA per-frame handler that runs WAIT_fnc_CortexSchedulerTick. The due-time cache makes
 *   idle frames constant-time; due work gets one budgeted opportunity per rendered/simulated frame
 *   instead of being capped at four heavy jobs per second;
 * - one EntityKilled mission handler that passes kills in locally owned groups to survivor regroup;
 * - the WAIT_fnc_CortexDiscover sweep job, which brings local groups under the pass;
 * - a ProjectileCreated handler for grenade evasion, only while WAIT_AIPass_GrenadeEvasion_Enable is
 *   on (it would otherwise run for every projectile);
 * - an ArtilleryShellFired handler for counter-battery, only while WAIT_AIPass_CounterBattery_Enable
 *   is on.
 * - event-driven civilian FiredNear/Hit reactions when enabled. Existing and newly created owner-local
 *   civilians are versioned once; no civilian polling loop is installed.
 * Existing local groups have their peak strength recorded. Repeat calls are safe, and they add the
 * optional handlers when their switches have been turned on since the last call. Player clients return immediately and pay nothing. Each
 * behaviour has its own WAIT_AIPass_<Behaviour>_Enable switch in \z\waldo_ai_tweaks\addons\main\settings\aiConfig.sqf, and
 * WAIT_fnc_CortexIsEligible keeps player groups and other WAIT features' units out.
 * WAIT's configured danger FSM must own all three base-soldier slots. If another addon replaces any
 * slot, this tactical runtime fails closed instead of running a second infantry brain beside it.
 * Movement ownership is reserved only for finite WAIT operations.
 * Locality and authority: CBA supplies the effective enable value to every joining owner. A direct
 * server call while disabled requests enable through the CBA server layer; callbacks install local
 * work. Remote calls from anything other than the server are refused. A headless client waits for
 * CBA settings readiness first.
 *
 * Review contract: Repeated pre-snapshot calls share one waiter. Stop cancels it; a headless client starts only if the completed authoritative snapshot still enables the pass.
 *
 * Arguments: None.
 *
 * Return Value:
 * Boolean - true when startup is accepted, pending settings readiness, or already running
 *
 * Example:
 * [] call WAIT_fnc_CortexInit;
 * Result: on the server, the pass starts and every connected or later headless client starts it too.
 *
 * Current callers: addon postInit, CBA setting callbacks, server scripts and audits.
 */

if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (hasInterface && {!isServer}) exitWith {false};
if !(missionNamespace getVariable ["WAIT_AITweaks_SettingsReady", false]) exitWith {
    if (missionNamespace getVariable ["WAIT_AIPass_InitPending", false]) exitWith {true};
    missionNamespace setVariable ["WAIT_AIPass_InitPending", true];
    [] spawn {
        waitUntil {
            missionNamespace getVariable ["WAIT_AITweaks_SettingsReady", false]
            || {!(missionNamespace getVariable ["WAIT_AIPass_InitPending", false])}
        };
        private _requested = missionNamespace getVariable ["WAIT_AIPass_InitPending", false];
        missionNamespace setVariable ["WAIT_AIPass_InitPending", false];
        if (_requested && {missionNamespace getVariable ["WAIT_AITweaks_SettingsReady", false]}
            && {missionNamespace getVariable ["WAIT_AIPass_Enable", false]}) then {[] call WAIT_fnc_CortexInit};
    };
    true
};

// A direct server start is a configuration request. CBA callbacks start each owner locally.
if !(missionNamespace getVariable ["WAIT_AIPass_Enable", false]) exitWith {
    if (!isServer) exitWith {false};
    ([createHashMapFromArray [["WAIT_AIPass_Enable", true]]] call WAIT_fnc_CortexTuning) > 0
};
private _dangerFsmPaths=["SoldierWB","SoldierEB","SoldierGB"] apply {
    [_x,toLowerANSI getText (configFile >> "CfgVehicles" >> _x >> "fsmDanger")]
};
private _dangerFsmOwned=_dangerFsmPaths findIf {
    (_x select 1) find "\z\waldo_ai_tweaks\addons\infantry\fsm\danger.fsm" < 0
} < 0;
missionNamespace setVariable ["WAIT_AIPass_DangerOwnershipConflict",[[],_dangerFsmPaths] select !_dangerFsmOwned];
if (!_dangerFsmOwned) exitWith {
    missionNamespace setVariable ["WAIT_AIPass_Active",false];
    diag_log format ["[WAIT] Infantry tactical runtime refused: WAIT does not own every base-soldier fsmDanger slot (%1).",_dangerFsmPaths];
    false
};
missionNamespace setVariable ["WAIT_AIPass_Active", true];

[] call WAIT_fnc_SchedulerReconcile;
if (isNil {missionNamespace getVariable "WAIT_AIPass_KilledHandler"}) then {
    missionNamespace setVariable ["WAIT_AIPass_KilledHandler", addMissionEventHandler ["EntityKilled", {
        params ["_unit"];
        if !(missionNamespace getVariable ["WAIT_AIPass_Active", false]) exitWith {};
        if !(_unit isKindOf "CAManBase") exitWith {};
        private _group = group _unit;
        if (isNull _group || {!local _group}) exitWith {};
        [_group, _unit] call WAIT_fnc_CortexRegroupOnKill;
    }]];
};

if (!(missionNamespace getVariable ["WAIT_AIPass_GrenadeEvasion_Enable", true]) && {!isNil {missionNamespace getVariable "WAIT_AIPass_ProjectileHandler"}}) then {
    removeMissionEventHandler ["ProjectileCreated", missionNamespace getVariable "WAIT_AIPass_ProjectileHandler"];
    missionNamespace setVariable ["WAIT_AIPass_ProjectileHandler", nil];
};
if (isNil {missionNamespace getVariable "WAIT_AIPass_ProjectileHandler"} && {missionNamespace getVariable ["WAIT_AIPass_GrenadeEvasion_Enable", true]}) then {
    missionNamespace setVariable ["WAIT_AIPass_ProjectileHandler", addMissionEventHandler ["ProjectileCreated", {
        params ["_projectile"];
        if !(missionNamespace getVariable ["WAIT_AIPass_Active", false]) exitWith {};
        private _type = typeOf _projectile;
        private _cache = missionNamespace getVariable ["WAIT_AIPass_GrenadeTypes", createHashMap];
        private _isGrenade = _cache getOrDefault [_type, -1];
        if (_isGrenade isEqualTo -1) then {
            _isGrenade = getText (configFile >> "CfgAmmo" >> _type >> "simulation") == "shotGrenade";
            _cache set [_type, _isGrenade];
            missionNamespace setVariable ["WAIT_AIPass_GrenadeTypes", _cache];
        };
        if (_isGrenade) then {
            [WAIT_fnc_CortexGrenadeCheck, createHashMapFromArray [["projectile", _projectile]], 0.3 + random 0.4] call WAIT_fnc_CortexQueueJob;
        };
    }]];
};
if (isNil {missionNamespace getVariable "WAIT_AIPass_ArtilleryHandler"}) then {
    missionNamespace setVariable ["WAIT_AIPass_ArtilleryHandler", addMissionEventHandler ["ArtilleryShellFired", {
        _this call WAIT_fnc_CortexArtilleryFired;
        params ["_vehicle", "", "", "_gunner"];
        if (missionNamespace getVariable ["WAIT_AIPass_Active", false]) then {[_vehicle, _gunner] call WAIT_fnc_CortexCounterBattery};
    }]];
};
// Optional addon public APIs can appear during postInit, so refresh the capability map before the
// first owner-local behaviour is accepted. Detection never changes another addon's state.
[] call WAIT_fnc_AITweaksDetectCompatibility;
[] call WAIT_fnc_CompatibilityHeadlessBridge;

// HC distribution remains owned by the active provider. WAIT only adopts a group after the
// provider confirms that the engine made it local to this HC; that retires old-owner jobs and
// restarts bounded discovery without choosing a destination or moving the group itself. These
// handlers live with the tactical runtime so headless continuation also works when skill tuning is
// disabled.
if !(missionNamespace getVariable ["WAIT_AI_ACEHeadlessHandlerInstalled", false]) then {
    missionNamespace setVariable ["WAIT_AI_ACEHeadlessHandlerInstalled", true];
    ["ace_headless_groupTransferPost", {
        params ["_group", "_headlessEntity", "_previousOwner", "_newOwner", "_transferredSuccessfully"];
        if (_transferredSuccessfully && {isServer || {!hasInterface}} && {clientOwner == _newOwner}
            && {local _group} && {missionNamespace getVariable ["WAIT_AIPass_Active", false]}) then {
            [_group, _previousOwner, _newOwner, "ACE"] call WAIT_fnc_AIHeadlessAdoptLocal;
        };
    }] call CBA_fnc_addEventHandler;
};
if !(missionNamespace getVariable ["WAIT_AI_CompatibilityHeadlessHandlerInstalled", false]) then {
    missionNamespace setVariable ["WAIT_AI_CompatibilityHeadlessHandlerInstalled", true];
    ["WAIT_Compatibility_HeadlessMigrated", {
        params ["_group", "_previousOwner", "_newOwner", "_provider"];
        if ((isServer || {!hasInterface}) && {clientOwner == _newOwner} && {local _group}
            && {missionNamespace getVariable ["WAIT_AIPass_Active", false]}) then {
            [_group, _previousOwner, _newOwner, _provider] call WAIT_fnc_AIHeadlessAdoptLocal;
        };
    }] call CBA_fnc_addEventHandler;
};
if (missionNamespace getVariable ["WAIT_AIPass_CivilianReaction_Enable",true]) then {
    {if (local _x) then {[_x] call WAIT_fnc_CortexCivilianSetup}} forEach (allUnits select {side group _x == civilian});
    if (isNil {missionNamespace getVariable "WAIT_Cortex_CivilianCreatedHandler"}) then {
        missionNamespace setVariable ["WAIT_Cortex_CivilianCreatedHandler",addMissionEventHandler ["EntityCreated",{
            params ["_entity"];
            if (_entity isKindOf "CAManBase" && {local _entity}) then {[_entity] call WAIT_fnc_CortexCivilianSetup};
        }]];
    };
} else {
    private _civilianCreated=missionNamespace getVariable "WAIT_Cortex_CivilianCreatedHandler";
    if (!isNil "_civilianCreated") then {
        removeMissionEventHandler ["EntityCreated",_civilianCreated];
        missionNamespace setVariable ["WAIT_Cortex_CivilianCreatedHandler",nil];
    };
    {if (local _x) then {[_x,true] call WAIT_fnc_CortexCivilianSetup}} forEach (allUnits select {side group _x == civilian});
};
{
    if (local _x) then {
        _x setVariable ["WAIT_AIPass_PeakSize", (_x getVariable ["WAIT_AIPass_PeakSize", 0]) max ({alive _x} count units _x)];
    };
} forEach allGroups;
if !(missionNamespace getVariable ["WAIT_AIPass_DiscoveryQueued", false]) then {
    missionNamespace setVariable ["WAIT_AIPass_DiscoveryQueued", true];
    [WAIT_fnc_CortexDiscover, createHashMap, 1] call WAIT_fnc_CortexQueueJob;
};

diag_log format ["[WAIT] Started on %1 (contact=%2 flank=%3 regroup=%4 artillery=%5 airborne=%6 dangerFSM=WAIT alternativeBackend=%7 meleeBackend=%8 specialistBackend=%9).",
    ["headless client", "server"] select isServer,
    missionNamespace getVariable ["WAIT_AIPass_Contact_Enable", true],
    missionNamespace getVariable ["WAIT_AIPass_Flank_Enable", true],
    missionNamespace getVariable ["WAIT_AIPass_Regroup_Enable", true],
    missionNamespace getVariable ["WAIT_AIPass_Artillery_Enable", false],
    missionNamespace getVariable ["WAIT_AIPass_Airborne_Enable", false],
    missionNamespace getVariable ["WAIT_AIPass_AlternativeBackendLoaded",false],
    missionNamespace getVariable ["WAIT_AIPass_MeleeBackendLoaded",false],
    missionNamespace getVariable ["WAIT_AIPass_SpecialistBackendLoaded",false]
];
true

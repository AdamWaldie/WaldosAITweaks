/*
 * Author: WaldoTheWarfighter
 * Loads standalone Waldos AI Tweaks settings and starts enabled owner-local AI systems.
 * Locality / Authority: Run once on every machine from mission init.sqf. Each machine loads guarded
 * shared defaults; the server starts Cortex and publishes its enabled state, while each current AI
 * owner installs skill and aircraft handlers. Interface clients install only Zeus interruption hooks.
 * Repeat/JIP: A machine-local guard makes repeated calls safe. JIP machines load the same settings,
 * mark their snapshot ready and receive the server's persistent Cortex start call when applicable.
 * Arguments: None.
 * Return Value: BOOL - true after this machine has initialized, including a repeat call.
 * Current callers: consuming mission init.sqf.
 * Example: [] execVM "bootstrap\start.sqf";
 */

if (missionNamespace getVariable ["Waldo_AITweaks_StartedLocal", false]) exitWith {true};
missionNamespace setVariable ["Waldo_AITweaks_StartedLocal", true];

private _config = call compile preprocessFileLineNumbers "MissionConfig\aiConfig.sqf";
if !(_config isEqualType createHashMap) exitWith {
    missionNamespace setVariable ["Waldo_AITweaks_StartedLocal", false];
    diag_log "[Waldos AI Tweaks] aiConfig.sqf did not return a HashMap.";
    false
};

{
    _x params ["_name", "_default"];
    if (isNil {missionNamespace getVariable _name}) then {
        missionNamespace setVariable [_name, _default];
    };
} forEach (_config getOrDefault ["shared", []]);

// The standalone package uses one checked-in settings source on every machine. This readiness
// sentinel retains the ordered-start contract expected by locality/JIP-safe AI initializers.
missionNamespace setVariable ["Waldo_FeatureRuntimeSnapshotFailed", false];
missionNamespace setVariable ["Waldo_FeatureRuntimeSnapshotReceived", true];

if (missionNamespace getVariable ["Waldo_AIRebalance_Enable", true]) then {
    [
        missionNamespace getVariable ["Waldo_AIRebalance_Mode", "AUTO"],
        missionNamespace getVariable ["Waldo_AIRebalance_Profile", "LINE"]
    ] call Waldo_fnc_AITweak;
};
if (missionNamespace getVariable ["Waldo_ImprovedHelicopterLanding_Enable", true]) then {
    [] call Waldo_fnc_ImprovedHelicopterLandingInit;
};
if (missionNamespace getVariable ["Waldo_HelicopterDeceleration_Enable", false]) then {
    [] call Waldo_fnc_HelicopterDecelerationInit;
};
if (isServer && {missionNamespace getVariable ["Waldo_AIPass_Enable", true]}) then {
    [] call Waldo_fnc_CortexInit;
};
if (hasInterface) then {
    [] call Waldo_fnc_CortexZeusWatchLocal;
};

diag_log format ["[Waldos AI Tweaks] Started on owner %1 (server=%2 interface=%3 HC=%4).",
    clientOwner, isServer, hasInterface, !isServer && {!hasInterface}];
true

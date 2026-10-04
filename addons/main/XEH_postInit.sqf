/*
 * Author: WaldoTheWarfighter
 * Starts enabled Waldos AI Tweaks systems after CBA and the mission have initialized.
 * Locality / Authority: Runs on every machine. AI owners install local handlers; the server owns
 * cross-group Cortex decisions; interface clients install Zeus interruption and optional ZEN controls.
 * Repeat/JIP: Guarded per machine. JIP and locality-aware systems perform their own repeat-safe adoption.
 * Arguments: None.
 * Return Value: BOOL - true once this machine has started the enabled systems.
 * Current callers: Extended_PostInit_EventHandlers in config.cpp.
 * Example: call compile preprocessFileLineNumbers "\z\waldo_ai_tweaks\addons\main\XEH_postInit.sqf";
 */

if (missionNamespace getVariable ["WAIT_AITweaks_PostInitComplete", false]) exitWith {true};
missionNamespace setVariable ["WAIT_AITweaks_PostInitComplete", true];
[] call WAIT_fnc_AITweaksDetectCompatibility;

if (missionNamespace getVariable ["WAIT_AIRebalance_Enable", true]) then {
    [
        missionNamespace getVariable ["WAIT_AIRebalance_Mode", "AUTO"],
        missionNamespace getVariable ["WAIT_AIRebalance_Profile", "LINE"]
    ] call WAIT_fnc_AITweak;
};
if (missionNamespace getVariable ["WAIT_ImprovedHelicopterLanding_Enable", true]) then {
    [] call WAIT_fnc_ImprovedHelicopterLandingInit;
};
if (missionNamespace getVariable ["WAIT_HelicopterDeceleration_Enable", false]) then {
    [] call WAIT_fnc_HelicopterDecelerationInit;
};
if (isServer && {missionNamespace getVariable ["WAIT_AIPass_Enable", true]}) then {
    [] call WAIT_fnc_CortexInit;
};
if (hasInterface) then {
    [] call WAIT_fnc_CortexZeusWatchLocal;
    [] execVM "\z\waldo_ai_tweaks\addons\main\bootstrap\zenRegister.sqf";
};

diag_log format ["[Waldos AI Tweaks] Started on owner %1 (server=%2 interface=%3 HC=%4).",
    clientOwner, isServer, hasInterface, !isServer && {!hasInterface}];
true

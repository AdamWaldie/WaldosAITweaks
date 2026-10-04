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

if (missionNamespace getVariable ["Waldo_AITweaks_PostInitComplete", false]) exitWith {true};
missionNamespace setVariable ["Waldo_AITweaks_PostInitComplete", true];

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
    [
        {!(isNil "zen_custom_modules_fnc_register")},
        {[] execVM "\z\waldo_ai_tweaks\addons\main\bootstrap\zenRegister.sqf";}
    ] call CBA_fnc_waitUntilAndExecute;
};

diag_log format ["[Waldos AI Tweaks] Started on owner %1 (server=%2 interface=%3 HC=%4).",
    clientOwner, isServer, hasInterface, !isServer && {!hasInterface}];
true

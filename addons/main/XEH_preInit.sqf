/*
 * Author: WaldoTheWarfighter
 * Loads guarded Waldos AI Tweaks defaults before mission initialization begins.
 * Locality / Authority: Runs once through CBA XEH on every server, headless client and interface client.
 * Repeat/JIP: The machine-local guard makes repeat execution safe; JIP machines receive the same defaults.
 * Arguments: None.
 * Return Value: BOOL - true once local defaults are available.
 * Current callers: Extended_PreInit_EventHandlers in config.cpp.
 * Example: call compile preprocessFileLineNumbers "\z\waldo_ai_tweaks\addons\main\XEH_preInit.sqf";
 */

if (missionNamespace getVariable ["WAIT_AITweaks_PreInitComplete", false]) exitWith {true};

private _config = call compile preprocessFileLineNumbers "\z\waldo_ai_tweaks\addons\main\settings\aiConfig.sqf";
if !(_config isEqualType createHashMap) exitWith {
    diag_log "[Waldos AI Tweaks] settings/aiConfig.sqf did not return a HashMap.";
    false
};

{
    _x params ["_name", "_default"];
    if (isNil {missionNamespace getVariable _name}) then {
        missionNamespace setVariable [_name, _default];
    };
} forEach (_config getOrDefault ["shared", []]);

// CBA Settings owns persisted mission/server configuration. Existing variable names remain the
// public scripting API because CBA deliberately stores each setting in missionNamespace.
[] call WAIT_fnc_AITweaksRegisterSettings;
[] call WAIT_fnc_AITweaksDetectCompatibility;

// Guarded defaults are not yet the effective server settings. CBA refreshes every setting
// after postInit; only that completion event may release owner-local startup.
missionNamespace setVariable ["WAIT_AITweaks_SettingsReady", false];
["CBA_settingsInitialized", {
    missionNamespace setVariable ["WAIT_AITweaks_SettingsReady", true];
    call compile preprocessFileLineNumbers "\z\waldo_ai_tweaks\addons\main\XEH_postInit.sqf";
}] call CBA_fnc_addEventHandler;

["WAIT_AITweaks_LandingReconfigure", {
    [] call WAIT_fnc_ImprovedHelicopterLandingInit;
}] call CBA_fnc_addEventHandler;
missionNamespace setVariable ["WAIT_AITweaks_PreInitComplete", true];
true

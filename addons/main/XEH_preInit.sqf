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

if (missionNamespace getVariable ["Waldo_AITweaks_PreInitComplete", false]) exitWith {true};

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

// Owner-local startup is allowed only after this machine has loaded every guarded default.
missionNamespace setVariable ["Waldo_AITweaks_SettingsReady", true];

if (isServer) then {
    ["Waldo_AITweaks_SettingsRequest", {
        _this call Waldo_fnc_AITweaksSettingsRequestServer;
    }] call CBA_fnc_addEventHandler;
};
["Waldo_AITweaks_LandingReconfigure", {
    [] call Waldo_fnc_ImprovedHelicopterLandingInit;
}] call CBA_fnc_addEventHandler;
missionNamespace setVariable ["Waldo_AITweaks_PreInitComplete", true];
true

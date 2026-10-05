/*
 * Author: WaldoTheWarfighter
 * Purpose: Verify standalone addon initialization, settings catalogue and dependency support.
 * Locality/authority: Dedicated server; reads initialized production state.
 * Repeat/JIP: Each fresh audit runs once; no settings are mutated by these assertions.
 * Arguments: 0 check callback <CODE>, required. Return: Nothing.
 * Current callers: cortexQAServer.sqf. Example: [_check] call compile preprocessFileLineNumbers "cortexQAAddon.sqf";
 */
params ["_check"];
["ADDON-cba-dependency",isClass (configFile >> "CfgPatches" >> "cba_main")] call _check;
["ADDON-optional-dialog-dependency",!("zen_main" in getArray (configFile >> "CfgPatches" >> "WAIT_AI_Tweaks_Main" >> "requiredAddons"))] call _check;
["ADDON-native-convoy-orders",["WAIT_ModuleConvoyStart", "WAIT_ModuleConvoyHold", "WAIT_ModuleConvoyRelease"] findIf {
    getNumber (configFile >> "CfgVehicles" >> _x >> "scopeCurator") != 2
} < 0] call _check;
["ADDON-settings-ready",missionNamespace getVariable ["WAIT_AITweaks_SettingsReady",false]] call _check;
["ADDON-postinit-ready",missionNamespace getVariable ["WAIT_AITweaks_PostInitComplete",false]] call _check;
private _spec=[] call WAIT_fnc_CortexTuningSpec;
["ADDON-setting-values-installed",_spec findIf {isNil {missionNamespace getVariable (_x select 0)}} < 0] call _check;
private _keys=_spec apply {_x select 0};
["ADDON-setting-keys-unique",count _keys == count (_keys arrayIntersect _keys)] call _check;

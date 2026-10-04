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
["ADDON-zen-dependency",isClass (configFile >> "CfgPatches" >> "zen_main")] call _check;
["ADDON-settings-ready",missionNamespace getVariable ["Waldo_AITweaks_SettingsReady",false]] call _check;
["ADDON-postinit-ready",missionNamespace getVariable ["Waldo_AITweaks_PostInitComplete",false]] call _check;
private _spec=[] call Waldo_fnc_CortexTuningSpec;
["ADDON-setting-values-installed",_spec findIf {isNil {missionNamespace getVariable (_x select 0)}} < 0] call _check;
private _keys=_spec apply {_x select 0};
["ADDON-setting-keys-unique",count _keys == count (_keys arrayIntersect _keys)] call _check;

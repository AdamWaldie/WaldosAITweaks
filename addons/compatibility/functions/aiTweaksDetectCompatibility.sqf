/*
 * Author: WaldoTheWarfighter
 * Detects specialist actor controllers and publishes a read-only compatibility capability map.
 * Locality / Authority: Machine-local config and public-function inspection; it changes no external
 * addon state. Eligibility checks consume the result before controlling specialist actors.
 * Repeat/JIP: Repeat-safe. The map may be rebuilt after postInit when optional public APIs appear.
 * Arguments: None.
 * Return Value: HASHMAP - supported addon capability flags.
 * Current callers: XEH_preInit.sqf and WAIT_fnc_CortexInit.
 * Example: private _compat = [] call WAIT_fnc_AITweaksDetectCompatibility;
 */

private _patch = {isClass (configFile >> "CfgPatches" >> _this)};
private _compat = createHashMapFromArray [
    ["meleeBackend", !isNil "IMS_Melee_Weapons" || {"WBK_IMS" call _patch} || {"WBK_IMS2" call _patch}],
    ["specialistBackend", !isNil "WBK_LoadAIThroughEden" || {!isNil "WBK_Droid_B1_Load"}]
];
missionNamespace setVariable ["WAIT_AITweaks_Compatibility", _compat];

// Public flags describe only source-specific specialist ownership. Ordinary driving, naval,
// medical, civilian, coordination and reinforcement behaviour remains WAIT-owned.
missionNamespace setVariable ["WAIT_AIPass_MeleeBackendLoaded", _compat get "meleeBackend"];
missionNamespace setVariable ["WAIT_AIPass_SpecialistBackendLoaded", _compat get "specialistBackend"];
_compat

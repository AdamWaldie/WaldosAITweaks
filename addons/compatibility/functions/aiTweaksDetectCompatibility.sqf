/*
 * Author: WaldoTheWarfighter
 * Detects supported AI addons once and publishes a read-only compatibility capability map.
 * Locality / Authority: Machine-local config and public-function inspection; it changes no external
 * addon state. Behaviour owners consume the result before requesting a finite movement lease.
 * Repeat/JIP: Repeat-safe. The map may be rebuilt after postInit when optional public APIs appear.
 * Arguments: None.
 * Return Value: HASHMAP - supported addon capability flags.
 * Current callers: XEH_preInit.sqf and WAIT_fnc_CortexInit.
 * Example: private _compat = [] call WAIT_fnc_AITweaksDetectCompatibility;
 */

private _patch = {isClass (configFile >> "CfgPatches" >> _this)};
private _compat = createHashMapFromArray [
    ["dangerBackend", "lambs_danger" call _patch],
    ["buildingBackend", "lambs_wp" call _patch],
    ["turretPolicy", "lambs_turrets" call _patch],
    ["suppressionPolicy", "lambs_suppression" call _patch],
    ["launcherPolicy", "lambs_rpg" call _patch],
    ["alternativeBackend", ("VCOM_AI" call _patch) || {!isNil "VCM_fnc_SQUADBEH"}],
    ["meleeBackend", !isNil "IMS_Melee_Weapons" || {"WBK_IMS" call _patch} || {"WBK_IMS2" call _patch}],
    ["webKnight", !isNil "WBK_LoadAIThroughEden" || {!isNil "WBK_Droid_B1_Load"}],
    ["civilianBackend", !isNil "WBK_CivilianFlee"],
    ["drivingBackend", "HBQ_AdvancedDrivingAI" call _patch],
    ["navalBackend", "PROTOCOL_AI_NAVY_SEAL" call _patch],
    ["suppressionBackend", "PinnedDown" call _patch],
    ["surrenderBackend", "mky_surrender_sameas_spe" call _patch],
    ["medicalBackend", "PD_MedicalSolution" call _patch],
    ["supportBackend", "pinneddown_arty" call _patch],
    ["coverBackend", "PD_Cover_And_Concealment" call _patch],
    ["transportBackend", "PD_Tracks_And_Boots" call _patch],
    ["awarenessBackend", "PD_CombatAwareness" call _patch],
    ["coordinationBackend", "PD_Conductor" call _patch],
    ["smartAircraft", "SAAI_main" call _patch],
    ["smartCombat", "SmartCombatAI" call _patch],
    ["smartMerge", "smai_main" call _patch],
    ["helicopterDeceleration", "AHDNC_main" call _patch],
    ["bhlLanding", "BHL_AI" call _patch],
    ["digii", "digii_ai_main" call _patch],
    ["aiCuller", "aic_main" call _patch],
    ["scorpions", "saai_core" call _patch]
];
missionNamespace setVariable ["WAIT_AITweaks_Compatibility", _compat];

// Legacy public flags remain during the transition so existing scripts do not need a flag-day edit.
missionNamespace setVariable ["WAIT_AIPass_DangerBackendLoaded", _compat get "dangerBackend"];
missionNamespace setVariable ["WAIT_AIPass_AlternativeBackendLoaded", _compat get "alternativeBackend"];
missionNamespace setVariable ["WAIT_AIPass_NavalBackendLoaded", _compat get "navalBackend"];
missionNamespace setVariable ["WAIT_AIPass_MeleeBackendLoaded", _compat get "meleeBackend"];
missionNamespace setVariable ["WAIT_AIPass_SpecialistBackendLoaded", _compat get "webKnight"];
missionNamespace setVariable ["WAIT_AIPass_CivilianBackendLoaded", _compat get "civilianBackend"];
missionNamespace setVariable ["WAIT_Cortex_TurretPolicyLoaded", _compat get "turretPolicy"];
missionNamespace setVariable ["WAIT_Cortex_SuppressionPolicyLoaded", _compat get "suppressionPolicy"];
missionNamespace setVariable ["WAIT_Cortex_LauncherPolicyLoaded", _compat get "launcherPolicy"];
_compat

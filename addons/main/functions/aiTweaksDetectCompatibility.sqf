/*
 * Author: WaldoTheWarfighter
 * Detects supported AI addons once and publishes a read-only compatibility capability map.
 * Locality / Authority: Machine-local config and public-function inspection; it changes no external
 * addon state. Behaviour owners consume the result before requesting a finite movement lease.
 * Repeat/JIP: Repeat-safe. The map may be rebuilt after postInit when optional public APIs appear.
 * Arguments: None.
 * Return Value: HASHMAP - supported addon capability flags.
 * Current callers: XEH_preInit.sqf and Waldo_fnc_CortexInit.
 * Example: private _compat = [] call Waldo_fnc_AITweaksDetectCompatibility;
 */

private _patch = {isClass (configFile >> "CfgPatches" >> _this)};
private _compat = createHashMapFromArray [
    ["lambsDanger", "lambs_danger" call _patch],
    ["lambsWaypoints", "lambs_wp" call _patch],
    ["lambsTurrets", "lambs_turrets" call _patch],
    ["lambsSuppression", "lambs_suppression" call _patch],
    ["lambsRpg", "lambs_rpg" call _patch],
    ["vcom", ("VCOM_AI" call _patch) || {!isNil "VCM_fnc_SQUADBEH"}],
    ["ims", !isNil "IMS_Melee_Weapons" || {"WBK_IMS" call _patch} || {"WBK_IMS2" call _patch}],
    ["webKnight", !isNil "WBK_LoadAIThroughEden" || {!isNil "WBK_Droid_B1_Load"}],
    ["simpleCivilian", !isNil "WBK_CivilianFlee"],
    ["hbqDriving", "HBQ_AdvancedDrivingAI" call _patch],
    ["protocolNavy", "PROTOCOL_AI_NAVY_SEAL" call _patch],
    ["pinnedSuppression", "PinnedDown" call _patch],
    ["pinnedSurrender", "mky_surrender_sameas_spe" call _patch],
    ["pinnedMedical", "PD_MedicalSolution" call _patch],
    ["pinnedSupport", "pinneddown_arty" call _patch],
    ["pinnedCover", "PD_Cover_And_Concealment" call _patch],
    ["pinnedTransport", "PD_Tracks_And_Boots" call _patch],
    ["pinnedAwareness", "PD_CombatAwareness" call _patch],
    ["pinnedConductor", "PD_Conductor" call _patch],
    ["smartAircraft", "SAAI_main" call _patch],
    ["smartCombat", "SmartCombatAI" call _patch],
    ["smartMerge", "smai_main" call _patch],
    ["helicopterDeceleration", "AHDNC_main" call _patch],
    ["bhlLanding", "BHL_AI" call _patch],
    ["digii", "digii_ai_main" call _patch],
    ["aiCuller", "aic_main" call _patch],
    ["scorpions", "saai_core" call _patch]
];
missionNamespace setVariable ["Waldo_AITweaks_Compatibility", _compat];

// Legacy public flags remain during the transition so existing scripts do not need a flag-day edit.
missionNamespace setVariable ["Waldo_AIPass_LambsDangerLoaded", _compat get "lambsDanger"];
missionNamespace setVariable ["Waldo_AIPass_VcomLoaded", _compat get "vcom"];
missionNamespace setVariable ["Waldo_AIPass_ProtocolNavyLoaded", _compat get "protocolNavy"];
missionNamespace setVariable ["Waldo_AIPass_IMSLoaded", _compat get "ims"];
missionNamespace setVariable ["Waldo_AIPass_WBKLoaded", _compat get "webKnight"];
missionNamespace setVariable ["Waldo_AIPass_WBKCivilianLoaded", _compat get "simpleCivilian"];
missionNamespace setVariable ["Waldo_Cortex_LambsTurretsLoaded", _compat get "lambsTurrets"];
missionNamespace setVariable ["Waldo_Cortex_LambsSuppressionLoaded", _compat get "lambsSuppression"];
missionNamespace setVariable ["Waldo_Cortex_LambsRpgLoaded", _compat get "lambsRpg"];
_compat

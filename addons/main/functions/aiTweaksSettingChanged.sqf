/*
 * Author: WaldoTheWarfighter
 * Applies side effects after CBA changes a Waldos AI Tweaks setting.
 * Locality / Authority: Called on every machine by a global CBA setting callback. Each machine may
 * only start or stop work it owns; the server remains responsible for cross-group coordination.
 * Repeat/JIP: Idempotent. PreInit callbacks update values but defer runtime work until postInit.
 * Arguments: 0 setting name <STRING>; 1 new value <ANY>.
 * Return Value: BOOL - true when the change was accepted.
 * Current callers: callbacks registered by Waldo_fnc_AITweaksRegisterSettings.
 * Example: ["Waldo_AIPass_Enable", false] call Waldo_fnc_AITweaksSettingChanged;
 */

params [["_name", "", [""]], "_value"];
if (_name == "") exitWith {false};
missionNamespace setVariable [_name, _value];
if !(missionNamespace getVariable ["Waldo_AITweaks_PostInitComplete", false]) exitWith {true};

if (_name == "Waldo_AIPass_Enable") then {
    if (_value) then {[] call Waldo_fnc_CortexInit} else {[] call Waldo_fnc_CortexStop};
};
// These optional handlers must follow CBA changes immediately, including disable/re-enable.
// Reuse the guarded owner-local installer; ordinary tuning values remain live reads.
if (_name in ["Waldo_AIPass_GrenadeEvasion_Enable", "Waldo_AIPass_CivilianReaction_Enable"]
    && {missionNamespace getVariable ["Waldo_AIPass_Active", false]}) then {
    [] call Waldo_fnc_CortexInit;
};
if (_name find "Waldo_AIRebalance_" == 0 || {_name in ["Waldo_AI_InfantryDispersion", "Waldo_AI_VehicleCrewAimMultiplier", "Waldo_AI_VehicleCrewDispersion", "Waldo_AI_AirCrewDispersion"]}) then {
    if (missionNamespace getVariable ["Waldo_AIRebalance_Enable", true]) then {
        [
            missionNamespace getVariable ["Waldo_AIRebalance_Mode", "AUTO"],
            missionNamespace getVariable ["Waldo_AIRebalance_Profile", "LINE"]
        ] call Waldo_fnc_AIRebalanceInit;
    } else {
        [] call Waldo_fnc_AIRebalanceStop;
    };
};
if (_name == "Waldo_ImprovedHelicopterLanding_Enable" && {_value}) then {
    [] call Waldo_fnc_ImprovedHelicopterLandingInit;
};
if (_name == "Waldo_HelicopterDeceleration_Enable" && {_value}) then {
    [] call Waldo_fnc_HelicopterDecelerationInit;
};
true

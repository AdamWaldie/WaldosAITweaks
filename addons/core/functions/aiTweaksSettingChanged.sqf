/*
 * Author: WaldoTheWarfighter
 * Applies side effects after CBA changes a Waldos AI Tweaks setting.
 * Locality / Authority: Called on every machine by a global CBA setting callback. Each machine may
 * only start or stop work it owns; the server remains responsible for cross-group coordination.
 * Repeat/JIP: Idempotent. PreInit callbacks update values but defer runtime work until postInit.
 * Arguments: 0 setting name <STRING>; 1 new value <ANY>.
 * Return Value: BOOL - true when the change was accepted.
 * Current callers: callbacks registered by WAIT_fnc_AITweaksRegisterSettings.
 * Example: ["WAIT_AIPass_Enable", false] call WAIT_fnc_AITweaksSettingChanged;
 */

params [["_name", "", [""]], "_value"];
if (_name == "") exitWith {false};
missionNamespace setVariable [_name, _value];
if !(missionNamespace getVariable ["WAIT_AITweaks_PostInitComplete", false]) exitWith {true};

if (_name == "WAIT_AIPass_Enable") then {
    if (_value) then {[] call WAIT_fnc_CortexInit} else {[] call WAIT_fnc_CortexStop};
};
// These optional handlers must follow CBA changes immediately, including disable/re-enable.
// Reuse the guarded owner-local installer; ordinary tuning values remain live reads.
if (_name in ["WAIT_AIPass_GrenadeEvasion_Enable", "WAIT_AIPass_CivilianReaction_Enable"]
    && {missionNamespace getVariable ["WAIT_AIPass_Active", false]}) then {
    [] call WAIT_fnc_CortexInit;
};
// Danger assessment is a LIVE setting.  Discovery runs sparsely by design, so relying on its next
// sweep would leave disabled observers active, or newly enabled groups unobserved, for up to a
// full discovery interval.  Reuse the bounded, repeat-safe per-group installer on the current
// owner only; this changes listeners and the finite FSM generation, never the scheduler or route.
if (_name == "WAIT_AIPass_Danger_Enable" && {missionNamespace getVariable ["WAIT_AIPass_Active", false]}) then {
    {if (local _x) then {[_x] call WAIT_fnc_DangerSetup}} forEach allGroups;
};
if (_name find "WAIT_AIRebalance_" == 0 || {_name in ["WAIT_AI_InfantryDispersion", "WAIT_AI_VehicleCrewAimMultiplier", "WAIT_AI_VehicleCrewDispersion", "WAIT_AI_AirCrewDispersion"]}) then {
    if (missionNamespace getVariable ["WAIT_AIRebalance_Enable", true]) then {
        [
            missionNamespace getVariable ["WAIT_AIRebalance_Mode", "AUTO"],
            missionNamespace getVariable ["WAIT_AIRebalance_Profile", "LINE"]
        ] call WAIT_fnc_AIRebalanceInit;
    } else {
        [] call WAIT_fnc_AIRebalanceStop;
    };
};
if (_name == "WAIT_ImprovedHelicopterLanding_Enable" && {_value}) then {
    [] call WAIT_fnc_ImprovedHelicopterLandingInit;
};
if (_name == "WAIT_HelicopterDeceleration_Enable" && {_value}) then {
    [] call WAIT_fnc_HelicopterDecelerationInit;
};
true

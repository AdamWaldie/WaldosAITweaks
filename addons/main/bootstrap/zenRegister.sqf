/*
 * Author: WaldoTheWarfighter
 * Registers targeted ZEN orders for the standalone AI package after ZEN is available.
 * Locality / Authority: Run on interface clients only. Order dialogs execute locally and send accepted
 * changes through the package's existing server-authoritative functions.
 * Repeat/JIP: A local version guard prevents duplicate module registration for JIP or repeat calls.
 * Arguments: None.
 * Return Value: BOOL - true when registered; false when ZEN is unavailable or no interface exists.
 * Current callers: XEH_postInit.sqf after CBA/ZEN initialization.
 * Example: [] execVM "\z\waldo_ai_tweaks\addons\main\bootstrap\zenRegister.sqf";
 */

if (!hasInterface || {isNil "zen_custom_modules_fnc_register"}) exitWith {false};
if (missionNamespace getVariable ["WAIT_AITweaks_ZenRegisteredLocal", false]) exitWith {true};
missionNamespace setVariable ["WAIT_AITweaks_ZenRegisteredLocal", true];

["Waldos AI Tweaks", "Create AI Convoy", {
    _this call WAIT_fnc_ZenConvoyModule;
}] call zen_custom_modules_fnc_register;
true

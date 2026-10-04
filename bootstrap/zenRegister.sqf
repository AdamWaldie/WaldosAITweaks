/*
 * Author: WaldoTheWarfighter
 * Registers optional ZEN controls for the standalone AI package after ZEN is available.
 * Locality / Authority: Run on interface clients only. Dialogs execute locally and send accepted
 * changes through the package's existing server-authoritative functions.
 * Repeat/JIP: A local version guard prevents duplicate module registration for JIP or repeat calls.
 * Arguments: None.
 * Return Value: BOOL - true when registered; false when ZEN is unavailable or no interface exists.
 * Current callers: consuming mission initPlayerLocal.sqf after CBA/ZEN initialization.
 * Example: [] execVM "bootstrap\zenRegister.sqf";
 */

if (!hasInterface || {isNil "zen_custom_modules_fnc_register"}) exitWith {false};
if (missionNamespace getVariable ["Waldo_AITweaks_ZenRegisteredLocal", false]) exitWith {true};
missionNamespace setVariable ["Waldo_AITweaks_ZenRegisteredLocal", true];

["Waldos AI Tweaks", "AI Control", {
    [] call Waldo_fnc_CortexControlOpenLocal;
}] call zen_custom_modules_fnc_register;

["Waldos AI Tweaks", "Create AI Convoy", {
    _this call Waldo_fnc_ZenConvoyModule;
}] call zen_custom_modules_fnc_register;
true

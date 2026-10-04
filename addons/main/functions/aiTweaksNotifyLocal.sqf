/*
 * Author: WaldoTheWarfighter
 * Shows concise local feedback through CBA without depending on Waldos Mission Pack UI functions.
 * Locality / Authority: Interface-local presentation only; callers must target the intended player owner.
 * Repeat/JIP: Stateless and safe to repeat; no JIP message is retained.
 * Arguments: 0 title <STRING>; 1 message <STRING>; 2 severity <STRING>, optional; remaining legacy fields ignored.
 * Return Value: BOOL - true when displayed, false without an interface.
 * Current callers: AI order results, convoy warnings and optional ZEN modules.
 * Example: ["CONVOY", "Vehicle blocked", "WARNING"] call Waldo_fnc_AITweaksNotifyLocal;
 */

params [
    ["_title", "Waldos AI Tweaks", [""]],
    ["_message", "", [""]],
    ["_severity", "INFO", [""]]
];
if (!hasInterface) exitWith {false};
private _prefix = switch (toUpperANSI _severity) do {
    case "ERROR": {"ERROR"};
    case "WARNING": {"WARNING"};
    case "SUCCESS": {"SUCCESS"};
    default {"INFO"};
};
[[format ["%1 | %2", _title, _prefix], _message]] call CBA_fnc_notify;
true

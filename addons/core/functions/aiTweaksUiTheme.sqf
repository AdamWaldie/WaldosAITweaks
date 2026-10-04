/*
 * Author: WaldoTheWarfighter
 * Returns the standalone Cortex control panel colours without depending on Waldos Mission Pack UI code.
 * Locality / Authority: Read-only and interface-local.
 * Repeat/JIP: Stateless and safe to repeat.
 * Arguments: None.
 * Return Value: HASHMAP with panel, text and muted RGBA colours.
 * Current callers: CortexControlOpenLocal and CortexControlPageLocal.
 * Example: private _theme = [] call WAIT_fnc_AITweaksUiTheme;
 */

createHashMapFromArray [
    ["panel", [0.02, 0.025, 0.03, 0.96]],
    ["text", [0.92, 0.94, 0.96, 1]],
    ["muted", [0.64, 0.69, 0.74, 1]]
]

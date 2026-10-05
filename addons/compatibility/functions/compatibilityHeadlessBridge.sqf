/*
 * Author: WaldoTheWarfighter
 * Bridges a supported external headless completion signal into WAIT's neutral, destination-local handover event.
 * Locality / Authority: The external manager retains transfer authority. This bridge only emits after the engine
 * confirms group locality on the destination owner; it never selects an HC or changes ownership.
 * Repeat/JIP: Installs one repeat-safe listener per machine. Neutral events may arrive more than once; consumers
 * deduplicate by transfer revision and owner.
 * Arguments: None.
 * Return Value: BOOL - true when the bridge is installed or was already installed.
 * Current callers: WAIT_fnc_CortexInit, WAIT_fnc_AIRebalanceInit and WAIT_fnc_ConvoySync.
 * Example: [] call WAIT_fnc_CompatibilityHeadlessBridge;
 */
if (missionNamespace getVariable ["WAIT_Compatibility_HeadlessBridgeInstalled", false]) exitWith {true};
missionNamespace setVariable ["WAIT_Compatibility_HeadlessBridgeInstalled", true];

["Waldo_Headless_GroupMigrated", {
    params [
        ["_group", grpNull, [grpNull]],
        ["_previousOwner", 2, [0]],
        ["_newOwner", -1, [0]]
    ];
    if (isNull _group || {!isServer && {hasInterface}} || {clientOwner != _newOwner} || {!local _group}) exitWith {};
    ["WAIT_Compatibility_HeadlessMigrated", [_group, _previousOwner, _newOwner, "COMPANION"]] call CBA_fnc_globalEvent;
}] call CBA_fnc_addEventHandler;

true

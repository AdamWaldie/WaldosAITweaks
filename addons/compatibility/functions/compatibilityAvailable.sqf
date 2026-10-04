/*
 * Author: WaldoTheWarfighter
 * Returns whether a semantic external-controller capability is available.
 * Locality / Authority: Read-only on any machine; detection owns the snapshot.
 * Repeat/JIP: Stateless and repeat-safe; reads the local compatibility snapshot on JIP.
 * Arguments: 0 capability <STRING>, default empty.
 * Return Value: BOOL - capability availability.
 * Current callers: building, profile, locality and diagnostics services.
 * Example: ["buildingBackend"] call WAIT_fnc_CompatibilityAvailable;
 */

params [["_capability","",[""]]];
(missionNamespace getVariable ["WAIT_AITweaks_Compatibility",createHashMap]) getOrDefault [_capability,false]

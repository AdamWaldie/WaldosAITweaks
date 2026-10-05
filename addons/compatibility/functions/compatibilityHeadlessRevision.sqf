/*
 * Author: WaldoTheWarfighter
 * Validates an external headless-manager adoption record and exposes only its monotonic revision.
 * Locality / Authority: Read-only; must run where the adopted group is now local.
 * Repeat/JIP: Stateless and repeat-safe. A missing or incomplete external record returns -1.
 * Arguments: 0 group <GROUP>; 1 destination owner <NUMBER>; 2 provider <STRING>, default "EXTERNAL".
 * Return Value: NUMBER - validated transfer revision, or -1 when no compatible confirmation exists.
 * Current callers: WAIT_fnc_AIHeadlessAdoptLocal and WAIT_fnc_ConvoyHeadlessAdoptLocal.
 * Example: [group player, clientOwner, "COMPANION"] call WAIT_fnc_CompatibilityHeadlessRevision;
 */
params [
    ["_group", grpNull, [grpNull]],
    ["_newOwner", -1, [0]],
    ["_provider", "EXTERNAL", [""]]
];
if (isNull _group || {_newOwner < 2} || {(toUpperANSI _provider) != "COMPANION"}) exitWith {-1};

private _record = [_group, _newOwner] call WAIT_fnc_CompatibilityHeadlessRecord;
if (_record isEqualTo []) exitWith {-1};
_record select 0

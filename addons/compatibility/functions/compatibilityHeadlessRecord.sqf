/*
 * Author: WaldoTheWarfighter
 * Returns a validated external headless adoption record for diagnostics and continuation checks.
 * Locality / Authority: Read-only and safe on any machine; it does not change group ownership.
 * Repeat/JIP: Stateless. JIP receives the public record when the compatible manager published one.
 * Arguments: 0 group <GROUP>; 1 owner <NUMBER>, default current group owner.
 * Return Value: ARRAY - [revision, destinationOwner, completed, appliedCount] or [] when unavailable.
 * Current callers: WAIT_fnc_AIGetDiagnostics and WAIT_fnc_CompatibilityHeadlessRevision.
 * Example: [group player] call WAIT_fnc_CompatibilityHeadlessRecord;
 */
params [
    ["_group", grpNull, [grpNull]],
    ["_owner", -1, [0]]
];
if (isNull _group) exitWith {[]};
if (_owner < 0) then {_owner = groupOwner _group};

private _record = _group getVariable ["Waldo_Headless_LastAdoption", []];
if (count _record < 3 || {(_record select 1) != _owner} || {!(_record select 2)}) exitWith {[]};
_record

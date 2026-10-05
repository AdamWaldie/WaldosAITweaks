/*
 * Author: WaldoTheWarfighter
 * Normalizes standalone AI diagnostics into a stable report without the WAIT diagnostics runtime.
 * Locality / Authority: Pure report construction on the caller; no authoritative state is changed.
 * Repeat/JIP: Stateless and safe to repeat; no JIP data is retained.
 * Arguments: 0 feature key <STRING>; 1 rows <ARRAY of [area, feature, state, detail]>.
 * Return Value: HASHMAP containing schema, feature, state, checks, error count, time and locality.
 * Current callers: WAIT_fnc_AIGetDiagnostics.
 * Example: ["ai", [["ai", "cortex", "ACTIVE", "12 managed groups"]]] call WAIT_fnc_AITweaksDiagnosticReport;
 */

params [["_feature", "ai", [""]], ["_checks", [], [[]]]];
private _errors = {_x param [2, "ERROR"] == "ERROR"} count _checks;
private _state = if (_checks isEqualTo []) then {"UNCONFIGURED"} else {
    if (_errors > 0) then {"ERROR"} else {
        if (_checks findIf {(_x param [2, ""]) == "ACTIVE"} >= 0) then {"ACTIVE"} else {
            if (_checks findIf {(_x param [2, ""]) == "LOADED"} >= 0) then {"LOADED"} else {
                (_checks select 0) param [2, "UNCONFIGURED"]
            }
        }
    }
};
createHashMapFromArray [
    ["schema", 1], ["feature", _feature], ["state", _state], ["checks", _checks],
    ["errorCount", _errors], ["generatedAt", diag_tickTime],
    ["locality", if (isServer) then {if (hasInterface) then {"HOST"} else {"SERVER"}} else {"CLIENT"}],
    ["clientOwner", clientOwner]
]

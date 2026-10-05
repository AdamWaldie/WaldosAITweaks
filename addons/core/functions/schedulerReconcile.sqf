/*
 * Author: WaldoTheWarfighter
 * Maintains one shared callback and retains only jobs belonging to enabled owner-local runtimes.
 * Locality / Authority: Local runtime lifecycle only; does not change CBA settings or other owners.
 * Repeat/JIP: Idempotent. Each joining owner creates its own callback after effective settings readiness.
 * Arguments: None.
 * Return Value: BOOL - true while at least one local runtime needs the scheduler.
 * Current callers: CortexInit/Stop and AIRebalanceInit/Stop.
 * Example: [] call WAIT_fnc_SchedulerReconcile;
 */
private _tactics = missionNamespace getVariable ["WAIT_AIPass_Active", false];
private _skills = missionNamespace getVariable ["WAIT_AI_RebalanceActive", false];
private _convoy = missionNamespace getVariable ["WAIT_Convoy_SchedulerActive", false];
private _generation = missionNamespace getVariable ["WAIT_AI_LightingGeneration", 0];
private _earliest = -1;
{
    private _retained = (missionNamespace getVariable [_x, []]) select {
        private _state = _x select 2;
        switch (_state getOrDefault ["subsystem", "TACTICS"]) do {
            case "SKILLS": {_skills && {(_state getOrDefault ["generation", -1]) == _generation}};
            case "CONVOY": {_convoy};
            default {_tactics};
        }
    };
    {
        private _due = _x select 0;
        if (_earliest < 0 || {_due < _earliest}) then {_earliest = _due};
    } forEach _retained;
    missionNamespace setVariable [_x, _retained];
} forEach ["WAIT_AIPass_Jobs", "WAIT_AIPass_PendingJobs"];
missionNamespace setVariable ["WAIT_AIPass_NextJobDue", _earliest];
private _handle = missionNamespace getVariable "WAIT_AIPass_SchedulerHandle";
if (_tactics || {_skills} || {_convoy}) then {
    if (isNil "_handle") then {
        missionNamespace setVariable ["WAIT_AIPass_SchedulerHandle",
            [{[] call WAIT_fnc_CortexSchedulerTick}, 0] call CBA_fnc_addPerFrameHandler];
    };
} else {
    if (!isNil "_handle") then {
        [_handle] call CBA_fnc_removePerFrameHandler;
        missionNamespace setVariable ["WAIT_AIPass_SchedulerHandle", nil];
    };
};
_tactics || {_skills} || {_convoy}

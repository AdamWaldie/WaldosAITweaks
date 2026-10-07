/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Adds one job to this machine's Smart AI Pass scheduler.
 *
 * A job is code that takes one state HASHMAP and returns the number of seconds until it should run
 * again, or -1 when it has finished. Jobs never sleep: the scheduler runs them unscheduled inside a
 * per-tick time budget. New jobs wait in a pending list that the next tick merges, so a job may
 * safely queue another job while it runs. The earliest queued due time is cached so the frame
 * scheduler callback can return without walking every group while all work is still waiting.
 * Locality and authority: machine-local. Jobs and their state are never broadcast.
 *
 * Arguments:
 * 0: job <CODE> - receives [state] and returns the next delay in seconds or -1
 * 1: state <HASHMAP> - job-owned state carried between runs
 * 2: delay <NUMBER> - seconds before the first run (optional, default: 0)
 * 3: jobKey <STRING> - optional owner-local key. A later job with this key updates and wakes the existing callback instead of appending a competing callback.
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [WAIT_fnc_CortexRegroupStep, createHashMapFromArray [["group", _group]], 5] call WAIT_fnc_CortexQueueJob;
 * Result: the regroup step runs on this machine about five seconds later.
 *
 * Current callers: WAIT_fnc_CortexRegroupOnKill.
 */

params [["_job", {}, [{}]], ["_state", createHashMap, [createHashMap]], ["_delay", 0, [0]], ["_jobKey", "", [""]]];
private _group = _state getOrDefault ["group", grpNull];
if (!isNull _group) then {_state set ["ownerEpoch", _group getVariable ["WAIT_AIPass_Epoch", 0]]};
if (_jobKey == "") then {_jobKey = _state getOrDefault ["jobKey", ""]};
if (_jobKey != "") then {_state set ["jobKey", _jobKey]};
private _dueAt = time + (_delay max 0);
// Only callers with a deliberate, stable key are coalesced. This keeps independent grenade,
// artillery and group operations separate while a burst of updates for the same owner wakes its
// existing finite callback immediately.
if (_jobKey != "") then {
    private _existingState = createHashMap;
    private _found = false;
    {
        private _candidateState = _x param [2, createHashMap, [createHashMap]];
        if ((_candidateState getOrDefault ["jobKey", ""]) == _jobKey) exitWith {
            _existingState = _candidateState;
            _found = true;
        };
    } forEach ((missionNamespace getVariable ["WAIT_AIPass_Jobs", []]) + (missionNamespace getVariable ["WAIT_AIPass_PendingJobs", []]));
    if (_found) exitWith {
        {_existingState set [_x, _y]} forEach _state;
        _existingState set ["wakeAt", _dueAt];
        private _nextDue = missionNamespace getVariable ["WAIT_AIPass_NextJobDue", -1];
        if (_nextDue < 0 || {_dueAt < _nextDue}) then {missionNamespace setVariable ["WAIT_AIPass_NextJobDue", _dueAt]};
    };
};
private _pending = missionNamespace getVariable ["WAIT_AIPass_PendingJobs", []];
_pending pushBack [_dueAt, _job, _state];
missionNamespace setVariable ["WAIT_AIPass_PendingJobs", _pending];
private _nextDue = missionNamespace getVariable ["WAIT_AIPass_NextJobDue", -1];
if (_nextDue < 0 || {_dueAt < _nextDue}) then {missionNamespace setVariable ["WAIT_AIPass_NextJobDue", _dueAt]};


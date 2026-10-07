/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Each invocation processes due jobs within the local budget. Joining owners have independent queues; jobs are not replayed across machines.
 * Runs due Smart AI Pass jobs on this machine with a soft time budget between jobs.
 *
 * Called by one CBA handler every frame on a machine with an active owner-local subsystem. Ground
 * tactics normally run on the server or a headless client; an interface machine only participates
 * when it genuinely owns an eligible aircraft. The cached deadline makes frames with no due work
 * constant-time. At least one due job runs
 * on a due frame; the rest run only while
 * WAIT_AIPass_TickBudgetMs remains. Jobs that do not fit wait for the next tick, which keeps
 * new jobs from starting after the budget is spent. A running job cannot be pre-empted and can
 * exceed the budget. An earliest-due cache makes idle callbacks constant-time instead of traversing
 * the complete group queue. Due processing still traverses the queue once and
 * jobs move to the back, so no group is starved when the budget is always spent. When the machine's FPS is below
 * WAIT_AIPass_LowFpsThreshold, rescheduling delays are doubled. While ENDEX or SafeStart is
 * active, due jobs are postponed by five seconds and never run. The pause refreshes a one-minute
 * resumption grace used by tactical-drill watchdogs, so deferred work is not mistaken for starvation.
 * Locality and authority: machine-local. It performs no world scans. Changed restoration checkpoints are published after group jobs.
 *
 * Review contract: The scheduler is machine-local and repeat-driven by CBA. Its budget is soft: it cannot interrupt a running SQF job and still traverses the full queue.
 * Danger assessment: bounded member events use generation-scoped finite FSMs and only wake the existing
 * group decision job; handlers retire on membership/owner changes and shutdown. No second movement owner.
 *
 * Arguments: None.
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [] call WAIT_fnc_CortexSchedulerTick;
 * Result: due jobs run and are rescheduled or retired.
 *
 * Current caller: the shared per-frame handler installed by WAIT_fnc_SchedulerReconcile.
 */

if (!(missionNamespace getVariable ["WAIT_AIPass_Active", false])
    && {!(missionNamespace getVariable ["WAIT_AI_RebalanceActive", false])}
    && {!(missionNamespace getVariable ["WAIT_Convoy_SchedulerActive", false])}
    && {!(missionNamespace getVariable ["WAIT_Aircraft_SchedulerActive", false])}) exitWith {};
private _jobs = missionNamespace getVariable ["WAIT_AIPass_Jobs", []];
private _pending = missionNamespace getVariable ["WAIT_AIPass_PendingJobs", []];
private _now = time;
if (_pending isEqualTo [] && {_now < (missionNamespace getVariable ["WAIT_AIPass_NextJobDue", -1])}) exitWith {};
if (_pending isNotEqualTo []) then {
    _jobs append _pending;
    missionNamespace setVariable ["WAIT_AIPass_PendingJobs", []];
};
if (_jobs isEqualTo []) exitWith {
    missionNamespace setVariable ["WAIT_AIPass_Jobs", []];
    missionNamespace setVariable ["WAIT_AIPass_NextJobDue", -1];
};

private _start = diag_tickTime;
private _budget = ((missionNamespace getVariable ["WAIT_AIPass_TickBudgetMs", 1]) max 0.2) / 1000;
private _slow = diag_fps < (missionNamespace getVariable ["WAIT_AIPass_LowFpsThreshold", 25]);
private _paused = [] call WAIT_fnc_CortexIsPaused;
// Deferred tactical jobs must not look starved immediately after a deliberate SafeStart or
// ENDEX pause. Refreshing this grace deadline while paused gives every owner queue one minute
// after play resumes to execute its existing drill callback.
if (_paused) then {missionNamespace setVariable ["WAIT_AIPass_ResumeGraceUntil",_now+60]};
private _processed = 0;
private _next = [];
private _rescheduled = [];
private _earliest = -1;
{
    _x params ["_dueAt", "_job", "_state"];
    _dueAt = _dueAt min (_state getOrDefault ["wakeAt",_dueAt]);
    if (_dueAt > _now || {_processed > 0 && {diag_tickTime - _start >= _budget}}) then {
        _next pushBack _x;
        if (_earliest < 0 || {_dueAt < _earliest}) then {_earliest = _dueAt};
    } else {
        _state deleteAt "wakeAt";
        _processed = _processed + 1;
        private _subsystem = _state getOrDefault ["subsystem", "TACTICS"];
        private _skillsJob = _subsystem == "SKILLS";
        private _enabledFlag = switch (_subsystem) do {
            case "SKILLS": {"WAIT_AI_RebalanceActive"};
            case "CONVOY": {"WAIT_Convoy_SchedulerActive"};
            case "AIRCRAFT": {"WAIT_Aircraft_SchedulerActive"};
            default {"WAIT_AIPass_Active"};
        };
        private _enabled = missionNamespace getVariable [_enabledFlag, false];
        // Skill refresh is intentionally live during a tactical pause. Convoys and aircraft are
        // likewise safety-critical: existing motion assistance must not become stale because an
        // unrelated infantry ENDEX or safe-start gate is active.
        private _jobPaused = _paused && {!_skillsJob};
        if (_subsystem in ["CONVOY", "AIRCRAFT"]) then {_jobPaused=false};
        private _group = _state getOrDefault ["group", grpNull];
        private _stale = !_enabled || {!isNull _group && {!local _group || {(_state getOrDefault ["ownerEpoch", -1]) != (_group getVariable ["WAIT_AIPass_Epoch", 0])}}};
        private _callbackStarted=diag_tickTime;
        private _delay = if (_stale) then {-1} else {if (_jobPaused) then {5} else {[_state] call _job}};
        _state set ["lastCallbackMs",(diag_tickTime-_callbackStarted)*1000];
        _state set ["queueLatency",(_now-_dueAt) max 0];
        _state set ["lastRunAt",_now];
        // Diagnostics describe the current queued state, not an old transient skip. A paused job
        // remains intentionally queued, while a later successful callback clears its previous
        // pause marker before it is reported as healthy again.
        if (_stale) then {
            _state set ["skippedReason",if (!_enabled) then {"DISABLED"} else {"LOCALITY"}]
        } else {
            if (_jobPaused) then {_state set ["skippedReason","PAUSED"]} else {_state deleteAt "skippedReason"};
        };
        if (!_stale && {!_paused} && {!isNull _group}) then {[_group] call WAIT_fnc_CortexCheckpoint};
        if (!isNil "_delay" && {_delay isEqualType 0} && {_delay >= 0}) then {
            // A finite danger response has already been observed locally. Preserve its prompt
            // reassessment under low FPS; only optional planning keeps the normal backoff. The
            // marker lives on this existing job and expires without another scheduler/loop.
            private _responsive = _now < (_state getOrDefault ["responsiveUntil",-1]);
            if (_slow && {!_jobPaused} && {!_skillsJob} && {_subsystem != "CONVOY"} && {!_responsive}) then {_delay = _delay * 2};
            _rescheduled pushBack [_now + _delay, _job, _state];
            private _rescheduledAt = _now + _delay;
            if (_earliest < 0 || {_rescheduledAt < _earliest}) then {_earliest = _rescheduledAt};
        };
    };
} forEach _jobs;
// Jobs that just ran move behind those still waiting, so a full budget rotates fairly.
_next append _rescheduled;
missionNamespace setVariable ["WAIT_AIPass_Jobs", _next];
missionNamespace setVariable ["WAIT_AIPass_NextJobDue", _earliest];

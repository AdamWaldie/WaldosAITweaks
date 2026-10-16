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
 * the complete group queue. Wake requests raised during a callback are merged after traversal,
 * including earlier jobs already skipped; the cache never hides their updated due time.
 * Aircraft runtime retirement counts retained and pending jobs, so a callback-queued successor
 * remains eligible for the next tick rather than being discarded by lifecycle reconciliation.
 * Due processing still traverses the queue once and
 * jobs move to the back, so no group is starved when the budget is always spent. When the machine's FPS is below
 * WAIT_AIPass_LowFpsThreshold, rescheduling delays are doubled. While ENDEX or SafeStart is
 * active, due jobs are postponed by five seconds and never run. The pause refreshes a one-minute
 * resumption grace used by tactical-drill watchdogs, so deferred work is not mistaken for starvation.
 * Locality and authority: machine-local. It performs no world scans. Changed restoration checkpoints are published after group jobs.
 * The latest 256 executed callbacks retain duration, lateness and bounded job identity in a local
 * ring, including callbacks which retire immediately. Paused/stale skips are not timing samples.
 * The ring has no JIP/network replay and is not a matched frame-time overhead measurement.
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

// Isolate wake requests raised during this traversal from the previous idle cache.
// QueueJob may update a previously skipped state after its old due time was sampled.
missionNamespace setVariable ["WAIT_AIPass_NextJobDue", -1];
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
        private _stale = !_enabled || {"group" in _state && {isNull _group || {!local _group} || {(_state getOrDefault ["ownerEpoch", -1]) != (_group getVariable ["WAIT_AIPass_Epoch", 0])}}};
        private _callbackStarted=diag_tickTime;
        private _delay = if (_stale) then {-1} else {if (_jobPaused) then {5} else {[_state] call _job}};
        private _callbackMs=(diag_tickTime-_callbackStarted)*1000;
        private _queueLatency=(_now-_dueAt) max 0;
        _state set ["lastCallbackMs",_callbackMs];
        _state set ["queueLatency",_queueLatency];
        // Retain terminal callbacks too: their state leaves the queue below. One fixed-size
        // owner-local ring uses the timers already collected here, with no extra worker,
        // sort, world query or network publication on this recurring path.
        if (!_stale && {!_jobPaused}) then {
            private _samples=missionNamespace getVariable ["WAIT_AIPass_CallbackSamples",[]];
            private _cursor=missionNamespace getVariable ["WAIT_AIPass_CallbackSampleCursor",0];
            _samples set [_cursor,[_subsystem,(_state getOrDefault ["jobKey",""]) select [0,160],
                _callbackMs,_queueLatency,_callbackStarted]];
            missionNamespace setVariable ["WAIT_AIPass_CallbackSamples",_samples];
            missionNamespace setVariable ["WAIT_AIPass_CallbackSampleCursor",(_cursor+1) mod 256];
        };
        _state set ["lastRunAt",_now];
        // Diagnostics describe the current queued state, not an old transient skip. A paused job
        // remains intentionally queued, while a later successful callback clears its previous
        // pause marker before it is reported as healthy again.
        if (_stale) then {
            private _discardReason=if (!_enabled) then {"DISABLED"} else {"LOCALITY"};
            _state set ["skippedReason",_discardReason];
            // A finite FSM must observe terminal rejection, not wait for its watchdog
            // to retry a callback which this scheduler has already discarded. Retire
            // only this queued brain; its guarded FSM cleanup owns any restoration.
            if ("pending" in _state && {"completed" in _state}) then {
                _state set ["pending",false];
                _state set ["completed",true];
                _state set ["cancelled",true];
                _state set ["cancelReason",_discardReason];
            }
        } else {
            if (_jobPaused) then {_state set ["skippedReason","PAUSED"]} else {_state deleteAt "skippedReason"};
        };
        if (!_stale && {!_paused} && {!isNull _group}) then {[_group] call WAIT_fnc_CortexCheckpoint};
        if (!isNil "_delay" && {_delay isEqualType 0} && {_delay >= 0}) then {
            // A finite danger response has already been observed locally. Preserve its prompt
            // reassessment under low FPS; only optional planning keeps the normal backoff. The
            // marker lives on this existing job and expires without another scheduler/loop.
            private _responsive = _now < (_state getOrDefault ["responsiveUntil",-1]);
            if (_slow && {!_jobPaused} && {!_skillsJob} && {!(_subsystem in ["CONVOY", "AIRCRAFT"])} && {!_responsive}) then {_delay = _delay * 2};
            // A callback can wake its own keyed operation while it runs. Include that wake
            // in the idle cache, otherwise the early-return gate hides it until the long delay.
            private _rescheduledAt = (_now + _delay) min (_state getOrDefault ["wakeAt",_now + _delay]);
            _rescheduled pushBack [_rescheduledAt, _job, _state];
            if (_earliest < 0 || {_rescheduledAt < _earliest}) then {_earliest = _rescheduledAt};
        };
    };
} forEach _jobs;
// Jobs that just ran move behind those still waiting, so a full budget rotates fairly.
_next append _rescheduled;
missionNamespace setVariable ["WAIT_AIPass_Jobs", _next];
private _raisedDue=missionNamespace getVariable ["WAIT_AIPass_NextJobDue",-1];
if (_raisedDue >= 0 && {_earliest < 0 || {_raisedDue < _earliest}}) then {_earliest=_raisedDue};
missionNamespace setVariable ["WAIT_AIPass_NextJobDue", _earliest];
// Aircraft observers activate the scheduler only on machines which currently own eligible
// aircraft. When the final generation-scoped job retires, release that runtime; class/locality
// handlers will reacquire it if another eligible aircraft becomes local later.
if (
    missionNamespace getVariable ["WAIT_Aircraft_DecelerationSchedulerActive", false]
    || {missionNamespace getVariable ["WAIT_Aircraft_LandingSchedulerActive", false]}
) then {
    private _aircraftStates = ((_next + (missionNamespace getVariable ["WAIT_AIPass_PendingJobs", []])) apply {_x select 2}) select {(_x getOrDefault ["subsystem", ""]) == "AIRCRAFT"};
    private _decelerationActive = (_aircraftStates findIf {(_x getOrDefault ["jobKey", ""]) find "WAIT_DECEL_" == 0}) >= 0;
    private _landingActive = (_aircraftStates findIf {(_x getOrDefault ["jobKey", ""]) find "WAIT_LANDING_" == 0}) >= 0;
    private _changed = _decelerationActive != (missionNamespace getVariable ["WAIT_Aircraft_DecelerationSchedulerActive", false])
        || {_landingActive != (missionNamespace getVariable ["WAIT_Aircraft_LandingSchedulerActive", false])};
    missionNamespace setVariable ["WAIT_Aircraft_DecelerationSchedulerActive", _decelerationActive];
    missionNamespace setVariable ["WAIT_Aircraft_LandingSchedulerActive", _landingActive];
    if (_changed) then {[] call WAIT_fnc_SchedulerReconcile};
};

# Matched performance validation

Build and seal a clean committed candidate first. Run each command only after the preceding game batch has completed and its processes have been retired. These are dedicated-server patrol measurements with a protected observer and native Zeus, not combat-effectiveness acceptance.

```powershell
./releaseVerificationAndDeployment/launch_mod_audit.ps1 -Focus standaloneperformance -PerformanceComposition infantry -NativeBaseline -HeadlessClients 0
./releaseVerificationAndDeployment/launch_mod_audit.ps1 -Focus standaloneperformance -PerformanceComposition infantry -HeadlessClients 0
./releaseVerificationAndDeployment/launch_mod_audit.ps1 -Focus standaloneperformance -PerformanceComposition mixed -NativeBaseline -HeadlessClients 0
./releaseVerificationAndDeployment/launch_mod_audit.ps1 -Focus standaloneperformance -PerformanceComposition mixed -HeadlessClients 0
```

Use the configured Python path when it is unavailable on PATH. The launcher defaults to 3840×2160, CBA and a visible observer client. Optional dependencies must match within each pair. `-StageOnly` prepares fixtures without launching; `-NativeBaseline` omits WAIT from every process's mod list and is restricted to this focus.

Infantry uses 50 six-person groups. Mixed uses 25 infantry groups, 15 crewed vehicles, five helicopters and five fixed-wing aircraft. Aircraft start airborne with velocity. Each run warms up for 20 seconds and samples frame time for 60 seconds. All 50 groups must physically move, actors must survive, ownership must stay on the server and the observer must remain alive. Mixed aircraft must remain mobile and airborne.

```powershell
python releaseVerificationAndDeployment/report_standalone_performance.py <native-runtime> <wait-runtime> --output <report.json>
```

The report rejects incomplete/erroring runs, inconsistent addon/FSM identity, differing fixture hashes, dependencies, resolution, ownership composition or dirty candidates. Patrol overhead must be at most 5% median and 10% p95. A passing report covers only its named patrol composition. Combat load, scheduler queue growth, stalled operations and full subsystem acceptance still require separate evidence. No patrol measurements are accepted yet.


## Native headless integration

Use `launch_mod_audit.ps1 -Focus lifecycle -BatchMode headless -HeadlessClients 2 -HeadlessProvider <local companion repository>` for the explicit native transfer/adoption matrix. The launcher copies the actual headless provider into the disposable mission, records hashes for every copied and generated file, and loads it on the server, observer and headless machines. These scripts are audit dependencies and are not included in WAIT PBOs.

This fixture tests native registration, transfer, refusal policy and destination adoption. Automatic distribution is deliberately delayed by the fixture's one-hour minimum group age; balancing and disconnect recovery require separate acceptance. Skill rebalancing stays disabled in this fixture. Existing ordinary engine-only migration tests remain available without the provider option and do not prove native integration.

Native refusal excludes the group from the management registry while retaining its current engine owner. The integration case verifies that policy and the actual adoption result. Do not fabricate registry entries to satisfy the standalone expectation. Integration remains pending physical validation.

Normal audit batches default to zero headless clients. Run HC ownership and migration acceptance separately with `-BatchMode headless -HeadlessClients 2`; embedded migration cases are omitted from normal results, never reported as passes. Both batches require their own packaged-candidate evidence.

## Callback cost attribution

The existing scheduler retains its latest 256 executed callbacks in an owner-local ring, including finite callbacks which have already left the queue. Each sample contains `[subsystem, boundedJobKey, callbackMilliseconds, queueLatencySeconds, localDiagTickTime]`. Recording reuses existing timers, performs one ring-slot replacement and adds no worker, world scan or network publication. Paused and stale skips are excluded. The ring persists for the mission session and overwrites its oldest slot; it is neither JIP state nor a full-run trace.

The server's on-demand `cortex-callback-samples` diagnostic reports sample count/age, nearest-rank p50/p95 callback duration, p95 queue latency and the eight slowest recorded identities. Empty history is `NOT_SAMPLED`, never a pass. Headless/client samples remain on their respective owners and are available there as `missionNamespace getVariable ["WAIT_AIPass_CallbackSamples",[]]`; the server report does not aggregate or represent those owners.

Use this attribution to locate expensive callbacks during later audits, especially convoy ticks and building work. Percentiles mix the retained workload and include observation overhead, but exclude scheduler bookkeeping/checkpoint work outside each timed callback. They cannot establish the 5% median/10% p95 frame-time budget; the matched native/WAIT measurements above remain required.

The distributed contact/mixed performance sampler reads the same bounded callback ring once per second on each measured owner. Only entries whose local `diag_tickTime` falls inside the current measurement window contribute to its callback/queue-latency diagnostic maxima. This includes terminal driving and operation callbacks that have already left the queue. Entries overwritten between reads can still be missed; these are observed maxima, not a complete trace. Queue depth and overdue-job readings remain separate. The audit-only ring reader adds at most 256 entry inspections per second per measured owner and no network publication until its existing terminal report. Frame sampling includes this audit instrumentation; it does not establish the cost of the production scheduler by itself. Physical validation remains pending while audits are held.

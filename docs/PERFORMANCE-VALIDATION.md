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

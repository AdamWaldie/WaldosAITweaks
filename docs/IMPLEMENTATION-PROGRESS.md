# Standalone conversion progress

## Implemented and statically checked

- Breaking WAIT function, setting, state and event namespace migration without forwarding aliases.
- Only CBA and ZEN as required external infrastructure; native danger stays active.
- Core, infantry, vehicles, aircraft, support and compatibility PBOs with one shared scheduler.
- Settings-only ZEN panel and its independent variable-writing bridge removed; CBA is the configuration UI.
- Runtime tuning uses the CBA server layer instead of independently publishing effective values.
- Behaviour-based capability registry; source inventory and fingerprints removed from tracked content.
- Cross-product detection and ownership markers preserved within interoperability boundaries.
- Technical controller identifiers isolated in compatibility adapters and their tests; neutral diagnostics, audit labels and internal APIs.
- Existing audit cases retained; bootstrap sources added to feature coverage.
- Published history rewritten across all five branches after a verified external recovery backup; review recreated as PR #6 and package resealed against the new history.
- Every current CBA setting has explicit live or next-operation activation metadata, shared by the options help, validation and generated reference.
- Independent client settings snapshot writer removed; CBA alone synchronizes effective configuration and invokes worker callbacks.

- Legacy start/stop APIs request CBA changes instead of publishing a second enable/profile state or keyed JIP initializer; headless startup uses the effective CBA state.
- Startup readiness follows the CBA settings-initialized event after effective server values refresh, rather than the guarded pre-init defaults.
- Repeated skill startup before settings readiness shares a cancellable waiter and reads the joining owner's current effective profile.
- Existing survivor recovery, flank bounds, suppression, landing and braking controls exposed through the authoritative settings specification without changing production defaults.

- Skills and tactics now share one generation-aware owner-local scheduler; disabling either retains the other runtime's jobs and the last runtime releases the callback. Skill refresh retains a ten-unit budget.
- Additive scheduler audits exercise measured skill refresh while tactics are off, callback cleanup and physical movement while skills are off; live evidence is pending.

## Still outstanding

- Original danger FSM, optional engine-policy PBOs and remaining medical/behaviour implementations.
- Remaining CBA configuration gaps and physical validation of activation behaviour.
- Deep assessment of every remaining method, including simulation/recovery shortcut purpose.
- Building, manoeuvre, aircraft and coordination fixes and fresh batched physical acceptance.
- JIP, headless migration, CBA server enforcement and 50 mixed-group measured performance.

External Git bundles preserve recovery. GitHub PR history, forks and caches can retain old content
after a ref rewrite; removal is not universal. Static success is not live acceptance.

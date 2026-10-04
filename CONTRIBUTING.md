# Contributing to Waldos AI Tweaks

Keep AI work in its semantic subsystem. Preserve feature gates, tactical intent, public APIs and compatibility ownership. WMP mission systems, Dynamic AA and Dynamic AO stay outside this repository.

## Source documentation

Every SQF file, including audit helpers, starts with a useful documentation block. Name `WaldoTheWarfighter` as author. Explain purpose, execution locality and authority, repeat safety and JIP behaviour. Document arguments with types and defaults, the return value, current callers and a working example. A config include may precede the block. Describe what the function actually does; do not substitute a generic promise of multiplayer safety.

Document FSM transitions and addon/config changes alongside their owning feature. State who starts the work, who owns it, what ends or cancels it and what cleanup restores. Never restore a value over a newer Zeus or mission order.

## Feature documentation

Each changed feature needs a guide containing:

- Expected behaviour and tactical purpose, including the observable manoeuvre.
- Triggers, prerequisites, start/end conditions, transitions and interruption by Zeus.
- CBA controls, defaults, ranges and public script examples with typed arguments.
- Locality, authority, JIP replay, headless-client migration and cleanup.
- Required/optional dependencies, compatibility ownership and handover.
- Casualty replacement, stuck/separated actors and other contingencies.
- Performance cost, scan limits, cache lifetime and scheduling budget.
- Audit cases, measured results, known limitations and outstanding live retests.

Keep the README as the installation and first-use entry point. Link new guides from it or the inventory. Regenerate [the settings reference](docs/SETTINGS-REFERENCE.md) when the shared tuning specification changes. Retained WMP guides describe the extracted script design; they are historical context, not proof of addon acceptance.

Keep PR descriptions current with the final scope. List changed behaviour, controls/defaults, dependencies, ownership and validation. Clearly separate static/package checks from live game evidence. Record breaking changes and migration instructions before a release.

## Required checks

Run `releaseVerificationAndDeployment/build_mod.ps1` for the sequential local pipeline. It runs unit tests, SQF structure checks, config checks, source/documentation contracts, CBA/Zeus/script parity, performance regression checks, feature coverage, HEMTT compilation, FSM validation and package sealing. CI runs the same checks for builds and signed candidates.

HEMTT provides compiler and lint diagnostics for current Arma commands. Fix compiler errors; review performance warnings. A static performance scan cannot establish the frame-time budget. Its high-severity baseline starts empty; an exception needs a specific reviewed reason and bounded count. Never regenerate a baseline merely to hide a new finding.

Game acceptance uses fresh packaged content through `launch_mod_audit.ps1`, dedicated server/client, `-noBattlEye`, 3840x2160 and the required CBA/ZEN dependencies. Batch related cases. Verify actual mission entry and fresh RPT evidence. Test real physical behaviour, live fire, casualty flow, Zeus replacement, cleanup, JIP and locality changes; an accepted flag or waypoint cannot pass a behaviour case. Rendering changes also need direct capture review across supported aspect ratios.

Release promotion requires the exact tested signed package and matching evidence. Incomplete acceptance remains visible in the coverage manifest. No source rebuild may replace the candidate after its audit.

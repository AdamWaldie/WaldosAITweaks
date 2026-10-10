# WAIT completion status

Status checked on 2026-10-10. WAIT is not production-ready. All 65 registered feature families remain `implemented_partial`. None has complete acceptance. This registry label covers both substantial controllers and capabilities with missing implementation, so it is not a completion percentage.

Audit processes are closed. Further game launches are suspended at the user's request. Static development can continue.

## Implementation and acceptance by category

| Category | Implementation present | Acceptance and remaining work |
| --- | --- | --- |
| Standalone addon and configuration | Eight addon PBOs, WAIT namespace, CBA settings, optional ZEN, native Zeus orders; nine FSM source files | Build gates pass. Complete CBA persistence, live-change, server enforcement, JIP and module parity remain unaccepted. |
| Danger foundation | Engine danger FSM, bounded observations, actor/witness identity, finite reactions and shared group handoff | Real contact, close-contact handoff and hold-fire subcases pass. Friendly blast intake, observer cover, cleanup and full response-depth parity remain unresolved. Highest behavioural priority. |
| Operation lifecycle and scheduler | Generations, owner epochs, cancellation, committed movement, one shared owner-local budget | Multiple Zeus replacement and disable/restart cases pass. Every operation phase, queue growth, low-FPS response and full migration coverage remain pending. |
| Skill, lighting and lethality | Skill profiles, darkness/NVG/light heuristics and operating-crew tuning | Full equipment/mod variation and infantry/vehicle/aircraft lethality acceptance remain pending. |
| Cover, suppression and fire | Cover scoring, stance leases, suppression, friendly-lane checks, fire distribution and grenade avoidance | Physical cover arrival and subsequent ordinary movement passed in the latest partial batch. Group hide, observer response and active replacement still have failures. Opposite-contact grenade throws remain unverified. |
| Infantry movement and combat | Paired bounds, advance, flank, assault, defence, crossing, fire while moving and clear-through transitions | Prior physical failures include reversals, pauses, incomplete participant use and poor approach choice. Dynamic casualty and stuck-actor continuation remain unaccepted. |
| Morale and survivor management | Withdrawal, surrender, regroup, survivor reinforcement and role rebalancing | Physical reactions and casualty continuation need complete acceptance; no full recreation credit. |
| Buildings and urban movement | Building operation FSM, entry/room/floor progression, garrison, traverse, reserves and explicit unreachable outcomes | Twelve-person clearance visited six covered positions. Two-/six-person entry, casualty replacement movement, door entry and handover failed in the last completed broad batch. Queued repairs have not completed their retest. |
| Multi-squad coordination | Communication eligibility, support opportunities, distinct manoeuvre roles and finite coordinated intent | Dynamic bounds, lanes, broad rally areas, casualty response and transition to assault remain unaccepted. |
| Combined arms | Contact-led support opportunities for infantry, vehicles and aircraft | Depends on effective movement, vehicle and aircraft behaviour. A roughly balanced, damage-enabled tactical battle is not yet accepted. |
| General driving | Independent driving gate, terrain/grade caps and bounded physical recovery | Road, hill, turn, obstruction, player-roadblock and new-order cases remain pending. |
| Convoys | Fleet registration, predecessor trails, spacing, holds, contact handling and individual recovery | Single-file behaviour across mixes, spacing/speed settings, migration and roadblocks remains unaccepted. |
| Passenger and crew ownership | Seat/task generations, safe-stop dismount, remount and native-task protection | Several boarding, safe-exit and crew-retention subcases passed. Independent passenger orders, every transition and locality case remain pending. |
| Ground gunnery and withdrawal | Target priority, finite suppression, smoke, standoff, jink and tracked reverse leg | Smoke, crew retention and withdrawal distance passed. Threat-facing reverse and Zeus replacement travel failed. |
| Aircraft attacks and defence | Attack operation FSM, capability selection, native aiming/flight, ingress/egress, countermeasures and air-to-air logic | Known failures include circling, no engagement, poor release geometry, misses and unsafe clearance. Guns, unguided/guided weapons, bombs, attack distinctions and air-to-air manoeuvres need physical proof. |
| Landing and braking | Dedicated flight ownership, approach, braking, go-around and release logic | Controller code exists; aircraft/terrain diversity and interruption acceptance remain pending. |
| Artillery and support | Artillery FSM, observed support, first-lethal-burst warning, smoke, relocation and counter-battery | Full warning timing, real effects, disabled-state, safety and interruption acceptance remain pending. |
| Medical and ammunition | Finite medic tasks, danger cancellation and magazine sharing | Physical treatment/sharing, casualty flow and ownership acceptance remain pending. |
| Civilian, airborne and naval | Event-driven civilian escape; finite parachute/boat delivery and passenger handover | Richer civilian behaviour and complete delivery-to-ground-combat transitions remain unaccepted. |
| Specialist interoperability | Per-actor ownership/exclusion and operation release; squad hide acquisition now excludes specialist actors | Actual specialist coexistence, activation/release, mixed groups, JIP and HC cases remain pending. Detection is not acceptance. |
| Native headless integration | Real provider staging, hashes, registration/transfer/adoption fixture and ownership bridge | Provider now loads. Native HC registration failed, so transfer/adoption acceptance did not run. Standalone engine transfer success does not establish native integration. |
| Performance and simulation | Shared budgets, caches, distance tiers and matched native/WAIT benchmark pipeline | Infantry patrol measurements matched at 21 ms median and 23 ms p95, but startup warnings invalidated comparison. Mixed/combat load, queue stability and the 5%/10% limits remain unaccepted. No new culling/simulation shortcut accepted. |
| Optional engine policies | Runtime skill/dispersion controls and policy requirements | Separate optional engine-policy PBOs are absent from the current build. They still require implementation, packaging and proof that player accuracy is unaffected. |
| Documentation and delivery | Static validators, tests, wiki generation, parity checks, package seals, audit launch/reporting and signed-candidate workflow | 554 static tests and package checks pass. No accepted release candidate. Some inventories describe earlier snapshots; full history cleanup has not been re-audited here. |

## Progression blockers

### B1: runtime integrity

The startup `a3_characters_f` warning occurs in both native and WAIT runs. Removing the generic declared mission dependency and headless slots did not remove it. Registration diagnostics are prepared but have not been exercised. A clean package is necessary for performance and release acceptance.

### B2: danger and ownership

Resolve danger intake, response-depth and exact actor/stance cleanup. Verify newer orders, players and specialist owners through real transitions. This is the behavioural prerequisite for infantry, building and coordination acceptance.

Implementation: [engine danger FSM](../addons/danger/danger.fsm), [operation start](../addons/core/functions/operationStart.sqf), [operation restoration](../addons/core/functions/operationRestore.sqf).

### B3: infantry and building continuity

Prove movement, fire, casualty replacement and isolated recovery without pauses or returns to stale destinations. Then prove entry, connected room/floor progress, garrison and actual traversal across models and squad sizes.

Implementation: [tactical operation FSM](../addons/main/fsm/tacticalDrill.fsm), [building operation FSM](../addons/main/fsm/buildingOperation.fsm), [building progression](../addons/infantry/functions/buildingOperationStep.sqf).

### B4: coordination and combined arms

Reliable local manoeuvre, building progression and platform support must compose through communication and finite roles. Verify separate lanes, support sectors, transitions and casualty response in balanced live battles.

Implementation: [group tactics FSM](../addons/main/fsm/groupTactics.fsm), [support request FSM](../addons/main/fsm/supportRequest.fsm).

### B5: vehicle and aircraft effectiveness

Validate driving before convoy fleet behaviour; validate crew/passenger ownership and reverse withdrawal. Aircraft require supported weapons, workable release geometry, terrain clearance, real effects and defensible air-to-air behaviour.

Implementation: [convoy FSM](../addons/main/fsm/convoyOperation.fsm), [reverse withdrawal](../addons/vehicles/functions/cortexVehicleReverseStep.sqf), [air attack FSM](../addons/main/fsm/airAttackOperation.fsm).

### B6: multiplayer and specialist handover

Native HC registration must work before native transfer/adoption can be credited. All categories need JIP, migration, disconnect, player/Zeus and specialist handover acceptance.

Implementation: [native provider staging](../releaseVerificationAndDeployment/stage_headless_provider.py), [headless bridge](../addons/compatibility/functions/compatibilityHeadlessBridge.sqf), [specialist ownership](../addons/compatibility/functions/cortexExternalOwner.sqf).

### B7: performance and release

After the behaviour and cross-cutting ownership checks pass, run matched infantry, mixed and combat measurements with stable observers and queues. Complete optional policy packaging, then promote the exact tested signed candidate.

Evidence contract: [performance validation](PERFORMANCE-VALIDATION.md), [all 65 feature families](../releaseVerificationAndDeployment/cortexQA/FEATURE_STATUS.md), [capability registry](CAPABILITY-REGISTRY.md).

## Latest physical evidence

- `runtime-20261010-123843-079`, candidate `20fd9d7`: completed broad batch, 755 checks, 62 server findings, zero client findings, no matched SQF/fatal errors, one loader warning. Remains FAIL.
- `runtime-20261010-143646-413`, candidate `c9f6657`: processes exited without either completion marker. Partial report has 171 checks and 19 failed checks; no matched SQF/fatal errors and one loader warning. Building/vehicle stages did not complete.
- `runtime-20261010-151701-617`, candidate `62d86bd`: completed native-provider batch, 300 checks, one server finding, zero client findings, no matched SQF/fatal errors and one loader warning. Native registration failed its prerequisite; physical native transfers were not accepted.
- `6308d3f` infantry patrol pair: native and WAIT both observed 21 ms median and 23 ms p95. Strict comparison is INVALID because both contain the loader warning. Patrol results do not establish combat performance.

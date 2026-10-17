# Historical completion and audit notes

Archived on 16 October 2026 from the former completion page. Statements below retain their original candidate/date and may contradict later evidence. They are not current launch authorisation, live process state, current build counts or acceptance of later source changes. Use [the current tracker](COMPLETION-STATUS.md) for present status. No failed case is withdrawn by this archive.

---

# Current delivery status

Status checked on 15 October 2026. The previous percentage table is withdrawn as a measure of implementation completion. It counted registry entries, source classifications, audit wiring and selected reviews. Those counts do not measure whether AI delivers the intended behaviour.

All 65 registered feature families remain partial. Some narrow physical cases have succeeded, and others have failed or varied across repeated runs. No family has complete intent, authority, locality and performance acceptance. This does not mean that every existing behaviour is absent. No reliable overall completion percentage can currently be assigned.

The latest sealed candidate and its offline check count are recorded in [the active implementation pull request](https://github.com/AdamWaldie/WaldosAITweaks/pull/14) and its candidate-specific build evidence. These are regression checks, not physical acceptance. Audits are held by user request. The ongoing source comparison distinguishes actual called mechanisms, missing methods, changed intent, retained failures and outcomes that remain unproven. File presence and accepted orders receive no physical completion credit.

Recent offline changes cover native-task driving recovery guards, crew-seat locality, CQB observer visibility and casualty promotion, successful natural-clearance route continuation, generation-scoped watch cleanup, reported AA threat geometry, convoy predecessor hull safety, danger-cover authored-order ownership and full-corridor direct-fire protection. These changes have no fresh physical acceptance. A natural-clearance continuation case is prepared but unrun. The full driving-source semantic review and required controller handovers remain incomplete.

Historical evidence below retains its original candidate and scope. It must not override this current status or be read as acceptance of later changes.

## Latest evidence boundary - 2026-10-13

Offline follow-up through 406b0ed adds unresolved artillery parking, observer rejection retry, exact CQB watch retirement, protected-target and believed-position vehicle responses, finite convoy timing evidence and ASL aircraft ingress projection. All passed offline gates; none has fresh physical acceptance. All 65 feature families remain partial; audits remain paused.

Source through 406b0ed passed 660 tests and full build gates. All 65 feature families remain partial. Latest completed normal clearance retained 18 findings; the next normal run was stopped early with eight findings and a first-six-person INCOMPLETE result. Subsequent entry-search, exterior observation, promotion/replay and driving-release fixes have no fresh physical acceptance. Audit launches are paused at the user's request. See [the current implementation ledger](IMPLEMENTATION-PROGRESS.md) for exact runtime boundaries and remaining scope.

Earlier evidence follows and must not be treated as current launch state.

# WAIT completion status

Current evidence - 2026-10-13: all 65 feature families remain partial. Source through 8c7d7c7 passed 654 tests and full build gates. Normal CQB candidate 8c7d7c7 is running in runtime-20261013-045724-829 with zero HCs. Two prior resumed normal batches retained 13 and 12 findings respectively: twelve-person clearance remained incomplete, and whole-pair casualty entry failed. Narrow two/six-person cases passed; single-casualty entry varied between runs. This does not establish repeatability. Recent corrections cover planned formation fallback and removal of geometry-only room offsets; their physical acceptance is pending. The wall negative-control fixture still fails after spawn displacement and is being repaired. Later historical statements that audits are paused do not describe current authorization or runtime state. Counter-battery source now uses qualified delayed native observers and side-specific radar receipts; physical acceptance remains pending.

Historical source and acceptance notes follow.

Current offline follow-up through c4f8606 passed 654 tests and the full build gates. Artillery fire checks operating-gunner readiness at the command boundary; assigned observers reject hidden/simulation-disabled actors before observation commands. Counter-battery acquisition still lacks qualified non-radar detection, and later global emissions can retarget active missions without side-specific detection. These faults remain open. No new physical acceptance; audits remain paused.


Recent source changes through 4023e01 passed 653 tests and full offline gates, with no new physical acceptance. CQB reserve staging uses bounded scene cover, three finite searches, owned approach timeout and generation-scoped migration journals built only on transitions. Clearance command readiness, reserve selection, room evidence and egress now account for hidden/simulation-disabled actors separately from roster/restoration ownership. Common recovery yields dormant actors without consuming retries; aggregate operation progress requires active observers. Dormant admission, recovery-observation expiry and wake baselines remain open. Convoy lateral recovery respects the closing cap, but mixed tracked/wheeled stop/start remains unresolved. Reinforcement need uses combat-effective strength; aircraft command boundaries require capable pilots. Grenade launch diagnostics and an isolated cardinal/stance fixture are unrun. Audits remain paused. Garrison now records exact movement receipts, fences continuation/release against replacement MOVE/FOLLOW, releases only diverted actors and their PATH locks, handles native service tasks, and retires the final empty group order. Defence arrival requires 3D distance and a floor match. Coordination uses believed drill contact geometry and transports confirmed-contact age through server/helper new-attack gates; already executing assault adoption remains separate without refreshing age/expiry. Migration, fresh per-target provenance, ongoing contact updates, dynamic allocation and all physical handovers remain incomplete.

Status checked on 2026-10-13. WAIT is not production-ready. All 65 registered feature families remain `implemented_partial`. None has complete acceptance. This registry label covers both substantial controllers and capabilities with missing implementation, so it is not a completion percentage.

Current evidence (2026-10-13):

- CQB boundary source now requires target-owned roofed topology and bounded intervening-building geometry for room receipts/holds. Fresh-clearance observations independently use live bounds/geometry; an exterior-wall observer negative control is queued. All remain unrun. Earlier proximity-based reports cannot establish the stronger boundary, actual room safety or universal interior entry. End-to-end production wall controls, edge models, dense-worker fairness and matched performance remain required.

- Latest completed production retest 26d782d recorded 410 checks and 11 retained failures, zero SQF/fatal errors and one unresolved load warning. Twelve-person reserve staging passed 39 actual observations, but two-person leader progression and twelve-person participation/settlement/egress remained incomplete. Six-person progression passed while result agreement failed. Later finite INCOMPLETE termination and ordinary physical handover are separate narrow results, not clearance success.
- Native 194c394 comparison completed 188 checks with 70 retained failures, zero SQF/fatal errors and one unresolved load warning. Command-FSM, direct movement and planner variants had identical raw reached-node masks across four models; there is no observed advantage supporting a production movement-interface replacement. Native failures on these placed instances do not establish a universal engine fault.
- Current implementation through 4023e01 passed 653 tests and full SQF/config/docs/wiki/parity/performance-pattern gates, with nine production PBOs/FSMs and the disposable native command-FSM validated. Production corrections since the last completed clearance batch retire stalled optional transit points, omit redundant same-floor buddy checkpoints, and protect reserve arrival/promotion from newer individual movement. These changes have no fresh physical production acceptance.
- Preserved clean candidate `.qa/candidates/d043238-clean` records commit d04323870e0c66fda41b54f06c6b3a38ebf63f75, dirty=false and verified fingerprint 4fb92b1c1df2cf089600cec3a8c90b50339d1c08cf81af29b5e7c37a88bcaed0. It has not been launched and predates later fixes through 392d458. A fresh clean candidate is required before resumed audits; prior packages remain preserved.
- Driving source corrections reject ineffective crew/immobile vehicles, preserve different reverse turn directions, yield followers to reversing predecessors and use the same effective-driver roster for convoy eligibility/locality. A bounded native reverse-yield/recovery diagnostic is queued. These fixes do not close mixed convoy spacing, stop/start, casualty replacement or performance findings.
- Equal-size d753d64 native controls completed 228 checks with 80 retained failures. Both leader/follower roles traversed validated Small_01; larger-model traversal remained incomplete. Interrupted 4871330 controls recorded 247 checks with 73 failed assertions, zero SQF/fatal errors, one unresolved load warning and matching provenance. ROOM-STOP and ROOM-SPEED masks were identical across all four models. The batch has complete=false; all recorded processes were terminated and verified absent. Game audits are paused at the user's request until resumed.
- Normal c450466 clearance completed 407 checks with 11 retained failures, zero SQF exceptions/fatal runtime errors and one unresolved load warning. Two-person participation and handover passed. Six-person shared room coverage and handover passed but one admitted worker never entered. Twelve-person upper-floor node 3, settlement, egress and physical handover failed. The leader received the correct authored MOVE destination but travelled only 2.36138 metres. Both processes were terminated and verified absent.
- Sealed b48a503 normal clearance completed 408 checks with eight retained twelve-person failures, zero SQF/fatal runtime errors and one unresolved load warning. Two-/six-person progression and handover passed these fixtures. All six twelve-person room nodes were visited, but participation, settlement, egress and handover failed. Both processes were terminated and verified absent. Candidate 26ea2bf completed 409 checks with seven retained twelve-person failures. Two-/six-person participation and handover passed. Twelve-person shared coverage passed; late finite termination correctly returned INCOMPLETE and subsequent physical handover passed. Original participation, settlement and egress findings remain failed. Absolute-boundary exhaustion and migration of that boundary remain untested. Native formation-planned traversal is being added as a diagnostic only. Accepted commands, elapsed time and shared coverage cannot pass individual participation or clearance.
- Separate two-HC d56396d batch completed 405 checks with seven twelve-person failures and one unresolved load warning. Completed two-person holds were adopted through both HCs, physically followed the successor order under the second HC and returned to server. This narrow result does not establish in-progress clearance migration or general multiplayer acceptance.
- Earlier reserve staging and casualty-replacement travel passed narrow checks. Full reserve roles, progressive admission beyond eight concurrent workers, security sectors and tactical consolidation remain incomplete.
- Reliable CQB across placed/native buildings, individual participation, damage-enabled combat, physical handover, driving/convoy/air/support acceptance, required external-controller handovers and the 5% median/10% p95 performance budget remain open. Workshop/driving/FSM foundations remain priority; broad compatibility expansion stays deferred. When the user resumes audits, closure/restarts remain authorized without repeated permission requests.

All 65 families remain partial. Completed production feature families: 0/65; this is an acceptance count, not a statement that implementation is zero percent. Source/feature completion estimates below remain estimates and must not be promoted from static wiring or test counts.

The following batch narrative is historical:
Historical normal batch (2026-10-11): `runtime-20261011-175607-317`, sealed candidate `e6b3f1d`, normal convoy matrix at 3840x2160 with observer Zeus and zero HCs. At 85 recorded checks, WHEELED-30 and WHEELED-50 passed all fourteen checks each: continuous travel, spacing, single file, stop fraction, halt/resume, crew retention and cleanup. These are flat-VR subcases at a 30 km/h request, not complete convoy or performance acceptance. WHEELED-15 remains failed; pacing repair `3c631a9` is outside the running candidate. HC tests remain a separate batch. One addon load warning remains unresolved.

Historical stopped batch (2026-10-11): `runtime-20261011-145921-734`, candidate `543880e`, 3840x2160 observer Zeus with two HCs. Stopped at user request; all four processes verified absent. Partial report: 823 checks, 266 failed assertions, zero SQF errors, one unresolved load warning; server/client completion markers missing. Repairs after this candidate remain physically unverified. Game audits were subsequently authorized again; the normal convoy batch above is running. Compatibility expansion remains deferred behind FSM/driving foundations.

Game audits are authorized in batches. The broad candidate 89812ab batch completed with
2,375 checks and 462 failed checks. The subsequent coordination candidate b3a9f70 completed
with 453 checks and 30 failed checks, zero SQF error lines, zero fatal runtime failures and
one unresolved load warning. Neither establishes subsystem acceptance.

## Historical batch and queued repairs

Subsequent repairs through `ae23694` are committed to follow-up PR #13 and remain physically unverified. Garrison and defence commands defer finite actor tasks and reservations; cleanup preserves newer tasks; door requests verify building-order generation. Route watchdogs require three-dimensional approach rather than arbitrary lateral travel. New lifecycle cases require real boarding after hold release. These changes do not close earlier coordination failures or prove building path acceptance.


Clean candidate ecdff24431f12c7fc780dee195ef5befe4a62fcf is preserved with dirty=false and
fingerprint e1c26e9caf17f11e632eb0c2117f5f23bdea2fb92b3760b2c8a796bbee6ef139.
Its corrected coordination retest was authorized on 2026-10-11 and launched as
runtime-20261011-045348-544. It completed with 456 checks, 32 failed checks, zero SQF error
lines, zero fatal runtime failures and one unresolved load warning. Physical acceptance failed.

The unresolved `a3_characters_f` warning occurs in the dedicated server RPT at 04:53:56, before its `Starting mission` marker at 04:53:59. The client and HC1 RPTs for this batch contain no corresponding missing-content warning. The installed character PBO exists, and the server's post-load diagnostics confirm the character patch and soldier classes. These observations narrow investigation to startup/loading; they neither identify the cause nor waive the warning for acceptance. Removing a valid mission dependency is not an established repair.

Repairs since b3a9f70 include matching operation generations on coordinated child bounds,
retiring outgoing child work before parent release, mover pursuit posture, protected actor
restoration and reservation-token-bound contact positions. Combined ground support preserves
unrelated movement owners and refuses unavailable operators or unsafe friendly firing lanes.
Those latter combined-fire repairs require their own physical batch; coordination results cannot
validate them. Larger force coordination, independent contact areas, capability-selected effects
and matched performance remain incomplete.

Later fixes remain queued: tactical/building/aircraft FSM supersession and cleanup, role-aware danger
posture, shared tactical operation phases, and scheduler admission/coalescing. Scheduler coalescing
now returns before duplicate append, isolates group/owner epochs and retires deleted-group work.
Additive in-engine cases exercise single execution, epoch rejection, stale callback retirement and
existing physical movement under the scheduler budget. Those cases have not run in the completed
package. The HC diagnostic fixture also reapplies its stated damage protection after migration;
this does not change production or damage-enabled battles. That historical restart request has been superseded by blanket audit closure/restart authorization.

Historical queued repairs below require individual evidence review against later batches:
Changes through 82e0fc6 are committed and statically/package validated, awaiting physical retest:

- Aircraft: live weapon/launch alignment, lateral turret traverse eligibility, logic-target
  rejection, preserved re-attack holds, moving-contact interception and bounded bomb drag.
- Shared combat: logic objects excluded from knowledge and immediate hostile danger admission.
- Audit fixtures: native radar acquisition separated from delivery, physical target checks,
  logic-contact rejection plus ordinary movement, and standalone/native-provider registry distinctions.
- Diagnostics: failure-only management snapshots for invalid performance arms; actual braking
  release evidence and capped building terminal route evidence.
- Movement repairs: reserved actors protected from scripted fire orders; generation-owned leader
  attack delegation, eligible consolidation rosters, result-aware recovery budgets and survivor
  replacement retain committed bounds and hard deadlines. Physical movement remains unaccepted.
- Ownership repairs: CQB cleanup yields to individual controllers; explicit vehicle driving
  ownership blocks reverse, group routes, withdrawal admission and stale speed restoration.
- Additive audits: standalone driving travel, condition waits, HOLD, same-index replacement,
  disabled cleanup and physical external handover; attack-policy interruption; concurrent
  exact-observer posture/cover evidence, and separate native handback versus tactical HC
  continuation. These cases are queued, not passes.
- Tactical migration: standalone advance/flank/assault checkpoints retain committed routes,
  actor destinations, bound deadlines and spent recovery budgets. New owners rebuild one local
  operation/FSM after authority validation; coordinated bounds keep server-role adoption.
  Physical resumption, interruption and loaded performance remain unaccepted.
- Coordination repairs: authenticated prepared eligibility can dispatch beside a current local
  drill; role handover does not return movers to formation. Operation admission retains the full
  ATL objective. Cover is stationary by design and does not inherit rally no-progress failure;
  stop commands occur once per role change. Expired acknowledgements reject, and unsafe bounds
  allow one delayed retry before retiring only that element. Route rejection does not starve
  other elements. Three capable survivors retain two movers and one coverer with unique donors.
- Fixture repairs: coordinated handoff explicitly enables Post Contact, roster sampling uses the
  configured helper size, absent admission fails after thirty seconds and owner objectives must
  match their lease. These dependencies and assertions remain physically unaccepted.
- Individual handover: legacy support hold cleanup in calm, withdrawal and support paths does
  not restore movement over player, remote or specialist ownership.
- Vehicle repairs: stopped follower command invalidation, tracked lead resume, unsettled HALT
  cadence and finite passenger-owner exit retries remain queued for exact-candidate acceptance.

Physical results from older packages do not validate later changes. Native companion
provider integration, specialist coexistence, CQB, combined combat and matched mixed-force
performance remain open. Clean candidate 82e0fc63eedffccaee8a0337657c92e94772a9f7 is preserved
with dirty=false and fingerprint ba42aa4fc0b74b0ec3f732107f2962d14c54133bace2f9a895ea3ed10bb4be15.
It includes the queued repairs; it has not run physically.

## Module progress toward completion

Overall: 0 of 65 feature families have full acceptance. All eight addon modules are packaged and statically validated, but their behavioural implementation remains partial. This is accepted completion, not a percentage of code written. No release candidate is accepted.

| Addon module | Implementation progress | Completion blocker |
| --- | --- | --- |
| Core | Shared lifecycle, scheduling, configuration and ownership implemented; transition repairs continue | Full interruption, migration, JIP, queue stability and performance acceptance |
| Danger | Engine danger FSM and finite response handoff implemented; some physical subcases passed | Response-depth baseline, intake, cover and cleanup failures; recent fixes await retest |
| Infantry | Tactical, CQB, morale, fire and coordination controllers present; continuity repairs continue | Reliable movement, room progression, casualty replacement and multi-squad combat |
| Vehicles | Driving, convoy, passengers and gunnery present | Mixed columns, obstructions, passenger orders, tracked reverse and replacement travel |
| Aircraft | Attack, defence, landing and braking present; release/handover repairs continue | Effective weapon delivery, distinct profiles, clearance, air-to-air and controller transitions |
| Support | Artillery, medical, ammunition, civilian and delivery capabilities present or partial | Complete physical outcomes, safety, interruption and cleanup |
| Compatibility | Ownership adapters and actual headless-provider fixture present | Native HC registration; real specialist coexistence, disconnect and migration |
| Main | Function registration, settings and operation FSM integration packaged | Complete settings persistence/parity and exact-candidate end-to-end acceptance |
| Optional engine policies | Separate turret policy PBO packaged, default off and restart-required | Physical lethality, override detection and player-accuracy exclusion proof |

The category table below gives feature-level detail. Blockers B1-B7 define the progression order. Static validation is a gate; physical subsystem acceptance, cross-cutting handover and matched performance checks remain separate gates.

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
| Native headless integration | Real provider staging, hashes, registration/transfer/adoption fixture and ownership bridge | Provider now loads. Native HC registration failed, so transfer/adoption acceptance did not run. Saved server evidence confirms installation but has no registration result; RPC receipt/policy and provider rejection remain unresolved. The queued diagnostic wrapper retains the original provider call and return, rather than substituting registration. Standalone engine transfer success does not establish native integration. |
| Performance and simulation | Shared budgets, caches, distance tiers and matched native/WAIT benchmark pipeline | Infantry patrol measurements matched at 21 ms median and 23 ms p95, but startup warnings invalidated comparison. Mixed/combat load, queue stability and the 5%/10% limits remain unaccepted. No new culling/simulation shortcut accepted. |
| Optional engine policies | Runtime skill/dispersion controls and policy requirements | A separate optional AI Turret Aiming PBO is now packaged outside the default addons folder. It changes only the AI turret aiming-error ceiling. Other engine policies, physical lethality, player precision and compatibility acceptance remain outstanding. |
| Documentation and delivery | Static validators, tests, wiki generation, parity checks, package seals, audit launch/reporting and signed-candidate workflow | 559 static tests and package checks pass. No accepted release candidate. Some inventories describe earlier snapshots; full history cleanup has not been re-audited here. |

## Progression blockers

### B1: runtime integrity

The startup `a3_characters_f` warning occurs in both native and WAIT runs. Removing the generic declared mission dependency and headless slots did not remove it. Registration diagnostics are prepared but have not been exercised. A clean package is necessary for performance and release acceptance.

### B2: danger and ownership

Resolve danger intake, response-depth and exact actor/stance cleanup. CBA disablement ends WAIT's response but does not replace the loaded fsmDanger config; no WAIT command/lease is a necessary disabled-state result, not proof of native danger equivalence. Matched baseline performance must continue using the addon-absent native candidate. Verify newer orders, players and specialist owners through real transitions. This is the behavioural prerequisite for infantry, building and coordination acceptance.

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

## Historical physical evidence through 2026-10-11

- `runtime-20261010-123843-079`, candidate `20fd9d7`: completed broad batch, 755 checks, 62 server findings, zero client findings, no matched SQF/fatal errors, one loader warning. Remains FAIL.
- `runtime-20261010-143646-413`, candidate `c9f6657`: processes exited without either completion marker. Partial report has 171 checks and 19 failed checks; no matched SQF/fatal errors and one loader warning. Building/vehicle stages did not complete.
- `runtime-20261010-151701-617`, candidate `62d86bd`: completed native-provider batch, 300 checks, one server finding, zero client findings, no matched SQF/fatal errors and one loader warning. Native registration failed its prerequisite; physical native transfers were not accepted.
- `6308d3f` infantry patrol pair: native and WAIT both observed 21 ms median and 23 ms p95. Strict comparison is INVALID because both contain the loader warning. Patrol results do not establish combat performance.
- `runtime-20261010-214346-432`, clean candidate `89812ab`: observer Zeus and 3840x2160 mission entry verified. Batch remains active: an unrestricted process check confirmed all four original PIDs and fresh building-stage RPT entries. An earlier restricted-shell inventory falsely appeared empty and its partial reporter snapshot must not be treated as terminal evidence. Completion and final results remain pending.

The latest observed partial snapshot records 1528 checks, 4231 SQF error trace lines,
no matched fatal failures, one startup load warning and no completion marker. All four
original processes remain live. The batch reached its final combat case; mechanics,
reactions, support and further suites still follow. Later source edits are not loaded.

Three manually assisted building-contact cases remain test problems. CQB, convoy resume,
air delivery and natural danger-cover findings remain open. Advance AWARE and YELLOW
stalled with native ATTACK destinations away from their bounds; the old audit awarded
assault-transition passes even when no assault was observed. Queued fixes and corrected
physical evidence cannot retroactively turn those runs into acceptance. Notification,
bomb integration, communication-hook and multi-contact fixture exceptions are recorded
by cause in the error ledger; repeated trace lines are not separate defects.
## Historical follow-up changes and acceptance gaps

PR #13 contains the work after merged PR #12. No feature family has gained complete behavioural acceptance from these static changes.

- Scheduler: function-scope keyed coalescing, earliest/self-wake deadlines, epoch and generation isolation, retired-state separation, and atomic admission fixtures.
- FSM ownership: registered-brain checks across group, building, convoy, support and artillery waits and cleanup; real packaged-FSM retirement cases are queued.
- CQB: physically visited rooms apply pair handoff before cursor advancement; another lane's completion cannot establish entry; entrance staging requires the assigned mover. The two-person audit additionally requires both actors to progress through multiple interior positions when the fixture supports it.
- Aircraft: pilot-fixed helicopter delivery legs cross the aim point; OFFSET/HOOK armed rocket fixtures are added. Stand-off geometry is tested separately from target-crossing runs. Actual shots, impacts, destruction, safe exits and terrain acceptance remain required.
- Diagnostics: bounded movement-handoff records and smoke-request prerequisites expose unresolved competing destinations and admission failures.

The last completed coordination run remains 456 checks with 32 failures. None of those failures has been waived by these changes. The preserved a2bed47 candidate predates later entrance-staging and aircraft changes; results from that candidate cannot validate later commits. The completed audit applications remain open and replacement-launch approval is pending. Full infantry/CQB, convoy, aircraft/support, compatibility, headless/JIP and matched performance acceptance remain incomplete.

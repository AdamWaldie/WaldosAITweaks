## Current acceptance boundary

The completed `dangerparity` run used clean commit `24bdee3`. Its server reported 69 findings:
39 danger, 24 passenger/vehicle, four tactical and two withdrawal cases. The client completed
with zero client findings. These results contradict broad behavioural acceptance; client success
does not establish server-side AI behaviour. Some compound failures include unmet stimulus or
contact prerequisites and must be traced from those prerequisites before changing a controller.

The subsequent `dangerparity` batch is running clean commit `d7c5649` at 3840×2160
with CBA, optional curator integration, observer Zeus and two headless clients. Native danger
entry, immediate physical posture, contact/search/regroup transitions and carried static assembly
have passed individual cases. Cover, cleanup, existing static support, carried weapon firing and
packing, tactical fixtures, vehicle responses and passenger transitions have recorded failures.
The batch has not yet published its completion marker; these are partial results.

Confirmed follow-up corrections are committed: the assembled empty static weapon is oriented
once toward its chosen sector before boarding; vehicle jink now supplies properly nested routes;
route validation rejects malformed endpoints; empty carried emplacements remain eligible for
packing after native dismount; and the airborne threat fixture has explicit initial altitude and
an ordinary transit waypoint. Cover rejection diagnostics distinguish ownership/command gates
from unavailable geometry. These corrections still need a fresh packaged physical run.

The full static build passed 504 tests, SQF/config checks, settings parity, performance-pattern
checks, FSM validation and eight-PBO packaging. Frame-time overhead, physical behaviour, JIP
and headless acceptance remain unproven by these gates.

Changes under physical reassessment:


- Armour overmatch, exposed elevated threats, insufficient firepower and shaken morale can start
  one finite screened reposition. Close protected armour inside 120 metres can invoke withdrawal;
  normal overmatch retains native combat and reassessment. Same-threat cooldown limits route churn.
- Aircraft overmatch without live AA can select concealment, while a viable fresh ground fight
  keeps priority. The new fixture verifies armed aircraft, crew, ammunition and flight velocity.
- Failed manoeuvre selection has an explicit reposition/native-reassessment handoff rather than
  an unexplained HOLD. Reposition completion requires physical destination arrival.
- Vehicle withdrawal, standoff, jink and artillery relocation require destination arrival; lease
  expiry elsewhere reports INCOMPLETE. This reporting correction does not prove recovery works.
- Zeus waypoint ownership releases when the authored chain finishes instead of retaining a
  120-second grace period. Direct edits retain the configured hold. During a Zeus chain, WAIT's
  present eligibility gate still yields its whole group controller; native combat remains available.
  Observation-only hearing is now retained during a waypoint chain, with direct edit, player,
  remote-control, aircraft and specialist gates rechecked on each callback. It stores only uncertain
  sound reports and cannot start movement or reveal a target. Broader selective combat assistance
  and physical coexistence acceptance remain incomplete.
- Native danger entry records now precede eligibility rejection. Live-disable audit evidence
  distinguishes actual reflex delivery from subsequent cleanup, while retaining the combined check.

The subsequent corrected `41da6a4` run has now passed existing-static disabled state, physical
seat occupation, real emplacement fire alongside squad fire, and contact cleanup. Those results
support the empty-weapon selection correction only; carried deployment and broader danger parity
remain separate acceptance cases. The rifle casualty fixture still reports no native projectile,
so casualty response cannot be evaluated from those failed stimulus cases. Additional weapon-state
and mode diagnostics are queued to establish the cause without changing casualty logic.
The corrected airborne-overmatch fixture now passes flight prerequisites, natural contact,
physical infantry repositioning and no-chase checks in the `41da6a4` run. These results establish
this restraint/reposition case only; air attack weapon employment and flight profiles remain open.

The separate-passenger crew-report case now passes natural crew contact, safe stop, physical
exit, WAIT attribution and driver retention in the `41da6a4` run. Passenger target knowledge was
absent, as intended. Other passenger layouts, remount, replacement orders and migration remain
independent acceptance cases; the corrected predicate does not establish them automatically.

The stationary separate-passenger replacement-order case also passes physical boarding of
the second truck and preservation of the replacement seat assignment in the `41da6a4` run.
This demonstrates the explicit boarding-order handover for that layout; ordinary remount
acceptance still needs the corrected enabled fixture gate.

The subsequent `e5fbdd6` packaged run passes vehicle-jink ownership and physical travel
(about 21 metres). Its refusal context shows a later danger generation yielding to the existing
movement operation rather than replacing it. This is one flat-terrain, crew-only APC case;
blocked routes, mixed vehicles, interruption and performance acceptance remain separate.

## Earlier implementation work

- Danger shutdown now retires every actor-local engine stance lease through the exact-ownership
  release helper. Disabling the feature or releasing a group therefore restores a still-owned weak
  stance for each local observer, while Zeus or specialist takeover only discards WAIT's lease and
  does not write over the new owner. Previously cleanup erased the response marker but could leave
  a WAIT-applied crouch or prone stance behind. Static validation passes; the packaged disabled-state
  and interruption cases remain queued for the next batch.
- Convoy followers now retain their committed native destination and steering path across physical
  progress updates. The former progress-record rebuild discarded both values after every three metres,
  causing the one-second trail sample to issue another movement command. Steering-capable vehicles now
  refresh `setDriveOnPath` only after the predecessor path endpoint advances by more than eight metres;
  the existing exact-owned `forceSpeed` remains the sole continuous spacing and braking control. Native
  fallback followers use the same committed-endpoint rule and rely on the bounded obstruction recovery
  before any retry. Static validation passes; wheeled, tracked and mixed physical stop/resume acceptance
  remains pending.
- Engine feasibility has been checked against the current official command and FSM contracts. The
  danger/operation architecture is supported; the observed freezes and oscillation are controller
  ownership defects rather than a missing engine capability. Post-contact consolidation now commits
  one actor destination, records physical progress and permits one same-route retry after ten seconds
  of no progress. It no longer recalculates every separated soldier's destination every eight seconds.
  The route record is discarded on renewed contact and calm restoration. Static validation passes;
  packaged physical regroup, interruption and locality acceptance remain pending.
- Defend and medical movement now use the same single-owner native route contract. Defenders receive one
  `doMove` and refresh it only after measured no-progress; medics no longer force a second destination or
  reissue a healthy route every eight seconds. Native treatment remains finite and danger, Zeus or specialist
  takeover still cancels it before another command. Static validation and exact-candidate packaging pass;
  physical post arrival, aid completion and interruption acceptance remain pending.
- Building clearance, traversal and garrison movement now follow the same single-owner command contract as
  tactical bounds. Every entrance, interior, retry, reassignment and egress leg uses one native `doMove`; the
  paired `setDestination` replans that could compete at doors and thresholds are removed. Garrison disables
  `PATH` only after a soldier physically reaches the assigned post, because holding that post is the requested
  terminal state, and the existing exact-owned release restores it on replacement, Zeus or external takeover.
  Static validation and exact-candidate packaging pass; multi-model physical CQB and garrison acceptance remain
  pending.
- Tactical bounds now retain one movement owner per actor. WAIT issues one committed native `doMove`, leaves
  `PATH`, `TARGET`, `AUTOTARGET`, `AUTOCOMBAT` and native combat behaviour available, and never pairs that
  destination with a competing `setDestination` or clears an engine target. Covering and newly arrived actors
  receive one ordinary stop order without inheriting a disabled path planner. After eight seconds of measured
  physical no-progress, one route refresh is permitted; continued failure isolates that actor through the existing
  recovery path while the viable element continues. Support-by-fire holds use the same non-freezing stop contract.
  Static validation and exact-candidate packaging pass; packaged physical movement, firing, interruption and
  recovery acceptance remain pending.
- A concrete native task that arrives during an already active danger response now interrupts both the engine reflex and its group wake immediately. The exact observer retained by the assessment is rechecked for boarding, action, treatment, rearm, join, fleeing or CARELESS ownership; WAIT releases only its finite posture and leaves the new command untouched. The contact audit now proves both directions of the race: a task present before danger must block tactical handoff, and a task issued after physical danger delivery must clear the live response and complete boarding. Static validation is required; the additive packaged case remains queued.
- Native danger meanings now survive the engine-to-group handoff. Enemy detection, close proximity and a live firing opportunity remain distinct bounded causes with the same tactical consequence ordering used by the engine-side FSM, rather than collapsing into generic detection. This prevents a simultaneous lower-value explosion or ambient report from displacing an actionable native contact. The change adds no observation or scheduler work. Static and packaged validation pass; mixed-cause physical acceptance remains pending.
- A useful static mortar can now turn one exact native danger generation into one finite self-defence mission without enabling optional squad-requested artillery. The current platform owner submits the existing believed danger position and live hostile identity; the server revalidates exact battery ownership, native knowledge, allegiance, position fidelity, eligibility, takeover state, ammunition, range and friendly safety. Danger, Vehicles and Vehicle Gunnery are its live gates. An accepted mission uses the existing warning, token, shot-confirmation and uncertain-result FSM, fires at most one round, never relocates and cannot retry for 120 seconds. It does not directly issue an artillery command from the danger/vehicle controller. Static validation passes; a physical packaged case requiring natural acquisition, lethal-burst warning, one real round, crew retention and finite release is queued.
- Fresh native hostile sightings now preserve contact cadence after the short engine-danger wake expires. Distant groups therefore continue bounded fire, manoeuvre and casualty decisions while they are actually seeing an enemy instead of dropping back to a 20-second discovery interval. The `EnemyDetected` bridge now selects a squad member who genuinely owns native target knowledge; the bounded contact cache retains that witness so a leader behind cover or a detecting member beyond the first squad slice cannot silently lose the wake. Visible fire also joins hits, explosions and near rounds as a physical-cover stimulus for the existing one-idle-actor bounded response. Active operations, native commands, Zeus and specialist ownership still block that cover move. This adds no scan or worker. Static and packaged validation pass; physical latency and performance acceptance remain pending.
- Fresh known infantry threats from 12 to 60 metres now have a direct assault entry. Previously, advance and flank both rejected contacts under 60 metres while final assault was reachable only after one of those manoeuvres, leaving a confirmed logical dead zone. The new entry forms separate assault and cover elements, commits one terrain-checked approach and clear-through, and reuses the existing tactical FSM, operation generation, casualty replacement, isolated-actor recovery and exact Zeus/external-owner cleanup. `ASSAULT-CLOSE` is queued as a physical packaged case; static validation is not live acceptance.
- Mounted danger now retains a bounded response profile after selecting the real observer: transport, armed vehicle, armour, artillery, static weapon or aircraft. The handoff carries the exact occupied platform and only an already native-known hostile; it issues no movement, target or fire command. The existing vehicle owner can dismount eligible transport/fighting-vehicle passengers, release the local crew of an empty or imminently overrun emplacement, or abandon a critically damaged immobile vehicle. Healthy mobile crews, unrelated vehicles, aircraft, targets and routes remain untouched. The armoured mixed-group audit requires the exact vehicle and `ARMOURED` profile before accepting the handoff. Static validation passes; packaged physical domain acceptance remains pending.
- Continuing engine-danger samples now retain the original cause instead of degrading every follow-up into generic detection. Mounted classification also precedes the on-foot path-availability gate, allowing intentionally immobile static and artillery crews to hand danger to their dedicated owners without granting the danger FSM movement authority. Static validation passes; packaged persistence and immobile-crew acceptance remain pending.
- Danger coalescing now retains both the exact actor that received the current native event and, when a newer approximate record inherits a still-live hostile identity, the separate actor whose native knowledge supports that identity. Mixed mounted/foot groups are therefore classified from the real response actor instead of an arbitrary group anchor, while hostile handoff remains bound to a living local witness. Static and package validation pass; physical mixed-domain acceptance remains pending.
- Engine danger intake now coalesces repeated causes by record freshness instead of queue iteration order. A stale queued record can no longer replace current hazard geometry, and the freshest still-live hostile identity is retained independently when a newer approximate event has no source. The group coalescer applies the same bounded native-knowledge validation before retaining a source. Static and package validation pass; physical mixed-event acceptance remains pending.
- Danger ownership now separates observation, vehicle safety and infantry tactical authority. Concrete boarding/action/heal/rearm/join tasks and RELEASE states such as authored CARELESS are filtered before engine-to-group submission, clear any older WAIT response and cannot wake group tactics even transiently; a mounted targetless event may run only the bounded passenger stop/dismount slice and cannot enter infantry CONTACT. The contact audit adds real grenades during native GET IN, CARELESS and disabled states, requiring physical boarding or authored-state preservation with no accepted group record or CONTACT handoff, then proves live re-enable. Static/package validation is required; physical acceptance remains pending.
- Casualty and scream danger causes now remain bounded local alerts. They may produce the engine FSM's finite weak hide stance and wake the existing group job for actual casualty/morale bookkeeping, but cannot change group behaviour or ROE, enter CONTACT or unlock tactical planning without separate hostile knowledge. The contact audit kills a real same-group actor and requires native HIDE delivery with the survivor remaining CALM and BLUE. Static/package validation is required; physical acceptance remains pending.
- Explicit BLUE/GREEN fire discipline now remains authoritative through every immediate danger mode and later group planning. The engine FSM may still apply its actor-local finite weak stance and the group may record real contact, but WAIT cannot change ROE or start fire control, artillery, reinforcement, combined-arms requests, coordinated assault, flank or advance. Physical cases cover targetless danger and naturally known contact under BLUE; execution remains pending.
- The engine danger response now accumulates bounded native events while its current reflex completes, then revalidates close hostile contact or effective-commander vehicle awareness through one short follow-up record. A source supplied by the engine or native EnemyDetected event is retained only when hostile and already known, then rechecked against the group knowledge cache before mounted contact can enter combat. Targetless vehicle events remain passenger-safety only and other crew cannot multiply the response. The audit adds real 25-metre hostile fixtures for an on-foot actor and a three-person armoured crew, then requires the existing vehicle layer to enter CONTACT and fire a real weapon without audit-injected targeting. Static validation passes; packaged physical persistence, fire and interruption acceptance remain pending.
- Known-but-unseen contact investigation no longer rolls random permission after consuming a 120-second retry. Every positive profile preference now permits an otherwise eligible physical investigation, zero remains an explicit opt-out, and the retry begins only when the operation actually starts. Static validation passes; physical and packaged investigation acceptance remains pending.
- Coordinated-assault discovery no longer grants speculative movement ownership to either group while responder-owner acknowledgement and route selection are pending. The requester and responder keep native combat and any viable local advance/flank. Only a returned safe assault route triggers an atomic responder handover, which releases the exact local drill before acquiring coordinated movement; only the matching responder acknowledgement then releases the requester's exact local drill and establishes the base-of-fire role. Rejected, missing or delayed coordination therefore cannot create repeated 15-second idle windows on either squad. Static and package validation pass; physical multi-owner acceptance remains pending.
- Bounding advance has no mandatory contact-age wait by default. Confirmed engine knowledge, morale, target range, capable paired elements, authored-order protection and a safe avenue remain required, so a viable squad can begin immediately instead of idling for an arbitrary timer. The CBA delay remains available for mission-specific pacing. Static and package validation pass; physical reaction-time acceptance remains pending.
- The exclusive danger FSM now prioritises the engine queue by tactical consequence: direct hit first, then a live firing opportunity, nearby rounds, own-group casualty evidence, screams, proximity, explosion/other casualty, detection and ambient fire. This prevents a weaker simultaneous observation from displacing an immediately actionable engagement while preserving one bounded selection pass. Static and package validation pass; mixed-cause physical acceptance remains pending.
- Convoy coordination now runs under one registry-revision-owned convoy FSM with explicit CRUISE, SPACING, CONTACT_HOLD, RECOVERY, ORDERED_HOLD, OBSTRUCTION and ARRIVED states. The former indefinitely re-queued convoy worker is removed. Each travel phase submits one coalesced physical step to the shared scheduler; stable holds sleep and are replaced by the next ordered registry snapshot. Existing predecessor trails, size-aware gap damping, contact policy, route recovery, passenger generation ownership and meaningful-roadblock handling remain the physical controller. Zeus, external ownership, registry replacement and locality migration invalidate the brain before another vehicle command. Diagnostics expose phase, revisions, pending state, spacing corrections and recovery actors. Physical mixed-column acceptance remains pending.

# Standalone conversion progress

The [delivery goal](DELIVERY-GOAL.md) defines the required release outcome and the exact difference between implemented, statically checked and physically accepted work. This progress record does not promote a subsystem beyond its evidence.

## Implemented and statically checked

- Breaking WAIT function, setting, state and event namespace migration without forwarding aliases.
- CBA as required external infrastructure, with optional ZEN; WAIT supplies the base-soldier engine danger FSM.
- WAIT verifies final danger-FSM ownership before starting infantry tactics on a server or headless owner. If any west, east or independent base class resolves to another FSM, tactics fail closed and record the conflicting paths rather than running two infantry brains.
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
- WAIT consumes WAIT's public post-migration event when WAIT's native headless manager transfers a group. It reapplies owner-local WAIT state after the engine confirms locality, but never registers, rebalances or migrates groups itself. ACE Headless remains supported through its own event path.
- Startup readiness follows the CBA settings-initialized event after effective server values refresh, rather than the guarded pre-init defaults.
- Repeated skill startup before settings readiness shares a cancellable waiter and reads the joining owner's current effective profile.
- Existing survivor recovery, flank bounds, suppression, landing and braking controls exposed through the authoritative settings specification without changing production defaults.

- Skills and tactics now share one generation-aware owner-local scheduler; disabling either retains the other runtime's jobs and the last runtime releases the callback. Skill refresh retains a ten-unit budget.
- The corrected c0e9009 packaged scheduler batch completed both server and client acceptance: 267 passing checks, no reported SQF errors or fatal runtime failures. It measured skill refresh while tactics were off, callback cleanup, physical arrival of twelve squads while skills were off, and registration/effective values of all 124 CBA controls. This focused result does not establish combat, JIP or performance acceptance.

- Coordinated final bounds now require a COMPLETE owner result; PARTIAL progress yields a turn without falsely retiring the squad's unfinished assault objective.
- Drill eligibility is checked before combat/speed mutations; ownership loss releases the drill without ordering formation return or holding troops against replacement commands. Physical interruption acceptance is pending.
- Audit observer launch explicitly selects its resolution config and 3840x2160 command-line dimensions. Curator assignment is corrected; fresh VR entry and observer Zeus use were previously verified. Runtime `20261009-131702-138` later proved that mission entry and Zeus readiness alone do not guarantee an interactive client window: the client reached VR in its RPT but was not visible to the operator. The launcher now requires a visible Arma window, restores and foregrounds it before accepting the batch, and rechecks visibility after observer Zeus is ready. Reassignment after respawn and the new visible-window gate remain pending physical checks.

## Order of implementation

1. Finish addon ownership, CBA configuration and native Zeus controls; validate CBA-only and optional-dialog operation.
2. Repair continuous infantry intent and communication-based squad coordination, including casualty replacement, fire lanes and interruption.
3. Repair building entry, clearance and traversal across models and squad sizes.
4. Consolidate vehicle driving, convoy obstruction recovery, passenger ownership and gunnery.
5. Repair capability-based aircraft attacks, flight/aiming, countermeasures and support operations.
6. Complete additive acceptance batches, roughly balanced live battles, JIP/HC migration and the 50 mixed-group performance comparison.

Each subsystem retains its gates, documents behaviour and queues physical acceptance before promotion.
This is an implementation order, not a timed automation. Unfinished acceptance remains visible.

- Optional-dialog dependency removed. Native Zeus START/HOLD/RELEASE convoy modules and display-load interruption installation are packaged; new-order speed, separation and contact defaults use CBA. The launcher defaults to CBA only and supports an explicit optional-dialog batch. Static checks passed; physical placement, late assignment and both dependency variants remain unverified.

- Depleted bounding teams no longer wait indefinitely when no recovery participant exists. Three capable survivors can use two movers and one covering actor; membership changes rebuild slots for the same committed bound. Physical casualty and straggler acceptance remains pending.

- CBA now separates eight numbered use-case pages, with explicit sections and enable gates before tuning. Vehicles and registered convoys retain independent controls; keys, values, defaults and activation policies are unchanged. Generated guides use the same section catalogue. Visual CBA acceptance remains queued.
- Infantry ownership discovery now enforces WAIT as the sole base-soldier danger-FSM owner. Another replacement of that engine slot is unsupported; specialist actors and finite alternative-movement leases still yield through explicit markers with exact baseline restoration. Physical specialist handover acceptance remains pending.

- A finite local danger response now promotes only its existing squad decision job to contact cadence. This lets a distant group use its native engine knowledge without waiting for the normal player-distance interval, while retaining the shared scheduler, route owner and performance bounds. Physical response latency and 50 mixed-group acceptance remain pending.
- Group `EnemyDetected` handoff now submits the engine's believed contact position rather than the observer's own location. This preserves uncertainty while preventing co-located threat geometry from generating zero-length, lateral or reversing tactical routes. Engine cause 10 remains a local ASSESS record and cannot manufacture group contact. Static/package validation is required; physical route acceptance remains pending.
- Danger-only CONTACT entry no longer indexes an empty visible-enemy list. A hit, explosion or suppression can now enter CONTACT using the bounded engine danger position, with an explicit `DANGER_CONTACT` reason, until native knowledge provides a target. This prevents an SQF error from terminating the group step and presenting as an unexplained AI stall. Static/package validation is required; physical no-visual-contact acceptance remains pending.
- Incoming-missile defence now uses the same finite shared scheduler as the rest of WAIT. A newer warning invalidates the earlier generation, and each response emits bounded countermeasures with at most two terrain-checked flight impulses. This removes the independent sleeping worker; real missile evasion and flight-quality acceptance remain pending packaged testing.

- Convoy lead-road and follower-trail grade sampling now uses absolute elevation. Terrain-relative heights previously hid hills from the safety cap. Query bounds and cadence are unchanged; sloped-route physical acceptance remains pending.

- General driving assistance is active as a separate next-operation feature. It samples only three forward terrain points every four seconds, converts its documented km/h policy caps to the engine's m/s command units, and restores only the exact cap it owns. A takeover during sampling releases the unissued lease instead of retaining stale state. A stalled ordinary route can receive one refresh, one clear-rear reverse and one final retry outside combat; it never rewrites waypoints, bypasses obstacles or changes collision. Physical stop, recovery and mixed-traffic acceptance remain pending.
- Convoy speed ownership is now vehicle-scoped. Each applied travel or halt cap records its group, revision and engine-unit value; release restores a pre-convoy speed only when that exact cap remains current, the vehicle is actually leaving convoy control and no group, crew or driving controller has taken over. This prevents configuration refreshes and Zeus/external handovers from producing a restore/reapply pulse or reviving an obsolete speed command. Physical handover and stop/resume acceptance remain pending.
- Passenger contact dismounts now use the same exact speed-lease rule. The vehicle authority records both the pre-stop cap and WAIT's owned zero cap; request expiry, group release and master shutdown restore the baseline only if zero is still current. A Zeus, mission or specialist speed change therefore survives cleanup instead of being replaced by the stale pre-dismount value. Physical moving-contact and interruption acceptance remain pending.
- Mounted danger response now requires the current seven-field exact-platform record. Expired, malformed or stale vehicle identity is discarded; it can no longer widen one hit, explosion or contact into stop, dismount, abandonment or gunnery commands for every vehicle in a mixed group. Multi-vehicle physical acceptance remains queued.
- Calm passenger remount now cancels on a live danger response as well as visible contact. Still-dismounted passengers remain in the task record, and boarding/cancellation commands recheck Zeus and specialist ownership at each engine write. This prevents a hit or suppression event from leaving a squad boarding while the same tick enters combat assessment. Physical remount interruption acceptance remains pending.
- Naval disembark now records its shore-stop as an exact zero-speed lease. Normal completion and cancellation restore the boat's earlier cap only when zero remains current and no external takeover occurred; newer helm orders survive cleanup. Physical approach, disembark, takeover and egress acceptance remain pending.

## Still outstanding

- Optional engine-policy PBOs and remaining behaviour implementations. Medical assistance now uses one bounded owner-local native treatment operation during CALM/SECURITY, yielding to direct/external ownership; it still requires physical, transition and performance acceptance.
- Remaining CBA configuration gaps and physical validation of activation behaviour.
- Deep assessment of every remaining method, including simulation/recovery shortcut purpose.
- Building, manoeuvre, aircraft and coordination fixes and fresh batched physical acceptance.
- JIP, headless migration, CBA server enforcement and 50 mixed-group measured performance.

External Git bundles preserve recovery. GitHub PR history, forks and caches can retain old content
after a ref rewrite; removal is not universal. Static success is not live acceptance.

## Current non-promoted repairs

- The packaged audit mission now declares only the concrete BLUFOR soldier package and VR terrain used by its placed observer. Declaring the core character package itself as mission content caused Arma to emit a false deleted-content blocker even while the inherited playable soldier classes loaded. The audit retains required production-addon checks through the packaged mod and treats any remaining real missing-addon warning as a hard failure.
- Packaged runtime `20261008-114125` proved that the engine rejected the configured infantry danger brain with `FSM '\z\waldo_ai_tweaks\addons\infantry\fsm\danger.fsm' cannot be loaded`. The PBO contained the file, but it was a bare FSM class without the named `scriptedFSM.cfg, Danger` compile envelope required by the engine-loaded `fsmDanger` slot. The source now carries that envelope, the Arma 3 Tools FSM compiler enumerates it as `danger`, and a regression contract prevents packaging another text-valid but engine-invisible danger brain. A rebuilt physical danger batch remains required before parity is claimed.
- Tactical bounds now treat physical arrival as the handoff trigger. The shipped overwatch pause default is zero, zero-duration PAUSE/HOLD phases are requeued at the next shared-scheduler opportunity instead of inheriting the 1.5-second observation cadence, and road smoke no longer imposes a fixed three-second wait. Mission makers may still configure a deliberate post-arrival interval. Grenade and smoke animation never extends it. Static and package validation pass; physical tempo, cover continuity and interruption acceptance remain pending.
- Packaged runtime `20261007-152049` exposed a command-boundary type failure in the shared external-ownership predicate: its first player-membership condition was wrapped as SQF code and then combined with Boolean `||`. Every ownership check therefore errored and rejected the first DEFEND order, invalidating the remainder of that batch. The predicate now begins with a Boolean expression and an explicit regression contract protects its shape. The packaged audit also executes the predicate as a command-boundary preflight and aborts before creating behavioural fixtures when any prerequisite fails, preventing a shared fault from becoming hundreds of misleading timeouts. Static validation passes; the failed runtime remains evidence and a rebuilt batch is required.
- Registered convoy travel now creates one owner-local `CONVOY` operation per revision. The operation records progress at the shared bounded cadence, completes only on an accepted arrival hold, and cancels on Zeus, player control, external ownership, mobility failure or a replacement route revision. The predecessor-trail, spacing and physical-roadblock controller remains unchanged. Static validation passes; mixed-column interruption, locality and obstruction acceptance remains pending.
- Support reservations now create a matching `SUPPORT_RALLY` or `COORDINATED_ASSAULT` operation on the accepting group owner. The existing reservation token remains the authoritative cross-owner record; its operation generation only tracks progress and makes lease expiry, feature closure, Zeus, external ownership and server retirement cancel the same finite assignment. Naval delivery now tracks boat-crew `NAVAL_ASSAULT` and passenger `NAVAL_LANDING` operations separately, preserving the existing public landing token and never allowing a passenger handover to replace crew movement. Static validation passes; physical support, landing, interruption and HC migration acceptance remain pending.
- Danger assessment now stops at admission, observer setup and FSM interruption when a curator, player, compatible specialist controller or other external owner holds the group. It clears only WAIT-owned response state and never wakes the group decision job after that handover. Static and package validation pass; live specialist and Zeus handover acceptance remains pending.
- The engine danger FSM now owns a finite per-soldier weak-stance lease. It retains the actor's original authored stance across coalesced danger events, restores only WAIT's exact applied value on exit, and discards the lease without writing when the engine, Zeus or a specialist controller has changed stance or ownership. Hit, explosion and suppression may additionally request one nearby physical-cover move for one genuinely idle actor through the existing group tick. Casualty and scream events remain mobile alerts, and an operation, native command or newer owner blocks the move.
- A running engine danger response now has a cheap interruption edge during its finite wait. Runtime shutdown, danger-feature disablement, pause, direct curator control, a new Zeus token, Zeus-owned waypoints or explicit external ownership ends the response immediately. The check performs no actor collection, config inspection, geometry work or scheduler submission.
- The group danger-assessment FSM no longer performs a full player/specialist takeover scan in its per-evaluation wait condition. Cheap locality, generation, runtime and Zeus checks remain immediate; the bounded assessment step performs the complete ownership check every 250 ms. Group cause priority now matches the immediate layer by ranking casualty evidence above screams.
- Targetless danger no longer leaves a group in a thirty-second artificial CONTACT state. The group returns to its prior behavior as soon as the finite danger lease ends, while native enemy knowledge acquired during that lease promotes the state into the ordinary occlusion and post-contact flow.
- Base soldier classes now load a bounded WAIT danger FSM. It consumes engine cause/position/expiry/source queues, separates reflex-only friendly hazards from group combat observations, requires a live hostile source for engage states, and wakes the existing finite group assessment without adding movement ownership. Static/package validation and physical handover acceptance remain pending.
- The configured WAIT danger FSM remains the base-soldier engine slot for the running addon, but its runtime, danger-feature and pause gates now exit without issuing WAIT stance, movement, target or planning commands. This keeps CBA disablement truthful without requiring a config restart; another addon replacing the same engine slot remains unsupported.
- Engine-confirmed contact handoff now uses the observing actor's native believed target position. It no longer substitutes the observer's own position, which could collapse the threat geometry onto the squad and produce lateral, reversing or zero-length routes. A danger-only CONTACT transition also has an explicit fallback position and no longer selects an empty visible-contact array. Static and package validation pass; fresh physical route acceptance remains pending.
- Danger-only CONTACT now separates immediate safety from target-dependent planning. Morale, finite posture, cover stance and vehicle stop restoration remain responsive, while anti-armour, artillery, reinforcement, coordinated assault, flank, advance and post-contact search wait for native target knowledge. A hazard-only engagement returns directly to calm after its finite lost-contact interval and clears its per-engagement knowledge marker. Approximate danger geometry therefore cannot consume tactical cooldowns or dispatch units toward an unidentified hazard. Static and package validation pass; physical transition acceptance remains pending.
- A targetless hit, explosion or suppression now creates one bounded passenger-safety lease for mounted groups. It reuses the exact safe-stop and cargo-exit handshake before the vehicle layer's no-enemy return, including a bounded approximate report from the local crew owner to separate allied passenger groups. The lease cannot select a target, publish target knowledge, withdraw the vehicle or issue a route. Cleanup retracts the report and restores only WAIT's exact zero-speed cap. The queued vehicle audit now starts an enemy-free moving truck, delivers a real grenade explosion through the engine FSM and requires physical cargo exit, operating-crew retention and no invented combat. It also corrects an always-true seat predicate in the older contact audit. Live acceptance, Zeus replacement and migration variants remain pending.
- Shared operation cleanup now records whether the operation began on foot. Only those operations release a WAIT danger-posture lease; aircraft, vehicle and naval operations retain their native combat state while still receiving the same generation, cancellation and diagnostic lifecycle. Static validation passes; mixed-operation handover acceptance remains pending.
- Shared operation progress now retains each actor's last meaningful position until that actor crosses the configured distance. Slow continuous travel therefore accumulates instead of being erased at every scheduler callback and misclassified as a stall. Static validation passes; packaged physical acceptance remains pending.
- Shared recovery progress is now actor-scoped. A quarantined actor can renew only its own observation window and cannot conceal a stationary manoeuvre element. Tactical drills consume the shared STALLED outcome at the configured bound timeout; support releases a stalled reservation as NO_PROGRESS; withdrawal re-reads the operation after quarantine and advances to another eligible straggler instead of retrying the same exhausted actor. Static validation passes; physical blocked-actor, support-stall and withdrawal-casualty acceptance remain pending.
- Ground tactics, building progression, convoy control, aircraft attacks and cross-squad support now recheck Zeus and external ownership while their shared-scheduler callback is pending. These FSMs release immediately and do not wait for the starvation watchdog. Ground/building/convoy controllers use their existing owned-state release; aircraft first removes its exact temporary waypoint and flight lease through the normal attack cleanup; support first retracts exact responder reservations. Artillery retains its separate uncertain-shot quarantine after an accepted native fire command, but issues no later shot or movement command after eligibility is lost. Static validation passes; packaged interruption acceptance remains pending.
- Building and convoy callbacks now propagate terminal shared-operation results to the outer function scope before any later room, formation, speed or recovery mutation. A replaced combined-ground generation can no longer clear the replacement generation's movement or alternative-backend lease. These fixes close nested SQF `exitWith` paths that released ownership but then continued executing the old callback. Static and package validation pass; physical Zeus, replacement and locality interruption acceptance remains pending.
- Medical assistance now uses an explicit finite physical approach followed by Arma's native `HealSoldier` action at treatment range, including immediate treatment when already close enough. The previous unrecognised `doHeal` form blocked PBO compilation. Every movement and treatment write now rechecks Zeus and specialist ownership. A live danger response cancels aid before the same group tick continues into combat assessment, preventing treatment from delaying a hit or suppression reaction. Support lease and feature-expiry exits were also corrected to top-level finite-operation exits. Seven PBOs now compile and seal; physical treatment, danger interruption and support-release acceptance remain pending.
- Building clearance now forms bounded lead/security pairs rather than giving the first available room to one single-worker lane. The security partner remains at a real entry until the lead crosses it, follows into the first room, and trails successive rooms; buildings with no usable entry positions still receive a physical paired first-room attempt. Static and package validation pass; multi-model, casualty and traversal acceptance remains pending.
- Danger/contact assessment now recognises only a recent native-known hostile physically inside a usable building, after model-bound and overhead-geometry confirmation. A capable squad can transition from contact into the existing finite clearance owner without tearing down its contact brain; approximate danger, outdoor contacts, vehicles, explicit ownership and undersized elements cannot trigger entry. Coordinated support receives first refusal and open-ground manoeuvre is skipped only after the building operation accepts. Static and packaged validation are required; the additive physical acquisition/entry audit remains pending.
- Room-progress leases now follow the assigned room mover after entry. Security partners may still adjust cover and trail the preceding room, but their movement can no longer conceal a doorway-stalled lead or postpone actor recovery indefinitely. Physical multi-model acceptance remains pending.
- CQB progression, support coordination and the central infantry tick now test dismounted eligibility directly through `objectParent`; the same bounded check covers stance, anti-armour selection, flank casualty replacement and ammunition sharing. This removes repeated vehicle resolution from recurring actor filters without adding caches, jobs or state, while preserving the rule that mounted crew cannot become room clearers, infantry bounders or on-foot tactical replacements. Static validation passes; physical infantry, CQB and support acceptance remains pending.

## Assault handoff responsiveness

A valid flank/advance assault transition now commits the covered approach and issues it in the same owner-local scheduler step. At physical assault-position arrival, an element without a queued frag starts its clear-through in that step. Existing feature gates, casualty replacement, ownership checks, cover selection and configured ordinary bound pauses remain in force. No new loop, scan or setting is added.

Grenade dispatch now occurs asynchronously beside the clear-through operation: the throw helper retains its own safety cancellation, while the moving element receives its next bound in the same owner-local step. Do not treat the static transition contracts as evidence of live assault effectiveness. The next combat batch must check single-squad and coordinated approach/clear-through, cancelled grenade requests, live projectiles, casualty replacement, Zeus interruption and cleanup.

The first standalone combat batch exposed an audit prerequisite defect: camera travel left the human observer over 6 km from fixtures, outside the real tactical participation range. Audit phase changes now place only the protected on-foot observer 150 m from the named fixture on the observer's owner. Production range settings and fixture AI positions are unchanged. The running fe7c39d batch retains its results; this audit repair requires a fresh staged run.

- Building clearance now runs under one generation-owned `buildingOperation.fsm` with explicit `ENTRY`, `SWEEP`, `REPLAN` and `EGRESS` states. The FSM itself remains cheap and non-suspending: each state submits one coalesced physical-progress step to the shared scheduler, while native pathfinding, target engagement and suppression remain active. Room visits, retry evidence, casualty replacement and actor-scoped recovery retain their existing physical authority. Zeus, external ownership, shutdown, replacement and locality changes invalidate the generation before further movement writes. Diagnostics expose phase, generation, owner epoch, queue state, progress age and room counts. All static, FSM and package gates pass; multi-model physical clearance and interruption acceptance remains pending.
- Aircraft attacks now run under one owner-local `airAttackOperation.fsm` with explicit `PLAN`, `INGRESS`, `ATTACK` and `EGRESS` phases. The FSM owns persistence and queues one coalesced step at the attack controller's requested cadence; the existing bounded implementation still validates live ammunition, terrain, target knowledge and control before native flight or weapon commands. Discovery and combined-arms opportunities can no longer create a self-rescheduling aircraft job outside the operation brain. Static and package validation are required before this is promoted; physical weapon, terrain, interruption and locality acceptance remains pending.
- Aircraft weapon ownership now follows the same committed-intent rule as movement. WAIT selects the planner-retained weapon station once when ATTACK begins, then leaves native pilot/gunner acquisition intact. A native release request receives three seconds to produce a real `Fired` event and only one no-shot retry; real fire resets that bounded retry state for the remaining finite salvo. This removes per-callback weapon selection and sub-second request churn while retaining exact-magazine validation and physical-shot evidence. Static validation passes; packaged gun, rocket, guided and bomb acceptance remains pending.
- Aircraft targeting no longer promotes an already known contact to maximum knowledge. The retained native target remains the attack object, while native observation and configured crew skill determine precision. Zeus, route-replacement and external-owner cleanup no longer clears crew target/watch state after the new owner has acted. A normal WAIT completion clears only the exact assigned target that WAIT still owns, and only while no external owner is present. Static validation passes; packaged knowledge, lethality and handover acceptance remains pending.
- Aircraft movement mutation now has one owner-local priority lease shared by landing, missile defence, attack and optional braking. A lease is bound to controller, generation token and locality owner; stale cleanup cannot clear a newer controller. Committed landing has priority over defensive velocity breaks, defensive separation over attack, and attack over cruise braking. Incoming-missile countermeasures still fire during landing, but cannot inject a competing velocity correction near terrain. Every mutation boundary rechecks player, Zeus, specialist and locality ownership. Static validation is required; live pre-emption and handover acceptance remains pending.
- Artillery and counter-battery missions now persist through one server-owned `artilleryMission.fsm` with `REQUESTED`, `WARNING`, `FIRING` and `RELOCATING` phases. Each state submits one coalesced bounded mission step through the shared scheduler. Existing owner-local observation, safe aim, physical shot confirmation, first-lethal-burst red warning smoke, uncertain-shot quarantine and shoot-and-scoot group handoff remain authoritative. Stop or replacement cancels the exact mission generation before another command can be issued. Static and package validation are required; physical fire, warning timing, interruption, relocation and headless-owner acceptance remain pending.
- Cross-squad reinforcement and coordinated-assault requests now persist through one server-owned `supportRequest.fsm` with `DISCOVER`, `RESERVE` and `COORDINATE` phases. It replaces the self-rescheduling server callback while retaining the bounded nearby candidate set, separated rally areas, immediate contact-to-avenue handoff, current-owner acknowledgement and expiring responder roles. The FSM never moves a responder itself; each current group owner continues to reject Zeus, player, specialist or newer-order conflicts before issuing a local command. Static and package validation are required; live multi-owner, casualty, no-responder and interruption acceptance remains pending.
## Danger framework foundation

Danger observer cleanup now invalidates and unpublishes the exact assessment generation in the same
owner-local step. A disable, locality handover or external takeover first retires WAIT's finite cover
lease, discards posture ownership without restoring over the new controller, and clears stale assessment
timing. `DangerRequest` reuses an assessment FSM only when both owner epoch and danger generation still
match. An old FSM may finish naturally after invalidation, but it cannot absorb the first observation for
the replacement owner and create a silent response gap. Static and package validation are required;
physical disable/re-enable, locality migration and Zeus replacement acceptance remain pending.

Danger-source allegiance now comes from the source object itself at every engine, observer, queue and
recycle boundary. The earlier infantry-only `group source` assumption could reduce a vehicle, static
weapon or aircraft contact to an unknown-side object and discard its native hostile identity before
the vehicle or combined-arms layer saw it. This correction adds no target scan or reveal and retains
the existing native-knowledge requirement. Static/package validation is required; physical infantry
against hostile manned and unmanned vehicle acceptance remains pending.

A live native `CANFIRE` response now reaches the existing rotating suppression primitive when its
engine-known contact is beyond assault distance. It uses only `CortexKnowledge`'s believed position,
the current danger generation, existing ammunition thresholds and friendly-fire check. It creates no
target reveal, firing worker or movement owner, closing the previous gap where WAIT visibly adopted a
combat posture but contributed no immediate fire. Packaged physical firing evidence remains queued.

The same direct-object allegiance boundary now protects adjacent observation paths: artillery spotters,
FiredNear hearing and convoy damage intake retain hostile vehicle, aircraft and static-weapon identity
instead of evaluating a possibly empty object group. Static regressions pass; mixed-platform physical
acceptance remains queued.

Danger recycling now requires a usable engine-believed position on every finite follow-up. Loss of that
position ends the actor response instead of substituting the hostile object's exact live coordinates;
normal native detection can wake the group again after a genuine reacquisition. Two-dimensional believed
positions inherit only the observing actor's local height, never target precision. Static validation is
required; physical lost-knowledge/reacquisition acceptance remains queued.

Native casualty meanings now remain distinct through the complete engine-to-group handoff. Losing a member
of the observer's own group retains `CASUALTY` priority for prompt survivor and role bookkeeping; discovering
another body is a shorter `BODY_FOUND` alert. Neither cause fabricates an attacker, changes ROE, authorises
CONTACT or issues movement. The contact audit now includes a real other-group death in front of the observer
and requires the native cause to remain distinct. Static validation passes; packaged physical delivery remains
queued.

The persistent ground decision owner is now `groupTactics.fsm`, with semantic CALM, INVESTIGATE, CONTACT, SUPPORT, MANOEUVRE, ASSAULT, CLEAR, SECURITY, SEARCH, REGROUP and WITHDRAW states. Each state queues one bounded decision through the shared scheduler; scripted FSM state bodies do not perform geometry scans or wait on animations. The older group tick remains a bounded implementation callback during phase-by-phase extraction, rather than a second persistent worker.

Its scheduler wait now has a bounded fifteen-second starvation watchdog. A delayed or lost due callback wakes the
same generation-keyed queue entry rather than appending work, and a cancelled callback exits before invoking legacy
group logic. The watchdog cannot run during SafeStart or ENDEX and remains suppressed through the scheduler's
resume grace. Ordinary pause deferral and bounded queue latency therefore cannot cause the FSM to clear and requeue
healthy work every few seconds. Owner epoch, generation, addon-disable and explicit cancellation can still end the
wait immediately. Diagnostics expose the watchdog count so real queue pressure is visible instead of appearing as
an unexplained idle squad.

The same bounded wait contract covers building, convoy, aircraft-attack, artillery and support-request FSMs. Each
queued step records its submission time; only a fifteen-second unpaused overdue wait wakes the same coalescing key,
and a cancelled or finished callback exits before physical implementation logic. Controller diagnostics include
their recovery counts. This removes an identical indefinite-wait path from six production brains without adding a
worker, scan or per-unit loop. Static validation passes; physical queue-pressure acceptance remains pending.

The tactical-drill FSM now gives a lost recurring advance/flank callback a fifteen-second same-key retry before
the existing thirty-second group cleanup releases the manoeuvre. This preserves a chance to continue through
transient scheduler pressure while persistent callback failure still restores owned AI state. The local diagnostic
record exposes retry count and is removed with the matching FSM.

Up to twelve owner-local AI group members now feed one finite owner-local assessment FSM, enabled by
default under the normal CBA contact settings. The evaluator coalesces causes, rejects expired records and
selects urgency without sorting. Its one group-level contact event accepts only engine-confirmed hostile knowledge
already held by the leader and passes the observer position, never a target identity or position. Event callbacks do
no squad/world scans; repeated causes are throttled before dispatch. The FSM publishes one short-lived, generation-scoped response context and wakes the
existing group decision job inside the shared budget. It never reveals a shooter, replaces a committed route
or creates a second movement owner. The context survives observer membership churn, preserves a stronger
live cause over weaker later events, expires cleanly, and is cleared before Zeus or external takeover can
consume it. Static/package validation is separate from the still-pending live physical reaction, transition and
performance acceptance.

The engine intake no longer discards first contact while waiting for the discovery interval. An eligible local
group that receives a native danger cause starts the same single group brain that discovery would create, then
coalesces the cause through the existing assessment FSM. Forced commands and mounted crews receive no posture or
movement command. Immediate and hide reactions remain weak native posture suggestions, while diagnostics retain
bounded counts for first-contact starts, accepted causes and response modes. Static/package validation is required;
physical first-contact latency, Zeus replacement and headless migration remain pending.

That native first-contact bootstrap now installs the same repeat-safe group `EnemyDetected` observer before it
publishes the tactical brain. Previously the first engine reflex and group wake could succeed while later native
contact identity waited for the sparse discovery sweep to install the observer. The bootstrap adds one group event
handler, no per-unit handlers, no scan and no second worker. Static validation passes; physical consecutive-contact
and locality-handover acceptance remains pending.

Forced-command and mounted checks now repeat at the queued group-assessment boundary. This closes a delayed race
where the immediate FSM yielded correctly but the later cause-only classification still changed group behaviour or
ROE. Explicit BLUE/GREEN hold-fire modes remain unchanged; ordinary WHITE/YELLOW groups may receive a finite YELLOW/RED response. Boarding, action,
healing, rearm, join, fleeing and vehicle owners remain observation-only. Native `ATTACK` stays eligible because
it is also Arma's ordinary autonomous combat command; the response does not replace its target or destination.

Each live response now also carries a finite action classification: `HIDE` after a hit, explosion or suppression,
`ENGAGE` after an engine-confirmed contact or nearby gunfire, `VEHICLE` for a mounted leader, and
`MAINTAIN` for a group that already has a committed operation. `RELEASE` marks an ownership handover.
The classification drives only a finite behaviour/combat-mode posture and scheduling context; native AI retains
target selection and movement, so it cannot introduce a second route owner or a forced firing loop. `MAINTAIN`
now means preserve the committed advance/flank/CQB/withdrawal route while still applying that bounded posture.
Previously, the presence of any operation caused the reaction function to return without responding at all.
Starting a new on-foot operation now reattaches any still-live danger context only after the new generation is
authoritative; stale posture is released. Contact-to-manoeuvre transitions therefore do not briefly discard the
combat response while waiting for another engine event.
Completion or cancellation now performs the inverse handoff: after removing the old movement owner, it
reclassifies an unexpired danger context and restores only the bounded posture. Zeus, player and specialist
takeover still rejects that reaction, so a new external order cannot be overwritten.

A validated live danger response now moves a CALM squad into CONTACT during that same awakened group tick,
even when the engine has not supplied a visible or known enemy. The transition does not carry shooter identity,
reveal a target or manufacture an enemy position; it enables the finite combat lifecycle, interruption and
post-contact cleanup that previously remained dormant until a separate visual sighting occurred. Physical event
delivery, no-knowledge contact behaviour and expiry back through the post-contact chain remain pending acceptance.
- Immediate danger cover now preserves the exact living local soldier selected by the native engine event in the surviving action lease. A wingman's hit, explosion or near-round response can no longer discard that observer identity and move the group leader instead, even when a newer lower-priority assessment is evaluated while the original response remains authoritative. The same one-actor, group-budgeted cover lease remains in force; stale, dead or migrated observers fall back to the current combat-effective anchor. An additive physical case separates the leader and wingman, delivers a real explosion beside the wingman and requires the action lease, cover lease and physical travel to belong to that observer. Static/package validation and batched physical execution remain required.
- Group danger handoff now consumes one strongest cause per finite assessment step and retains every other valid live cause for the next bounded step. A hit, explosion or near round can therefore keep its higher-priority physical response while a simultaneous native-confirmed detection still reaches contact authority instead of being erased. Duplicate causes remain coalesced, the queue stays bounded, and no extra scheduler or world scan is added. Static validation is required; the existing mixed-cause packaged acceptance remains queued.
- Native-task interruption now follows the actor stored in the surviving danger action lease, even while weaker mixed causes continue through assessment. A lower-priority event from another squad member can no longer redirect the ownership check away from the soldier boarding, healing, rearming or joining. WAIT releases only its exact response and leaves the native command untouched. Static validation is required; the existing mid-response boarding case remains queued for packaged acceptance.
- Approximate detection, proximity, firing-opportunity and gunfire observations are now classified before the existing-operation `MAINTAIN` path. An event with no native-known hostile may preserve an advance, flank or clearance route through the operation owner, but it cannot turn that route into CONTACT or RED fire authority merely because movement is already active. Static validation is required; known-hostile versus unidentified-fire comparison remains queued for packaged acceptance.
- Ordinary mounted groups now lease the engine unload-in-combat policy on the exact locally owned ground vehicle while WAIT owns deliberate passenger contact handling. This closes the path where native autonomous unloading could bypass passenger task generations, safety checks and Zeus ownership. The lease records the previous and applied values, is separate from convoy control, survives locality adoption, yields without restoration to external control and restores only when WAIT's exact applied value remains current. A newer external policy change is preserved and blocks reacquisition for the current group epoch. Static validation is required; mixed crew/passenger, separate-group task replacement and locality migration remain queued for packaged acceptance.
- Compatible carried static-weapon teams can now physically deploy and recover one emplacement. WAIT selects one primary bag and its matching base bag, commits the same two actors to one dry, level firing sector, uses native bag/assembly actions, and gives the original primary-bag carrier a finite ordinary boarding attempt. Existing emplacements still take priority. During post-contact security, the same pair exits, approaches the exact WAIT-deployed weapon, uses native disassembly and takes back its original bags. Renewed contact before disassembly remounts the gunner; renewed contact after disassembly lets the finite bag recovery finish before another deployment. Failure leaves the physical weapon or bags in the world and releases the squad. The operation never creates, deletes, teleports, force-seats, rearms or repairs equipment. A saved natural-contact audit requires configuration compatibility, physical assembly, the original carrier in the real gunner seat, real weapon fire, native recovery of both bags and exact cleanup. Static validation is required; the fixture has not yet run.

- Finite squad concealment now ranks eligible responders by tactical replacement cost before applying its four-actor cap. Ordinary riflemen lower their profile first; leaders, machine gunners, medics and loaded AT/AA gunners remain available where the squad has other eligible actors. Tiny specialist teams may still receive the weak stance fallback, but WAIT adds no movement, weapon switch or fire restriction. Static validation is required; mixed-role physical acceptance remains queued.

- Contact assessment now separates weapon targets from foot-manoeuvre objectives. Autonomous advance, flank and assault selection considers dismounted infantry and fixed emplacements; mobile vehicles, mounted crew and aircraft remain with native fire, anti-armour, support or withdrawal. A mission-authored MOVE, SAD or DESTROY objective may still advance through vehicle contact because WAIT preserves that external route. This removes a duplicate movement response without adding a scan or scheduler. Static validation is required; mixed infantry/vehicle physical acceptance remains queued.
- Combined-arms role dispatch now shares hostile knowledge without pre-targeting every crew member. Only the stationary ground-fire role issues one explicit target/fire request to its actual gunner. Ground manoeuvre reaches its selected firing area before requesting fire, while aircraft leave target and weapon ownership to the finite air-attack controller. This removes an engine ATTACK/pursuit command that could replace a vehicle route or create a second aircraft targeting owner before the intended operation began. Static validation is required; packaged ground-fire, manoeuvre-route and aircraft-role acceptance remains queued.
- Fixed-wing pilot-operated surface attacks now use their object-attached native `DESTROY` waypoint as the sole attack-movement owner. WAIT no longer sends duplicate target/watch commands to both the aircraft object and pilot before release; independently aimed turrets, helicopter pilot weapons and air-to-air operators still receive one operator-local target instruction. This closes another route-to-ATTACK replacement path behind circling and missed attack runs while preserving native aiming and real weapon release evidence. Static validation is required; packaged gun, rocket, bomb, guided and handover acceptance remains queued.
- Defence casualty reinforcement now reapplies only the reserve actors whose positions changed. The established firing line retains its hold, watch sector and committed route instead of being reset when one reserve element fills a gap. Per-actor route generations invalidate an older arrival watcher for reassigned soldiers without cancelling other defenders still approaching their original positions. This removes the former duplicate reserve `doMove` and whole-line replanning pause. Static/package validation passes; physical casualty reinforcement and Zeus-interruption acceptance remain queued.
- Garrison movement now releases formation with `doStop` only on the initial ownership handoff. A stalled-route retry, alternate entrance or replacement position issues one `doMove` without first injecting another STOP command, while physical arrival still establishes the intended hold. This removes a systematic pause from every recovery branch without weakening bounded retries or external-owner checks. Static/package validation and multi-building physical acceptance remain required.
- The packaged `dangerparity` run from commit `744cf13` proved that the tactical-contact fixtures had acquired real native knowledge, but three wait predicates still returned false because their inline `findIf` expressions were parsed ambiguously. Each predicate now stores the documented `[contacts, seenCount]` result first and explicitly compares the completed contact search with zero. This prevents a successful contact from consuming the entire wait window, allowing armour and elevated-position policy to be judged at the intended initial geometry instead of after native AI has already closed hundreds of metres.
- The same run also exposed an older vehicle-audit parenthesis error. That expression is already corrected in the current candidate by commit `4dc740a`; the next packaged batch must confirm both audit repairs before any tactical result is promoted.

Separate passenger remount evidence: candidate e5fbdd6 physically remounted the stationary
separate-group passengers with both original groups retained. The moving separate-group case
still failed. Remount retirement now records contact, authored order, external ownership,
disabled state, resolution/reassignment or deadline, with pending vehicle speed, distance and
assignment. This is diagnostic evidence for the remaining failure, not a behavioural fix or pass.

Infantry support reservation now rejects groups containing living operating vehicle crews,
even when three or more dismounts are available. This closes the group-rally authority gap
without disabling vehicle-domain support or independent passenger squads. Static regression
coverage is present; mixed-group physical acceptance remains pending.

Tracked withdrawal in candidate e5fbdd6 failed physical reverse and escape distance while smoke
and crew retention passed. Inspection found vehicle lease retirement still required a tagged
waypoint even during the waypoint-free native reverse leg. The lease now recognises only a
matching generation/epoch, local live vehicle, owner marker and unexpired reverse record.
Physical retest remains required; a valid record alone does not establish reverse movement.

Withdrawal audit candidate e5fbdd6 reported HC resume, preserved origin, continued physical
escape, no smoke replay and crew retention. The fixture did not record the immediately preceding
owner, so these results alone cannot prove an owner boundary was crossed. The next candidate
records the source owner, chooses a different available HC and requires a distinct owner for
resume/physical-continuation acceptance. This retains the observed movement evidence without
promoting an unproven migration claim.

The withdrawal Zeus fixture marked a waypoint event before adding the replacement waypoint,
allowing its snapshot to capture the retiring WAIT route. The fixture now releases through a
direct takeover, creates the ordinary replacement waypoint, then snapshots its exact index and
position through the production waypoint handover. It asserts that snapshot before judging
travel. Earlier replacement/resurrection failures remain recorded but do not isolate a production
curator-event defect. Retest is queued while game audits are paused.

The gunner recovery fixture used a platform which supplied no dedicated commander; the live
failure payload recorded commander null while the driver remained in its original seat. It now
uses the three-seat tracked APC and explicitly asserts distinct driver/gunner/commander roles.
The earlier prerequisite-dependent driver assertion cannot establish a driver reassignment bug.
Real commander-to-gunner recovery remains unproven until the corrected physical case runs.

Cover candidate geometry now intersects the threat-away ray with rotated object bounds rather
than using a capped circular half-diagonal. Candidates must remain within the requested search
radius and still pass existing slope, occupancy, clearance and ballistic screening checks.
This repairs a geometric rejection risk for rectangular/long objects; physical cover acceptance
across terrain and building models remains pending.

Group-hide generation replacement now restores an old unchanged weak stance before dropping
its lease, only for local idle actors still in the group with no actor-level stance or movement
owner. Previously the old posture could survive after its proof was discarded and become the
next generation's baseline. Physical exact-posture cleanup remains queued for retest.

Active danger-cover lease retention now rechecks current generation, live feature gates,
external ownership, operation ownership, mounted state and native command before returning
active. A previously valid timer no longer masks a newer order or disabled response. Physical
interruption and cleanup acceptance remain queued while audits are paused.

Danger-cover cleanup now requires the exact actor-move deadline and current expected destination
before returning a nonleader to formation. Living local membership, on-foot state and absence of
player/external/operation ownership remain required. A replacement native MOVE destination is
preserved even when the command name matches the old move. Physical new-order retest is pending.

Anti-armour relocation retirement now clears only its exact actor marker, destination and
deadline on the current actor owner. A successor grenade, cover or static-support reservation
is preserved. This closes stale marker deletion without adding scans or recurring workers;
physical transition acceptance remains pending.

Carried-static retirement now rechecks successor operation and external ownership inside its
cleanup boundary. Those handovers retire old event handlers and records without unassigning
crew or issuing return-to-formation commands into the new task. Physical handover remains pending.

Packaging boundary: clean candidate 7bc6c6b passes the full static/package pipeline, including
519 tests, 277 SQF files, 171 config files, 139 settings and eight addon PBOs. No separate optional
engine-policy PBOs or optional policy release layout currently exist. Runtime crew skill/aim
coefficients do not fulfil that locked delivery requirement. Policy design must preserve player
projectile accuracy, remain restart-required and receive config plus physical acceptance before
release inclusion. This is outstanding implementation, not an optional scope reduction.

The passenger safe-stop handshake now also accepts a current bounded remount record, checked
against original vehicle, surviving passenger membership, assignment, distance, feature state
and external ownership. Crew contact or active vehicle movement ownership rejects this boarding
hold. Passenger owners refresh requests only within the remount deadline; boarding, reassignment
or expiry removes eligibility. This repairs the missing cooperation path but moving remount
physical acceptance remains pending. At most eight boarding records are considered per vehicle.

Remount progress now publishes only remaining owned passengers when the set changes, preserving
the original deadline. Boarded or reassigned passengers cannot crowd the vehicle owner's bounded
boarding checks ahead of the remaining squad. Larger-squad physical boarding remains pending.

Queued additive twelve-passenger separate-squad cases for unrestricted and stationary transport,
with an explicit cargo-capacity prerequisite and distinct LARGE case IDs. Initial fixture seating
is setup only; every judged exit/remount still uses the real production path and physical seat
occupancy. Existing two-passenger/native/replacement comparisons are retained.

Successful danger-cover arrival no longer issues a return-to-leader order during lease expiry.
The actor retires its cover reservation at the useful physical position for native combat or
later assessment. Only a failed still-owned approach can request guarded formation recovery.
This removes an explicit backtracking command; native formation behaviour and physical outcomes
still require retest. No persistent hold or movement suppression is added.

WAIT diagnostics now display the last owner-local remount retirement reason, age and pending
actor/vehicle speed-distance-assignment evidence beside existing active ownership checks.
The view identifies locality and does not present stored intent or historical HC observations
as physical boarding completion. No recurring diagnostic scan was added.

Finite anti-armour relocation and static-support approach reservations now participate in the
engine danger committed-mover check. Repeated immediate danger retains a mobile weak posture
instead of forcing a reserved launcher relocation prone. Reservation expiry still returns the
actor to ordinary danger classification; physical movement-under-fire acceptance is pending.

Tracked reverse release now suppresses STOP/STOPTURNING when external ownership has taken over,
while retiring its exact old markers. A matching native command string alone cannot authorise
cleanup over a newer Zeus/player/specialist order. Physical reverse interruption remains queued.

The cheap compatibility object gate now checks seven supported specialist runtime markers,
allowing danger waiting to yield when one appears mid-response. The group form stays a declared
ownership read; config/faction classification remains outside this hot gate. Runtime marker
recognition is not full compatibility acceptance: activation/release/animation handovers and
ordinary group-member coexistence still need physical tests. Candidate aa23ee8 is separately
staged at runtime-20261009-201916-298 and predates this new change; no game was launched.

The cheap actor compatibility gate now matches the same specialist animation prefixes as the
full classifier, covering animation-only activation during a danger wait. It reads one actor's
animation without configuration or group scans. Static regression checks cover the bounded gate;
actual specialist activation/release and its performance cost still need packaged acceptance.

Authored BLUE audit now measures retained ROE, actual zero shots and absence of a manoeuvre
operation. A naturally sighted enemy entering CONTACT is awareness, not by itself permission to
fire or move. The prior case contradicted the adjacent hold-fire awareness contract. Original
failure evidence is retained; the corrected physical check has not run.

CARELESS release audit now reports engine-stimulus delivery and preserved state separately,
while retaining the original combined acceptance requirement. Empty submission evidence still
fails the exercised handover; it is distinguished from a mutated behaviour or retained response.
No missing-stimulus result is promoted to a behavioural pass. Physical retest remains pending.

Same-group casualty fixture now faces its observer toward the victim before the physical shot.
Native casualty danger requires observed death or body discovery; proximity alone is not that
prerequisite. Engine delivery and no-contact acceptance remain pending physical retest.

Cover discovery merges up to ten terrain objects and ten placed objects, ranks the combined
bounded set by distance, then performs geometry checks on at most ten. Previously terrain
insertion order could discard a closer placed wall. This changes candidate availability without
increasing the geometry budget; mixed placed/terrain physical acceptance remains pending.

Committed danger-cover movement now survives expiry of its short observation response, within
a distance-derived 4–12 second travel allowance. Previously an empty current threat payload
retired the approach after the roughly two-second reflex even before its movement timer ended.
Live gates, generation, native tasks and successor operations still invalidate it. This preserves
continuous intent without a new worker or repeated destination; physical arrival remains pending.

Cover lease retention now requires its exact actor marker, deadline and native expected
destination. An unmarked replacement doMove can end the old reservation immediately even
when its command name remains MOVE. Successful arrival and guarded cleanup retain their prior
semantics. New-order physical acceptance is still pending.

Group-hide release and retained leases now require the living local nonplayer actor to remain
in the original group and on foot, with no specialist runtime ownership. Transfers and boarding
retire the old proof rather than restoring a prior group posture into the new domain. Physical
transfer/boarding cleanup remains queued.

Added physical cover-destination arrival and subsequent ordinary native move cases to the
isolated danger fixture. They require captured production cover geometry and actual arrival,
not travel alone. The subsequent order checks post-release control; it does not replace the
separate active-interruption acceptance requirement. Both cases remain unrun.

Queued an independent active cover handover fixture: a genuine production lease is required
before an ordinary replacement doMove, then exact lease retirement and physical replacement
arrival are measured separately. No cover record or operation is injected. Missing cover
prerequisites fail the case. This supplements post-release movement and remains unrun.

Passenger stop acquisition and release now publish the saved/owned forced-speed pair. Previously
the old owner alone knew the pre-stop speed, so a new owner could retain a zero cap after request
expiry. Commands remain vehicle-owner local and restoration still requires exact current-speed
ownership. Actual stop/boarding HC migration remains queued for physical acceptance.

Vehicle withdrawal no longer consumes its contact-episode marker before route and operation
acceptance. Failed selection/ownership is reconsidered after an eight-second vehicle-locality
safe retry deadline. Smoke is requested on accepted withdrawal, not each rejected attempt.
Blocked-route recovery and later acceptance remain pending physical testing.

Group-hide generation retirement now uses the same nonplayer/on-foot/specialist ownership
checks as normal release. A newly boarded or activated specialist actor cannot receive prior
posture restoration through the separate generation-change branch. Physical combined handover
remains pending; staged cb648d7 predates this incremental repair.

Idle on-foot body/scream reactions now use a finite native glance toward the valid observation position. Committed movers and concrete native tasks do not receive it.
No target knowledge, fire authority, persistent watch or movement operation is created. This
adds alert observation depth but does not complete body assessment or danger parity; physical
observation/interruption acceptance remains pending.

Alert observation uses only the position form of the native glance command. The object form
fully reveals its target and is therefore excluded from WAIT observation. Native glance timing
and cleanup are not established by static checks and remain physical acceptance requirements.

Body/scream observation now has an independent default-on LIVE CBA gate under Contact. It
requires danger response and uses the authoritative shared settings specification, with no
separate runtime settings store. Disabled-state and native observation timing remain physical
acceptance requirements.

Danger cover now permits a separately gated visual-concealment fallback after solid cover fails.
The next shared callback performs the visual-only query; each callback retains the ten-object
geometry limit. Shared callers default to ballistic COVER mode. A failed concealment pass ends
that actor/generation search instead of cycling both searches. Decision evidence labels the
selected mode. Physical visual screening, disabled state and frame-time cost remain unproven.

Short valid cover moves are no longer rejected by a two-metre minimum. Negligible displacement
is recorded separately and cannot trigger concealment fallback. The physical travel check now
allows the same short approach; the separate committed-destination arrival case remains required.
Nearby-cover outcome and movement precision are unproven until the queued physical batch runs.

Danger cover searches now retire a failed solid-cover assessment when the visual fallback is disabled, rather than repeating geometry work on every callback. A new danger generation can reassess. This change requires physical disabled-state and renewed-danger checks; no game audit was launched.

Danger-cover retention and failed-approach recovery now require both native MOVE and PATH to remain enabled. Disabling either retires the lease without issuing return-to-formation movement. Physical external-disablement checks remain pending.

Group release now explicitly retires danger-cover leases through release-only mode. It cannot retain a still-valid cover lease or issue return-to-formation movement during handover. Physical lifecycle acceptance remains pending.

A failed solid-cover search now retains one four-second owner-local follow-up record, so brief danger expiry does not discard the visual-concealment assessment. The existing group callback consumes it once, with generation and ownership revalidation in the helper. Group release clears the record. Physical cadence and handover acceptance remain pending.

Danger cover now records one owner-local retirement observation with release/interruption/timeout/destination-proximity reason, generation, horizontal and vertical distance and destination. Diagnostics expose it without treating proximity as effective screening or replicated HC history. Physical acceptance remains pending.

The 4531829 danger batch reported a native rifle fixture with no projectile before the casualty-alert failure. That result does not establish an exercised casualty-response defect. Additive real-damage and native-observation prerequisite cases now expose this distinction for the next batch; the combined behavioural checks are retained unchanged. Current runtime remains on its original packaged source.

The running 4531829 cover fixture shows prior grenade-evasion displacement and no accepted cover destination. Inspection found a directional search blind spot: an eight-metre search around a seven-metre threat-away offset can exclude nearby side cover. Danger cover now searches the actor-centred existing eighteen-metre move envelope, retaining ten geometry candidates and explicit threat screening. This addresses the blind spot in code; it is not yet a physical fix confirmation.

The separated-observer audit allowed native formation to move its wingman during setup while leaving the wall at the spawn location. Live evidence shows the actor near the distant leader, outside that wall envelope. The next fixture places only its disposable wall relative to the actual pre-stimulus actor position and records range; it does not freeze/reset the actor. The group-hide exact-four requirement remains separate and unresolved.

Forced boarding acceptance now separately reports native GET IN establishment, danger handover/task preservation and physical boarding. The original combined requirement is unchanged. This exposes whether failure began before WAIT response, at ownership handling or at engine boarding; current live results remain unresolved.

The casualty rifle fixture now retries the documented native muzzle/mode call at most four times across its existing two-second projectile window. It stops upon actual projectile capture and logs attempts, canFire, FIREWEAPON and animation on failure. This addresses possible asynchronous firing readiness without fabricated damage; physical verification remains pending.

Regroup now permits a bounded grace (at most thirty seconds, no more than the configured base budget) when a route actor has recent measured progress, physical speed and its exact native destination. Stationary actors retain the original timeout, and the absolute ceiling still releases INCOMPLETE. No destination is reissued by this grace. Physical verification remains pending.

Carried-static retirement now preserves one owner-local evidence record: owner/epoch, episode, last phase/deadline, destination, actor positions/native commands/distances/backpacks/vehicles and command-free handover. The 4531829 batch failed before assembly and consequently had no weapon for firing/facing/packing checks; the first failing phase remains unresolved.

Carried deployment now captures the exact assistant bag before PutBag, then uses a finite DROPPING phase to observe native detachment before Assemble. Only the existing shared scheduler services it; the squad is not held. Missing/reassigned bags or drop timeout fail explicitly. Physical assembly/facing/fire/packing remain unproven.

The enabled vehicle-orientation audit now explicitly records natural target knowledge before evaluating operation ownership. Detection absence leaves that behavioural acceptance unproven; no reveal or synthetic danger is added. This responds to engine detection limitations without treating missing observations as successful controller behaviour.

Mixed-observer audit now samples exact commander/VEHICLE/ARMOURED/vehicle identity during its existing observation window. It no longer requires the latest group event to remain mounted after a legitimate foot-leader detection. All original mounted identity criteria are preserved; physical retest remains pending.

Crew recovery now retains one owner-local refusal observation with stage reason, danger cause/generation, vehicle speed, commander native command and native knowledge. No eligibility/ownership rule or seat-change behaviour is relaxed. This is diagnostic evidence, not recovery acceptance.

The live 4531829 batch passes stationary shared/separate physical remount but fails moving separate-group remount. The next audit emits the existing remount retirement reason plus vehicle speed/forced-speed/position/owner/stop request and passenger distance. This adds evidence without altering boarding or masking its failure.

WAIT-issued exits now publish a bounded sixty-second continuation proof before exit: original passenger pairs, operation generation and current waypoint identity/position. Only newly recorded owned exits publish it; native/unowned exits do not. Group release and calm/remount handover clear it. Vehicle stop consumption is still being implemented; this record alone does not fix remount or prove acceptance.

The continuation proof now refreshes the existing bounded stop request for nearby owned passengers. Vehicle validation requires the original passenger generation/waypoint and a captured crew generation/waypoint, no competing vehicle movement or external passenger owner, and an unexpired sixty-second episode. The first stop captures crew order proof; retirement clears it. Physical remount, order replacement, locality and performance remain unverified.

The new audit still consumed rifle ammunition without retaining a projectile. The fixture now handles the actual engine bullet inside FiredMan before scheduled delay and tracks real shot capture independently of projectile lifetime. No created bullet, scripted death, target reveal or WAIT danger injection is added. Physical casualty/body stimulus remains pending.

Targetless contact-suite grenades now come from an excluded same-side actor. The earlier hidden hostile firer could still produce legitimate native enemy attribution, contradicting no-contact acceptance. Real projectile/explosion delivery remains required; enemy-acquisition cases retain their separate hostile fixtures. Physical retest remains pending.

The observer-cover fixture now waits for a native idle command and reports MOVE/PATH readiness before the stimulus, without stopping/resetting the actor. Combined physical cover acceptance requires that prerequisite; native formation movement must not be misclassified as a WAIT cover failure. Retest remains pending.

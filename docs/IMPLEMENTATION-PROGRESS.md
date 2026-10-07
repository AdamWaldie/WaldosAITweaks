- Convoy coordination now runs under one registry-revision-owned convoy FSM with explicit CRUISE, SPACING, CONTACT_HOLD, RECOVERY, ORDERED_HOLD, OBSTRUCTION and ARRIVED states. The former indefinitely re-queued convoy worker is removed. Each travel phase submits one coalesced physical step to the shared scheduler; stable holds sleep and are replaced by the next ordered registry snapshot. Existing predecessor trails, size-aware gap damping, contact policy, route recovery, passenger generation ownership and meaningful-roadblock handling remain the physical controller. Zeus, external ownership, registry replacement and locality migration invalidate the brain before another vehicle command. Diagnostics expose phase, revisions, pending state, spacing corrections and recovery actors. Physical mixed-column acceptance remains pending.

# Standalone conversion progress

The [delivery goal](DELIVERY-GOAL.md) defines the required release outcome and the exact difference between implemented, statically checked and physically accepted work. This progress record does not promote a subsystem beyond its evidence.

## Implemented and statically checked

- Breaking WAIT function, setting, state and event namespace migration without forwarding aliases.
- CBA as required external infrastructure, with optional ZEN; WAIT supplies the base-soldier engine danger FSM.
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
- Audit observer launch explicitly selects its resolution config and 3840x2160 command-line dimensions. Curator assignment is corrected; fresh VR entry and observer Zeus use were visibly verified. Reassignment after respawn is implemented and remains a separate pending physical check.

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

- Packaged runtime `20261007-152049` exposed a command-boundary type failure in the shared external-ownership predicate: its first player-membership condition was wrapped as SQF code and then combined with Boolean `||`. Every ownership check therefore errored and rejected the first DEFEND order, invalidating the remainder of that batch. The predicate now begins with a Boolean expression and an explicit regression contract protects its shape. The packaged audit also executes the predicate as a command-boundary preflight and aborts before creating behavioural fixtures when any prerequisite fails, preventing a shared fault from becoming hundreds of misleading timeouts. Static validation passes; the failed runtime remains evidence and a rebuilt batch is required.
- Registered convoy travel now creates one owner-local `CONVOY` operation per revision. The operation records progress at the shared bounded cadence, completes only on an accepted arrival hold, and cancels on Zeus, player control, external ownership, mobility failure or a replacement route revision. The predecessor-trail, spacing and physical-roadblock controller remains unchanged. Static validation passes; mixed-column interruption, locality and obstruction acceptance remains pending.
- Support reservations now create a matching `SUPPORT_RALLY` or `COORDINATED_ASSAULT` operation on the accepting group owner. The existing reservation token remains the authoritative cross-owner record; its operation generation only tracks progress and makes lease expiry, feature closure, Zeus, external ownership and server retirement cancel the same finite assignment. Naval delivery now tracks boat-crew `NAVAL_ASSAULT` and passenger `NAVAL_LANDING` operations separately, preserving the existing public landing token and never allowing a passenger handover to replace crew movement. Static validation passes; physical support, landing, interruption and HC migration acceptance remain pending.
- Danger assessment now stops at admission, observer setup and FSM interruption when a curator, player, compatible specialist controller or other external owner holds the group. It clears only WAIT-owned response state and never wakes the group decision job after that handover. Static and package validation pass; live specialist and Zeus handover acceptance remains pending.
- The engine danger FSM now owns a finite per-soldier weak-stance lease. It retains the actor's original authored stance across coalesced danger events, restores only WAIT's exact applied value on exit, and discards the lease without writing when the engine, Zeus or a specialist controller has changed stance or ownership. Hit, explosion and suppression may additionally request one nearby physical-cover move for one genuinely idle actor through the existing group tick. Casualty and scream events remain mobile alerts, and an operation, native command or newer owner blocks the move.
- Targetless danger no longer leaves a group in a thirty-second artificial CONTACT state. The group returns to its prior behavior as soon as the finite danger lease ends, while native enemy knowledge acquired during that lease promotes the state into the ordinary occlusion and post-contact flow.
- Base soldier classes now load a bounded WAIT danger FSM. It consumes engine cause/position/expiry/source queues, separates reflex-only friendly hazards from group combat observations, requires a live hostile source for engage states, and wakes the existing finite group assessment without adding movement ownership. Static/package validation and physical handover acceptance remain pending.
- The configured WAIT danger FSM remains the base-soldier engine slot for the running addon, but its runtime, danger-feature and pause gates now exit without issuing WAIT stance, movement, target or planning commands. This keeps CBA disablement truthful without requiring a config restart; another addon replacing the same engine slot remains unsupported.
- Engine-confirmed contact handoff now uses the observing actor's native believed target position. It no longer substitutes the observer's own position, which could collapse the threat geometry onto the squad and produce lateral, reversing or zero-length routes. A danger-only CONTACT transition also has an explicit fallback position and no longer selects an empty visible-contact array. Static and package validation pass; fresh physical route acceptance remains pending.
- Danger-only CONTACT now separates immediate safety from target-dependent planning. Morale, finite posture, cover stance and vehicle stop restoration remain responsive, while anti-armour, artillery, reinforcement, coordinated assault, flank, advance and post-contact search wait for native target knowledge. A hazard-only engagement returns directly to calm after its finite lost-contact interval and clears its per-engagement knowledge marker. Approximate danger geometry therefore cannot consume tactical cooldowns or dispatch units toward an unidentified hazard. Static and package validation pass; physical transition acceptance remains pending.
- A targetless hit, explosion or suppression now creates one bounded passenger-safety lease for mounted groups. It reuses the exact safe-stop and cargo-exit handshake before the vehicle layer's no-enemy return, including a bounded approximate report from the local crew owner to separate allied passenger groups. The lease cannot select a target, publish target knowledge, withdraw the vehicle or issue a route. Cleanup retracts the report and restores only WAIT's exact zero-speed cap. The queued vehicle audit now starts an enemy-free moving truck, delivers a real grenade explosion through the engine FSM and requires physical cargo exit, operating-crew retention and no invented combat. It also corrects an always-true seat predicate in the older contact audit. Live acceptance, Zeus replacement and migration variants remain pending.
- Shared operation cleanup now records whether the operation began on foot. Only those operations release a WAIT danger-posture lease; aircraft, vehicle and naval operations retain their native combat state while still receiving the same generation, cancellation and diagnostic lifecycle. Static validation passes; mixed-operation handover acceptance remains pending.
- Shared operation progress now retains each actor's last meaningful position until that actor crosses the configured distance. Slow continuous travel therefore accumulates instead of being erased at every scheduler callback and misclassified as a stall. Static validation passes; packaged physical acceptance remains pending.
- Shared recovery progress is now actor-scoped. A quarantined actor can renew only its own observation window and cannot conceal a stationary manoeuvre element. Tactical drills consume the shared STALLED outcome at the configured bound timeout; support releases a stalled reservation as NO_PROGRESS; withdrawal re-reads the operation after quarantine and advances to another eligible straggler instead of retrying the same exhausted actor. Static validation passes; physical blocked-actor, support-stall and withdrawal-casualty acceptance remain pending.
- Ground tactics, building progression, convoy control, aircraft attacks and cross-squad support now recheck Zeus and external ownership while their shared-scheduler callback is pending. These FSMs no longer retain control until the three-second watchdog. Ground/building/convoy controllers use their existing owned-state release; aircraft first removes its exact temporary waypoint and flight lease through the normal attack cleanup; support first retracts exact responder reservations. Artillery retains its separate uncertain-shot quarantine after an accepted native fire command, but issues no later shot or movement command after eligibility is lost. Static validation passes; packaged interruption acceptance remains pending.
- Building and convoy callbacks now propagate terminal shared-operation results to the outer function scope before any later room, formation, speed or recovery mutation. A replaced combined-ground generation can no longer clear the replacement generation's movement or alternative-backend lease. These fixes close nested SQF `exitWith` paths that released ownership but then continued executing the old callback. Static and package validation pass; physical Zeus, replacement and locality interruption acceptance remains pending.
- Medical assistance now uses an explicit finite physical approach followed by Arma's native `HealSoldier` action at treatment range, including immediate treatment when already close enough. The previous unrecognised `doHeal` form blocked PBO compilation. Every movement and treatment write now rechecks Zeus and specialist ownership. A live danger response cancels aid before the same group tick continues into combat assessment, preventing treatment from delaying a hit or suppression reaction. Support lease and feature-expiry exits were also corrected to top-level finite-operation exits. Seven PBOs now compile and seal; physical treatment, danger interruption and support-release acceptance remain pending.
- Building clearance now forms bounded lead/security pairs rather than giving the first available room to one single-worker lane. The security partner remains at a real entry until the lead crosses it, follows into the first room, and trails successive rooms; buildings with no usable entry positions still receive a physical paired first-room attempt. Static and package validation pass; multi-model, casualty and traversal acceptance remains pending.
- Room-progress leases now follow the assigned room mover after entry. Security partners may still adjust cover and trail the preceding room, but their movement can no longer conceal a doorway-stalled lead or postpone actor recovery indefinitely. Physical multi-model acceptance remains pending.
- CQB progression, support coordination and the central infantry tick now test dismounted eligibility directly through `objectParent`; the same bounded check covers stance, anti-armour selection, flank casualty replacement and ammunition sharing. This removes repeated vehicle resolution from recurring actor filters without adding caches, jobs or state, while preserving the rule that mounted crew cannot become room clearers, infantry bounders or on-foot tactical replacements. Static validation passes; physical infantry, CQB and support acceptance remains pending.

## Assault handoff responsiveness

A valid flank/advance assault transition now commits the covered approach and issues it in the same owner-local scheduler step. At physical assault-position arrival, an element without a queued frag starts its clear-through in that step. Existing feature gates, casualty replacement, ownership checks, cover selection and configured ordinary bound pauses remain in force. No new loop, scan or setting is added.

Grenade dispatch now occurs asynchronously beside the clear-through operation: the throw helper retains its own safety cancellation, while the moving element receives its next bound in the same owner-local step. Do not treat the static transition contracts as evidence of live assault effectiveness. The next combat batch must check single-squad and coordinated approach/clear-through, cancelled grenade requests, live projectiles, casualty replacement, Zeus interruption and cleanup.

The first standalone combat batch exposed an audit prerequisite defect: camera travel left the human observer over 6 km from fixtures, outside the real tactical participation range. Audit phase changes now place only the protected on-foot observer 150 m from the named fixture on the observer's owner. Production range settings and fixture AI positions are unchanged. The running fe7c39d batch retains its results; this audit repair requires a fresh staged run.

- Building clearance now runs under one generation-owned `buildingOperation.fsm` with explicit `ENTRY`, `SWEEP`, `REPLAN` and `EGRESS` states. The FSM itself remains cheap and non-suspending: each state submits one coalesced physical-progress step to the shared scheduler, while native pathfinding, target engagement and suppression remain active. Room visits, retry evidence, casualty replacement and actor-scoped recovery retain their existing physical authority. Zeus, external ownership, shutdown, replacement and locality changes invalidate the generation before further movement writes. Diagnostics expose phase, generation, owner epoch, queue state, progress age and room counts. All static, FSM and package gates pass; multi-model physical clearance and interruption acceptance remains pending.
- Aircraft attacks now run under one owner-local `airAttackOperation.fsm` with explicit `PLAN`, `INGRESS`, `ATTACK` and `EGRESS` phases. The FSM owns persistence and queues one coalesced step at the attack controller's requested cadence; the existing bounded implementation still validates live ammunition, terrain, target knowledge and control before native flight or weapon commands. Discovery and combined-arms opportunities can no longer create a self-rescheduling aircraft job outside the operation brain. Static and package validation are required before this is promoted; physical weapon, terrain, interruption and locality acceptance remains pending.
- Aircraft movement mutation now has one owner-local priority lease shared by landing, missile defence, attack and optional braking. A lease is bound to controller, generation token and locality owner; stale cleanup cannot clear a newer controller. Committed landing has priority over defensive velocity breaks, defensive separation over attack, and attack over cruise braking. Incoming-missile countermeasures still fire during landing, but cannot inject a competing velocity correction near terrain. Every mutation boundary rechecks player, Zeus, specialist and locality ownership. Static validation is required; live pre-emption and handover acceptance remains pending.
- Artillery and counter-battery missions now persist through one server-owned `artilleryMission.fsm` with `REQUESTED`, `WARNING`, `FIRING` and `RELOCATING` phases. Each state submits one coalesced bounded mission step through the shared scheduler. Existing owner-local observation, safe aim, physical shot confirmation, first-lethal-burst red warning smoke, uncertain-shot quarantine and shoot-and-scoot group handoff remain authoritative. Stop or replacement cancels the exact mission generation before another command can be issued. Static and package validation are required; physical fire, warning timing, interruption, relocation and headless-owner acceptance remain pending.
- Cross-squad reinforcement and coordinated-assault requests now persist through one server-owned `supportRequest.fsm` with `DISCOVER`, `RESERVE` and `COORDINATE` phases. It replaces the self-rescheduling server callback while retaining the bounded nearby candidate set, separated rally areas, immediate contact-to-avenue handoff, current-owner acknowledgement and expiring responder roles. The FSM never moves a responder itself; each current group owner continues to reject Zeus, player, specialist or newer-order conflicts before issuing a local command. Static and package validation are required; live multi-owner, casualty, no-responder and interruption acceptance remains pending.
## Danger framework foundation

The persistent ground decision owner is now `groupTactics.fsm`, with semantic CALM, INVESTIGATE, CONTACT, SUPPORT, MANOEUVRE, ASSAULT, CLEAR, SECURITY, SEARCH, REGROUP and WITHDRAW states. Each state queues one bounded decision through the shared scheduler; scripted FSM state bodies do not perform geometry scans or wait on animations. The older group tick remains a bounded implementation callback during phase-by-phase extraction, rather than a second persistent worker.

Its scheduler wait now has a bounded three-second watchdog. A delayed or lost due callback wakes the same
generation-keyed queue entry rather than appending work, and a cancelled callback exits before invoking legacy
group logic. Owner epoch, generation, addon-disable and explicit cancellation can therefore end the wait even
when the scheduler is under load. Diagnostics expose the watchdog count so queue pressure is visible instead of
appearing as an unexplained idle squad.

The same bounded wait contract now covers building, convoy, aircraft-attack, artillery and support-request
FSMs. Each queued step records its submission time; a three-second overdue wait wakes the same coalescing key,
and a cancelled or finished callback exits before physical implementation logic. Controller diagnostics include
their recovery counts. This removes an identical indefinite-wait path from six production brains without adding
a worker, scan or per-unit loop. Static and packaged validation are required; physical queue-pressure acceptance
remains pending.

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

Forced-command and mounted checks now repeat at the queued group-assessment boundary. This closes a delayed race
where the immediate FSM yielded correctly but the later cause-only classification still changed group behaviour or
ROE. On-foot hide/engage responses raise BLUE or GREEN groups to a finite YELLOW response, while native ATTACK,
boarding, action, healing, rearm, join, fleeing and vehicle owners remain observation-only.

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

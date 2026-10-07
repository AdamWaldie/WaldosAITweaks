# Standalone conversion progress

The [delivery goal](DELIVERY-GOAL.md) defines the required release outcome and the exact difference between implemented, statically checked and physically accepted work. This progress record does not promote a subsystem beyond its evidence.

## Implemented and statically checked

- Breaking WAIT function, setting, state and event namespace migration without forwarding aliases.
- CBA as required external infrastructure, with optional ZEN; native danger stays active.
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
- WAIT-only infantry ownership discovery now reads the registered WAIT enum instead of an obsolete value. This repairs a path where discovery left the external danger controller active while finite leases assumed it had been disabled. Exact baseline restoration and shared ownership remain; dependency-loaded physical acceptance is pending.

- A finite local danger response now promotes only its existing squad decision job to contact cadence. This lets a distant group use its native engine knowledge without waiting for the normal player-distance interval, while retaining the shared scheduler, route owner and performance bounds. Physical response latency and 50 mixed-group acceptance remain pending.
- Incoming-missile defence now uses the same finite shared scheduler as the rest of WAIT. A newer warning invalidates the earlier generation, and each response emits bounded countermeasures with at most two terrain-checked flight impulses. This removes the independent sleeping worker; real missile evasion and flight-quality acceptance remain pending packaged testing.

- Convoy lead-road and follower-trail grade sampling now uses absolute elevation. Terrain-relative heights previously hid hills from the safety cap. Query bounds and cadence are unchanged; sloped-route physical acceptance remains pending.

- General driving assistance is active as a separate next-operation feature. It samples only three forward terrain points every four seconds, converts its documented km/h policy caps to the engine's m/s command units, and restores only the exact cap it owns. A takeover during sampling releases the unissued lease instead of retaining stale state. A stalled ordinary route can receive one refresh, one clear-rear reverse and one final retry outside combat; it never rewrites waypoints, bypasses obstacles or changes collision. Physical stop, recovery and mixed-traffic acceptance remain pending.
- Convoy speed ownership is now vehicle-scoped. Each applied travel or halt cap records its group, revision and engine-unit value; release restores a pre-convoy speed only when that exact cap remains current, the vehicle is actually leaving convoy control and no group, crew or driving controller has taken over. This prevents configuration refreshes and Zeus/external handovers from producing a restore/reapply pulse or reviving an obsolete speed command. Physical handover and stop/resume acceptance remain pending.
- Passenger contact dismounts now use the same exact speed-lease rule. The vehicle authority records both the pre-stop cap and WAIT's owned zero cap; request expiry, group release and master shutdown restore the baseline only if zero is still current. A Zeus, mission or specialist speed change therefore survives cleanup instead of being replaced by the stale pre-dismount value. Physical moving-contact and interruption acceptance remain pending.
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

- Registered convoy travel now creates one owner-local `CONVOY` operation per revision. The operation records progress at the shared bounded cadence, completes only on an accepted arrival hold, and cancels on Zeus, player control, external ownership, mobility failure or a replacement route revision. The predecessor-trail, spacing and physical-roadblock controller remains unchanged. Static validation passes; mixed-column interruption, locality and obstruction acceptance remains pending.
- Support reservations now create a matching `SUPPORT_RALLY` or `COORDINATED_ASSAULT` operation on the accepting group owner. The existing reservation token remains the authoritative cross-owner record; its operation generation only tracks progress and makes lease expiry, feature closure, Zeus, external ownership and server retirement cancel the same finite assignment. Naval delivery now tracks boat-crew `NAVAL_ASSAULT` and passenger `NAVAL_LANDING` operations separately, preserving the existing public landing token and never allowing a passenger handover to replace crew movement. Static validation passes; physical support, landing, interruption and HC migration acceptance remain pending.
- Danger assessment now stops at admission, observer setup and FSM interruption when a curator, player, compatible specialist controller or other external owner holds the group. It clears only WAIT-owned response state and never wakes the group decision job after that handover. Static and package validation pass; live specialist and Zeus handover acceptance remains pending.
- Shared operation cleanup now records whether the operation began on foot. Only those operations release a WAIT danger-posture lease; aircraft, vehicle and naval operations retain their native combat state while still receiving the same generation, cancellation and diagnostic lifecycle. Static validation passes; mixed-operation handover acceptance remains pending.
- Building clearance now forms bounded lead/security pairs rather than giving the first available room to one single-worker lane. The security partner remains at a real entry until the lead crosses it, follows into the first room, and trails successive rooms; buildings with no usable entry positions still receive a physical paired first-room attempt. Static and package validation pass; multi-model, casualty and traversal acceptance remains pending.

## Assault handoff responsiveness

A valid flank/advance assault transition now commits the covered approach and issues it in the same owner-local scheduler step. At physical assault-position arrival, an element without a queued frag starts its clear-through in that step. Existing feature gates, casualty replacement, ownership checks, cover selection and configured ordinary bound pauses remain in force. No new loop, scan or setting is added.

Grenade dispatch now occurs asynchronously beside the clear-through operation: the throw helper retains its own safety cancellation, while the moving element receives its next bound in the same owner-local step. Do not treat the static transition contracts as evidence of live assault effectiveness. The next combat batch must check single-squad and coordinated approach/clear-through, cancelled grenade requests, live projectiles, casualty replacement, Zeus interruption and cleanup.

The first standalone combat batch exposed an audit prerequisite defect: camera travel left the human observer over 6 km from fixtures, outside the real tactical participation range. Audit phase changes now place only the protected on-foot observer 150 m from the named fixture on the observer's owner. Production range settings and fixture AI positions are unchanged. The running fe7c39d batch retains its results; this audit repair requires a fresh staged run.

## Danger framework foundation

Up to twelve owner-local AI group members now feed one finite owner-local assessment FSM, enabled by
default under the normal CBA contact settings. The evaluator coalesces causes, rejects expired records and
selects urgency without sorting. Its one group-level contact event accepts only engine-confirmed hostile knowledge
already held by the leader and passes the observer position, never a target identity or position. Event callbacks do
no squad/world scans; repeated causes are throttled before dispatch. The FSM publishes one short-lived, generation-scoped response context and wakes the
existing group decision job inside the shared budget. It never reveals a shooter, replaces a committed route
or creates a second movement owner. The context survives observer membership churn, preserves a stronger
live cause over weaker later events, expires cleanly, and is cleared before Zeus or external takeover can
consume it. Static/package validation is separate from the still-pending physical reaction, transition and
performance acceptance.

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

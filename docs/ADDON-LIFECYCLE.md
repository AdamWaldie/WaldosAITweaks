# Addon lifecycle and feature integration

WAIT is an addon, not a mission script bootstrap. Loading the mod registers its functions,
settings and runtime entry points. Missions do not copy its files or execute an initialization script.

## Startup and authority

CBA pre-init loads guarded defaults and registers the shared tuning specification on every machine.
CBA owns global setting persistence and synchronization. Post-init starts enabled systems after addon
initialization. The server coordinates cross-group decisions; the current AI owner executes movement,
fire and local handlers. Interface clients provide Zeus controls and interruption monitoring.

Retained function and setting names are compatibility identifiers. Changing display text must not
rename them or invalidate mission overrides. Native engine danger remains active; WAIT adds finite operations rather than a second permanent
movement controller. An original danger replacement must pass acceptance before it is enabled.

## Existing improvements remain in scope

| Subsystem | Existing implementation retained | Runtime mechanism |
| --- | --- | --- |
| Skills and visibility | Profiles, ambient light, equipment heuristics, operator/cargo distinction and dispersion | Local creation/locality events plus bounded refresh |
| Infantry | Contact, cover, fire control, advance, flank, assault, withdrawal, morale, surrender and recovery | Shared budgeted scheduler, finite drill FSM and sparse danger events |
| Buildings | Garrison, clearance, casualty replacement and task handover | Owner-local building tasks with ownership checks; traversal remains subject to live acceptance |
| Coordination | Contact communication, support by fire, multi-squad and combined-arms responder roles | Server decisions and expiring owner-local operations |
| Vehicles | Convoy, passengers, gunnery, obstruction and non-teleport recovery | Native commands with bounded progress jobs and seat ownership |
| Aircraft | Weapon-aware attack choices, defence, countermeasures, landing and braking | Finite owner-local jobs, missile events and terrain checks |
| Support and reactions | Artillery warning/support, airborne/naval operations and civilian reactions | Event-driven requests and finite scheduled responses |
| Operator controls | Per-feature gates, diagnostics, Zeus replacement and script API | Shared setting specification and explicit ownership |

Retention is not acceptance: building traversal, aircraft geometry, coordinated movement and measured
performance still need fresh batched game tests. The feature coverage manifest records outstanding cases.

## Runtime changes

CBA callbacks defer work until addon post-init. Skill/profile changes reconfigure the existing local
skill worker. Master disable releases WAIT-owned operations; it does not erase externally owned state.
Grenade-evasion and civilian-reaction switches immediately reconcile their optional handlers through
the repeat-safe installer. Turning them back on must work without restarting the mission. Other
behaviour gates are read by their finite jobs and eligibility checks; this does not justify installing
another worker for each setting.

A newer Zeus or mission order invalidates the current operation. Cleanup restores only state still
owned by that operation. Locality migration retires stale work and lets the new owner adopt eligible AI.
No tactical job waits indefinitely for a grenade animation, a casualty, or every straggler to arrive.

## Choosing addon mechanisms

The shared tuning specification carries each option's activation policy into CBA help and the
generated settings reference. Live controls follow their callback or next owner-local update.
Next-operation controls are guaranteed when new intent starts; active work keeps committed geometry
and may adopt safety values earlier. No runtime control currently requires a restart. Optional engine
policies will require package selection and restart rather than a reversible checkbox.

The script tuning API validates input and changes CBA's server layer. It does not send a second
settings snapshot or install duplicate workers. CBA handles effective-value synchronization and JIP;
the published revision counter is diagnostic only. Settings changes are not a multi-key atomic
transaction. Physical server-enforcement and JIP acceptance remain pending.

Use config for declarations and dependencies, CBA settings for reversible configuration, events for
sparse stimuli, finite FSMs for transitions, and the existing scheduler for bounded due work. A config
change that cannot be undone at runtime must never be presented as a reversible setting. Do not put
terrain queries, global scans or movement reissue loops in unconditional FSM transitions.

Core, infantry, vehicles, aircraft, support and compatibility are separate mandatory PBOs. The
bootstrap registers the function catalogue and starts enabled owner-local systems after its component
dependencies load. Components do not add schedulers. Engine-policy PBOs remain a separate pending
implementation and must not be advertised as available until packaged and validated.

## Validation

The sequential build checks source, config, settings parity, documentation, performance contracts,
FSM validity and packaging. Game validation uses the packaged addon and dedicated-server/client audit.
Next batched acceptance includes disable/re-enable of optional handlers, JIP and headless migration,
Zeus replacement during manoeuvres, active external ownership, and the feature behaviour matrix.
Measured performance compares the same 50 mixed groups against baseline AI: at most 5 percent added
median frame time and 10 percent added p95 frame time. Static checks cannot establish that budget.

Owner-local startup waits for CBA's settings-initialized event after post-init refresh.
Guarded pre-init defaults do not establish effective settings readiness. Direct server start/stop
requests use the CBA server layer; callbacks perform local setup and cleanup.

## Shared queue ownership

Tactics and skill adjustment share one owner-local callback and the configured soft budget.
Skill refresh examines at most ten registered units per second, writes only changed layers and
continues when tactics are disabled or paused. Tactical job delays retain low-FPS backoff;
the bounded skill refresh does not inherit that backoff. Stopping either runtime retires its jobs
without disabling the other. Stopping the last runtime removes the callback. Skill stop advances
its generation so stale jobs cannot revive after a quick restart. No job is replayed across owners;
locality adoption registers the new owner's units.

The scheduler audit checks actual skill refresh with tactics disabled and physical queued movement
with skills disabled, then callback removal when both stop. The c0e9009 packaged scheduler batch
completed server and client acceptance with 267 passing checks and no reported SQF errors.
This validates that focused batch, not combat tactics or frame-time overhead. The shared budget
is soft and cannot pre-empt an executing SQF function; 50 mixed-group
median/p95 frame-time acceptance remains required.

## Finite FSM interruption

Active manoeuvre FSMs check cached Zeus-order markers and addon activation before their scheduled step is due. A newer Zeus marker releases the matching operation immediately and cancels its queued callback. Cleanup checks the group owner, epoch and drill token, so a stale FSM cannot release a newer manoeuvre. Zeus cleanup restores owned overrides without issuing formation-return or replacement movement. Shutdown also releases the matching drill. No geometry or group scan runs in FSM conditions.

This is an interruption improvement to the finite manoeuvre FSM, not a replacement danger brain. Native danger behaviour remains active. WAIT's event-driven danger assessment and finite response handoff are implemented; physical reaction, transition and 50 mixed-group performance acceptance remain outstanding. Live acceptance must cover Zeus replacement while the tactical scheduler is delayed, disable/re-enable, replaced tokens, ownership migration and preservation of specialist animation control.

## Danger assessment

`WAIT_AIPass_Danger_Enable` is a server-enforced, live CBA option under Infantry / Contact, default true.
It installs Hit, Suppressed and FiredNear observers on up to twelve eligible local AI group members,
prioritising the leader, plus one owner-local EnemyDetected observer for engine-confirmed hostile contact. The
contact observer accepts only information already known to the current group leader, records the observer position
rather than the target identity or position, and is removed on loss of ownership or shutdown. Membership changes reinstall
observers without cancelling the group's active finite response.
Four cause classes are coalesced in a queue capped at sixteen records. Events expire after two seconds;
Repeated callbacks of the same cause are throttled to 0.25 seconds before any squad eligibility scan;
assessment selects the highest urgency without sorting and breaks equal-priority ties by observation time.
Gunfire records the observer position rather than an unseen attacker. The queue never supplies a target
identity, reveal or firing command.

One finite assessment FSM per affected group runs while observations or its short response lease remain.
It wakes that group's existing scheduler job, at most twice per second, using a local deadline on the same
job state. The response context records cause, approximate observer position, expiry and generation; it is
not target knowledge or a movement request. Stronger causes remain in force over weaker later callbacks.
While the finite response is live, its already-scheduled group decision receives the contact cadence even
outside normal player-distance range. It still reads only native engine knowledge, and does not add a worker,
scan or route owner. The existing job is also exempt from the low-FPS cadence backoff for that response lease;
optional work remains backoff-limited. Expensive knowledge, geometry and tactical decisions retain the shared scheduler budget and normal
participation gates. Native danger behaviour remains installed: this is not an engine danger-FSM replacement
or proof that reaction and CQB behaviours work.

Owner epochs and FSM generations prevent old callbacks from acting after transfer or restart. Zeus
hold-token changes and replacement waypoints terminate the FSM and clear the response before another
controller can consume it. Interruption explicitly releases only the temporary behaviour and combat-mode
values that the response lease still owns, so a Zeus order, feature disable, pause or locality handover
cannot leave a stale COMBAT/ROE posture behind. Eligibility checks preserve external animation/combat
ownership. The new owner starts from observations received locally. Queued acceptance
covers priority/expiry, sustained fire, no knowledge leakage, disabled state, leader casualties, Zeus,
external ownership, locality transfer, physical reaction and 50 mixed-group frame-time comparison.

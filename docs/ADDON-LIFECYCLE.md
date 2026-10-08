# Addon lifecycle and feature integration

WAIT is an addon, not a mission script bootstrap. Loading the mod registers its functions,
settings and runtime entry points. Missions do not copy its files or execute an initialization script.

## Startup and authority

CBA pre-init loads guarded defaults and registers the shared tuning specification on every machine.
CBA owns global setting persistence and synchronization. Post-init starts enabled systems after addon
initialization. The server coordinates cross-group decisions; the current AI owner executes movement,
fire and local handlers. Interface clients provide Zeus controls and interruption monitoring.

Retained function and setting names are compatibility identifiers. Changing display text must not
rename them or invalidate mission overrides. WAIT owns the base-soldier engine danger slot and provides
the complete danger-response path while loaded. Another addon replacing the same engine slot is incompatible;
specialist actor ownership still yields through explicit finite compatibility markers.
Each server or headless owner verifies the final configured west, east and independent base-soldier
paths before starting infantry tactics. A mismatch fails that tactical runtime closed and reports the
three resolved paths, preventing WAIT group operations from competing with a foreign danger brain.
Repeated engine observations are coalesced by expiry, so an older queued duplicate cannot replace the
current cause geometry. Hostile identity is retained on its own freshness track and must remain alive,
hostile and natively known before use. Immediate soldier danger posture is also generation-bounded: the engine danger FSM records the prior
scripted stance, applies one short scripted stance, and restores it only while that exact observable value remains owned by WAIT.
Any newer engine, Zeus or specialist stance wins and invalidates the lease without restoration.

## Existing improvements remain in scope

| Subsystem | Existing implementation retained | Runtime mechanism |
| --- | --- | --- |
| Skills and visibility | Profiles, ambient light, equipment heuristics, operator/cargo distinction and dispersion | Local creation/locality events plus bounded refresh |
| Infantry | Contact, cover, fire control, advance, flank, assault, withdrawal, morale, surrender and recovery | Engine danger intake, shared budgeted scheduler and finite group-operation FSMs |
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

Event-driven jobs that represent a single owner and response may supply a stable, owner-local job
key. A repeated observation then refreshes that callback's state and wake time rather than adding a
second callback that will become stale later. Keying is opt-in: separate groups, projectiles,
artillery missions and ordinary operations remain independent queue entries.

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

Active operation FSMs check cached Zeus-order markers and external ownership before a delayed step is due and while a shared-scheduler callback is pending. A newer owner therefore releases ground tactics, building progression, convoy control, aircraft attack and support reservations without waiting for the watchdog. Cleanup checks the current generation and exact owned token: ground controllers restore only matching overrides, aircraft removes its named temporary waypoint before releasing its flight lease, and support retracts only matching responder reservations. A stale FSM cannot release a newer operation or issue formation-return movement. No geometry or world scan runs in these FSM conditions.

An artillery order already accepted by the engine is treated separately. WAIT stops issuing new fire or relocation commands when eligibility changes, but retains the bounded uncertain-shot record until the engine confirms the shot or its quarantine expires. This bookkeeping does not own movement or block a newer Zeus order; it prevents an unconfirmed shot from being retried.

Every scheduler-backed operation FSM has a fifteen-second starvation watchdog while a due callback is pending.
This covers group tactics, building progression, convoy control, aircraft attacks, artillery and support requests.
The watchdog is disabled during SafeStart or ENDEX and remains suppressed through the scheduler's resume grace,
so a deliberate pause or ordinary budget latency cannot create repeated recovery churn. A genuine overdue wait
clears only its local pending flag and wakes the same generation-keyed scheduler entry, so it cannot create a
second brain or grow a parallel queue. Cancellation, disablement, ownership and generation changes end the wait
before a stale callback can act. The callback repeats those checks before implementation logic. Diagnostics expose
watchdog activations per controller; any recurring count is a performance or queue-health finding rather than proof
of successful behaviour.

Tactical drills use a separate fifteen-second same-key recovery before the existing thirty-second
movement-lease cleanup. A missing recurring callback is therefore retried once through the FSM while
persistent callback failure still releases owned PATH, behaviour and ROE state through common cleanup.

Actor recovery is isolated from operation progress. Once an actor receives its one recovery route, only
the remaining manoeuvre element can renew the operation-wide progress clock. Physical travel by the
isolated actor renews its own bounded observation window, arrival rejoins it, and no progress marks only
that actor unavailable. A stalled main element produces an explicit terminal result; support reservations
release as NO_PROGRESS, and withdrawal selects another eligible straggler instead of retrying the same
exhausted actor. These checks do not add a per-unit worker or recurring scan.

The engine danger FSM is a finite response and interruption layer, not a second manoeuvre brain. It separates local physical reflexes from group combat planning: known-friendly near fire may change a finite scripted stance briefly, but cannot create CONTACT, while engage causes require a live hostile source. Casualty and scream causes are local alert/hide evidence only; actual losses still reach morale and role replacement, but the danger record cannot change group behaviour or ROE or invent an attacker. Explicit BLUE/GREEN fire discipline remains authoritative: real-contact awareness and defensive posture remain available, and an idle authored STEALTH element may take one weak finite low-profile stance without receiving a movement or target command. WAIT fire control, artillery, reinforcement, combined-arms requests, coordinated assault, flank and advance remain blocked. Direct commander stance orders retain higher engine priority, and a newer scripted stance invalidates WAIT's exact lease. New native causes accumulate through the current response and are reconsidered early only when the bounded queue exceeds three records. At group handoff, one strongest event is consumed per finite step and other still-live causes remain queued; an immediate hit therefore cannot erase a simultaneous confirmed contact. The surviving higher-priority physical-response lease still cannot be shortened by those later weaker causes, and native-order interruption remains bound to that surviving lease's actor rather than whichever weaker record was assessed last. Coalesced events retain the actor that received the current response separately from the actor whose native knowledge supports an inherited hostile identity. This prevents an arbitrary group anchor from turning a mixed mounted/foot event into the wrong response domain while still requiring a living local witness for target identity. At the response deadline, a close living hostile may add at most two short follow-up records and an effective vehicle commander may add at most three; every follow-up repeats ownership and interruption checks. Reaching that fixed budget ends the immediate actor chain and hands continuing combat back to native AI and the persistent group brain even while target knowledge remains valid. An engine-confirmed hostile identity is retained only when already known and is checked again against current group knowledge before a mounted response may enter vehicle combat; targetless vehicle danger remains safety-only. Other vehicle crew finish instead of multiplying the response. The waiting state otherwise checks only cheap live gates and explicit ownership markers, so runtime disable, pause, direct curator control, new Zeus orders and declared external ownership terminate the response without a squad scan or delayed command. WAIT's cause assessment, finite persistence handoff and one bounded idle-actor cover move are implemented; physical transition, interruption and 50 mixed-group performance acceptance remain outstanding. Queued acceptance covers known-contact hold-fire, mounted combat, mixed-domain observation, active Zeus replacement and leader-loss continuity; ownership migration and specialist animation preservation remain open.

The group assessment FSM likewise keeps its per-evaluation wait condition to locality, generation,
runtime and Zeus-token comparisons. Full player and specialist ownership checks occur in the bounded
250 ms assessment step, avoiding a per-frame scan of every member in every reacting group. Cause
priority is consistent across the engine and group layers: casualty evidence outranks a scream, while
direct harm, explosion and suppression retain priority over both.

An unidentified hit, explosion or suppression event may wake the finite CONTACT phase and preserve its approximate danger position for immediate safety decisions. It cannot authorise a route, weapon target, artillery request, reinforcement request, coordinated manoeuvre or later search. Those layers require native enemy knowledge. A hazard-only engagement returns directly to calm when its finite contact interval ends. Engine-confirmed contacts use the observer's believed target position, never the observer position, so the handoff cannot manufacture a co-located threat or a zero-length approach.

When that event affects a mounted group, its approximate position may also create a thirty-second passenger-safety lease. The lease invokes only the existing stationary-vehicle check, exact forced-speed-zero ownership and cargo exit. A local crew owner may publish the same bounded geometry to separately grouped allied passengers aboard its vehicle; the passenger owner validates crew authority and exits only its own eligible local cargo. This handover is not target knowledge and cannot authorise vehicle withdrawal, gunnery, tactical movement or contact reporting. Zeus, player and specialist ownership still reject the commands, while group release and shutdown retract the public lease.

The configured engine slot cannot be swapped at runtime. Disabling `WAIT_AIPass_Danger_Enable`, pausing the tactical pass or disabling the wider pass makes WAIT's FSM finish without issuing a new stance, movement, target or planning command. An exact stance lease already held by WAIT is still released safely. Player, Zeus, CARELESS, forced-command, mounted and specialist ownership boundaries take precedence at every action boundary.

## Danger assessment

`WAIT_AIPass_Danger_Enable` is a server-enforced, live CBA option under Infantry / Contact, default true.
`WAIT_AIPass_DangerSmoke_Enable` is a separate live control, also default true. During a severe hit,
explosion or suppression response, one eligible local soldier may queue one carried-smoke throw. A
generation lease and 45-second group cooldown prevent a burst from consuming the squad's smoke.
The operation does not wait for the throw, and the next-frame weapon release rechecks the setting,
danger generation, Zeus state and specialist ownership.
Arma loads WAIT's bounded danger FSM for the three soldier base classes. The engine supplies immediate cause,
position, expiry, source and queued records; WAIT maps those into detected enemy, gunfire, hit, explosion,
suppression, casualty and scream observations. One owner-local EnemyDetected observer separately retains only
engine-confirmed contact identity already known by a living local group member. It is removed on loss of ownership
or shutdown and never reveals or assigns a target.
The engine FSM explicitly branches through forced-command, vehicle, immediate, hide, engage and assess states.
Its responsibility map is deliberately narrow:

| State | WAIT responsibility |
|---|---|
| `ASSESS` | Record bounded geometry and expiry only. It never moves, reveals, targets or fires. |
| `IMMEDIATE` | Apply one exactly-owned weak stance for a hit, explosion or suppression. The existing group-brain tick may move the genuinely idle exposed soldier who received the native event to nearby physical cover; a stale or unavailable observer falls back to the current combat-effective anchor. It does not start another worker. |
| `HIDE` | Treat casualty and scream evidence as mobile awareness. It may use a finite crouch but cannot request cover movement from those causes. |
| `ENGAGE` | Require a living hostile source. Native knowledge and the existing group brain retain targeting, firing, suppression, CQB and manoeuvre ownership. Explicit BLUE/GREEN fire discipline remains unchanged and blocks danger-only tactical promotion. |
| `VEHICLE` | Record a bounded vehicle-safety wake only. The finite vehicle layer may stop for eligible passenger exit. An intact armed or armoured platform may request one route-neutral smoke countermeasure for a severe generation, while suppression still requires a native-known hostile. Infantry CONTACT, withdrawal, gunnery and manoeuvre retain their own gates. |
| `FORCED` | Yield to fleeing or a concrete boarding, action, healing, rearm or join task. The local engine FSM records the observation but filters it before group submission; group assessment also clears any older WAIT response. No transient tactical wake, posture or movement command is possible. Native `ATTACK` remains eligible because Arma also uses it for autonomous combat. |
| release | Filter the observation before group submission, then restore only the exact stance or cover lease still owned by this FSM generation. Authored CARELESS, disabled movement and other release conditions cannot create a transient CONTACT; a newer order is never overwritten. |

The engine states themselves never issue a destination, target or firing command. Forced commands, player/Zeus control,
external specialist ownership, disabled movement and CARELESS behaviour terminate or bypass WAIT action. This keeps
the engine response finite while the group brain owns tactics. The optional cover move runs inside that already-budgeted
group tick, refuses an active operation or native command and cannot create a second movement scheduler.
The queued group assessment repeats the concrete-task and mounted checks before changing behaviour or ROE, so
the delayed handoff cannot undo the immediate FSM's decision to yield. Native `ATTACK` is intentionally not a
yield condition: WAIT changes only finite posture here and leaves native targeting, firing and movement intact.
An eligible first engine event starts that same generation-owned group brain immediately when the periodic discovery
sweep has not reached the group yet. It does not create a second worker. Diagnostics count these first-contact
bootstraps, accepted records and finite response modes without publishing target identity.
Cause records are consumed twelve at a time by the engine FSM, then coalesced in a group queue capped at sixteen records. Events expire after two seconds;
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
participation gates. The configured engine danger FSM replaces the base soldier danger slot while WAIT is loaded;
the queued targetless-explosion audit requires a real engine event, physical cover travel and exact lease release, but
has not yet supplied live acceptance evidence.

Owner epochs and FSM generations prevent old callbacks from acting after transfer or restart. Zeus
hold-token changes, replacement waypoints and active external-controller ownership terminate the FSM and
clear the response before another controller can consume it. Interruption explicitly releases only the
temporary behaviour and combat-mode values that the response lease still owns, so a Zeus order, external
controller, feature disable, pause or locality handover cannot leave a stale COMBAT/ROE posture behind.
Eligibility checks preserve external animation/combat ownership. The new owner starts from observations received locally. Queued acceptance
covers priority/expiry, sustained fire, no knowledge leakage, disabled state, leader casualties, Zeus,
external ownership, locality transfer, physical reaction and 50 mixed-group frame-time comparison.

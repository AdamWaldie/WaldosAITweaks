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

The engine danger FSM is a finite response and interruption layer, not a second manoeuvre brain. It separates local physical reflexes from group combat planning: known-friendly near fire may change a finite scripted stance briefly, but cannot create CONTACT, while engage causes require a live hostile source. Casualty and scream causes are local alert/hide evidence only; actual losses still reach morale and role replacement, but the danger record cannot change group behaviour or ROE or invent an attacker. Explicit BLUE/GREEN fire discipline remains authoritative: real-contact awareness and defensive posture remain available, and an idle authored STEALTH element may take one weak finite low-profile stance without receiving a movement or target command. WAIT fire control, artillery, reinforcement, combined-arms requests, coordinated assault, flank and advance remain blocked. Direct commander stance orders retain higher engine priority, and a newer scripted stance invalidates WAIT's exact lease. New native causes accumulate through the current response and are reconsidered early only when the bounded queue exceeds three records. At group handoff, one strongest event is consumed per finite step and other still-live causes remain queued; an immediate hit therefore cannot erase a simultaneous confirmed contact. The surviving higher-priority physical-response lease still cannot be shortened by those later weaker causes, and native-order interruption remains bound to that surviving lease's actor rather than whichever weaker record was assessed last. Coalesced events retain the actor that received the current response separately from the actor whose native knowledge supports an inherited hostile identity. This prevents an arbitrary group anchor from turning a mixed mounted/foot event into the wrong response domain while still requiring a living local witness for target identity. At the response deadline, a close living hostile may add at most two short follow-up records and an effective vehicle commander may add at most three; every follow-up repeats ownership and interruption checks. Reaching that fixed budget ends the immediate actor chain and hands continuing combat back to native AI and the persistent group brain even while target knowledge remains valid. An engine-confirmed hostile identity is retained only when already known and is checked again against current group knowledge before a mounted response may enter vehicle combat; targetless vehicle danger remains safety-only. Other vehicle crew finish instead of multiplying the response. The waiting state otherwise checks only cheap live gates and explicit ownership markers, so runtime disable, pause, direct curator control, new Zeus orders and declared external ownership terminate the response without a squad scan or delayed command. WAIT's cause assessment, finite persistence handoff and one bounded idle-actor cover move are implemented. Immediate incoming danger also gives up to four otherwise idle squad members a generation-owned weak low-profile stance; operation participants, native tasks and actor-level moves remain untouched. Release restores only stance values still matching WAIT's exact application, while external handover discards the leases without writing over the new owner. Physical transition, interruption and 50 mixed-group performance acceptance remain outstanding. Queued acceptance covers the multi-actor hide response, known-contact hold-fire, mounted combat, mixed-domain observation, active Zeus replacement and leader-loss continuity; ownership migration and specialist animation preservation remain open.

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
`WAIT_AIPass_StaticSupport_Enable` is a next-operation control, default true. On confirmed contact,
the existing group brain samples at most 75 metres once per contact episode for a live, armed,
simulation-enabled, empty friendly static weapon. One uncommitted nonleader receives a real gunner
assignment and a twenty-second physical boarding window. The group does not wait: its remaining
actors retain fire, manoeuvre, casualty replacement and withdrawal. Failure is recorded without a
retry during that contact. CONTACT cleanup cancels only the exact WAIT assignment; Zeus or another
external owner causes a command-free handover. WAIT never teleports an actor into the seat.
WAIT_AIPass_StaticDeploy_Enable is a separate next-operation control, default true. If no
usable emplacement exists, the same finite support opportunity may select one compatible primary
weapon bag and base bag from uncommitted local AI. The pair physically moves to one of two bounded,
dry, low-slope positions with a clear firing sector, uses the engine assembly action and gives the
original carrier a real gunner assignment. The squad does not wait. Failure is recorded once for
the contact episode; WAIT does not create a weapon, consume bags directly or force-seat the gunner.
During the ordinary post-contact security phase, the same pair receives one bounded recovery attempt:
the gunner exits normally, both actors approach the exact WAIT-deployed weapon, native disassembly
creates the two bags and the engine's bag actions return them to their original carriers. A renewed
contact before disassembly remounts the gunner; one arriving during disassembly lets the finite pack
finish before the recovered team may deploy again. Authored movement, Zeus, specialist control,
locality loss, casualties or timeout release WAIT ownership without deleting the weapon or loose bags.
`WAIT_AIPass_VehicleJink_Enable` is a next-operation control, default true. A slow, intact, crew-only
armed ground vehicle may make one 25-second terrain-checked escape from a close hostile, hit or
explosion generation. The response uses the shared operation and movement lease, covers 35-45 metres
and ends before ordinary route control resumes. It refuses convoy vehicles, passenger loads, foot
elements, active movement, players, Zeus and specialist ownership. It never changes collision,
velocity, damage or physical position directly.
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
| `HIDE` | Treat casualty and scream evidence as mobile awareness. Immediate hit, explosion, suppression and gunfire geometry may give up to four idle, unreserved squad members an exactly-owned weak crouch/prone lease while the observed actor receives the existing single physical cover attempt. Casualty and scream cannot request cover movement from those causes. |
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


Squad low-profile posture inspects at most 64 members and applies at most four weak stance leases. Actor eligibility excludes declared external ownership, specialist identities and active melee control before acquisition; ordinary actors in the same group remain eligible. This boundary correction is statically validated and still requires specialist coexistence acceptance.

Lifecycle anchoring accepts an eligible ordinary leader immediately, otherwise inspects at most twelve members. Player remote-control, declared ownership, specialist identity and active melee prevent anchor selection. Opportunistic danger smoke inspects at most 64 members and tries at most three ordinary carriers; grenade initiation independently rejects specialist identities. Mixed ordinary actors remain eligible. These corrections await physical coexistence and casualty acceptance.

Grenade requests reject player and remote-controlled actors at initiation and again at asynchronous release. Taking control during the alignment window cancels the queued request. Physical control-transfer acceptance remains pending.

Grenade evasion considers at most 16 nearby actors. Its delayed recovery matches the exact reservation expiry before clearing bookkeeping, and checks the captured operation generation and owner epoch before issuing follow. Player, specialist and native action owners block movement. Cover acquisition and recovery apply the same player/specialist boundary. Physical interruption and repeated-evasion acceptance remain queued.

Squad posture restoration requires the complete six-field lease, matching operation generation and owner epoch. Incomplete records grant no restoration authority. Remote-controlled actors are excluded from acquisition, retention and restoration. Physical takeover and malformed-record acceptance remain pending.

Danger posture renewal preserves its original behaviour and combat-mode baseline while the recorded generation, owner epoch, owner and applied values still match. Lease expiry permits cleanup, but an event arriving before that cleanup cannot adopt WAIT-applied COMBAT as the baseline. Renewal after expiry and eventual release still require physical acceptance.

Danger renewals issue group behaviour and combat-mode commands only when the effective value differs from the selected response. Lease renewal remains unchanged; repeated observations do not resend identical posture commands. Physical command-churn and response acceptance remain pending.

Danger renewal compares behaviour and combat-mode ownership independently. An external change to one value does not replace the original baseline of the other value while that value still matches WAIT's application. Generation, locality epoch and owner remain mandatory for both. Physical mixed-value renewal acceptance remains pending.

A renewed suppression or hide observation preserves RED engagement only while the exact combat-mode lease is still owned. This avoids RED/YELLOW oscillation during the same finite response. Explicit BLUE/GREEN orders, external changes and release retain priority; this does not issue movement or firing commands. Physical sustained-contact acceptance remains pending.

Disabling stance control clears its bookkeeping but resets posture only for an ordinary local actor without group takeover, player control, remote control or specialist ownership. Cleanup also requires the current posture to match WAIT's applied posture. Physical setting-change takeover acceptance remains pending.

Vehicle-gunnery feature-disable and hold-fire cleanup clears WAIT's target metadata without issuing doTarget over group takeover, player control, remote control or specialist ownership. For an eligible ordinary actor, the assigned target must still match WAIT's recorded target before removal. Physical target handover acceptance remains pending.

Normal CALM restoration preserves stance and targeting during explicit external handover, player/remote control and specialist ownership while clearing WAIT metadata. Cover-height stance acquisition excludes players, remote-controlled actors and specialist identities independently of an active external-control marker. Physical mixed-group acceptance remains pending.

Cover-height stance checks inspect at most twelve members and cast at most six rays per group step. The existing rotating cursor advances for every inspected actor, including ineligible members, so large or specialist-heavy groups do not cause an unbounded eligibility scan or permanently starve later members. Frame-time acceptance remains pending.

The cover-height stance entry point rejects null or non-local groups, current Zeus holds and declared group external control before geometry work or posture changes. Per-actor specialist checks remain separate so ordinary members of a mixed specialist group can participate. Direct-call and locality-handover physical acceptance remains pending.

Danger-cover timeout is terminal for the current actor and danger generation. Exact-owned reservation cleanup and eligible failed-approach recovery still run, but the same observation cannot immediately search and recommit its failed destination. A new danger generation permits reassessment. Physical blocked-cover acceptance remains pending.

Operation start releases its old on-foot danger-posture lease before publishing the new operation generation. A live danger response then acquires MAINTAIN under the new generation using the restored baseline. This prevents generation replacement from silently discarding restoration authority. Physical CONTACT-to-manoeuvre/CQB/withdrawal acceptance remains pending.

Operation participant admission and progress use combat-effective local members of the owning group. Captive, surrendering, handcuffed, unconscious, player, remote-controlled and specialist/external-owned actors cannot count as ordinary manoeuvre progress or recovery candidates. Specialist activation excludes that actor on the next bounded step. Physical mixed-group and casualty acceptance remains pending.

Isolated recovery uses actor-local specialist ownership at both command boundaries. A specialist squadmate does not prevent an ordinary participant's recovery; group Zeus/player/declared ownership remains authoritative, and the recovery actor's declared external control yields without consuming its retry. Physical mixed-group recovery acceptance remains pending.

Role rebalancing filters specialist identities, remote-controlled actors and actor-specific external ownership before selecting reserves. Group takeover is checked again before publishing the roster using an ordinary candidate as specialist context; player, Zeus and declared group control remain group-wide. No ordinary candidate yields without recruiting a specialist. Physical casualty reinforcement acceptance remains pending.

Tactical drill rebalancing excludes squad members outside its current live fire-team element. The operation roster therefore tracks actual drill participants rather than unrelated security/support movement. Existing casualty team assignment remains authoritative; physical stalled-bound and replacement acceptance remains pending.

Danger posture respects a live tactical drill's exact groupCombatMode lease while an operation exists. Renewed engagement cannot replace its applied YELLOW discipline with RED and falsely end movement as ROE_CHANGED. Drill team rebuilding also excludes operation-quarantined unavailable actors. Physical sustained-contact and isolated-stall acceptance remains pending.

Danger's tactical fire-mode exemption requires matching operation generation, current owner epoch, drill operation generation and an active START/MOVE/PAUSE/HOLD phase. A leftover mode lease cannot constrain danger after replacement or migration. Physical stale-record transition acceptance remains pending.

Flank, advance and assault drills record the operation owner epoch at creation. Drill cleanup requires that epoch and its operation generation to match current group ownership before restoring AI features, modes or movement. A stale callback cannot gain restoration authority merely because the operation record was cleared. Physical migration/replacement cleanup acceptance remains pending.

Operation replacement synchronously ends a matching outgoing drill before changing generation. Exact matching generation and owner epoch are required; REPLACED releases drill feature holds without formation return, and the incoming operation owns subsequent movement. New drill records lacking the outgoing generation are not consumed. Physical replacement-with-held-features acceptance remains pending.

Zeus release ends a matching drill before incrementing the curator generation. ZEUS cleanup releases tracked feature holds while suppressing posture, mode and formation commands; then generation invalidation rejects old callbacks. Locality adoption retains its separate checkpoint restoration path. Physical Zeus-with-held-features acceptance remains pending.

Locality checkpoint actor restoration requires a live local member without player, remote, specialist or declared actor ownership. This gate covers feature switches, unit modes, behaviour and formation return; formation return additionally yields to native service/action commands. Group ownership eligibility remains mandatory. Physical migration-to-specialist/service acceptance remains pending.

Drill checkpoints record committed mover destinations. Locality formation return may replace a MOVE only when its destination matches that actor's recorded spot within one metre and the expected floor band. A different MOVE, or MOVE without destination proof, survives. Physical migration/new-order acceptance remains pending.

Danger intake checks actor/cause cadence before group ownership scanning. Throttled duplicates return without that scan; rejected eligibility does not advance cadence, and accepted observations retain the existing quarter-second gate. Physical intake responsiveness and frame-time acceptance remain pending.

Danger intake and selection require three numeric coordinates, not merely a three-element position array. Invalid coordinate types are rejected before event storage or geometry consumers. Existing event priority, witness identity and expiry rules remain unchanged. Physical intake acceptance remains pending.

Danger duplicate matching validates record shape and reads cause/witness through typed fields before coalescing. A malformed stored record cannot be indexed as an event or replace a valid witness. The existing selector rejects malformed records and retains its bounded priority pass. Physical malformed-intake acceptance remains pending.

Danger classification rechecks surrender and handcuff state when consuming a queued hostile identity. Intake, inherited-source retention and contact publication also reject handcuffed sources. Native knowledge of a detained or newly surrendering actor cannot alone authorise a fresh engagement. Physical surrender-during-queued-contact acceptance remains pending.

Active flank, advance and assault drills end hostile intent when the retained target begins surrender or becomes handcuffed, alongside existing captive/side-change checks. Target death remains distinct so a valid clear-through can continue after a casualty. Physical surrender-during-manoeuvre acceptance remains pending.

Shared tactical knowledge prunes surrendering and handcuffed actors from cached observations and hostile candidates alongside captive/side checks. Ending an active drill cannot immediately recreate hostile intent through the same detained target's native knowledge. Physical surrender-to-security acceptance remains pending.

Observed-contact cache pruning validates numeric expiry before comparing time and inspects at most the eight newest records, matching the writer's eight-contact cap. Invalid expiry records do not reach recurring knowledge evaluation. Physical intake and performance acceptance remains pending.

Vehicle target cleanup retires WAIT's recorded target when dead, captive, surrendering, detained or friendly. It clears the native assignment only when it still matches WAIT's target and no newer owner controls the actor. Gunnery ranking independently revalidates protection and hostility, including direct callers with stale candidate lists. Physical surrender/side-change vehicle acceptance remains pending.

Aircraft planning rejects protected targets. Active attack updates revalidate living targets for captive, surrender, detention and side change, releasing WAIT attack control as TARGET_NO_LONGER_HOSTILE. A destroyed objective remains distinct and follows the existing physical-attack egress path. Physical protection-during-air-attack acceptance remains pending.

Aircraft cleanup no longer restores enableAttack because the controller does not modify that setting. It preserves later policy changes. Owned-target cleanup additionally requires local ordinary crew without player, remote, specialist or declared actor control; newer target assignments remain untouched. Physical aircraft policy/target handover acceptance remains pending.

Ordinary aircraft route resume selects the actual authored waypoint handle rather than treating a list offset as an engine waypoint ID. Deleted temporary waypoints may leave ID gaps; the selected handle must still match the recorded resume position. Physical resume-after-waypoint-deletion acceptance remains pending.

Aircraft resume validates local group authority and the stored authored position before searching waypoints. An absent resume position yields no waypoint search or route replay; attack completion/cancellation still retires its finite lease. Physical no-authored-route acceptance remains pending.

Aircraft attack cleanup resets speed and restores its pilot feature switches only while the original AIR_ATTACK flight lease remains valid. A newer landing, braking, evasion or attack owner keeps its controls. Pilot feature restoration also requires eligible local ordinary control. Physical flight-owner transition acceptance remains pending.

Flight lease acquisition and validation both require a combat-effective current pilot, excluding unconscious, incapacitated, captive, surrendering or detained actors. The lease itself has no time-based expiry; finite controller deadlines govern release. Reacquisition retains identity rather than promising an expiry refresh. Physical pilot-incapacitation acceptance remains pending.

Operation start, cancellation and release reuse danger posture only from an unexpired response matching the current danger generation. An older response cannot be renewed merely because its timestamp has not elapsed after reset or handover. Physical disable/reset and migration transition acceptance remains pending.

The selected danger response retains one exact owner-local event, including hostile source and witness. Operation release/cancel reclassification uses it only when cause and observation time match the live generation-checked response. Targetless fallback remains targetless; it cannot fabricate a witness or enemy. Response cleanup removes the local event, adding no network payload. Physical contact-to-operation-to-contact acceptance remains pending.

Operation start classifies the retained matching danger event after publication and applies posture through its original observer. Mounted and native forced-task witnesses remain VEHICLE/FORCED observation-only; valid ordinary foot contact becomes MAINTAIN through the shared classifier. Lost witnesses are not replaced with unrelated actors. Physical mixed-domain start acceptance remains pending.

An unavailable explicit danger witness retires its finite response instead of transferring response identity to the group anchor. Exact-owned group posture is released using a viable actor; queued observations from other witnesses remain available. Native-task handover removes only the original witness's queued events. Physical witness-casualty and mixed-witness acceptance remains pending.

Engine weak-stance renewal and release require complete six-field leases. Group-hide baseline transfer also requires its complete generation/epoch proof. Incomplete records are discarded without posture mutation or restoration; they cannot confer ownership through legacy short-record fallbacks. Physical malformed-lease and posture-transfer acceptance remains pending.

On-foot operation start releases owned engine weak-stance leases for at most 64 members, then group-hide posture, before changing operation generation. Each release retains its exact-value and external-owner checks. This prevents temporary posture becoming the new operation's authored baseline. Physical danger-to-movement posture acceptance remains pending.

Building entry selection and actor availability exclude remote-controlled actors and full specialist identities. Cancellation rechecks group takeover before any stance, speed, watch or formation restoration, including early disabled/deleted-building exits. Metadata cleanup remains finite. Physical mixed-group and early-cancellation acceptance remains pending.

Building egress rechecks operation quarantine every step; losing an assigned actor keeps the egress result incomplete rather than routing that actor again. Room-visit credit requires a combat-effective local ordinary actor without player, remote or specialist ownership, in addition to the existing three-dimensional physical arrival check. Physical quarantine-during-egress and controlled-visitor acceptance remains pending.

Building approach deadline renewal requires a new best three-dimensional distance to the committed target, accumulating at least one metre of improvement. Backtracking and repeated circles cannot repeatedly renew the budget. A changed entry/room target establishes its own baseline; physical room visits retain their existing renewal path. Physical doorway-circle acceptance remains pending.

Building room retries reset their no-progress timestamp only for a new best approach distance, not arbitrary walking. Circling reaches existing finite retries, alternate-entry selection and isolated recovery while other pairs continue. Physical detour, stair and doorway cases must verify the retry timing remains appropriate; acceptance remains pending.

Building reserve selection excludes operation-quarantined actors even when they are outside current pairs, plus remote-controlled actors and full specialist identities. Those actors cannot be inserted into a casualty vacancy before later availability checks reject them. Physical casualty/reserve mixed-group acceptance remains pending.

CQB reserve replacement retires only the removed actor's active recovery observation in the matching CLEAR generation and owner epoch. Common operation quarantine also retires that actor's observation. Both retain the generation's retry budget and unavailable roster: rotating reserves cannot grant a failed actor unlimited retries. Other actors continue their existing routes. Physical casualty, blocked-entry and replacement cases remain pending while game audits are suspended.

Danger-cover timeout cleanup treats a wrong-floor arrival as an unfinished approach, even when its horizontal distance is within two metres. Return-to-formation recovery requires the native expected destination to still match the owned spot horizontally and vertically; a newer destination on another floor is preserved. Existing player, Zeus, specialist and operation exclusions remain. Multi-floor timeout and newer-order cases require physical retesting.

Engine danger classification, follow-up recycling, submission and EnemyDetected intake exclude handcuffed actors as well as captive and surrendering actors. This aligns immediate FSM eligibility with group threat selection without changing reactions to anonymous explosions or incoming hazards. Capture during an active response and later release require physical transition acceptance.

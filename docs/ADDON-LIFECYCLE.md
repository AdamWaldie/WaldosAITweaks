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

Finite engine responses record operation generation, owner epoch and group identity. Their waiting gate drains an old response immediately after operation replacement, group reassignment or owner-epoch change, before recycling. Initial native intake remains available; the check reads only the affected actor and group and adds no squad scan or worker. Physical replacement and HC-transition acceptance remain pending.

Engine queue selection and submission accept only two- or three-coordinate numeric positions before adding a floor coordinate or applying geometry. Malformed positions drain without creating danger intent. Existing expiry tolerance, priority and twelve-record callback limit remain unchanged; this adds at most three primitive type checks per accepted record. Physical delayed-contact acceptance remains pending.

Squad low-profile acquisition includes stationary native ATTACK, FIRE and SUPPRESS actors, instead of requiring an empty command. A speed cap of 0.5 km/h excludes actors already moving; operation participants, actor reservations, native service tasks and specialist ownership remain excluded. Only weak stance changes, never targets, firing or movement. This repairs an intake mismatch for soldiers already engaging; physical fire continuity and cover readability remain unaccepted.

Tactical reposition revalidates a retained target's hostility and protected state before committing movement. Missing contact geometry falls back only to the local representative's native believed position while knowledge exists; absent or malformed belief declines reposition rather than reading the target's exact live location. Existing close-armour withdrawal and screened lateral options remain. Physical occluded-contact and protection transitions are pending.

Tactical reposition reports started only after group movement returns a valid waypoint handle. A rejected final movement boundary immediately releases the exact generation as INCOMPLETE/MOVEMENT_REJECTED, drops its ownership reservation and records a bounded retry cooldown. It does not install an active movement lease or claim physical progress. Native-task and Zeus refusal cases remain pending physical acceptance.

Vehicle jink and artillery relocation require a valid returned group waypoint before publishing movement leases or active platform evidence. Rejection releases the exact new operation as INCOMPLETE/MOVEMENT_REJECTED and drops its matching feature reservation; artillery also clears its pending relocation request. Neither substitutes another route or overwrites the native task that refused movement. Physical refusal and subsequent ordinary-order acceptance remain pending.

Infantry withdrawal validates local group eligibility, player/Zeus/external ownership, a combat-effective anchor and native service tasks before route selection or any support, PATH, attack or behaviour mutation. A refused boarding, treatment, assembly or supply task leaves its existing state intact instead of creating a partially applied withdrawal. Ordinary native combat remains eligible. Entry/refusal and resumed-locality cases require physical acceptance.

Withdrawal replanning updates its target and moving state only after a valid group waypoint is returned. Missing routes and refused commands consume the existing bounded replan attempt and observation interval; they cannot claim travel or trigger fresh geometry on every callback. Physical distance remains measured independently. Blocked-route, native-task refusal and eventual INCOMPLETE outcomes remain pending in-game acceptance.

Tactical reposition completion checks the matching operation's remaining capable participants, excluding quarantined and externally controlled actors. COMPLETE requires a nonempty element within the twelve-metre destination radius and 1.5-metre floor band; anchor-only arrival is insufficient. This is terminal evidence, not an assembly gate: normal expiry still releases the operation as INCOMPLETE when the element did not arrive. Physical split-element and floor-band cases remain pending.

Tactical reposition issues the first committed avenue leg, then the shared group callback advances at most one leg after the anchor physically reaches its six-metre radius and floor band. Generation, owner epoch, deadline and a sixteen-leg bound gate progression. Final completion still uses the remaining element's arrival; no separate worker or repeated destination issuance is added. Actual covered-corridor travel and Zeus interruption require physical acceptance.

All tactical reposition legs, including the final leg and one-leg routes, run common operation progress accounting through the existing callback. A stalled element may select one stationary, non-quarantined participant without an active recovery record for isolated recovery toward the current leg; common retry limits and actor ownership checks still apply. Other participants retain their route. This adds no worker and bounds selection to sixty-four declared participants. Physical obstruction and continuation acceptance remain pending.

Reposition recovery selection excludes actors whose generation-owned retry budget is exhausted even after their active observation was retired. One already-used actor cannot repeatedly occupy the first selection slot and prevent another stuck participant from receiving its bounded attempt. Existing reservation and common command-boundary ownership checks remain. Multi-actor obstruction acceptance is pending.

Actor danger stance renewal avoids reissuing an unchanged weak-stance engine command. Existing leases retain their original baseline and updated finite deadline; transferred squad-hide baselines remain intact. When the authored baseline already matches the desired stance, WAIT owns no restoration and stores no stance lease. Physical posture continuity and performance remain unaccepted.

Combined ground-support admission requires a valid firing-area waypoint before publishing APPLIED, installing its movement lease or queuing its finite movement job. Refusal records MOVEMENT_REJECTED for the opportunity token, releases the exact new operation and feature reservation, and leaves native orders authoritative. This also closes the post-operation takeover refusal leak. Physical combined support and external takeover acceptance remain pending.

Combined ground-support continuation rechecks the current operation owner epoch and handcuffed target state. Its single bounded route reacquisition verifies the returned waypoint; refusal ends the role as MOVEMENT_REJECTED rather than renewing an apparently active move. An unchanged owned destination remains committed through normal group-move coalescing. Physical obstruction, target protection and migration acceptance remain pending.

Combined ground-support jobs capture their operation owner epoch at admission. A stale epoch returns without route cleanup, reservation mutation or terminal result publication. Matching cleanup additionally requires the exact operation generation, intent and epoch before clearing its waypoint. New-owner adoption must queue a fresh job through normal admission. Physical HC handover and late-callback acceptance remain pending.

Shared ground waypoint adoption and cleanup compare height as well as horizontal position. A floor change greater than 1.5 metres invalidates WAIT ownership; cleanup preserves the edited waypoint instead of deleting it. Destination coalescing does not treat different floor bands as the same route. Two-coordinate requests receive an explicit zero height rather than a nil coordinate. Physical floor-edited Zeus orders and terrain waypoint normalization remain pending acceptance.

Shared waypoint ownership stores the engine-returned position as its edit baseline, separately retaining requestedPosition. Radius-zero native placement can adjust the request and must not itself trigger a takeover. Explicit elevated ATL destinations use exact ASL placement with negative radius; ordinary ground requests retain safe native placement. See [addWaypoint engine semantics](https://community.bistudio.com/wiki/addWaypoint). Terrain, elevated-route and edited-waypoint physical acceptance remain pending.

The queued tactical-assessment armour case retains its leader-travel result and adds an independent physical element-travel check: at least half of the six-person fixture must move fifteen metres from their own recorded origins within a bounded observation. This is partial movement evidence, not route completion or combat effectiveness. No reveal, teleport or solved-state injection is added. The case has not run while audits are suspended.

Support admission emits one final refusal acknowledgement when operation creation fails, instead of an inner refusal followed by a stale success. It releases its matching SUPPORT reservation. Ordinary rally support also requires a valid waypoint before publishing movement/response state; refusal releases the exact operation as INCOMPLETE/MOVEMENT_REJECTED and acknowledges false. Coordinated attack admission still delegates detailed routes to its existing controller. Physical server acknowledgement and refusal cleanup acceptance remain pending.

Withdrawal applies temporary autonomous-attack, combat-mode and behaviour changes only after its group waypoint is accepted. Refused movement releases the exact operation and INFANTRY_WITHDRAW reservation, reports MOVEMENT_REJECTED and returns false before setting the retreat phase, movement lease or screen effects. Earlier support/drill retirement remains intentional replacement cleanup. Physical native-task refusal, Zeus replacement and normal retreat acceptance remain pending.

Shared group movement rejects destinations outside the two-/three-numeric-coordinate contract before adoption, route cleanup or engine commands. Invalid script input returns the normal refused waypoint handle and preserves the existing route. Omitted height remains zero; the documented operation-generation argument binds cleanup to the current operation. Physical script/refusal parity remains pending.

Danger posture cleanup and common autonomous-attack restoration consume their matching leases without reissuing commands when prior and applied values are identical. Changed values still require exact current-value ownership before restoration. This removes redundant group commands; no measured frame-time improvement or physical acceptance is claimed.

Danger posture duration selection uses fixed branches rather than allocating an eleven-entry map per response. Hit, explosion, suppression, casualty, observation and gunfire durations are unchanged, as are lease renewal and public restoration ownership. This is an allocation reduction only; frame-time budget acceptance still requires the matched physical benchmark.

Reposition recovery selection skips disabled MOVE/PATH, mounted, player/remote-controlled, specialist, live actor-reservation and native-service-task actors before selecting its one candidate. An ineligible first participant cannot repeatedly consume the selection slot while another participant remains recoverable. The recovery helper still revalidates authority at command time. Physical mixed-eligibility and isolated obstruction cases remain pending.

Common isolated recovery rejects malformed coordinates before recording an attempt and enforces operation quarantine at initial and final command boundaries. An unavailable participant returns EXHAUSTED without movement or retry-budget mutation, even when a caller retained an earlier roster snapshot. Physical late-quarantine and invalid-script-input acceptance remain pending.

Frag safety excludes handcuffed actors inside the existing twelve-metre target safety radius at both admission and delayed release. This matches danger threat protection and handles a capture state changed during alignment without adding a new scan or pausing movement. Physical capture-during-throw and friendly-safety cases remain pending.

## Engine FSM disabled-state boundary

The danger addon replaces SoldierWB/SoldierEB/SoldierGB fsmDanger at config load. Runtime disablement makes the initial continuation gate end the WAIT response; it does not write another config path or launch an unverified stock FSM through execFSM. Disabled-state acceptance must prove restored native movement/fire and absence of WAIT commands, leases and queue churn. It must not claim native danger equivalence solely from an empty WAIT operation. The matched performance baseline remains addon-absent. See [Arma 3 AI config reference](https://community.bistudio.com/wiki/Arma_3%3A_AI_Config_Reference). This behavioural boundary remains physically unaccepted.

Withdrawal speed uses an exact prior/applied lease. Calm cleanup restores it only while the group still has the applied FULL mode; a newer different mission speed is preserved. Checkpoints expose that lease through the existing exact group-speed restoration path for headless migration, and cleanup consumes the withdrawal metadata. Physical speed edits, stop/restart and HC resume remain pending.

On-foot engine danger classification does not treat disabled MOVE as loss of all combat response. Stationary defenders may receive finite weak posture and native hostile awareness; cover moves and evasive actions retain their independent MOVE/PATH guards and never enable disabled movement. Native service tasks, explicit ownership and mounted domain precedence remain unchanged. Physical stationary-defender and authored-stance acceptance remain pending.

Queued contact acceptance adds a stationary defender with MOVE/PATH disabled and an attributed native grenade stimulus. It checks physical crouch/prone during a finite engine response, no travel, unchanged disabled permissions and lease cleanup. No danger state or solved outcome is injected. This instrumented reflex case does not establish combat effectiveness and has not run while audits are suspended.

Group danger RELEASE/RESTORE may retire a dead local observer's lease through a surviving combat-effective anchor. If none remains, cleanup discards metadata without issuing group commands. New danger acquisition still requires a live observer, and generation/epoch/external-owner checks continue to govern restoration. Physical observer casualty and group collapse acceptance remain pending.

Incoming-missile jobs retain whether the warning supplied a concrete projectile. Deletion or death of that known projectile ends the matching finite defence response and flight lease, including before its first scheduled sample. A null reference after deletion cannot be mistaken for an originally unknown projectile. Warnings without a projectile retain the existing twelve-sample maximum. Physical destruction, interception and attack/landing handover acceptance remain pending.

Missile countermeasure-only response does not acquire flight-correction ownership. Live break disable releases only its exact missile-defence lease while flare emission can continue; closing both gates retires the response. Attack and landing ownership are therefore not preempted merely to fire countermeasures. Physical live-gate and flight-controller handover acceptance remain pending.

Aircraft discovery filters captive, surrendering and handcuffed objects before selecting assigned or native-known attack contacts. A protected first candidate cannot mask a later valid hostile merely because the planner subsequently rejects it. Native knowledge limits and bounded contact selection remain unchanged; the planner still revalidates at admission. Physical capture/retarget and air-to-air contact acceptance remain pending.

Aircraft ATTACK validates the selected station's actual operator before weapon selection, target/watch assignment or release requests. Locality, combat effectiveness, player/remote control and actor-context group eligibility govern this boundary, including gunners belonging to a different group from the pilot. Refusal ends the run as WEAPON_OPERATOR_RELEASED. Physical gunner casualty, separate-group Zeus ownership and specialist activation acceptance remain pending.

Aircraft target cleanup checks each crew member's own group takeover with actor-local specialist context, in addition to the pilot-group boundary. A separate-group gunner under a newer Zeus, player or explicit external order retains target/watch commands even when assignedTarget still equals WAIT's former hostile. Ordinary exact-owned targets can still retire. Physical separate-group interruption and cleanup acceptance remain pending.

Combined air support acknowledges APPLIED only when attack startup succeeds or a live flight-lease-owning brain already addresses the same target/platform. A different existing target or refused flight lease reports AIR_BUSY_OR_REFUSED and requests the existing fallback path without replacing the aircraft's current intent. A busy marker alone is not acceptance. Physical competing-target, landing/evasion ownership and fallback acceptance remain pending.

Combined air fallback requires the rejecting group's exact current opportunity token, requester and AIR_ATTACK role, then consumes that role before advancing the candidate cursor. Duplicate notices cannot dispatch extra aircraft; newer roles and the rejected aircraft's existing attack brain remain untouched. Physical duplicate delivery, stale-owner and busy-aircraft acceptance remain pending.

Combined air fallback revalidates requester eligibility/communication and live target hostility/protection after consuming the exact refusal. Invalid opportunities retire their matching fallback record. Candidate selection preserves another unexpired opportunity rather than overwriting its role. Existing aircraft brains remain untouched. Physical changed-requester, capture and competing-role acceptance remain pending.

The packaged audit launcher supports -WaitForCompletion with a bounded -BatchTimeoutSeconds observation window (default four hours). It records retained process handles, observed exit codes and separate completion markers in batch-status.json. Process exit and observation timeout remain incomplete results; the monitor never stops applications or restarts a batch. Completion markers do not override failed behaviour cases in the audit report.

Building audit comparisons excluded from WAIT scheduling are not addon-absent native baselines: fsmDanger remains replaced by the loaded addon. The fixture records effective danger/formation FSM paths and labels this scope explicitly while retaining historical case IDs and failed outcomes. Native building-path parity requires a separate addon-absent candidate; exclusion alone cannot establish a game-engine limitation.

Garrison initial application and scheduled arrival/recovery now require actor combat effectiveness and actor-context takeover clearance. Captive, surrendered, handcuffed or specialist-controlled soldiers cannot receive new movement or PATH locks from those paths. The existing temporarily incapacitated pending-route policy remains bounded by the order deadline. Physical activation/release acceptance remains pending.

Garrison hit/suppression reactions, delayed duck restoration and release posture/watch/speed/formation commands now use combat-effective actor and actor-context ownership gates too. Capture or specialist activation between the event and delayed callback cannot reacquire that actor. Removal of WAIT-owned PATH-lock metadata remains separate from tactical restoration. Physical capture and specialist transitions remain unaccepted.

Garrison and defence admission allocate positions and initial strength only from local combat-effective actors without player/specialist ownership. Captive or unconscious members no longer consume limited interior/line/reserve slots merely to be rejected during application. An empty capable set refuses the request before retiring the previous order. Physical mixed-eligibility allocation and casualty rebalancing remain pending.

Defence reserve activation requires local group authority and combat-effective, unowned reserve actors. Line losses count incapacitated/captive actors as unavailable, allowing a reserve to fill their recorded slot without ordering those actors. Activation retains its finite one-commit policy and existing terrain checks. Physical casualty/capture reinforcement acceptance remains pending.

Fresh CQB audit cases retain the 245-second physical sampling budget and add at most 15 seconds for a queued terminal result to settle before restoration/outcome assertions. A separate terminal-settlement check fails if no result arrives. The settlement interval adds no physical visits and calls no cleanup; failed entry and room visits remain failures.

Building-operation termination captures WAIT_Cortex_ClearRouteEvidence once before cleanup: timestamp/reason, at most eight pair states and sixteen actor IDs, positions, commands, expected destinations and MOVE/PATH permissions. This complements visit evidence without recurring logging or geometry work. Physical route conclusions require an audit of the candidate containing this instrumentation.

Defence continuation retires its scheduler job and published order when group eligibility is lost, replacing an indefinite delayed-job state. Initial application, arrival/recovery and release watch/formation commands also recheck combat-effective actor ownership. Metadata cleanup remains unconditional so old orders cannot reappear after handover. Physical Zeus/player/specialist transitions remain pending.

The shared unlocked-door helper now requires combat-effective actor eligibility and actor-context ownership before opening a door. Group eligibility alone cannot authorize a captured or specialist-controlled actor's door interaction. Locks, distance and request cooldown remain unchanged; opening still does not establish physical entry.

Natural building-contact QA now searches bounded room/approach combinations for a clear VIEW ray before spawning, verifies an actual actor-eye sightline and enables the required contact feature through the tuning API. Missing visibility fails a distinct fixture prerequisite; native knowledge remains necessary and no reveal or clearance order is injected. The earlier batch contact stage was manually assisted by the user and cannot establish unassisted acceptance.

WAIT local notifications pass title and body as separate CBA line arrays. The previous body string occupied the first line's numeric size parameter and caused a real client Params type error during convoy warning delivery. Static validation does not establish live rendering; the next exact-candidate batch must verify the warning appears without the client error.

Convoy IMMOBILE halts now retain their distinct operation phase through start, step and FSM routing, instead of being labelled OBSTRUCTION. They use the existing bounded halt cadence and shared scheduler, with unchanged stop/recovery decisions. This is diagnostic state fidelity, not proof of physical recovery.

Convoy release clears a crew target command only for combat-effective actors without actor-context takeover whose assigned target still matches WAIT's recorded target. Protected actors retain their newer command while stale convoy target metadata is retired. Physical separate-crew-group and Zeus target handover remain pending.

Convoy FSM spacing diagnostics reuse dimensions cached by the immediately preceding ConvoyTick and the same aligned forward-gap projection as driving. They no longer repeat bounding-box queries every callback or report a lateral offset as longitudinal spacing. No driving policy, cadence or new worker is introduced; measured performance acceptance remains pending.

Convoy revision reacquisition retains predecessor trails/cursors but invalidates follower native/path command commitments once, because setup stops those followers. An unchanged endpoint can no longer suppress the first resumed movement command. Tracked 15 m resume failed in the active old candidate; this plausible contributor requires physical retest, especially for turn direction. Matrix resume assertions now include actual position/travel, speed, heading, command, destination and forced speed.

Tracked convoy resume replaces WAIT's matching lead-vehicle current-position HALT command once with its existing MOVE waypoint destination. It requires the same group/owner halt marker and current driving authority, and retires that marker after issue. No waypoint replacement, fixed heading or recurring command is added. Tracked resume failures at 15/30 m remain unaccepted pending exact-candidate physical retest.

Convoy HALT retains one-second shared-scheduler cadence while any live local registered vehicle moves at least 1 km/h, then drops to the existing thirty-second settled hold cadence. This avoids treating an accepted halt as a physical stop and permits bounded crew/braking retries during deceleration. No extra worker or global scan is added. Tracked 75 m halt failure remains open until physical retest.

Separate convoy passenger owners now retry HALT unloading through a finite revision-scoped shared-scheduler job. It checks current registry identity, actor locality/ownership and remaining mounted cargo, handles at most sixteen records per callback at five-second cadence, and expires after ninety seconds. Vehicle movement remains with the convoy owner; all seat/safe-stop/new-task checks stay in ConvoyCrewLocal. Physical split-owner unload acceptance remains pending.

Survivor regroup is subordinate to newer group operations. Casualty-created and directly
queued jobs capture the operation generation once; a changed generation retires the job
without recalling its held actors. Surrendered, captive, incapacitated and externally owned
actors cannot become movers or receive regroup restoration. Host selection and continuation
use a capable local anchor, with capable strength distinct from the total membership cap.
Locality adoption retires this opportunistic merge; it does not fabricate a migrated merge
commitment. These changes require physical casualty, surrender, host-loss and handover retests.

Finite tracked reverse observes a bounded rear swept area for live infantry and vehicles.
A newly occupied rear area ends the reverse leg through its existing release path; collision,
damage and native pathfinding remain active. Physical obstruction and pedestrian acceptance
is still pending. Smoke delivery audits retain actual shell/landing requirements; rejected
requests fail delivery immediately rather than consuming an impossible 150-second wait.


### Standalone tactical drill migration

An unfinished advance, flank or assault publishes a bounded semantic checkpoint through the shared scheduler. It contains the committed route, bound index, fire teams, current actor destinations, absolute bound deadline and spent retry/recovery budgets. Stable server-time clock anchors keep countdowns from generating repeated network updates. The checkpoint is capped at 64 route records and 64 actors; it contains no FSM handles, scheduled callbacks or previous-owner feature leases.

Locality adoption checks the source operation generation, target, feature gate, external ownership, unchanged waypoint and applied combat/speed/attack policies before suppressing return-to-formation. It restores old leases, then allocates a fresh generation and owner epoch for the same intent. Current moving destinations are reused; completed bound destinations are discarded before the next phase. Member locality may settle for at most five seconds through the existing shared scheduler. Valid adoption preserves the combat phase instead of publishing an artificial CALM episode; failed settling records a release. A resumed assault retains its assault operation phase. A newer order, expired deadline, protected target or unsupported owner refuses resumption.

Coordinated bounds continue to use their server-role adoption path; this standalone checkpoint does not replace that protocol. `ADVANCE-HC-CONTINUATION` retains the hostile and checks route continuity, unchanged deadline and physical progress under the resumed generation. `ADVANCE-HC-HANDOVER` removes the hostile and separately checks native permission restoration and travel. Both cases are queued for a fresh packaged batch. Static validation is not physical acceptance, and continuity under disconnects, specialist interruption and performance load remains unaccepted.


Clearance egress retains each actor's exit destination while it makes new best approach progress. Arrived actors receive no additional movement command. One native route refresh is allowed after eight seconds without approach progress; the original 45-second exit deadline remains unchanged. Unlocked-door actions do not repeatedly reset a progressing exit route. Fresh clearance audits independently sample actor position and exit floor band, and record the bounded retry evidence. Physical egress remains unaccepted until the next packaged batch.


A stand-off pass without a firing solution enters its existing immutable egress leg before releasing flight ownership. The finite exit has a 75-second deadline and retains `NO_FIRE_SOLUTION` as the failed-delivery result. A physical exit cannot turn the missed attack into success. Zeus, external ownership and safety interruptions still release immediately through their existing guards. Physical no-solution egress is queued for packaged acceptance.


Coordinated acknowledgement, responder adoption and MOVE-to-COVER role changes end the outgoing drill as `ROLE_HANDOVER`. Matching posture, combat/speed and attack-permission leases are released without a follow, stop or return-to-leader command from drill cleanup. The incoming role remains the next movement owner. Actor feature restoration additionally rejects player, remote, specialist and declared external ownership. Physical role-transition continuity and specialist activation during release remain queued for packaged acceptance.


Coordinated admission distinguishes authenticated eligibility from an executing support operation. The server acknowledges the exact current-owner lease and publishes a token, owner and expiry for route preparation. Both requester and server dispatch consume that eligibility; only an executing assault status can claim the requester as base of fire. Prepared acknowledgement may coexist with an existing tactical drill but cannot claim its movement. Direct coordination uses the helper's live position as reservation metadata and does not require a safe rear rally route; reinforcement-only admission retains its separate rally routing. Physical direct-contact composition and HC re-acknowledgement remain unaccepted.


Coordinated bounds now use the same three-person minimum as responder admission. Three capable dismounts begin with two movers and one coverer; role changes rebalance the moving element before issuing a bound. Transferring a donor removes that actor from the available covering list immediately, preventing duplicate selection and false two-person strength. Fewer than three capable actors retires the coordinated role. Physical three-person movement, casualty replacement and unique-participant acceptance remain queued.

Coordinated support leases store their attack destination as one ATL position. Operation admission retains that complete position as its objective and initial route point; it must not interpret the coordinate array as a route and reduce the objective to altitude. This handoff correction awaits physical acceptance.

Coordinated covering roles retain their finite lease without requiring travel every thirty seconds. Their moving bounds retain separate physical-progress watchdogs. Cover stop orders are issued once per token/sequence transition and exclude player, remotely controlled and specialist-owned actors; normal rally still retains aggregate no-progress failure.

Legacy support PATH holds retire their WAIT marker during calm, support and withdrawal cleanup. Restoring PATH or issuing follow commands separately requires an ordinary local actor without player, remote or specialist ownership. Removing WAIT metadata is not permission to alter the replacement controller's movement state.

Support acknowledgements must match the exact six-field lease and current owner. A delayed acceptance becomes rejection when either the lease or request has expired; it cannot publish fresh prepared eligibility. Matching rejection remains valid for cleanup.

Coordinated bound selection continues through its bounded responder list when an eligible element has no safe next route. It stops scoring after the first viable bound. Eligibility alone must not consume a movement slot or prevent another element from progressing.

A coordinated next-bound geometry rejection permits one retry after eight seconds, without blocking other elements. A second rejection retires that token as NO_SAFE_BOUND. Selecting a viable route clears its geometry-failure count. This is finite failure handling, not proof of route success or physical acceptance.

Building room progression opens usable doors without replacing committed movement solely because a door changed. Interior no-progress retries affect the room mover, retaining the partner's security destination; entrance staging can still retry the pair. Physical room visits remain the only completion evidence.

A CQB reserve replacement rebases best-distance observation at its actual position. The committed room cursor and generation-owned recovery budget remain unchanged; a removed actor's closer baseline must not hide real approach progress by the reserve.

Moving bounds lease individual RED orders as YELLOW while retaining native target and fire features. Cover/release restores the exact prior mode only if unchanged. BLUE/GREEN holds are not escalated. This repair follows native ATTACK diversion in the b3a9f70 batch and requires physical retest.

Between-bound restoration uses the same actor-task ownership guard as movement admission. New player, remote, specialist, boarding, treatment and independent actor reservations block restoration of former WAIT combat modes, behaviour and AI features, even when the former applied value is unchanged.

Support release retires its exact token-matched tactical bound before shared operation cleanup. It uses ROLE_HANDOVER without formation recall, preventing an old queued drill from blocking a replacement bound as NOT_READY. A different drill token is untouched.

Coordinated fire-team bounds inherit the existing support operation generation and owner epoch after validation. They do not start a second operation. This enables the common interruption, attack-delegation and exact restoration paths already used by standalone tactical drills.

Combined-arms discovery preserves an asset's unexpired role from another opportunity. Separate requesters cannot overwrite that reservation; matching tokens or expired roles remain eligible for validated dispatch. This protects simultaneous local contacts without creating a battle-wide assembly controller.

Combined ground manoeuvre admission refuses OTHER_INTENT_ACTIVE when an existing local operation has a different intent or target. It does not cancel that operation or reveal the new target through the refused move. Fire-only support remains a separate non-movement opportunity. Compatible same-target combined intent can continue through normal generation validation.

Ground-support refusal retires its exact reservation on the server through current-owner and snapshot validation. It retains the refusal result, clears only matching role metadata, and never cancels the asset's existing operation. Repeated or replaced replies are no-ops; aircraft retains its separate fallback path.

Combined ground-fire admission checks both group and gunner fire permissions, current operator ownership and the shared friendly/civilian firing-lane guard. NO_FIRE_OPERATOR and BLOCKED_FIRE_LANE retire the exact reservation instead of publishing APPLIED. This is one admission check, not a persistent scanning loop; native aiming and weapon release remain responsible for actual fire.

Combined ground arrival uses the same fire permissions, actor ownership and friendly-lane checks as direct fire admission. CombinedFireDecision records ORDER_ISSUED or a refusal, separately from physical POSITION_REACHED. Neither receipt proves shots, suppression or destruction; combat acceptance still requires fired and target-effect evidence.

### Scheduler and tactical FSM authority

Queue admission rejects a non-local group or a supplied owner epoch that differs from the current
epoch. It assigns the current epoch only to new work without a conflicting proof. Keyed coalescing
requires the same group and epoch, updates the existing state and due time, and returns from the
function before append. A stale callback cannot become fresh by being queued again.

Tactical FSMs retire when their drill token or operation generation is superseded. Building queue,
callback and finalization boundaries require the current brain and owner epoch. Aircraft waiting
states retire replaced/non-local brains before invoking control-handover actions. These checks
retire old work; they do not complete, restore or command a successor operation.

Real tactical stage changes update the matching operation to MANOEUVRE, ASSAULT, SUPPORT or SECURITY.
Ending a coordinated child never completes its parent. Danger posture reads the matching child's
moving and recovery actors rather than treating every participant as a mover. Cover actors retain
native low-profile protection; active movers retain mobile protection.

The coordination batch now includes scheduler component and physical movement cases. Component
cases measure one keyed callback, updated state, retirement, rejection without epoch rewriting,
fresh-owner execution and no old-epoch execution. They supplement physical movement, interruption,
HC and performance acceptance; they are queued and have not passed in game.
A keyed callback may request an earlier wake while it is running. The scheduler carries that wake into both the rescheduled job and its cached earliest deadline, so the idle gate cannot postpone immediate reassessment until the callback's normal cadence. The additive scheduler audit checks a self-wake against a twenty-second return delay; physical acceptance remains pending.

Keyed updates coalesce only within the same explicit generation as well as group and owner epoch. Stable aircraft observer keys therefore cannot adopt an earlier generation's braking or landing progress after locality changes. The retired callback retains its original generation for its existing release checks; fresh work receives separate state. The additive generation-isolation audit remains pending in game.

Group decision admission and execution also require the supplied brain to match WAIT_GroupBrain on the current group. A detached brain with a matching numeric generation is rejected before queuing or tactical commands; execution records SUPERSEDED only on that detached state. This safeguard follows the existing building and aircraft brain contract. In-game interruption acceptance remains pending.

Convoy admission, execution and FSM replacement transitions require the registered WAIT_Convoy_Brain as well as the registry revision and job token. Delay watches token or brain replacement immediately, including a thirty-second settled hold; replacement does not wait for the next due step. Physical convoy replacement and locality acceptance remain pending.

The group tactical FSM watches registered-brain replacement in Router, Delay and Waiting. Finished cleanup additionally requires the captured owner epoch and registered brain before clearing group state or releasing tactics. A detached same-generation FSM audit executes the packaged FSM and checks retirement without clearing the live brain; this case remains pending in game.

Support and artillery Delay states watch registered-brain replacement as well as generation changes. Support Waiting retires superseded work before invoking Zeus or external cleanup callbacks. Final bookkeeping requires the matching generation and registered brain. Existing current-generation interruption cleanup remains active; these paths await packaged runtime acceptance.

Building Router, Delay and Waiting now watch registered-brain replacement directly, matching queue and execution guards. A detached same-generation packaged-FSM case verifies retirement without altering the registered sweep brain. This lifecycle case remains pending; physical entry, room visits and traversal are still separately unaccepted.

### Clearance exit progress

Each exit assignment retains physical arrival within five horizontal metres and the 1.5 metre floor band for its current owner and operation generation. Once observed, that exit is complete even if native formation later moves the actor away; WAIT does not pull it back while a partner descends. Replacement ownership still cancels routing, and an unavailable actor or unvisited exit retains failure evidence. The existing one-refresh recovery bound and 45-second deadline remain. This uses the existing bounded building callback, with no extra scanner or per-unit worker. The two-person case has physical clearance and handover evidence; the larger-house exit-latching repair still requires its next packaged retest.

Clearance replacement orders suppress formation recall independently of setting cleanup. Ordinary local actors release unchanged WAIT speed and posture leases even when a temporary curator hold preserves the new movement destination. Direct control, specialist ownership, explicit external ownership, conflicting actor reservations and native action tasks still prohibit writes. Edited settings survive. This repairs a receipt-erasure path that could leave an indoor speed cap applied after cancellation; physical replacement-order validation remains pending.

Room recovery consults durable native retry counts before starting another isolated actor attempt. Reserve replacement and owner replay cannot reopen that room budget: one lane permits one recovery cycle, and multiple lanes permit at most two before exhaustion is handed to another lane or recorded incomplete. A yielded native task keeps its claim without new movement or an unreachable classification; the existing operation safety deadline still applies. No room is credited without physical arrival. This bounds a twelve-person repeated-replacement failure; packaged physical acceptance remains pending.

### Native order cancellation during clearance

Clearance captures a bounded receipt of the current native waypoint and waypoint count. Its callback compares that receipt before any room, recovery, speed or posture write. A new or edited authored order cancels the matching clear as NEW_ORDER, releases unchanged owned settings without formation recall and advances the operation generation. The implicit spawn waypoint is excluded. The durable clearance order retains the receipt so locality replay refuses a superseded intent. This adds no waypoint scan or new worker; physical replacement-order and HC acceptance remain pending.

Clearance checks the individual native task immediately before initial room movement, posture/speed changes, stalled retries and exit commands. Boarding, medical, service, joining and assembly actions yield without fresh movement or consuming route-failure retries; other lanes continue. The existing finite deadline remains. These guards use current actor command state in the existing callback; native-task physical regression acceptance remains pending.
# Clearance exit arrival ownership

Room movement keeps native building positions as its destinations. The geometry-only nearby floor adjustment was removed after a normal live audit showed its converted 8.62 m ASL target producing a native path endpoint at ground-floor 5 m ASL. Floor support does not establish native navigation connectivity. Physically established access checkpoints and finite recovery remain; no adjusted point grants room coverage. Upper-floor reliability and performance acceptance remain pending.

Clearance records only its issued native movement destinations, including finite recovery requests. On a changed group waypoint, an ordinary actor still executing MOVE is released to the current leader only when its live destination matches that issued request within 0.25 metres and actor/task/external ownership remains eligible. A different actor destination is preserved. Active cancellation releases matching moves and known STOP holds directly after the old operation retires, rechecking the owner, epoch, generation, registered brain, actual command and new order. Already completed STOP holds retain their receipt-based handover. The physical audit includes a newer, distinct actor destination with actual travel and old-clearance retirement requirements. Planner-adjusted endpoints outside the conservative match remain unaccepted; this is not a blanket movement reset or general external-script ownership guarantee.

The normal clearance audit also observes the real actors' native PathCalculated events, with a maximum of 24 samples per actor, eight-second spacing and 24 sampled path points plus the last point. Handlers are removed before disposable actor cleanup. This is diagnostic only: a calculated endpoint is not a physical visit, and segmented routes are not automatically classified as failed paths. The accompanying insideBuilding sound-interior value is supplementary evidence, not a universal geometric admission requirement.

Physical room/support arrival now holds that actor once per destination between pair handoffs; an unchanged stopped support target is not restarted. Follow-through arrivals hold once while remaining members finish. Newer native orders include these room holds in the same receipt-based release. An ordinary mover stranded by exhausted recovery remains a failed-participation result even when replacements or other members complete shared room coverage. Death/incapacitation replacement remains a separate contingency. These changes require fresh physical acceptance.

Initial exterior admission waits when every cached recognised door is locked and closed. The bounded building job holds ordinary admitted actors once, observes live locks and resumes the normal first-room request when access becomes available; expiry remains a failed/cancelled operation. It does not unlock or open locked doors. Actors initially inside the live model bounds are exempt from this exterior barrier. Unknown door conventions, partially locked access, per-entrance routing and mid-clear locking remain unaccepted; model bounds alone do not establish a safe room. Status is published only on admission transitions, without repeated broadcast or movement writes.

Active clearing members must each physically visit two distinct reported positions (or the sole available position) before successful egress. Shared coverage alone cannot finish a member parked at the first node. Once coverage and entry are established, a finite native follow-through chooses from at most 24 remaining visited nodes, preferring the current floor; common recovery remains one attempt and failure cannot become a successful visit. An independent audit now checks every initially admitted worker, with reserves outside that admission kept separate. These are navigation receipts, not proof that a hostile room is safe.

Reserves receive an initial actual-position hold before their single staging geometry attempt. If that attempt is rejected, the hold remains rather than leaving native formation following an interior leader. Ordinary room movers retired by common recovery likewise receive one guarded hold; player, specialist, medical, actor-reservation and newer-order ownership still prevent commands. This prevents two sources of exterior wedge formation but does not provide tactical security sectors. Existing terminal handover/cleanup includes these actors.

A newer native waypoint releases pre-completion holds through the clearance owner's cancellation path. It clears its old hold receipt before any release command and does not depend on an ordinary group brain remaining live after a failed clear. External takeover receives no old formation command. Completed-clear holds remain governed by the separate public receipt path. Physical interruption acceptance remains required.

Interior mover changes retain one finite route checkpoint when the new mover is off the next room's floor: the pair's preceding physically visited node must lie on that target floor. The actor must actually arrive within the existing three-dimensional tolerance before the final room request resumes. The checkpoint does not mark a room clear, change a floor coordinate or add a recurring controller; existing room recovery and cancellation bounds apply. This dynamic route-continuity change requires packaged physical validation and does not claim to solve all stairs or model path faults.

During the finite EGRESS phase, each clearing actor receives one native exit destination. Confirmed horizontal and floor arrival records a monotonic receipt and issues one owner-guarded stop at the actual arrival position. Later steps do not rewrite that hold. This prevents an early arrival from resuming formation while its partners are still exiting. New native orders, Zeus or specialist ownership still supersede the controller. Terminal settlement retains actual positions and an order-scoped hold even when the result is INCOMPLETE; it must not recall workers around an interior leader. Cancellation retains its existing cleanup path. This change adds no recurring actor controller or geometry scan. It does not yet provide security sectors or a complete tactical consolidation phase, and requires a fresh packaged physical retest.

### Clearance leader handover correction

The d61afa9 normal clearance batch completed 408 checks with nine failed assertions, all in the twelve-person case. Two- and six-person admitted-worker progression and physical handover passed in this run. Twelve-person upper-floor routing, settlement and handover remain unaccepted. The geometry-supported floor alternative was used but native paths still projected its target onto the ground.

Recorded handback receipts showed a healthy, local stopped leader following itself. New ordinary MOVE waypoint handover now sends only that held leader to the current authored waypoint position; followers resume following the leader. Waypoint lists remain intact, different actor destinations remain protected, and non-MOVE waypoint semantics receive no positional substitute. The same correction applies to the completed-hold consumer. Physical retest is pending. This does not establish tactical consolidation or coherent reserve security.

### Shared physical floor access

An entered pair whose preceding node is on the wrong floor may use another lane's physically visited node on the destination floor as a native access checkpoint. Selection examines at most 24 original visited nodes once per changed coverage snapshot, chooses the nearest matching floor, and caches one approach per claimed room. Actors must physically reach that checkpoint before the assigned destination is requested; neither checkpoint selection nor arrival clears the assigned node. No model route table, coordinate lifting or additional actor controller is introduced. Physical retest is pending; this change does not assert that the native planner can reach every reported building position.

A stalled unentered partner uses its existing one-shot entry recovery to retry the original lane anchor after that anchor has been physically visited. A nearby geometry-connected candidate is not treated as a proven native access path. The shared entry target is changed once at recovery and subsequent pair steps retain it; actual interior visits and common recovery limits still govern success. No additional retries, immunity or simulated entry are granted. Physical retest is pending.

### Absolute clearance episode lifetime

Physical progress may renew the existing 240-second stall lease, but cannot renew the separate absolute episode boundary. Initial admission sets that boundary using 60 seconds per filtered interior node, with a 240-second minimum and 900-second maximum. The eleventh public clear-order field carries its server-clock timestamp across owner migration; legacy orders retain their published deadline as the boundary rather than receiving a fresh lifetime. Progress publication preserves this field unchanged. Exhaustion moves into the existing finite 45-second egress phase and preserves missing room/worker participation as failure. Wholly locked admission obeys the same earlier boundary. No elapsed timer passes physical clearance. Absolute-lifetime physical acceptance remains pending.

Once shared coverage is complete, entered workers continue their finite individual follow-through without waiting for every partner to enter. Unentered partners remain with entry recovery; they are not assigned interior follow-through or counted as successful. Missing entry and successive visits still latch an incomplete result before egress. The episode boundary is checked before further follow-through movement is issued. This removes a collective waiting barrier, not the individual participation requirement. Physical retest remains pending.

The clearance audit retains its original 245-second physical sampling and 15-second settlement findings. If a hard boundary exists and settlement is still missing, a separate diagnostic waits only through that absolute boundary plus the existing 45-second egress budget and ten seconds of observation tolerance. This does not rewrite original findings, collect substitute room visits, inject movement or call cleanup; it checks finite terminal publication before the subsequent ordinary waypoint handover.

### Native planning-mode traversal diagnostic

Independent excluded actors now include a fourth FORMATION control alongside DIRECT, HOUSE-WAYPOINT and REPLAN. It issues ordinary native movement and a forced FORMATION PLANNED destination for the original model node, then observes actual 3D entry and successive visits under the same node budgets. Original controls remain, placement is recorded rather than corrected for this native comparison, and a skipped node remains failed. Different fixture instances prevent treating one run as a definitive mode ranking. No production routing mode changes are made from this diagnostic alone. Physical results are pending.

### Exposed model positions retained for transit

Clearance retains the complete original engine position array separately from its roof-covered target set. Exposed positions remain excluded from clearance coverage but may supply a floor-access candidate during an off-floor interior request. Selection examines at most 32 exposed positions in original metadata order, requires a same-building upward floor surface within 0.75 metres of the original point, and caches success or absence once per half-metre floor bucket, with at most eight buckets per episode. A preceding visited same-floor checkpoint remains preferred. If no supported exposed point is found, the existing bounded shared-interior checkpoint search remains available. Actual checkpoint arrival is required before the assigned room request; it cannot clear that room. No classname routes, coordinate lifting, object repositioning or second movement writer are added. Native raw large-house controls reached exposed upstairs positions across all three movement modes while later interior nodes failed, motivating this routing distinction; production physical retest is pending.

An initial lane assigned above its actor's current floor may also request this transit approach before its first covered-node visit; transit selection itself does not establish entry. Checkpoint completion requires 3D proximity within 1.5 metres and feet on the checkpoint floor within 0.75 metres, preventing a nearby actor on lower stair treads from prematurely switching to the room target. Partner flow and progressive reserve admission remain unaccepted.

Covered-node visit receipts and arrival holds now require feet within 0.75 metres of the node's absolute floor elevation as well as 1.5-metre 3D proximity. Pair handoffs consume the visit collector's actor-specific receipts rather than creating separate proximity-only entry receipts. Matching production audit samples apply the same floor requirement. Transit buckets and off-floor comparisons use absolute ASL elevations, avoiding terrain-relative floor comparisons on slopes; native destination coordinates remain unchanged. These stricter checks may expose additional failures and remain pending physical retest. They do not prove a room safe or establish full CQB acceptance.

### Actor-specific buddy handoff route

An unentered or off-floor mover that has not personally visited its buddy's preceding covered node first receives that original node as a physical handoff checkpoint. An already-entered mover on the destination floor requests its next room directly, avoiding a redundant stop at its buddy's occupied security node. An off-floor request may then append one destination-floor access checkpoint, using visited shared access before unvisited supported transit candidates. Each actor/pair/room retains an ordered approach of at most two legs. Three-dimensional arrival and absolute floor proximity are required before advancing; new actors receive their own approach identity. Neither a handoff nor a transit arrival clears the assigned room, resets the durable room/actor recovery budget, or extends the episode lifetime. The previous target-floor-only approach could skip the preceding ground-floor room during mover rotation. Physical retest is pending.

### Native leg commitment and hold receipts

Room visitation tolerance is separate from native movement completion. An actor whose MOVE destination still matches this job's issued target is allowed to finish that leg before a room handoff, checkpoint advancement or arrival hold. Native readiness or precise arrival within 0.4 metres ends this commitment; the episode and recovery bounds still apply. Arrival holds cannot stop a different live MOVE destination. Each new owned request retires its prior room-hold receipt, and a stopped actor displaced from its recorded target is not treated as already settled. Confirmed exit-arrival records remain explicit handover candidates when a new waypoint interrupts egress. This adds no second movement controller. Physical retest remains pending.

Successful coverage transitions also wait for active owned native legs to settle before exit dispatch. Deadline exhaustion and unreachable work retain their finite failure cleanup. Terminal restoration skips a different live MOVE destination; releasing unchanged WAIT stance/speed settings remains separate from taking movement ownership.

Active clearance workers also retain movement ownership when a failed native path silently returns them to formation. The existing owner-local building step holds the actor's actual position once per issued request only when no new request is being issued, the command is empty, unitReady is true and the planner reports DoNotPlanFormation. Explicit FOLLOW, newer MOVE, specialist tasks and takeover remain untouched. The next owned movement request retires this fallback hold; newer native order cleanup includes stopped fallback actors. Existing finite retries still recover or fail the route. This prevents one identified source of wedge drift; physical repeatability and coherent security/consolidation remain unaccepted.

Reserve staging acceptance excludes soldiers promoted into the active clearing roster. Their old staging record is not their current movement assignment.

Geometry-supported raw transit nodes are provisional access candidates. During clearance, a candidate that stalls under the existing observation interval is abandoned once for that actor/room claim. The original room remains the objective and is issued through the same owned movement writer. An abandonment tombstone keeps its arrival flag false and prevents immediate recreation; it neither marks coverage nor renews the progress deadline or resets retries. Covered buddy handoff checkpoints are not abandoned by this path. Physical room recovery and locality migration acceptance remain pending.


Reserve staging arrival requires three-dimensional proximity, matching floor height and completion of WAIT's own native movement leg. A different MOVE or FOLLOW cannot be stopped by a stale stage receipt. This uses the existing callback and movement receipts; no recurring controller is added. Physical reserve and newer-order interruption acceptance remains pending while game audits are paused.


A current-generation staged reserve with a different live individual MOVE or FOLLOW is excluded from staging and casualty promotion until that command ends. Its owned stage MOVE remains eligible for promotion. This protects the individual command boundary that the group waypoint receipt does not represent; it adds no scan or movement writer. Staging metadata is not an independent movement controller, so its retention alone does not explain CQB entry delay. Physical replacement-order and casualty acceptance remains pending with audits paused.


Standalone driving retires its cap when the vehicle is destroyed/immobilized or its driver is combat-ineffective. Immediately before recovery/cap commands it rechecks vehicle mobility plus driver and effective-commander ability, alongside existing ownership and MOVE/PATH boundaries. It does not repair damage, fuel, relocate vehicles or force seat changes. Crew casualty replacement remains a distinct incomplete capability. This source correction follows local controller review; physical casualty/immobilization acceptance and runtime performance remain pending while audits are paused.


Convoy follower pacing distinguishes predecessor reverse motion from forward travel using the existing vehicle-local longitudinal velocity sample. Below -0.5 m/s, follower requested speed is zero after smoothing/lateral recapture and before infantry safety limiting. Route commitments remain intact; ordinary pacing resumes when reverse motion ends. No extra sensor loop, waypoint replacement or recovery budget is introduced. The prior absolute-speed input could command forward travel toward a backing predecessor. This source fault is separate from unresolved mixed tracked/wheeled stop/start and spacing observations; physical reverse-yield, restart and convoy acceptance remain pending with audits paused.


Tracked reverse admission/continuation requires combat-effective driver and commander, not alive crew alone. Reverse cleanup sends STOPTURNING only when the live LEFT/RIGHT command matches its recorded last turn; a different turn is preserved. Generation, epoch, vehicle marker and external-owner checks remain required. This matching guard cannot distinguish an identical later native command without an ownership/order receipt, so universal successor preservation is not claimed. Reverse distance, timeout and facing limits remain unchanged. Physical crew incapacity and different-turn handover are pending with audits paused.


Convoy mobility eligibility is computed once before locality filtering. The same combat-effective-driver roster is used for split-locality comparison, so an unconscious/incapacitated driver no longer masquerades as an eligible remote vehicle and indefinitely bypasses the tick. Real eligible split locality still defers commands; no effective vehicles still reaches the existing IMMOBILE request. Remaining mobile vehicles retain existing continuation/contact policy. This does not implement seat replacement or prove casualty continuation; physical incapacity, migration and halt acceptance remain pending while audits are paused.


Convoy horizontal projections now use unit bearings derived from vehicle heading. Zeroing vectorDir's vertical component without renormalizing previously shrank forward distance by the cosine of vehicle pitch and fabricated lateral offset: a straight 30 m gap at 30 degrees pitch appeared about 26 m forward and 15 m lateral. Spacing/phase diagnostics, obstruction classification and forward trail acquisition now share the corrected horizontal metric. Physical gap/speed thresholds and turn handling remain unchanged; the audit retains its independent route-axis observation. This proves a calculation fault, not its contribution to observed mixed-convoy stop/start or physical terrain acceptance. Audits remain paused.


Convoy operation brains explicitly carry subsystem CONVOY into the shared queue. The prior omitted tag defaulted them to TACTICS, selecting the infantry active gate and pause deferral despite the dedicated convoy registry/scheduler flag. Correct classification uses the existing WAIT_Convoy_SchedulerActive gate and existing safety-subsystem scheduling rule; no extra loop or new setting is introduced. ConvoyTick still enforces its own pause, Zeus and external-owner command boundaries, so this does not authorize movement during a tactical pause. Driver incapacity itself does not retire convoy callbacks through a leader-effectiveness gate. Physical pause, disable, incapacity and migration acceptance remains pending while audits are paused.


Temporary global tactical pause is recorded as PAUSED rather than EXTERNAL_OWNER in convoy lease release. The finite convoy brain remains registered, reports SUSPENDED and observes at five-second cadence through the existing queue. WAIT local driving leases release once; pause is not a fabricated arrival, obstruction or transfer of ownership. On resumption the tick reacquires from current native state, while player/Zeus/specialist/external takeover still terminates old ownership. Semantic suspension clears obsolete spacing/recovery counts. Physical pause/resume, persistent HALT and locality migration remain unaccepted; no game audit was launched.


Suspended convoy resumption clears common operation state only when its saved operation generation, CONVOY intent and current owner epoch still match. Previously it unconditionally erased WAIT_Operation after eligibility returned, including a successor explicit operation. Current-route reacquisition remains required. Eligibility rejection still combines feature/faction filters with external actor orders; its early return can retain old driving leases. That broader suspension/restoration distinction remains unresolved and is not repaired by this successor guard. Physical resume/handback acceptance remains pending while audits are paused.


Shared ownership takeover now recognizes the already-supported active curator garrison and suppression actor flags during cleanup/command boundaries as well as admission. Actor-local contexts remain limited to that actor; ordinary group commands retain group-wide protection. Addon presence alone grants no ownership. This closes an admission-versus-restoration discrepancy and supports safer filter reasoning, but does not by itself resolve all convoy eligibility-filter lease release or establish controller handover acceptance. Broad compatibility expansion remains deferred. Physical curator-order interruption/cleanup remains pending while audits are paused.


Old convoy cleanup treats a different current movement-operator group as successor ownership, including ordinary AI groups without an external-controller marker. It preserves that vehicle's speed/unload policy and does not recall a driver from another group. Empty vehicles can still release their unchanged old cap; old-group metadata is retired without overwriting a new group's receipt. This closes a group-transfer restoration gap but does not establish all callback/event-handler transfer or filter-only lease cleanup. Physical AI-group reassignment/handback remains pending while audits are paused.


Convoy hit-handler IDs now carry a local group/machine ownership receipt. Current crew processing adopts the generic handler for its active convoy without duplicating it; cleanup removes only a matching local receipt and preserves a successor group's adopted handler. Unreceipted legacy handler cleanup is not presumed owned. The existing passenger-HALT follow-up job is also tagged CONVOY, using the registry scheduler gate and its existing revision checks. Neither correction creates a polling loop or completes handover/JIP acceptance. Physical hostile-hit continuity, repeated cleanup, owner migration and suspended passenger processing remain pending with audits paused.


Clearance topology requires an overhead GEOM hit belonging to the target building or its parent object. The existing ten-metre roof probe examines at most four hits per original model node. Neighbouring overhead objects cannot classify a point as a room, and an empty owned-roof set is refused/logged rather than promoting all exposed model positions into clearance. Original coordinates remain unchanged; garrison/raw transit metadata remains separate. This is an admission/topology correction, not wall-separated actor visit proof or universal building support. Tall/unusual models outside the probe envelope and repeatable physical clearance still need evidence. Audits remain paused.


Production room visit/entry receipts and close room holds now reject intervening target-building GEOM surfaces at body height. Existing proximity/floor bands remain required. Callback-local pose/target caching caps new geometry probes at sixteen, each with at most eight hits; saturated results and exhausted budget cannot grant a receipt. Worker observation rotates each callback to avoid permanent first-worker preference. Original coordinates, movement ownership, retries and deadlines are unchanged. This source implementation still needs an independent exterior-wall audit, furniture/door/floor edge cases, dense-worker fairness and matched performance evidence. Existing audit proximity flags remain weaker and cannot establish this new boundary's acceptance. Game audits remain paused.


Building command boundaries and room-geometry cache reads now recheck registered brain identity, cancelled/finished flags, locality, owner epoch, clear generation and the bound common-operation generation. Building existence/transform, external takeover and authored native order remain live checks. Thus cached geometry cannot authorize room receipts or movement after a replacement operation or moved/deleted building invalidates ownership. The callback-local cache/budget remains unchanged; no new observer or lifetime extension is added. Physical supersession during work, transform cancellation and performance acceptance remain pending with audits paused.


CQB geometry queries that cannot grant a receipt now return before repeated ownership/config scans when their ray quota is exhausted or the exact callback-local pose/target already has a negative result. Cached positives and new probes still pass current brain/generation/epoch/order/transform and external-ownership checks. No dynamic ownership decision is cached, no query becomes a positive through budget exhaustion, and the sixteen-probe ceiling remains. This reduces avoidable source work without mutating the read-only ownership gate; measured runtime benefit and performance acceptance remain pending with audits paused.

Reserve staging constructs its bounded migration journal only when a search is consumed, an approach physically arrives, or an owned approach times out. Unchanged callbacks retain the previous receipt; authority and content comparison still gate publication. This reduces idle allocation work but has not been measured against the live frame-time budget.

Convoy lateral recapture retains the longitudinal closing-distance cap. A sideways offset beside a stopped predecessor cannot raise the requested speed above the safe closing cap merely to regain the trail. This adds no scans or controller. Physical offset recovery, mixed tracked/wheeled stop/start and convoy acceptance remain pending.

Reinforcement casualty assessment compares current combat-effective strength with the retained peak living roster. Unconscious, incapacitated, captive and surrendered actors do not count as available combat strength; conscious wounded actors still do. The existing responder cap, request tokens, bounded retry and 300-second assignment expiry remain. Physical casualty-triggered reinforcement arrival and CQB replacement remain unaccepted.

The owner-local group decision job defers planning for five seconds when every living member is hidden or simulation-disabled. It retains the same shared scheduler job and does not force simulation on, create a pending-order worker, release ownership merely for dormancy, or extend finite operation deadlines. Dead groups still retire. One awake visible member permits ordinary reassessment; individual operation participant readiness and explicit dormant-order admission remain separate work. Physical dynamic-simulation wake, hidden actors, Zeus replacement and HC migration tests remain pending.

Clearance room-visit evidence requires a visible, simulation-enabled combat-effective actor. A dormant or hidden participant cannot credit a new visit from a frozen stored position. Existing geometric, distance and floor checks remain. This does not change cleanup or solve dormant participant routing; physical dormancy and clearance tests remain pending.

Clearance command checks now require simulation-enabled visible actors; reserve staging and promotion use the same dormancy conditions. The existing owned-actor predicate remains separate, preserving roster obligations and guarded setting restoration for dormant workers. This does not extend operation deadlines, enable simulation or make dormancy a casualty. Explicit dormant admission and comprehensive egress/recovery handling remain pending, as do physical tests.

Clearance egress preserves an already observed exit but cannot establish a new exit from a hidden or simulation-disabled actor position. Dormant unresolved assignments remain in the exit roster and skip retry bookkeeping until awake; the original finite egress deadline still ends an unresolved exit as incomplete. No simulation or deadline is changed. Physical dormant exit/wake tests remain pending.

Common native recovery returns YIELDED for hidden or simulation-disabled actors before reading recovery history and again before committing a retry. Dormancy therefore issues no recovery move and consumes no attempt; current roster ownership, operation generation and original lifetime remain. Wake can reconsider the same finite generation if it is still valid. Physical wake, casualty and HC recovery acceptance remain pending.

Shared operation progress requires a visible simulation-enabled observer, for both declared participants and the leader fallback used by participant-free operations. Hidden or dormant position changes cannot renew lastProgressAt or reset replans; participant baselines remain at the last meaningful physical observation. Recovery observation timing and dormant wake baselines still need separate policy. Physical evidence and performance acceptance remain pending.

Defence initial movement and arrival use three-dimensional distance; holding additionally requires the destination height within 1.5 m. Horizontal proximity on another storey cannot establish a held defence slot. Existing owner/generation guards and bounded route refresh remain. Physical raised-position defence, routing and cleanup acceptance remain pending.

Garrison records every issued native movement destination with group, generation and owner epoch. Release recalls MOVE only when the live three-dimensional destination matches that receipt within 0.25 m; newer MOVE/FOLLOW is preserved while owned PATH cleanup stays separate. Receipts are retired on release. Continuation command fencing and owner-migration adoption still need completion; physical release tests remain pending.

Garrison continuation movement gates now compare current MOVE against the retained exact group/generation/epoch destination receipt and reject FOLLOW. Door-triggered movement, arrival holds and bounded retries therefore yield to a different individual MOVE/FOLLOW. Initial admission, migration adoption and post-yield assignment cleanup remain separate unfinished work; physical interruption tests remain pending.

Garrison release accepts an optional third argument containing actor objects; an empty list retains whole-group release. The existing owner-local decision job detects individually replaced MOVE/FOLLOW against exact garrison receipts and releases only affected actors with formation recall disabled. Their owned PATH locks, handlers and assignments retire; other actors and the group order remain. Example: `[_group,false,[_soldier]] call WAIT_fnc_CortexGarrisonRelease;`. Migration adoption, native service-task reconciliation and physical partial handover remain pending.

After actor-scoped garrison release, the group order remains only while at least one member retains a garrison assignment. Releasing the final assignment retires the published order, candidates and applied marker so subsequent group decisions can use ordinary behaviour. Remaining defenders retain their assignments. Physical final-actor handover and repeat/locality tests remain pending.

The existing garrison actor reconciliation also yields assignments to native boarding, service, medical, carry and assembly tasks. It invokes subset release without movement recall. Owned PATH and handler metadata retire; the release task guard preserves task-owned posture/watch/speed. No replacement command or extra scheduler is added. Physical service handover, partial occupancy and migration remain unaccepted.

Support handover compares the coordinated request contact area with the drill retained numeric believed enemy position, within the existing 75 m area. It no longer reads the live target object location for this match. Missing/malformed belief declines handover of a live-target drill; target liveness, movement ownership and finite delivery guards remain. Hidden-target movement, stale contact and independent subcontact coordination remain physically unaccepted.

Coordinated attack dispatch now carries the requester confirmed-contact time on the shared serverTime clock to server and helper owner. Both require it within the existing 60-second window; delivery and HC migration do not refresh it. Discovery position-only receipts still permit provisional eligibility, but attack execution requires timestamped contact. The internal SupportAssaultServer fourth argument is required for execution; its default -1 declines unknown age. This uses the existing lastSeen confirmation, not exact native per-target age/error provenance; those and ongoing contact refresh remain open. Physical delayed-delivery/migration tests remain pending.

Confirmed-contact freshness gates new attack authorization, while an exact already executing assault token may continue or adopt ownership under its unchanged finite lease. This requires matching published active/assaulting status plus local assault state or explicit owner adoption; a provisional rally cannot use it. No confirmation time or expiry is refreshed. Ongoing contact-loss and physical HC continuation acceptance remain open.

Owner-local artillery shots require a combat-effective operating gunner at preflight and immediately before doArtilleryFire. The final boundary also requires the same gunner, local battery, current mission token and group eligibility after safety/ammunition checks. Changed or incapacitated operators reject rather than receive the command. Physical medical/operator replacement and support/smoke/counter-battery fire remain unaccepted.

Assigned artillery observers must be visible and simulation-enabled before producing a fix or receiving binocular/watch commands. Dormant observers return no observation; this does not establish counter-battery acquisition or physical fire acceptance. Counter-battery radar/visual qualification is implemented by the later changes below; audio localization, report-age provenance and physical effects remain unresolved.

Explicit counter-battery observer requests scan at most four cached observers per scheduler step and expire fifteen seconds after admission. Each step cancels on pause, inactive WAIT or disabled counter-battery, and each observer must retain its group feature gate before observation commands. This finite legacy observation path is not yet connected to automatic emission acquisition; detector provenance and qualified relocation remain open.

Convoy follower speed smoothing now extends to the safe lower spacing boundary while the predecessor moves above 2 km/h. The existing closing cap still overrides smoothing, and stopped/reversing predecessors retain immediate braking. This removes the requested-gap discontinuity in smoothing without granting extra compression clearance. Mixed tracked startup, spacing and restart remain physically unaccepted.

When clearance replaces lane members and no physically entered member survives, that lane restarts admission at its retained first route room. It clears inherited entry and previous-room state without erasing shared coverage, rebuilding routes or extending the deadline. A physically entered survivor retains its current lane progress. Whole-pair casualty replacement and coherent physical join-up remain unaccepted pending separate normal/HC audits.

Combined-arms opportunity dispatch preserves the supplied visual-contact age in its observation timestamp. Nonfinite, negative-age, missing-time and future-time observations reject before asset selection; delayed delivery cannot reset the original observation age. The separate ground-fire, ground-manoeuvre and aircraft roles remain partial: live effects, multi-contact allocation, physical migration and performance acceptance are pending.

Combined ground direct-fire and manoeuvre-arrival fire commands require visible, simulation-enabled platform and gunner as well as the existing combat-effective/local/authority/ROE gates. Dormant assets cannot receive those commands. This guard does not establish operator-station ammunition compatibility or real suppression/destruction; those remain open with physical acceptance.

Combined ground fire now rereads the selected gunner seat, current station weapons and loaded turret magazines at both immediate and arrival fire boundaries. A damaging magazine must have rounds, belong to that exact turret and be compatible with an exposed station weapon; ammunition on another station does not qualify. NO_STATION_AMMO rejects the fire command. The read-only check creates no scheduler or movement owner. Engine weapon choice, multi-turret edge cases and physical effects remain unaccepted.

Counter-battery retargeting no longer consumes the global firing-event position. Observer-backed missions use the current owner-local spotter query/report path between bursts. Missions without a spotter may update relocation from a side-specific radar-qualified emission no more than 120 seconds old. The later acquisition repair below adds radar/visual qualification; audio localization, report-age provenance and physical fire acceptance remain unresolved.

Automatic counter-battery acquisition now requires registered same-side radar coverage for an emission-coordinate mission. The firing event also schedules one delayed observer wakeup per event cooldown; current server/headless owners scan cached assigned observers in finite four-actor slices. Only fresh native visual knowledge, visibility, transmission and observer readiness can produce a non-radar fix through the existing authenticated fire request. The event provides identity, not actionable coordinates, to that path. No new movement writer or global observer scan is added. Audio-only localization, delivery-age provenance, normal/HC physical fire and matched performance remain incomplete.

Initial observer-backed counter-battery requests carry native last-seen time converted to server time; admission rejects missing, nonfinite, future or older-than-ten-second observations before battery selection/reservation. CortexArtilleryFire argument 10 is the observation timestamp (default -1). Legacy calls with a local spotter may derive its native last-seen timestamp; remote spotter callers must supply it. SUPPORT, radar and DANGER calls retain their existing arguments. Network/locality age handling remains physically unaccepted.

Each ranging observer reply now transports native last-seen time as CortexArtilleryReport argument 5 (default -1). A fix update requires the expected/current owner and mission phase, an active visible combat-effective observer, finite coordinates and nonnegative finite error, and an observation no older than ten seconds or more than one second in the future. Invalid fixes do not overwrite the existing mission estimate; the existing finite sequence proceeds without a new correction. Physical delayed-report, owner migration and ranging effects remain unaccepted.

Combined air discovery, owner-side asset resolution and fallback revalidation require the aircraft pilot's group, matching AirAttackOperationStart. Separate commander or passenger groups cannot reserve flight authority. The aircraft and pilot group must still be local at startup; cross-owner crew migration remains subject to refusal and requires live validation. Ground commander/driver eligibility remains unchanged.

Garrison deferred entrance-anchor recovery restores its topology cache from the queued job payload. Alternate-entrance and interior reassignment callbacks no longer rely on the initial apply function's expired private scope. Physical recovery acceptance remains pending.

Garrison building assignments capture their world transform. Initial owner adoption, deferred approach/reassignment and the existing held-state group tick invalidate changed or deleted building bindings through actor-subset release. Stale candidate slots are excluded from recovery. Unaffected actors retain their posts; explicit inPlace holds remain unbound. No new monitor or automatic re-garrison is introduced. Physical relocation/deletion and HC migration acceptance remain pending.

CQB exterior observation retries prefer real exits not yet attempted by that actor before repeating an exit. Existing assignment coverage and distance rank candidates within that preference. The three-search cap, one-search callback budget and original deadline remain unchanged. Exit history is replayed through the existing transform-bound migration journal; older rows without history remain readable. Physical multi-exit isolation and HC replay acceptance remain pending.

Terminal CQB route evidence includes each exterior actor's attempted exits after its stage and search count. Existing evidence indices remain unchanged. This records finite recovery choices without adding geometry queries or claiming physical isolation.

Convoy audit timing rows retain their original eight fields and append local controller evidence: follower limit/timestamp, lead limit/timestamp, last progress time, recovery count, retained native and steering targets, and steering mode. Remote owner state is explicitly unavailable. Sampling remains within the existing finite audit window and does not change driving or acceptance thresholds.

Garrison owner adoption preserves exhausted-route failure flags and does not restart those positions. Fresh explicit garrison orders still clear old assignments through release before admitting new routes. This prevents locality migration from renewing a failed position's recovery budget. Physical inaccessible-position and repeated-HC acceptance remain pending.

Explicit garrison orders publish one 240-second server-time approach deadline. Owner adoption reuses it; pending assignments after expiry are marked failed without another movement request. Arrived posts remain held. Full release or retirement of the last assignment clears the deadline; a new explicit order creates a fresh one. Legacy orders without a deadline initialize it once. Physical repeated-HC deadline acceptance remains pending.

Garrison approach speed restoration metadata is public on the actor. Owner adoption preserves the original forced speed instead of saving the current WAIT cap as the original. Release clears both published values and still restores only an unchanged applied cap. Physical HC transfer and newer-controller speed acceptance remain pending.

Expired garrison adoption restores an unchanged published approach-speed lease before marking a locally owned AI route failed. It uses the existing actor-authority gate and preserves newer speed caps. This closes the adoption path that bypasses ordinary callback failure cleanup; physical HC expiry acceptance remains pending.

A garrison approach job with no pending routes and every surviving assigned actor marked failed publishes INCOMPLETE / ALL_ROUTES_FAILED with bounded actor-position/assignment evidence before normal release. Successful or unresolved assigned actors prevent this full-failure retirement. New explicit orders clear the previous result; release preserves it for diagnosis. Physical wholly inaccessible-building acceptance remains pending.

Garrison approach records the applied UP stance as an actor-public lease. Release restores the saved original stance only while the current stance still matches that lease and existing actor/external-owner guards permit restoration. Duck restoration remains separately guarded; release clears both applied stance records. Physical repeated-order and HC stance acceptance remain pending.

Garrison surplus actors now retain EXTERIOR_PENDING assignments rather than native formation slots. The existing job searches one actor per callback, at most three times per actor, and keeps the original deadline. It ranks real exits by attempt history, existing coverage and distance, validates exterior geometry and observation separately from cover, then commits a distinct direct route. Arrival holds watch the selected exit approach; exterior failure cannot reassign an interior slot. Actor-public attempts and assignment purpose support owner adoption; release retires them. Physically inaccessible or exhausted selection remains failed, not accepted security. Live overflow isolation, HC adoption and runtime cost remain pending.

Garrison exterior selection builds its reservation and exit-use maps in one squad pass instead of scanning the squad for every exit. Failed or combat-ineffective assignments do not count as live coverage or reserve destinations. Shared geometry validation still excludes physically occupied positions. This reduces selector bookkeeping without changing its one-search cadence, finite attempts or deadline; runtime overhead remains unaccepted.

Garrison exterior recovery retains up to six attempted candidate positions per actor and excludes them on later cover searches. The history is public for owner adoption and retired by release. This prevents repeated rejection of the same point on a single-exit building without adding searches, moving actors artificially or extending deadlines. Physical alternate-position recovery remains pending.

The normal building audit now includes a capacity-plus-two garrison fixture with independent physical interior/exit-observation checks, stable holding, finite search counts and real ordinary-waypoint handover. It reuses placement and room-observation validation and injects no actor relocation, door opening or completion. Large-only and transform-only focuses remain separate. This fixture is not yet run and does not establish HC or combat effectiveness.

When an exterior cover/search point fails geometry, the same finite garrison search may make one short-range engine empty-space query around a reservation-adjusted exit approach. The proposal must pass the existing exterior bounds, exit clearance, support, occupancy, separation and observation-ray checks; accepted fallback records covered=false. Three searches, original deadlines and owner-authority gates remain unchanged. No actor is moved artificially and native query success is not path evidence. Live open-ground multi-observer and cost acceptance remain pending.

The shared exterior validator optionally checks committed observer lanes in both directions: the candidate body must not occlude an existing planned view, and an existing planned body must not occlude the candidate view. Garrison passes its live reservation lanes and adjusts empty-space proposals laterally using those directions and the actor's current side. Actual object/terrain rays and endpoint separation remain required. More than 64 supplied lanes is refused; no lane is silently ignored. Physical mutual observation and runtime cost remain pending.

CQB exterior selection passes live APPROACH/ARRIVED observer lanes to the shared geometry validator. Promoted, unavailable and historical stages do not reserve a planned view. Endpoint spacing, actual visibility and finite search budgets remain independent requirements; physical isolation and migration acceptance remain pending.

CQB and garrison share BuildingExteriorProposal for one uncovered native empty-space query after a rejected observation candidate. It corrects a proposal centre once against actual reservations and planned observation directions, refuses excessive/malformed inputs and does not issue commands. CQB retains at most six attempted points across its three searches and owner migration. Covered=false is recorded for this fallback; existing geometry/arrival gates and order deadlines remain authoritative. Open-ground multi-reserve isolation, dynamic obstruction and performance acceptance remain pending.

Active CQB exterior posts now revalidate actual eye-to-watch visibility and continued physical occupation. The existing clearance callback samples at most one post ray, with a two-second actor throttle and at least three seconds of persistent failure before retirement; transient bodies do not immediately trigger movement. A failed post releases only its matching generation/epoch watch and becomes REJECTED or EXHAUSTED using the existing three-search budget and hard deadline. No new movement controller, global scan or command is added to retirement. The local sampling grace restarts on owner adoption, while public search/deadline limits remain preserved. Dynamic blockage, migration and performance acceptance remain pending.

CQB observation sampling selects the oldest due eligible post from the current eight-reserve slice; it does not repeatedly favour the first roster actor. The one-ray callback budget and two-second actor throttle remain unchanged.

CQB egress now uses one bounded native exterior proposal per admitted worker instead of a fixed three-column grid. Proposed positions avoid committed exit destinations and live reserve posts/observation lanes, then pass the shared bounds, support, occupancy, exit-clearance and visibility checks. Each actor retains a distinct movement destination and one-metre arrival hold. No valid proposal records failed consolidation and retains the actor's actual point; it never claims a shared success. Existing 45-second exit lifetime, route recovery, newer-order protection and physical participation requirements remain unchanged. Dynamic egress, casualty flow, HC replay and performance acceptance remain pending.

CQB egress now publishes a material-change journal bound to the target building, transform and original hard deadline. It retains separate actor destinations, exact owned native route legs, arrival flags, checkpoint/retry consumption and the original server-clock exit deadline. A resumed owner adopts only eligible actors whose MOVE still matches the saved leg or whose stopped physical arrival matches its destination; diverted actors remain failures. Adoption issues no movement and never resets the exit lifetime or retry count. Sampling/progress grace is local, bounded by the retained exit deadline. Older unbound diagnostic snapshots do not provide egress replay. HC physical mid-egress replay and cost acceptance remain pending.

The separate headless building batch now includes a fresh four-actor multi-storey clearance transferred while an actor is still physically inside and exiting. It requires two registered HCs, real owner adoption in EGRESS, unchanged transform/deadline/destinations, nondecreasing consumed retries, independent room participation and physical exterior arrival with COMPLETE outcome. No freeze, teleport, door assistance or receipt injection is applied. Failure to reach the mid-exit prerequisite remains a failure, not a skipped pass. This added fixture is unrun; it does not establish HC acceptance.

The HC egress fixture also returns the group through the real migration API, then issues an ordinary MOVE waypoint and requires every original actor to travel at least 20 m with leader arrival. It performs no cleanup/reset before that successor order. Owner adoption requires a fresh post-transfer building-brain timestamp, preventing the old owner's public state from passing. This fixture remains unrun.

Garrison PATH locking now requires actual physical post validation rather than a bare two-metre distance. Interior posts require 1.5 m proximity, 0.75 m floor agreement, actual building bounds and no target-building surface across the pose-to-post segment. Exterior posts require two-metre/floor proximity, an exterior pose and actual eye-to-watch visibility. Setup, expired owner adoption and queued arrival use the same transported self-contained predicate; commands still require current authority. Geometry runs only within proximity, under the existing finite approach lifetime. Repeatability and performance acceptance remain pending.

CQB egress selection now tries at most three native proposals per admitted worker, rather than one. Existing real entrances rank by committed exit use and current actor distance; other entrances precede a repeated search at the first entrance. Rejected candidate history is included in reservation adjustment and validation, with no grid/fan or authored model route. At most eight admitted workers bound this one-time selection to 24 native queries; the original 45-second exit deadline, distinct destinations and physical arrival/retry requirements remain unchanged. Each proposal records compact diagnostic evidence. Six/twelve-person physical reliability and measured runtime cost remain pending.

Pair support separation now detects a stationary partner occupying the mover's actual straight approach segment, even when endpoint spacing is sufficient. This trigger requires a target-building-clear segment through the existing shared geometry budget; it does not treat a line through a wall as a native route. Replacement support points remain physically visited, same-floor points within eight metres and clear of live reservations and the mover segment. Negative searches can reconsider changed live mover/partner poses; successful choices remain cached unless their route/coverage/reservations become invalid. The existing pair writer issues any yield; deadlines and recovery budgets are unchanged. Cross-pair/stair traffic and higher-concurrency physical acceptance remain pending.

Scoped physical evidence: normal candidate 67d29d9 passed the fresh six-person Big01 clearance, all actor participation and genuine distinct exterior exits, then post-clear holding and ordinary movement. The proposal log confirms a rejected first point followed by a successful alternative at another actual entrance. The stricter garrison overflow fixture passed physical interior/exterior posts and handover. These cases do not establish repeated, higher-concurrency, HC, combat, modded-building or performance acceptance; the full normal batch remains in progress.

BuildingExteriorCandidate retains BOOL return by default. Optional argument 8 (BOOL false) enables [BOOL, named measurement pairs] for diagnosis, with the identical acceptance gates. Active CQB reserve searches log compact cover/uncovered proposal results and distinguish no native proposal from geometry rejection. Standing geometry remains short-circuited and explicitly NOT_CHECKED when earlier gates reject; no extra geometry ray or movement query is added. Existing one-search callback, three-search actor and original deadline budgets remain unchanged. Physical isolation and runtime cost acceptance remain pending.

Exterior rejection diagnostics distinguish initial uncovered SEARCH results from actual COVER selections. Dry/slope/standing fields retain NOT_CHECKED when the original short-circuit path did not evaluate them; diagnosis never executes extra engine checks merely to fill those fields.

New CQB room claims now prioritize the lowest unfinished native room band in ASL world height. Claimed lower rooms remain unfinished until a physical visit or existing bounded failure; merely removing a claim from the pending queue cannot release upper-floor claims. The wave cache recomputes only when coverage/failure counts change and is reconstructed on owner adoption. Idle waiting pairs receive one current-position hold through the existing room-hold bookkeeping and pair writer; active native legs, specialist tasks and newer authority remain protected. Waiting creates no visits, failures, retries or deadline renewal. Existing worker capacity and follow-through participation remain unchanged. Physical multi-floor flow, headless replay and performance acceptance are pending.

Exterior native-search envelopes now preserve the supplied reservation and observation-corridor exclusions after centre correction. The query radius is capped by post spacing, the nearest committed corridor segment and the selected exit's 3-18 m band, with a small numerical margin. The native area radius is zero so it cannot enlarge that envelope. A conflicting centre or out-of-envelope native result is rejected within the existing attempt history. This adds at most one arithmetic pass over the existing 128 reservations and 64 lanes, no world scans/rays and no additional native queries. Geometry/visibility, physical arrival, inaccessible-point failure and original deadlines remain authoritative. This addresses query displacement that could undo exclusion correction; physical multi-reserve/egress, modded buildings and performance acceptance remain pending.

Interior follow-through previously used only decreasing target distance to trigger recovery at 12 seconds and retire a failed target at 24 seconds. It now additionally requires eight seconds without at least one metre of actual motion, preserving native stair/corridor detours within the original hard deadline and shared three-target recovery budget. This mirrors the existing egress motion safeguard; it neither grants visit receipts nor changes an exhausted outcome. Normal larger-case, casualty, HC replay and runtime cost remain physically unvalidated. Exact a422403 egress recount: two of 24 proposals were accepted (2:179 and 2:183); the earlier all-rejected statement has been corrected.

CQB follow-through now ranks unvisited native points by current ASL floor, live occupancy/owned destination and actual distance. A lazy callback-local snapshot contains at most eight admitted workers; subsequent commands in that callback update their reservations so later selections see them. Historical destinations without an owned MOVE do not reserve space. If every point is occupied, ranking does not fabricate a free point or silently classify a room inaccessible: ordinary finite native attempts/recovery and physical receipts remain required. This adds bounded arithmetic over at most 24 points per selecting worker, no world scan, ray or independent movement writer. Larger-case, casualty, headless and performance acceptance remain pending.

Focused normal 3cb1c9d audit 20261014-195342-594 was stopped at user request after 20 checks; no comparison completion and no recorded SQF/fatal/genuine load errors. Both exact processes were terminated and verified exited. All partial evidence remains preserved. Further audits are held by request while implementation continues. Ordinary-driving assist now excludes native service/boarding/medical/assembly tasks on both driver and effective commander at admission and final command boundaries, releasing only its exact unchanged speed lease through existing cleanup. No new controller, scan or retry is added; physical task handover and performance remain unvalidated.

Workshop-informed convoy catch-up: the locally archived Better Convoy 2801179774 lead/link speed functions separate leader pacing from nonlinear follower gap correction. WAIT retains its owner-local FSM/shared scheduler and linear normal-band control, adding only an outer-band excess-gap correction proportional to excess^1.5 and capped at 8 km/h. The existing acceleration limit, shared vehicle cruise/terrain maximum, closing cap, immediate compressed-gap braking, stopped/reversing predecessor protection and infantry safety still constrain the result. No authored speed mode, road preference, independent loop, waypoint or tight stopping band is added. This aims to restore large gaps after mixed-vehicle step-off/path acquisition; convoy gap convergence, stop/start behaviour and performance remain physically unvalidated. The archived local code is a method reference, not proof of current Workshop parity.

Convoy follower path safety now persists across spacing-only ticks. Previously curve/grade analysis limited only the refresh callback, while the next ordinary spacing calculation could raise speed before new trail geometry was considered. Each existing follower record now retains the latest path cap at field 8; legacy field 7 remains the native hold receipt. Fresh three-point trail analysis replaces the cap, including straight/level relaxation; an insufficient trail retains the known constraint. Disabling DrivingAssist clears it, and existing convoy release/reacquisition boundaries retire or retain the associated follower state. One group feature lookup replaces repeated per-follower refresh lookups. There are no new scans, rays, schedulers, path commands or public state broadcasts. This is an implementation repair; bent-route, mixed-vehicle, stop/resume, ownership migration and performance acceptance remain pending while audits are held.

Coordinated assault no longer uses the same 45/65/85 m approach radii for every engagement. Inner radius now derives from live requester-contact axis length and responder-contact distance, clamped to 45-180 m; a second radial depth adds 70 m up to 250 m, and oblique candidates scale with the inner radius. The existing six-candidate budget, actual responder origin, preserved side, 60 m endpoint separation, terrain/ballistic fire-lane checks, authority tokens and finite bound/recovery lifetimes remain in force. This expands geometry for wider engagements without a shared rally or additional discovery scan. It does not implement independent contact clustering, broad tactical command hierarchy or full large-force acceptance. Physical coordinated movement, fire support, contact separation and performance remain unvalidated; audits are held by request.

Combined-arms ground refusal contract corrected: the owner-local station preflight emitted NO_STATION_AMMO, but the server refusal whitelist omitted it. The exact authenticated reservation now retires immediately for that reason instead of holding an incapable asset until expiry. Snapshot equality, current owner authentication, accepted ground-role checks and metadata-only cleanup remain unchanged; no authored movement or other operation is cancelled. A cross-file regression contract checks all literal/direct and dynamic fire-refusal reasons emitted by the owner against the server whitelist. This resolves a protocol defect, not broad weapon-effect selection, ground fallback, suppression/destruction, subcontact planning or physical acceptance. Audits remain held by request.

Combined ground fire now checks target suitability after confirming actual loaded gunner-station ammunition. A target inside another platform is classified by that platform. Explicit CfgAmmo usage flags select infantry/vehicle/air/armour intent; allowAgainstInfantry=0 blocks infantry use. Missing flags preserve soft-target legacy rounds, require airLock for air, and require a non-AA heavy shell/rocket/missile with hit >=100 for armour, matching the existing conservative launcher fallback. Omitted target preserves the two-argument API. Direct-role refusal NO_TARGET_AMMO retires the exact authenticated reservation; manoeuvre arrival records that decision without claiming a fire effect. Native weapon selection still owns which suitable station weapon fires; these checks cannot prove damage, range, penetration, suppression or destruction. Config reference: https://community.bistudio.com/wiki/CfgAmmo . Modded config tuning, effective weapon choice, physical fire, HC/locality and performance acceptance remain pending. Audits remain held.

Ground combined-arms refusals now advance a shared pool of at most 32 already-ranked asset/group pairs. Exact authenticated retirement precedes fallback; a per-group token/role consumption receipt rejects duplicate notices. The cursor never rescans discovery, resets on rejection or extends the original opportunity. Current asset commander/driver ownership, requester/candidate eligibility, feature gates, convoy exclusion, communications, target protection, believed-position tolerance and absence of any other live role are revalidated. One replacement receives the same ground role/context and must pass its owner-local loaded-station/target suitability preflight. Each replacement expires under the original clock while preserving terminal outcomes. Existing manoeuvre roles remain independent; the fallback does not replan their routes or claim complete suppression/destruction, ground effect selection or cross-arm fire-lane acceptance. Audits are held; physical refusal replacement, competing contacts, HC migration and performance remain unvalidated.

Garrison suppression posture is limited to available stationary actors. Immediate duck and delayed recovery both yield to native MOVE/FOLLOW, medical/boarding/service/assembly commands, mounted or remote control and typed actor movement reservations. Already-prone actors are not raised. Recovery uses the immediate pre-duck stance only while the same group, generation, owner epoch, full assignment, expiry token and applied stance remain valid; it does not restore a pre-garrison stance over a newer task. Default epoch zero matches explicit garrison movement receipts before group scheduling begins. General native/danger reactions remain available during approach. Offline regression and packaging checks pass; live incoming-fire, changed assignment, interrupted movement and headless ownership migration remain unverified while audits are paused.

Garrison hit/suppression posture checks also compare the assigned building against its current position, direction and up vector before ducking and before delayed recovery. A moved, rotated or deleted post cannot retain posture authority merely because its stored assignment is unchanged. Assignments without a building-transform receipt retain the documented legacy path. Physical Zeus movement/deletion during incoming fire remains unverified.

Morale bounds native suppression samples to0..1 before averaging. A local unavailable/disabled sample (-1) contributes zero pressure, never a morale bonus. Script-set values above one cannot exceed the existing20% suppression contribution. No skill penalty, synthetic hearing pressure or additional scan is added. Live disabled-suppression and mixed-pressure cases remain unverified.

Anti-armour selection, grenade-evasion probability and smoke candidate ranking also bound suppression arithmetic to0..1. Unavailable/disabled suppression cannot improve a gunner rank or grant a grenade-reaction bonus. Smoke task admission uses the shared typed reservation predicate; unknown or malformed movement leases remain reserved. Existing hazard thresholds, skill-based probability, ammunition, native-task and fire-safety rules remain. Physical selection/evasion and concurrent reserved-task cases remain unverified.

Queued danger-smoke release and each bounded aiming retry recheck the same strict actor movement reservation used in selection. A new, unknown or malformed lease cancels the throw before facing or weapon commands; a stale local expiry shortcut cannot grant release authority. Existing throw generation, operation/owner epoch, contact, ammunition and native-task guards remain. Live next-frame reservation takeover remains unverified.

Flank, advance and assault casualty replacement uses the shared strict actor reservation predicate before changing its fire-team roster. Unknown or malformed reservations remain owned; only local actors with empty or fully typed expired leases qualify. Existing specialist/native task exclusions still apply. Concurrent casualty replacement and actor-task takeover remain physically unverified.

Coordinated support rechecks strict local actor reservations both before forming moving fire teams and before stopping covering actors. Unknown or malformed leases do not authorize either command. Server eligibility remains provisional; the current owner can refuse execution. Live bound/cover task takeover and cross-owner coordination remain unverified.

Grenade evasion preserves unknown or malformed actor reservations at admission. Its delayed regroup retires only the exact issued lease, including destination and deadline; a nearby replacement destination is not the original lease. Existing drill, native-task, route, generation and locality safeguards remain. Live evasion/replacement and migration acceptance remain outstanding.

Ordinary driver casualty replacement excludes reserved candidates and rechecks the same strict actor reservation before dead-driver ejection and internal seat switching. A newer actor reservation cancels the finite attempt without clearing that reservation. Existing route, seat, native-command and owner receipts remain required. Physical casualty replacement, task takeover and migration remain unverified.

Combat gunner-loss recovery preserves the commander's actor reservation, direct remote-control ownership and specialist controller before assigning or requesting a gunner seat. Rejection records ACTOR_OWNERSHIP without clearing another task. This remains distinct from ordinary driver replacement; successful physical seat transfer and casualty recovery remain unverified.

Airborne DROP rechecks live pilot and effective-commander readiness, player/remote control and external takeover before each passenger exit. Parachute exit also preserves the passenger's actor reservation and specialist ownership before changing damage permission or leaving the aircraft. Already-started exit callbacks retain their existing cleanup. Damage-protection overlap and mid-exit locality continuation remain unresolved; physical takeover/exit acceptance is outstanding.

Pending airborne selection skips unavailable passengers rather than repeatedly retrying the first refused actor. Eligible squad members may continue; skipped actors stay aboard. LAND still requires actual touchdown of the living squad and retains its deadline, so a partial drop is not reported as complete.

Airborne insertions retain a group/serial/owner-epoch episode on the job, passenger group and aircraft. Steps lacking the current group episode or owner epoch do no work; an aircraft episode replacement retires only the old group episode. Cleanup clears aircraft drop state only when its episode still matches. This prevents stale-job cleanup but is not cross-owner shared-aircraft admission arbitration. Live replacement/migration remains unverified.

For focused owner-local entry diagnostics, set the group variable WAIT_Cortex_ClearCaptureEntry to true before clearance. Entry samples retain generation/epoch, actor/lane/mover identity, intended destination, physical ASL pose, native expected destination/command, speed and physical-entry status. Capture is off by default, limited to256 records and16 actors per job at2s per actor, and performs no geometry scan, network replay or movement write. Instrumented cases are not performance-budget evidence; diagnostic records do not prove path reachability or clearance.

Clearance preserves an unchanged exact-owned MOVE request even when native unitReady becomes true. Readiness still governs physical handoffs; it no longer authorizes per-callback destination reissue. Existing finite no-progress retry timing remains responsible for refreshing that path. Entry diagnostics include native readiness to distinguish this state. Physical effects on entry stalls and responsiveness remain unverified.

The same CQB no-reissue rule also covers an ended native command only while its retained destination exactly matches WAIT's unchanged committed destination. New/changed destinations remain distinct requests. This does not broaden movement ownership to empty commands: only the initial writer coalesces that duplicate; existing timed recovery and handoff authority remain unchanged. Physical stall/route responsiveness remains unverified.

CQB buddy separation and room-mover progress use separate decision flags. A support actor can yield a blocking position without resetting the assaulter's no-progress clock or motion baseline. New room requests and measured improvement retain their existing timing effects; finite stuck recovery remains available even while the buddy adjusts. Physical congestion/straggler effects remain unverified.

Parachute exit applies inherited chute velocity only after the soldier actually occupies the created chute. Failed boarding deletes only that newly created chute when it remains local and empty; an occupied or transferred chute is preserved. Existing damage restoration still runs. This prevents an abandoned moving object, but does not establish successful deployment or solve damage-protection overlap and mid-exit locality continuation. Physical failed-boarding acceptance remains outstanding.

Ordinary driving assistance checks both the driver and effective commander for individual movement reservations as well as native service tasks. A live, malformed or nonlocal reservation refuses new cap/recovery commands. Recovery release checks the same reservation before stopping or following the authored route; it retires its journal without clearing the actor reservation. Valid expired reservations remain eligible through the shared predicate. Physical takeover during a rear leg remains unverified.

Bypass and navigation-corridor execution apply the same strict driver/commander actor-reservation boundary in ordinary and convoy-lead modes. Acquisition, approach and fixed-path writes refuse a newly reserved seat. Release retires matching work without issuing stop/follow/route-resume over that reservation or clearing it. This guards command ownership; it does not prove that an engine fixed path already in progress has stopped after an external takeover. Live takeover and fixed-steering termination remain acceptance requirements.

Ordinary route recovery now refuses every synchronized trigger link, including one currently activated. This matches its handback contract and preserves authored trigger control throughout a finite manoeuvre. Native waypoint travel and ordinary safety sampling remain available; the change does not remove a waypoint or evaluate its condition. Physical repeating-trigger and reverse-interruption cases remain unverified.

CQB casualty reinforcement invalidates the changed lane's cached buddy-entry proposal. The next normal planner selects against current geometry and occupied destinations instead of inheriting the removed partner's proposal. The surviving actor's physical entry, room coverage, route and operation deadline remain intact. This changes target selection, not proof of native building access; replacement entry and flow still require physical acceptance.

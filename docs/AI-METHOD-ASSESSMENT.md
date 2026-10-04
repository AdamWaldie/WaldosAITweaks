# AI implementation methods

Assessment date: 4 October 2026. Installed PBOs were unpacked locally with HEMTT for inspection.
Upstream code is kept in ignored scratch storage and is excluded from WAIT packages.
No upstream source was imported into production in this pass.

LAMBS Danger and its Waypoints component are now required runtime foundations, following the
decision to build WAIT around LAMBS. The existing shared-ownership default remains; explicit
WAIT-only settings remain available for legacy/manual diagnostics. This dependency does not prove
that every inherited WAIT movement path composes correctly with LAMBS. Those paths still require
ownership and behavior acceptance. The [upstream license](https://github.com/nk3nny/LambsDanger/blob/master/LICENSE)
restricts derivative Workshop redistribution, so WAIT neither bundles nor rewrites upstream code.

## Findings from installed code

| Source | Observed implementation | WAIT decision |
| --- | --- | --- |
| LAMBS Danger `config.cpp`, `scripts/lambs_danger.fsm`, `XEH_postInit.sqf` | Soldier and civilian `fsmDanger` overrides, a danger-cause queue, infantry evaluation via `brain`, and contact/assessment/reinforcement events | Design the original fallback around observed danger events and finite intent. Keep LAMBS ownership and its public task backend when installed. A global danger-FSM replacement needs dedicated compatibility testing |
| LAMBS Turrets `config.cpp` | Brain turret angular error plus machine-gun and cannon AI dispersion/burst config | Separate immutable addon config policy from runtime crew skills. Current WAIT crew coefficients remain the runtime fallback. A faithful config-level replacement has not been implemented |
| LAMBS Suppression `config.cpp` | Brain suppression decay, explosion weight and aim stabilization config | Config changes can avoid repeated script work, but affect all inheriting actors and cannot obey a runtime feature checkbox. Treat a config component as separately selectable and test its interaction with external suppression mods |
| LAMBS RPG `config.cpp` | Launcher firing-mode dispersion, rate/range policy and ammo changes | Keep live ammunition/backblast checks in WAIT. Assess original config policy for target opportunity and cadence without changing player projectile accuracy inadvertently |
| HBQ `functions/fn_driveAssist.sqf` | Owner-local driver helper, adaptive precision/ray count, player-driver pause, collision and obstacle assistance, public pause variables and recovery facilities | Reuse concepts of sparse progress observations and obstacle-aware pacing. Keep physical obstructions meaningful. Teleport, repair, unflip and collision immunity are excluded from WAIT recovery |
| Protocol Combat Pairs `functions/fn_pairs.sqf` | Alternating individual movement/suppression and stance changes; an unbounded `while {true}` scans `allGroups` with no sleep in the installed script | Preserve the tactical idea through the shared scheduler and committed movement intent. Do not reproduce its global loop or continually replace destinations. Installation requires exclusive movement ownership |
| Simple Civilian Behaviour `XEH_preInit.sqf` | FiredNear/Hit reactions and flee destinations | Event-driven owner-local reactions fit the standalone fallback. Preserve external civilian ownership when this addon runs |

The Protocol loop is an important counterexample: a mod that appears tactically useful can still
use an execution method that is unsuitable for the agreed performance budget. The mod transition
allows better integration points; it does not justify adding another persistent controller per unit.

## Work already present and work still open

WAIT already contains infantry movement/reactions, pair/fire-team roles, casualty reinforcement,
vehicle and aircraft operations, civilian fleeing, airborne/naval operations and artillery support.
These implementations are inherited from the AI pass and remain partially accepted. Compatibility
detection and documented inspiration must not be counted as complete reproduction of an upstream mod.

The following conversion sequence keeps the existing feature flags and public intent:

1. Establish packaged multiplayer evidence and exact-build performance comparisons.
2. Remove overlapping movement authority and idle barriers across current combined-arms operations.
   Contact, casualty and order changes update finite intent; grenade animation completion cannot
   become a prerequisite for the entire squad to continue moving.
3. Introduce engine-danger integration for the fallback only after ownership, Zeus interruption and
   restored native behavior pass. Keep expensive building/route decisions queued and cached.
4. Develop building traversal using model-specific topology evidence: entrance, room, floor and exit
   progression. Use different building models and squad sizes, with reinforcements after casualties.
5. Tune air operations against actual weapon capability and native release behavior. Validate guns,
   unguided rockets, guided weapons and bombs separately across range, altitude and terrain relief.
6. Add separately scoped config components where the script-pack limitations previously prevented
   engine-policy changes. Document static versus runtime gating for every such component.

IMS and WebKnight specialist combat remain compatibility-only. They keep control of their actors,
animations and melee. CBA and ZEN are required infrastructure. VCOM, LAMBS and the other requested
AI mods receive explicit movement arbitration during coexistence and original WAIT alternatives
where useful methods can be implemented safely. Each remaining Workshop assessment needs its own
source evidence and acceptance record; this pass does not certify every requested mod.

## Acceptance

The feature registry currently has 63 mapped cases and 14 required variant categories. All feature
cases remain `implemented_partial`. Test wiring, config parsing and successful PBO signing are build
evidence only. Physical movement, firing, casualty continuation, state transitions, Zeus handover,
locality/JIP and frame-time measurements remain the decisive acceptance evidence.

The finite tactical FSM now submits calculations to the shared scheduler. It has no allocating
token lookup in a per-frame condition. Duplicate starts return at function scope. This is a concrete
performance/ownership correction; its live impact has not been measured yet.

See [modding and operations](MODDING-AND-OPERATIONS.md) for primary references and the packaged
test/release procedure. Installed-source fingerprints are recorded in `inspected-mod-sources.json`.

## Extended installed-source assessment

All additional local AI reference candidates are in scope. The following is a first source pass,
not a complete addon audit. Classification applies to the identified method, not the whole mod.
Useful means a method worth implementing independently; repair means a verified source problem;
conflict means incompatible with WAIT's physical movement or ownership requirements; pending means
the behavior has not been inspected deeply enough. No upstream files below are release content.

| Source and evidence | Classification | WAIT action |
| --- | --- | --- |
| Pinned Down Combat Suppression, `functions/fn_postInit.sqf`: optional close-fire event bridge, support-aware hearing exception | Useful; full suppression path pending | Keep sound reports distinct from physical suppression; support elements must not stop because distant shots are heard |
| Pinned Down Surrender, `functions/fn_postInit.sqf`: one-second `allGroups` evaluation plus separate prisoner jobs | Requires changes | Evaluate changed local groups through WAIT's shared budget; prisoner behavior must be finite and subordinate to Zeus |
| Pinned Down Medical Solution, `XEH_postInit.sqf`: several watched-unit PFHs; initial machine gate excludes headless clients | Requires changes; HC ownership risk | Assess local treatment jobs and ACE integration separately; do not import damage shields or repeated animation overrides |
| Pinned Down Steel Rain, `XEH_postInit.sqf`: initialization follows CBA settings-ready event | Useful; strike execution pending | Use readiness events, not guessed startup delays; preserve lethal-only first-burst red-smoke warning |
| Pinned Down Cover and Concealment, `functions/fn_processGroups.sqf`: four-group round-robin slice | Useful | Retain staggered local processing and cache cover geometry; measure single-job worst-case cost as well as slice count |
| Pinned Down Tracks and Boots, `fn_registerJob.sqf`, `fn_releaseJob.sqf`, `fn_commandPassengerLocal.sqf`: public transport job, assigned seats, hidden exits and position jumps | Useful ownership; conflicting recovery | WAIT now respects the active transport job on occupied/assigned vehicles. Do not reproduce hidden exits or micro-teleports |
| Pinned Down Combat Awareness, `fn_postInit.sqf`, `fn_hearGunfire.sqf`: class Fired handlers, firing-group cooldown, group-owner knowledge | Useful; full cost pending | Consider vehicle fire and integral suppressors. Keep uncertain WAIT reports; do not grant exact targets from sound |
| Pinned Down Conductor, `fn_inspectGroupOwnership.sqf`, `fn_createSupportLease.sqf`, release functions: active leases and explicit garrison markers | Useful; borrowing policy differs | WAIT now yields to live Conductor leases/garrisons. Do not borrow or restore over newer Zeus orders |
| Smart Merge AI, `fn_tick.sqf`, `fn_abortPending.sqf`: bounded queues, time budget and explicit pending movement | Useful; total-budget accounting needs review | WAIT now yields to owned pending merges. Preserve player/mission group identity; casualty reinforcement is not an unconditional merge |
| Smart Aircraft AI, `XEH_postInit.sqf`, `fn_main.sqf`: server-only startup, weapon-specific distance defaults and AA cache | Useful ranges; owner model requires changes | Ground/air weapon capability and observed threat drive attack selection. Keep flight decisions on aircraft owner, not server-only |
| Smart Combat AI V2, `fn_getFeatureOwner.sqf`, `fn_registerUnit.sqf`: feature ownership resolver and actor registry | Useful; full runtime pending | Feature-level authority is preferable to blanket addon disable. Detection alone is not a completed coexistence adapter |
| AI Helicopter Decelerate No Climbing, `fnc_perSecond.sqf`: locality/player checks, terrain-ahead probes, temporary frame correction | Useful safety checks; controller conflict | Reuse independent safety concepts; one flight correction owner only. Preserve terrain clearance and native recovery |
| BHL AI, `fn_landingLogic.sqf`: glideslope, waypoint/locality abort, direct PATH/physics takeover | Useful approach geometry; conflicting permanent-style takeover risk | Keep abort and go-around concepts; do not stack velocity controllers over native flight or LAMBS |
| DiGii AI, `digii_ai_manager/functions/fnc_managerTick.sqf`: one local scheduler, due-group slices and LOD cadence | Useful | Build on WAIT's existing scheduler instead of adding another. Slice limits do not bound the work inside one group |
| AI Culler, `fn_mainLoop.sqf`: global unit scans, disabled simulation and restoration for dead/mounted units | Performance reference; conflicts with behavior acceptance | Do not count culled units as successful movement or silently enable their simulation. Separate culling from tactical AI benchmarking |
| Scorpions Advanced AI, `saai_air/fn_airAttackSafety.sqf`, `fn_airAimSolution.sqf`: speed/munition safety geometry and predictive release authorization | Useful; native firing outcome pending | Examine weapon direction, moving target and parent velocity; never bend projectiles or treat authorization as a hit |
| Protocol Navy Seal, `fn_navy_seal.sqf`: shallow-water predicate requires depth both >= 0.1 and <= 0.1 | Repair: effectively exact-depth shoreline selection | Implement a non-zero safe depth interval in WAIT and validate terrain/slope/access. Do not copy the equality constraint |
| Protocol CQB, `fn_cqb.sqf`: enemy-near-building test uses distance rather than room/floor containment | Requires changes | Proximity cannot prove an enemy is inside; use real building/topology evidence before committing the entry team |

The other Protocol sources have been extracted; initial config/settings inspection is not yet
sufficient for algorithm acceptance. Battle Lines, VCOM and the exact IMS DEV package still need
their source evidence completed. Every reference remains eligible for further investigation;
none receives a quality exemption because its Workshop page describes a useful feature.

## Changes and queued acceptance

The compatibility map now identifies the installed Pinned Down and additional AI reference families.
Read-only operation markers protect Conductor support/garrisons, Tracks and Boots transports and
Smart Merge pending movement. Both ground and aircraft permission checks consume the actor gate;
aircraft also honor their own generic external-control flag. Detection of the other packages is
diagnostic only and does not assert complete interoperability.

Queue one packaged batch covering ordinary AI with addons merely loaded; active external operations;
release/reacquisition; assigned but dismounted cargo; Zeus replacement; HC transfer; deletion; and
setting changes. Require physical progress and exact external-marker preservation. Benchmark 50
mixed groups against the same LAMBS-only dependency baseline, with WAIT off/on, using the agreed
5% median / 10% p95 added frame-time budget. Retain a separate vanilla baseline to show the total
cost of the complete dependency stack. No game was launched for this source pass.

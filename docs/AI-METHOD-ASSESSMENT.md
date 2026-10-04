# AI implementation methods

Assessment date: 4 October 2026. Installed PBOs were unpacked locally with HEMTT for inspection.
Upstream code is kept in ignored scratch storage and is excluded from WAIT packages.
No upstream source was imported into production in this pass.

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

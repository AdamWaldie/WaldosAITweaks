# Delivery goal

## Product outcome

Deliver a standalone Arma 3 AI addon that improves AI combat without taking control away from Zeus,
players, mission makers, specialist systems or native engine behaviour that is already working. The
addon must make AI more decisive, tactically useful and resilient while keeping its CPU cost bounded.

The release candidate is successful only when it provides the following in real multiplayer play:

- AI responds promptly to confirmed danger, maintains an intention while moving and stops only for a
  meaningful tactical reason.
- Infantry can advance, flank, support, assault, withdraw, recover from losses and hand over to a
  newer Zeus or mission order without movement churn, rally loops or abandoned state.
- Nearby groups coordinate through short-lived opportunities: one group can support while another
  manoeuvres, but every group retains its own route, safety sector and ownership.
- Buildings are entered and cleared through physically reachable positions. A blocked route is
  reported as incomplete; it is never fabricated as complete.
- Vehicles drive safely as ordinary units, while registered convoys stay single file, preserve
  operational passengers, recognise real roadblocks and recover only through physical actions.
- Aircraft choose only attacks their loaded weapons and flight geometry can support, conduct a
  credible ingress, release and egress, and yield immediately to a player, Zeus, landing or another
  valid flight owner.
- Support features, casualty handling and compatibility handovers use the same finite operation
  lifecycle and do not create a second movement owner.
- All work is locality-aware, headless-client safe, JIP-safe and visible in diagnostics.

## Non-negotiable operating rules

1. **One movement owner.** Every operation records its owner, generation, participants, route,
   physical progress and cancellation reason. A later Zeus, player, mission or compatible specialist
   order invalidates WAIT work before it issues another movement command.
2. **Continuous intent.** Planning may be delayed under load, but current physical movement and
   immediate danger response are never delayed behind a scheduled rally, grenade animation or an
   unreachable straggler.
3. **Physical recovery only.** Recovery may wait, refresh a route, reverse cautiously or select a
   local alternative. It cannot teleport, repair, unflip, disable collision or bypass a meaningful
   player roadblock.
4. **Bounded cost.** Event handlers collect small observations; the shared owner-local scheduler
   performs bounded work. No global per-frame scans, permanent per-unit movement loops or repeated
   destination issuance.
5. **Evidence before promotion.** A configuration flag, queued job, accepted order or static test
   never proves behaviour. Promotion requires the exact packaged candidate to pass physical audit
   cases.

## Work packages and exit criteria

| Package | It is complete only when… | Current position |
| --- | --- | --- |
| 1. Core danger and lifecycle | The owner-local danger FSM, operation lifecycle and scheduler preserve native knowledge, react within the configured cadence, release cleanly on ownership change and show bounded diagnostics. | Implemented; static/package checked; physical reaction, interruption and performance cases pending. |
| 2. Infantry tactics | Advance, bounds, flank, assault, withdrawal, surrender and recovery maintain progress with casualties and stuck actors, preserve fire lanes and hand off instantly to Zeus/new orders. | Partly repaired; static checks only; live manoeuvre, casualty and interruption acceptance pending. |
| 3. CQB and garrison | AI enters, traverses, clears or holds reachable building positions across models and squad sizes, rotates survivors and explicitly reports unreachable rooms. | Native ownership corrected; topology and physical building acceptance pending. |
| 4. Driving and convoys | General driving and registered convoy logic are separately configurable, use native routes, preserve a single-file column, classify stops and respect roadblocks, passengers and external owners. | Convoy repairs exist; general driving and all terrain/obstruction acceptance pending. |
| 5. Aircraft, vehicles and support | Capability-valid weapon selection, attack geometry, countermeasures, air-to-air response, artillery warnings, medical help and delivery operations produce real outcomes without competing flight or movement owners. | Design and partial implementation exist; physical weapon, target-effect and handover acceptance pending. |
| 6. Coordination and compatibility | Nearby groups form useful, temporary supporting/manoeuvring relationships without compacting onto one point; affected specialist actors hand over immediately and ordinary actors remain eligible. | Ownership boundaries exist; coexistence acceptance pending. |
| 7. Multiplayer and performance | JIP, locality transfer, headless ownership and server-enforced settings remain correct. Matched 50-group baseline comparisons remain within 5% median and 10% p95 frame-time overhead, with no growing queue or command churn. | Static safeguards exist; no physical benchmark has passed yet. |
| 8. Release evidence | The signed package exactly matches the candidate tested in four batched audits: infantry/CQB, vehicles/convoys, air/support, and compatibility/multiplayer/performance. Remaining failures are visible and block promotion. | Not started; game runs are currently paused by request. |

## Status vocabulary

- **Designed:** behaviour, ownership and acceptance rules are specified.
- **Implemented:** production code exists but has not yet cleared all checks.
- **Statically checked:** source, configuration, packaging and regression gates passed.
- **Physically accepted:** a fresh packaged dedicated-server/client audit demonstrated the required
  in-game outcome.
- **Promoted:** all required physical and performance gates for the package have passed.

No work package may skip directly from **implemented** or **statically checked** to **promoted**.

## Current execution order

1. Complete the danger FSM and common lifecycle, then prove it in a single batch when game testing
   resumes.
2. Finish infantry continuity, multi-squad coordination and CQB using that common lifecycle.
3. Consolidate driving and convoy behaviour on the shared scheduler.
4. Complete aircraft, vehicle and support operations only where capability and geometry make them
   viable.
5. Validate compatibility handovers, locality/JIP/headless behaviour and the measured performance
   budget.
6. Seal and test the release candidate in the four physical acceptance batches.

Game testing is intentionally paused until explicitly re-enabled. Static validation and package builds
continue; their results remain separate from physical acceptance.

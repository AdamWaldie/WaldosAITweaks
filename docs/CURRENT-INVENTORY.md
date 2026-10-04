# Current implementation inventory

This inventory describes the first standalone CBA foundation. It records what was extracted before
tactical tuning resumes, so growth and ownership can be measured instead of inferred.

## Size and shape

- 164 production SQF files, including CBA pre/post init and standalone support functions.
- 126 Cortex functions for tactical state, movement, support, vehicles, aircraft and compatibility.
- 38 SQF files in the retained Cortex QA suites, plus standalone mission initialization.
- About 1.14 MB of production SQF and 3.06 MB in the repository excluding Git metadata.
- One addon PBO at `addons/main`, packaged under `z\waldo_ai_tweaks` by HEMTT.

## Implemented domains

| Domain | Current implementation | Primary control |
| --- | --- | --- |
| Skill and lethality | Day/night/AUTO profiles, equipment heuristics, infantry and operating-crew dispersion, locality adoption | `Waldo_AIRebalance_*`, `Waldo_AI_*Dispersion` |
| Infantry state | Contact reporting, investigation, cover, suppression reactions, morale, retreat, surrender, regroup and calm restoration | `Waldo_AIPass_*` |
| Manoeuvre | Finite flank, advance, assault, bounding, route planning, stance and casualty reinforcement | Cortex group scheduler |
| Coordination | Support-by-fire, reinforcement, coordinated assault and combined-arms opportunity exchange | Server opportunity coordinator plus owner-local action |
| Buildings | Garrison, defend, clear, COMPAT Waypoints lease and physical progress tracking | Explicit order or enabled tactical opportunity |
| Convoys | Predecessor spacing, road look-ahead, mixed-vehicle pacing, contact halt, dismount, remount, recovery and Zeus notification | `Waldo_fnc_SimpleAiConvoy` |
| Vehicles | Passenger decisions, gunnery priorities, standoff, smoke/withdrawal and crew retention | Cortex vehicle jobs |
| Aircraft | Attack planning, weapon capability, ingress/release/egress, missile reaction, attack-run flares, landing and deceleration | Cortex aircraft jobs and landing handlers |
| Fires | Artillery roles, warning smoke, finite bursts, observation, counter-battery and shoot-and-scoot | Server mission authority plus gun owner |
| Other actors | Civilian reactions, airborne insertion and naval assault | Event-driven or finite group job |
| Operator support | Diagnostics, ZEN control and convoy module, visible QA overlays | Required ZEN and audit mission |

## Optional integrations

The code detects installed COMPAT components, external controller AI, external controller/external controller, external civilian controller, external controller
Advanced Driving AI and supported external controller packages. Integrations must use public variables or
functions, take a finite lease, and restore the exact prior state. Addon presence alone must not
disable unrelated AI.

## Known tuning and acceptance work

The extraction preserves the latest implementation but does not certify it. CQB/building traversal,
air attack geometry and weapon employment, multi-squad flow, convoy recovery, transitions, Zeus
handover and casualty continuation remain priority live-test areas. Performance acceptance is a
batched comparison against native AI at 50 mixed groups, with the agreed budget of no more than 5%
added median frame time and 10% added p95 frame time.

The public settings catalogue is registered through CBA Settings. Legacy variable names remain the
scripting interface. The packaged build, audit and signed-release promotion paths are documented in
[Modding and operations](MODDING-AND-OPERATIONS.md). Behavioural acceptance remains pending;
successful packaging and mapped coverage do not certify the inherited tactical implementations.

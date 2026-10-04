# Current implementation inventory

This inventory describes the first standalone CBA foundation. It records what was extracted before
tactical tuning resumes, so growth and ownership can be measured instead of inferred.

## Size and shape

- 160 production SQF files, including CBA pre/post init and five standalone support functions.
- 126 Cortex functions for tactical state, movement, support, vehicles, aircraft and compatibility.
- 37 SQF files in the retained Cortex QA mission.
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
| Operator support | Diagnostics, ZEN control and convoy module, visible QA overlays | Optional ZEN and audit mission |

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

The CBA settings UI is still represented by guarded missionNamespace defaults. Converting the public
settings catalogue to `CBA_fnc_addSetting`, replacing remaining remote execution with CBA events where
appropriate, and versioned multiplayer settings replay are the next packaging tasks.

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

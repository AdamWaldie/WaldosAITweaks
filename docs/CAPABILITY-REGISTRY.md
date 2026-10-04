# Capability registry

This registry consolidates existing WAIT work and newly requested capabilities. Decisions describe
implementation direction, not completed acceptance. Each subsystem retains its feature gates.

| Capability | Purpose | Decision | Mechanism |
| --- | --- | --- | --- |
| Infantry danger and contact | Immediate observation, threat response and combat handover | repair | FSM assessment plus bounded scheduled decisions |
| Suppression and fire control | Effective fire without synchronised squads or blocked manoeuvres | repair | Local firing events, fire-lane checks and sparse jobs |
| Cover and concealment | Useful firing posture and covered avenues of approach | repair | Cached bounded geometry |
| Pairs, bounds, flank and assault | Continuous physical advance with covering elements | repair | Finite intent and shared scheduler |
| Morale, surrender and withdrawal | Physical fallback and appropriate terminal surrender | repair | Changed-group assessment and finite movement |
| Buildings | Enter, progress through rooms/floors and exit with the squad | repair | Topology cache and physical progress |
| Coordination and combined arms | Communicating nearby elements exploit support opportunities | repair | Server opportunity registry and finite local roles |
| Driving and convoy | Single-file route progress, stable spacing and obstruction handling | repair | Native movement and sparse progress sampling |
| Passengers and crew | Safe task-owned dismount/remount without crew leakage | repair | Seat reservations and order generations |
| Ground gunnery | Weapon-aware engagement, appropriate precision and threat withdrawal | repair | Owner-local target decisions and optional engine policy |
| Ground and air attack | Capability-valid attack selection and real target effects | repair | Native flight/aiming with finite approach intent |
| Air defence and countermeasures | Preserve energy, clearance and physical countermeasures | repair | Incoming-threat events and finite responses |
| Landing and braking | Terrain-aware natural approach and safe go-around | retain | One flight correction owner |
| Artillery | Observed-target support, lethal-only initial warning and battery survival | retain | Authoritative requests and finite burst jobs |
| Medical assistance | Maintain squad effectiveness through local treatment | implement independently | Owner-local finite aid job; respect existing medical authority |
| Survivor reinforcement | Replenish manoeuvre elements without unconditional merging | repair | Casualty events and role replacement |
| Civilian reactions | Physical escape from perceived danger | retain | FiredNear/Hit events and finite escape |
| Airborne and naval delivery | Deploy embarked infantry safely to useful terrain | repair | Finite vehicle/passenger intent |
| Scheduling and update cadence | Bound work while retaining urgent reactions | retain | One shared owner-local budget and cached due times |
| Simulation-management methods | Reduce expensive distant simulation without invalidating gameplay | assessment pending | First quantify purpose and owner/multiplayer risks; no new culling yet |
| Recovery shortcuts | Resolve engine deadlock without erasing obstructions | assessment pending | Prefer physical retries; no newly introduced teleport or immunity |
| Specialist controller interoperability | Preserve externally owned actors and animation | compatibility-only | Read-only active ownership and finite leases |

Every family requires physical outcomes, disabled-state and transition cases, casualty and stuck-actor
continuity, Zeus replacement, cleanup, JIP/locality and measured terrain/performance. Additional
configuration and audit gaps remain. Existing cases are retained additively; none are promoted to
accepted by this assessment. Simulation shortcuts remain unimplemented pending purpose assessment.

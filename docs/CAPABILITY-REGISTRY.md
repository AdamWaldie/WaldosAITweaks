# Capability registry

This registry consolidates existing WAIT work and newly requested capabilities. Decisions describe
implementation direction, not completed acceptance. Each subsystem retains its feature gates.

| Capability | Purpose | Decision | Mechanism |
| --- | --- | --- | --- |
| Infantry danger and contact | Immediate observation, threat response and combat handover | repair | Native danger behaviour plus bounded member-event assessment FSM; one finite response context wakes the existing shared decision job; no engine danger replacement |
| Suppression and fire control | Effective fire without synchronised squads or blocked manoeuvres | repair | Local firing events, fire-lane checks and sparse jobs |
| Cover and concealment | Useful firing posture and covered avenues of approach | repair | Cached bounded geometry |
| Pairs, bounds, flank and assault | Continuous physical advance with covering elements | repair | Finite intent and shared scheduler |
| Morale, surrender and withdrawal | Physical fallback and appropriate terminal surrender | repair | Changed-group assessment and finite movement |
| Buildings | Enter, progress through rooms/floors and exit with the squad | repair | Topology cache and physical progress |
| Coordination and combined arms | Communicating nearby elements exploit support opportunities | repair | Server opportunity registry, durable support reservations and matching finite local roles |
| General vehicle driving | Safe route progress outside registered convoys without replacing native pathfinding | repair | Shared scheduler invokes a bounded owner-local terrain-grade cap every four seconds, then permits one native-route refresh, clear-rear reverse and final retry outside combat. It yields to players, Zeus, registered convoys and external driver owners; physical acceptance remains pending. |
| Registered convoys | Single-file route progress, stable spacing and individual obstruction handling | repair | Native movement and sparse progress sampling; independent convoy gates |
| Passengers and crew | Safe task-owned dismount/remount without crew leakage | repair | Seat reservations and order generations |
| Ground gunnery | Weapon-aware engagement, appropriate precision and threat withdrawal | repair | Owner-local target decisions and optional engine policy |
| Ground and air attack | Capability-valid attack selection and real target effects | repair | Native flight/aiming with finite approach intent |
| Air defence and countermeasures | Preserve energy, clearance and physical countermeasures | repair | Incoming-threat events and finite responses |
| Landing and braking | Terrain-aware natural approach and safe go-around | retain | One flight correction owner |
| Artillery | Observed-target support, lethal-only initial warning and battery survival | retain | Authoritative requests and finite burst jobs |
| Medical assistance | Maintain squad effectiveness through local treatment | repair | One local vanilla medic receives a finite physical treatment task only during CALM or SECURITY. WAIT yields to direct ownership and specialist medical controllers; live acceptance remains pending. |
| Survivor reinforcement | Replenish manoeuvre elements without unconditional merging | repair | Casualty events and role replacement |
| Civilian reactions | Physical escape from perceived danger | retain | FiredNear/Hit events and finite escape |
| Airborne and naval delivery | Deploy embarked infantry safely to useful terrain | repair | Separate finite boat-crew and passenger intent, bound by one durable landing token |
| Scheduling and update cadence | Bound work while retaining urgent reactions | retain | One shared owner-local budget and cached due times |
| Simulation-management methods | Reduce expensive distant simulation without invalidating gameplay | assessment pending | First quantify purpose and owner/multiplayer risks; no new culling yet |
| Recovery shortcuts | Resolve engine deadlock without erasing obstructions | assessment pending | Prefer physical retries; no newly introduced teleport or immunity |
| Specialist controller interoperability | Preserve externally owned actors and animation | compatibility-only | Read-only active ownership and finite leases |

Every family requires physical outcomes, disabled-state and transition cases, casualty and stuck-actor
continuity, Zeus replacement, cleanup, JIP/locality and measured terrain/performance. Additional
configuration and audit gaps remain. Existing cases are retained additively; none are promoted to
accepted by this assessment. Simulation shortcuts remain unimplemented pending purpose assessment.

## Driving method decisions

The addon assessment separates reusable safety techniques from convoy intent. Shared geometry
should not couple participation, spacing, contact response or passenger policy between use cases.

| Method | Decision | Reason and acceptance boundary |
| --- | --- | --- |
| Locality-triggered installation | retain | Vehicle work belongs to its current owner; migration must release old work before adoption. |
| Distance-based precision and cached proximity | implement independently | Expensive geometry should run only when relevant, through the shared budget rather than permanent loops for every vehicle. |
| Road curvature and grade anticipation | repair | Convoys already sample bounded geometry; use absolute elevation for slopes. Extend the reusable sample only with independent general-driving participation. |
| Collision prediction and clear-rear checks | implement independently | Reduce collisions and permit physical recovery. Require bounded queries and preserve genuine roadblocks. |
| Navigation helper objects | exclude from initial implementation | Objects can change the engine route and erase intentional blockage; native navigation and explicit physical recovery are the initial approach. |
| Automatic gate opening | defer | Opening a gate changes mission intent. A future opt-in must distinguish access permission and preserve Zeus changes. |
| Route refresh after an artificial hold | repair | Release our own hold before a bounded retry; never replace a newer waypoint or continuously resend destinations. |
| Crew retrieval | repair | Recover only seats still owned by the operation. A dismounted squad with a new task must retain that task. |
| Teleport, automatic repair, unflip and temporary immunity | exclude from default recovery | These change physical gameplay and ambush outcomes; no adoption as an invisible stuck-vehicle workaround. |

These are implementation decisions, not measured driving acceptance. General driving has a production
controller, independent CBA controls and additive static coverage; its physical vehicle and terrain
acceptance remains pending. The existing convoy settings do not enable general driving.

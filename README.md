# Waldos AI Tweaks

Waldos AI Tweaks is a standalone CBA mod for Arma 3. Its goal is aggressive, dynamic and tactically
sound AI with bounded, locality-aware work that remains subordinate to Zeus and authored mission
orders.

## Current foundation

The repository now builds as a conventional `z\waldo_ai_tweaks\addons\main` addon:

- CBA extended pre-init loads guarded defaults on every machine;
- CBA extended post-init starts only the systems enabled for that owner;
- the established `WAIT_fnc_*` API remains available through `CfgFunctions`;
- CBA Settings owns global addon configuration and JIP synchronization;
- Native Zeus orders are included; optional ZEN supplies an extended convoy dialog;
- the standalone settings request validates the requesting curator and updates the CBA server layer;
- HEMTT owns packaging and version metadata.

Run `hemtt build` from the repository root to create the mod package. Arma 3 2.18+ and CBA_A3 are required; ZEN is optional. WAIT supplies the base-soldier danger FSM and treats another replacement of that engine slot as incompatible. No external AI addon is required or bundled.

The new function and settings API uses `WAIT_*` with no forwarding aliases. See
[API migration](docs/API-MIGRATION.md), [addon lifecycle](docs/ADDON-LIFECYCLE.md) and the
[capability registry](docs/CAPABILITY-REGISTRY.md) and the [delivery goal](docs/DELIVERY-GOAL.md).

## Product boundary

This repository owns AI behaviour:

- skill, lighting/equipment heuristics and dispersion;
- infantry contact, cover, flank, advance, assault, withdrawal, regroup, surrender and CQB;
- multi-squad and combined-arms coordination;
- convoy, passenger, vehicle gunnery and recovery behaviour;
- aircraft attack, defence, countermeasures, landing and deceleration;
- artillery support and counter-battery decisions;
- civilian, naval and airborne reactions;
- AI diagnostics, ZEN controls and the Cortex QA suite.

Mission-specific systems retain Dynamic AA, Dynamic AO, logistics, transport, paradrop, economy,
UI and their diagnostics. WAIT may mark an object, unit or group with the public
`Waldo_AI_ExternalControl` flag while another system owns its behaviour. Independent weapon systems
may set `Waldo_AI_PrecisionExclude` when they intentionally own lethality. AI Tweaks contains no
Dynamic AA or Dynamic AO implementation and does not inspect their private state.

An integrating mission must yield AI skill, convoy, landing, deceleration and Cortex ownership when
`WAIT_AI_Tweaks_Main` is present. WAIT will release its work immediately when another eligible system
records external ownership.

## Authority and Zeus

The server owns public settings and cross-group decisions, including ordered replay for JIP clients.
The current unit, group or vehicle owner
executes physical behaviour. Direct Zeus selection, editing and waypoints interrupt Cortex control;
the addon restores only state it changed. Locality changes retire stale jobs and repeat owner-local
setup.

## Validation

Static validation lives under `releaseVerificationAndDeployment`. It checks SQF structure, the addon
layout, product boundaries, feature coverage and implementation contracts. Aircraft, convoy, CQB,
performance and multiplayer locality still require the generated dedicated-server/client audit in
batched runs. Static success is not an in-engine acceptance claim.

See [the current inventory](docs/CURRENT-INVENTORY.md), [the CBA migration plan](docs/CBA-MIGRATION.md)
and [the standalone boundary](docs/EXTRACTION-BOUNDARY.md).

See [modding and operations](docs/MODDING-AND-OPERATIONS.md) for packaged local audits,
signed release promotion and the execution-method assessment.
See [matched performance validation](docs/PERFORMANCE-VALIDATION.md) for native/WAIT patrol pairs and their acceptance limits.

See [contribution and documentation requirements](CONTRIBUTING.md) and [all CBA settings](docs/SETTINGS-REFERENCE.md).

Native Zeus provides **Convoy: start / resume**, **Convoy: hold and unload passengers**, and
**Convoy: release control** under Waldos AI Tweaks. Place the order directly on a crewed AI land
vehicle; group at least two AI-driven vehicles and give the leader its route before starting.
New convoys use the CBA default speed, separation and push-through options. Resume preserves
existing convoy settings. Optional ZEN adds a dialog for per-convoy settings. Neither interface
replaces ordinary Zeus waypoints. Missions still determine which addons/modules a curator may use.

The audit launcher defaults to CBA only. Use `-WithZen` for the optional-dialog compatibility batch.
Native module placement, late Zeus assignment and both dependency variants remain queued for
physical acceptance; static validation alone does not establish those behaviours.

CBA Addon Options is split into **General**, **Skills**, **Infantry**, **Coordination**, **Vehicles**,
**Convoys**, **Aircraft**, and **Support and civilians**. Each page groups related controls and
places enable switches before tuning. Existing saved option keys and defaults are preserved.
Vehicles covers general combat and passenger decisions. Convoys covers explicitly registered
columns, their spacing, driving assistance and halt/unload rules. Convoy driving assistance does
not enable a standalone general driving controller. See the [settings reference](docs/SETTINGS-REFERENCE.md).

Current implementation, physical acceptance and progression blockers are recorded in [the completion status](docs/COMPLETION-STATUS.md).

# Waldos AI Tweaks

Waldos AI Tweaks is a standalone CBA mod for Arma 3. Its goal is aggressive, dynamic and tactically
sound AI with bounded, locality-aware work that remains subordinate to Zeus and authored mission
orders.

## Current foundation

The repository now builds as a conventional `z\waldo_ai_tweaks\addons\main` addon:

- CBA extended pre-init loads guarded defaults on every machine;
- CBA extended post-init starts only the systems enabled for that owner;
- the established `Waldo_fnc_*` API remains available through `CfgFunctions`;
- CBA Settings owns global addon configuration and JIP synchronization;
- ZEN is a required operator dependency and supplies the live control surface;
- the standalone settings request uses a CBA server event and validates the requesting curator;
- HEMTT owns packaging and version metadata.

Run `hemtt build` from the repository root to create the mod package. CBA_A3 and ZEN are hard runtime
dependencies. ACE, COMPAT, external controller AI, external controller systems, external controller and supported external controller packages are
detected only when present.

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

Waldos Mission Pack retains Dynamic AA, Dynamic AO, mission logistics, transport, paradrop, economy,
UI and its diagnostics shell. WMP may mark an object, unit or group with the public
`Waldo_AI_ExternalControl` flag while another system owns its behaviour. Independent weapon systems
may set `Waldo_AI_PrecisionExclude` when they intentionally own lethality. AI Tweaks contains no
Dynamic AA or Dynamic AO implementation and does not inspect their private state.

WMP may keep its mission-level AI skill values for missions that do not load this addon. When
`Waldo_AI_Tweaks_Main` is present, WMP must not start a second skill, convoy, landing, deceleration or
Cortex controller.

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
and [the WMP extraction boundary](docs/WMP-Extraction.md).

See [modding and operations](docs/MODDING-AND-OPERATIONS.md) for packaged local audits,
signed release promotion and the execution-method assessment.

See [contribution and documentation requirements](CONTRIBUTING.md) and [all CBA settings](docs/SETTINGS-REFERENCE.md).

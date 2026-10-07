# Waldos AI Tweaks

Waldos AI Tweaks (WAIT) is a standalone CBA mod for Arma 3 that makes AI aggressive, dynamic and
tactically sound. Its work stays bounded and locality-aware, and it always yields to Zeus and to
mission-authored orders.

## Get started

1. Load **Arma 3 2.18+**, **CBA_A3** and Waldos AI Tweaks on the server and every client. ZEN is optional.
2. Open **CBA Addon Options** and review the Waldos AI Tweaks pages: **General**, **Skills**,
   **Infantry**, **Coordination**, **Vehicles**, **Convoys**, **Aircraft** and **Support and civilians**.
   On each page the enable switches come first, then the tuning controls.
3. Play. Missions do not copy files or run an initialization script, because the addon registers its
   functions, settings and runtime entry points when it loads.

Every option, default and range is listed in the [settings reference](../SETTINGS-REFERENCE.md).

## Find the right page

| I want to… | Read |
| --- | --- |
| Understand what the mod does and what it leaves to other systems | [Overview](../../README.md) |
| Make AI squads fight, move and support each other | [WAIT Cortex](../Smart-AI-Pass.md) |
| Tune AI skill, spotting and day/night behaviour | [Waldo's AI Tuning](../Waldos-AI-Tweak.md) |
| Look up a CBA setting, its default or range | [Settings reference](../SETTINGS-REFERENCE.md) |
| Give Zeus convoy orders or hand a unit to another system | [Overview](../../README.md#authority-and-zeus) and [WAIT Cortex: orders](../Smart-AI-Pass.md#orders) |
| Integrate a mission system with WAIT | [Standalone boundary](../EXTRACTION-BOUNDARY.md) and [addon lifecycle](../ADDON-LIFECYCLE.md) |
| Migrate scripts from `Waldo_*` names | [API migration](../API-MIGRATION.md) |
| Build, test or release the mod | [Mod build, testing and architecture](../MODDING-AND-OPERATIONS.md) |
| See what is implemented and what still needs live acceptance | [Implementation progress](../IMPLEMENTATION-PROGRESS.md) and [delivery goal](../DELIVERY-GOAL.md) |

## How WAIT behaves in multiplayer

- The server owns public settings and cross-group decisions, and replays them in order for JIP clients.
- The machine that owns a unit, group or vehicle runs its physical behaviour, including on headless clients.
- When Zeus directly selects, edits or gives waypoints to a unit, that interrupts Cortex control. WAIT
  restores only the state it changed.
- Other systems take ownership through the public `Waldo_AI_ExternalControl` and
  `Waldo_AI_PrecisionExclude` flags.

## Status

Static and package validation runs on every change. Aircraft, convoy, CQB, performance and
multiplayer locality behaviour still need dedicated-server/client audit runs, and a passed static
check is not live acceptance. [Implementation progress](../IMPLEMENTATION-PROGRESS.md) lists current
evidence and outstanding retests.

## Contributing

Read the [contribution and documentation requirements](../../CONTRIBUTING.md). This wiki is
generated from the repository's `docs/` folder, so change the documentation there.

# Waldo's AI Tuning

> **Use this page when:** you need to choose and configure WAIT's day or night AI behavior adjustments.

_Associated Files: `addons/core/functions/AISkillAdjustmentSystem.sqf`; `aiRebalanceInit.sqf`; `aiApplyProfile.sqf`; `aiRebalanceStop.sqf`_

## Overview

The AI rebalance applies named, bounded skill profiles to editor, scripted and Zeus-spawned AI. It runs where each AI unit is local, so dedicated servers and headless clients remain consistent. Players are never modified.

## Set up AI tuning

Edit `addons/main/settings/aiConfig.sqf`. The shipped pack enables AI tuning with the `LINE`
profile in `AUTO` mode. WAIT waits for the server's feature settings and starts the
wrapper automatically on each machine that can own AI. Do not add a second call to
multiplayer `init.sqf` for normal setup.

| Setting in `aiConfig.sqf` | Type | Shipped default | What it controls |
| --- | --- | --- | --- |
| `WAIT_AIRebalance_Enable` | Boolean | `true` | Enables WAIT skill profiles. |
| `WAIT_AIRebalance_Profile` | String | `"LINE"` | Built-in or mission-defined profile key. |
| `WAIT_AIRebalance_Mode` | String | `"AUTO"` | Ambient-darkness/NVG-aware by default; `DAY` suppresses the extra penalty and `NIGHT` retains the legacy night tiers. |
| `WAIT_AI_ApplyMode` | String | `"BOTH"` | Existing AI, newly created AI, or both: `EXISTING`, `NEW`, `BOTH`. |
| `WAIT_AI_RestoreOnStop` | Boolean | `true` | Restore each unit's captured skills when this feature stops. |
| `WAIT_AI_SkillVariance` | Number | `0` | Stable per-unit variance; zero disables it. |
| `WAIT_AI_InfantryDispersion` | Number | `1.35` | Owner-local aim coefficient for ordinary infantry and vehicle cargo. Values above `1` widen weapon dispersion without changing detection or movement. |
| `WAIT_AI_VehicleCrewAimMultiplier` | Number | `0.6` | Final aiming-skill multiplier for ordinary operating vehicle and aircraft crew. Named Dynamic AA crews are exempt. |
| `WAIT_AI_VehicleCrewDispersion` | Number | `3.5` | Owner-local aim coefficient for ordinary ground-vehicle operating crew when external AI controller is absent. Named Dynamic AA crews retain their authored coefficient. |
| `WAIT_AI_AirCrewDispersion` | Number | `4.25` | Wider owner-local aim coefficient for ordinary helicopter and fixed-wing crew when external AI controller is absent. This reduces excessive first-burst lethality while retaining real weapon and targeting behaviour. |
| `WAIT_AI_IncludedSides` | Array of side-ID Strings | `[]` | Empty allows every side. |
| `WAIT_AI_IncludedFactions` | Array of `CfgFactionClasses` Strings | `[]` | Empty allows every faction. |
| `WAIT_AI_ExcludedFactions` | Array of `CfgFactionClasses` Strings | `[]` | Skip these factions after include filtering. |
| `WAIT_AI_ExcludedClasses` | Array of exact `CfgVehicles` Strings | `[]` | Never tune these unit classes. |
| `WAIT_AI_ProfileDisplayNames` | HashMap from profile key String to label String | Labels for the built-in profiles | Names shown in ZEN and diagnostics. Add a label for a custom profile. |

For a controlled change during play, the public call accepts two Strings and returns
a Boolean: `true` if the profile was accepted. The default arguments are `"DAY"`
and `"LINE"`. Call it where the affected AI are local; WAIT's normal lifecycle
handles the server, headless clients and joining machines.

```sqf
["DAY", "LINE"] call WAIT_fnc_AITweak;
```

## Built-in profiles

| Internal key | ZEN name | Intended use |
|---|---|---|
| `LEGACY` | Existing Mission Balance | Compatibility with the established pre-profile behaviour |
| `MILITIA` | WAIT Militia | Irregular opposition with slow acquisition and forgiving lethality |
| `LINE` | WAIT Line | Trained regular opposition with restrained shooting precision |
| `VETERAN` | WAIT Veteran | Fast, capable opposition without maximum or superhuman precision inputs |
| `ELITE` | WAIT Elite | Highly capable opposition with strong sensing, decisions and weapon handling |

Change only the profile name to select a baseline. The wrapper `WAIT_fnc_AITweak` remains supported, while new code can call `WAIT_fnc_AIRebalanceInit` directly.

Use **Options > Addon Options > Waldos AI Tweaks** to configure the mode and built-in skill profile. CBA controls server enforcement, persistence and JIP. Custom scripted profiles remain available through the validated API.

When ACE Headless moves an ordinary AI group, WAIT listens to ACE's supported post-transfer event on
the destination HC, reapplies the selected profile there, and sends an authenticated result to the
server. This works even when WAIT's own optional HC distributor is disabled. Pack diagnostics report
`ai-headless-adoption` as an error if an HC owns ordinary AI without a matching verified adoption.

The same diagnostics report includes `improved-helicopter-landing`. It shows active vector
controllers and explicitly flags either a stale ground anchor or a controller that survived after
separately spawned helicopters were grouped. Ordinary MOVE waypoints and multi-helicopter formation
flight remain under Arma's own AI; WAIT releases any previous landing controller before that flight.
WAIT-controlled Dynamic AA, Paradrop, Gunship, Transport and convoy groups remain server-owned;
Dynamic AO is pinned only during creation and may move after its full setup completes.

## What the values control

WAIT sets the nine supported Arma 3 sub-skills. `aimingAccuracy` controls leading, range/drop estimation, dispersion and recoil compensation; `aimingShake` controls steadiness; `aimingSpeed` controls rotation and stabilisation. `spotDistance` affects spotting ability and information accuracy, while `spotTime` affects reaction time. `commanding` controls group target sharing, `general` influences decision making, `courage` affects morale and `reloadSpeed` controls weapon switching/reloading. Arma 3 disables the old `endurance` sub-skill, so WAIT does not expose it.

These are requested inputs, not guaranteed final values. The engine interpolates them through `CfgAISkill`, and the active server AI difficulty coefficients affect `skillFinal`. Test missions should inspect `skillFinal`, not assume that an input of `0.50` produces a final value of `0.50`. See Bohemia's official [AI Skill](https://community.bohemia.net/wiki/Arma_3:_AI_Skill), [setSkill](https://community.bohemia.net/wiki/setSkill), [skillFinal](https://community.bohemia.net/wiki/skillFinal) and [AI Config Reference](https://community.bohemia.net/wiki/Arma_3:_AI_Config_Reference) documentation.

## Day and low-light modes

`DAY` uses the selected base profile. `NIGHT` waits until illumination is below `WAIT_AI_DarknessThreshold`, then reduces the modern WAIT profiles' combat, sensing, target-sharing and decision inputs. AI with an assigned NVG/HMD receive the gentler `WAIT_AI_NightNVGMultipliers`; unaided AI use `WAIT_AI_NightUnaidedMultipliers`. Equipping the unit is therefore the explicit way to offset low-light degradation. The compatibility profile retains its established absolute spotting controls through `WAIT_AI_NightSpotWithNVG` and `WAIT_AI_NightSpotWithoutNVG`.

AI behaviour mods can still change tactical decisions independently of these skill inputs. WAIT does not assume or require one.

## Vehicle and aircraft crew

Drivers, commanders and turret operators receive the selected profile first, then the bounded
vehicle-crew aiming multiplier. Cargo retains the ordinary infantry profile. When external AI controller is
absent, WAIT also applies the configured owner-local aim coefficient; when the addon is present, WAIT
leaves its config-level turret dispersion and angular error in charge instead of stacking another
coefficient. Crews belonging to a named WAIT Dynamic AA system retain the selected profile and their
original aim coefficient because that system owns its own detection, fire-gate and ammunition policy.
Seat and Dynamic AA membership are included in the bounded refresh signature, so locality or seat
changes are corrected without installing a loop per unit.

## Settings: mission overrides

Add or replace named profiles before initialisation:

```sqf
private _profiles = missionNamespace getVariable ["WAIT_AI_Profiles", createHashMap];
_profiles set ["CUSTOM", createHashMapFromArray [
    ["aimingSpeed", 0.40], ["aimingAccuracy", 0.35], ["aimingShake", 0.50],
    ["spotTime", 0.60], ["spotDistance", 0.70], ["commanding", 0.75],
    ["general", 0.65], ["courage", 0.75], ["reloadSpeed", 0.70]
]];
missionNamespace setVariable ["WAIT_AI_Profiles", _profiles];
WAIT_AI_ProfileDisplayNames set ["CUSTOM", "WAIT Recon Opposition"];
["DAY", "CUSTOM"] call WAIT_fnc_AIRebalanceInit;
```

Custom profile keys appear in the ZEN selector automatically. Add a friendly label to `WAIT_AI_ProfileDisplayNames`; otherwise ZEN shows the key itself. Define the same custom profile on every machine during mission setup because AI can become local to the server, a client or a headless client.

`WAIT_AI_FactionOverrides` maps faction classnames to partial skill maps. `WAIT_AI_RoleOverrides` does the same for upper-case `textSingular` role names. Each override layers on top of the selected profile and all values are clamped to `0`–`1`.

`WAIT_AIRebalance_Mode` selects the lighting variant: `DAY` or `NIGHT`. This is independent of
`WAIT_AI_ApplyMode`, which selects the AI population: `BOTH`, `EXISTING` or `NEW`.
`WAIT_AI_IncludedSides`, `WAIT_AI_IncludedFactions`, `WAIT_AI_ExcludedFactions` and
`WAIT_AI_ExcludedClasses` provide coarse filters; set `WAIT_AI_Exclude = true` on an individual
unit for a precise opt-out. `WAIT_AI_SkillVariance` adds bounded variation after all overrides. The
offset is chosen once for each AI and follows it across repeated application and headless-client
ownership changes; migration therefore cannot silently reroll the AI's difficulty.

The feature records the original named skills before its first application and carries that snapshot
with the unit if ownership changes. With `WAIT_AI_RestoreOnStop` enabled,
`WAIT_fnc_AIRebalanceStop` restores those values. A server-side stop is authoritative for current
machines and JIP players; AI remains stopped until `WAIT_fnc_AIRebalanceInit` or the ZEN control
explicitly enables it again. A locality handler reapplies the selected profile when ownership moves
between server and headless clients.

## If an AI unit keeps its old behaviour

Check that AI tuning is enabled and that the unit's side, faction and class pass the profile filters. A unit with `WAIT_AI_Exclude` keeps its existing skills. Arma difficulty also changes final values through `CfgAISkill`; compare `skillFinal` rather than expecting an exact match to the profile input.

## See also

- [Optional Feature Systems](https://github.com/AdamWaldie/WaldosAITweaks/wiki/Optional-Feature-Systems)
- [Optional Feature Extensions](https://github.com/AdamWaldie/WaldosAITweaks/wiki/Optional-Feature-Extensions)
- [AI Convoy System](https://github.com/AdamWaldie/WaldosAITweaks/wiki/AI-Convoy-System)

<!-- WAIT-WIKI-NAV -->
---
[Wiki home](https://github.com/AdamWaldie/WaldosAITweaks/wiki/Home) · [Quickstart](https://github.com/AdamWaldie/WaldosAITweaks/wiki/Quickstart-Guide) · [Feature index](https://github.com/AdamWaldie/WaldosAITweaks/wiki/Feature-Tutorials)

# Waldos AI Tweaks

Standalone, mission-native AI behaviour for Arma 3. The package adds finite and interruptible
infantry tactics, combined-arms coordination, convoy control, aircraft behaviour, building use,
artillery decisions, civilian reactions and configurable AI skill without requiring Waldos Mission Pack.

## Product boundary

This repository contains AI behaviour only:

- Cortex infantry contact, movement, flank, advance, assault, withdrawal, regroup and CQB logic;
- proximity-based multi-squad and combined-arms coordination;
- convoy spacing, contact, dismount, recovery and crew-retention behaviour;
- aircraft attack, defence, countermeasure, landing and deceleration behaviour;
- vehicle gunnery, dispersion, standoff and passenger decisions;
- artillery support and counter-battery behaviour;
- AI skill, lighting, equipment and vehicle-crew profiles;
- compatibility leases for LAMBS, VCOM AI, WebKnight systems and detected Protocol AI packages;
- AI-specific diagnostics, optional ZEN controls and the Cortex QA suite.

Dynamic AA, Dynamic AO, mission logistics, economy, transport, paradrop services, notification UI and
the WMP diagnostics shell remain WMP features. Cortex may recognise units created by those systems,
but this package does not own or duplicate them.

## Requirements

- Arma 3
- CBA_A3
- ZEN is optional and only needed for `bootstrap\zenRegister.sqf`.
- ACE and supported AI mods are optional. Compatibility is detected at runtime.

## Mission installation

Copy `MissionConfig`, `MissionScripts`, `bootstrap` and `functions.hpp` into the mission root. Include
the functions from `description.ext`:

```cpp
#include "functions.hpp"
```

Start the package on every machine from `init.sqf`:

```sqf
[] execVM "bootstrap\start.sqf";
```

For optional ZEN controls, add this to `initPlayerLocal.sqf`:

```sqf
[] spawn {
    waitUntil {!isNil "zen_custom_modules_fnc_register"};
    [] execVM "bootstrap\zenRegister.sqf";
};
```

Mission code may set any `Waldo_*` setting before `bootstrap\start.sqf`; guarded defaults preserve it.
The complete settings and feature flags are documented in `MissionConfig\aiConfig.sqf`.

## Authority and Zeus

The server owns public enable state and cross-group decisions. Each unit, group or vehicle owner runs
the physical operation. JIP and locality changes reinstall only owner-local handlers. Direct Zeus
selection and orders always interrupt Cortex ownership; ordinary mission waypoints remain usable.

## Validation

Static validation lives under `releaseVerificationAndDeployment`. The Cortex QA builder remains
available for batched dedicated-server and client testing. A static pass proves syntax and contracts;
aircraft, convoy, CQB and multiplayer locality behaviour still require the generated in-engine audit.

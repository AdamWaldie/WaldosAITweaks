# CBA mod migration

## Completed foundation

1. Production code now lives inside one PBO namespace at `z\waldo_ai_tweaks\addons\main`.
2. CBA XEH owns pre-init and post-init. Missions no longer copy folders or call a bootstrap script.
3. Existing function names are preserved through addon `CfgFunctions` paths.
4. The settings panel sends curator-authorised changes through a CBA server event.
5. ZEN remains optional and registers after its API becomes available.
6. Product-specific Dynamic AA, Dynamic AO, transport and paradrop coupling was removed. Other
   systems use `Waldo_AI_ExternalControl` or `Waldo_AI_PrecisionExclude` instead.

## Next conversion steps

1. Register mission-maker settings with CBA Settings while retaining the existing variable names as
   the compatibility API.
2. Split the single addon into semantic PBOs only when ownership or optional dependencies justify it;
   file count alone is not a reason to create more scheduler or packaging overhead.
3. Replace cross-owner commands with named CBA events where that improves restrictive mission
   `CfgRemoteExec` compatibility. Preserve server validation and owner locality.
4. Add signed release packaging, version macros and CI build artifacts.
5. Rebuild the audit as an addon-loaded disposable mission and run live cases in batches.

## Runtime rules

- CBA is the only hard dependency.
- ZEN, ACE and other AI addons are optional.
- One controller owns movement at a time. Compatibility uses finite leases and exact restoration.
- Zeus and newer authored orders always win.
- Work is scheduled and bounded. No per-unit global scan or permanent micro-movement loop may be
  introduced to improve a single showcase.
- Static checks prove structure and contracts. They do not prove Arma pathfinding, flight or combat.

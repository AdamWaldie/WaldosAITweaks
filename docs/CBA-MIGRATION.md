# CBA mod migration

## Completed foundation

1. Production code now lives inside semantic PBOs beneath `z\waldo_ai_tweaks\addons`.
2. CBA XEH owns pre-init and post-init. Missions no longer copy folders or call a bootstrap script.
3. Functions use the breaking `WAIT_fnc_*` API through addon `CfgFunctions` paths.
4. Global mission options are registered with CBA Settings, which owns persistence and JIP replay
   with `WAIT_*` variable names as the public scripting API.
5. ZEN is a hard dependency and provides the live curator control surface.
6. Product-specific Dynamic AA, Dynamic AO, transport and paradrop coupling was removed. Other
   systems use `Waldo_AI_ExternalControl` or `Waldo_AI_PrecisionExclude` instead.
7. Accepted flank, advance and coordinated-bound lifecycles now run in a finite scripted FSM. The
   FSM exists only for the active manoeuvre and queues decisions through the shared SQF budget; it does not add
   a permanent per-group controller or an unbounded scan.

## Next conversion steps

1. Extend the finite-FSM pattern only where it reduces polling or makes interruption and cleanup
   clearer. Keep discovery, bounded calculations and event reactions in budgeted SQF.
2. Split the single addon into semantic PBOs only when ownership or optional dependencies justify it;
   file count alone is not a reason to create more scheduler or packaging overhead.
3. Replace cross-owner commands with named CBA events where that improves restrictive mission
   `CfgRemoteExec` compatibility. Preserve server validation and owner locality.
4. Exercise the signed candidate and exact-package release promotion workflows.
5. Run the addon-loaded disposable audit in batches and retain physical acceptance evidence.

## Runtime rules

- CBA and ZEN are hard dependencies.
- ACE and other AI addons are optional.
- One controller owns movement at a time. Compatibility uses finite leases and exact restoration.
- Zeus and newer authored orders always win.
- Work is scheduled and bounded. No per-unit global scan or permanent micro-movement loop may be
  introduced to improve a single showcase.
- Static checks prove structure and contracts. They do not prove Arma pathfinding, flight or combat.

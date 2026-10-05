# Standalone boundary

Waldos AI Tweaks owns the `WAIT_fnc_*` API and `WAIT_*` feature flags. It starts with guarded defaults,
locality ownership and JIP readiness without relying on a mission-side settings snapshot.

WAIT deliberately excludes scenario-owned Dynamic AA/AO, logistics, transport, paradrop, economy and UI
systems. Their units can be observed when eligible, but spawning, tasking, fire gates and lifecycle stay
with the system that owns them. `Waldo_AI_ExternalControl` and `Waldo_AI_PrecisionExclude` provide the
public handover contract without coupling WAIT to another implementation.

Integrations consume released WAIT packages and public contracts. They must not copy addon source or
start a competing controller for an actor WAIT already owns.

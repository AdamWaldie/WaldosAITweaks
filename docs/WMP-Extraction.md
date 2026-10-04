# WMP extraction boundary

Waldos AI Tweaks preserves the existing `Waldo_fnc_*` API and `Waldo_*` feature flags so missions can
move AI settings without rewriting calls. The standalone bootstrap replaces WMP's feature-runtime
snapshot dependency while retaining guarded defaults, locality ownership and JIP readiness.

The extraction deliberately excludes WMP's Dynamic AA and Dynamic AO implementations. Their units may
be observed by Cortex when eligible, but their spawning, fire gates, tasking and lifecycle remain under
WMP authority. The same boundary applies to WMP transport, paradrop, economy, logistics and UI systems.

The original WMP AI development branch remains available as migration evidence until the standalone
pull request is accepted. Subsequent AI changes should be made here; WMP integration should consume a
released version rather than copying the implementation back into the mission pack.

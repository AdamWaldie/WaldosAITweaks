# WAIT API migration

This is a breaking addon update. There are no forwarding aliases.

| Previous interface | New interface |
| --- | --- |
| `Waldo_fnc_<Function>` | `WAIT_fnc_<Function>` |
| `Waldo_<SettingOrState>` | `WAIT_<SettingOrState>` |
| `Waldo_AI_Tweaks_Main` addon identifier | `WAIT_AI_Tweaks_Main` |

Infantry controller ownership uses `WAIT_AIPass_InfantryOwnership` with `SPLIT` or `WAIT`.
There is no saved-setting alias for its former source-oriented key or legacy ownership values.

Update mission calls, remote-execution allowlists, overrides and saved CBA settings before upgrading.
The legacy addon-detection marker and cross-product `Waldo_AI_ExternalControl` and
`Waldo_AI_PrecisionExclude` markers remain for
interoperability; they are not WAIT configuration aliases. The virtual file prefix remains unchanged
so this API migration does not also invalidate packaged asset paths.

CBA Addon Options is the effective settings authority. Authorized runtime tuning updates its server
layer for the current session and does not silently write the administrator profile. Profile
persistence remains an explicit CBA operator action. Validate session overrides, restart, JIP and
server enforcement in the addon audit before release.
## Settings transport removal

`WAIT_fnc_CortexSettingsLocal` and `WAIT_fnc_AIPassSettingsLocal` are removed. Call
`WAIT_fnc_CortexTuning` on the server (or as an authorized curator) for validated runtime changes.
CBA performs client and JIP synchronization; do not replace the removed transport with direct
variable broadcasts. Activation timing is listed in the generated settings reference.


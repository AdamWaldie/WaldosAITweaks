/*
 * Author: WaldoTheWarfighter
 * Registers Waldos AI Tweaks mission options with CBA Settings.
 * Locality / Authority: Runs during CBA preInit on every machine. CBA owns authoritative server and
 * mission values, persistence and JIP synchronization; callbacks only start or stop owner-local work.
 * Repeat/JIP: Guarded per machine. CBA replays the authoritative values to joining machines.
 * Arguments: None.
 * Return Value: NUMBER - count of settings registered on this machine.
 * Current callers: XEH_preInit.sqf.
 * Example: [] call WAIT_fnc_AITweaksRegisterSettings;
 */

if (missionNamespace getVariable ["WAIT_AITweaks_CBASettingsRegistered", false]) exitWith {0};
missionNamespace setVariable ["WAIT_AITweaks_CBASettingsRegistered", true];

private _sections = [] call WAIT_fnc_AITweaksSettingsSections;
private _layout = createHashMap;
{_x params ["_key", "_page", "_heading"]; _layout set [_key, ["Waldos AI Tweaks - " + _page, _heading]]} forEach _sections;
private _spec = [] call WAIT_fnc_CortexTuningSpec;
private _ordered = [];
// Group controls by use case; enable gates appear before tuning without renaming persisted keys.
{
    private _section = _x select 0;
    private _rows = _spec select {(_x select 6) == _section};
    _ordered append (_rows select {(_x select 0) find "_Enable" >= 0});
    _ordered append (_rows select {(_x select 0) find "_Enable" < 0});
} forEach _sections;
private _registered = 0;
{
    _x params ["_name", "_label", "_tooltip", "_kind", "_options", "_default", ["_section", "GENERAL"], "_activation"];
    private _activationHelp = switch (_activation) do {
        case "LIVE": {"Applies on the next local update; existing worker setup follows this change."};
        case "NEXT_OPERATION": {"Guaranteed for the next operation. Existing operations keep their committed intent and may read safety values earlier."};
        case "RESTART_REQUIRED": {"Requires a mission restart."};
        default {"Unsupported activation policy."};
    };
    private _help = _tooltip + " " + _activationHelp;
    private _category = _layout get _section;
    private _cbaType = "CHECKBOX";
    private _valueInfo = _default;
    switch (_kind) do {
        case "CHECKBOX": {_cbaType = "CHECKBOX"; _valueInfo = _default};
        case "SLIDER": {
            _cbaType = "SLIDER";
            _valueInfo = [_options select 0, _options select 1, _default, _options select 2];
        };
        case "COMBO": {
            _cbaType = "LIST";
            _options params ["_values", "_labels"];
            private _defaultIndex = (_values find _default) max 0;
            _valueInfo = [_values, _labels, _defaultIndex];
        };
    };
    private _callback = compile format [
        "['%1', _this] call WAIT_fnc_AITweaksSettingChanged;",
        _name
    ];
    [_name, _cbaType, [_label, _help], _category, _valueInfo, true, _callback, _activation == "RESTART_REQUIRED"]
        call CBA_fnc_addSetting;
    _registered = _registered + 1;
} forEach _ordered;

diag_log format ["[Waldos AI Tweaks] Registered %1 global CBA settings.", _registered];
_registered

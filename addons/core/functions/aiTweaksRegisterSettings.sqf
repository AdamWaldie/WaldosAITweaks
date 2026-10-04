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

private _sectionNames = createHashMapFromArray [
    ["GENERAL", "General"],
    ["CONTACT", "Contact and fire"],
    ["MOVEMENT", "Movement and assault"],
    ["MORALE", "Morale and recovery"],
    ["SUPPORT", "Coordination and support"],
    ["VEHICLES", "Vehicles and convoy"],
    ["AIR", "Aircraft"],
    ["ARTILLERY", "Artillery"],
    ["REACTIONS", "Civilian and special reactions"]
];
private _registered = 0;
{
    _x params ["_name", "_label", "_tooltip", "_kind", "_options", "_default", ["_section", "GENERAL"]];
    private _category = ["Waldos AI Tweaks", _sectionNames getOrDefault [_section, _section]];
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
    [_name, _cbaType, [_label, _tooltip], _category, _valueInfo, true, _callback, false]
        call CBA_fnc_addSetting;
    _registered = _registered + 1;
} forEach ([] call WAIT_fnc_CortexTuningSpec);

diag_log format ["[Waldos AI Tweaks] Registered %1 global CBA settings.", _registered];
_registered

/*
 * Author: WaldoTheWarfighter
 * Reads or writes a semantic ownership field exposed by an optional controller.
 * Locality / Authority: Caller must own the affected object/group for mutations; optional public writes preserve prior transport semantics.
 * Repeat/JIP: Stateless and repeat-safe; reads the local compatibility snapshot on JIP.
 * Arguments: 0 entity <OBJECT or GROUP>; 1 field <STRING>; 2 value/default <ANY>, default nil; 3 write <BOOL>, default false; 4 public <BOOL>, default false.
 * Return Value: ANY - field value for reads; BOOL for writes or an unknown field.
 * Current callers: ownership discovery/release, group tactics, convoy setup/release and diagnostics.
 * Example: [vehicle player,"drivingPause",false] call WAIT_fnc_CompatibilityState;
 */

params ["_entity",["_field","",[""]],["_value",nil],["_write",false,[false]],["_public",false,[false]]];
private _key = switch (_field) do {
    case "drivingPause": {"HBQAD_Pause"};
    case "drivingCrewReturn": {"HBQAD_PreventDisembark"};
    default {""};
};
if (_key == "") exitWith {false};
if (_write) exitWith {_entity setVariable [_key,_value,_public]; true};
_entity getVariable [_key,_value]

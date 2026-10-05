/*
 * Author: WaldoTheWarfighter
 * Resolves the public precision-policy opt-out through WAIT's compatibility boundary. It preserves
 * authored weapon behaviour for an opted-out soldier, operating vehicle or owning group while
 * leaving all other WAIT skill layers available.
 *
 * Locality / Authority: Read-only; callable on any machine for a unit.
 * Repeat/JIP: Safe to repeat. It reads public state only and changes no state.
 *
 * Arguments:
 * 0: unit <OBJECT>, default objNull - AI whose personal, vehicle and group opt-outs are checked.
 *
 * Return Value:
 * Boolean - true when the unit, its current vehicle or its group explicitly opts out of precision tuning.
 *
 * Current callers: WAIT skill layers and diagnostics.
 *
 * Example:
 * if ([_unit] call WAIT_fnc_CompatibilityPrecisionExcluded) then {_unit setCustomAimCoef 1};
 */
params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {false};

private _vehicle = vehicle _unit;
(_unit getVariable ["Waldo_AI_PrecisionExclude", false])
|| {_vehicle != _unit && {_vehicle getVariable ["Waldo_AI_PrecisionExclude", false]}}
|| {(group _unit) getVariable ["Waldo_AI_PrecisionExclude", false]}

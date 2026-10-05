/*
 * Author: WaldoTheWarfighter
 * Reads the public external-controller ownership marker through WAIT's compatibility boundary.
 * Tactical subsystems use this neutral gate rather than depending on another product's runtime
 * variable name. The marker is read-only and never grants WAIT ownership.
 *
 * Locality / Authority: Read-only; callable on any machine for a group or object.
 * Repeat/JIP: Safe to repeat. It reads the currently published marker each time and changes no state.
 *
 * Arguments:
 * 0: subject <GROUP or OBJECT>, default grpNull - group or actor/vehicle to inspect.
 *
 * Return Value:
 * Boolean - true only when the subject or, for an object, its current group explicitly declares
 * external control.
 *
 * Current callers: WAIT eligibility, vehicles, aircraft, skill layers, diagnostics and HC adoption.
 *
 * Example:
 * if ([group _unit] call WAIT_fnc_CompatibilityExternalControl) exitWith {};
 */
params [["_subject", grpNull, [grpNull, objNull]]];

if (_subject isEqualType grpNull) exitWith {
    !isNull _subject && {_subject getVariable ["Waldo_AI_ExternalControl", false]}
};
if (isNull _subject) exitWith {false};

(_subject getVariable ["Waldo_AI_ExternalControl", false])
|| {(group _subject) getVariable ["Waldo_AI_ExternalControl", false]}

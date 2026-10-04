/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Decides whether a soldier can pass information or call for support by radio.
 *
 * AI communications do not require an inventory radio item.
 * Missions may provide Waldo_AITweaks_JammingFactor as a read-only CODE hook. A result of 0.5 or
 * more blocks AI reports, reinforcement calls and artillery requests. Without a hook, transmission
 * is available and this addon remains independent of any electronic-warfare implementation.
 * Locality and authority: read-only; callable anywhere.
 *
 * Arguments:
 * 0: unit <OBJECT>
 *
 * Return Value:
 * Boolean - true when the unit can transmit
 *
 * Example:
 * if ([leader _group] call Waldo_fnc_CortexCanTransmit) then {...};
 * Result: a jammed squad leader cannot call for help.
 *
 * Current callers: Cortex contact reports, reinforcement, artillery, coordinated support and combined-arms opportunity selection.
 */

params [["_unit", objNull, [objNull]]];
if (isNull _unit || {!alive _unit}) exitWith {false};
private _hook = missionNamespace getVariable ["Waldo_AITweaks_JammingFactor", {}];
if !(_hook isEqualType {}) exitWith {true};
private _factor = [getPosASL _unit, side group _unit] call _hook;
_factor isEqualType 0 && {_factor < 0.5}


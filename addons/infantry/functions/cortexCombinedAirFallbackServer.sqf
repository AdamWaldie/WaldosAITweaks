/*
 * Author: WaldoTheWarfighter
 * Advances a finite combined-arms air candidate list after its actual aircraft owner rejects a
 * weapon/turret preflight. It only dispatches an already ranked live candidate; it never creates
 * an airframe, changes locality, changes player orders or assumes a remote loadout is usable.
 *
 * Locality / Authority: Server-only. The rejected group owner must be the remote sender. The next
 * candidate applies the role only on its current group owner through CortexCombinedArmsLocal.
 *
 * Repeat/JIP: The requester holds one expiring public fallback record. Duplicate rejection notices
 * consume no extra candidate after the cursor advances. The record is cleared with its opportunity.
 *
 * Arguments:
 * 0: requester group <GROUP>; 1: rejected aircraft group <GROUP>; 2: opportunity token <STRING>.
 *
 * Return Value:
 * BOOL - true when one replacement candidate was dispatched.
 *
 * Current callers: WAIT_fnc_CortexCombinedArmsLocal after local weapon or busy/start refusal.
 *
 * Example:
 * [_requester,_rejectedGroup,_token] remoteExecCall ["WAIT_fnc_CortexCombinedAirFallbackServer",2];
 * Result: the next viable candidate receives the same finite AIR_ATTACK opportunity.
 */
params [["_requester",grpNull,[grpNull]],["_rejected",grpNull,[grpNull]],["_token","",[""]]];
if (!isServer || {isNull _requester} || {isNull _rejected} || {_token == ""}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != groupOwner _rejected}}) exitWith {false};
private _fallback=_requester getVariable ["WAIT_Cortex_CombinedAirFallback",[]];
if (count _fallback != 6) exitWith {false};
_fallback params ["_storedToken","_target","_position","_expiry","_candidates","_cursor"];
if (_storedToken != _token || {serverTime >= _expiry} || {isNull _target} || {!alive _target}) exitWith {false};
private _rejectedRole=_rejected getVariable ["WAIT_Cortex_CombinedRole",[]];
if (count _rejectedRole != 7 || {(_rejectedRole select 0) != _token}
    || {(_rejectedRole select 1) != _requester} || {(_rejectedRole select 4) != "AIR_ATTACK"}) exitWith {false};
// Consume this exact refusal once. A duplicate notice has no matching role; a newer role
// survives. Retiring the opportunity never cancels the aircraft's existing attack brain.
_rejected setVariable ["WAIT_Cortex_CombinedRole",nil,true];
_rejected setVariable ["WAIT_Cortex_CombinedApplied",nil,true];
private _replacement=grpNull;
while {_cursor < count _candidates && {isNull _replacement}} do {
    private _candidate=_candidates select _cursor;
    _cursor=_cursor+1;
    if (!isNull _candidate && {_candidate != _rejected} && {!isNull ([_candidate] call WAIT_fnc_CortexGroupTransmitter)}
        && {[_candidate] call WAIT_fnc_CortexIsEligible}
        && {((units _candidate) findIf {
            private _vehicle=vehicle _x;
            _vehicle != _x && {_vehicle isKindOf "Air"} && {!(_vehicle getVariable ["WAIT_Cortex_AirAttackJob",false])}
        }) >= 0}) then {
        _replacement=_candidate;
    };
};
_requester setVariable ["WAIT_Cortex_CombinedAirFallback",[_storedToken,_target,+_position,_expiry,_candidates,_cursor],true];
if (isNull _replacement) exitWith {false};
private _opportunity=[_token,_requester,_target,+_position,"AIR_ATTACK",_expiry,[]];
_replacement setVariable ["WAIT_Cortex_CombinedRole",_opportunity,true];
_replacement setVariable ["WAIT_Cortex_CombinedApplied",nil,true];
_replacement setVariable ["WAIT_Cortex_CombinedResult",[_token,"AIR_ATTACK","FALLBACK_DISPATCHED",serverTime,_target],true];
[_replacement,_opportunity] remoteExecCall ["WAIT_fnc_CortexCombinedArmsLocal",groupOwner _replacement];
[{
    params ["_replacement","_token","_target"];
    if (!isNull _replacement && {((_replacement getVariable ["WAIT_Cortex_CombinedRole",[]]) param [0,""]) == _token}) then {
        _replacement setVariable ["WAIT_Cortex_CombinedResult",[_token,"AIR_ATTACK","EXPIRED",serverTime,_target],true];
        _replacement setVariable ["WAIT_Cortex_CombinedRole",nil,true];
        _replacement setVariable ["WAIT_Cortex_CombinedApplied",nil,true];
    };
},[_replacement,_token,_target],(_expiry-serverTime) max 0] call CBA_fnc_waitAndExecute;
true

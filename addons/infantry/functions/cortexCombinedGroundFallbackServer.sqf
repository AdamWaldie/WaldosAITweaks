/*
 * Author: WaldoTheWarfighter
 * Purpose: Dispatch one replacement from an opportunity's bounded ranked ground-asset pool.
 * Locality/authority: Server-only internal call after CortexCombinedRejectServer authenticates
 * and retires the exact refusal. Current requester, candidate and operating crew are revalidated.
 * Original contact confidence/time pass unchanged to replacements; fallback never renews observation age.
 * Repeat/JIP: A token/role consumption receipt rejects duplicates. The shared cursor advances
 * through at most 32 retained candidates; original contact, expiry and independent leases survive.
 * No discovery scan, movement command, locality change or fabricated weapon acceptance is added.
 * Arguments: 0 rejected group <GROUP, grpNull>; 1 retired opportunity <ARRAY, []>, seven legacy or eight receipt-bearing fields.
 * Return Value: BOOL, one replacement was dispatched; not proof of acceptance or physical effect.
 * Current caller: WAIT_fnc_CortexCombinedRejectServer after exact metadata-only retirement.
 * Example: [_group,_retiredOpportunity] call WAIT_fnc_CortexCombinedGroundFallbackServer;
 */
params [["_rejected",grpNull,[grpNull]],["_snapshot",[],[[]]]];
if (!isServer || {isNull _rejected} || {!((count _snapshot) in [7,8])}
    || {!(missionNamespace getVariable ["WAIT_AIPass_Active",false])}
    || {[] call WAIT_fnc_CortexIsPaused}) exitWith {false};
_snapshot params ["_token","_requester","_target","_position","_role","_expiry","_context"];
if (isNull _requester || {isNull _target} || {!alive _target}
    || {!(_role in ["GROUND_FIRE","GROUND_MANOEUVRE"])} || {serverTime >= _expiry}
    || {count _position != 3} || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {_target distance2D _position > 75}
    || {captive _target} || {_target getVariable ["ace_captives_isSurrendering",false]}
    || {_target getVariable ["ace_captives_isHandcuffed",false]}
    || {(side _requester) getFriend side _target >= 0.6}
    || {!([_requester] call WAIT_fnc_CortexIsEligible)}) exitWith {false};
private _fallback=_requester getVariable ["WAIT_Cortex_CombinedGroundFallback",[]];
if (!((count _fallback) in [6,7])) exitWith {false};
_fallback params ["_storedToken","_storedTarget","_storedPosition","_storedExpiry","_candidates","_cursor"];
private _contactReceipt=_fallback param [6,[],[[]]];
if (_storedToken != _token || {_storedTarget != _target} || {_storedPosition isNotEqualTo _position}
    || {_storedExpiry != _expiry} || {(_snapshot param [7,[],[[]]]) isNotEqualTo _contactReceipt} || {count _candidates > 32} || {_cursor < 0}
    || {_cursor > count _candidates}) exitWith {false};
private _result=_rejected getVariable ["WAIT_Cortex_CombinedResult",[]];
if (count _result != 5 || {(_result select 0) != _token} || {(_result select 1) != _role}
    || {(_result select 4) != _target}
    || {(_rejected getVariable ["WAIT_Cortex_CombinedRole",[]]) isNotEqualTo []}
    || {(_rejected getVariable ["WAIT_Cortex_CombinedGroundConsumed",[]]) isEqualTo [_token,_role]}) exitWith {false};
_rejected setVariable ["WAIT_Cortex_CombinedGroundConsumed",[_token,_role]];
private _sender=[_requester] call WAIT_fnc_CortexGroupTransmitter;
private _origin=if (isNull _sender) then {leader _requester} else {_sender};
if (isNull _origin) exitWith {false};
private _range=missionNamespace getVariable ["WAIT_AIPass_ContactReports_Radius",500];
private _voiceRange=missionNamespace getVariable ["WAIT_AIPass_ContactReports_VoiceRange",35];
private _replacement=grpNull;
while {_cursor < count _candidates && {isNull _replacement}} do {
    private _row=_candidates select _cursor;
    _cursor=_cursor+1;
    _row params ["_candidate","_asset"];
    if (!isNull _candidate && {_candidate != _rejected} && {_candidate != _requester}
        && {side _candidate == side _requester} && {[_candidate] call WAIT_fnc_CortexIsEligible}
        && {!isNull _asset} && {alive _asset} && {_asset isKindOf "LandVehicle"}
        && {!(_asset isKindOf "StaticWeapon")} && {canFire _asset}
        && {!(_asset getVariable ["WAIT_Convoy_Active",false])}
        && {[_candidate,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
        && {[_candidate,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
        && {private _commander=effectiveCommander _asset; private _driver=driver _asset;
            (!isNull _commander && {group _commander == _candidate})
                || {!isNull _driver && {group _driver == _candidate}}}
        && {private _live=_candidate getVariable ["WAIT_Cortex_CombinedRole",[]];
            !((count _live) in [7,8]) || {serverTime >= (_live select 5)}}) then {
        private _receiver=[_candidate] call WAIT_fnc_CortexGroupTransmitter;
        private _anchor=if (isNull _receiver) then {leader _candidate} else {_receiver};
        if (!isNull _anchor && {alive _anchor} && {_anchor distance2D _origin <= _range}
            && {_anchor distance2D _origin <= _voiceRange || {!isNull _sender && {!isNull _receiver}}}) then {
            _replacement=_candidate;
        };
    };
};
_requester setVariable ["WAIT_Cortex_CombinedGroundFallback",[_token,_target,+_position,_expiry,_candidates,_cursor,+_contactReceipt],true];
if (isNull _replacement) exitWith {false};
private _opportunity=[_token,_requester,_target,+_position,_role,_expiry,+_context,+_contactReceipt];
_replacement setVariable ["WAIT_Cortex_CombinedRole",_opportunity,true];
_replacement setVariable ["WAIT_Cortex_CombinedApplied",nil,true];
_replacement setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"FALLBACK_DISPATCHED",serverTime,_target],true];
[_replacement,_opportunity] remoteExecCall ["WAIT_fnc_CortexCombinedArmsLocal",groupOwner _replacement];
[{
    params ["_replacement","_token","_role","_target"];
    if (!isNull _replacement && {((_replacement getVariable ["WAIT_Cortex_CombinedRole",[]]) param [0,""]) == _token}) then {
        private _result=_replacement getVariable ["WAIT_Cortex_CombinedResult",[]];
        if ((_result param [0,""]) == _token && {(_result param [2,""]) in ["DISPATCHED","FALLBACK_DISPATCHED","APPLIED"]}) then {
            _replacement setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"EXPIRED",serverTime,_target],true];
        };
        _replacement setVariable ["WAIT_Cortex_CombinedRole",nil,true];
        _replacement setVariable ["WAIT_Cortex_CombinedApplied",nil,true];
    };
},[_replacement,_token,_role,_target],(_expiry-serverTime) max 0] call CBA_fnc_waitAndExecute;
true

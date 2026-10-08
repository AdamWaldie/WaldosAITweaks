/*
 * Author: WaldoTheWarfighter
 * Purpose: Gives one finite WAIT operation exclusive ownership of the group's WAIT movement domain.
 * Locality / Authority: Call only where the group is local. The public lease follows group locality so a server or headless-client owner can renew or release it.
 * Repeat/JIP: Reacquiring the same owner renews its deadline without replacing the captured baseline.
 * A competing unexpired WAIT owner is refused; external ownership is handled before acquisition. Repeated release is safe.
 * Arguments: 0 group <GROUP>; 1 owner <STRING>; 2 acquire <BOOL>, true; 3 expiry <NUMBER>, serverTime + 30.
 * Return Value: Boolean - true when acquired/released, false for invalid locality or competing work.
 * Current callers: Finite WAIT group movement start/end, discovery expiry and group release.
 * Example: [_group,"SUPPORT",true,serverTime + 180] call WAIT_fnc_CortexOwnershipLease;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_owner","",[""]],
    ["_acquire",true,[false]],
    ["_expires",serverTime + 30,[0]]
];
if (isNull _group || {!local _group}) exitWith {false};

private _lease=_group getVariable ["WAIT_Cortex_MovementLease",[]];
private _live=count _lease == 2 && {serverTime < (_lease select 1)};
if (_acquire) exitWith {
    if (_owner == "" || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
    if (_live && {(_lease select 0) != _owner}) exitWith {
        missionNamespace setVariable [
            "WAIT_Cortex_OwnershipBusyRefusals",
            (missionNamespace getVariable ["WAIT_Cortex_OwnershipBusyRefusals",0]) + 1
        ];
        false
    };
    _group setVariable ["WAIT_Cortex_MovementLease",[_owner,_expires max (serverTime + 1)],true];
    true
};

if (_lease isEqualTo []) exitWith {true};
if (_owner != "" && {(_lease select 0) != _owner}) exitWith {false};
_group setVariable ["WAIT_Cortex_MovementLease",nil,true];
true

/*
 * Author: WaldoTheWarfighter
 * Purpose: Give one finite WAIT movement operation exclusive group movement ownership when an
 * independent alternative AI controller is active, then restore that controller's exact setting.
 * Locality / Authority: Call only where the group is local. The public lease follows group locality
 * so a server or headless-client owner can renew or release the same operation.
 * Repeat/JIP: Reacquiring the same owner renews its deadline without replacing the captured baseline.
 * A competing owner or an active external support/medical move is refused. Repeated release is safe.
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
if !(missionNamespace getVariable ["WAIT_AIPass_AlternativeBackendLoaded",false]) exitWith {true};

private _lease=_group getVariable ["WAIT_Cortex_AlternativeLease",[]];
if (_acquire) exitWith {
    if (_owner == "") exitWith {false};
    private _same=count _lease == 3 && {(_lease select 0) == _owner};
    private _expired=count _lease == 3 && {serverTime >= (_lease select 2)};
    if (_lease isNotEqualTo [] && {!_same} && {!_expired}) exitWith {false};
    private _busy=!_same && {
        _group getVariable ["VCM_MOVE2SUP",false]
        || {(units _group) findIf {_x getVariable ["VCM_MBUSY",false]} >= 0}
    };
    if (_busy) exitWith {
        missionNamespace setVariable [
            "WAIT_Cortex_OwnershipBusyRefusals",
            (missionNamespace getVariable ["WAIT_Cortex_OwnershipBusyRefusals",0]) + 1
        ];
        false
    };
    private _baseline=if (_same || {_expired}) then {_lease select 1} else {_group getVariable ["Vcm_Disable",false]};
    _group setVariable ["WAIT_Cortex_AlternativeLease",[_owner,_baseline,_expires max (serverTime + 1)],true];
    _group setVariable ["Vcm_Disable",true,true];
    true
};

if (_owner != "" && {_lease isNotEqualTo [] && {(_lease select 0) != _owner}}) exitWith {false};
if (_lease isNotEqualTo []) then {
    private _baseline=_lease select 1;
    _group setVariable ["WAIT_Cortex_AlternativeLease",nil,true];
    _group setVariable ["Vcm_Disable",_baseline,true];
};
true

/*
 * Author: WaldoTheWarfighter
 * Gives one finite Cortex movement operation exclusive group-level movement ownership when
 * LAMBS_Danger and/or external controller are active, then restores each mod's exact previous setting.
 *
 * Locality/authority: call only where the group is local. The lease and COMPAT group switch are
 * public so a new server/headless-client owner can renew or release the same ownership record.
 * WMP mode already owns COMPAT group movement through Waldo_AIPass_DangerBackendDisabledByPass. external controller always
 * receives a finite lease because Cortex does not otherwise own it. LAMBS_Turrets, Suppression and
 * RPG remain active, and external controller skill/formation settings are never altered.
 * Repeat/JIP: reacquiring the same owner renews its deadline without changing the saved baseline;
 * another owner is refused until release or expiry. A fresh lease is refused while COMPAT has a
 * queued/active tactic or external controller has an active support/medic move. Release restores only captured
 * settings and leaves pre-existing user opt-outs intact. Repeated release is harmless.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: owner <STRING> - stable Cortex movement owner, for example SUPPORT
 * 2: acquire <BOOL> - true to acquire/renew, false to release
 * 3: expires <NUMBER> - serverTime deadline (optional, default serverTime + 30)
 *
 * Return Value:
 * Boolean - true when ownership was acquired/released, false for invalid locality, a competing
 * owner or movement which COMPAT already owns
 *
 * Current callers: every finite Cortex group-movement start/end, CortexDiscover and CortexReleaseGroup.
 *
 * Example:
 * [_group, "SUPPORT", true, serverTime + 180] call Waldo_fnc_CortexOwnershipLease;
 * Result: COMPAT group manoeuvres pause for that finite Cortex support move and resume afterwards.
 */

params [
    ["_group", grpNull, [grpNull]],
    ["_owner", "", [""]],
    ["_acquire", true, [false]],
    ["_expires", serverTime + 30, [0]]
];
if (isNull _group || {!local _group}) exitWith {false};
private _dangerLoaded=missionNamespace getVariable ["Waldo_AIPass_DangerBackendLoaded",false];
private _alternativeBackendLoaded=missionNamespace getVariable ["Waldo_AIPass_AlternativeBackendLoaded",false];
if (!_dangerLoaded && {!_alternativeBackendLoaded}) exitWith {true};

private _lease = _group getVariable ["Waldo_Cortex_OwnershipLease", []];
private _alternativeBackendLease=_group getVariable ["Waldo_Cortex_AlternativeLease",[]];
private _blanket = _group getVariable ["Waldo_AIPass_DangerBackendDisabledByPass", false];
private _wmpMode = toUpperANSI (missionNamespace getVariable ["Waldo_AIPass_InfantryOwnership", "SPLIT"]) == "WMP";

if (_acquire) exitWith {
    if (_owner == "") exitWith {false};
    private _same = count _lease == 3 && {(_lease select 0) == _owner};
    private _expired = count _lease == 3 && {serverTime >= (_lease select 2)};
    if (_lease isNotEqualTo [] && {!_same} && {!_expired}) exitWith {false};
    private _sameVcom=count _alternativeBackendLease == 3 && {(_alternativeBackendLease select 0) == _owner};
    private _expiredVcom=count _alternativeBackendLease == 3 && {serverTime >= (_alternativeBackendLease select 2)};
    if (_alternativeBackendLease isNotEqualTo [] && {!_sameVcom} && {!_expiredVcom}) exitWith {false};

    // COMPAT 2.6.2.1 publishes isExecutingTactic before its delayed flank/assault callback. Testing
    // it here therefore covers both queued and running tactics. forceMove covers unit/group actions;
    // task* identifies explicit COMPAT Waypoint ownership. Do not clear any of these upstream states.
    private _dangerTactic = _group getVariable ["lambs_main_currentTactic", ""];
    private _dangerWaypointTask = _dangerTactic isEqualType "" && {
        (toLowerANSI _dangerTactic) find "task" == 0
    };
    private _dangerForcedMovement = (units _group) findIf {
        _x getVariable ["lambs_danger_forceMove", false]
    } >= 0;
    private _dangerBusy = _dangerLoaded && {!_wmpMode} && {!_blanket} && {
        _group getVariable ["lambs_danger_isExecutingTactic", false]
        || {_dangerForcedMovement}
        || {_dangerWaypointTask}
    };
    private _alternativeBackendBusy=_alternativeBackendLoaded && {!_sameVcom} && {
        _group getVariable ["VCM_MOVE2SUP",false]
        || {(units _group) findIf {_x getVariable ["VCM_MBUSY",false]} >= 0}
    };
    if ((!_same && {_dangerBusy}) || {_alternativeBackendBusy}) exitWith {
        missionNamespace setVariable [
            "Waldo_Cortex_OwnershipBusyRefusals",
            (missionNamespace getVariable ["Waldo_Cortex_OwnershipBusyRefusals", 0]) + 1
        ];
        false
    };

    if (_dangerLoaded && {!_wmpMode} && {!_blanket}) then {
        private _baseline = if (_same) then {_lease select 1} else {
            if (_expired) then {_lease select 1} else {_group getVariable ["lambs_danger_disableGroupAI", false]}
        };
        _group setVariable ["Waldo_Cortex_OwnershipLease", [_owner, _baseline, _expires max (serverTime + 1)], true];
        _group setVariable ["lambs_danger_disableGroupAI", true, true];
    };
    if (_alternativeBackendLoaded) then {
        private _baselineVcom=if (_sameVcom || {_expiredVcom}) then {_alternativeBackendLease select 1}
            else {_group getVariable ["Vcm_Disable",false]};
        _group setVariable ["Waldo_Cortex_AlternativeLease",[_owner,_baselineVcom,_expires max (serverTime+1)],true];
        _group setVariable ["Vcm_Disable",true,true];
    };
    true
};

if (_owner != "" && {(_lease isNotEqualTo [] && {(_lease select 0) != _owner})
    || {_alternativeBackendLease isNotEqualTo [] && {(_alternativeBackendLease select 0) != _owner}}}) exitWith {false};
if (_lease isNotEqualTo []) then {
    private _baseline = _lease select 1;
    _group setVariable ["Waldo_Cortex_OwnershipLease", nil, true];
    if (_wmpMode || {_blanket}) then {
        _group setVariable ["lambs_danger_disableGroupAI", true, true];
    } else {
        _group setVariable ["lambs_danger_disableGroupAI", _baseline, true];
    };
};
if (_alternativeBackendLease isNotEqualTo []) then {
    private _baselineVcom=_alternativeBackendLease select 1;
    _group setVariable ["Waldo_Cortex_AlternativeLease",nil,true];
    _group setVariable ["Vcm_Disable",_baselineVcom,true];
};
true

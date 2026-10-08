/*
 * Author: WaldoTheWarfighter
 * Owns the engine unload-in-combat policy for one ordinary WAIT-controlled ground vehicle.
 *
 * ACQUIRE prevents the engine from independently unloading cargo while WAIT is responsible for
 * deliberate contact dismounts. The exact crew group, group epoch, previous value and applied value
 * are recorded on the vehicle. A later owner adopts the unchanged lease without reissuing the
 * command. If any other controller changes the value, WAIT drops its lease and blocks reacquisition
 * for that group epoch instead of fighting the newer owner.
 * RELEASE restores the previous value only when requested, the vehicle is local, the lease still
 * belongs to the supplied group and the current value still exactly matches WAIT's applied value.
 * Zeus, player and specialist handovers use release without restoration. Convoys retain their own
 * independent unload policy and are never acquired here.
 *
 * Locality and authority: call on the machine local to the vehicle. The effective commander's group
 * must be the supplied local group for ACQUIRE. Lease and tracked-vehicle records are public so a
 * replacement owner can adopt or release them after locality migration.
 * Repeat/JIP: ACQUIRE is idempotent for an unchanged lease; RELEASE is idempotent. No loop or
 * scheduled work is created.
 *
 * Arguments:
 * 0: vehicle <OBJECT>, default objNull
 * 1: crew group <GROUP>, default grpNull
 * 2: action <STRING> - ACQUIRE or RELEASE, default ACQUIRE
 * 3: restore previous value <BOOL> - RELEASE only, default true
 *
 * Return Value:
 * Boolean - true when WAIT owns or cleanly released the matching lease
 *
 * Current callers: WAIT_fnc_CortexVehicles, WAIT_fnc_CortexReleaseGroup and WAIT_fnc_CortexStop.
 *
 * Example:
 * [_truck, group effectiveCommander _truck, "ACQUIRE"] call WAIT_fnc_CortexVehicleUnloadPolicy;
 * Result: the engine keeps passengers aboard until WAIT deliberately dismounts them or yields.
 */

params [
    ["_vehicle",objNull,[objNull]],
    ["_group",grpNull,[grpNull]],
    ["_action","ACQUIRE",[""]],
    ["_restore",true,[false]]
];
if (isNull _vehicle || {isNull _group} || {!local _vehicle}) exitWith {false};
_action=toUpperANSI _action;
private _lease=_vehicle getVariable ["WAIT_Cortex_UnloadPolicyLease",[]];
private _removeTracked={
    private _tracked=(_group getVariable ["WAIT_Cortex_UnloadPolicyVehicles",[]]) - [_vehicle];
    if (_tracked isEqualTo []) then {
        _group setVariable ["WAIT_Cortex_UnloadPolicyVehicles",nil,true];
    } else {
        _group setVariable ["WAIT_Cortex_UnloadPolicyVehicles",_tracked,true];
    };
};

if (_action == "RELEASE") exitWith {
    if (count _lease != 5 || {(_lease select 0) != _group}) exitWith {
        call _removeTracked;
        false
    };
    _lease params ["_leaseGroup","_leaseEpoch","_previous","_applied","_leaseOwner"];
    if (_restore && {getUnloadInCombat _vehicle isEqualTo _applied}) then {
        _vehicle setUnloadInCombat _previous;
    };
    _vehicle setVariable ["WAIT_Cortex_UnloadPolicyLease",nil,true];
    _vehicle setVariable ["WAIT_Cortex_UnloadPolicyBlocked",nil,true];
    call _removeTracked;
    true
};

if (_action != "ACQUIRE" || {_vehicle getVariable ["WAIT_Convoy_Active",false]}
    || {!local _group} || {!((effectiveCommander _vehicle) in units _group)}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
private _epoch=_group getVariable ["WAIT_AIPass_Epoch",0];
private _blocked=_vehicle getVariable ["WAIT_Cortex_UnloadPolicyBlocked",[]];
if (count _blocked == 2 && {(_blocked select 0) == _group} && {(_blocked select 1) == _epoch}) exitWith {false};

if (count _lease == 5 && {(_lease select 0) != _group}) exitWith {false};
if (count _lease == 5 && {getUnloadInCombat _vehicle isNotEqualTo (_lease select 3)}) exitWith {
    // A newer controller changed the engine policy. Preserve its value and do not reacquire
    // until this group's next ownership epoch.
    _vehicle setVariable ["WAIT_Cortex_UnloadPolicyLease",nil,true];
    _vehicle setVariable ["WAIT_Cortex_UnloadPolicyBlocked",[_group,_epoch],true];
    call _removeTracked;
    false
};
if (count _lease == 5) then {
    _lease set [1,_epoch];
    _lease set [4,clientOwner];
    _vehicle setVariable ["WAIT_Cortex_UnloadPolicyLease",_lease,true];
} else {
    private _previous=getUnloadInCombat _vehicle;
    private _applied=[false,false];
    _vehicle setUnloadInCombat _applied;
    _vehicle setVariable ["WAIT_Cortex_UnloadPolicyLease",[_group,_epoch,_previous,_applied,clientOwner],true];
    _vehicle setVariable ["WAIT_Cortex_UnloadPolicyBlocked",nil,true];
};
private _tracked=_group getVariable ["WAIT_Cortex_UnloadPolicyVehicles",[]];
_tracked pushBackUnique _vehicle;
_group setVariable ["WAIT_Cortex_UnloadPolicyVehicles",_tracked,true];
true

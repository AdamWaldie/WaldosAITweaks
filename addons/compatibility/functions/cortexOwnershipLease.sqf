/*
 * Author: WaldoTheWarfighter
 * Purpose: Gives one finite WAIT operation exclusive ownership of the group's WAIT movement domain.
 * Locality / Authority: Call only where the group is local. The public lease follows group locality so a server or headless-client owner can renew or release it.
 * Repeat/JIP: Reacquiring the same owner renews its deadline without replacing the captured baseline.
 * Unknown/malformed existing leases refuse acquisition and release; only their producer or an
 * explicit administrative repair can resolve unrecognised state. Discovery never renews a lease.
 * A competing unexpired WAIT owner is refused; external ownership is handled before acquisition. Repeated release is safe.
 * Acquiring finite movement synchronously retires the ordinary driving FSM and its unchanged
 * speed leases before the new tactical owner is published; later ordinary samples are refused.
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
private _typed=_lease isEqualType [] && {count _lease == 2}
    && {(_lease select 0) isEqualType ""} && {(_lease select 0) != ""}
    && {(_lease select 1) isEqualType 0} && {finite (_lease select 1)};
if (_lease isNotEqualTo [] && {!_typed}) exitWith {false};
private _live=_typed && {serverTime < (_lease select 1)};
if (_acquire) exitWith {
    if (_owner == "" || {!finite _expires} || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
    if (_live && {(_lease select 0) != _owner}) exitWith {
        missionNamespace setVariable [
            "WAIT_Cortex_OwnershipBusyRefusals",
            (missionNamespace getVariable ["WAIT_Cortex_OwnershipBusyRefusals",0]) + 1
        ];
        false
    };
    // Release the ordinary cap while it is still the current owner, before publishing the
    // successor tactical lease or allowing its caller to issue movement/speed commands.
    private _drivingBrain=_group getVariable ["WAIT_Driving_Brain",createHashMap];
    if (count _drivingBrain > 0) then {[_drivingBrain,"TACTICAL_HANDOVER"] call WAIT_fnc_DrivingOperationFinish};
    if (!local _group || {(_group getVariable ["WAIT_Cortex_MovementLease",[]]) isNotEqualTo _lease}
        || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
    _group setVariable ["WAIT_Cortex_MovementLease",[_owner,_expires max (serverTime + 1)],true];
    true
};

if (_lease isEqualTo []) exitWith {true};
if (_owner != "" && {(_lease select 0) != _owner}) exitWith {false};
_group setVariable ["WAIT_Cortex_MovementLease",nil,true];
true

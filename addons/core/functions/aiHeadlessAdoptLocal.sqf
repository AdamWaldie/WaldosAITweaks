/*
 * Author: WaldoTheWarfighter
 * Re-adopts a WAIT-managed group after a confirmed headless-client locality transfer.
 * It reapplies the effective local skill profile, advances the group ownership epoch and wakes
 * discovery on the new owner without changing the transfer destination or issuing movement.
 *
 * Locality / Authority: Must run only on the destination owner after the engine reports the group
 * local. The caller owns distribution; this function never calls setGroupOwner or selects an HC.
 * Repeat/JIP: Idempotent for one provider transfer generation. Repeated notifications refresh local
 * WAIT state only once; a later compatible migration back to the same HC carries a new published revision
 * and therefore retires stale callbacks before discovery resumes.
 *
 * Arguments:
 * 0: group <GROUP> - transferred AI group.
 * 1: previous owner <NUMBER> - owner before the accepted transfer.
 * 2: new owner <NUMBER> - destination server or HC network owner.
 * 3: provider <STRING> - transfer authority label for diagnostics, default "EXTERNAL".
 *
 * Return Value:
 * BOOL - true when WAIT adopted its locally owned group; false when ineligible or not local.
 *
 * Example:
 * [group cursorObject, 2, clientOwner, "COMPANION"] call WAIT_fnc_AIHeadlessAdoptLocal;
 * Result: local AI regain effective WAIT skills and their owner-local jobs are rediscovered.
 *
 * Current callers: WAIT ACE Headless event adapter and the compatibility headless bridge.
 */

params [
    ["_group", grpNull, [grpNull]],
    ["_previousOwner", 2, [0]],
    ["_newOwner", -1, [0]],
    ["_provider", "EXTERNAL", [""]]
];

// Owner 2 is the dedicated/listen server. A compatible manager can deliberately rebalance a group from an HC back
// to server authority, so treating it as an invalid destination leaves stale jobs and skills there.
if (isNull _group || {_newOwner < 2} || {clientOwner != _newOwner} || {!local _group}) exitWith {false};
private _skillsActive = missionNamespace getVariable ["WAIT_AI_RebalanceActive", false];
private _tacticsActive = missionNamespace getVariable ["WAIT_AIPass_Active", false];
if !(_skillsActive || {_tacticsActive}) exitWith {false};

// A compatible transfer publishes an increasing revision before its completion event. Previous/new
// owner alone are not unique: a group may return to the server and later move back to the same HC.
// The compatibility adapter validates the provider record so duplicate delivery stays harmless.
private _providerKey = toUpperANSI _provider;
private _providerRevision = [_group, _newOwner, _providerKey] call WAIT_fnc_CompatibilityHeadlessRevision;
if (_providerKey == "COMPANION" && {_providerRevision < 0}) exitWith {false};
private _adoptionKey = format ["%1:%2:%3:%4", _previousOwner, _newOwner, _providerKey, _providerRevision];
if ((_group getVariable ["WAIT_AI_LastAdoptionKey", ""]) isEqualTo _adoptionKey
    && {(_group getVariable ["WAIT_AI_LastAdoptionOwner", -1]) == _newOwner}) exitWith {true};

private _applied = 0;
if (_skillsActive) then {
    {
        if (local _x && {!isPlayer _x} && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
            && {[_x] call WAIT_fnc_CortexExternalOwner == ""}
            && {[_x] call WAIT_fnc_AIApplyProfile}) then {
            _applied = _applied + 1;
        };
    } forEach units _group;
};

// The compatibility bridge emits only after destination-local adoption completed.  Recover tactical
// semantics here, rather than waiting for the next discovery sweep: CortexLocality retires stale
// callbacks, advances the epoch and reconstructs only durable intent without replaying old moves.
if (_tacticsActive && {!(_group getVariable ["WAIT_AIPass_Adopted",false])}) then {
    [_group,true] call WAIT_fnc_CortexLocality;
};
_group setVariable ["WAIT_AI_LastAdoptionKey", _adoptionKey, true];
_group setVariable ["WAIT_AI_LastAdoptionOwner", _newOwner, true];
_group setVariable ["WAIT_AI_LastHeadlessAdoption", [_newOwner, _applied, toUpperANSI (missionNamespace getVariable ["WAIT_AIRebalance_Profile", "LINE"]), toUpperANSI (missionNamespace getVariable ["WAIT_AIRebalance_Mode", "AUTO"]), serverTime, _providerKey, _providerRevision], true];

[] call WAIT_fnc_CortexDiscover;
[] call WAIT_fnc_SchedulerReconcile;

diag_log format ["[WAIT AI] %1 HC adoption group=%2 previousOwner=%3 owner=%4 applied=%5.", toUpperANSI _provider, _group, _previousOwner, _newOwner, _applied];
true

/*
 * Author: WaldoTheWarfighter
 * Hands a group back to its own orders and removes everything the pass applied to it.
 *
 * Ends any flank drill (re-enabling only the AI features the drill itself disabled), rejoins the
 * search team, removes pass waypoints, restores behaviour and speed without ordering passengers to board,
 * and releases both scoped SPLIT-mode and blanket WAIT-mode COMPAT ownership. Explicit building
 * orders remain in place during ordinary cleanup; a detected Zeus takeover releases them before
 * restoring the rest of Cortex state so no old controller competes with the curator.
 * Locality and authority: call where the group is local; state and flags are machine-local.
 *
 * Review contract: Only the current group owner restores the public COMPAT flag. Changed restoration checkpoints are public and consumed on ownership adoption.
 *
 * A Zeus takeover yields movement, formation, behaviour and speed to the curator while still restoring
 * Cortex-owned AI feature switches and removing Cortex waypoints. Repeat/JIP: only tracked changes are
 * restored; repeated cleanup is harmless and never boards passengers.
 * Public remount intent is cancelled even when owner migration left no local behaviour map.
 * A public actor marker likewise releases only PATH restrictions proven to belong to Cortex.
 * A crew owner also restores any forced speed borrowed for an onboard dismount safe stop.
 * Naval cleanup restores the exact boat forced speed and removes only the token-matched WAIT plan.
 * Arguments:
 * 0: group <GROUP>
 * 1: forget <BOOL> - also clear the managed flag so discovery may pick the group up again
 *    (optional, default: true)
 * 2: transition reason <STRING> - published with the CALM handover. Empty selects
 *    ZEUS_TAKEOVER or EXTERNAL_TAKEOVER when another controller owns the group, otherwise RELEASED
 *    (optional, default: "").
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [_group] call WAIT_fnc_CortexReleaseGroup;
 * Result: the group behaves exactly as it would without the pass.
 *
 * Current callers: Cortex eligibility/stop cleanup, Zeus and AI-order handovers, surrender,
 * defence, garrison and building-clear order entry.
 */

params [["_group", grpNull, [grpNull]], ["_forget", true, [false]], ["_reason", "", [""]]];
if (isNull _group) exitWith {};
private _state = _group getVariable ["WAIT_AIPass_State", createHashMap];
private _yieldToZeus=local _group && {[_group] call WAIT_fnc_CortexZeusHeld};
// The helper covers player members, curator possession, specialist ownership and explicit
// compatibility markers. Do not restore a stale WAIT formation or posture when any one of those
// arrives between the original operation and this release.
private _yieldToExternal=local _group && {!_yieldToZeus} && {[_group] call WAIT_fnc_CortexExternalTakeover};
if (_reason == "") then {
    _reason=if (_yieldToZeus) then {"ZEUS_TAKEOVER"} else {if (_yieldToExternal) then {"EXTERNAL_TAKEOVER"} else {"RELEASED"}};
};
private _externalTakeover=_yieldToZeus || {_yieldToExternal} || {_reason in ["ZEUS_TAKEOVER","EXTERNAL_TAKEOVER"]};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (local _group && {count _operation > 0}) then {
    [_group,_operation getOrDefault ["generation",-1],_reason] call WAIT_fnc_OperationCancel;
};
if ((_state getOrDefault ["navalOperation",[]]) isNotEqualTo []
    || {(_group getVariable ["WAIT_Cortex_NavalOperation",[]]) isNotEqualTo []}) then {
    [_group,_state] call WAIT_fnc_CortexNavalRelease;
};
// Defence in depth for every caller, including a release delivered after locality migration. The
// curator client normally retires these public tokens before dispatch, but cleanup must never depend
// on that client-side write arriving first.
if (_externalTakeover) then {
    _group setVariable ["WAIT_Cortex_CombinedRole",nil,true];
    _group setVariable ["WAIT_Cortex_CombinedApplied",nil,true];
    _group setVariable ["WAIT_Cortex_CombinedOpportunity",nil,true];
};
// Explicit building controllers are movement owners too. Zeus replacement orders must terminate the
// delegated COMPAT loop or native building job before general Cortex state is restored.
if (_externalTakeover) then {
    [_group,false] call WAIT_fnc_CortexBuildingBackendRelease;
    [_group,false] call WAIT_fnc_CortexClearRelease;
    [_group,false] call WAIT_fnc_CortexGarrisonRelease;
};
private _markedSupportHold=(units _group) findIf {_x getVariable ["WAIT_Cortex_SupportPathHold",false]} >= 0;
if (local _group && {count _state > 0 || {_markedSupportHold} || {(_group getVariable ["WAIT_Cortex_Remount",[]]) isNotEqualTo []}}) then {
    if (count (_state getOrDefault ["drill", createHashMap]) > 0) then {[_group, _state, ["RELEASE","ZEUS"] select _externalTakeover] call WAIT_fnc_CortexFlankEnd};
    [_group, _state, false, _externalTakeover, _reason] call WAIT_fnc_CortexRestoreCalm;
};
if (local _group) then {
    private _dangerActor=[_group] call WAIT_fnc_CortexGroupTransmitter;
    if (isNull _dangerActor) then {_dangerActor=leader _group};
    [_dangerActor,"RELEASE"] call WAIT_fnc_DangerReact;
    [_group,"",false] call WAIT_fnc_CortexOwnershipLease;
    // A release or Zeus takeover invalidates any still-published danger handoff before another
    // controller can consume it. Event handlers will create a fresh, owner-local response later.
    _group setVariable ["WAIT_Danger_Response",nil,true];
    _group setVariable ["WAIT_Danger_Action",nil,true];
    private _dangerJob=_group getVariable ["WAIT_Cortex_GroupJob",createHashMap];
    if (count _dangerJob > 0) then {_dangerJob deleteAt "responsiveUntil"};
};
// General driving owns a speed cap, never a route. Its former vehicle may no longer contain this
// group by the time Zeus, a player or another controller takes ownership, so release the tracked
// local set as well as currently occupied vehicles.
if (local _group) then {
    {[_x] call WAIT_fnc_DrivingAssistRelease} forEach (_group getVariable ["WAIT_DrivingAssist_Vehicles",[]]);
    _group setVariable ["WAIT_DrivingAssist_Vehicles",nil];
};
// Release an interrupted cross-group dismount without stranding the vehicle at forced speed zero.
private _releasedVehicles=[];
{
    private _vehicle=vehicle _x;
    if (_vehicle != _x && {!(_vehicle in _releasedVehicles)}
        && {local _vehicle} && {effectiveCommander _vehicle in units _group}) then {
        _releasedVehicles pushBack _vehicle;
        private _saved=_vehicle getVariable ["WAIT_Cortex_DismountForcedSpeed",[]];
        if (_saved isNotEqualTo []) then {_vehicle forceSpeed (_saved param [0,-1])};
        _vehicle setVariable ["WAIT_Cortex_DismountForcedSpeed",nil];
        _vehicle setVariable ["WAIT_Cortex_DismountStopRequest",nil,true];
    };
} forEach units _group;
if (local _group && {_group getVariable ["WAIT_AIPass_DangerBackendDisabledByPass", false]}) then {
    [_group,"dangerDisabled",_group getVariable ["WAIT_AIPass_DangerBackendBaseline", false],true,true] call WAIT_fnc_CompatibilityState;
    _group setVariable ["WAIT_AIPass_DangerBackendDisabledByPass", nil, true];
    _group setVariable ["WAIT_AIPass_DangerBackendBaseline", nil, true];
};
_group setVariable ["WAIT_AIPass_State", nil];
if (_forget) then {_group setVariable ["WAIT_AIPass_Managed", nil]; _group setVariable ["WAIT_Cortex_GroupJob",nil]};

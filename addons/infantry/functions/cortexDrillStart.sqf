/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts the finite scripted FSM which executes one accepted flank, advance, direct assault or coordinated
 * support bound. The FSM observes lifecycle completion; the shared scheduler owns tactical cadence; bounded tactical calculations and actor
 * commands remain in CortexFlankStep so one implementation serves every manoeuvre type.
 * Locality / Authority: Runs on the current group owner. It refuses remote groups and the FSM exits
 * when ownership or the drill token changes. No server-global scan is created.
 * Repeat/JIP: An accepted drill receives one token and one FSM. Repeated calls for the same live token
 * return success without starting another controller. JIP machines do not recreate owner-local FSMs;
 * locality recovery starts from the group state on its new owner.
 * Arguments:
 * 0: group <GROUP> - locally owned group with an accepted drill.
 * 1: drill token <STRING> - token stored in the group's Cortex state.
 * Return Value: Boolean - true when the matching FSM is already running or was started.
 * Current callers: CortexFlankStart, CortexAdvanceStart, CortexAssaultStart and CortexSupportBoundStart.
 * Example: [_group,_drill get "token"] call WAIT_fnc_CortexDrillStart;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_token","",[""]]
];
if (isNull _group || {!local _group} || {_token == ""}) exitWith {false};

private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
private _drill=_state getOrDefault ["drill",createHashMap];
if (count _drill == 0 || {(_drill getOrDefault ["token",""]) != _token}) exitWith {false};

private _existing=_group getVariable ["WAIT_Cortex_DrillFSM",[]];
if (count _existing == 2 && {(_existing select 0) == _token} && {
    private _existingHandle=_existing select 1;
    _existingHandle isEqualType 0 && {_existingHandle > 0} && {!completedFSM _existingHandle}
}) exitWith {true};

private _handle=[_group,_token] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\tacticalDrill.fsm";
if (_handle <= 0) exitWith {
    // Keep an explicit degraded path for malformed or unavailable addon content. The same finite
    // step contract runs through the budgeted WAIT scheduler instead of leaving leased AI state set.
    [WAIT_fnc_CortexFlankStep,createHashMapFromArray [["group",_group],["drillToken",_token]],0]
        call WAIT_fnc_CortexQueueJob;
    true
};

_group setVariable ["WAIT_Cortex_DrillFSM",[_token,_handle]];
true

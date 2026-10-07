/*
 * Author: WaldoTheWarfighter
 * Combines a squad in contact with the squads that came to reinforce it into one prepared assault.
 *
 * The squad in contact becomes the base of fire
 * (its fire control keeps suppressing) and communicating reinforcing squads assault the enemy
 * position from safe separated sides of the line to the base of fire. The server can move two
 * responders concurrently when their approach
 * lanes remain separated; each mover retains alternating fire-team bounds and the gated final
 * assault sequence. Responders keep a fixed side of the supporting-fire axis. Original waypoints
 * survive the finite reservation. An accepted responder can enter the assault directly from its
 * current position; physical rally arrival is not a prerequisite and coordinated responders do not
 * receive an intermediate rally move. Nearby squads exploit a shared contact as soon as
 * communication succeeds instead of waiting for scheduled assembly.
 * It needs an enemy seen in the last 60 s within 400 m, STEADY
 * morale. Communication, available responders and safe avenues determine whether it can happen;
 * a behaviour profile never blocks an otherwise viable shared-contact action. Once responders have
 * acknowledged, the assault launches deterministically. Only one coordinated assault is made per
 * engagement. Responders must be
 * reserved by the server; receiving owners revalidate before execution, including after migration.
 * Locality and authority: call where the requesting group is local.
 *
 * Review contract: Responder selection rechecks eligibility immediately before issuing assault orders, including any Zeus hold received since reinforcement was requested.
 *
 * Reads the server-published bounded responder index rather than scanning all groups.
 * A prepared assault may dispatch from CONTACT or the immediately following SECURITY phase so a
 * short target occlusion cannot strand rallied responders. Once every acknowledged responder has
 * released its matching assault lease, the requester clears its coordinated ownership and resumes
 * the ordinary post-contact chain. Repeat/JIP: current feature gates and eligibility are rechecked;
 * owner jobs are retired on migration. A pending network dispatch does not own the requester: its
 * current native movement or local drill continues until a responder acknowledges a viable assault.
 * At acknowledgement, the matching local drill is released before the requester becomes base of fire.
 * Dispatch is retried on a short cooldown until a responder acknowledges assault; sending
 * a request alone cannot consume the engagement if no responder was eligible.
 * Arguments:
 * 0: group <GROUP> - the squad in contact
 * 1: state <HASHMAP>
 *
 * Return Value:
 * Boolean - true only while this group owns an acknowledged coordinated base-of-fire role;
 * false while dispatch is pending or no coordinated movement formed, so existing movement can continue.
 *
 * Example:
 * [_group, _state] call WAIT_fnc_CortexCoordinatedAssault;
 * Result: two reinforcing squads sweep the enemy position from both flanks while the first squad fires.
 *
 * Current caller: WAIT_fnc_CortexGroupTick.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]]];
private _publicResponders = _group getVariable ["WAIT_Cortex_SupportResponders",[]];
if (_state getOrDefault ["coordinated", false]) exitWith {
    private _active = _publicResponders findIf {
        _x params ["_helper","_token"];
        private _lease = _helper getVariable ["WAIT_AIPass_SupportLease",[]];
        private _status = _helper getVariable ["WAIT_AIPass_SupportStatus",[]];
        count _lease == 6 && {(_lease select 0) == _token} && {(_lease select 1) == _group}
            && {serverTime < (_lease select 2)} && {count _status == 4}
            && {(_status select 0) == _token} && {_status select 2} && {_status select 3}
    };
    if (_active >= 0) then {true} else {
        _state deleteAt "coordinated";
        _state deleteAt "coordinatedPendingUntil";
        false
    }
};
private _pendingUntil = _state getOrDefault ["coordinatedPendingUntil", 0];
if (time < _pendingUntil && {_publicResponders isNotEqualTo []}) exitWith {false};
if (_pendingUntil > 0 && {_publicResponders isEqualTo []}) then {
    // The server found no safe shared avenue and retired the reservation. Drop the asynchronous
    // ownership window on the next group tick so a local advance or flank can start immediately.
    _state deleteAt "coordinatedPendingUntil";
};
if ([_state, "coordinated"] call WAIT_fnc_CortexCooldown) exitWith {false};
if ((_state getOrDefault ["moraleState", "STEADY"]) != "STEADY") exitWith {false};
private _enemyPos = _state getOrDefault ["enemyPos", []];
// Use a local combat-effective anchor so leader loss or reassignment does not suppress an otherwise viable manoeuvre.
private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
if (count _enemyPos < 2 || {time - (_state getOrDefault ["lastSeen", -1e6]) > 60} || {_leader distance2D _enemyPos > 400}) exitWith {false};
private _responders = [];
private _acknowledged = false;
{
    _x params ["_helper","_token"];
    private _lease = _helper getVariable ["WAIT_AIPass_SupportLease",[]];
    private _status = _helper getVariable ["WAIT_AIPass_SupportStatus",[]];
    if (count _lease == 6 && {(_lease select 0) == _token} && {(_lease select 1) == _group}
        && {count _status == 4} && {(_status select 0) == _token}
        && {_status select 2} && {[_helper] call WAIT_fnc_CortexIsEligible}) then {
        if (_status select 3) then {_acknowledged = true};
        _responders pushBack _helper;
    };
} forEach _publicResponders;
if (_acknowledged) exitWith {
    // The requester keeps fighting and may begin a local drill while the network dispatch is pending.
    // Only a real responder acknowledgement justifies the base-of-fire handover. Retire that exact
    // local drill now, before publishing coordinated ownership, so two movement controllers never
    // overlap and a rejected or delayed request never creates an idle planning window.
    if (count (_state getOrDefault ["drill",createHashMap]) > 0) then {
        [_group,_state,"ABORT"] call WAIT_fnc_CortexFlankEnd;
    };
    _state set ["coordinated",true];
    _state deleteAt "coordinatedPendingUntil";
    true
};
if (_responders isEqualTo []) exitWith {false};
[_group,_enemyPos,clientOwner] remoteExecCall ["WAIT_fnc_CortexSupportAssaultServer",2];
[_state,"coordinated",10] call WAIT_fnc_CortexCooldown;
// Suppress duplicate network dispatches for a bounded interval without claiming movement. The
// requester keeps native combat or its local drill until a helper owner acknowledges the assault.
_state set ["coordinatedPendingUntil",time+15];
false // A request alone owns no movement; acknowledgement performs the handover.

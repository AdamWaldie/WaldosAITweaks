/*
 * Author: WaldoTheWarfighter
 * Publishes one fresh visual contact as a bounded combined-arms opportunity.
 * Locality/authority: called on the observing group owner; the server validates and selects assets.
 * It never moves the requester, creates a rally point or waits for another arm to become ready.
 * Repeat/JIP: owner-local cooldown limits requests; opportunities expire and are not replayed to JIP.
 * Contact positions require exactly three finite numeric ATL components, each within +/-1e6m.
 * Invalid payloads reject before local cooldown or server reservation; no live-target fallback is used.
 * Arguments: 0: observing group <GROUP>; 1: group state <HASHMAP>; 2: visible contacts <ARRAY>.
 * Return Value: Boolean, true when a valid opportunity was sent to the server.
 * Current callers: WAIT_fnc_CortexGroupTick.
 * Example: [_group,_state,_visible] call WAIT_fnc_CortexCombinedArmsRequest;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_visible",[],[[]]]];
if (!local _group || {_visible isEqualTo []}) exitWith {false};
if (serverTime < (_state getOrDefault ["combinedArmsDue",0])) exitWith {false};
private _contact=_visible select 0;
private _target=_contact param [0,objNull,[objNull]];
private _position=_contact param [1,[],[[]]];
private _age=_contact param [2,1e6,[0]];
private _confidence=_contact param [5,1,[0]];
if (isNull _target || {!alive _target} || {!finite _age} || {_age < 0} || {_age > 5} || {!finite _confidence} || {_confidence <= 0} || {_confidence > 4} || {count _position != 3}
    || {_position findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} >= 0}) exitWith {false};
_state set ["combinedArmsDue",serverTime+20+random 8];
[_group,_target,+_position,serverTime-_age,_confidence min 2.5] remoteExecCall ["WAIT_fnc_CortexCombinedArmsServer",2];
true

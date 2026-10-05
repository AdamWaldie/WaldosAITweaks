/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts or replaces one finite WAIT operation without allowing stale work to command the group.
 * Locality/authority: Runs on the current group owner; server forwards only through callers that already own dispatch.
 * Repeat/JIP: Replacing an intent increments a public generation. The durable summary is replayable; local routes and callbacks rebuild on ownership migration.
 * Arguments: 0 group <GROUP>; 1 intent <STRING>; 2 objective <OBJECT or ARRAY>; 3 participants <ARRAY>; 4 route <ARRAY>; 5 state <STRING, PLAN>.
 * Return Value: HASHMAP operation, or an empty HASHMAP when the group cannot be owned here.
 * Current callers: Cortex tactical, building, vehicle and air operation starts.
 * Example: [group player, "ADVANCE", getPosATL player, units group player, [], "PLAN"] call WAIT_fnc_OperationStart;
 */
params [
    ["_group",grpNull,[grpNull]], ["_intent","",[""]], ["_objective",objNull,[objNull,[]]],
    ["_participants",[],[[]]], ["_route",[],[[]]], ["_phase","PLAN",[""]]
];
if (isNull _group || {!local _group} || {_intent == ""}) exitWith {createHashMap};
// The shared lifecycle is the final authority boundary for every feature. Check it before
// retiring an earlier route: a delayed job must not cancel WAIT state or issue cleanup after
// Zeus, a player or a specialist controller has claimed the group.
if !([_group,false,false,true] call WAIT_fnc_CortexIsEligible) exitWith {createHashMap};
private _previous=_group getVariable ["WAIT_Operation",createHashMap];
private _generation=(_group getVariable ["WAIT_OperationGeneration",0])+1;
if (count _previous > 0) then {
    [_group,_previous getOrDefault ["generation",-1],"REPLACED"] call WAIT_fnc_OperationCancel;
};
// A finite danger posture is meaningful only for an on-foot group. Aircraft, vehicles and boats
// use this common record too, but must not have their native flight or combat state altered merely
// because a lifecycle record starts. Retain the decision so release is equally narrow later.
private _dangerPosture=(vehicle (leader _group)) isEqualTo (leader _group);
if (_dangerPosture) then {[leader _group,"RELEASE"] call WAIT_fnc_DangerReact};
private _dangerResponse=_group getVariable ["WAIT_Danger_Response",[]];
private _liveDanger=if (count _dangerResponse == 5 && {time < (_dangerResponse select 3)}) then {+_dangerResponse} else {[]};
private _capable=_participants select {alive _x && {local _x} && {!isPlayer _x} && {lifeState _x != "INCAPACITATED"}};
private _operation=createHashMapFromArray [
    ["intent",toUpperANSI _intent], ["generation",_generation], ["ownerEpoch",_group getVariable ["WAIT_AIPass_Epoch",0]],
    ["objective",_objective], ["participants",_capable], ["route",+_route], ["phase",toUpperANSI _phase],
    ["startedAt",time], ["lastProgressAt",time], ["lastProgressPosition",getPosATL leader _group],
    ["participantProgress",_capable apply {[_x,getPosATL _x]}], ["lastProgressActor",objNull],
    ["replans",0], ["recovery",createHashMap], ["unavailable",[]], ["restore",createHashMap],
    ["dangerAtStart",_liveDanger], ["dangerPosture",_dangerPosture], ["cancelReason",""]
];
_group setVariable ["WAIT_OperationGeneration",_generation,true];
_group setVariable ["WAIT_Operation",_operation,true];
_group setVariable ["WAIT_OperationResult",[toUpperANSI _intent,"RUNNING",_generation,serverTime],true];
_operation

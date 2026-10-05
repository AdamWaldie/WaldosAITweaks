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
private _previous=_group getVariable ["WAIT_Operation",createHashMap];
private _generation=(_group getVariable ["WAIT_OperationGeneration",0])+1;
if (count _previous > 0) then {
    [_group,_previous getOrDefault ["generation",-1],"REPLACED"] call WAIT_fnc_OperationCancel;
};
// A finite danger posture is not a tactical movement owner. Release only its owned behaviour/ROE
// values before this operation commits its own intent, while retaining the short-lived danger
// context below so GroupTick can still react to the native observation without recreating a route.
[leader _group,"RELEASE"] call WAIT_fnc_DangerReact;
private _dangerResponse=_group getVariable ["WAIT_Danger_Response",[]];
private _liveDanger=if (count _dangerResponse == 5 && {time < (_dangerResponse select 3)}) then {+_dangerResponse} else {[]};
private _capable=_participants select {alive _x && {local _x} && {!isPlayer _x} && {lifeState _x != "INCAPACITATED"}};
private _operation=createHashMapFromArray [
    ["intent",toUpperANSI _intent], ["generation",_generation], ["ownerEpoch",_group getVariable ["WAIT_AIPass_Epoch",0]],
    ["objective",_objective], ["participants",_capable], ["route",+_route], ["phase",toUpperANSI _phase],
    ["startedAt",time], ["lastProgressAt",time], ["lastProgressPosition",getPosATL leader _group],
    ["participantProgress",_capable apply {[_x,getPosATL _x]}], ["lastProgressActor",objNull],
    ["replans",0], ["recovery",createHashMap], ["unavailable",[]], ["restore",createHashMap], ["dangerAtStart",_liveDanger], ["cancelReason",""]
];
_group setVariable ["WAIT_OperationGeneration",_generation,true];
_group setVariable ["WAIT_Operation",_operation,true];
_group setVariable ["WAIT_OperationResult",[toUpperANSI _intent,"RUNNING",_generation,serverTime],true];
_operation

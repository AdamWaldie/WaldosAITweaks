/*
 * Author: WaldoTheWarfighter
 * Starts a direct close assault when a fresh known hostile is already too near for an advance or
 * flank approach. The function forms a small assault element and a covering element, selects a
 * safe approach and clear-through axis, and hands the committed route to the existing finite
 * tactical-drill FSM. It does not create another scheduler, waypoint or per-unit loop.
 *
 * The assault element moves first while the other element covers, then the covering element closes
 * to the same assault position before both elements clear through the fixed reported objective.
 * The avenue selector rejects water and unsafe firing-lane crossings. Native target knowledge and
 * firing remain enabled. Optional grenades support the movement but never gate it. Casualty
 * replacement, isolated-actor recovery and physical completion are owned by CortexFlankStep.
 *
 * Locality / Authority: call only where the group is local. The function respects external/Zeus
 * ownership, authored hold-style orders and the shared TACTICAL_DRILL movement lease.
 * Repeat/JIP: an active drill, lease or assault cooldown refuses another start. The finite operation
 * carries an owner epoch and generation; locality migration or a newer order cancels it. JIP clients
 * observe published drill state but do not recreate the owner-local FSM.
 *
 * Arguments:
 * 0: group <GROUP> - locally owned infantry group in contact
 * 1: state <HASHMAP> - current WAIT group state
 * 2: enemies <ARRAY> - current WAIT_fnc_CortexKnowledge result
 *
 * Return Value:
 * Boolean - true when a direct close assault started
 *
 * Current caller: WAIT_fnc_CortexTacticalStart.
 *
 * Example:
 * private _started = [_group,_state,_enemies] call WAIT_fnc_CortexAssaultStart;
 * Result: two fire teams commit a safe approach and physical clear-through against the close threat.
 */

params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_enemies",[],[[]]]];
private _refuse={
    params ["_reason",["_detail",[]]];
    private _previous=_group getVariable ["WAIT_Cortex_AssaultRefusal",[]];
    if ((_previous param [0,""]) != _reason) then {
        _group setVariable ["WAIT_Cortex_AssaultRefusal",[_reason,serverTime,_detail],true];
    };
    false
};
if (!local _group || {!([_group,"WAIT_AIPass_Assault_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) exitWith {["DISABLED_OR_REMOTE"] call _refuse};
if (_state getOrDefault ["responding",false] || {_state getOrDefault ["assaulting",false]}) exitWith {["SUPPORT_OWNS_MOVEMENT"] call _refuse};
private _movementLease=_state getOrDefault ["movementLease",[]];
if (count _movementLease == 2 && {time < (_movementLease select 1)}) exitWith {["MOVEMENT_LEASE",_movementLease] call _refuse};
if (count (_state getOrDefault ["drill",createHashMap]) > 0) exitWith {["DRILL_ACTIVE"] call _refuse};
if ([_state,"assault"] call WAIT_fnc_CortexCooldown) exitWith {["COOLDOWN"] call _refuse};
if ((_state getOrDefault ["moraleState","STEADY"]) != "STEADY") exitWith {["MORALE"] call _refuse};
if (_enemies isEqualTo []) exitWith {["NO_TARGET"] call _refuse};

private _contact=_enemies select 0;
_contact params ["_target","_enemyPos","_age","_distance"];
private _closeRange=(missionNamespace getVariable ["WAIT_AIPass_Assault_Range",80]) min 60;
if (isNull _target || {_age > 10} || {_distance > _closeRange} || {_distance < 12}) exitWith {
    ["NO_FRESH_CLOSE_TARGET",[_age,_distance,_closeRange]] call _refuse
};

// Do not replace an explicit hold or security task merely because danger was reported nearby.
private _waypointIndex=currentWaypoint _group;
if (_waypointIndex < count waypoints _group && {
    waypointDescription [_group,_waypointIndex] != "WAIT AI PASS"
    && {!(waypointType [_group,_waypointIndex] in ["MOVE","SAD","DESTROY"])}
}) exitWith {["AUTHORED_OBJECTIVE_TYPE",[waypointType [_group,_waypointIndex]]] call _refuse};

private _onFoot=(units _group) select {
    private _actorMove=_x getVariable ["WAIT_Cortex_ActorMove",[]];
    [_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {isNull objectParent _x}
        && {_x checkAIFeature "PATH"} && {_x checkAIFeature "MOVE"}
        && {count _actorMove != 3 || {time >= (_actorMove select 2)}}
};
if (count _onFoot < 4) exitWith {["INSUFFICIENT_ACTORS",[count _onFoot]] call _refuse};
private _leader=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
private _riflemen=_onFoot select {_x != _leader && {!(([_x] call WAIT_fnc_CortexUnitRole) in ["MG","AT","LEADER"])}};
private _ranked=[];
{_ranked pushBack [_x distance2D _enemyPos,_forEachIndex]} forEach _riflemen;
_ranked sort true;
private _assaultSize=((floor (count _onFoot/2)) min 5) min count _ranked;
if (_assaultSize < 2) exitWith {["NO_ASSAULT_ELEMENT",[count _riflemen]] call _refuse};
private _assaultElement=(_ranked select [0,_assaultSize]) apply {_riflemen select (_x select 1)};
private _coverElement=_onFoot-_assaultElement;
if (count _coverElement < 2) exitWith {["NO_COVER_ELEMENT",[count _coverElement]] call _refuse};

private _start=[0,0,0];
{_start=_start vectorAdd getPosATL _x} forEach _assaultElement;
_start=_start vectorMultiply (1/count _assaultElement);
private _axis=_start getDir _enemyPos;
private _routes=[];
{
    private _direction=_axis+_x;
    _routes pushBack [
        _enemyPos getPos [20,_direction+180],
        _enemyPos getPos [20,_direction]
    ];
} forEach [0,-15,15,-30,30];
// Both teams reach the assault position before the clear-through. The cover element therefore
// lifts its original lane as it follows the first team; treating that expired lane as permanent
// would reject every valid crossing through the objective.
private _route=[_start,_routes,_enemyPos,[],_target] call WAIT_fnc_CortexSelectAvenue;
if (_route isEqualTo []) exitWith {
    [_state,"assault",15] call WAIT_fnc_CortexCooldown;
    ["NO_SAFE_AVENUE",[_start,_enemyPos]] call _refuse
};

private _serial=(missionNamespace getVariable ["WAIT_Cortex_DrillSerial",0])+1;
missionNamespace setVariable ["WAIT_Cortex_DrillSerial",_serial];
private _token=format ["%1:%2",clientOwner,_serial];
private _direction=(_route select 0) getDir (_route select 1);
private _points=[[_route select 0,"ASSAULT"],[_route select 1,"CLEAR"]];
_group setVariable ["WAIT_Cortex_DrillResult",[],true];
_group setVariable ["WAIT_Cortex_DrillFailure",[],true];
_group setVariable ["WAIT_Cortex_DrillReinforcements",[],true];
_state set ["drill",createHashMapFromArray [
    ["token",_token],["target",_target],["type","ASSAULT"],["units",_onFoot],
    ["desiredStrength",count _onFoot],["teams",[_assaultElement,_coverElement]],
    ["teamSizes",[count _assaultElement,count _coverElement]],["teamTurn",0],
    ["points",_points],["index",0],["stage",""],["enemyPos",+_enemyPos],
    ["assaulting",true],["assaultObjective",+_enemyPos],["assaultDirection",_direction],
    ["assaultGrenade",random 1 < ([_group,"assaultChance"] call WAIT_fnc_CortexProfile)],
    ["disabled",[]],["spots",[]],["started",time],["lastStep",time],["boundStart",time],["pauseUntil",0]
]];
if !([_group,"TACTICAL_DRILL",true,serverTime+90] call WAIT_fnc_CortexOwnershipLease) exitWith {
    _state deleteAt "drill";
    ["EXTERNAL_MOVEMENT_BUSY"] call _refuse
};
private _operation=[_group,"ASSAULT",_target,_onFoot,_points apply {_x select 0},"ASSAULT"] call WAIT_fnc_OperationStart;
if (count _operation == 0) exitWith {
    [_group,"TACTICAL_DRILL",false] call WAIT_fnc_CortexOwnershipLease;
    _state deleteAt "drill";
    ["OPERATION_OWNER_LOST"] call _refuse
};
(_state get "drill") set ["operationGeneration",_operation get "generation"];
[_group,_state get "drill","START","ASSAULT_COMMITTED"] call WAIT_fnc_CortexDrillSetStage;
_group setVariable ["WAIT_Cortex_AssaultRefusal",nil,true];
_state set ["movementLease",["TACTICAL_DRILL",time+90]];
missionNamespace setVariable ["WAIT_AIPass_Assaults",(missionNamespace getVariable ["WAIT_AIPass_Assaults",0])+1];
[_group,_token] call WAIT_fnc_CortexDrillStart;
true

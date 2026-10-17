/*
 * Author: WaldoTheWarfighter
 * Purpose: Admit up to two nearby individual indoor investigations from fresh native group knowledge
 * when the contact decision has not committed a whole-group clearance or coordinated task.
 * Locality/authority: Current group owner only. The actor executor revalidates all ownership,
 * native orders and feature gates before movement; this dispatcher issues no movement itself.
 * Repeat/JIP: At most one building selection per eight seconds per owner-local group state.
 * Actor journals, hard deadlines and cooldowns prevent replay; locality does not resume old jobs.
 * Arguments: 0 group <GROUP>, grpNull; 1 group state <HASHMAP>, empty;
 * 2 native knowledge records <ARRAY>, [] (same format as BuildingContactSelect).
 * Return: NUMBER of newly admitted actors, 0..2; admission is not physical entry or clearance.
 * Current callers: CortexGroupTick CONTACT fallback after natural whole-group CLEAR admission.
 * Example: private _admitted=[_group,_state,_knowledge] call WAIT_fnc_IndoorActorDispatch;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_enemies",[],[[]]]];
if (isNull _group || {!local _group} || {_enemies isEqualTo []}
    || {!([_group,"WAIT_AIPass_BuildingCombat_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!([_group,"WAIT_AIPass_Assault_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {[_state,"indoorActors"] call WAIT_fnc_CortexCooldown}) exitWith {0};
private _range=missionNamespace getVariable ["WAIT_AIPass_BuildingCombat_Range",100];
if (!(_range isEqualType 0) || {!finite _range} || {_range <= 0}) exitWith {0};
[_state,"indoorActors",8] call WAIT_fnc_CortexCooldown;
private _selection=[_group,_enemies,_range] call WAIT_fnc_BuildingContactSelect;
if (_selection isEqualTo []) exitWith {0};
_selection params ["_building","_contact","_belief"];
private _ranked=[];
private _actors=(units _group) select [0,16];
{
    if (local _x && {!isPlayer _x} && {[_x] call WAIT_fnc_CortexCombatEffective}
        && {isNull objectParent _x} && {_x knowsAbout _contact >= 1}
        && {_x distance2D (_belief select 0) <= (_range min 40)}
        && {[_x] call WAIT_fnc_IndoorActorGroupAvailable}
        && {(_x getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo []}
        && {serverTime >= (_x getVariable ["WAIT_IndoorActor_Cooldown",-1])}) then {
        // Prefer another available soldier over displacing the squad's leader/formation anchor.
        _ranked pushBack [[0,1] select (_x == leader _group),_x distance2D (_belief select 0),_forEachIndex];
    };
} forEach _actors;
_ranked sort true;
private _admitted=0;
{
    if (_admitted >= 2) exitWith {};
    private _actor=_actors select (_x select 2);
    private _accepted=["START",_actor,createHashMapFromArray [
        ["building",_building],["contact",_contact],["belief",_belief]
    ]] call WAIT_fnc_IndoorActorOperation;
    if (_accepted) then {_admitted=_admitted+1};
} forEach _ranked;
_admitted
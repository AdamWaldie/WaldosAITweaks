/*
 * Author: WaldoTheWarfighter
 * Purpose: Promote one recent, engine-confirmed hostile belief inside a usable building into
 * a natural WAIT clearance operation without replacing explicit orders or manufacturing knowledge.
 * Locality / Authority: Runs only on the local group owner during the bounded CONTACT decision.
 * It uses the stored native believed position, never the hostile's current world position,
 * through the shared selector, bounded to three recent infantry contacts. Natural admission requests four actually eligible
 * actors from the executor; nominal headcount cannot satisfy that threshold.
 * The common building operation remains the sole
 * movement owner. After successful clearance it may return to the unchanged plain authored MOVE,
 * preserving native behaviour/ROE and newer actor orders. Believed inclusion/roof geometry is not proof an enemy remains in that house.
 * Repeat/JIP: A per-group cooldown bounds failed topology and executor admission checks. An accepted clear publishes its
 * normal durable order and is reconstructed by the new owner after locality migration.
 * Arguments: 0: group <GROUP>; 1: group state <HASHMAP>; 2: Cortex knowledge records <ARRAY>.
 * Return Value: Boolean - true only when a physical building-clear operation was started.
 * Current callers: WAIT_fnc_CortexGroupTick before open-ground tactical movement selection.
 * Example: private _started=[_group,_state,_enemies] call WAIT_fnc_CortexBuildingContact;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_state",createHashMap,[createHashMap]],
    ["_enemies",[],[[]]]
];
if (isNull _group || {!local _group} || {_enemies isEqualTo []}) exitWith {false};
if (!([_group,"WAIT_AIPass_BuildingCombat_Enable",true] call WAIT_fnc_CortexFeatureEnabled)
    || {!([_group,"WAIT_AIPass_Assault_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {_group getVariable ["WAIT_AIPass_ClearBuilding",false]}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[_group] call WAIT_fnc_CortexZeusHeld}
    || {[_state,"buildingCombat"] call WAIT_fnc_CortexCooldown}) exitWith {false};

// Do not promote a fresh whole-group clear over an already-owned individual investigation.
// Explicit mission/Zeus clearance still uses its own authoritative replacement path.
if ((_group getVariable ["WAIT_IndoorActor_Actors",[]]) findIf {
    !isNull _x && {group _x == _group}
        && {private _brain=_x getVariable ["WAIT_IndoorActor_Brain",createHashMap];
            count _brain > 0 && {!(_brain getOrDefault ["finished",true])}}
} >= 0) exitWith {false};

private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation > 0) exitWith {false};
private _range=missionNamespace getVariable ["WAIT_AIPass_BuildingCombat_Range",100];
private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _anchor) then {_anchor=leader _group};
if (isNull _anchor) exitWith {false};
private _capable=(units _group) select {
    [_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
        && {isNull objectParent _x} && {simulationEnabled _x} && {!isObjectHidden _x}
};
// A natural entry needs a viable clearing pair plus exterior/reserve strength. Explicit CLEAR
// orders retain their existing executor minimum for mission-authored special cases.
if (count _capable < 4) exitWith {false};

// Shared observation only: the executor still owns actor admission and movement.
private _selection=[_group,_enemies,_range] call WAIT_fnc_BuildingContactSelect;
private _building=_selection param [0,objNull,[objNull]];
private _enemy=_selection param [1,objNull,[objNull]];
private _contactBelief=_selection param [2,[],[[]]];
if (isNull _building) exitWith {
    [_state,"buildingCombat",8] call WAIT_fnc_CortexCooldown;
    false
};

private _accepted=[_group,_building,createHashMapFromArray [["preserveBrain",true],["continueRoute",true],["minimumActors",4],["contact",_enemy],["contactBelief",_contactBelief]]] call WAIT_fnc_CortexClearBuilding;
if (_accepted) then {
    _state set ["buildingContact",[_building,_enemy,serverTime]];
    [_state,"buildingCombat",60] call WAIT_fnc_CortexCooldown;
} else {
    // Eligibility may change after the cheap strength check. Avoid repeating the same
    // building geometry/admission work every decision callback while actors stay protected.
    [_state,"buildingCombat",8] call WAIT_fnc_CortexCooldown;
};
_accepted

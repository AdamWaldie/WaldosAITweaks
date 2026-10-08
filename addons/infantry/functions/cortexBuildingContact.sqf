/*
 * Author: WaldoTheWarfighter
 * Purpose: Promote one recent, engine-confirmed hostile physically inside a usable building into
 * a natural WAIT clearance operation without replacing explicit orders or manufacturing knowledge.
 * Locality / Authority: Runs only on the local group owner during the bounded CONTACT decision.
 * It reads native target knowledge and performs one building/ray check for the nearest eligible
 * contact. The common building operation remains the sole movement owner.
 * Repeat/JIP: A per-group cooldown bounds failed topology checks. An accepted clear publishes its
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

private _operation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _operation > 0) exitWith {false};
private _range=missionNamespace getVariable ["WAIT_AIPass_BuildingCombat_Range",100];
private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _anchor) then {_anchor=leader _group};
if (isNull _anchor) exitWith {false};
private _capable=(units _group) select {
    alive _x && {local _x} && {!isPlayer _x} && {lifeState _x != "INCAPACITATED"}
        && {isNull objectParent _x}
};
// A natural entry needs a viable clearing pair plus exterior/reserve strength. Explicit CLEAR
// orders retain their existing two-person acceptance for mission-authored special cases.
if (count _capable < 4) exitWith {false};

private _records=_enemies select {
    private _enemy=_x param [0,objNull,[objNull]];
    !isNull _enemy && {alive _enemy} && {isNull objectParent _enemy}
        && {(_x param [2,1e6,[0]]) <= 5}
        && {(_x param [3,1e6,[0]]) <= _range}
};
if (_records isEqualTo []) exitWith {false};
if (count _records > 3) then {_records resize 3};
private _enemy=objNull;
private _building=objNull;
// Nearest-building alone also returns houses beside an outdoor actor. Check at most three fresh
// contacts and require model-bound inclusion plus overhead geometry from that same building.
// The strict bound prevents a crowded contact from multiplying geometry work per group tick.
{
    if (!isNull _building) exitWith {};
    private _candidateEnemy=_x select 0;
    private _candidateBuilding=nearestBuilding (getPosATL _candidateEnemy);
    if (!isNull _candidateBuilding && {(_candidateBuilding buildingPos -1) isNotEqualTo []}) then {
        private _bounds=boundingBoxReal _candidateBuilding;
        private _minimum=_bounds param [0,[0,0,0]];
        private _maximum=_bounds param [1,[0,0,0]];
        private _modelPosition=_candidateBuilding worldToModelVisual (getPosWorld _candidateEnemy);
        private _insideBounds=(_modelPosition select 0) >= ((_minimum select 0)-1)
            && {(_modelPosition select 0) <= ((_maximum select 0)+1)}
            && {(_modelPosition select 1) >= ((_minimum select 1)-1)}
            && {(_modelPosition select 1) <= ((_maximum select 1)+1)}
            && {(_modelPosition select 2) >= ((_minimum select 2)-1)}
            && {(_modelPosition select 2) <= ((_maximum select 2)+1)};
        if (_insideBounds) then {
            private _origin=getPosASL _candidateEnemy;
            private _roofHits=lineIntersectsSurfaces [
                _origin vectorAdd [0,0,0.4],_origin vectorAdd [0,0,20],_candidateEnemy,objNull,true,4,"GEOM","NONE"
            ];
            if (_roofHits findIf {(_x select 2) == _candidateBuilding || {(_x select 3) == _candidateBuilding}} >= 0) then {
                _enemy=_candidateEnemy;
                _building=_candidateBuilding;
            };
        };
    };
} forEach _records;
if (isNull _building) exitWith {
    [_state,"buildingCombat",8] call WAIT_fnc_CortexCooldown;
    false
};

private _accepted=[_group,_building,createHashMapFromArray [["preserveBrain",true],["contact",_enemy]]] call WAIT_fnc_CortexClearBuilding;
if (_accepted) then {
    _state set ["buildingContact",[_building,_enemy,serverTime]];
    [_state,"buildingCombat",60] call WAIT_fnc_CortexCooldown;
};
_accepted

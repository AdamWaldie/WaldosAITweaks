/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one finite chassis-orientation response for a stopped tracked fighting vehicle
 * toward the real hostile retained by the current native danger generation.
 * Locality / Authority: Runs on the current group and vehicle owner. It yields to convoy, player,
 * Zeus, specialist, existing operation and movement ownership before issuing a turn command.
 * Repeat/JIP: Acceptance and refusal are recorded by the caller for one danger generation. An
 * accepted response uses the shared operation generation and movement lease; the normal group tick
 * proves alignment or timeout and releases only the matching command owner.
 * Arguments: 0 group <GROUP>; 1 state <HASHMAP>; 2 vehicle <OBJECT>; 3 threat position <ARRAY>;
 * 4 threat object <OBJECT>; 5 danger generation <NUMBER, -1>.
 * Return Value: BOOL - true only when the finite orientation operation was started.
 * Current callers: WAIT_fnc_CortexVehicles for the exact tracked platform carried by native danger.
 * Example: [group driver tank1,state,tank1,getPosATL enemy1,enemy1,4] call WAIT_fnc_CortexVehicleOrient;
 */

params [
    ["_group",grpNull,[grpNull]], ["_state",createHashMap,[createHashMap]],
    ["_vehicle",objNull,[objNull]], ["_threatPosition",[],[[]]],
    ["_threat",objNull,[objNull]], ["_dangerGeneration",-1,[0]]
];
if (isNull _group || {!local _group} || {isNull _vehicle} || {!local _vehicle}
    || {isNull _threat} || {!alive _threat} || {count _threatPosition < 2}
    || {_dangerGeneration < 0}) exitWith {false};
if !([_group,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled
    && {[_group,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) exitWith {false};
if ([_group] call WAIT_fnc_CortexExternalTakeover
    || {_vehicle getVariable ["WAIT_Convoy_Active",false]}
    || {!(_vehicle isKindOf "Tank")} || {!alive _vehicle} || {!canMove _vehicle}
    || {abs speed _vehicle > 5}
    || {count (_group getVariable ["WAIT_Operation",createHashMap]) > 0}
    || {(_state getOrDefault ["movementLease",[]]) isNotEqualTo []}) exitWith {false};
private _commander=effectiveCommander _vehicle;
private _driver=driver _vehicle;
if (isNull _commander || {!alive _commander} || {!local _commander} || {isPlayer _commander}
    || {group _commander != _group} || {!isNull (remoteControlled _commander)}
    || {isNull _driver} || {!alive _driver} || {!local _driver} || {isPlayer _driver}) exitWith {false};
if (_commander knowsAbout _threat <= 0) exitWith {false};
private _relative=_vehicle getRelDir _threatPosition;
if (_relative <= 20 || {_relative >= 340}) exitWith {false};
if !([_group,"VEHICLE_ORIENT",true,serverTime+8] call WAIT_fnc_CortexOwnershipLease) exitWith {false};
private _operation=[_group,"VEHICLE_ORIENT",_threat,crew _vehicle,[],"ORIENTING"] call WAIT_fnc_OperationStart;
if (count _operation == 0) exitWith {
    [_group,"VEHICLE_ORIENT",false] call WAIT_fnc_CortexOwnershipLease;
    false
};
private _operationGeneration=_operation get "generation";
_vehicle sendSimpleCommand (["LEFT","RIGHT"] select (_relative < 180));
_state set ["movementLease",["VEHICLE_ORIENT",time+8]];
_state set ["vehicleOperationGeneration",_operationGeneration];
_vehicle setVariable ["WAIT_Danger_VehicleOrient",[
    _dangerGeneration,_group,+_threatPosition,serverTime+8,_operationGeneration
],true];
true

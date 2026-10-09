/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one short terrain-checked escape by an intact armed ground vehicle after a close
 * hostile, hit or explosion danger generation, without becoming a persistent driving controller.
 * Locality / Authority: Runs on the current group and vehicle owner. It yields to convoy, player,
 * Zeus, specialist, existing operation and foot-element ownership before issuing movement.
 * Repeat/JIP: The caller records both acceptance and refusal for the danger generation. Accepted
 * movement uses the shared operation generation, movement lease and waypoint cleanup, so locality
 * adoption and cancellation follow the same rules as other vehicle movement.
 * Arguments: 0 group <GROUP>; 1 state <HASHMAP>; 2 vehicle <OBJECT>; 3 threat position <ARRAY>;
 * 4 threat object <OBJECT, default objNull>; 5 danger generation <NUMBER, default -1>.
 * Return Value: BOOL - true only when the physical jink operation was started.
 * Current callers: WAIT_fnc_CortexVehicles for the exact platform carried by native danger.
 * Example: [group driver apc1,state,apc1,getPosATL enemy1,enemy1,4] call WAIT_fnc_CortexVehicleJink;
 */

params [
    ["_group",grpNull,[grpNull]], ["_state",createHashMap,[createHashMap]],
    ["_vehicle",objNull,[objNull]], ["_threatPosition",[],[[]]],
    ["_threat",objNull,[objNull]], ["_dangerGeneration",-1,[0]]
];
private _refuse={
    params ["_reason"];
    _state set ["vehicleJinkRefusal",[_reason,serverTime,_vehicle,_dangerGeneration]];
    false
};
if (isNull _group || {!local _group} || {isNull _vehicle} || {!local _vehicle}
    || {count _threatPosition < 2} || {_dangerGeneration < 0}) exitWith {["INVALID_OWNER"] call _refuse};
if !([_group,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled
    && {[_group,"WAIT_AIPass_VehicleJink_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) exitWith {["DISABLED"] call _refuse};
if ([_group] call WAIT_fnc_CortexExternalTakeover
    || {_vehicle getVariable ["WAIT_Convoy_Active",false]}
    || {_vehicle isKindOf "StaticWeapon"} || {!(_vehicle isKindOf "LandVehicle")}
    || {!alive _vehicle} || {!canMove _vehicle} || {abs speed _vehicle > 25}
    || {count (_group getVariable ["WAIT_Operation",createHashMap]) > 0}
    || {(_state getOrDefault ["movementLease",[]]) isNotEqualTo []}) exitWith {["MOVEMENT_OR_PLATFORM"] call _refuse};
private _driver=driver _vehicle;
if (isNull _driver || {!alive _driver} || {!local _driver} || {isPlayer _driver}
    || {group _driver != _group} || {!isNull (remoteControlled _driver)}) exitWith {["DRIVER"] call _refuse};
// A vehicle carrying passengers first owes them the normal task-safe dismount decision. The jink
// is reserved for a crewed fighting platform and cannot drag an unloading squad away.
if ((fullCrew [_vehicle,"",false]) findIf {
    private _role=_x select 1;
    alive (_x select 0) && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
} >= 0) exitWith {["PASSENGERS"] call _refuse};
if ((units _group) findIf {alive _x && {vehicle _x == _x}} >= 0) exitWith {["FOOT_ELEMENT"] call _refuse};
private _hasWeapon=([[-1]]+allTurrets [_vehicle,true]) findIf {
    (_vehicle weaponsTurret _x) findIf {
        private _config=configFile >> "CfgWeapons" >> _x;
        toLowerANSI getText (_config >> "displayName") != "horn"
            && {getText (_config >> "simulation") != "cmlauncher"}
    } >= 0
} >= 0;
if (!_hasWeapon) exitWith {["NO_WEAPON"] call _refuse};
private _origin=getPosATL _vehicle;
private _awayBearing=_threatPosition getDir _origin;
private _candidates=[];
{
    _candidates pushBack [_origin getPos [_x select 0,_awayBearing+(_x select 1)]];
} forEach [[35,0],[40,-30],[40,30],[45,-55],[45,55]];
private _route=[_origin,_candidates,_threatPosition,[],_threat,"VEHICLE"] call WAIT_fnc_CortexSelectAvenue;
if (_route isEqualTo []) exitWith {["NO_ROUTE"] call _refuse};
private _destination=+(_route select -1);
if !([_group,"VEHICLE_JINK",true,serverTime+25] call WAIT_fnc_CortexOwnershipLease) exitWith {["LEASE_BUSY"] call _refuse};
private _operation=[_group,"VEHICLE_JINK",_threat,crew _vehicle,[_destination],"MOVING"] call WAIT_fnc_OperationStart;
if (count _operation == 0) exitWith {
    [_group,"VEHICLE_JINK",false] call WAIT_fnc_CortexOwnershipLease;
    ["OPERATION_REFUSED"] call _refuse
};
_state deleteAt "vehicleJinkRefusal";
[_group,_destination,25] call WAIT_fnc_CortexGroupMove;
_state set ["movementLease",["VEHICLE_JINK",time+25]];
_state set ["vehicleOperationGeneration",_operation get "generation"];
_vehicle setVariable ["WAIT_Danger_VehicleJink",[_dangerGeneration,_group,_destination,serverTime+25],true];
true


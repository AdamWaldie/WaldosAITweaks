/*
 * Author: WaldoTheWarfighter
 * Proves that the packaged engine danger FSM loads, handles one real danger event and releases its
 * temporary actor state. This is the short loader gate used before long parity batches.
 * Locality/authority: scheduled dedicated-server audit; the fixture group remains server-local.
 * Repeat/JIP: creates a fresh disposable group and grenade, then removes every owned fixture.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>; required audit callbacks.
 * Return: Nothing.
 * Current callers: cortexQA/runServer.sqf for the dangerload focus.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQADangerLoad.sqf";
 */
params ["_check","_phase","_wait"];
[createHashMapFromArray [
    ["WAIT_AIPass_Enable",true],
    ["WAIT_AIPass_Contact_Enable",true],
    ["WAIT_AIPass_Danger_Enable",true],
    ["WAIT_AIPass_Flank_Enable",false],
    ["WAIT_AIPass_Advance_Enable",false],
    ["WAIT_AIPass_CoordinatedAssault_Enable",false],
    ["WAIT_AIPass_Regroup_Enable",false],
    ["WAIT_AIPass_Artillery_Enable",false]
]] call WAIT_fnc_CortexTuning;

private _group=createGroup [east,true];
_group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_group setVariable ["acex_headless_blacklist",true,true];
_group setCombatMode "YELLOW";
private _unit=_group createUnit ["O_Soldier_F",[2220,1310,0],[],0,"NONE"];
_unit allowDamage false;
_unit setUnitPos "AUTO";
_unit setVariable ["acex_headless_blacklist",true,true];
_unit setVariable ["WAIT_CortexQA_Label","ENGINE DANGER LOADER",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_unit],true];
private _origin=getPosATL _unit;
private _before=(_group getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0];
["Danger FSM loader gate","A real grenade detonates beside one server-local soldier. The packaged engine FSM must record the event, produce a finite physical reflex and then restore its exact temporary stance ownership.",_origin] call _phase;
private _grenade=createVehicle ["GrenadeHand",_origin getPos [7,90],[],0,"CAN_COLLIDE"];
private _configuredFSM=getText (configFile >> "CfgVehicles" >> typeOf _unit >> "fsmDanger");
private _threatGroup=createGroup [west,true];
_threatGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_threatGroup setVariable ["acex_headless_blacklist",true,true];
private _threat=_threatGroup createUnit ["B_Soldier_F",_origin getPos [45,270],[],0,"NONE"];
_threat allowDamage false;
_threat setVariable ["acex_headless_blacklist",true,true];
_threat setDir (_threat getDir _unit);
_threat reveal [_unit,4];
_unit reveal [_threat,4];
[_threat,_unit] spawn {
    params ["_threat","_unit"];
    sleep 1;
    for "_shot" from 1 to 3 do {
        if (!alive _threat || {!alive _unit}) exitWith {};
        _threat setDir (_threat getDir _unit);
        _threat forceWeaponFire [currentWeapon _threat,currentMuzzle _threat];
        sleep 0.4;
    };
};
[
    "DANGERLOAD-configured-fsm",
    toLowerANSI _configuredFSM == "\z\waldo_ai_tweaks\addons\infantry\fsm\danger.fsm",
    _configuredFSM
] call _check;
private _accepted=[{
    ((_group getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0]) > _before
        && {(_unit getVariable ["WAIT_Danger_EngineResponse",[]]) isNotEqualTo []}
},12] call _wait;
private _physical=[{
    stance _unit in ["CROUCH","PRONE"]
        || {_unit distance2D _origin >= 1.5}
},12] call _wait;
["DANGERLOAD-engine-event-accepted",_accepted,str [_group getVariable ["WAIT_Danger_EngineStats",createHashMap],_unit getVariable ["WAIT_Danger_EngineResponse",[]]]] call _check;
["DANGERLOAD-physical-reflex",_accepted && {_physical},str [unitPos _unit,stance _unit,_unit distance2D _origin,_unit getVariable ["WAIT_Danger_EngineStanceLease",[]]]] call _check;

private _released=[{
    (_unit getVariable ["WAIT_Danger_EngineResponse",[]]) isEqualTo []
        && {(_unit getVariable ["WAIT_Danger_EngineStanceLease",[]]) isEqualTo []}
        && {toUpperANSI unitPos _unit == "AUTO"}
},30] call _wait;
["DANGERLOAD-finite-exact-release",_accepted && {_released},str [unitPos _unit,_unit getVariable ["WAIT_Danger_EngineResponse",[]],_unit getVariable ["WAIT_Danger_EngineStanceLease",[]]]] call _check;

deleteVehicle _grenade;
deleteVehicle _threat;
deleteGroup _threatGroup;
deleteVehicle _unit;
deleteGroup _group;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];

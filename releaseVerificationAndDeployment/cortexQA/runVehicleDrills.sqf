/*
 * Author: WaldoTheWarfighter
 * Checks targetless danger, static-emplacement crew safety, mixed mounted/foot observer
 * classification, effective-commander mounted-contact persistence, contact dismount,
 * calm remount and damaged-armour withdrawal using live vehicles, including an active withdrawal
 * migrating from the server to a real headless owner before Zeus replacement.
 * Locality/authority: scheduled server creates disposable fixtures; production Cortex code commands
 * each current owner, and the migration case deliberately transfers its crew group and vehicle.
 * Repeat/JIP: fresh fixtures and public observer state; caller restores tuning, actors are deleted.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>, required callbacks.
 * Return: Nothing. Current caller: cortexQAServer.sqf.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAVehicles.sqf";
 */
params ["_check","_phase","_wait"];
// Use an engine-fired hostile grenade rather than an unattributed createVehicle projectile. Capturing the
// real FiredMan projectile preserves native shot ownership and danger delivery while the audit only
// relocates the physical shot into the isolated fixture. The excluded firer is cleaned after fuse.
private _spawnRealGrenade={
    params [["_position",[0,0,0],[[]]]];
    private _sourceGroup=createGroup [west,true];
    _sourceGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _sourceGroup setVariable ["acex_headless_blacklist",true,true];
    _sourceGroup setVariable ["WAIT_AIPass_Exclude",true,true];
    _sourceGroup setCombatMode "BLUE";
    private _sourcePosition=+_position;
    _sourcePosition set [2,0];
    _sourcePosition=_sourcePosition getPos [80,0];
    private _source=_sourceGroup createUnit ["B_Soldier_F",_sourcePosition,[],0,"NONE"];
    _source allowDamage false;
    _source hideObjectGlobal true;
    _source disableAI "MOVE";
    _source disableAI "TARGET";
    _source disableAI "AUTOTARGET";
    _source setVariable ["acex_headless_blacklist",true,true];
    _source setVariable ["WAIT_CortexQA_Projectile",objNull];
    _source addMagazine "HandGrenade";
    _source addEventHandler ["FiredMan",{
        params ["_unit","","","","","","_projectile"];
        _unit setVariable ["WAIT_CortexQA_Projectile",_projectile];
    }];
    _source forceWeaponFire ["HandGrenadeMuzzle","HandGrenadeMuzzle"];
    private _deadline=diag_tickTime+2;
    waitUntil {
        sleep 0.05;
        !isNull (_source getVariable ["WAIT_CortexQA_Projectile",objNull]) || {diag_tickTime >= _deadline}
    };
    private _grenade=_source getVariable ["WAIT_CortexQA_Projectile",objNull];
    if (isNull _grenade) then {
        diag_log "WAIT CORTEX QA FIXTURE ERROR: native grenade firing produced no projectile";
    } else {
        private _spawn=+_position;
        _spawn set [2,(_spawn param [2,0]) + 2];
        _grenade setPosATL _spawn;
        _grenade setVelocity [0,0,-4];
    };
    [_source,_sourceGroup] spawn {
        params ["_source","_sourceGroup"];
        sleep 12;
        deleteVehicle _source;
        deleteGroup _sourceGroup;
    };
    _grenade
};
[createHashMapFromArray [
    ["WAIT_AIPass_Enable",true],["WAIT_AIPass_Contact_Enable",true],
    ["WAIT_AIPass_Regroup_Enable",false],["WAIT_AIPass_Flank_Enable",false],["WAIT_AIPass_Advance_Enable",false],
    ["WAIT_AIPass_Morale_Enable",false],["WAIT_AIPass_ContactReports_Enable",false],
    ["WAIT_AIPass_Reinforce_Enable",false],["WAIT_AIPass_CoordinatedAssault_Enable",false],
    ["WAIT_AIPass_Artillery_Enable",false],["WAIT_AIPass_FireControl_Enable",false],
    ["WAIT_AIPass_Vehicles_Enable",true],["WAIT_AIPass_VehicleDismount_Enable",false],
    ["WAIT_AIPass_VehicleRemount_Enable",true],["WAIT_AIPass_VehicleWithdraw_Enable",false],
    ["WAIT_AIPass_VehicleGunnery_Enable",false],["WAIT_AIPass_PostContact_Enable",false]
]] call WAIT_fnc_CortexTuning;
private _pin={params ["_group"]; _group setVariable ["WAIT_Headless_ExcludeGroup",true,true]; _group setVariable ["acex_headless_blacklist",true,true]; {_x setVariable ["acex_headless_blacklist",true,true]} forEach units _group};
private _recordVehicleCheck = _check;

// A separate, enemy-free fixture proves that a native explosion can invoke only passenger safety.
// It does not inject danger state or target knowledge, and it starts moving before the stimulus.
[createHashMapFromArray [
    ["WAIT_AIPass_Enable",true],["WAIT_AIPass_Danger_Enable",true],
    ["WAIT_AIPass_Vehicles_Enable",true],["WAIT_AIPass_VehicleDismount_Enable",true],
    ["WAIT_AIPass_VehicleRemount_Enable",false],["WAIT_AIPass_VehicleWithdraw_Enable",true],
    ["WAIT_AIPass_VehicleGunnery_Enable",true]
]] call WAIT_fnc_CortexTuning;
private _dangerTruck=createVehicle ["O_Truck_03_transport_F",[1600,900,0],[],0,"NONE"];
createVehicleCrew _dangerTruck;
_dangerTruck allowDamage false;
private _dangerCrewGroup=group driver _dangerTruck;
[_dangerCrewGroup] call _pin;
_dangerCrewGroup setCombatMode "BLUE";
private _dangerPassengerGroup=createGroup [east,true];
[_dangerPassengerGroup] call _pin;
_dangerPassengerGroup setCombatMode "BLUE";
private _dangerPassengers=[];
for "_i" from 0 to 1 do {
    private _unit=_dangerPassengerGroup createUnit ["O_Soldier_F",[1600+_i*2,894,0],[],0,"NONE"];
    _unit allowDamage false;
    _unit setVariable ["WAIT_CortexQA_Label",format ["TARGETLESS DANGER PASSENGER %1",_i+1],true];
    _unit assignAsCargo _dangerTruck;
    [_unit] orderGetIn true;
    _unit moveInCargo _dangerTruck;
    _dangerPassengers pushBack _unit;
};
private _dangerCrew=crew _dangerTruck select {group _x == _dangerCrewGroup};
private _dangerWaypoint=_dangerCrewGroup addWaypoint [[1850,900,0],0];
_dangerWaypoint setWaypointType "MOVE";
_dangerWaypoint setWaypointCompletionRadius 8;
_dangerCrewGroup setCurrentWaypoint _dangerWaypoint;
missionNamespace setVariable ["WAIT_CortexQA_Actors",_dangerPassengers+_dangerCrew,true];
["Vehicle targetless danger","The moving truck has no enemy. A real explosion must produce a bounded safe stop and passenger exit while its operating crew stays aboard. It must not invent a target, start gunnery or withdraw the vehicle.",[1600,900,0]] call _phase;
private _dangerReady=[{
    missionNamespace getVariable ["WAIT_AIPass_Active",false]
        && {_dangerCrewGroup getVariable ["WAIT_AIPass_Managed",false]}
        && {_dangerPassengerGroup getVariable ["WAIT_AIPass_Managed",false]}
        && {abs speed _dangerTruck > 5}
},45] call _wait;
["DANGER-VEHICLE-fixture-moving",_dangerReady,str [speed _dangerTruck,getPosATL _dangerTruck]] call _check;
private _dangerStart=getPosATL _dangerTruck;
private _dangerProjectile=[_dangerStart vectorAdd [6,0,0]] call _spawnRealGrenade;
private _dangerSubmitted=false;
private _dangerLease=false;
private _dangerStopped=false;
private _dangerExited=[{
    private _stats=_dangerCrewGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
    _dangerSubmitted=_dangerSubmitted || {(_stats getOrDefault ["acceptedRecords",0]) > 0 && {"EXPLOSION" in (_stats getOrDefault ["lastCauses",[]])}};
    private _crewState=_dangerCrewGroup getVariable ["WAIT_AIPass_State",createHashMap];
    _dangerLease=_dangerLease || {count (_crewState getOrDefault ["dangerDismount",[]]) == 7}
        || {count (_dangerTruck getVariable ["WAIT_Cortex_OnboardDanger",[]]) == 4};
    _dangerStopped=_dangerStopped || {abs speed _dangerTruck < 1};
    _dangerPassengers findIf {!alive _x || {vehicle _x == _dangerTruck}} < 0
},45] call _wait;
private _dangerPassengerState=_dangerPassengerGroup getVariable ["WAIT_AIPass_State",createHashMap];
private _dangerOwnedExit=_dangerPassengers findIf {
    private _passenger=_x;
    (_dangerPassengerState getOrDefault ["dismounted",[]]) findIf {(_x select 0) == _passenger && {(_x select 1) == _dangerTruck}} < 0
} < 0;
private _dangerDriver=driver _dangerTruck;
private _dangerAssignedTarget=assignedTarget _dangerDriver;
private _dangerNoTarget=isNull _dangerAssignedTarget;
private _dangerNoWithdrawal=(_dangerCrewGroup getVariable ["WAIT_Cortex_WithdrawalIntent",[]]) isEqualTo []
    && {(_dangerCrewGroup getVariable ["WAIT_AIPass_PublicPhase","CALM"]) != "RETREAT"};
["DANGER-VEHICLE-native-explosion",_dangerSubmitted,str (_dangerCrewGroup getVariable ["WAIT_Danger_EngineStats",createHashMap])] call _check;
["DANGER-VEHICLE-bounded-safety-lease",_dangerLease,str [_dangerCrewGroup getVariable ["WAIT_AIPass_State",createHashMap],_dangerTruck getVariable ["WAIT_Cortex_OnboardDanger",[]]]] call _check;
["DANGER-VEHICLE-safe-stop",_dangerStopped,str [speed _dangerTruck,_dangerTruck getVariable ["WAIT_Cortex_DismountStopRequest",[]]]] call _check;
["DANGER-VEHICLE-passengers-physically-exit",_dangerReady && {_dangerExited} && {_dangerOwnedExit},str (_dangerPassengers apply {[vehicle _x,assignedVehicle _x,currentCommand _x]})] call _check;
["DANGER-VEHICLE-operating-crew-retained",_dangerCrew findIf {!alive _x || {vehicle _x != _dangerTruck}} < 0,str (_dangerCrew apply {vehicle _x})] call _check;
["DANGER-VEHICLE-no-invented-combat",_dangerNoTarget && {_dangerNoWithdrawal},str [_dangerAssignedTarget,_dangerCrewGroup getVariable ["WAIT_Cortex_WithdrawalIntent",[]],_dangerCrewGroup getVariable ["WAIT_AIPass_PublicPhase",""]]] call _check;
deleteVehicle _dangerProjectile;
{deleteVehicle _x} forEach (_dangerPassengers+_dangerCrew+[_dangerTruck]);
deleteGroup _dangerPassengerGroup;
deleteGroup _dangerCrewGroup;

// An armed crew-only vehicle receives the same real explosive danger twice. With the finite jink
// disabled it must not acquire a WAIT route. Once enabled, the next native danger generation may
// own one short terrain-checked escape. The fixture never injects danger, velocity or a destination.
[createHashMapFromArray [
    ["WAIT_AIPass_Enable",true],["WAIT_AIPass_Danger_Enable",true],
    ["WAIT_AIPass_Vehicles_Enable",true],["WAIT_AIPass_VehicleJink_Enable",false],
    ["WAIT_AIPass_VehicleDismount_Enable",false],["WAIT_AIPass_VehicleWithdraw_Enable",false],
    ["WAIT_AIPass_VehicleGunnery_Enable",false]
]] call WAIT_fnc_CortexTuning;
private _jinkVehicle=createVehicle ["O_APC_Wheeled_02_rcws_v2_F",[1480,880,0],[],0,"NONE"];
createVehicleCrew _jinkVehicle;
_jinkVehicle allowDamage false;
private _jinkGroup=group driver _jinkVehicle;
[_jinkGroup] call _pin;
_jinkGroup setCombatMode "BLUE";
private _jinkCrew=crew _jinkVehicle;
{_x allowDamage false; _x setVariable ["WAIT_CortexQA_Label",format ["DANGER JINK CREW %1",_forEachIndex+1],true]} forEach _jinkCrew;
missionNamespace setVariable ["WAIT_CortexQA_Actors",_jinkCrew,true];
["Danger FSM: finite vehicle jink","A crew-only armed APC receives a real nearby explosion. Disabled, WAIT must not take movement. Enabled, one later danger generation may make a short physical terrain-checked escape while retaining every crew member.",getPosATL _jinkVehicle] call _phase;
private _jinkReady=[{
    missionNamespace getVariable ["WAIT_AIPass_Active",false]
        && {_jinkGroup getVariable ["WAIT_AIPass_Managed",false]}
        && {count _jinkCrew >= 2}
},30] call _wait;
private _jinkDisabledOrigin=getPosATL _jinkVehicle;
private _jinkDisabledBlast=[_jinkVehicle modelToWorld [7,0,0]] call _spawnRealGrenade;
sleep 6;
private _jinkState=_jinkGroup getVariable ["WAIT_AIPass_State",createHashMap];
private _jinkDisabledNoOwner=(_jinkVehicle getVariable ["WAIT_Danger_VehicleJink",[]]) isEqualTo []
    && {(_jinkState getOrDefault ["movementLease",[]]) param [0,""] != "VEHICLE_JINK"};
["DANGER-VEHICLE-jink-disabled",_jinkReady && {_jinkDisabledNoOwner},str [_jinkVehicle getVariable ["WAIT_Danger_VehicleJink",[]],_jinkState getOrDefault ["movementLease",[]],_jinkVehicle distance2D _jinkDisabledOrigin]] call _check;
deleteVehicle _jinkDisabledBlast;
[createHashMapFromArray [["WAIT_AIPass_VehicleJink_Enable",true]]] call WAIT_fnc_CortexTuning;
private _jinkOrigin=getPosATL _jinkVehicle;
private _jinkBlast=[_jinkVehicle modelToWorld [7,0,0]] call _spawnRealGrenade;
private _jinkOwned=[{
    private _state=_jinkGroup getVariable ["WAIT_AIPass_State",createHashMap];
    count (_jinkVehicle getVariable ["WAIT_Danger_VehicleJink",[]]) == 4
        && {(_state getOrDefault ["movementLease",[]]) param [0,""] == "VEHICLE_JINK"}
},25] call _wait;
private _jinkMoved=[{
    _jinkVehicle distance2D _jinkOrigin >= 20
},35] call _wait;
private _jinkCrewRetained=_jinkCrew findIf {!alive _x || {vehicle _x != _jinkVehicle}} < 0;
["DANGER-VEHICLE-jink-operation-owned",_jinkReady && {_jinkOwned},str [_jinkVehicle getVariable ["WAIT_Danger_VehicleJink",[]],
    (_jinkGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["movementLease",[]],
    (_jinkGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["vehicleDangerJink",[]],
    (_jinkGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["vehicleJinkRefusal",[]],
    (_jinkGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["dangerDismount",[]],
    _jinkGroup getVariable ["WAIT_Danger_VehicleContext",[]],_jinkGroup getVariable ["WAIT_Operation",createHashMap],
    [_jinkGroup] call WAIT_fnc_CortexExternalTakeover,speed _jinkVehicle]] call _check;
["DANGER-VEHICLE-jink-physical-travel",_jinkOwned && {_jinkMoved},str [_jinkOrigin,getPosATL _jinkVehicle,_jinkVehicle distance2D _jinkOrigin]] call _check;
["DANGER-VEHICLE-jink-crew-retained",_jinkCrewRetained,str (_jinkCrew apply {[vehicle _x,assignedVehicleRole _x]})] call _check;
deleteVehicle _jinkBlast;
{deleteVehicle _x} forEach (_jinkCrew+[_jinkVehicle]);
deleteGroup _jinkGroup;
// A stopped tracked fighting vehicle must physically turn its hull toward a naturally detected
// hostile while the gunnery gate is enabled, without receiving a waypoint or changing position.
// A first naturally detected hostile with the gate disabled proves that danger alone cannot acquire
// the orientation owner. A replacement hostile then creates a fresh native detection generation.
[createHashMapFromArray [
    ["WAIT_AIPass_Enable",true],["WAIT_AIPass_Danger_Enable",true],
    ["WAIT_AIPass_Vehicles_Enable",true],["WAIT_AIPass_VehicleGunnery_Enable",false],
    ["WAIT_AIPass_VehicleJink_Enable",false],["WAIT_AIPass_VehicleDismount_Enable",false],
    ["WAIT_AIPass_VehicleWithdraw_Enable",false]
]] call WAIT_fnc_CortexTuning;
private _orientVehicle=createVehicle ["O_MBT_02_cannon_F",[1580,880,0],[],0,"NONE"];
createVehicleCrew _orientVehicle;
_orientVehicle allowDamage false;
_orientVehicle setDir 0;
private _orientGroup=group driver _orientVehicle;
[_orientGroup] call _pin;
_orientGroup setCombatMode "RED";
private _orientCrew=crew _orientVehicle;
{_x allowDamage false; _x setVariable ["WAIT_CortexQA_Label",format ["DANGER ORIENT CREW %1",_forEachIndex+1],true]} forEach _orientCrew;
private _orientDisabledTargetGroup=createGroup [west,true];
private _orientDisabledTarget=_orientDisabledTargetGroup createUnit ["B_Soldier_F",[1650,880,0],[],0,"NONE"];
removeAllWeapons _orientDisabledTarget;
_orientDisabledTarget allowDamage false;
_orientDisabledTarget disableAI "PATH";
missionNamespace setVariable ["WAIT_CortexQA_Actors",_orientCrew+[_orientDisabledTarget],true];
["Danger FSM: finite tracked-vehicle orientation","A stationary tank naturally detects a hostile off its bow. Disabled, WAIT must not take orientation ownership. Enabled, a fresh hostile may trigger one bounded hull turn with no waypoint or travel.",getPosATL _orientVehicle] call _phase;
private _orientReady=[{
    missionNamespace getVariable ["WAIT_AIPass_Active",false]
        && {_orientGroup getVariable ["WAIT_AIPass_Managed",false]}
        && {count _orientCrew >= 3}
},30] call _wait;
private _orientDisabledKnown=[{(effectiveCommander _orientVehicle) knowsAbout _orientDisabledTarget > 0},20] call _wait;
sleep 3;
private _orientState=_orientGroup getVariable ["WAIT_AIPass_State",createHashMap];
private _orientDisabledNoOwner=(_orientVehicle getVariable ["WAIT_Danger_VehicleOrient",[]]) isEqualTo []
    && {(_orientState getOrDefault ["movementLease",[]]) param [0,""] != "VEHICLE_ORIENT"};
["DANGER-VEHICLE-orient-disabled",_orientReady && {_orientDisabledKnown} && {_orientDisabledNoOwner},str [_orientVehicle getDir _orientDisabledTarget,_orientState getOrDefault ["movementLease",[]]]] call _check;
deleteVehicle _orientDisabledTarget;
deleteGroup _orientDisabledTargetGroup;
[createHashMapFromArray [["WAIT_AIPass_VehicleGunnery_Enable",true]]] call WAIT_fnc_CortexTuning;
private _orientTargetGroup=createGroup [west,true];
private _orientTarget=_orientTargetGroup createUnit ["B_Soldier_F",[1650,880,0],[],0,"NONE"];
removeAllWeapons _orientTarget;
_orientTarget allowDamage false;
_orientTarget disableAI "PATH";
_orientTarget setVariable ["WAIT_CortexQA_Label","DANGER ORIENT HOSTILE",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_orientCrew+[_orientTarget],true];
private _orientOrigin=getPosATL _orientVehicle;
private _orientOwned=[{
    count (_orientVehicle getVariable ["WAIT_Danger_VehicleOrient",[]]) == 5
        && {private _state=_orientGroup getVariable ["WAIT_AIPass_State",createHashMap];
            (_state getOrDefault ["movementLease",[]]) param [0,""] == "VEHICLE_ORIENT"}
},25] call _wait;
private _orientAligned=[{
    private _relative=_orientVehicle getRelDir _orientTarget;
    _relative <= 20 || {_relative >= 340}
},15] call _wait;
private _orientCrewRetained=_orientCrew findIf {!alive _x || {vehicle _x != _orientVehicle}} < 0;
["DANGER-VEHICLE-orient-operation-owned",_orientReady && {_orientOwned},str [_orientVehicle getVariable ["WAIT_Danger_VehicleOrient",[]],(_orientGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["movementLease",[]]]] call _check;
["DANGER-VEHICLE-orient-physical-alignment",_orientOwned && {_orientAligned},str [getDir _orientVehicle,_orientVehicle getDir _orientTarget,_orientVehicle getRelDir _orientTarget]] call _check;
["DANGER-VEHICLE-orient-no-travel",_orientVehicle distance2D _orientOrigin < 8,str [_orientOrigin,getPosATL _orientVehicle,_orientVehicle distance2D _orientOrigin]] call _check;
["DANGER-VEHICLE-orient-crew-retained",_orientCrewRetained,str (_orientCrew apply {[vehicle _x,assignedVehicleRole _x]})] call _check;
deleteVehicle _orientTarget;
{deleteVehicle _x} forEach (_orientCrew+[_orientVehicle]);
deleteGroup _orientTargetGroup;
deleteGroup _orientGroup;

// Empty and useful emplacements share the same real explosion stimulus. Only the empty exact
// platform may release its crew: the armed emplacement must remain manned, and neither case may
// manufacture a target or route. This exercises the static domain which ordinary driving cannot.
private _emptyStatic=createVehicle ["O_HMG_01_F",[1580,1000,0],[],0,"NONE"];
private _armedStatic=createVehicle ["O_HMG_01_F",[1660,1000,0],[],0,"NONE"];
createVehicleCrew _emptyStatic;
createVehicleCrew _armedStatic;
_emptyStatic allowDamage false;
_armedStatic allowDamage false;
_emptyStatic setVehicleAmmo 0;
private _emptyStaticGroup=group gunner _emptyStatic;
private _armedStaticGroup=group gunner _armedStatic;
[_emptyStaticGroup] call _pin;
[_armedStaticGroup] call _pin;
_emptyStaticGroup setCombatMode "BLUE";
_armedStaticGroup setCombatMode "BLUE";
private _emptyStaticCrew=crew _emptyStatic;
private _armedStaticCrew=crew _armedStatic;
missionNamespace setVariable ["WAIT_CortexQA_Actors",_emptyStaticCrew+_armedStaticCrew,true];
["Danger FSM: static emplacement survival","Two static guns receive real nearby explosions without an enemy. The empty gun must release its own crew; the useful armed gun must remain manned. Neither may receive a target or movement route.",getPosATL _emptyStatic] call _phase;
private _staticReady=[{
    _emptyStaticGroup getVariable ["WAIT_AIPass_Managed",false]
        && {_armedStaticGroup getVariable ["WAIT_AIPass_Managed",false]}
        && {!someAmmo _emptyStatic} && {someAmmo _armedStatic}
},30] call _wait;
private _emptyBlast=[(getPosATL _emptyStatic) vectorAdd [6,0,0]] call _spawnRealGrenade;
private _armedBlast=[(getPosATL _armedStatic) vectorAdd [6,0,0]] call _spawnRealGrenade;
private _emptyReleased=[{
    _emptyStaticCrew findIf {alive _x && {vehicle _x == _emptyStatic}} < 0
},30] call _wait;
private _armedRetained=_armedStaticCrew findIf {!alive _x || {vehicle _x != _armedStatic}} < 0;
private _staticNoTargets=(_emptyStaticCrew+_armedStaticCrew) findIf {
    !isNull (assignedTarget _x)
} < 0;
["DANGER-STATIC-empty-crew-released",_staticReady && {_emptyReleased},str [_emptyStatic getVariable ["WAIT_Danger_AbandonReason",[]],_emptyStaticCrew apply {vehicle _x}]] call _check;
["DANGER-STATIC-useful-crew-retained",_staticReady && {_armedRetained},str [_armedStatic getVariable ["WAIT_Danger_AbandonReason",[]],_armedStaticCrew apply {vehicle _x}]] call _check;
["DANGER-STATIC-no-invented-combat",_staticNoTargets,str ((_emptyStaticCrew+_armedStaticCrew) apply {[assignedTarget _x,currentCommand _x]})] call _check;
deleteVehicle _emptyBlast;
deleteVehicle _armedBlast;
{deleteVehicle _x} forEach (_emptyStaticCrew+_armedStaticCrew+[_emptyStatic,_armedStatic]);
deleteGroup _emptyStaticGroup;
deleteGroup _armedStaticGroup;

// A three-person armoured crew proves that mounted danger persistence belongs only to the effective
// commander. The audit supplies a real visible hostile and reads native knowledge; it does not reveal,
// assign a target, issue fire or inject a danger record. Other crew may receive engine callbacks, but
// they must finish their reflex instead of multiplying the vehicle response.
[createHashMapFromArray [
    ["WAIT_AIPass_Enable",true],["WAIT_AIPass_Danger_Enable",true],
    ["WAIT_AIPass_Vehicles_Enable",true],["WAIT_AIPass_VehicleDismount_Enable",false],
    ["WAIT_AIPass_VehicleRemount_Enable",false],["WAIT_AIPass_VehicleWithdraw_Enable",false],
    ["WAIT_AIPass_VehicleGunnery_Enable",false]
]] call WAIT_fnc_CortexTuning;
private _contactVehicle=createVehicle ["O_APC_Wheeled_02_rcws_v2_F",[1650,1050,0],[],0,"NONE"];
createVehicleCrew _contactVehicle;
_contactVehicle allowDamage false;
_contactVehicle setDir 0;
private _contactCrewGroup=group effectiveCommander _contactVehicle;
[_contactCrewGroup] call _pin;
_contactCrewGroup setCombatMode "RED";
// Keep one foot soldier in the crew group and make him leader. The native vehicle event must still
// be classified from the mounted observer; using an arbitrary group anchor would misclassify this
// as a foot reaction and suppress the mounted combat handoff.
private _contactFootLeader=_contactCrewGroup createUnit ["O_Soldier_F",[1635,1050,0],[],0,"NONE"];
_contactFootLeader allowDamage false;
_contactFootLeader disableAI "PATH";
_contactFootLeader disableAI "TARGET";
_contactFootLeader disableAI "AUTOTARGET";
_contactFootLeader setVariable ["WAIT_CortexQA_Label","MIXED GROUP FOOT LEADER",true];
_contactCrewGroup selectLeader _contactFootLeader;
private _contactEnemyGroup=createGroup [west,true];
[_contactEnemyGroup] call _pin;
_contactEnemyGroup setVariable ["WAIT_AIPass_Exclude",true,true];
_contactEnemyGroup setCombatMode "BLUE";
private _contactEnemy=_contactEnemyGroup createUnit ["B_Soldier_F",[1650,1075,0],[],0,"NONE"];
_contactEnemy allowDamage false;
_contactEnemy disableAI "PATH";
_contactEnemy setDir 180;
_contactEnemy setVariable ["WAIT_CortexQA_Label","MOUNTED DANGER HOSTILE",true];
private _contactCrew=crew _contactVehicle;
{_x allowDamage false; _x setVariable ["WAIT_CortexQA_Label",format ["MOUNTED CREW %1",_forEachIndex+1],true]} forEach _contactCrew;
_contactVehicle setVariable ["WAIT_CortexQA_DangerShots",0];
_contactVehicle setVariable ["WAIT_CortexQA_DangerCountermeasures",0];
private _contactFiredHandler=_contactVehicle addEventHandler ["Fired",{
    params ["_vehicle","_weapon"];
    _vehicle setVariable ["WAIT_CortexQA_DangerShots",(_vehicle getVariable ["WAIT_CortexQA_DangerShots",0])+1];
    if (toLowerANSI getText (configFile >> "CfgWeapons" >> _weapon >> "simulation") == "cmlauncher") then {
        _vehicle setVariable ["WAIT_CortexQA_DangerCountermeasures",
            (_vehicle getVariable ["WAIT_CortexQA_DangerCountermeasures",0])+1];
    };
}];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_contactCrew+[_contactFootLeader,_contactEnemy],true];
["Danger FSM: mixed-group mounted persistence","A three-person APC crew and separate foot leader face a real hostile at 25 metres. The mounted event must remain a vehicle response owned only by the effective commander, without WAIT vehicle gunnery, target assignment or injected danger.",getPosATL _contactEnemy] call _phase;
private _contactReady=[{
    missionNamespace getVariable ["WAIT_AIPass_Active",false]
        && {_contactCrewGroup getVariable ["WAIT_AIPass_Managed",false]}
        && {count _contactCrew >= 2}
        && {!isNull (effectiveCommander _contactVehicle)}
},30] call _wait;
["DANGER-VEHICLE-contact-fixture-ready",_contactReady,str [_contactCrew,effectiveCommander _contactVehicle]] call _check;
private _contactStatsBefore=_contactCrewGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
private _contactRecyclesBefore=_contactStatsBefore getOrDefault ["recycles",0];
private _mountedPersistent=[{
    private _stats=_contactCrewGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
    private _actors=_stats getOrDefault ["vehicleRecycleActors",[]];
    private _commander=effectiveCommander _contactVehicle;
    private _commanderId=if (isNull _commander) then {""} else {netId _commander};
    if (_commanderId == "" && {!isNull _commander}) then {_commanderId=str _commander};
    (_stats getOrDefault ["recycles",0]) > _contactRecyclesBefore
        && {(_stats getOrDefault ["lastMode",""]) == "VEHICLE"}
        && {(_stats getOrDefault ["lastRecycleActor",objNull]) == _commander}
        && {count _actors == 1}
        && {_actors param [0,""] == _commanderId}
        && {!isNull _commander}
        && {_commander knowsAbout _contactEnemy > 0}
},30] call _wait;
["DANGER-VEHICLE-mixed-observer-domain",_contactReady && {
        private _assessment=_contactCrewGroup getVariable ["WAIT_Danger_LastAssessment",[]];
        private _action=_contactCrewGroup getVariable ["WAIT_Danger_Action",[]];
        private _vehicleContext=_contactCrewGroup getVariable ["WAIT_Danger_VehicleContext",[]];
        count _assessment >= 7 && {(_assessment select 5) == effectiveCommander _contactVehicle}
            && {_action param [0,""] == "VEHICLE"}
            && {count _vehicleContext == 8}
            && {(_vehicleContext select 0) == "ARMOURED"}
            && {(_vehicleContext select 1) == _contactVehicle}
    },str [_contactCrewGroup getVariable ["WAIT_Danger_LastAssessment",[]],
        _contactCrewGroup getVariable ["WAIT_Danger_Action",[]],
        _contactCrewGroup getVariable ["WAIT_Danger_VehicleContext",[]],leader _contactCrewGroup,effectiveCommander _contactVehicle]] call _check;
["DANGER-VEHICLE-effective-commander-persistence",_contactReady && {_mountedPersistent},
    str [_contactCrewGroup getVariable ["WAIT_Danger_EngineStats",createHashMap],effectiveCommander _contactVehicle]] call _check;
// Enable only the existing vehicle combat layer after proving FSM persistence. The same naturally
// known hostile must now cross the validated danger handoff, enter CONTACT and produce real fire.
// The opponent is allowed to engage natively so a fresh engine danger generation also proves the
// exact platform's finite orient/suppress response. The audit never reveals, assigns a target,
// issues a fire command or injects a group danger record.
[createHashMapFromArray [["WAIT_AIPass_VehicleGunnery_Enable",true]]] call WAIT_fnc_CortexTuning;
_contactEnemyGroup setCombatMode "RED";
_contactEnemyGroup setBehaviourStrong "COMBAT";
private _mountedCombat=[{
    (_contactCrewGroup getVariable ["WAIT_AIPass_PublicPhase",""]) == "CONTACT"
        && {(_contactVehicle getVariable ["WAIT_CortexQA_DangerShots",0]) > 0}
        && {(crew _contactVehicle) findIf {
            (_x getVariable ["WAIT_AIPass_VehicleTarget",objNull]) == _contactEnemy
        } >= 0}
},30] call _wait;
["DANGER-VEHICLE-confirmed-contact-enters-combat",_mountedCombat,
    str [_contactCrewGroup getVariable ["WAIT_AIPass_PublicPhase",""],_contactVehicle getVariable ["WAIT_CortexQA_DangerShots",0],
        _contactCrew apply {[_x,_x getVariable ["WAIT_AIPass_VehicleTarget",objNull],assignedTarget _x]}]] call _check;
private _vehicleReaction=_contactVehicle getVariable ["WAIT_Danger_VehicleReaction",[]];
["DANGER-VEHICLE-known-hostile-finite-reaction",count _vehicleReaction == 4
        && {(_vehicleReaction select 1) == gunner _contactVehicle}
        && {(_vehicleReaction select 2) == _contactEnemy},
    str [_vehicleReaction,_contactCrewGroup getVariable ["WAIT_Danger_Generation",-1],
        _contactCrewGroup getVariable ["WAIT_Danger_Action",[]]]] call _check;
// A real explosive stimulus must permit one defensive smoke request without replacing the route or
// gunner response. The Fired event proves physical launcher use; the generation record proves that
// repeated danger ticks did not manufacture a persistent countermeasure worker.
[_contactVehicle modelToWorld [6,0,0]] call _spawnRealGrenade;
private _dangerCountermeasure=[{
    (_contactVehicle getVariable ["WAIT_CortexQA_DangerCountermeasures",0]) > 0
        && {count (_contactVehicle getVariable ["WAIT_Danger_VehicleCountermeasure",[]]) == 5}
},20] call _wait;
["DANGER-VEHICLE-finite-countermeasure",_dangerCountermeasure,
    str [_contactVehicle getVariable ["WAIT_CortexQA_DangerCountermeasures",0],
        _contactVehicle getVariable ["WAIT_Danger_VehicleCountermeasure",[]],
        _contactCrewGroup getVariable ["WAIT_Danger_Generation",-1]]] call _check;
// A fresh detected contact after losing the primary gunner must recover the weapon with an existing
// dedicated commander. This uses the engine's internal seat-change action: the audit neither moves a
// crew member into a seat nor injects a danger record. The driver and current route remain untouched.
private _recoveryDriver=driver _contactVehicle;
private _lostGunner=gunner _contactVehicle;
private _recoveryCommander=commander _contactVehicle;
private _recoveryPrerequisite=!isNull _recoveryDriver && {!isNull _lostGunner}
    && {!isNull _recoveryCommander} && {_recoveryDriver != _recoveryCommander}
    && {_lostGunner != _recoveryCommander};
// Retire the first contact and let the real casualty response finish before presenting the fresh
// target. Otherwise the deliberately stronger casualty lease can consume a simultaneous DETECTED
// record without replacing its action, which would test priority coalescing rather than crew recovery.
deleteVehicle _contactEnemy;
if (_recoveryPrerequisite) then {
    _lostGunner allowDamage true;
    _lostGunner setDamage 1;
};
sleep 4;
private _recoveryEnemy=_contactEnemyGroup createUnit ["B_Soldier_F",_contactVehicle modelToWorld [30,20,0],[],0,"NONE"];
_recoveryEnemy allowDamage false;
_recoveryEnemy disableAI "PATH";
_recoveryEnemy setDir (_recoveryEnemy getDir _contactVehicle);
_recoveryEnemy setVariable ["WAIT_CortexQA_Label","FRESH CREW-RECOVERY CONTACT",true];
private _gunnerRecovered=[{
    private _crewState=_contactCrewGroup getVariable ["WAIT_AIPass_State",createHashMap];
    private _recovery=_crewState getOrDefault ["vehicleDangerCrewRecovery",[]];
    count _recovery == 4 && {_recovery param [2,false,[true]]}
        && {gunner _contactVehicle == _recoveryCommander}
},30] call _wait;
["DANGER-VEHICLE-gunner-loss-recovered",_recoveryPrerequisite && {_gunnerRecovered},
    str [_recoveryCommander,gunner _contactVehicle,
        (_contactCrewGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["vehicleDangerCrewRecovery",[]],
        _contactVehicle getVariable ["WAIT_Danger_CrewRecovery",[]]]] call _check;
["DANGER-VEHICLE-driver-role-preserved",_recoveryPrerequisite
        && {alive _recoveryDriver} && {driver _contactVehicle == _recoveryDriver},
    str [_recoveryDriver,driver _contactVehicle,assignedVehicleRole _recoveryDriver]] call _check;
_contactVehicle removeEventHandler ["Fired",_contactFiredHandler];
{deleteVehicle _x} forEach (_contactCrew+[_contactFootLeader,_contactEnemy,_recoveryEnemy,_contactVehicle]);
deleteGroup _contactEnemyGroup;
deleteGroup _contactCrewGroup;

{
_x params ["_separate","_freshEnabled",["_nativeBaseline",false],["_stationary",false],["_replacementOrder",false]];
private _layout = ["shared crew/passenger group","separate passenger squad"] select _separate;
private _check = {params ["_id","_passed",["_detail",""]]; [(["","REPLACEMENT-"] select _replacementOrder)+(["","STATIONARY-"] select _stationary)+(["","NATIVE-"] select _nativeBaseline)+(["","FRESH-"] select _freshEnabled)+(["","SEPARATE-"] select _separate)+_id,_passed,_detail] call _recordVehicleCheck};
[createHashMapFromArray [["WAIT_AIPass_Enable",!_nativeBaseline],["WAIT_AIPass_VehicleDismount_Enable",false],
    ["WAIT_AIPass_VehicleRemount_Enable",true]]] call WAIT_fnc_CortexTuning;
private _truck=createVehicle ["O_Truck_03_transport_F",[1900,1100,0],[],0,"NONE"];
createVehicleCrew _truck;
// Additive safe-stop comparison; keep the original unrestricted fixtures intact.
// This isolated safe-exit fixture deliberately holds only the driver pathing.
// Passenger pathing and detection remain native. Unrestricted cases above/below
// still assess real driver decisions; this fixture cannot establish convoy behaviour.
if (_stationary) then {(driver _truck) disableAI "PATH"};
private _group=group driver _truck;
[_group] call _pin;
_group setCombatMode "BLUE";
_truck allowDamage false;
private _passengerGroup = if (_separate) then {createGroup [east,true]} else {_group};
[_passengerGroup] call _pin; _passengerGroup setCombatMode "BLUE";
private _passengers=[];
for "_i" from 0 to 1 do {
    private _unit=_passengerGroup createUnit ["O_Soldier_F",[1900+_i*3,1090,0],[],0,"NONE"];
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["%1 | PASSENGER %2",_layout,_i+1],true];
    _unit allowDamage false;
    _unit assignAsCargo _truck; [_unit] orderGetIn true; _unit moveInCargo _truck;
    _passengers pushBack _unit;
};
private _crew=[driver _truck];
_truck addEventHandler ["GetOut",{
    params ["_vehicle","_role","_unit","_turret"];
    private _group=group _unit;
    private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
    private _records=_state getOrDefault ["dismounted",[]];
    private _issued=_records findIf {(_x select 0) == _unit && {(_x select 1) == _vehicle}} >= 0;
    if (!isNull _unit && {alive _unit} && {_role == "cargo" || {_role == "turret"}}) then {
        _unit setVariable ["WAIT_CortexQA_PhysicalExit",[_vehicle,abs speed _vehicle,_issued,serverTime]];
    };
    diag_log format ["WAIT CORTEX QA PASSENGER EXIT|unit=%1 role=%2 turret=%3 group=%4 phase=%5 cortexIssued=%6 dismountEnabled=%7 speed=%8 command=%9 assigned=%10",
        netId _unit,_role,_turret,_group,_state getOrDefault ["phase",""],_issued,
        [_group,"WAIT_AIPass_VehicleDismount_Enable",true] call WAIT_fnc_CortexFeatureEnabled,
        speed _vehicle,currentCommand _unit,assignedVehicle _unit];
    _unit setVariable ["WAIT_CortexQA_Label",format ["EXIT | %1 | Cortex order %2 | %3",_role,_issued,_state getOrDefault ["phase",""]],true];
}];
// Independent enabled runs start occupied before introducing contact. The original
// disabled-to-enabled sequence remains intact to expose unexpected native exits.
private _enabledStartedMounted=_passengers findIf {!alive _x || {vehicle _x != _truck}} < 0;
if (_freshEnabled) then {
    [createHashMapFromArray [["WAIT_AIPass_VehicleDismount_Enable",true]]] call WAIT_fnc_CortexTuning;
};
// Establish controller readiness before exposing the fresh fixture to enemies.
// No feature-state injection: wait for ordinary discovery to adopt both groups.
if (!_nativeBaseline) then {
    private _ready=[{
        missionNamespace getVariable ["WAIT_AIPass_Active",false]
            && {_group getVariable ["WAIT_AIPass_Managed",false]}
            && {_passengerGroup getVariable ["WAIT_AIPass_Managed",false]}
    },30] call _wait;
    ["DISMOUNT-fixture-controller-ready",_ready,"Both crew and passenger jobs must be adopted before contact"] call _check;
};
private _enemyGroup=createGroup [west,true]; [_enemyGroup] call _pin;
_enemyGroup setVariable ["WAIT_AIPass_Exclude",true,true]; _enemyGroup setCombatMode "BLUE";
private _enemy=_enemyGroup createUnit ["B_Soldier_F",[1900,1220,0],[],0,"NONE"];
_enemy setVariable ["acex_headless_blacklist",true,true]; _enemy allowDamage false; _enemy disableAI "PATH";
// Rear-facing cargo must have a real visible threat too; do not inject shared knowledge.
private _rearEnemy = _enemyGroup createUnit ["B_Soldier_F",[1900,980,0],[],0,"NONE"];
_rearEnemy setVariable ["acex_headless_blacklist",true,true]; _rearEnemy allowDamage false; _rearEnemy disableAI "PATH";
private _opponents = [_enemy,_rearEnemy];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_passengers+_crew+_opponents,true];
[(["","Native AI baseline: "] select _nativeBaseline)+(["Vehicle dismount disabled: ","Fresh enabled dismount: "] select _freshEnabled)+_layout,(["Observe native seat retention while Cortex dismount is disabled; any engine exit must remain unattributed to Cortex.","A fresh occupied truck tests enabled contact dismount independently of earlier retention observations."] select _freshEnabled)+" Visible opponents are ahead and behind for driver and cargo sightlines.",[1900,1100,0]] call _phase;
private _passengerSamples=[];
private _nextPassengerSample=0;
private _driverDetected=false;
private _passengersDetected=false;
private _contactSeen=[{
    _driverDetected=_driverDetected || {(_opponents findIf {(_crew select 0) knowsAbout _x > 1}) >= 0};
    _passengersDetected=_passengersDetected || {(_opponents findIf {leader _passengerGroup knowsAbout _x > 1}) >= 0};
    if (diag_tickTime >= _nextPassengerSample && {count _passengerSamples < 20}) then {
        _nextPassengerSample=diag_tickTime+2;
        _passengerSamples pushBack [serverTime,speed _truck,
            _passengers apply {[netId _x,vehicle _x == _truck,currentCommand _x,[_x,_truck] call WAIT_fnc_CortexPassengerReady]},
            [_group,_passengerGroup] apply {private _sampleGroup=_x; [_sampleGroup,(_sampleGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["phase",""],(_opponents apply {leader _sampleGroup knowsAbout _x})]}];
    };
private _crewSees=(_opponents findIf {(_crew select 0) knowsAbout _x > 1}) >= 0;
private _passengersSee=(_opponents findIf {leader _passengerGroup knowsAbout _x > 1}) >= 0;
// Separate cargo relies on the crew report; its own target detection is observation only.
_crewSees},30] call _wait;
{diag_log format ["WAIT CORTEX QA PASSENGER SAMPLE %1 [time,speed,occupants,groupKnowledge]: %2",_forEachIndex,_x]} forEach _passengerSamples;
["DISMOUNT-fixture-natural-contact",_contactSeen,["Shared occupants must naturally detect an opponent","The crew must naturally detect an opponent; the separate passenger squad intentionally relies on the bounded crew report"] select _separate] call _check;
["DISMOUNT-driver-detected-contact",_driverDetected,"Measured separately: a crew report cannot originate without crew detection"] call _check;
diag_log format ["WAIT CORTEX QA ONBOARD CONTACT: separate=%1 native=%2 driverDetected=%3 passengersDetected=%4 crewReport=%5",
    _separate,_nativeBaseline,_driverDetected,_passengersDetected,_truck getVariable ["WAIT_Cortex_OnboardReport",[]]];
if (!_freshEnabled) then {
    sleep 15;
    private _disabledRecords=([_passengerGroup] call WAIT_fnc_CortexGroupState) getOrDefault ["dismounted",[]];
    ["DISMOUNT-disabled-no-controller-order",_disabledRecords isEqualTo [],format ["mounted=%1; native Arma may independently order a shared crew/passenger group out",_passengers findIf {vehicle _x != _truck} < 0]] call _check;
    _enabledStartedMounted=_passengers findIf {!alive _x || {vehicle _x != _truck}} < 0;
};
if (_nativeBaseline) then {
    // Preserve the real engine-only retention result. Do not force occupants back in
    // or run enabled transitions on this fixture; compare with the Cortex cases.
    diag_log format ["WAIT CORTEX QA NATIVE PASSENGERS|separate=%1 occupants=%2",_separate,_passengers apply {[netId _x,vehicle _x,currentCommand _x]}];
} else {
if (!_enabledStartedMounted) then {
    // This legacy disabled-to-enabled comparison remains additive, but a native exit has already
    // consumed its precondition. Do not mislabel that engine action as a Cortex failure; the fresh
    // enabled fixtures below remain the authoritative transition cases.
    private _unowned=([_passengerGroup] call WAIT_fnc_CortexGroupState) getOrDefault ["dismounted",[]];
    ["DISMOUNT-native-exit-not-misattributed",_unowned isEqualTo [],"Enabled transition skipped because occupants had already left under native control"] call _check;
} else {
["DISMOUNT-enabled-starts-mounted",_enabledStartedMounted,"Passengers already outside cannot prove an enabled dismount transition"] call _check;
[createHashMapFromArray [["WAIT_AIPass_VehicleDismount_Enable",true]]] call WAIT_fnc_CortexTuning;
["Vehicle contact dismount: "+_layout,"Both passengers must physically exit after the feature is enabled. The driver must remain in the truck.",[1900,1100,0]] call _phase;
private _peakExitSpeed=0;
private _safeStopObserved=false;
private _dismounted=[{
    _peakExitSpeed=_peakExitSpeed max abs speed _truck;
    _safeStopObserved=_safeStopObserved || {abs speed _truck < 1};
    // Require all living passengers physically on foot, rather than still inside the carrier.
    _passengers findIf {!alive _x || {vehicle _x != _x}} < 0
},35] call _wait;
private _exitEvidence=_passengers apply {_x getVariable ["WAIT_CortexQA_PhysicalExit",[]]};
_safeStopObserved=_exitEvidence isNotEqualTo [] && {_exitEvidence findIf {
    count _x != 4 || {(_x select 0) != _truck} || {(_x select 1) >= 1}
} < 0};
["DISMOUNT-fixture-safe-stop-observed",_safeStopObserved,
    format ["observedVehiclePeak=%1 stationaryRequested=%2 physicalExits=%3",_peakExitSpeed,_stationary,_exitEvidence]] call _check;
if (_stationary) then {["DISMOUNT-fixture-stationary-held",_peakExitSpeed < 1,format ["peakSpeed=%1; movement invalidates the stationary comparison",_peakExitSpeed]] call _check};
["DISMOUNT-contact-physical-exit",_contactSeen && {_enabledStartedMounted} && {_dismounted},format ["startedMounted=%1 endedDismounted=%2",_enabledStartedMounted,_dismounted]] call _check;
private _recorded=([_passengerGroup] call WAIT_fnc_CortexGroupState) getOrDefault ["dismounted",[]];
private _ownedExit=_passengers findIf {private _unit=_x; _recorded findIf {(_x select 0) == _unit && {(_x select 1) == _truck}} < 0} < 0;
["DISMOUNT-controller-attribution-valid",_ownedExit || {!_separate},["A shared group may execute its native exit first; Cortex does not claim or remount an unowned exit","The separate passenger case must record every exit before issuing it"] select _separate] call _check;
if (_separate) then {
    ["DISMOUNT-crew-report-physical-exit",_driverDetected && {_enabledStartedMounted} && {_dismounted} && {_ownedExit},
        format ["crewContact=%1 passengerContact=%2 physicalExit=%3 controllerOwned=%4 safeStop=%5",_driverDetected,_passengersDetected,_dismounted,_ownedExit,_safeStopObserved]] call _check;
};
["DISMOUNT-driver-retained",vehicle (_crew select 0) == _truck] call _check;
{deleteVehicle _x} forEach _opponents;
if (!_ownedExit) then {
    ["REMOUNT-unowned-native-exit-not-reclaimed",(_passengerGroup getVariable ["WAIT_Cortex_Remount",[]]) isEqualTo [],"Cortex must not overwrite an exit it did not initiate"] call _check;
} else {
if (_replacementOrder) then {
    private _replacement=createVehicle ["O_Truck_03_transport_F",_truck getPos [25,90],[],0,"NONE"];
    _replacement allowDamage false;
    // A genuine external boarding order: no seat teleport, state flag or cleanup call.
    {_x assignAsCargo _replacement; [_x] orderGetIn true} forEach _passengers;
    ["Replacement passenger order","After a Cortex dismount, another script orders the squad into the second truck. They must walk and board it; calm restoration must never send them back to the original truck.",getPosATL _replacement] call _phase;
    private _replacementPreserved=true;
    private _replacementBoarded=[{
        if (_passengers findIf {assignedVehicle _x != _replacement || {vehicle _x == _truck}} >= 0) then {_replacementPreserved=false};
        _passengers findIf {vehicle _x != _replacement} < 0
    },100] call _wait;
    // Observe beyond the normal contact-loss delay, including after successful boarding.
    for "_sample" from 1 to 40 do {
        sleep 1;
        if (_passengers findIf {assignedVehicle _x != _replacement || {vehicle _x == _truck}} >= 0) then {_replacementPreserved=false};
    };
    private _ownedExit=_passengers findIf {private _passenger=_x; _recorded findIf {(_x select 0) == _passenger && {(_x select 1) == _truck}} < 0} < 0;
    ["REMOUNT-replacement-assignment-preserved",_enabledStartedMounted && {_dismounted} && {_ownedExit} && {_replacementPreserved},str (_passengers apply {[assignedVehicle _x,vehicle _x,currentCommand _x]})] call _check;
    ["REMOUNT-replacement-physically-boarded",_ownedExit && {_replacementBoarded} && {_passengers findIf {vehicle _x != _replacement} < 0}] call _check;
    {deleteVehicle _x} forEach _passengers;
    deleteVehicle _replacement;
} else {
["Vehicle calm remount: "+_layout,"The enemy is removed. Once contact expires, both recorded passengers must physically board the same truck again. The test never moves them into seats.",[1900,1100,0]] call _phase;
private _remounted=[{_passengers findIf {!alive _x || {vehicle _x != _truck}} < 0},100] call _wait;
["REMOUNT-physical-seat-occupancy",_enabledStartedMounted && {_dismounted} && {_remounted},
    str ["previouslyDismounted",_dismounted,_passengerGroup getVariable ["WAIT_Cortex_Remount",[]],_passengers apply {[vehicle _x,assignedVehicle _x,currentCommand _x]}]] call _check;
["REMOUNT-group-membership-independent",_passengers findIf {group _x != _passengerGroup} < 0
    && {group (_crew select 0) == _group} && {(_passengerGroup != _group) isEqualTo _separate},
    "Membership is measured independently of seat occupancy; the original combined check follows"] call _check;
["REMOUNT-original-groups-retained",_enabledStartedMounted && {_remounted} && {_dismounted}
    && {_passengers findIf {group _x != _passengerGroup} < 0}
    && {group (_crew select 0) == _group}
    && {(_passengerGroup != _group) isEqualTo _separate},
    str [_separate,group (_crew select 0),_passengers apply {group _x}]] call _check;
};
};
};
};
{deleteVehicle _x} forEach (_passengers+_crew+_opponents+[_truck]); deleteGroup _group; if (_separate) then {deleteGroup _passengerGroup}; deleteGroup _enemyGroup;

} forEach [[false,false,true],[true,false,true],[false,false],[true,false],[false,true],[true,true],[false,true,false,true],[true,true,false,true],[true,true,false,true,true]];

[createHashMapFromArray [["WAIT_AIPass_VehicleDismount_Enable",false],["WAIT_AIPass_VehicleWithdraw_Enable",false]]] call WAIT_fnc_CortexTuning;
private _armour=createVehicle ["O_APC_Tracked_02_cannon_F",[1900,1100,0],[],0,"NONE"];
createVehicleCrew _armour;
private _group=group driver _armour; [_group] call _pin;
_group setCombatMode "BLUE";
private _crew=crew _armour;
{_x allowDamage false; _x setVariable ["WAIT_CortexQA_Label","WITHDRAWING CREW",true]} forEach _crew;
private _enemyGroup=createGroup [west,true]; [_enemyGroup] call _pin;
_enemyGroup setVariable ["WAIT_AIPass_Exclude",true,true]; _enemyGroup setCombatMode "BLUE";
private _enemy=_enemyGroup createUnit ["B_Soldier_F",[1900,1250,0],[],0,"NONE"];
_enemy setVariable ["acex_headless_blacklist",true,true]; _enemy allowDamage false; _enemy disableAI "PATH";
// Compare independent engine/config views before attributing an empty inventory to the controller.
diag_log format ["WAIT CORTEX QA ARMOUR IDENTITY: class=%1 config=%2 simulation=%3 simple=%4 crew=%5 allTurrets=%6 fullCrew=%7 magazines=%8",
    typeOf _armour,configName (configOf _armour),simulationEnabled _armour,isSimpleObject _armour,
    crew _armour,allTurrets _armour,fullCrew [_armour,"",true],magazinesAllTurrets _armour];
diag_log format ["WAIT CORTEX QA ARMOUR CONFIG TURRETS: %1",("true" configClasses (configOf _armour >> "Turrets")) apply {
    [configName _x,getArray (_x >> "weapons"),getArray (_x >> "magazines")]
}];
private _smokeReady=[{
    ([[-1]]+allTurrets [_armour,true]) findIf {
        private _turret=_x;
        (_armour weaponsTurret _turret) findIf {toLowerANSI (getText (configFile >> "CfgWeapons" >> _x >> "simulation")) == "cmlauncher"} >= 0
            && {(_armour magazinesTurret _turret) isNotEqualTo []}
    } >= 0
},10] call _wait;
["WITHDRAW-smoke-inventory-prerequisite",_smokeReady,format ["class=%1 owner=%2 turrets=%3",typeOf _armour,owner _armour,allTurrets [_armour,true]]] call _check;
diag_log format ["WAIT CORTEX QA COUNTERMEASURE CONFIG: %1",([[-1]]+allTurrets [_armour,true]) apply {
    private _turret=_x;
    [_turret,(_armour weaponsTurret _turret) apply {[_x,getText (configFile >> "CfgWeapons" >> _x >> "simulation")]},_armour magazinesTurret _turret]
}];
_armour addEventHandler ["Fired",{
    params ["_vehicle","_weapon","_muzzle","_mode","_ammo","_magazine"];
    diag_log format ["WAIT CORTEX QA VEHICLE FIRED: weapon=%1 muzzle=%2 ammo=%3 magazine=%4",_weapon,_muzzle,_ammo,_magazine];
    if (toLowerANSI getText (configFile >> "CfgWeapons" >> _weapon >> "simulation") == "cmlauncher") then {_vehicle setVariable ["WAIT_CortexQA_SmokeShots",(_vehicle getVariable ["WAIT_CortexQA_SmokeShots",0])+1,true]};
}];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_crew+[_enemy],true];
private _origin=getPosATL _armour;
_armour setDamage 0.55;
["WITHDRAW-mobile-damaged-fixture",alive _armour && {canMove _armour} && {damage _armour >= 0.5}] call _check;
["Damaged armour: withdrawal disabled","The damaged but mobile APC must hold while withdrawal is disabled. The crew must naturally detect the visible opponent before the enabled comparison begins.",[1900,1100,0]] call _phase;
private _withdrawContact = [{driver _armour knowsAbout _enemy > 1},30] call _wait;
["WITHDRAW-fixture-natural-contact",_withdrawContact] call _check;
private _disabledTravel = 0;
private _disabledCrewRetained = true;
for "_sample" from 1 to 15 do {
    sleep 1;
    _disabledTravel = _disabledTravel max (_armour distance2D _origin);
    if (_crew findIf {!alive _x || {vehicle _x != _armour}} >= 0) then {_disabledCrewRetained=false};
};
["WITHDRAW-disabled-holds",_withdrawContact && {_disabledTravel <= 5} && {_disabledCrewRetained},str _disabledTravel] call _check;
["WITHDRAW-disabled-no-smoke",(_armour getVariable ["WAIT_CortexQA_SmokeShots",0]) == 0] call _check;
_origin=getPosATL _armour;
[createHashMapFromArray [["WAIT_AIPass_VehicleWithdraw_Enable",true]]] call WAIT_fnc_CortexTuning;
["Damaged armour withdrawal","Withdrawal is now enabled on the same APC. It must fire actual defensive smoke and drive at least 40 m away from the visible threat, retaining all operating crew.",[1900,1100,0]] call _phase;
private _reversePhysical=false;
private _reverseFacing=false;
private _withdrawn=[{
    private _reverse=_group getVariable ["WAIT_VehicleReverse",[]];
    if (count _reverse == 9 && {(_reverse select 0) == _armour}
        && {(_armour distance2D _origin) >= 8}
        && {(velocityModelSpace _armour select 1) < -0.5}) then {
        _reversePhysical=true;
        private _bearing=_armour getRelDir (getPosATL _enemy);
        _reverseFacing=_reverseFacing || {_bearing <= 45 || {_bearing >= 315}};
    };
    _armour distance2D _origin > 40 && {_armour distance2D _enemy > (_origin distance2D _enemy)+30}
},100] call _wait;
["WITHDRAW-tracked-physical-reverse",_withdrawContact && {_reversePhysical},str [getPosATL _armour,vehicleMoveInfo _armour]] call _check;
["WITHDRAW-tracked-threat-facing",_reversePhysical && {_reverseFacing},str [_armour getRelDir (getPosATL _enemy)]] call _check;
["WITHDRAW-physical-distance",_withdrawContact && {_withdrawn},str getPosATL _armour] call _check;
["WITHDRAW-actual-smoke",(_armour getVariable ["WAIT_CortexQA_SmokeShots",0]) > 0] call _check;
["WITHDRAW-crew-retained",_crew findIf {!alive _x || {vehicle _x != _armour}} < 0] call _check;
sleep 12;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach (_crew+[_enemy,_armour]); deleteGroup _group; deleteGroup _enemyGroup;

// A separate fixture crosses the owner boundary while the production vehicle withdrawal is active.
// Keeping it independent preserves the original disabled/enabled comparison and prevents a failed
// migration precondition from consuming that result.
private _hcOwners=(missionNamespace getVariable ["WAIT_Headless_Clients",[]]) apply {_x select 0};
["WITHDRAW-MIGRATION-headless-prerequisite",_hcOwners isNotEqualTo [],str _hcOwners] call _check;
if (_hcOwners isNotEqualTo []) then {
    private _hcOwner=_hcOwners select 0;
    [createHashMapFromArray [
        ["WAIT_AIPass_Enable",true],["WAIT_AIPass_Contact_Enable",true],
        ["WAIT_AIPass_Vehicles_Enable",true],["WAIT_AIPass_VehicleWithdraw_Enable",true],
        ["WAIT_AIPass_VehicleDismount_Enable",false],["WAIT_AIPass_VehicleGunnery_Enable",false],
        ["WAIT_AIPass_Morale_Enable",false],["WAIT_AIPass_PostContact_Enable",false]
    ]] call WAIT_fnc_CortexTuning;
    private _migrateArmour=createVehicle ["O_APC_Tracked_02_cannon_F",[2300,1100,0],[],0,"NONE"];
    createVehicleCrew _migrateArmour;
    private _migrateGroup=group driver _migrateArmour;
    [_migrateGroup] call _pin;
    _migrateGroup setCombatMode "BLUE";
    private _migrateCrew=crew _migrateArmour;
    {
        _x allowDamage false;
        _x setVariable ["WAIT_CortexQA_Label",format ["VEHICLE WITHDRAW HANDOFF %1",_forEachIndex+1],true];
    } forEach _migrateCrew;
    private _migrateEnemyGroup=createGroup [west,true];
    [_migrateEnemyGroup] call _pin;
    _migrateEnemyGroup setVariable ["WAIT_AIPass_Exclude",true,true];
    _migrateEnemyGroup setCombatMode "BLUE";
    private _migrateEnemy=_migrateEnemyGroup createUnit ["B_Soldier_LAT_F",[2300,1260,0],[],0,"NONE"];
    _migrateEnemy allowDamage false;
    _migrateEnemy disableAI "PATH";
    _migrateEnemy setVariable ["acex_headless_blacklist",true,true];
    _migrateEnemy setVariable ["WAIT_CortexQA_Label","WITHDRAW HANDOFF THREAT",true];
    _migrateArmour setDamage 0.55;
    _migrateArmour setVariable ["WAIT_CortexQA_SmokeShots",0,true];
    private _countermeasureAmmo={
        params ["_vehicle"];
        private _total=0;
        {
            _x params ["_magazine","_turret","_rounds"];
            private _ammo=getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
            if (toLowerANSI getText (configFile >> "CfgAmmo" >> _ammo >> "simulation") in ["shotsmoke","shotsmokex"]) then {
                _total=_total+_rounds;
            };
        } forEach magazinesAllTurrets _vehicle;
        _total
    };
    _migrateArmour addEventHandler ["Fired",{
        params ["_vehicle","_weapon","_muzzle","_mode","_ammo","_magazine"];
        if (toLowerANSI getText (configFile >> "CfgWeapons" >> _weapon >> "simulation") == "cmlauncher") then {
            _vehicle setVariable ["WAIT_CortexQA_SmokeShots",(_vehicle getVariable ["WAIT_CortexQA_SmokeShots",0])+1,true];
        };
    }];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",_migrateCrew+[_migrateEnemy],true];
    private _migrationOrigin=getPosATL _migrateArmour;
    ["Vehicle withdrawal: active owner handoff","The damaged APC must naturally detect the visible AT threat, start a real withdrawal on the server, then continue under a headless owner without replaying its initial smoke screen. Crew must remain aboard.",_migrationOrigin getPos [120,180]] call _phase;
    private _migrationContact=[{driver _migrateArmour knowsAbout _migrateEnemy > 1},35] call _wait;
    ["WITHDRAW-MIGRATION-natural-contact",_migrationContact,str (driver _migrateArmour knowsAbout _migrateEnemy)] call _check;
    private _migrationStarted=[{
        (_migrateGroup getVariable ["WAIT_AIPass_PublicPhase",""]) == "RETREAT"
            && {private _intent=_migrateGroup getVariable ["WAIT_Cortex_WithdrawalIntent",[]]; count _intent == 7 && {(_intent select 0) == "VEHICLE"}}
            && {_migrateArmour distance2D _migrationOrigin >= 8}
    },45] call _wait;
    ["WITHDRAW-MIGRATION-production-start",_migrationContact && {_migrationStarted},str [_migrateGroup getVariable ["WAIT_AIPass_PublicPhase",""],_migrateGroup getVariable ["WAIT_Cortex_WithdrawalIntent",[]],getPosATL _migrateArmour]] call _check;
    private _initialSmoke=[{(_migrateArmour getVariable ["WAIT_CortexQA_SmokeShots",0]) > 0},12] call _wait;
    ["WITHDRAW-MIGRATION-initial-smoke",_initialSmoke,str (_migrateArmour getVariable ["WAIT_CortexQA_SmokeShots",0])] call _check;
    // Let the owner's initial launcher burst finish before taking the ammunition baseline. A Fired
    // handler installed on the old owner cannot observe a later HC-local replay, while live magazine
    // depletion remains authoritative across locality and therefore catches one.
    sleep 5;
    private _smokeBefore=_migrateArmour getVariable ["WAIT_CortexQA_SmokeShots",0];
    private _countermeasureAmmoBefore=[_migrateArmour] call _countermeasureAmmo;
    private _intentBefore=+(_migrateGroup getVariable ["WAIT_Cortex_WithdrawalIntent",[]]);
    private _startedAt=_intentBefore param [4,-1];
    private _ownerBefore=groupOwner _migrateGroup;
    // Automatic balancing may have adopted this group already. Test an actual boundary,
    // not a successful no-op request to the owner it currently has.
    private _otherOwners=_hcOwners select {_x != _ownerBefore};
    if (_otherOwners isNotEqualTo []) then {_hcOwner=_otherOwners select 0};
    private _realOwnerBoundary=_ownerBefore != _hcOwner;
    ["WITHDRAW-MIGRATION-distinct-owner-prerequisite",_realOwnerBoundary,
        str [_ownerBefore,_hcOwner,owner _migrateArmour]] call _check;
    private _handoffPosition=getPosATL _migrateArmour;
    private _handoffThreatDistance=_migrateArmour distance2D _migrateEnemy;
    _migrateGroup setVariable ["WAIT_Headless_ExcludeGroup",false,true];
    {_x setVariable ["acex_headless_blacklist",false,true]} forEach _migrateCrew;
    private _migrationRequested=[_migrateGroup,_hcOwner] call WAIT_fnc_HeadlessMigrateGroup;
    private _migrationAdopted=[{
        groupOwner _migrateGroup == _hcOwner
            && {owner _migrateArmour == _hcOwner}
            && {_migrateCrew findIf {owner _x != _hcOwner} < 0}
            && {(_migrateGroup getVariable ["WAIT_AIPass_PublicPhase",""]) == "RETREAT"}
            && {private _entry=_migrateGroup getVariable ["WAIT_Cortex_PhaseTransition",[]]; count _entry == 5 && {(_entry select 3) == "VEHICLE_OWNERSHIP_RESUME"} && {(_entry select 4) == _hcOwner}}
    },40] call _wait;
    ["WITHDRAW-MIGRATION-owner-resume",_realOwnerBoundary && {_migrationRequested} && {_migrationAdopted},str [groupOwner _migrateGroup,owner _migrateArmour,_migrateCrew apply {owner _x},_migrateGroup getVariable ["WAIT_Cortex_PhaseTransition",[]]]] call _check;
    private _intentAfter=+(_migrateGroup getVariable ["WAIT_Cortex_WithdrawalIntent",[]]);
    ["WITHDRAW-MIGRATION-start-preserved",_migrationAdopted && {count _intentAfter == 7}
        && {abs ((_intentAfter select 4)-_startedAt) < 0.25},str [_startedAt,_intentAfter]] call _check;
    private _continued=[{
        _migrateArmour distance2D _handoffPosition >= 12
            && {_migrateArmour distance2D _migrateEnemy >= _handoffThreatDistance+8}
    },45] call _wait;
    ["WITHDRAW-MIGRATION-physical-continuation",_realOwnerBoundary && {_migrationAdopted} && {_continued},str [_handoffPosition,getPosATL _migrateArmour,_handoffThreatDistance,_migrateArmour distance2D _migrateEnemy]] call _check;
    sleep 6;
    private _countermeasureAmmoAfter=[_migrateArmour] call _countermeasureAmmo;
    ["WITHDRAW-MIGRATION-no-smoke-replay",_initialSmoke && {_countermeasureAmmoAfter == _countermeasureAmmoBefore},str [_smokeBefore,_migrateArmour getVariable ["WAIT_CortexQA_SmokeShots",0],_countermeasureAmmoBefore,_countermeasureAmmoAfter]] call _check;
    ["WITHDRAW-MIGRATION-crew-retained",_migrateCrew findIf {!alive _x || {vehicle _x != _migrateArmour}} < 0,str (_migrateCrew apply {vehicle _x})] call _check;

    ["Vehicle withdrawal: Zeus replacement","Zeus now replaces the resumed withdrawal. The APC must release RETREAT, drive to the new marker under the replacement waypoint and remain there without reviving the old withdrawal.",[2420,1100,0]] call _phase;
    [_migrateGroup,true] call WAIT_fnc_CortexZeusMark;
    private _released=[{
        (_migrateGroup getVariable ["WAIT_AIPass_PublicPhase",""]) == "CALM"
            && {(_migrateGroup getVariable ["WAIT_Cortex_WithdrawalIntent",[]]) isEqualTo []}
    },25] call _wait;
    ["WITHDRAW-MIGRATION-zeus-release",_released,str [_migrateGroup getVariable ["WAIT_AIPass_PublicPhase",""],_migrateGroup getVariable ["WAIT_Cortex_WithdrawalIntent",[]]]] call _check;
    private _replacement=[2420,1100,0];
    private _replacementWP=_migrateGroup addWaypoint [_replacement,0];
    _replacementWP setWaypointType "MOVE";
    _replacementWP setWaypointCompletionRadius 8;
    _migrateGroup setCurrentWaypoint _replacementWP;
    {_x setVariable ["WAIT_CortexQA_Target",_replacement,true]} forEach _migrateCrew;
    private _replacementArrived=[{_migrateArmour distance2D _replacement <= 22},100] call _wait;
    ["WITHDRAW-MIGRATION-zeus-physical-replacement",_released && {_replacementArrived},str getPosATL _migrateArmour] call _check;
    private _stayedReleased=_replacementArrived;
    for "_sample" from 1 to 12 do {
        sleep 1;
        if ((_migrateGroup getVariable ["WAIT_AIPass_PublicPhase","CALM"]) == "RETREAT"
            || {(_migrateGroup getVariable ["WAIT_Cortex_WithdrawalIntent",[]]) isNotEqualTo []}
            || {_migrateArmour distance2D _replacement > 25}) then {_stayedReleased=false};
    };
    ["WITHDRAW-MIGRATION-zeus-no-resurrection",_stayedReleased,str [_migrateGroup getVariable ["WAIT_AIPass_PublicPhase",""],_migrateGroup getVariable ["WAIT_Cortex_WithdrawalIntent",[]],getPosATL _migrateArmour]] call _check;
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
    {deleteVehicle _x} forEach (_migrateCrew+[_migrateEnemy,_migrateArmour]);
    deleteGroup _migrateGroup;
    deleteGroup _migrateEnemyGroup;
};

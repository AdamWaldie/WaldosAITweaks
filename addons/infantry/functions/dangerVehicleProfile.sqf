/*
 * Author: WaldoTheWarfighter
 * Purpose: Classify the occupied vehicle domain for one bounded danger response so the danger FSM
 * can hand work to the correct existing subsystem without issuing movement, target or fire commands.
 * Locality/authority: Read-only. Call on the actor owner after validating the actor. It inspects the
 * actor's current vehicle, live turret weapons and vehicle configuration but changes no state.
 * Repeat/JIP: Pure classification. A new owner recomputes the profile from the current vehicle.
 * Arguments: 0: actor <OBJECT>, objNull.
 * Return Value: STRING - FOOT, AIR, ARTILLERY, STATIC, ARMOURED, ARMED or TRANSPORT.
 * Current callers: WAIT_fnc_DangerEngineAct and WAIT_fnc_DangerStep.
 * Example: [effectiveCommander vehicle player] call WAIT_fnc_DangerVehicleProfile;
 */

params [["_actor",objNull,[objNull]]];
if (isNull _actor || {!alive _actor}) exitWith {"FOOT"};
private _vehicle=vehicle _actor;
if (_vehicle == _actor) exitWith {"FOOT"};
if (_vehicle isKindOf "Air") exitWith {"AIR"};
// Artillery is a support owner even when the weapon is mounted on a truck or static carriage.
// It must be identified before mobility and armour so incoming danger cannot turn a battery into
// an infantry passenger-dismount or generic fighting-vehicle operation.
if (getNumber (configOf _vehicle >> "artilleryScanner") == 1) exitWith {"ARTILLERY"};
if (_vehicle isKindOf "StaticWeapon") exitWith {"STATIC"};
if (_vehicle isKindOf "Tank" || {_vehicle isKindOf "Wheeled_APC_F"}) exitWith {"ARMOURED"};
private _hasRealWeapon=([[-1]]+allTurrets [_vehicle,true]) findIf {
    (_vehicle weaponsTurret _x) findIf {
        private _weaponConfig=configFile >> "CfgWeapons" >> _x;
        private _simulation=toLowerANSI getText (_weaponConfig >> "simulation");
        toLowerANSI getText (_weaponConfig >> "displayName") != "horn"
            && {_simulation != "cmlauncher"}
    } >= 0
} >= 0;
if (_hasRealWeapon) exitWith {"ARMED"};
"TRANSPORT"

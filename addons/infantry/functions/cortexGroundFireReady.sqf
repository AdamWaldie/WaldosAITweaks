/*
 * Author: WaldoTheWarfighter
 * Purpose: Verify the selected ground gunner's actual station has a loaded damaging magazine
 * compatible with an exposed station weapon. Ammunition on another turret cannot qualify it.
 * An optional target also requires configured ammunition intent for its actual platform class.
 * Missing usage flags retain a conservative legacy fallback; no targeting command is issued.
 * Locality/authority: Read-only on the gunner owner; vehicle locality may differ; callers retain ROE, safety and token checks.
 * Repeat/JIP: No state, commands or handlers; rereads current crew and magazines at each fire boundary.
 * Arguments: 0 platform <OBJECT, objNull>; 1 selected gunner <OBJECT, objNull>;
 * 2 target <OBJECT, objNull>, omitted means the legacy station-only ammunition check.
 * Return Value: BOOL, station has usable damaging ammunition for the supplied target,
 * or any damaging ammunition when target is omitted; not proof of firing/effect.
 * Current callers: CortexCombinedArmsLocal, CortexCombinedGroundStep and CortexVehicles.
 * Example: [_vehicle,gunner _vehicle,_enemy] call WAIT_fnc_CortexGroundFireReady;
 */
params [["_asset",objNull,[objNull]],["_gunner",objNull,[objNull]],["_target",objNull,[objNull]]];
if (isNull _asset || {isNull _gunner} || {!local _gunner}
    || {!alive _asset} || {!(_asset isKindOf "LandVehicle")}
    || {gunner _asset != _gunner} || {vehicle _gunner != _asset}) exitWith {false};
private _crew=fullCrew [_asset,"",false];
private _stationIndex=_crew findIf {(_x select 0) == _gunner};
if (_stationIndex < 0) exitWith {false};
private _station=(_crew select _stationIndex) select 3;
private _weapons=_asset weaponsTurret _station;
private _loaded=magazinesAllTurrets _asset;
private _targetPlatform=if (isNull _target) then {objNull} else {vehicle _target};
private _targetFlag=if (isNull _targetPlatform) then {0} else {
    if (_targetPlatform isKindOf "Man") then {64} else {
        if (_targetPlatform isKindOf "Air") then {256} else {
            if (_targetPlatform isKindOf "Tank"
                || {getNumber (configFile >> "CfgVehicles" >> typeOf _targetPlatform >> "type") == 1}) then {512} else {128}
        }
    }
};
private _targetSuitable={
    params ["_ammo"];
    if (_targetFlag == 0) exitWith {true};
    // Explicit infantry exclusion is authoritative even for older unflagged ammo.
    if (_targetFlag == 64 && {isNumber (_ammo >> "allowAgainstInfantry")}
        && {getNumber (_ammo >> "allowAgainstInfantry") == 0}) exitWith {false};
    private _flags=getNumber (_ammo >> "aiAmmoUsageFlags");
    if (_flags > 0) exitWith {(floor (_flags/_targetFlag) mod 2) == 1};
    // Preserve legacy ordinary rounds against soft targets. Armour requires a
    // heavy shell/rocket/missile, consistent with the existing launcher fallback;
    // air needs an explicit air-lock capability. Config intent is not effect proof.
    if (_targetFlag == 256) exitWith {getNumber (_ammo >> "airLock") > 0};
    if (_targetFlag == 512) exitWith {
        toLowerANSI getText (_ammo >> "simulation") in ["shotshell","shotrocket","shotmissile"]
            && {getNumber (_ammo >> "hit") >= 100} && {getNumber (_ammo >> "airLock") <= 0}
    };
    getNumber (_ammo >> "airLock") <= 0
};
_loaded findIf {
    _x params ["_magazine","_turret","_rounds"];
    _turret isEqualTo _station && {_rounds > 0} && {
        private _ammo=configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
        (getNumber (_ammo >> "hit") > 0 || {getNumber (_ammo >> "indirectHit") > 0})
            && {_weapons findIf {_magazine in compatibleMagazines _x} >= 0}
            && {[_ammo] call _targetSuitable}
    }
} >= 0

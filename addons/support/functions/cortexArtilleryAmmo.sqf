/*
 * Author: WaldoTheWarfighter
 * Selects available smoke (including smoke deployers) or plain HE; excludes illumination, explosive and mixed payloads. Smoke requires a known smoke leaf,
 * not only an AI usage flag; each uncached payload tree permits 64 reads and four levels.
 * Locality/authority: read-only query on the battery owner; callers coordinate fire on the server.
 * Repeat/JIP: repeat-safe; immutable ammunition profiles are cached locally, available rounds are read each call.
 * Arguments: 0: battery <OBJECT>, default objNull; 1: smoke <BOOL>, default false.
 * Return Value: String magazine class, or empty string.
 * Current callers: ArtilleryFire and ArtilleryShot.
 * Example: private _mag = [_gun, false] call WAIT_fnc_CortexArtilleryAmmo;
 */
params [["_battery", objNull, [objNull]], ["_smoke", false, [true]]];
private _best = "";
private _available = (magazinesAllTurrets [_battery,true]) select {(_x select 2) > 0};
private _cache = missionNamespace getVariable ["WAIT_AIPass_ArtilleryAmmoProfiles",createHashMap];
private _bestHit = -1;
// Mortar smoke can be a shotDeploy carrier rather than a direct smoke projectile.
// Inspect only immutable config, bounded against recursive addon payload definitions.
private _smokeChecks=0;
private _classifySmoke = {
    params ["_ammoClass",["_depth",0]];
    _smokeChecks=_smokeChecks+1;
    if (_depth >= 4 || {_smokeChecks > 64} || {!isClass (configFile >> "CfgAmmo" >> _ammoClass)}) exitWith {false};
    private _ammoConfig=configFile >> "CfgAmmo" >> _ammoClass;
    private _simulation=toLowerANSI getText (_ammoConfig >> "simulation");
    private _indirect=getNumber (_ammoConfig >> "indirectHit");
    if (!finite _indirect || {_indirect != 0}) exitWith {false};
    private _payload=getText (_ammoConfig >> "submunitionAmmo");
    private _payloadArray=getArray (_ammoConfig >> "submunitionAmmo");
    private _hasPayload=_payload != "" || {isArray (_ammoConfig >> "submunitionAmmo")};
    if (_hasPayload) exitWith {
        private _payloads=if (_payload != "") then {[_payload]} else {+_payloadArray};
        private _validPayload=true;
        if (_payload == "" && {_payloadArray findIf {!(_x isEqualType "")} >= 0}) then {
            // Engine format: alternating class/probability pairs. Preserve every branch,
            // including zero-weight ones, instead of filtering numbers out of malformed data.
            _payloads=[];
            _validPayload=count _payloadArray > 0 && {count _payloadArray <= 32} && {count _payloadArray mod 2 == 0};
            private _positiveWeight=false;
            if (_validPayload) then {
                for "_index" from 0 to ((count _payloadArray)-2) step 2 do {
                    private _class=_payloadArray select _index;
                    private _weight=_payloadArray select (_index+1);
                    if (!(_class isEqualType "") || {_class == ""} || {!(_weight isEqualType 0)}
                        || {!finite _weight} || {_weight < 0}) exitWith {_validPayload=false};
                    _payloads pushBack _class;
                    if (_weight > 0) then {_positiveWeight=true};
                };
            };
            _validPayload=_validPayload && {_positiveWeight};
        };
        _validPayload && {_payloads isNotEqualTo []} && {count _payloads <= 16}
            && {_payloads findIf {!(_x isEqualType "") || {_x == ""}} < 0}
            && {getNumber (_ammoConfig >> "hit") == 0}
            && {_payloads findIf {!([_x,_depth+1] call _classifySmoke)} < 0}
    };
    // An AI usage flag alone cannot prove this projectile delivers smoke.
    _simulation in ["shotsmoke","shotsmokex"]
};
{
    private _profile = _cache getOrDefault [_x,[]];
    if (_profile isEqualTo []) then {
        private _ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
        private _cfg = configFile >> "CfgAmmo" >> _ammo;
        _smokeChecks=0;
        private _smokeAmmo = [_ammo] call _classifySmoke;
        private _specialAmmo = getText (_cfg >> "simulation") == "shotIlluminating" || {getText (_cfg >> "submunitionAmmo") != ""} || {isArray (_cfg >> "submunitionAmmo")};
        _profile = [_smokeAmmo,_specialAmmo,getNumber (_cfg >> "hit")];
        _cache set [_x,_profile];
    };
    _profile params ["_isSmoke","_special","_hit"];
    if (_isSmoke == _smoke && {_smoke || {!_special && {_hit > _bestHit}}}) then {_best = _x; _bestHit = _hit};
} forEach ((getArtilleryAmmo [_battery]) select {private _magazine = _x; _available findIf {(_x select 0) == _magazine} >= 0});
missionNamespace setVariable ["WAIT_AIPass_ArtilleryAmmoProfiles",_cache];

_best

/*
 * Author: WaldoTheWarfighter
 * Makes one soldier throw a smoke or fragmentation grenade he is carrying, towards a position.
 *
 * Grenade types are identified from config, so mod grenades work: smoke is ammo simulation shotSmoke
 * or shotSmokeX; fragmentation is shotGrenade. Chemlights and ACE
 * flashbangs are skipped. The throw muzzle is the "Throw" weapon muzzle that accepts that magazine.
 * The queued throw revalidates ownership and requests target observation. Release requires actual
 * body and viewing alignment; an unaligned actor cancels rather than throwing behind contact. A fragmentation grenade is never thrown when a
 * friendly, civilian, captive or surrendering soldier is within 12 m of the target, or when the target is under 8 m or over
 * 40 m away. Engine AI already treat smoke particles as blocking sight.
 * Locality and authority: call where the unit is local (forceWeaponFire is local-argument).
 *
 * Repeat/JIP: a maximum 1.5-second aiming window with 0.25-second retries rechecks ownership, medical/captivity status, Zeus takeover, drill replacement/cancellation, ammunition and frag safety;
 * Replacement operation generations, owner epochs and native protected tasks cancel queued throws.
 * A cancelled queued fragmentation throw records its drill token so assault may continue without it.
 * Pending throws are not replayed to joining clients. Fragmentation throws track the actual projectile
 * locally for assault sequencing; that FiredMan handler removes itself or expires after ten seconds.
 * One additional three-second listener records native launch velocity for smoke and fragmentation;
 * zero horizontal velocity is marked unavailable, not interpreted as an observed bearing. Locality
 * changes retire the listener. Neither listener changes the projectile or creates recurring work.
 * Arguments:
 * 0: unit <OBJECT>
 * 1: towards <ARRAY> - ATL position
 * 2: kind <STRING> - "SMOKE" or "FRAG" (optional, default: "SMOKE")
 * 3: context <ARRAY> - optional ["DANGER", generation, expiry] cancellation contract
 *
 * Return Value:
 * Boolean - true when a carried grenade was queued; FiredMan/projectile evidence confirms deployment
 *
 * Example:
 * [_unit, _enemyPos, "FRAG"] call WAIT_fnc_CortexThrowGrenade;
 * Result: the lead assaulter throws a grenade before the final rush.
 *
 * Current callers: WAIT_fnc_CortexFlankStep, WAIT_fnc_CortexRetreat and WAIT_fnc_DangerSmokeStep.
 */

params [["_unit", objNull, [objNull]], ["_towards", [], [[]]], ["_kind", "SMOKE", [""]], ["_context",[],[[]]]];
if (isNull _unit || {!alive _unit} || {!local _unit} || {vehicle _unit != _unit} || {count _towards < 2}) exitWith {false};
if (!([_unit] call WAIT_fnc_CortexCombatEffective)
    || {[_unit] call WAIT_fnc_CompatibilityExternalControl}) exitWith {false};
_kind=toUpperANSI _kind;
if (!(_kind in ["SMOKE","FRAG"]) || {!([group _unit] call WAIT_fnc_CortexIsEligible)}) exitWith {false};
private _simulations = if (_kind == "FRAG") then {["shotGrenade"]} else {["shotSmoke", "shotSmokeX"]};
if (toUpperANSI _kind == "FRAG") then {
    private _distance = _unit distance2D _towards;
    private _side = side group _unit;
    if (_distance < 8 || {_distance > 40}) exitWith {_simulations = []};
    if ((_towards nearEntities ["CAManBase", 12]) findIf {
        private _otherSide = side group _x;
        alive _x && {captive _x || {_x getVariable ["ace_captives_isSurrendering",false]}
            || {_otherSide == civilian} || {_side getFriend _otherSide >= 0.6}}
    } >= 0) then {_simulations = []};
};
if (_simulations isEqualTo []) exitWith {false};
private _throwConfig = configFile >> "CfgWeapons" >> "Throw";
private _muzzles = getArray (_throwConfig >> "muzzles");
private _thrown = false;
{
    private _magazine = _x;
    private _ammo = getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
    private _ammoConfig = configFile >> "CfgAmmo" >> _ammo;
    // Chemlights inherit from SmokeShell and ACE flashbangs use the grenade simulations: neither is
    // the smoke screen or fragmentation grenade the drill asked for.
    if (getText (_ammoConfig >> "simulation") in _simulations
        && {!(_ammo isKindOf ["Chemlight_base", configFile >> "CfgAmmo"])}
        && {getNumber (_ammoConfig >> "ace_grenades_flashbang") != 1}) then {
        private _muzzleIndex = _muzzles findIf {_magazine in getArray (_throwConfig >> _x >> "magazines")};
        if (_muzzleIndex >= 0) then {
            private _muzzle = _muzzles select _muzzleIndex;
            // A throw leaves along the unit's current facing. Do not alter facing until the queued
            // release has revalidated WAIT, Zeus, specialist, generation and ammunition ownership.
            if (_kind == "FRAG") then {_unit setVariable ["WAIT_Cortex_FragCancelled",nil]};
            private _drillToken=(((group _unit) getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["drill",createHashMap]) getOrDefault ["token",""];
            private _throwGeneration=(_unit getVariable ["WAIT_Cortex_ThrowGeneration",0])+1;
            _unit setVariable ["WAIT_Cortex_ThrowGeneration",_throwGeneration];
            _unit setVariable ["WAIT_Cortex_ThrowDecision",[time,"QUEUED",_kind,_throwGeneration]];
            private _operationGeneration=(group _unit) getVariable ["WAIT_OperationGeneration",0];
            private _ownerEpoch=(group _unit) getVariable ["WAIT_AIPass_Epoch",0];
            private _release = {
                params ["_unit", "_muzzle", "_magazine", "_group", "_hold", "_kind", "_towards", "_drillToken", "_context", "_expires", "_retry", "_throwGeneration", "_operationGeneration", "_ownerEpoch"];
                // A newer request supersedes this queued attempt without cancelling its frag token.
                if ((_unit getVariable ["WAIT_Cortex_ThrowGeneration",-1]) != _throwGeneration) exitWith {};
                private _cancel = {
                    params [["_reason","OWNERSHIP_OR_SAFETY",[""]],["_details",[],[[]]]];
                    _unit setVariable ["WAIT_Cortex_ThrowDecision",[time,_reason,_kind,_throwGeneration,_details]];
                    if (_kind == "FRAG" && {_drillToken != ""}) then {
                        _unit setVariable ["WAIT_Cortex_FragCancelled",_drillToken];
                    };
                };
                if ((_group getVariable ["WAIT_OperationGeneration",0]) != _operationGeneration
                    || {(_group getVariable ["WAIT_AIPass_Epoch",0]) != _ownerEpoch}
                    || {!local _group}
                    || {currentCommand _unit in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}) exitWith {
                    ["NEW_TASK",[_operationGeneration,_group getVariable ["WAIT_OperationGeneration",0],
                        _ownerEpoch,_group getVariable ["WAIT_AIPass_Epoch",0],currentCommand _unit]] call _cancel;
                };
                if (!([_unit] call WAIT_fnc_CortexCombatEffective) || {!local _unit} || {vehicle _unit != _unit} || {group _unit != _group}
                    || {[_unit] call WAIT_fnc_CompatibilityExternalControl}
                    || {!([_group] call WAIT_fnc_CortexIsEligible)}
                    || {(_group getVariable ["WAIT_AIPass_ZeusHold",[]]) isNotEqualTo _hold}
                    || {!(_magazine in magazines _unit)}
                    || {(((_group getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["drill",createHashMap]) getOrDefault ["token",""]) != _drillToken}) exitWith {[] call _cancel};
                // Reject at the callback scope: exitWith inside the context block only left
                // that block and allowed stale danger work to reach weapon release below.
                private _dangerInvalid=count _context == 3 && {(_context select 0) == "DANGER"} && {
                    !([_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled)
                        || {!([_group,"WAIT_AIPass_DangerSmoke_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
                        || {(_context select 1) != (_group getVariable ["WAIT_Danger_Generation",-1])}
                        || {time >= (_context select 2)}
                        || {[_group] call WAIT_fnc_CortexExternalTakeover}
                };
                if (_dangerInvalid) exitWith {[] call _cancel};
                if (count _context == 3 && {(_context select 0) == "DANGER"}) then {
                    private _reservation=_unit getVariable ["WAIT_Cortex_ActorMove",[]];
                    if (count _reservation == 3 && {(_reservation param [2,-1,[0]]) > time}) then {
                        _dangerInvalid=true;
                    };
                };
                if (_dangerInvalid) exitWith {["ACTOR_RESERVED"] call _cancel};
                // A queued screen must still face the retained contact at release. Observation
                // may change during alignment; cancel rather than throw along an obsolete bearing.
                private _contactChanged=false;
                if (count _context == 3 && {(_context select 0) == "DANGER"}) then {
                    private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
                    private _contact=_state getOrDefault ["enemyPos",[]];
                    _contactChanged=!(_state getOrDefault ["contactKnowledge",false]) || {count _contact < 2};
                    if (!_contactChanged) then {
                        private _contactBearing=_unit getDir _contact;
                        private _throwBearing=_unit getDir _towards;
                        _contactChanged=abs (((_throwBearing-_contactBearing+540) % 360)-180) > 60;
                    };
                };
                if (_contactChanged) exitWith {["CONTACT_CHANGED",[+_towards]] call _cancel};
                if (_kind == "FRAG" && {_drillToken != ""}
                    && {!([_group,"WAIT_AIPass_Assault_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) exitWith {[] call _cancel};
                _unit doWatch _towards;
                // setDir changes the object transform without proving the prone throwing animation
                // has turned. Never force release into the actor's previous facing. A bounded
                // asynchronous aiming window leaves the manoeuvre element free to continue.
                private _bearing = _unit getDir _towards;
                private _bodyError = abs (((getDir _unit - _bearing + 540) % 360) - 180);
                // A lowered rifle can point across a standing actor's chest even when looking
                // towards contact. Its muzzle is not the grenade release orientation.
                private _aim = eyeDirection _unit;
                private _aimBearing = (_aim select 0) atan2 (_aim select 1);
                private _aimError = abs (((_aimBearing - _bearing + 540) % 360) - 180);
                if (_bodyError > 30 || {_aimError > 30}) exitWith {
                    if (time >= _expires) then {
                        ["ALIGNMENT_TIMEOUT",[_bodyError,_aimError,_muzzle,currentWeapon _unit,stance _unit]] call _cancel;
                    } else {
                        [_retry,+_this,0.25] call CBA_fnc_waitAndExecute;
                    };
                };
                _unit setVariable ["WAIT_Cortex_ThrowDecision",[time,"ALIGNED",_kind,_throwGeneration,[_bodyError,_aimError,_muzzle]]];
                // Observe the native release once; never steer or replace the projectile.
                private _oldTrace=_unit getVariable ["WAIT_Cortex_ThrowTraceHandler",-1];
                if (_oldTrace >= 0) then {_unit removeEventHandler ["FiredMan",_oldTrace]};
                _unit setVariable ["WAIT_Cortex_ThrowTracePending",[_magazine,+_towards,_kind,_throwGeneration]];
                private _traceHandler=_unit addEventHandler ["FiredMan",{
                    params ["_actor","_weapon","_muzzle","_mode","_ammo","_magazine","_projectile"];
                    private _pending=_actor getVariable ["WAIT_Cortex_ThrowTracePending",[]];
                    if (_weapon == "Throw" && {count _pending == 4} && {_magazine == (_pending select 0)}) then {
                        private _velocity=velocity _projectile;
                        private _bearing=_actor getDir (_pending select 1);
                        private _directionAvailable=!isNull _projectile
                            && {((_velocity select 0)^2+(_velocity select 1)^2) > 0.01};
                        private _launchBearing=if (_directionAvailable) then {(_velocity select 0) atan2 (_velocity select 1)} else {-1};
                        private _error=if (_directionAvailable) then {abs (((_launchBearing-_bearing+540) % 360)-180)} else {-1};
                        private _trace=[time,_pending select 2,_pending select 3,+(_pending select 1),_bearing,_launchBearing,_error,_velocity,_directionAvailable];
                        _actor setVariable ["WAIT_Cortex_ThrowReleaseTrace",_trace];
                        diag_log format ["WAIT GRENADE RELEASE TRACE: %1 %2",netId _actor,_trace];
                        _actor removeEventHandler ["FiredMan",_thisEventHandler];
                        _actor setVariable ["WAIT_Cortex_ThrowTraceHandler",-1];
                        _actor setVariable ["WAIT_Cortex_ThrowTracePending",nil];
                    };
                }];
                _unit setVariable ["WAIT_Cortex_ThrowTraceHandler",_traceHandler];
                [{
                    params ["_actor","_handler"];
                    if ((_actor getVariable ["WAIT_Cortex_ThrowTraceHandler",-1]) == _handler) then {
                        _actor removeEventHandler ["FiredMan",_handler];
                        _actor setVariable ["WAIT_Cortex_ThrowTraceHandler",-1];
                        _actor setVariable ["WAIT_Cortex_ThrowTracePending",nil];
                    };
                },[_unit,_traceHandler],3] call CBA_fnc_waitAndExecute;
                if (_kind == "FRAG") then {
                    private _distance=_unit distance2D _towards;
                    private _side=side _group;
                    if (_distance < 8 || {_distance > 40} || {
                        (_towards nearEntities ["CAManBase",12]) findIf {
                            alive _x && {captive _x || {_x getVariable ["ace_captives_isSurrendering",false]}
                                || {side group _x == civilian} || {_side getFriend (side group _x) >= 0.6}}
                        } >= 0
                    }) exitWith {[] call _cancel};
                    private _old = _unit getVariable ["WAIT_Cortex_FragHandler",-1];
                    if (_old >= 0) then {_unit removeEventHandler ["FiredMan",_old]};
                    _unit setVariable ["WAIT_Cortex_FragFlight",[_drillToken,objNull,false,_magazine,-1]];
                    private _handler = _unit addEventHandler ["FiredMan",{
                        params ["_actor","_weapon","_muzzle","_mode","_ammo","_magazine","_projectile"];
                        private _flight = _actor getVariable ["WAIT_Cortex_FragFlight",[]];
                        if (_weapon == "Throw" && {count _flight == 5} && {_magazine == (_flight select 3)}) then {
                            _flight set [1,_projectile];
                            _flight set [2,true];
                            _flight set [4,time];
                            _actor removeEventHandler ["FiredMan",_thisEventHandler];
                            _actor setVariable ["WAIT_Cortex_FragHandler",-1];
                        };
                    }];
                    _unit setVariable ["WAIT_Cortex_FragHandler",_handler];
                    [{
                        params ["_actor","_handler"];
                        if ((_actor getVariable ["WAIT_Cortex_FragHandler",-1]) == _handler) then {
                            _actor removeEventHandler ["FiredMan",_handler];
                            _actor setVariable ["WAIT_Cortex_FragHandler",-1];
                        };
                    },[_unit,_handler],10] call CBA_fnc_waitAndExecute;
                _unit setVariable ["WAIT_Cortex_ThrowDecision",[time,"RELEASE_REQUESTED",_kind,_throwGeneration,[_muzzle,currentWeapon _unit,stance _unit,+_towards,getDir _unit,eyeDirection _unit]]];
                    _unit forceWeaponFire [_muzzle,_muzzle];
                } else {
                _unit setVariable ["WAIT_Cortex_ThrowDecision",[time,"RELEASE_REQUESTED",_kind,_throwGeneration,[_muzzle,currentWeapon _unit,stance _unit,+_towards,getDir _unit,eyeDirection _unit]]];
                    _unit forceWeaponFire [_muzzle,_muzzle];
                };
            };
            [_release, [_unit,_muzzle,_magazine,group _unit,+(group _unit getVariable ["WAIT_AIPass_ZeusHold",[]]),_kind,+_towards,_drillToken,+_context,time+1.5,_release,_throwGeneration,_operationGeneration,_ownerEpoch]] call CBA_fnc_execNextFrame;
            _thrown = true;
        };
    };
    if (_thrown) exitWith {};
} forEach (magazines _unit);
_thrown


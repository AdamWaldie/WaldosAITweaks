/*
 * Author: WaldoTheWarfighter
 * Applies one expiring combined-arms contact role on the selected asset owner.
 * Direct fire requires a combat-effective local gunner and target-suitable loaded station ammo;
 * incapacitated operators or incompatible target classes reject the exact reservation.
 * A direct-fire ground vehicle receives fresh receipt-bounded knowledge and one gunner fire request without losing
 * its authored route. Manoeuvring vehicles and aircraft receive knowledge only: their finite
 * operation owns later target and weapon commands after movement/release geometry is valid. A second
 * ground vehicle receives a finite safe-side manoeuvre destination selected once from a bounded set
 * which keeps the support fire lane clear and avoids water, cliff-like slopes and unnecessarily rough
 * ground. Engine pathfinding remains responsible for the actual route. Airborne aircraft receive the
 * same target and may start their existing finite attack-run job;
 * its controller, rather than a single instantaneous speed sample, proves progress or handles a stall.
 * Locality/authority: current group owner only; server-issued public token must still match. Asset
 * aircraft discovery requires the pilot's group; ground discovery accepts the commander's or driver's group.
 * Repeat/JIP: duplicate roles are harmless; expiry, Zeus takeover, feature closure and token replacement reject stale calls.
 * Contact positions require exactly three finite numeric ATL components, each within +/-1e6m.
 * Invalid payloads reject before local cooldown or server reservation; no live-target fallback is used.
 * Arguments: 0: asset group <GROUP>; 1: opportunity <ARRAY>
 * [token,requester,target,position,role,expiry,ground-fire anchor,contact receipt].
 * Receipt [1,original observedAt,confidence] may reveal only within10s and at sender-bounded confidence.
 * Legacy seven-field roles grant no new knowledge. Owner replay never renews the receipt.
 * Return Value: Boolean, true when the role was applied.
 * Current callers: WAIT_fnc_CortexCombinedArmsServer through remote execution.
 * Example: [_vehicleGroup,_opportunity] remoteExecCall ["WAIT_fnc_CortexCombinedArmsLocal",groupOwner _vehicleGroup];
 */
params [["_group",grpNull,[grpNull]],["_opportunity",[],[[]]]];
if (!local _group || {!(missionNamespace getVariable ["WAIT_AIPass_Active",false])}
    || {[] call WAIT_fnc_CortexIsPaused} || {!((count _opportunity) in [7,8])} || {!([_group] call WAIT_fnc_CortexIsEligible)}) exitWith {false};
_opportunity params ["_token","_requester","_target","_position","_role","_expiry","_context"];
if ((_group getVariable ["WAIT_Cortex_CombinedRole",[]]) isNotEqualTo _opportunity
    || {serverTime >= _expiry} || {isNull _requester} || {isNull _target} || {!alive _target}
    || {side _group != side _requester} || {(side _group) getFriend side _target >= 0.6}
    || {captive _target} || {_target getVariable ["ace_captives_isSurrendering",false]}
    || {_target getVariable ["ace_captives_isHandcuffed",false]}
    || {!(_position isEqualType [])} || {count _position != 3}
    || {_position findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} >= 0}
    || {!(_role in ["GROUND_FIRE","GROUND_MANOEUVRE","AIR_ATTACK"])}) exitWith {false};
private _asset=objNull;
{
    private _vehicle=vehicle _x;
    private _commander=effectiveCommander _vehicle;
    private _driver=driver _vehicle;
    if (_vehicle != _x && {alive _vehicle}
        && {if (_vehicle isKindOf "Air") then {
            !isNull _driver && {group _driver == _group}
        } else {
            (!isNull _commander && {group _commander == _group})
                || {!isNull _driver && {group _driver == _group}}
        }}) exitWith {_asset=_vehicle};
} forEach units _group;
if (isNull _asset) exitWith {false};
if (_role in ["GROUND_FIRE","GROUND_MANOEUVRE"] && {
    !(_asset isKindOf "LandVehicle") || {_asset isKindOf "StaticWeapon"}
        || {!([_group,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
        || {!([_group,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
}) exitWith {false};
if (_role == "AIR_ATTACK" && {
    !(_asset isKindOf "Air") || {isTouchingGround _asset}
        || {!([_group,"WAIT_Cortex_AirAttack_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
}) exitWith {false};
// Server reservation is not permission to replace a different live owner operation.
// Fire-only support does not claim movement; a manoeuvre must match the existing intent.
private _existingOperation=_group getVariable ["WAIT_Operation",createHashMap];
if (_role == "GROUND_MANOEUVRE" && {count _existingOperation > 0}
    && {(_existingOperation getOrDefault ["intent",""]) != "COMBINED_GROUND"
        || {(_existingOperation getOrDefault ["objective",objNull]) isNotEqualTo _target}}) exitWith {
    _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"OTHER_INTENT_ACTIVE",serverTime,_target],true];
        [_group,_opportunity,"OTHER_INTENT_ACTIVE",clientOwner] remoteExecCall ["WAIT_fnc_CortexCombinedRejectServer",2];
    false
};
// Role discovery and weapon preflight may take longer than an external order transition.
// Recheck before assigning targets or starting a finite manoeuvre.
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {false};
// A role receipt is not a new sighting. Legacy roles can use independent native
// knowledge, but never manufacture confidence or a fresh observation on replay.
private _contactReceipt=_opportunity param [7,[],[[]]];
private _freshReport=count _contactReceipt == 3 && {(_contactReceipt select 0) isEqualTo 1}
    && {(_contactReceipt select 1) isEqualType 0} && {finite (_contactReceipt select 1)}
    && {(_contactReceipt select 1) >= 0} && {(_contactReceipt select 1) <= serverTime+1}
    && {serverTime-(_contactReceipt select 1) <= 10}
    && {(_contactReceipt select 2) isEqualType 0} && {finite (_contactReceipt select 2)}
    && {(_contactReceipt select 2) > 0} && {(_contactReceipt select 2) <= 2.5};
if (_freshReport) then {_group reveal [_target,_contactReceipt select 2]};
if (_role == "GROUND_FIRE") exitWith {
    private _gunner=gunner _asset;
    // Knowledge is shared with the whole crew, but only the weapon operator receives an explicit
    // target. Ordering the driver/commander to attack can replace the vehicle's current route with
    // native pursuit. GROUND_MANOEUVRE and AIR_ATTACK deliberately skip this block because their
    // operation controllers own the later target/release boundary.
    private _fireRefusal=if (_group knowsAbout _target > 0) then {""} else {"NO_KNOWN_CONTACT"};
    if (isNull _gunner || {!([_gunner] call WAIT_fnc_CortexCombatEffective)} || {!local _gunner}
        || {!simulationEnabled _asset} || {isObjectHidden _asset}
        || {!simulationEnabled _gunner} || {isObjectHidden _gunner}
        || {!(combatMode _group in ["YELLOW","RED"])}
        || {!(unitCombatMode _gunner in ["YELLOW","RED"])}
        || {isPlayer _gunner} || {!isNull remoteControlled _gunner}
        || {([_gunner] call WAIT_fnc_CortexExternalOwner) != ""}
        || {[_gunner] call WAIT_fnc_CompatibilityExternalControl}
        || {[_group] call WAIT_fnc_CortexExternalTakeover}) then {_fireRefusal="NO_FIRE_OPERATOR"};
    if (_fireRefusal == "" && {!([_asset,_gunner] call WAIT_fnc_CortexGroundFireReady)}) then {_fireRefusal="NO_STATION_AMMO"};
    if (_fireRefusal == "" && {!([_asset,_gunner,_target] call WAIT_fnc_CortexGroundFireReady)}) then {_fireRefusal="NO_TARGET_AMMO"};
    if (_fireRefusal == "" && {!([_gunner,aimPos _target] call WAIT_fnc_CortexLineOfFireClear)}) then {
        _fireRefusal="BLOCKED_FIRE_LANE";
    };
    if (_fireRefusal != "") exitWith {
        _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,_fireRefusal,serverTime,_target],true];
        [_group,_opportunity,_fireRefusal,clientOwner] remoteExecCall ["WAIT_fnc_CortexCombinedRejectServer",2];
        false
    };
    _gunner doTarget _target;
    _gunner doFire _target;
    _group setVariable ["WAIT_Cortex_CombinedApplied",[_token,clientOwner,serverTime],true];
    _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"APPLIED",serverTime,_target],true];
    true
};
if (_role == "GROUND_MANOEUVRE") exitWith {
    private _start=getPosATL _asset;
    // Route geometry belongs to the authenticated contact report. An unseen moving enemy
    // must not silently update this committed firing-area plan through its live coordinates.
    private _targetPosition=+_position;
    private _supportPosition=if (count _context >= 2) then {+_context} else {getPosATL leader _requester};
    private _axis=_targetPosition vectorDiff _supportPosition;
    _axis set [2,0];
    if (vectorMagnitude _axis < 1) then {_axis=[sin getDir _asset,cos getDir _asset,0]};
    _axis=vectorNormalized _axis;
    private _left=[-(_axis select 1),_axis select 0,0];
    private _relative=_start vectorDiff _supportPosition;
    private _side=if ((_relative vectorDotProduct _left) < 0) then {_left vectorMultiply -1} else {_left};
    // These are alternative firing areas, not a scripted movement profile. Sampling a few ranges
    // and lateral offsets makes the same contact opportunity usable on hills and rough terrain while
    // keeping the engine free to choose roads and avoid local obstacles.
    private _candidates=[];
    {
        private _standOff=_x;
        {
            private _destination=_targetPosition vectorAdd (_axis vectorMultiply -_standOff);
            _destination=_destination vectorAdd (_side vectorMultiply _x);
            _destination set [2,0];
            _candidates pushBack [_destination];
        } forEach [260,320,380];
    } forEach [180,240];
    private _selected=[_start,_candidates,_targetPosition,[_supportPosition],_target,"VEHICLE"]
        call WAIT_fnc_CortexSelectAvenue;
    if (_selected isEqualTo []) exitWith {
        _group setVariable ["WAIT_Cortex_CombinedApplied",[_token,clientOwner,serverTime],true];
        _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"NO_SAFE_ROUTE",serverTime,_target],true];
        [_group,_opportunity,"NO_SAFE_ROUTE",clientOwner] remoteExecCall ["WAIT_fnc_CortexCombinedRejectServer",2];
        false
    };
    private _destination=_selected select ((count _selected)-1);
    if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {false};
    if !([_group,"COMBINED_GROUND",true,_expiry] call WAIT_fnc_CortexOwnershipLease) exitWith {
        _group setVariable ["WAIT_Cortex_CombinedApplied",[_token,clientOwner,serverTime],true];
        _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"EXTERNAL_BUSY",serverTime,_target],true];
        [_group,_opportunity,"EXTERNAL_BUSY",clientOwner] remoteExecCall ["WAIT_fnc_CortexCombinedRejectServer",2];
        false
    };
    // This remains native vehicle pathfinding, but the temporary firing-area move has a common
    // lifecycle so a later Zeus order, locality migration or role expiry cannot leave an orphaned
    // combined-arms waypoint behind.
    private _operation=[_group,"COMBINED_GROUND",_target,[],[_destination],"MANOEUVRE"] call WAIT_fnc_OperationStart;
    if (count _operation == 0) exitWith {
        [_group,"COMBINED_GROUND",false] call WAIT_fnc_CortexOwnershipLease;
        _group setVariable ["WAIT_Cortex_CombinedApplied",[_token,clientOwner,serverTime],true];
        _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"OWNER_LOST",serverTime,_target],true];
        [_group,_opportunity,"OWNER_LOST",clientOwner] remoteExecCall ["WAIT_fnc_CortexCombinedRejectServer",2];
        false
    };
    private _generation=_operation get "generation";
    private _waypoint=[_group,_destination,55,"MOVE",_generation] call WAIT_fnc_CortexGroupMove;
    if (isNull (_waypoint param [0,grpNull,[grpNull]]) || {(_waypoint param [1,-1,[0]]) < 0}
        || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {
        [_group,_generation,"INCOMPLETE","MOVEMENT_REJECTED"] call WAIT_fnc_OperationRelease;
        [_group,"COMBINED_GROUND",false] call WAIT_fnc_CortexOwnershipLease;
        _group setVariable ["WAIT_Cortex_CombinedApplied",[_token,clientOwner,serverTime],true];
        _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"MOVEMENT_REJECTED",serverTime,_target],true];
        [_group,_opportunity,"MOVEMENT_REJECTED",clientOwner] remoteExecCall ["WAIT_fnc_CortexCombinedRejectServer",2];
        false
    };
    private _state=[_group] call WAIT_fnc_CortexGroupState;
    _state set ["movementLease",["COMBINED_GROUND",time+((_expiry-serverTime) max 5)]];
    [WAIT_fnc_CortexCombinedGroundStep,createHashMapFromArray [
        ["group",_group],["asset",_asset],["target",_target],["token",_token],
        ["expiry",_expiry],["destination",_destination],["operationGeneration",_operation get "generation"],
        ["ownerEpoch",_operation get "ownerEpoch"],["lastPosition",_start],
        ["progressAt",time],["stalls",0]
    ],1] call WAIT_fnc_CortexQueueJob;
    _group setVariable ["WAIT_Cortex_CombinedApplied",[_token,clientOwner,serverTime],true];
    _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"APPLIED",serverTime,_target,_destination],true];
    true
};
if (_role == "AIR_ATTACK") exitWith {
    // The aircraft owner alone has an authoritative view of loaded magazines, pylon mapping and
    // occupied turrets. Do this read-only preflight before claiming an air role, so a transport or
    // incompatible loadout cannot look like an accepted attack and then circle without firing.
    private _plan=[_asset,_target] call WAIT_fnc_CortexAirAttackPlan;
    if (_plan isEqualTo createHashMap) exitWith {
        _group setVariable ["WAIT_Cortex_CombinedApplied",[_token,clientOwner,serverTime],true];
        _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"NO_VIABLE_WEAPON",serverTime,_target],true];
        [_requester,_group,_token] remoteExecCall ["WAIT_fnc_CortexCombinedAirFallbackServer",2];
        false
    };
    if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {false};
    // Acceptance must correspond to this target, not merely an aircraft's busy marker.
    private _started=[createHashMapFromArray [["aircraft",_asset],["group",_group],["target",_target]],0.5] call WAIT_fnc_AirAttackOperationStart;
    if (!_started) exitWith {
        _group setVariable ["WAIT_Cortex_CombinedApplied",[_token,clientOwner,serverTime],true];
        _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"AIR_BUSY_OR_REFUSED",serverTime,_target],true];
        [_requester,_group,_token] remoteExecCall ["WAIT_fnc_CortexCombinedAirFallbackServer",2];
        false
    };
    _group setVariable ["WAIT_Cortex_CombinedApplied",[_token,clientOwner,serverTime],true];
    _group setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"APPLIED",serverTime,_target],true];
    true
};
false

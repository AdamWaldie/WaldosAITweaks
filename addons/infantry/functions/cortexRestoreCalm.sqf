/*
 * Author: WaldoTheWarfighter
 * Remount cleanup preserves a newer vehicle assignment from Zeus or another controller.
 * Returns a group to CALM and undoes everything the pass changed for the engagement.
 * Ends an active drill synchronously before consuming its restoration data; queued
 * steps then find no matching drill and cannot revive the old movement.
 *
 * Restores recorded changes: a retreat combat-mode lease goes back to its prior value only while
 * the group still has Cortex's applied value; behaviour goes back to the value
 * recorded at first contact only if the pass changed it and the group is still in COMBAT (a squad
 * that was SAFE before an actual firefight comes back AWARE, not SAFE); speed goes
 * back only if the pass changed it. Pass waypoints are removed so the group resumes its own
 * waypoints, the search or investigation team and soldiers holding ground from a drill rejoin
 * formation, stances still matching the recorded Cortex value go back to AUTO, and infantry
 * dismounted by the pass remount their
 * vehicle. Morale is kept and recovers slowly.
 * Locality and authority: call where the group is local.
 *
 * Review contract: Investigation can change SAFE to AWARE; cleanup restores that recorded behaviour as well as a COMBAT change. Only the local group owner performs restoration.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP> - from WAIT_fnc_CortexGroupState
 *
 * 2: allow remount <BOOL>, true; false during stop, ownership restoration or external takeover.
 * 3: yield to external order <BOOL>, false; when true Cortex removes its owned controls and
 *    preserves identifiable replacement commands, behaviour and speed.
 * 4: transition reason <STRING>, "RESTORED"; published with the CALM handover.
 * 5: force transition record <BOOL>, false; used only when a new owner must replace a stale public
 *    phase even though its fresh local state already begins in CALM.
 * Repeat/JIP: removes only WAIT transient orders and restores recorded values.
 * Explicitly tracked Cortex holds and their public actor markers restore PATH and resume formation
 * even if local state vanished during migration or combat relabelled doStop as ATTACK/FIRE.
 * Search teams never restore PATH because Cortex did not disable it for that action;
 * ordinary cleanup ends their stale search move, while external takeover preserves a replacement
 * MOVE or other command. Commands which cannot be a combat-side effect of a hold survive.
 * Pending remount intent is public for owner migration; GroupTick retries for up to 60 seconds.
 * Any finite COMPAT movement handover is released before its local support token is erased.
 * The per-engagement native-contact marker and targetless vehicle dismount lease are also cleared,
 * so a later danger-only wake cannot inherit permission to search or exit from an earlier event.
 * Return Value:
 * Nothing
 *
 * Example:
 * [_group, _state] call WAIT_fnc_CortexRestoreCalm;
 * Result: the group carries on with its mission as it was before contact.
 *
 * Current callers: CortexGroupTick, CortexReleaseGroup, CortexLocality and CortexOnboardContact.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_allowRemount",true,[true]], ["_yieldToExternal",false,[true]], ["_reason","RESTORED",[""]], ["_forcePhase",false,[true]]];
private _reverseCleanup=_group getVariable ["WAIT_VehicleReverse",[]];
if (local _group && {count _reverseCleanup == 9}) then {
    [_group,_state,objNull,[],"RELEASE",_reverseCleanup select 1] call WAIT_fnc_CortexVehicleReverseStep;
};
if (isNull _group || {!local _group}) exitWith {};
// A cleanup can run before the engine elects a replacement leader. All WAIT-owned followers use
// this viable local anchor; external handovers still suppress the follow command below.
private _leader=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
// A pending drill step may not run until after a checkpoint or ownership change.
// Restore its movement restrictions now, before clearing the checkpoint below.
if (count (_state getOrDefault ["drill",createHashMap]) > 0) then {
    [_group,_state,"CALM"] call WAIT_fnc_CortexFlankEnd;
};
private _releaseOwnedHold={
    params ["_unit",["_restorePath",true],["_returnSearchTeam",false]];
    if (local _unit && {group _unit == _group}) then {
        if (_restorePath) then {
            _unit enableAI "PATH";
            _unit setVariable ["WAIT_Cortex_SupportPathHold",nil,true];
        };
        private _command=toUpperANSI currentCommand _unit;
        private _ownedHold=_command in ["","STOP","ATTACK","FIRE","SUPPRESS"];
        // A replacement controller may intentionally leave a unit stationary, firing or holding
        // position. Remove only WAIT's PATH lease during that handover; do not turn a neutral
        // engine command into a new follow order.
        if ((!_yieldToExternal && {_ownedHold}) || {_returnSearchTeam && {!_yieldToExternal}}) then {
            _unit doFollow _leader;
        };
    };
};
private _supportHeld=_state getOrDefault ["supportHeld",[]];
{
    if (_x getVariable ["WAIT_Cortex_SupportPathHold",false]) then {_supportHeld pushBackUnique _x};
} forEach units _group;
{[_x,true,false] call _releaseOwnedHold} forEach _supportHeld;
_state deleteAt "supportHeld";
_state deleteAt "supportBoundSequence";
// Withdrawals, calm restoration and external handovers retire the shared assignment.
private _supportLease=_group getVariable ["WAIT_AIPass_SupportLease",[]];
if (count _supportLease == 6 && {(_state getOrDefault ["supportToken",""]) == (_supportLease select 0)}) then {
    [_group,_supportLease select 0,false,_supportLease,clientOwner] remoteExecCall ["WAIT_fnc_CortexSupportAck",2];
};
[_group,"SUPPORT",false] call WAIT_fnc_CortexOwnershipLease;
private _movementOwner=(_state getOrDefault ["movementLease",[]]) param [0,""];
if (_movementOwner != "") then {[_group,_movementOwner,false] call WAIT_fnc_CortexOwnershipLease};
{_state deleteAt _x} forEach ["supportHeld","supportBoundSequence","supportToken","responding","assaulting","respondingTo","respondUntil"];
// Zeus may deliberately replace Cortex's disabled autonomous-attack state while taking over.
// The external handover owns that setting, just as it owns replacement movement and ROE.
if (!_yieldToExternal && {_state getOrDefault ["attackChanged",false]}) then {_group enableAttack (_state getOrDefault ["baseAttack",true])};
private _retreatModeLease = _state getOrDefault ["retreatCombatMode",[]];
if (!_yieldToExternal && {count _retreatModeLease == 2} && {combatMode _group == (_retreatModeLease select 1)}) then {
    _group setCombatMode (_retreatModeLease select 0);
};
[_group] call WAIT_fnc_CortexGroupMoveClear;
// Search movement never disables PATH. Do not enable a mission-disabled feature while
// returning a search team. During an ordinary handback its Cortex MOVE is explicitly
// retired; during a Zeus takeover a MOVE may already be the curator's replacement order.
{if (alive _x) then {[_x,false,true] call _releaseOwnedHold}} forEach (_state getOrDefault ["searchTeam", []]);
// Drill holders are explicit Cortex PATH holds. Retire that ownership on every release,
// including Zeus takeover, while preserving a newer individual command.
{if (alive _x) then {[_x,true,false] call _releaseOwnedHold}} forEach (_state getOrDefault ["holders", []]);
{
    if (local _x && {_x getVariable ["WAIT_AIPass_StanceSet", false]}) then {
        if (toUpperANSI (unitPos _x) == (_x getVariable ["WAIT_Cortex_AppliedStance",""])) then {_x setUnitPos "AUTO"};
        _x setVariable ["WAIT_Cortex_AppliedStance",nil,true];
        _x setVariable ["WAIT_AIPass_StanceSet", nil, true];
    };
    if (local _x) then {
        private _target = _x getVariable ["WAIT_AIPass_VehicleTarget",objNull];
        if (!isNull _target && {assignedTarget _x == _target}) then {_x doTarget objNull};
        _x setVariable ["WAIT_AIPass_VehicleTarget",nil,true];
        _x setVariable ["WAIT_AIPass_TargetHold",nil];
        _x setVariable ["WAIT_Cortex_ActorMove",nil];
    };
} forEach units _group;
private _staticSupport=_group getVariable ["WAIT_Danger_StaticSupport",[]];
if (count _staticSupport >= 7) then {
    private _staticActor=_staticSupport param [1,objNull,[objNull]];
    private _staticWeapon=_staticSupport param [2,objNull,[objNull]];
    if (!_yieldToExternal && {!isNull _staticActor} && {alive _staticActor} && {local _staticActor}
        && {!isNull _staticWeapon} && {assignedVehicle _staticActor == _staticWeapon}) then {
        [_staticActor] orderGetIn false;
        unassignVehicle _staticActor;
        if (vehicle _staticActor == _staticWeapon) then {_staticActor action ["GetOut",_staticWeapon]};
    };
};
_group setVariable ["WAIT_Danger_StaticSupport",nil,true];
_group setVariable ["WAIT_Danger_StaticAttempt",nil,true];
private _staticDeployment=_group getVariable ["WAIT_Danger_StaticDeployment",[]];
if (count _staticDeployment >= 10) then {
    private _deployGunner=_staticDeployment param [2,objNull,[objNull]];
    private _deployedWeapon=_staticDeployment param [7,objNull,[objNull]];
    private _packHandler=_staticDeployment param [10,-1,[0]];
    if (!isNull _deployGunner && {local _deployGunner}) then {
        if (_packHandler >= 0) then {_deployGunner removeEventHandler ["WeaponDisassembled",_packHandler]};
        private _assemblyHandler=_staticDeployment param [12,-1,[0]];
        if (_assemblyHandler >= 0) then {_deployGunner removeEventHandler ["WeaponAssembled",_assemblyHandler]};
        _deployGunner setVariable ["WAIT_Danger_StaticPackContext",nil];
        private _deployMove=_deployGunner getVariable ["WAIT_Cortex_ActorMove",[]];
        if ((_deployMove param [0,""]) in ["STATIC_DEPLOY","STATIC_PACK"]) then {
            _deployGunner setVariable ["WAIT_Cortex_ActorMove",nil];
        };
        if (!_yieldToExternal && {!isNull _deployedWeapon}
            && {assignedVehicle _deployGunner == _deployedWeapon}) then {
            [_deployGunner] orderGetIn false;
            unassignVehicle _deployGunner;
            if (vehicle _deployGunner == _deployedWeapon) then {
                _deployGunner action ["GetOut",_deployedWeapon];
            };
        };
    };
    private _deployAssistant=_staticDeployment param [3,objNull,[objNull]];
    if (!isNull _deployAssistant && {local _deployAssistant}) then {
        private _assistantMove=_deployAssistant getVariable ["WAIT_Cortex_ActorMove",[]];
        if ((_assistantMove param [0,""]) in ["STATIC_DEPLOY","STATIC_PACK"]) then {
            _deployAssistant setVariable ["WAIT_Cortex_ActorMove",nil];
        };
    };
};
_group setVariable ["WAIT_Danger_StaticDeployment",nil,true];
_group setVariable ["WAIT_Danger_StaticDeployAttempt",nil,true];
private _vehicleJink=_state getOrDefault ["vehicleDangerJink",[]];
private _jinkVehicle=_vehicleJink param [1,objNull,[objNull]];
if (!isNull _jinkVehicle && {local _jinkVehicle}) then {
    private _jinkMarker=_jinkVehicle getVariable ["WAIT_Danger_VehicleJink",[]];
    if (_jinkMarker param [1,grpNull,[grpNull]] == _group) then {
        _jinkVehicle setVariable ["WAIT_Danger_VehicleJink",nil,true];
    };
};
private _vehicleOrient=_state getOrDefault ["vehicleDangerOrient",[]];
private _orientVehicle=_vehicleOrient param [1,objNull,[objNull]];
if (!isNull _orientVehicle && {local _orientVehicle}) then {
    private _orientMarker=_orientVehicle getVariable ["WAIT_Danger_VehicleOrient",[]];
    if (_orientMarker param [1,grpNull,[grpNull]] == _group) then {
        if (!_yieldToExternal) then {_orientVehicle sendSimpleCommand "STOPTURNING"};
        _orientVehicle setVariable ["WAIT_Danger_VehicleOrient",nil,true];
    };
};
if (!_yieldToExternal && {_state getOrDefault ["behaviourChanged", false]} && {behaviour _leader in ["COMBAT", "AWARE"]}) then {
    private _base = _state getOrDefault ["baseBehaviour", "AWARE"];
    // After a real firefight a squad stays alert rather than slinging weapons, as the engine does.
    if (_base == "SAFE" && {_state getOrDefault ["hadContact", false]}) then {_base = "AWARE"};
    _group setBehaviour _base;
};
if (!_yieldToExternal && {_state getOrDefault ["speedChanged", false]}) then {
    _group setSpeedMode (_state getOrDefault ["baseSpeed", "NORMAL"]);
};
{
    _x params ["_unit", "_vehicle"];
    if (_allowRemount && {[_group,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled} && {group _unit == _group} && {isNull assignedVehicle _unit || {assignedVehicle _unit == _vehicle}} && {[_group, "WAIT_AIPass_VehicleRemount_Enable", true] call WAIT_fnc_CortexFeatureEnabled} && {[_unit, _vehicle, true] call WAIT_fnc_CortexPassengerReady}) then {
        _unit assignAsCargo _vehicle;
        [_unit] orderGetIn true;
    };
} forEach (_state getOrDefault ["dismounted", []]);
// Retain boarding intent until seats are actually occupied. The public record lets
// a new HC owner continue the bounded attempt; it never moves units into seats.
_group setVariable ["WAIT_Cortex_DismountContinuation",nil,true];
private _boarding = _state getOrDefault ["dismounted", []];
if (_allowRemount && {_boarding isNotEqualTo []}) then {
    _group setVariable ["WAIT_Cortex_Remount",[serverTime+60,+_boarding],true];
};
if (!_allowRemount) then {
    {private _unit=_x select 0; if (local _unit && {vehicle _unit == _unit} && {assignedVehicle _unit == (_x select 1)}) then {[_unit] orderGetIn false; unassignVehicle _unit}} forEach ((_group getVariable ["WAIT_Cortex_Remount",[0,[]]]) select 1);
    _group setVariable ["WAIT_Cortex_Remount",nil,true];
};
{_state deleteAt _x} forEach [
    "consolidationRoutes", "baseAttack", "attackChanged", "areaInvestigation", "enemyPos", "behaviourChanged", "speedChanged", "searchTeam", "dismounted", "onboardContactUntil", "reinforceRequested", "reinforceDispatchedAt",
    "withdrawn", "contactLeader", "lastSeen", "contactKnowledge", "dangerDismount", "holders", "baseBehaviour", "baseSpeed", "armourSeen",
    "armourRequested", "antiArmourRelocation", "coordinated", "coordinatedPendingUntil", "retreatCombatMode", "retreatRetryAt", "movementLease", "retreatStart", "retreatTarget", "retreatProgress", "withdrawOperationGeneration", "vehicleDangerJink", "vehicleDangerOrient", "reserveCommitted", "arrivedAt", "assaulting", "hadContact"
];
_group setVariable ["WAIT_Cortex_Withdrawal",nil,true];
_group setVariable ["WAIT_Cortex_WithdrawalIntent",nil,true];
_group setVariable ["WAIT_Cortex_TransitionIntent",nil,true];
_group setVariable ["WAIT_AIPass_Checkpoint", [], true];
// Explicit terminal handovers remain observable even when the tactical phase was already CALM.
_forcePhase=_forcePhase || {_reason in ["CORTEX_STOPPED","ZEUS_TAKEOVER","EXTERNAL_TAKEOVER"]};
[_group,_state,"CALM",_reason,time,_forcePhase] call WAIT_fnc_CortexSetPhase;
if (missionNamespace getVariable ["WAIT_AIPass_Debug", false]) then {diag_log format ["[WAIT] %1 CALM restored", _group]};

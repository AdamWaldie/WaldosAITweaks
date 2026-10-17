/*
 * Author: WaldoTheWarfighter
 * Release commands preserve live or malformed actor reservations; only typed finite leases expire.
 * Ends a garrison order: soldiers can move again and return to their normal stance. Normal release
 * rejoins formation; replacement-order release clears only a still-owned combat-labelled hold so
 * a new group waypoint can move the soldier without overwriting a newer direct unit command.
 *
 * Re-enables PATH, restores each soldier's recorded stance and rejoins formation, and clears the
 * published order so no machine re-applies it. Called automatically when a garrison breaks (losses
 * or broken morale), or by the AI Orders ZEN module and scripts.
 * Locality and authority: call where the group is local, or on the server, which forwards to the
 * owner.
 *
 * Review contract: Repeated release restores PATH only for soldiers marked as disabled by this garrison. Mission-maker PATH restrictions remain in place; public assignments are cleared for JIP.
 *
 * Restores only unchanged Cortex duck or approach stances; preserves later Zeus/script stance choices.
 * Posture, watch, speed and formation restoration also require a combat-effective actor
 * without actor-specific external ownership, an active reservation or a finite native task.
 * Owned PATH locks and metadata are still retired, allowing replacement tasks to move.
 * Repeat/JIP: repeated release clears published assignments; new owners do not replay a released order.
 * Arguments:
 * 0: group <GROUP or OBJECT>
 * 1: restore formation <BOOL> - false when Zeus already supplied replacement movement (default true)
 * 2: actors <ARRAY of OBJECT>, [] - empty releases the whole group; a non-empty subset retires
 *    only those members and preserves other assignments. The group order retires once no assignments remain.
 *
 * 3: recall formation <BOOL>, true - false for a validated WAIT successor task, avoiding
 *    a protected JOIN command while restoring the old owned PATH/stance/speed/watch holds.
 * Return Value:
 * Boolean - true when released or forwarded
 *
 * Example:
 * [_group] call WAIT_fnc_CortexGarrisonRelease;
 * Result: the defenders leave their positions and fight as a normal squad.
 *
 * Current callers: CortexClearBuilding (no recall handoff), WAIT_fnc_CortexGroupTick, the AI Orders ZEN module and mission scripts.
 */

params [["_group", grpNull, [grpNull, objNull]],["_restore",true,[true]],["_actors",[],[[]]],["_recall",true,[true]]];
if (_group isEqualType objNull) then {_group = group _group};
if (isNull _group) exitWith {false};
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (!local _group) exitWith {
    if (isServer) then {[_group,_restore,_actors,_recall] remoteExecCall ["WAIT_fnc_CortexGarrisonRelease", groupOwner _group]; true} else {false};
};
// No Cortex assignment means there is nothing for this release to restore.
if ((_group getVariable ["WAIT_AIPass_Garrison",[]]) isEqualTo [] && {units _group findIf {(_x getVariable ["WAIT_AIPass_GarrisonPos",[]]) isNotEqualTo []} < 0}) exitWith {false};
// A newer Zeus, player or specialist owner may have replaced this order before this release
// reaches the group owner. WAIT must still remove only its own state, but a feature gate change
// is not an external order: it must release the held element back to its formation.
private _partial=_actors isNotEqualTo [];
if (!_partial) then {_actors=+units _group};
_actors=_actors select {_x isEqualType objNull && {!isNull _x} && {group _x == _group}};
private _externalTakeover = [_group] call WAIT_fnc_CortexExternalTakeover;
private _canRestore = _restore && {!_externalTakeover};
private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
{
    if (local _x) then {
        private _unit = _x;
        private _ownedHold = (_unit getVariable ["WAIT_AIPass_GarrisonPos",[]]) isNotEqualTo []
            || {_unit getVariable ["WAIT_AIPass_GarrisonDisabledPath",false]};
        {_unit removeEventHandler _x} forEach (_unit getVariable ["WAIT_AIPass_GarrisonHandlerIds", []]);
        _unit setVariable ["WAIT_AIPass_GarrisonHandlerIds", nil];
        _unit setVariable ["WAIT_AIPass_GarrisonHandlers", nil];
        _unit setVariable ["WAIT_AIPass_DuckUntil", nil];

        if (_x getVariable ["WAIT_AIPass_GarrisonDisabledPath", false]) then {_x enableAI "PATH"};
        private _reservationFree=!([_unit] call WAIT_fnc_CortexActorMoveReserved);
        private _nativeTask=currentCommand _unit in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"];
        if ([_x] call WAIT_fnc_CortexCombatEffective && {!isPlayer _x}
            && {_reservationFree} && {!_nativeTask} && {isNull objectParent _unit}
            && {isNull remoteControlled _unit}
            && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}) then {
            // A replacement owner receives untouched posture, watch and speed. Normal release
            // still restores WAIT's temporary hold exactly when its own lease remains intact.
            if (unitPos _x == (_x getVariable ["WAIT_Cortex_GarrisonDuckStance", ""])) then {
                if (!_externalTakeover) then {
                    _x setUnitPos (_x getVariable ["WAIT_AIPass_GarrisonStance", "AUTO"]);
                };
            };
            if (!_externalTakeover && {unitPos _x == (_x getVariable ["WAIT_Cortex_GarrisonAppliedStance",""])}) then {
                _x setUnitPos (_x getVariable ["WAIT_AIPass_GarrisonStance","AUTO"]);
            };
            if (!_externalTakeover) then {_x doWatch objNull;};
            if (!_externalTakeover && {getForcedSpeed _x == (_x getVariable ["WAIT_Cortex_GarrisonAppliedSpeed",-2])} && {!isNil {_x getVariable "WAIT_Cortex_GarrisonForcedSpeed"}}) then {
                _x forceSpeed (_x getVariable ["WAIT_Cortex_GarrisonForcedSpeed",-1]);
            };
            private _command = toUpperANSI currentCommand _x;
            private _move=_unit getVariable ["WAIT_Cortex_GarrisonMove",[]];
            private _live=(expectedDestination _unit) param [0,[]];
            private _ownedMove=count _move in [4,5] && {(_move select 0) == _group}
                && {count _move == 4 || {(_move select 4) isEqualTo (_unit getVariable ["WAIT_AIPass_GarrisonPos",[]])}}
                && {(_move select 1) == (_group getVariable ["WAIT_AIPass_GarrisonGeneration",-1])}
                && {(_move select 2) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
                && {count _live == 3} && {count (_move select 3) == 3}
                && {_live vectorDistance (_move select 3) <= 0.25};
            private _recallCommand= !(_command in ["MOVE","FOLLOW"]) || {_command == "MOVE" && {_ownedMove}};
            if (_recallCommand && {_canRestore || {!_externalTakeover && {_ownedHold && {_command in ["","STOP","ATTACK","FIRE","SUPPRESS"]}}}}) then {
                if (_recall) then {_x doFollow _leader};
            };
        };
    };
    _x setVariable ["WAIT_Cortex_GarrisonMove",nil,true];
    _x setVariable ["WAIT_Cortex_GarrisonDuckStance",nil,true];
    _x setVariable ["WAIT_Cortex_GarrisonAppliedStance",nil,true];
    _x setVariable ["WAIT_AIPass_GarrisonDisabledPath", nil, true];
    _x setVariable ["WAIT_AIPass_GarrisonPos", nil, true];
    _x setVariable ["WAIT_AIPass_GarrisonFailed",nil,true];
    _x setVariable ["WAIT_Cortex_GarrisonExteriorAttempts",nil,true];
    _x setVariable ["WAIT_Cortex_GarrisonExteriorTried",nil,true];
    _x setVariable ["WAIT_Cortex_GarrisonExteriorTargets",nil,true];
    _x setVariable ["WAIT_AIPass_GarrisonStance", nil, true];
    _x setVariable ["WAIT_Cortex_GarrisonForcedSpeed",nil,true];
    _x setVariable ["WAIT_Cortex_GarrisonAppliedSpeed",nil,true];
} forEach _actors;
private _hasAssignments=units _group findIf {(_x getVariable ["WAIT_AIPass_GarrisonPos",[]]) isNotEqualTo []} >= 0;
if (!_partial || {!_hasAssignments}) then {
    _group setVariable ["WAIT_AIPass_Garrison", nil, true];
    _group setVariable ["WAIT_Cortex_GarrisonDeadline",nil,true];
    _group setVariable ["WAIT_Cortex_GarrisonPlacement",nil,true];
    _group setVariable ["WAIT_Cortex_GarrisonPending",nil,true];
    _group setVariable ["WAIT_Cortex_GarrisonRefill",nil,true];
    _group setVariable ["WAIT_Cortex_GarrisonRoster",nil,true];
    _group setVariable ["WAIT_Cortex_GarrisonCandidates",nil,true];
    _group setVariable ["WAIT_AIPass_GarrisonApplied", nil];
};

diag_log format ["[WAIT] %1 garrison released actors=%2 partial=%3", _group,count _actors,_partial];
true

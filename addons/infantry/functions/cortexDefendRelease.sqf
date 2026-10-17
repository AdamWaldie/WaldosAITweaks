/*
 * Author: WaldoTheWarfighter
 * Release commands preserve live or malformed actor reservations; only typed finite leases expire.
 * Ends a defence order: soldiers normally rejoin formation and fight as a normal squad. Replacement-
 * order release clears Cortex state and releases only a still-owned combat-labelled hold, so a
 * new group waypoint can move the soldier without overwriting a newer direct unit command.
 * Watch and formation restoration require combat-effective, local actors without player or
 * specialist ownership, active actor reservations or finite native tasks. Metadata cleanup
 * still retires assignments for every member without cancelling replacement tasks.
 * Restoration also requires a typed public receipt bound to this group and exact assignment.
 * A newer MOVE, STOP without an owned HOLD, or any unmatched command keeps its movement and watch.
 * Missing legacy receipts are metadata-only cleanup; repeated identical commands remain ambiguous.
 *
 * Clears each soldier's spot and watch direction and the published order, so no machine re-applies
 * it. Called automatically when a defence breaks (losses or broken morale) or Zeus gives the group
 * waypoints, or by the AI Orders ZEN module and scripts.
 * Locality and authority: call where the group is local, or on the server, which forwards to the
 * owner.
 *
 * Repeat/JIP: repeated release clears published assignments; new owners do not replay a released order.
 * Arguments:
 * 0: group <GROUP or OBJECT>
 * 1: restore formation <BOOL> - false when Zeus already supplied replacement movement (default true)
 * 2: recall owned holds <BOOL> - default true; false for an admitted replacement task, which
 *    supplies fresh movement itself. Together with restore=false this suppresses every recall.
 *
 * Return Value:
 * Boolean - true when released or forwarded
 *
 * Example:
 * [_group] call WAIT_fnc_CortexDefendRelease;
 * Result: the defenders leave the line and move with their leader.
 *
 * Current callers: WAIT_fnc_CortexGroupTick, the AI Orders ZEN module and mission scripts.
 */

params [["_group", grpNull, [grpNull, objNull]],["_restore",true,[true]],["_recallHeld",true,[true]]];
if (_group isEqualType objNull) then {_group = group _group};
if (isNull _group) exitWith {false};
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (!local _group) exitWith {
    if (isServer) then {[_group,_restore,_recallHeld] remoteExecCall ["WAIT_fnc_CortexDefendRelease", groupOwner _group]; true} else {false};
};
// No Cortex assignment means there is nothing for this release to restore.
if ((_group getVariable ["WAIT_AIPass_Defend",[]]) isEqualTo [] && {units _group findIf {(_x getVariable ["WAIT_AIPass_DefendPos",[]]) isNotEqualTo []} < 0}) exitWith {false};
// Clear only WAIT's published order after an external takeover. A normal feature gate change
// still returns the released defence element to formation; it is not an external movement order.
private _externalTakeover = [_group] call WAIT_fnc_CortexExternalTakeover;
private _canRestore = _restore && {!_externalTakeover};
private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
{
    private _command = toUpperANSI currentCommand _x;
    private _assignment=_x getVariable ["WAIT_AIPass_DefendPos",[]];
    private _receipt=_x getVariable ["WAIT_Cortex_DefendMove",[]];
    private _receiptValid=_receipt isEqualType [] && {count _receipt == 6}
        && {(_receipt select 0) isEqualTo _group} && {_assignment isNotEqualTo []}
        && {(_receipt select 4) isEqualTo _assignment}
        && {[1,2] findIf {!((_receipt select _x) isEqualType 0) || {!finite (_receipt select _x)} || {(_receipt select _x) < 0}} < 0}
        && {(_receipt select 2) <= (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {(_receipt select 3) isEqualType []} && {count (_receipt select 3) == 3}
        && {(_receipt select 3) findIf {!(_x isEqualType 0) || {!finite _x}} < 0};
    private _live=(expectedDestination _x) param [0,[],[[]]];
    private _ownedMove=_receiptValid && {_command == "MOVE"} && {(_receipt select 5) == "MOVE"}
        && {count _live == 3} && {_live vectorDistance (_receipt select 3) <= 0.25};
    private _ownedHold=_receiptValid && {_command in ["","STOP"]} && {(_receipt select 5) == "HOLD"}
        && {(getPosATL _x) vectorDistance (_receipt select 3) <= 3};
    private _ownedCommand=_ownedMove || {_ownedHold} || {_receiptValid && {_command == ""}};
    private _reservationFree=!([_x] call WAIT_fnc_CortexActorMoveReserved);
    private _nativeTask=currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"];
    if ([_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
        && {_reservationFree} && {!_nativeTask} && {_ownedCommand} && {isNull objectParent _x}
        && {isNull remoteControlled _x}
        && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}) then {
        if (!_externalTakeover) then {_x doWatch objNull;};
        if (_canRestore || {_recallHeld && {!_externalTakeover && {_ownedHold && {_command in ["","STOP","ATTACK","FIRE","SUPPRESS"]}}}}) then {
            _x doFollow _leader
        };
    };
    _x setVariable ["WAIT_AIPass_DefendPos", nil, true];
    _x setVariable ["WAIT_Cortex_DefendMove",nil,true];
    _x setVariable ["WAIT_AIPass_DefendFailed",nil,true];
    _x setVariable ["WAIT_AIPass_DefendHolding", nil];
    _x setVariable ["WAIT_AIPass_DefendRouteGeneration",nil];
} forEach units _group;
_group setVariable ["WAIT_AIPass_Defend", nil, true];
_group setVariable ["WAIT_Cortex_DefendNativeRoute",nil,true];
_group setVariable ["WAIT_AIPass_DefendApplied", nil];
diag_log format ["[WAIT] %1 defence released", _group];
true

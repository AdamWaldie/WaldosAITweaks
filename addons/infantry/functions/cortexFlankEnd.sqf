/*
 * Author: WaldoTheWarfighter
 * Ends a drill (flank, bounding advance or direct assault). Restores owned unit and group combat-mode overrides only
 * while the current mode still matches the value Cortex applied; later external changes survive.
 *
 * Restores the leader attack-assignment setting and only the AI features the drill disabled. A drill that completed, or stopped because the
 * enemy is close, leaves its members holding the ground they took: they are recorded as "holders" and
 * rejoin formation later (WAIT_fnc_CortexGroupTick, WAIT_fnc_CortexRestoreCalm,
 * WAIT_fnc_CortexRetreat). Any other ending (losses, the squad leaving contact, Zeus taking the
 * group, or release) orders members to follow the leader again at once, unless replacement
 * orders or external ownership prohibit movement commands. A failed coordinated
 * bound instead holds its gained ground until the next server sequence; it must not regroup
 * backwards before a retry. Holding uses an ordinary stop order and never disables PATH, so a
 * replacement mission, Zeus order or locality handover cannot inherit frozen actors.
 * The drill's type-specific cooldown starts: advances may resume sooner than wide flanks. Cleanup
 * releases a TACTICAL_DRILL movement lease only; a newer
 * withdrawal, vehicle, artillery or coordinated-assault owner survives a delayed drill callback.
 * Locality and authority: call where the group is local.
 *
 * Repeat/JIP: an empty drill is a no-op; the ending reason is published for observers and JIP.
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP>
 * 2: reason <STRING> - COMPLETE, CLOSE, ABORT, LOSSES, STALLED, TIME_LIMIT, RELEASE, ZEUS, CALM,
 *    ROE_CHANGED, SPEED_CHANGED, GRENADE_UNRESOLVED, RECOVERY_FAILED, OWNERSHIP_LOST or SCHEDULER_STALLED
 * Unresolved stragglers change COMPLETE/CLOSE to PARTIAL; main actors hold while stragglers rejoin.
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [_group, _state, "COMPLETE"] call WAIT_fnc_CortexFlankEnd;
 * Result: the element stays on the enemy's flank instead of running back to the leader.
 *
 * Current callers: WAIT_fnc_CortexFlankStep and WAIT_fnc_CortexReleaseGroup.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_reason", "", [""]]];
if (isNull _group || {!local _group}) exitWith {};
private _drill = _state getOrDefault ["drill", createHashMap];
if (count _drill == 0) exitWith {};
// An old owner or replaced generation has no authority over feature switches or cleanup.
if ((_drill getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])
    || {(_drill getOrDefault ["operationGeneration",-1]) != (_group getVariable ["WAIT_OperationGeneration",0])}) exitWith {};
private _liveDrill=(_group getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["drill",createHashMap];
if (count _liveDrill > 0 && {(_liveDrill getOrDefault ["token",""]) != (_drill getOrDefault ["token",""])}) exitWith {};
private _liveOperation=_group getVariable ["WAIT_Operation",createHashMap];
private _sameOperation=count _liveOperation == 0 || {(_liveOperation getOrDefault ["generation",-2]) == (_drill getOrDefault ["operationGeneration",-1])};
private _mayRestore=_sameOperation && {!(_reason in ["ZEUS","OWNERSHIP_LOST","EXTERNAL","REPLACED"])}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)};
private _mayCommand = _mayRestore && {!(_reason in ["ZEUS","OWNERSHIP_LOST"])}
    && {[_group] call WAIT_fnc_CortexIsEligible};
private _groupModeLease = _drill getOrDefault ["groupCombatMode",[]];
if (_mayRestore && {count _groupModeLease == 2} && {combatMode _group == (_groupModeLease select 1)}) then {
    _group setCombatMode (_groupModeLease select 0);
};
private _groupSpeedLease = _drill getOrDefault ["groupSpeedMode",[]];
if (_mayRestore && {count _groupSpeedLease == 2} && {speedMode _group == (_groupSpeedLease select 1)}) then {
    _group setSpeedMode (_groupSpeedLease select 0);
};
{
    _x params ["_unit", "_feature"];
    if (alive _unit && {local _unit}) then {_unit enableAI _feature};
} forEach (_drill getOrDefault ["disabled", []]);
{
    _x params ["_unit","_mode",["_ownedMode","BLUE"]];
    if (_mayRestore && {local _unit} && {unitCombatMode _unit == _ownedMode}) then {_unit setUnitCombatMode _mode};
} forEach (_drill getOrDefault ["combatModes",[]]);
{
    _x params ["_unit","_previous","_owned"];
    if (_mayRestore && {local _unit} && {behaviour _unit == _owned}) then {_unit setCombatBehaviour _previous};
} forEach (_drill getOrDefault ["combatBehaviours",[]]);
private _members = (_drill getOrDefault ["units", []]) select {alive _x && {local _x} && {group _x == _group}};
// Retire only the temporary throw listener belonging to this cancelled/completed drill.
// Keep the projectile record: cancellation does not remove a live explosive from the world.
{
    private _flight = _x getVariable ["WAIT_Cortex_FragFlight",[]];
    if (count _flight == 5 && {(_flight select 0) == (_drill getOrDefault ["token",""])}) then {
        private _handler = _x getVariable ["WAIT_Cortex_FragHandler",-1];
        if (_handler >= 0) then {_x removeEventHandler ["FiredMan",_handler]};
        _x setVariable ["WAIT_Cortex_FragHandler",-1];
    };
} forEach _members;
// Listener cleanup above still covers the old roster. Movement cleanup below may affect
// only capable foot actors whose current task has not acquired a newer independent owner.
_members=_members select {
    private _reservation=_x getVariable ["WAIT_Cortex_ActorMove",[]];
    private _free=_reservation isEqualTo [] || {_reservation isEqualType [] && {count _reservation == 3}
        && {(_reservation param [2,1e12,[0]]) <= time}};
    _free && {[_x] call WAIT_fnc_CortexCombatEffective} && {!isPlayer _x} && {isNull objectParent _x}
        && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
private _stragglers = ((_drill getOrDefault ["recovery",[]]) apply {_x select 0}) select {_x in _members};
private _supportToken=_drill getOrDefault ["supportToken",""];
private _lease=_group getVariable ["WAIT_AIPass_SupportLease",[]];
private _holdFailedBound=_mayCommand && {_supportToken != ""}
    && {_reason in ["STALLED","TIME_LIMIT","RECOVERY_FAILED"]}
    && {_state getOrDefault ["assaulting",false]}
    && {count _lease == 6} && {(_lease select 0) == _supportToken}
    && {serverTime < (_lease select 2)}
    && {[_group] call WAIT_fnc_CortexIsEligible};
private _hold = _mayCommand && {_reason in ["COMPLETE","CLOSE"]};
if (_hold && {_stragglers isNotEqualTo []}) then {_reason = "PARTIAL"};
_group setVariable ["WAIT_Cortex_DrillRecovery",[_reason,_stragglers,_drill getOrDefault ["index",-1]],true];
if (_holdFailedBound) then {
    // A failed movement remains a failure. Preserve physical gains while the server
    // yields the turn; doFollow here creates repeated outward/return journeys.
    {
        doStop _x;
    } forEach _members;
} else {
if (_hold) then {
    private _holders = _state getOrDefault ["holders", []];
    {doStop _x; _holders pushBackUnique _x} forEach (_members-_stragglers);
    {_x doFollow leader _group} forEach _stragglers;
    _state set ["holders", _holders];
} else {
    private _leader = leader _group;
    // Zeus has already supplied the replacement movement. Restore Cortex-owned
    // feature switches above, but do not replace that order with formation return.
    if (_mayCommand) then {{_x doFollow _leader} forEach _members};
};
};
if (_supportToken != "") then {
    _group setVariable ["WAIT_Cortex_SupportBoundResult",[_supportToken,_drill get "supportSequence",_reason],true];
} else {
    if (_mayCommand && {_state getOrDefault ["attackChanged",false]}) then {_group enableAttack (_state getOrDefault ["baseAttack",true])};
    _state deleteAt "attackChanged";
    _state deleteAt "baseAttack";
};
private _type = _drill getOrDefault ["type", "FLANK"];
private _operationGeneration=_drill getOrDefault ["operationGeneration",-1];
if (_operationGeneration >= 0) then {
    if (_reason in ["COMPLETE","CLOSE","PARTIAL"]) then {
        [_group,_operationGeneration,["COMPLETE","PARTIAL"] select (_reason == "PARTIAL"),_reason] call WAIT_fnc_OperationRelease;
    } else {
        [_group,_operationGeneration,_reason] call WAIT_fnc_OperationCancel;
    };
};
_group setVariable ["WAIT_Cortex_DrillResult",[_type,_reason,time],true];
[_group,_drill,"ENDED",_reason] call WAIT_fnc_CortexDrillSetStage;
_state deleteAt "drill";
private _movementLease = _state getOrDefault ["movementLease",[]];
if (count _movementLease == 2 && {(_movementLease select 0) == "TACTICAL_DRILL"}) then {
    [_group,"TACTICAL_DRILL",false] call WAIT_fnc_CortexOwnershipLease;
    _state deleteAt "movementLease";
};
private _cooldownName=switch (_type) do {
    case "ADVANCE": {"WAIT_AIPass_Advance_Cooldown"};
    case "ASSAULT": {"WAIT_AIPass_Assault_Cooldown"};
    default {"WAIT_AIPass_Flank_Cooldown"};
};
private _cooldownDefault=switch (_type) do {case "ADVANCE": {20}; case "ASSAULT": {15}; default {90}};
[_state, toLowerANSI _type, missionNamespace getVariable [_cooldownName, _cooldownDefault]] call WAIT_fnc_CortexCooldown;
if (_reason == "COMPLETE") then {
    private _counter=switch (_type) do {
        case "ADVANCE": {"WAIT_AIPass_AdvancesCompleted"};
        case "ASSAULT": {"WAIT_AIPass_AssaultsCompleted"};
        default {"WAIT_AIPass_FlanksCompleted"};
    };
    missionNamespace setVariable [_counter,(missionNamespace getVariable [_counter,0])+1];
};
if (missionNamespace getVariable ["WAIT_AIPass_Debug", false]) then {diag_log format ["[WAIT] %1 %2 end reason=%3", _group, _type, _reason]};

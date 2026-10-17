/*
 * Author: WaldoTheWarfighter
 * Executes an authenticated Zeus order only when the selected group is still local, then acknowledges its result.
 * Locality/authority: server authenticates dispatch; the current owner executes group commands.
 * Repeat/JIP: request tokens are consumed once; authored waypoint and Zeus control receipts
 * fence delayed work before mutation. The server-clock request deadline also prevents an
 * acknowledged timeout from later starting work. No stale order is replayed for JIP.
 * Failed task rollback restores only the unchanged temporary control token, owner epoch,
 * serial, task generations and native route. Capability-only refusal can restore unchanged
 * prior flags; a newer accepted task blocks rollback even without another module request.
 * Arguments: 0: token <STRING>; 1: task parameters <ARRAY> of named pairs.
 * Return Value: Nothing; reports actual owner acceptance.
 * Current callers: WAIT_fnc_CortexOrderDispatch.
 * Example: [_token, _pairs] remoteExecCall ["WAIT_fnc_CortexOrderLocal", groupOwner _group];
 */
params ["_token", "_pairs"];
if (remoteExecutedOwner != 2) exitWith {};
private _settings = createHashMapFromArray _pairs;
private _group = _settings getOrDefault ["group", grpNull];
if (isNull _group || {!local _group} || {(units _group) findIf {isPlayer _x} >= 0}) exitWith {
    [_token, false, false, clientOwner, "The squad changed owner or now contains a player."] remoteExecCall ["WAIT_fnc_CortexOrderResult", 2];
};
private _serial = _settings getOrDefault ["requestSerial",-1];
private _deadline = _settings getOrDefault ["requestDeadline",-1];
private _receipt = _settings getOrDefault ["nativeReceipt",[]];
private _controlReceipt = _settings getOrDefault ["controlReceipt",[]];
private _currentControl = [
    _group getVariable ["WAIT_AIPass_ZeusHold",[]],
    _group getVariable ["WAIT_AIPass_ZeusWaypoints",false],
    _group getVariable ["WAIT_AIPass_ZeusControlKind",""]
];
if (!(_deadline isEqualType 0) || {!finite _deadline} || {serverTime >= _deadline}
    || {!(_serial isEqualType 0)} || {_token != str _serial}
    || {_serial <= (_group getVariable ["WAIT_Cortex_LastTaskSerial",-1])}
    || {_receipt isNotEqualTo ([_group] call WAIT_fnc_NativeOrderReceipt)}
    || {_controlReceipt isNotEqualTo _currentControl}) exitWith {
    [_token,false,false,clientOwner,"The task expired, is stale, or newer native/Zeus control replaced it."] remoteExecCall ["WAIT_fnc_CortexOrderResult",2];
};
_group setVariable ["WAIT_Cortex_LastTaskSerial",_serial,true];
private _order = _settings getOrDefault ["order", ""];
private _position = _settings getOrDefault ["position", []];
private _radius = _settings getOrDefault ["radius", 50];
private _width = _settings getOrDefault ["width",_radius];
private _building = _settings getOrDefault ["building", objNull];
private _facing = _settings getOrDefault ["facing", 0];
private _sortByHeight = _settings getOrDefault ["sortByHeight",true];
private _teleport = _settings getOrDefault ["teleport",false];
if (!(_sortByHeight isEqualType true) || {!(_teleport isEqualType true)} || {!(_width isEqualType 0)} || {!(_facing isEqualType 0)}) exitWith {[_token,false,false,clientOwner,"Invalid task parameters."] remoteExecCall ["WAIT_fnc_CortexOrderResult",2]};
private _reason = [_group,_order,_building] call WAIT_fnc_CortexOrderReason;
if (_reason != "") exitWith {[_token,false,false,clientOwner,_reason] remoteExecCall ["WAIT_fnc_CortexOrderResult",2]};
private _oldHold = _group getVariable ["WAIT_AIPass_ZeusHold",[]];
private _oldWaypoints = _group getVariable ["WAIT_AIPass_ZeusWaypoints",false];
private _oldControlKind = _group getVariable ["WAIT_AIPass_ZeusControlKind",""];
private _executionEpoch=_group getVariable ["WAIT_AIPass_Epoch",0];
private _executionTaskKeys=["WAIT_AIPass_ClearGeneration","WAIT_AIPass_GarrisonGeneration",
    "WAIT_AIPass_DefendGeneration","WAIT_OperationGeneration"];
private _executionTasks=_executionTaskKeys apply {_group getVariable [_x,-1]};
private _temporaryControl=[];
if (_order in ["GARRISON", "DEFEND", "CLEAR", "AIRBORNE"]) then {
    _group setVariable ["WAIT_AIPass_ZeusControlKind",nil,true];
    _group setVariable ["WAIT_AIPass_ZeusWaypoints", false, true];
    _group setVariable ["WAIT_AIPass_ZeusHold", [random 1e6, 0], true];
    _temporaryControl=[_group getVariable ["WAIT_AIPass_ZeusHold",[]],false,""];
};

private _previousClearFailure=_group getVariable ["WAIT_Cortex_ClearAdmissionFailure",[]];
private _previousGarrisonFailure=_group getVariable ["WAIT_Cortex_GarrisonAdmissionFailure",[]];
    private _accepted = switch (_order) do {
        case "GARRISON": {[_group, _position, (_radius max 15) min 150, createHashMapFromArray [["teleport",_teleport],["sortByHeight",_sortByHeight]]] call WAIT_fnc_CortexGarrison};
        case "DEFEND": {[_group, _position, _facing, (_width max 15) min 150] call WAIT_fnc_CortexDefend};
        case "RELEASE": {
            private _released = [_group] call WAIT_fnc_CortexClearRelease;
            // Release automatic actor jobs too; no group-wide reset is needed to retire them.
            // Inspect every current member so reordered membership cannot hide an admitted actor.
            {
                private _indoor=_x getVariable ["WAIT_IndoorActor_Brain",createHashMap];
                if (count _indoor > 0 || {(_x getVariable ["WAIT_IndoorActor_Order",[]]) isNotEqualTo []}) then {
                    private _retired=["FINISH",_x,_indoor] call WAIT_fnc_IndoorActorOperation;
                    _released=_released || {_retired};
                };
            } forEach units _group;
            if ((_group getVariable ["WAIT_AIPass_Garrison", []]) isNotEqualTo []) then {_released = [_group] call WAIT_fnc_CortexGarrisonRelease};
            if ((_group getVariable ["WAIT_AIPass_Defend", []]) isNotEqualTo []) then {_released = [_group] call WAIT_fnc_CortexDefendRelease};
            _released
        };
        case "EXCLUDE": {
            if (isNull _group) exitWith {false};
            [_group] call WAIT_fnc_CortexClearRelease;
            [_group] call WAIT_fnc_CortexGarrisonRelease;
            [_group] call WAIT_fnc_CortexDefendRelease;
            [_group] call WAIT_fnc_CortexReleaseGroup;
            _group setVariable ["WAIT_AIPass_Exclude", true, true];
            true
        };
        case "RETURN": {
            if (isNull _group) exitWith {false};
            _group setVariable ["WAIT_AIPass_Exclude", nil, true];
            _group setVariable ["WAIT_AIPass_ZeusControlKind",nil,true];
            _group setVariable ["WAIT_AIPass_ZeusWaypoints", false, true];
            // A zero-length token cancels any remaining Zeus hold on every machine.
            _group setVariable ["WAIT_AIPass_ZeusHold", [random 1e6, 0], true];
            true
        };
        case "CLEAR": {[_group, _building] call WAIT_fnc_CortexClearBuilding};
        case "AIRBORNE": {[_group] call WAIT_fnc_CortexAirborneDrop};
        default {false};
    };

private _garrisonFailure=_group getVariable ["WAIT_Cortex_GarrisonAdmissionFailure",[]];
private _newGarrisonFailure=_order == "GARRISON" && {count _garrisonFailure == 3}
    && {_garrisonFailure isNotEqualTo _previousGarrisonFailure} && {(_garrisonFailure select 2) == _serial};
private _liveControl=[_group getVariable ["WAIT_AIPass_ZeusHold",[]],
    _group getVariable ["WAIT_AIPass_ZeusWaypoints",false],_group getVariable ["WAIT_AIPass_ZeusControlKind",""]];
// Rollback owns only this exact temporary override. A newer order/owner/control token survives.
if (!_accepted && {_temporaryControl isNotEqualTo []}
    && {(_executionTaskKeys apply {_group getVariable [_x,-1]}) isEqualTo _executionTasks}
    && {local _group} && {(_group getVariable ["WAIT_AIPass_Epoch",0]) == _executionEpoch}
    && {(_group getVariable ["WAIT_Cortex_LastTaskSerial",-1]) == _serial}
    && {_liveControl isEqualTo _temporaryControl}
    && {([_group] call WAIT_fnc_NativeOrderReceipt) isEqualTo _receipt}) then {
    _group setVariable ["WAIT_AIPass_ZeusControlKind",_oldControlKind,true];
    _group setVariable ["WAIT_AIPass_ZeusHold",_oldHold,true];
    _group setVariable ["WAIT_AIPass_ZeusWaypoints",_oldWaypoints,true];
};
private _executionReason="No valid positions or eligible passengers were available. The order was not started.";
if (!_accepted && {_newGarrisonFailure}) then {
    _executionReason=switch (_garrisonFailure select 1) do {
        case "PLAN_CONTEXT_CHANGED": {"The squad's orders, owner or actors changed during planning. Garrison was not started and no earlier task was replaced."};
        case "NO_VALID_POSITIONS": {"No valid garrison positions were found in the selected area. No earlier task was replaced."};
        default {"Garrison planning was invalid or exceeded its bounded planning budget. No earlier task was replaced."};
    };
};
if (!_accepted && {_order == "CLEAR"}) then {
    private _failure=_group getVariable ["WAIT_Cortex_ClearAdmissionFailure",[]];
    _executionReason="Clearance was refused by the current owner; inspect the selected squad and building.";
    if (count _failure >= 2 && {_failure isNotEqualTo _previousClearFailure}) then {
        _executionReason=switch (_failure select 1) do {
            case "TARGET_ABSENT": {"The selected building no longer exists."};
            case "TARGET_DESTROYED": {"The selected building is destroyed."};
            case "POSITION_BUDGET_EXCEEDED": {"The building reports too many positions for this bounded clearance task."};
            case "NO_VALID_ROOFED_POSITIONS": {"The building has no valid roofed internal positions to attempt."};
            case "NO_ELIGIBLE_ACTORS": {"No task-free, capable infantry are available to enter the building."};
            case "INVALID_TARGET_POSITION": {"The clearance target coordinates are invalid."};
            default {format ["Clearance refused: %1. No clearance was started.",_failure select 1]};
        };
    };
};
[_token, _accepted, false, clientOwner, if (_accepted) then {""} else {_executionReason}] remoteExecCall ["WAIT_fnc_CortexOrderResult", 2];

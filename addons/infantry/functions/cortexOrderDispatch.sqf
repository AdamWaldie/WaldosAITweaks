/*
 * Author: WaldoTheWarfighter
 * Routes named behaviour task parameters to the group owner and keeps a bounded pending result until acknowledgement or timeout.
 * Locality/authority: server scripts are trusted; remote requests must come from an assigned
 * curator. The server derives the reply owner from the network sender; the group owner executes.
 * Repeat/JIP: request tokens are consumed once; no stale order is replayed for JIP.
 * Arguments: 0: task parameters <ARRAY> of named pairs; 1: requesting owner <NUMBER>, default 2.
 * Return Value: Boolean, dispatch accepted.
 * Current callers: mission scripts, ModuleGarrison, ZenGarrisonModule and ZenDefendModule.
 * No JIP command replay. Pending owner acknowledgements are limited to 64 for at most 12 seconds.
 * The server overwrites the admission deadline; owners refuse packets received at/after expiry.
 * Example: [[["order", "RELEASE"], ["group", _group]], 2] call WAIT_fnc_CortexOrderDispatch;
 */
params [["_pairs", [], [[]]], ["_requestOwner", 2, [0]]];
if (!isServer) exitWith {[_pairs,clientOwner] remoteExecCall ["WAIT_fnc_CortexOrderDispatch",2]; true};
private _sender = remoteExecutedOwner;
if (isRemoteExecuted && {_sender <= 0}) exitWith {false};
if (_sender > 0) then {_requestOwner = _sender};
if (_sender > 2 && {allPlayers findIf {owner _x == _sender && {!isNull getAssignedCuratorLogic _x}} < 0}) exitWith {false};
if (count _pairs > 16) exitWith {false};
if (_pairs findIf {!(_x isEqualType []) || {count _x != 2} || {!((_x select 0) isEqualType "")}} >= 0) exitWith {false};
private _settings = createHashMapFromArray _pairs;
private _group = _settings getOrDefault ["group", grpNull];
private _order = _settings getOrDefault ["order", ""];
if (!(_group isEqualType grpNull) || {!(_order isEqualType "")}) exitWith {false};
private _radius = _settings getOrDefault ["radius", 50];
private _facing = _settings getOrDefault ["facing", 0];
private _width = _settings getOrDefault ["width",_radius];
private _building = _settings getOrDefault ["building", objNull];
private _unit = _settings getOrDefault ["unit", objNull];
if (!(_radius isEqualType 0) || {!(_facing isEqualType 0)} || {!(_width isEqualType 0)} || {!finite _radius} || {!finite _facing} || {!finite _width} || {!(_building isEqualType objNull)} || {!(_unit isEqualType objNull)}) exitWith {false};
private _sortByHeight = _settings getOrDefault ["sortByHeight",true];
if !(_sortByHeight isEqualType true) exitWith {false};
private _teleport = _settings getOrDefault ["teleport",false];
if !(_teleport isEqualType true) exitWith {false};
// Remote module requests cannot change addon configuration or artillery role registration.
if (_sender > 2 && {!(_order in ["GARRISON","DEFEND","CLEAR","RELEASE","AIRBORNE"])}) exitWith {false};
private _pending = missionNamespace getVariable ["WAIT_AIPass_OrderPending", createHashMap];
if (count _pending >= 64) exitWith {
    ["AI ORDERS","Too many pending squad orders. Wait for owner replies before retrying.","ERROR"] remoteExecCall ["WAIT_fnc_AITweaksNotifyLocal",_requestOwner];
    false
};
private _serial = (missionNamespace getVariable ["WAIT_AIPass_OrderSerial", 0]) + 1;
missionNamespace setVariable ["WAIT_AIPass_OrderSerial", _serial];
private _token = str _serial;
_pending set [_token, [_requestOwner, _group, groupOwner _group, _order]];
missionNamespace setVariable ["WAIT_AIPass_OrderPending", _pending];
private _valid = !isNull _group && {(units _group) findIf {isPlayer _x} < 0}
    && {_order in ["GARRISON", "DEFEND", "RELEASE", "CLEAR", "AIRBORNE", "ARTY_SUPPORT", "ARTY_COUNTER", "ARTY_BOTH", "EXCLUDE", "RETURN", "SPOTTER_ON", "SPOTTER_OFF"]};
if (_order in ["GARRISON", "DEFEND"]) then {
    private _pos = _settings getOrDefault ["position", []];
    _valid = _valid && {_pos isEqualType []} && {count _pos == 3} && {_pos findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} < 0};
};
if (_order == "CLEAR") then {_valid = _valid && {!isNull (_settings getOrDefault ["building", objNull])}};
if (!_valid) exitWith {
    _pending deleteAt _token;
    ["AI ORDERS","Invalid squad or task target. No order was started.","ERROR"] remoteExecCall ["WAIT_fnc_AITweaksNotifyLocal",_requestOwner];
    false
};
if (_order in ["ARTY_SUPPORT", "ARTY_COUNTER", "ARTY_BOTH"]) exitWith {
    private _accepted = [_group, _order select [5]] call WAIT_fnc_CortexSetArtilleryRole;
    [_token, _accepted] call WAIT_fnc_CortexOrderResult;
    _accepted
};
if (_order in ["SPOTTER_ON", "SPOTTER_OFF"]) exitWith {
    private _unit = _settings getOrDefault ["unit", objNull];
    private _accepted = !isNull _unit && {group _unit == _group} && {[_unit, _order == "SPOTTER_ON"] call WAIT_fnc_CortexSetSpotter};
    [_token, _accepted] call WAIT_fnc_CortexOrderResult;
    _accepted
};
// Serialize the validated named map, so clients cannot forge execution metadata.
_settings set ["requestSerial",_serial];
_settings set ["requestDeadline",serverTime+12];
_settings set ["nativeReceipt",[_group] call WAIT_fnc_NativeOrderReceipt];
_settings set ["controlReceipt",[
    _group getVariable ["WAIT_AIPass_ZeusHold",[]],
    _group getVariable ["WAIT_AIPass_ZeusWaypoints",false],
    _group getVariable ["WAIT_AIPass_ZeusControlKind",""]
]];
_settings set ["radius",(_radius max 15) min 150];
_settings set ["width",(_width max 15) min 150];
_settings set ["facing",((_facing mod 360)+360) mod 360];
_pairs = (keys _settings) apply {[_x,_settings get _x]};
[_token, _pairs] remoteExecCall ["WAIT_fnc_CortexOrderLocal", groupOwner _group];
[{
    params ["_token"];
    if (_token in (missionNamespace getVariable ["WAIT_AIPass_OrderPending", createHashMap])) then {
        [_token, false, true] call WAIT_fnc_CortexOrderResult;
    };
}, [_token], 12] call CBA_fnc_waitAndExecute;
true

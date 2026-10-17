/*
 * Author: WaldoTheWarfighter
 * Purpose: Authenticates and applies a named create/update/remove navigation corridor task.
 * Locality / Authority: Server creates only WAIT_DrivingCorridorArea; remote requests derive
 * identity from the sender and require an assigned curator. Edits require the explicit editable
 * area and unchanged transform. No vehicle movement or addon setting is written here.
 * Repeat/JIP: Per-curator sequence receipts coalesce duplicate delivery; requests expire after
 * at most 12 seconds. At most 64 live curator receipts and 32 registered areas are retained.
 * JIP receives passive area definitions, never historical creation or movement RPCs.
 * Arguments: 0 named pairs <ARRAY, []>: mode CREATE/UPDATE/REMOVE, area OBJECT, position ATL
 * ARRAY, facing NUMBER, halfLength NUMBER (5..45), halfWidth NUMBER (2..20), speed NUMBER
 * (5..30 km/h), transform ARRAY (for edits), serial positive integer, expires serverTime NUMBER.
 * Return Value: BOOL - server registration or request submission, never physical passage.
 * Current callers: ModuleDrivingCorridor and ZenDrivingCorridorModule.
 * Example: [[["mode","CREATE"],["position",getMarkerPos "bridge"],["facing",90],
 * ["halfLength",25],["halfWidth",5],["speed",15]]] call WAIT_fnc_DrivingCorridorDispatch;
 */
params [["_pairs",[],[[]]]];
if (!isServer) exitWith {[_pairs] remoteExecCall ["WAIT_fnc_DrivingCorridorDispatch",2];true};
private _sender=remoteExecutedOwner;
if (isRemoteExecuted && {_sender <= 0}) exitWith {false};
private _replyOwner=[2,_sender] select (_sender > 0);
private _curator=objNull;
if (_replyOwner >= 2) then {
    private _actor=allPlayers findIf {owner _x == _replyOwner && {!isNull getAssignedCuratorLogic _x}};
    if (_actor >= 0) then {_curator=getAssignedCuratorLogic (allPlayers select _actor)};
};
if (_sender > 2 && {isNull _curator}) exitWith {false};
private _reply={
    params ["_accepted","_message"];
    ["NAVIGATION CORRIDOR",_message,["ERROR","INFO"] select _accepted]
        remoteExecCall ["WAIT_fnc_AITweaksNotifyLocal",_replyOwner];
    _accepted
};
if (count _pairs > 10 || {_pairs findIf {
    !(_x isEqualType []) || {count _x != 2} || {!((_x select 0) isEqualType "")}
} >= 0}) exitWith {[false,"Invalid task payload."] call _reply};
private _keys=_pairs apply {_x select 0};
if (count (_keys arrayIntersect _keys) != count _keys || {_keys findIf {
    !(_x in ["mode","area","position","facing","halfLength","halfWidth","speed","transform","serial","expires"])
} >= 0}) exitWith {[false,"Invalid or duplicate task parameter."] call _reply};
private _task=createHashMapFromArray _pairs;
private _mode=_task getOrDefault ["mode",""];
private _area=_task getOrDefault ["area",objNull];
private _position=_task getOrDefault ["position",[]];
private _facing=_task getOrDefault ["facing",0];
private _halfLength=_task getOrDefault ["halfLength",25];
private _halfWidth=_task getOrDefault ["halfWidth",5];
private _speed=_task getOrDefault ["speed",15];
private _transform=_task getOrDefault ["transform",[]];
private _expires=_task getOrDefault ["expires",serverTime+10];
private _receipts=missionNamespace getVariable ["WAIT_DrivingCorridor_Requests",createHashMap];
private _key=str _replyOwner;
private _previous=_receipts getOrDefault [_key,[0,[]]];
private _serial=_task getOrDefault ["serial",if (_sender > 2) then {-1} else {(_previous select 0)+1}];
if (!(_mode isEqualType "") || {!(_mode in ["CREATE","UPDATE","REMOVE"])}
    || {!(_area isEqualType objNull)} || {!(_position isEqualType [])} || {!(_transform isEqualType [])}
    || {[_facing,_halfLength,_halfWidth,_speed,_serial,_expires] findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {_serial < 1} || {_serial != floor _serial}) exitWith {[false,"Invalid corridor task values."] call _reply};
// Hosted-server scripts and local Zeus dialogs share owner 2; keep their next serial aligned.
if (_sender <= 0) then {
    missionNamespace setVariable ["WAIT_DrivingCorridor_LocalSerial",
        (missionNamespace getVariable ["WAIT_DrivingCorridor_LocalSerial",0]) max _serial];
};
if (_serial == (_previous select 0) && {(_previous select 1) isNotEqualTo []}) exitWith {
    (_previous select 1) call _reply
};
if (_serial < (_previous select 0)) exitWith {[false,"A newer corridor request already exists."] call _reply};
if ((_sender > 2 && {isNil {_task get "expires"}}) || {_expires <= serverTime}
    || {_expires > serverTime+12}) exitWith {[false,"Corridor request expired; place the task again."] call _reply};
if (_facing < 0 || {_facing > 360} || {_halfLength < 5} || {_halfLength > 45}
    || {_halfWidth < 2} || {_halfWidth > 20} || {_speed < 5} || {_speed > 30}) exitWith {
    [false,"Corridor dimensions, direction or speed are outside the task limits."] call _reply
};
if (_mode == "CREATE" && {!isNull _area || {count _position != 3}
    || {_position findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} >= 0}}) exitWith {
    [false,"Select an explicit valid area position for a new corridor."] call _reply
};
if (_mode != "CREATE" && {isNull _area || {!(_area isKindOf "WAIT_DrivingCorridorArea")}
    || {_sender > 2 && {owner _area != _sender && {!(_area in curatorEditableObjects _curator)}}}
    || {[getPosWorld _area,vectorDir _area,vectorUp _area] isNotEqualTo _transform}}) exitWith {
    [false,"The selected corridor was removed, moved or is not editable. Reopen its task dialog."] call _reply
};
// Retain only current curator owners; a disconnected owner's sequence must not consume capacity forever.
private _owners=(allPlayers select {!isNull getAssignedCuratorLogic _x}) apply {str owner _x};
{if (_x != "2" && {!(_x in _owners)}) then {_receipts deleteAt _x}} forEach keys _receipts;
if (isNil {_receipts get _key} && {count _receipts >= 64}) exitWith {[false,"Curator request budget reached."] call _reply};
private _registered=(missionNamespace getVariable ["WAIT_DrivingCorridor_Snapshot",[0,[]]]) select 1;
if (_mode == "CREATE" && {count (_registered select {!isNull (_x select 0)}) >= 32}) exitWith {
    [false,"Corridor area budget reached; remove an unused area first."] call _reply
};
private _created=false;
private _areaGroup=grpNull;
if (_mode == "CREATE") then {
    _areaGroup=createGroup [sideLogic,true];
    if (!isNull _areaGroup) then {_area=_areaGroup createUnit ["WAIT_DrivingCorridorArea",_position,[],0,"NONE"]};
    _created=!isNull _area;
    if (_created) then {_area setPosATL _position;_area setDir _facing};
};
if (isNull _area) exitWith {
    if (!isNull _areaGroup) then {deleteGroup _areaGroup};
    [false,"Corridor area creation failed."] call _reply
};
private _dimensions=if (_mode == "REMOVE") then {[]} else {[_halfLength,_halfWidth,_speed]};
// Direct remote registration enforces the same explicit curator target. Make a new area's
// editable ownership visible before registration; no temporary vehicle or physics is created.
if (_created && {!isNull _curator}) then {
    _curator addCuratorEditableObjects [[_area],false];
    if (_replyOwner > 2) then {(group _area) setGroupOwner _replyOwner};
};
private _result=[_area,_dimensions] call WAIT_fnc_DrivingCorridorRegister;
if (_result select 0) then {
    if (_mode == "UPDATE") then {_area setDir _facing};
    if (_mode == "REMOVE") then {
        private _oldGroup=group _area;
        deleteVehicle _area;
        if (!isNull _oldGroup && {local _oldGroup} && {units _oldGroup isEqualTo []}) then {deleteGroup _oldGroup};
    };
} else {
    if (_created) then {
        deleteVehicle _area;
        if (!isNull _areaGroup && {local _areaGroup} && {units _areaGroup isEqualTo []}) then {deleteGroup _areaGroup};
    };
};
diag_log format ["WAIT corridor task: owner=%1 serial=%2 mode=%3 area=%4 class=%5 dimensions=%6 facing=%7 result=%8",
    _replyOwner,_serial,_mode,netId _area,typeOf _area,_dimensions,_facing,_result];
private _answer=[_result select 0,format ["%1: %2. Registration is not physical passage.",_mode,_result select 1]];
_receipts set [_key,[_serial,_answer]];
missionNamespace setVariable ["WAIT_DrivingCorridor_Requests",_receipts];
_answer call _reply

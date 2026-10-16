/*
 * Author: WaldoTheWarfighter
 * Purpose: Registers or removes a finite navigation-area definition without issuing movement.
 * Locality / Authority: Server mutation only. Remote callers must be assigned curators editing their
 * explicit editable WAIT corridor area; trusted local/server scripts may register another Logic.
 * Repeat/JIP: Identical definitions retain their revision. Changed definitions invalidate old
 * work. One public ordered snapshot replays passive definitions to JIP; no commands replay.
 * Arguments:
 * 0 area <OBJECT, objNull> - existing Logic defining centre, facing and elevation.
 * 1 dimensions <ARRAY, [25,5,15]> - half-length metres (5..45), half-width metres
 *   (2..20), task speed km/h (5..30). An empty array removes this area's definition.
 * Return Value: ARRAY [accepted BOOL, reason STRING, revision NUMBER]. Maximum 32 areas.
 * Current callers: DrivingCorridorDispatch and trusted server scripts.
 * Example: [corridorLogic,[25,5,15]] call WAIT_fnc_DrivingCorridorRegister;
 */
params [["_area",objNull,[objNull]],["_dimensions",[25,5,15],[[]]]];
if (!isServer) exitWith {[false,"SERVER_ONLY",-1]};
private _sender=remoteExecutedOwner;
if (isRemoteExecuted && {_sender <= 0}) exitWith {[false,"INVALID_SENDER",-1]};
if (_sender > 2) then {
    private _curatorPlayer=allPlayers findIf {owner _x == _sender && {!isNull getAssignedCuratorLogic _x}};
    private _curator=if (_curatorPlayer < 0) then {objNull} else {getAssignedCuratorLogic (allPlayers select _curatorPlayer)};
    if (isNull _curator || {isNull _area} || {!(_area isKindOf "WAIT_DrivingCorridorArea")}
        || {owner _area != _sender && {!(_area in curatorEditableObjects _curator)}}) exitWith {
        _sender=-1;
    };
};
if (_sender == -1) exitWith {[false,"CURATOR_AUTHORITY",-1]};
if (isNull _area || {!(_area isKindOf "Logic")}) exitWith {[false,"AREA_REQUIRED",-1]};
if (_dimensions isNotEqualTo [] && {count _dimensions != 3 || {
    _dimensions findIf {!(_x isEqualType 0) || {!finite _x}} >= 0
}}) exitWith {[false,"INVALID_DIMENSIONS",-1]};
if (_dimensions isNotEqualTo [] && {
    (_dimensions select 0) < 5 || {(_dimensions select 0) > 45}
    || {(_dimensions select 1) < 2} || {(_dimensions select 1) > 20}
    || {(_dimensions select 2) < 5} || {(_dimensions select 2) > 30}
}) exitWith {[false,"OUT_OF_RANGE",-1]};
private _snapshot=missionNamespace getVariable ["WAIT_DrivingCorridor_Snapshot",[0,[]]];
private _records=(_snapshot select 1) select {!isNull (_x select 0)};
private _index=_records findIf {(_x select 0) isEqualTo _area};
private _old=if (_index >= 0) then {(_records select _index) select 1} else {[]};
if (_dimensions isNotEqualTo [] && {_old isNotEqualTo []}
    && {(_old select [1,3]) isEqualTo _dimensions}
    && {(_area getVariable ["WAIT_DrivingCorridor_Task",[]]) isEqualTo _old}) exitWith {
    [true,"UNCHANGED",_old select 0]
};
if (_dimensions isNotEqualTo [] && {_index < 0} && {count _records >= 32}) exitWith {[false,"AREA_BUDGET",-1]};
private _revision=(_snapshot select 0)+1;
if (_index >= 0) then {_records deleteAt _index};
// Publish invalidation/readiness before the atomic registry snapshot. Consumers must match both.
if (_dimensions isEqualTo []) then {
    _area setVariable ["WAIT_DrivingCorridor_Task",nil,true];
} else {
    private _definition=[_revision]+_dimensions;
    _area setVariable ["WAIT_DrivingCorridor_Task",_definition,true];
    _records pushBack [_area,_definition];
};
missionNamespace setVariable ["WAIT_DrivingCorridor_Snapshot",[_revision,_records],true];
[true,["REGISTERED","REMOVED"] select (_dimensions isEqualTo []),_revision]

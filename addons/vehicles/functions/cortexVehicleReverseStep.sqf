/*
 * Author: WaldoTheWarfighter
 * Purpose: Own one finite tracked reverse leg while preserving a threat-facing hull and native turret engagement.
 * Locality/authority: Current AI group and vehicle owner only; all command boundaries yield to external ownership.
 * Repeat/JIP: Generation/epoch-bound record; repeated steps retain commands. No worker or JIP command replay.
 * Arguments: 0 group <GROUP>; 1 state <HASHMAP>; 2 vehicle <OBJECT>; 3 threat ATL <ARRAY>;
 * 4 mode <STRING, START>; 5 operation generation <NUMBER, -1>.
 * Return: STRING - REVERSE, COMPLETE, FALLBACK or RELEASED. Caller owns forward fallback and operation release.
 * Current callers: CortexVehicles, CortexGroupTick, OperationCancel and OperationRelease.
 * Example: [group driver apc1,state,apc1,getPosATL enemy1,"START",4] call WAIT_fnc_CortexVehicleReverseStep;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],
    ["_vehicle",objNull,[objNull]],["_threat",[],[[]]],["_mode","START",[""]],["_generation",-1,[0]]];
if (isNull _group || {!local _group}) exitWith {"FALLBACK"};
private _record=_group getVariable ["WAIT_VehicleReverse",[]];
private _release={
    if (count _record == 9 && {(_record select 1) == _generation}) then {
        private _ownedVehicle=_record select 0;
        if (!isNull _ownedVehicle && {local _ownedVehicle}
            && {(_ownedVehicle getVariable ["WAIT_VehicleReverseOwner",[]]) isEqualTo [_group,_generation]}) then {
            private _info=vehicleMoveInfo _ownedVehicle;
            if ((_info param [1,""]) in ["LEFT","RIGHT"]) then {_ownedVehicle sendSimpleCommand "STOPTURNING"};
            if ((_info param [0,""]) == "BACK") then {_ownedVehicle sendSimpleCommand "STOP"};
            _ownedVehicle setVariable ["WAIT_VehicleReverseOwner",nil,true];
        };
        _group setVariable ["WAIT_VehicleReverse",nil,true];
    };
    "RELEASED"
};
if (toUpperANSI _mode == "RELEASE") exitWith {call _release};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
private _eligible=(missionNamespace getVariable ["WAIT_AIPass_Active",false])
    && {[_group,"WAIT_AIPass_VehicleWithdraw_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {count _operation > 0} && {(_operation getOrDefault ["generation",-2]) == _generation}
    && {(_operation getOrDefault ["intent",""]) == "VEHICLE_WITHDRAW"}
    && {(_operation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
    && {!isNull _vehicle} && {local _vehicle} && {alive _vehicle} && {canMove _vehicle}
    && {_vehicle isKindOf "Tank"} && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])};
if (!_eligible) exitWith {call _release; "FALLBACK"};
private _driver=driver _vehicle;
private _commander=effectiveCommander _vehicle;
if (isNull _driver || {isNull _commander} || {_driver == _commander}
    || {!alive _driver} || {!alive _commander} || {!local _driver} || {!local _commander}
    || {isPlayer _driver} || {isPlayer _commander} || {group _driver != _group}
    || {group _commander != _group} || {!isNull remoteControlled _driver}
    || {!isNull remoteControlled _commander}) exitWith {call _release; "FALLBACK"};
if (toUpperANSI _mode == "START") exitWith {
    if (count _record == 9) exitWith {
        if ((_record select 1) == _generation && {(_record select 0) == _vehicle}) then {"REVERSE"} else {"FALLBACK"}
    };
    if (count _threat < 2 || {abs speed _vehicle > 10}) exitWith {"FALLBACK"};
    private _relative=_vehicle getRelDir _threat;
    if (_relative > 30 && {_relative < 330}) exitWith {"FALLBACK"};
    private _origin=getPosATL _vehicle;
    private _rear=_vehicle getRelPos [35,180];
    if (_rear distance2D _threat <= _origin distance2D _threat) exitWith {"FALLBACK"};
    private _route=[_origin,[[_rear]],_threat,[],objNull,"VEHICLE"] call WAIT_fnc_CortexSelectAvenue;
    if (_route isEqualTo [] || {lineIntersectsSurfaces [AGLToASL (_origin vectorAdd [0,0,1]),
        AGLToASL (_rear vectorAdd [0,0,1]),_vehicle,objNull,true,1,"GEOM","NONE"] isNotEqualTo []}) exitWith {"FALLBACK"};
    _record=[_vehicle,_generation,_group getVariable ["WAIT_AIPass_Epoch",0],+_origin,+_threat,
        time+20,time,+_origin,"BACK"];
    _group setVariable ["WAIT_VehicleReverse",_record,true];
    _vehicle setVariable ["WAIT_VehicleReverseOwner",[_group,_generation],true];
    _vehicle sendSimpleCommand "STOPTURNING";
    _vehicle sendSimpleCommand "BACK";
    "REVERSE"
};
if (count _record != 9 || {(_record select 0) != _vehicle} || {(_record select 1) != _generation}
    || {(_record select 2) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {"FALLBACK"};
if (_vehicle distance2D (_record select 3) >= 30) exitWith {call _release; "COMPLETE"};
if (_vehicle distance2D (_record select 7) >= 2) then {_record set [6,time]; _record set [7,getPosATL _vehicle]};
if (time >= (_record select 5) || {time-(_record select 6) > 6}) exitWith {call _release; "FALLBACK"};
private _bearing=_vehicle getRelDir (_record select 4);
private _turn=if (_bearing <= 20 || {_bearing >= 340}) then {"STOPTURNING"} else {["LEFT","RIGHT"] select (_bearing < 180)};
if (_turn != (_record select 8)) then {_vehicle sendSimpleCommand _turn; _record set [8,_turn]};
_group setVariable ["WAIT_VehicleReverse",_record,true];
"REVERSE"

/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes native driver path segments and derives a fresh nearby forward bend hint.
 * Locality / Authority: Current vehicle/group owner; no movement, speed, path calculation or
 * clearance commands. One local PathCalculated handler on the actual driver, never a helper agent.
 * Repeat/JIP: Exact route/controller/seat/owner context replaces obsolete handlers. Local handles
 * and paths are never published. New owners wait for fresh native evidence, not replayed paths.
 * A six-second local subscription expiry is refreshed only by the existing owner callback;
 * abandoned/disabled/player-controlled watches cannot keep copying native events indefinitely.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 group <GROUP, grpNull>; 2 context <ARRAY, []>,
 * first element ORDINARY or CONVOY, second convoy revision where applicable; 3 release <BOOL, false>;
 * 4 expected convoy revision <NUMBER, -1> protects stale cleanup when >=0.
 * Return Value: ARRAY [] without usable evidence, otherwise [curvature NUMBER, allowStopped BOOL].
 * Bounds: native events retain at most 64 ASL nodes; owner callbacks inspect at most 63 segments.
 * Five-second evidence age, exact both-seat destinations, current proximity/floor and forward
 * lookahead 3..12 m protect use. Multiple disconnected nearby path stretches refuse a hint;
 * equal-distance ties within one stretch retain the first segment rather than jumping ahead.
 * A captured path grants neither movement nor physical completion.
 * Current callers: DrivingAssistStart, ConvoyTick, DrivingAssistRelease and ConvoyReleaseLocal.
 * Example: private _hint=[truck1,_group,["ORDINARY",_route,_epoch]] call WAIT_fnc_DrivingNativePathWatch;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],["_context",[],[[]]],
    ["_release",false,[true]],["_expectedRevision",-1,[0]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _vehicle} || {!local _vehicle}) exitWith {[]};
private _record=_vehicle getVariable ["WAIT_DrivingNativePath_Watch",[]];
private _remove={
    if (count _record == 4) then {
        _record params ["_oldGroup","_identity","_actor","_id"];
        private _binding=[_vehicle,_oldGroup,_identity,_id];
        if (!isNull _actor && {(_actor getVariable ["WAIT_DrivingNativePath_Binding",[]]) isEqualTo _binding}) then {
            _actor removeEventHandler ["PathCalculated",_id];
            _actor setVariable ["WAIT_DrivingNativePath_Binding",nil];
        };
        if ((_vehicle getVariable ["WAIT_DrivingNativePath_Watch",[]]) isEqualTo _record) then {
            _vehicle setVariable ["WAIT_DrivingNativePath_Watch",nil];
            _vehicle setVariable ["WAIT_DrivingNativePath_Segment",nil];
            _vehicle setVariable ["WAIT_DrivingNativePath_ValidUntil",nil];
        };
    };
};
if (_release) exitWith {
    if (count _record == 4 && {isNull _group || {(_record select 0) == _group}}
        && {(((_record select 1) select 0) param [0,""]) == (_context param [0,""])}
        && {_expectedRevision < 0 || {(((_record select 1) select 0) param [1,-2]) isEqualTo _expectedRevision}}) then {call _remove};[]
};
private _mode=_context param [0,""];
if (!(_mode in ["ORDINARY","CONVOY"])) exitWith {[]};
private _feature=["WAIT_AIPass_DrivingAssist_Enable","WAIT_Convoy_DrivingAssist_Enable"] select (_mode == "CONVOY");
if (!([_group,_feature,true] call WAIT_fnc_CortexFeatureEnabled)) exitWith {
    if (count _record == 4 && {(_record select 0) == _group}
        && {(((_record select 1) select 0) param [0,""]) == _mode}) then {call _remove};[]
};
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
if (isNull _group || {!local _group} || {isNull _driver} || {!local _driver}
    || {group _driver != _group} || {[_driver,_operator] findIf {
        isNull _x || {!local _x} || {group _x != _group} || {vehicle _x != _vehicle}
            || {isPlayer _x} || {!isNull remoteControlled _x}
            || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {[_x] call WAIT_fnc_CortexExternalOwner != ""}
    } >= 0}) exitWith {[]};
private _identity=[_context,_driver,_operator,clientOwner];
if (count _record != 4 || {(_record select 0) != _group} || {(_record select 1) isNotEqualTo _identity}) then {
    call _remove;
    // A driver can leave a deleted vehicle before its owner callback cleans up. Retire that
    // driver's exact local handler before binding a new vehicle; do not accumulate inert handlers.
    private _oldBinding=_driver getVariable ["WAIT_DrivingNativePath_Binding",[]];
    if (count _oldBinding == 4) then {
        _driver removeEventHandler ["PathCalculated",_oldBinding select 3];
        private _oldVehicle=_oldBinding select 0;
        private _oldWatch=_oldVehicle getVariable ["WAIT_DrivingNativePath_Watch",[]];
        if (count _oldWatch == 4 && {(_oldWatch select 2) == _driver}
            && {(_oldWatch select 3) == (_oldBinding select 3)}) then {
            _oldVehicle setVariable ["WAIT_DrivingNativePath_Watch",nil];
            _oldVehicle setVariable ["WAIT_DrivingNativePath_Segment",nil];
            _oldVehicle setVariable ["WAIT_DrivingNativePath_ValidUntil",nil];
        };
        _driver setVariable ["WAIT_DrivingNativePath_Binding",nil];
    };
    private _id=_driver addEventHandler ["PathCalculated",{
        params ["_unit","_path"];
        private _binding=_unit getVariable ["WAIT_DrivingNativePath_Binding",[]];
        if (count _binding != 4 || {(_binding select 3) != _thisEventHandler}) exitWith {};
        _binding params ["_vehicle","_group","_identity"];
        if (!local _unit || {!local _vehicle} || {!local _group} || {driver _vehicle != _unit}
            || {(_vehicle getVariable ["WAIT_DrivingNativePath_Watch",[]]) isNotEqualTo [_group,_identity,_unit,_thisEventHandler]}) exitWith {};
        private _mode=(_identity select 0) param [0,""];
        private _feature=["WAIT_AIPass_DrivingAssist_Enable","WAIT_Convoy_DrivingAssist_Enable"] select (_mode == "CONVOY");
        if (time > (_vehicle getVariable ["WAIT_DrivingNativePath_ValidUntil",-1])
            || {!([_group,_feature,true] call WAIT_fnc_CortexFeatureEnabled)}
            || {[_unit,effectiveCommander _vehicle] findIf {
                isNull _x || {!local _x} || {group _x != _group} || {vehicle _x != _vehicle}
                    || {isPlayer _x} || {!isNull remoteControlled _x}
                    || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                    || {[_x] call WAIT_fnc_CortexExternalOwner != ""}
            } >= 0}) exitWith {
            _vehicle setVariable ["WAIT_DrivingNativePath_Segment",nil];
        };
        private _nodes=_path select [0,64];
        _vehicle setVariable ["WAIT_DrivingNativePath_Segment",nil];
        if (count _nodes < 2 || {_nodes findIf {!(_x isEqualType []) || {count _x != 3}
            || {_x findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} >= 0}} >= 0}) exitWith {};
        _vehicle setVariable ["WAIT_DrivingNativePath_Segment",[_identity,time,
            +(expectedDestination _unit),+(expectedDestination effectiveCommander _vehicle),_nodes]];
    }];
    _record=[_group,_identity,_driver,_id];
    _vehicle setVariable ["WAIT_DrivingNativePath_Watch",_record];
    _driver setVariable ["WAIT_DrivingNativePath_Binding",[_vehicle,_group,_identity,_id]];
};
_vehicle setVariable ["WAIT_DrivingNativePath_ValidUntil",time+6];
private _segment=_vehicle getVariable ["WAIT_DrivingNativePath_Segment",[]];
if (count _segment != 5 || {(_segment select 0) isNotEqualTo _identity} || {time-(_segment select 1) > 5}
    || {time < (_segment select 1)} || {(expectedDestination _driver) isNotEqualTo (_segment select 2)}
    || {(expectedDestination _operator) isNotEqualTo (_segment select 3)}) exitWith {[]};
private _nodes=_segment select 4;private _origin=getPosASL _vehicle;private _nearIndex=-1;private _nearDistance=3;private _nearRuns=0;private _inNearRun=false;private _target=[];private _best=12;
for "_i" from 0 to (count _nodes-2) do {
    private _a=_nodes select _i;private _b=_nodes select (_i+1);private _line=_b vectorDiff _a;_line set [2,0];
    private _lengthSquared=_line vectorDotProduct _line;
    if (_lengthSquared >= 0.01) then {
        private _fraction=(((_origin vectorDiff _a) vectorDotProduct _line)/_lengthSquared) max 0 min 1;
        private _closest=_a vectorAdd ((_b vectorDiff _a) vectorMultiply _fraction);
        private _distance=_origin distance2D _closest;
        private _near=_distance <= 3 && {abs ((_origin select 2)-(_closest select 2)) <= 2};
        if (_near) then {
            if (!_inNearRun) then {_nearRuns=_nearRuns+1};
            if (_nearIndex < 0 || {_distance < _nearDistance}) then {_nearIndex=_i;_nearDistance=_distance};
        };
        // Zero-length duplicate nodes do not break a contiguous path stretch.
        _inNearRun=_near;
    };
};
if (_nearIndex < 0 || {_nearRuns > 1}) exitWith {[]};
for "_i" from (_nearIndex+1) to ((_nearIndex+3) min (count _nodes-1)) do {
    private _point=_nodes select _i;
    private _distance=_origin distance2D _point;
    if (_distance >= 3 && {_distance <= _best} && {abs ((_origin select 2)-(_point select 2)) <= 2}) then {
        private _local=_vehicle worldToModel (ASLToAGL _point);
        if ((_local select 1) > 1) then {_best=_distance;_target=_local};
    };
};
if (_target isEqualTo []) exitWith {[]};
private _distanceSquared=(_target select 0)^2+(_target select 1)^2;
[2*(_target select 0)/_distanceSquared,true]

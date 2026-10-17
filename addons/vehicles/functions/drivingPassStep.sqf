/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes finite OUT, DROP_BACK, RETURN_SCAN and RETURN pass work in the driving FSM.
 * Locality/authority: Existing current ordinary-driving callback only. Exact epoch, generation,
 * route, crew, token and issued command receipts guard every fixed-path write. No speed writer:
 * the caller applies the returned cap with its unchanged traffic/pedestrian/geometry limits.
 * Observed native STOP events end work without recall. Own setup carries an exact write fence.
 * Repeated identical STOP delivery and event timing require physical interruption QA.
 * Repeat/JIP: Original consent context and finite expiry must still match; its deadline never renews. Return begins only after measured hull
 * separation. New native/controller orders retire work without recall. Each issued leg publishes
 * cleanup identity for successor owners, never the path/work. No physics or JIP replay.
 * Arguments: 0 group <GROUP>, grpNull; 1 vehicle <OBJECT>, objNull; 2 brain <HASHMAP>, empty;
 * 3 current caller movement guard <CODE>, false.
 * Return: ARRAY [active BOOL, cap m/s NUMBER, phase/reason STRING]. Terminal blocked aborts
 * retain failure evidence and may leave an owned STOP rather than merge through an occupied hull.
 * One existing callback observes at most one bounded traffic query OR one geometry slice.
 * Current callers: DrivingAssistStart only; admission is explicit DrivingPassBegin.
 * Example: [_group,_vehicle,_brain,_mayIssueDriving] call WAIT_fnc_DrivingPassStep;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],
    ["_brain",createHashMap,[createHashMap]],["_mayIssue",{false},[{}]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _vehicle} || {!local _vehicle}
    || {isNull _group} || {!local _group}
    || {(_group getVariable ["WAIT_Driving_Brain",createHashMap]) isNotEqualTo _brain}) exitWith {[false,1e6,"NOT_CURRENT_OWNER"]};
private _work=_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap];
if (count _work == 0) exitWith {[false,1e6,""]};
if ((_work get "group") != _group) exitWith {
    [_vehicle,_work get "group","GROUP_CHANGED",false] call WAIT_fnc_DrivingPassFinish;
    [false,1e6,"GROUP_CHANGED"]
};
private _driver=_work get "driver";private _operator=_work get "operator";private _peer=_work get "peer";
private _base={
    !(_work getOrDefault ["interrupted",false]) && {call _mayIssue} && {(_work get "epoch") == (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {(_work get "generation") == (_brain getOrDefault ["generation",-1])}
        && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])}
        && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")}
        && {driver _vehicle == _driver} && {(effectiveCommander _vehicle) in [_operator,objNull]}
        && {[_driver,_operator] findIf {[_x] call WAIT_fnc_CortexActorMoveReserved} < 0}
        && {[_driver,_operator] findIf {!(currentCommand _x in ["","MOVE","WAIT","STOP"])} < 0}
        && {(_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap]) isEqualTo _work}
};
private _current={call _base && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
    && {(expectedDestination _operator) isEqualTo (_work get "command")}};
private _finish={params ["_reason",["_resume",false]];
    [_vehicle,_group,_reason,_resume] call WAIT_fnc_DrivingPassFinish;
    [false,1e6,_reason]
};
if (_work getOrDefault ["interrupted",false]) exitWith {["NATIVE_STOP_EVENT",false] call _finish};
if !(call _current) exitWith {["OWNER_OR_ORDER_CHANGED",true] call _finish};
private _consent=_vehicle getVariable ["WAIT_DrivingPass_Consent",[]];

if (isNull _peer) exitWith {["PEER_DELETED",true] call _finish};
// Use complete oriented hull intervals, not centre distance and nominal half lengths.
// Even the permitted heading difference changes longitudinal extent at the outer corners.
private _heading=getDir _peer;private _axis=[sin _heading,cos _heading,0];
private _origin=getPosWorld _peer;
private _span={
    params ["_object"];
    private _box=boundingBoxReal _object;private _low=_box select 0;private _high=_box select 1;
    private _minimum=1e9;private _maximum=-1e9;
    {private _xx=_x;{private _yy=_x;{
        private _point=(_object modelToWorldWorld [_xx,_yy,_x]) vectorDiff _origin;
        private _along=_point vectorDotProduct _axis;
        _minimum=_minimum min _along;_maximum=_maximum max _along;
    } forEach [_low select 2,_high select 2];} forEach [_low select 1,_high select 1];} forEach [_low select 0,_high select 0];
    [_minimum,_maximum]
};
private _ownSpan=[_vehicle] call _span;private _peerSpan=[_peer] call _span;
private _aligned=abs (((getDir _vehicle-getDir _peer+540) mod 360)-180) <= 25;
private _ahead=_aligned && {(_ownSpan select 0) > (_peerSpan select 1)+6};
private _behind=_aligned && {(_ownSpan select 1) < (_peerSpan select 0)-3};
if (!(_consent isEqualType []) || {count _consent != 5} || {(_consent select 0) isNotEqualTo (_work get "token")}
    || {(_consent select 4) isNotEqualTo "AGREED"}
    || {(_consent select 1) isNotEqualTo (_work get "context")}
    || {!((_consent select 3) isEqualType 0)} || {!finite (_consent select 3)}
    || {(_consent select 3) != (_work get "deadline")}) exitWith {["CONSENT_RETIRED",_ahead || {_behind}] call _finish};
if (serverTime >= (_work get "deadline")) exitWith {
    [["EXPIRED_HELD","EXPIRED_CLEAR"] select (_ahead || {_behind}),_ahead || {_behind}] call _finish
};
private _phase=_work get "phase";
private _pairContext=[[_vehicle,_peer]] call WAIT_fnc_DrivingPassContext;
private _peerCurrent=_pairContext isNotEqualTo [] && {((_pairContext select 1) select 1) isEqualTo (_work get "peerRow")};
if ((!_peerCurrent || {!alive _peer} || {!_aligned}) && {_phase in ["OUT","RETURN_SCAN"]}) then {
    _phase="DROP_BACK";_work set ["phase",_phase];
};
private _issue={
    params ["_path","_newPhase"];
    private _issued=false;
    // Keep the formation release and sole fixed-path write in one unscheduled boundary.
    isNil {
        if (count _path >= 2 && {call _current}) then {
            private _writing=[_vehicle,_work get "token",_work get "epoch",_work get "generation"];
            _group setVariable ["WAIT_DrivingPass_CommandWriting",_writing];
            doStop _driver;if (_operator != _driver) then {doStop _operator};
            if (call _base) then {
                _vehicle setDriveOnPath _path;
                _work set ["driverCommand",+(expectedDestination _driver)];
                _work set ["command",+(expectedDestination _operator)];
                _work set ["issued",true];_work set ["phase",_newPhase];
                // Cleanup identity only: successors must never replay the old fixed path.
                _vehicle setVariable ["WAIT_DrivingPass_Leg",["PASS_LEG_V1",clientOwner,_group,
                    _work get "epoch",_work get "generation",_work get "token",_driver,_operator,
                    +(expectedDestination _driver),+(expectedDestination _operator),
                    _work get "route",_work get "deadline",_peer],true];
                _work set ["target",+(_path select (count _path-1))];
                _work set ["lastDistance",_vehicle distance2D (_work get "target")];
                _work set ["lastAt",serverTime];
                _issued=true;
            };
            if ((_group getVariable ["WAIT_DrivingPass_CommandWriting",[]]) isEqualTo _writing) then {
                _group setVariable ["WAIT_DrivingPass_CommandWriting",nil];
            };
        };
        false
    };
    _issued
};
if (!(_work get "issued") && {!_peerCurrent || {!_aligned} || {!alive _peer}}) exitWith {["ADMISSION_CONTEXT_CHANGED",false] call _finish};
if !(_work get "issued") then {
    if !([_work get "outPath","OUT"] call _issue) exitWith {};
};
if !(_work get "issued") exitWith {["PATH_NOT_ISSUED",false] call _finish};
if (_phase == "OUT" && {_ahead}) then {
    _phase="RETURN_SCAN";_work set ["phase",_phase];_work set ["scanAt",serverTime];
};
if (_phase == "DROP_BACK") exitWith {
    if (_behind || {_ahead}) exitWith {["ABORT_CLEAR",true] call _finish};
    [true,(((velocityModelSpace _peer select 1) max 0)-12/3.6) max 0,"DROP_BACK"]
};
if (_phase == "RETURN_SCAN") exitWith {
    if (serverTime-(_work get "scanAt") >= 4) exitWith {["RETURN_SCAN_EXPIRED",_ahead] call _finish};
    private _proposal=createHashMapFromArray [["status","PROPOSAL"],["vehicles",[_vehicle,_peer]],
        ["context",_pairContext],["observedAt",serverTime],["guideASL",_work get "returnASL"]];
    private _slice=[_proposal,_work get "scanCursor"] call WAIT_fnc_DrivingPassGeometry;
    if ((_slice getOrDefault ["status",""]) != "SLICE_PROPOSAL") exitWith {["RETURN_OBSTRUCTED",false] call _finish};
    private _points=_work get "returnValidated";
    _points append ((_slice get "pointsATL") select [[1,0] select ((_work get "scanCursor") == 0)]);
    _work set ["scanCursor",_slice get "next"];
    if (_slice get "lastSlice") then {
        if (_ahead && {[_points,"RETURN"] call _issue}) then {_phase="RETURN"} else {_phase="RETURN_SCAN"};
    };
    [true,[0,_work get "cap"] select (_phase == "RETURN"),_phase]
};
if (_phase == "RETURN") exitWith {
    private _target=_work get "target";
    if (_vehicle distance2D _target <= 4 && {abs (((getPosATL _vehicle) select 2)-(_target select 2)) <= 2}) exitWith {["RETURN_COMPLETE",true] call _finish};
    [true,_work get "cap","RETURN"]
};
// OUT retains all caller collision caps. An obstruction never grants traffic-ignore time.
private _proposal=createHashMapFromArray [["status","PROPOSAL"],["vehicles",[_vehicle,_peer]],
    ["context",_pairContext],["observedAt",serverTime],["guideASL",(_work get "outPath") apply {ATLToASL _x}],
    ["estimatedSeconds",((_work get "deadline")-serverTime) min 24],["requiredTravel",350]];
private _traffic=[_proposal] call WAIT_fnc_DrivingPassTraffic;
private _distance=_vehicle distance2D (_work get "target");
if ((_work get "lastDistance")-_distance >= 1) then {_work set ["lastDistance",_distance];_work set ["lastAt",serverTime]};
if ((_traffic getOrDefault ["status",""]) != "TRAFFIC_OBSERVATION" || {_traffic getOrDefault ["blocked",true]}
    || {serverTime-(_work get "lastAt") >= 15} || {behaviour leader _group in ["COMBAT","STEALTH"]}) then {
    _work set ["phase","DROP_BACK"];
    [true,(((velocityModelSpace _peer select 1) max 0)-12/3.6) max 0,"DROP_BACK"]
} else {[true,_work get "cap","OUT"]}
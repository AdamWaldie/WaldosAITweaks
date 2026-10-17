/*
 * Author: WaldoTheWarfighter
 * Purpose: Admits an explicitly prepared, agreed road pass into the existing ordinary driving FSM.
 * Locality/authority: Current owner of the leader vehicle, effective crew and group only. No
 * movement occurs here; DrivingPassStep is called by the existing sole driving writer.
 * Repeat/JIP: One local work journal per vehicle, original consent expiry never renews. New
 * owners require new preparation/agreement. A finite exact STOP observer is installed;
 * no scheduler, JIP command or automatic discovery.
 * Arguments: 0 proposal <HASHMAP>, empty; 1 prepared work <HASHMAP>, empty.
 * Return: BOOL - local work admitted, not movement or successful passage.
 * Current callers: trusted explicit scripts and experimental DrivingPassAdmission.
 * Requires an existing current driving brain and an unexpired prepared proposal/consent.
 * Example: [_proposal,_prepared] call WAIT_fnc_DrivingPassBegin;
 */
params [["_proposal",createHashMap,[createHashMap]],["_prepared",createHashMap,[createHashMap]]];
if (isRemoteExecuted) exitWith {false};
_prepared=[_proposal,_prepared] call WAIT_fnc_DrivingPassPrepare;
if ((_prepared getOrDefault ["phase",""]) != "READY_PROPOSAL") exitWith {false};
private _vehicles=_prepared get "vehicles";private _vehicle=_vehicles select 0;
if (!([_vehicle] call WAIT_fnc_DrivingPassCanConsent)
    || {count (_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap]) > 0}) exitWith {false};
private _group=group driver _vehicle;
if (vehicle leader _group != _vehicle) exitWith {false};
private _brain=_group getVariable ["WAIT_Driving_Brain",createHashMap];
if (count _brain == 0 || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {false};
private _context=_prepared get "context";
private _agreement=_vehicle getVariable ["WAIT_DrivingPass_Agreement",[]];
private _consent=_vehicle getVariable ["WAIT_DrivingPass_Consent",[]];
if (!(_agreement isEqualType []) || {!(_consent isEqualType [])} || {count _agreement != 5} || {count _consent != 5} || {(_agreement select 4) != "AGREED"}
    || {(_consent select 4) != "AGREED"} || {(_agreement select 0) != (_consent select 0)}
    || {(_agreement select 1) isNotEqualTo _vehicles} || {(_agreement select 2) isNotEqualTo _context}
    || {(_consent select 1) isNotEqualTo _context} || {serverTime >= (_agreement select 3)}) exitWith {false};
private _traffic=[_proposal] call WAIT_fnc_DrivingPassTraffic;
if ((_traffic getOrDefault ["status",""]) != "TRAFFIC_OBSERVATION" || {_traffic getOrDefault ["blocked",true]}) exitWith {false};
private _path=(_prepared get "pointsATL") apply {+_x};
private _pathASL=(_prepared get "pointsASL") apply {+_x};
private _budget=+(_prepared get "budget");
if (count _budget != 4 || {_budget findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {(_budget select 0) <= 0} || {count _path != count _pathASL} || {count _path < 4}) exitWith {false};
private _split=_budget select 3;
if (_split != floor _split || {_split < 2} || {_split >= count _path-1}) exitWith {false};
private _operator=effectiveCommander _vehicle;if (isNull _operator) then {_operator=driver _vehicle};
private _work=createHashMapFromArray [["group",_group],["epoch",_group getVariable ["WAIT_AIPass_Epoch",0]],
    ["generation",_brain get "generation"],["route",[_group] call WAIT_fnc_DrivingRouteReceipt],
    ["driver",driver _vehicle],["operator",_operator],["driverCommand",+(expectedDestination driver _vehicle)],
    ["command",+(expectedDestination _operator)],["peer",_vehicles select 1],["peerRow",(_context select 1) select 1],
    ["context",_context],["token",_agreement select 0],["deadline",_agreement select 3],["started",serverTime],
    ["phase","OUT"],["issued",false],["interrupted",false],["outPath",_path select [0,_split]],
    ["returnPath",_path select [_split-1]],["returnASL",_pathASL select [_split-1]],
    ["scanAt",-1],["scanCursor",0],["returnValidated",[]],
    ["cap",((_budget select 1)-30)/(_budget select 0)]];
if (([_vehicles] call WAIT_fnc_DrivingPassContext) isNotEqualTo _context
    || {serverTime >= (_prepared get "deadline")} || {!([_vehicle] call WAIT_fnc_DrivingPassCanConsent)}) exitWith {false};
_vehicle setVariable ["WAIT_DrivingPass_Work",_work];
if (!([_group,_vehicle,_work] call WAIT_fnc_DrivingPassCommandWatch)) exitWith {
    if ((_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap]) isEqualTo _work) then {
        _vehicle setVariable ["WAIT_DrivingPass_Work",nil];
    };
    false
};
_vehicle setVariable ["WAIT_DrivingAssist_Next",time];
_brain set ["nextAt",time];
[_brain] call WAIT_fnc_DrivingOperationQueue;
true
/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe sustained ordinary-road obstruction and prepare an opt-in automatic pass.
 * Locality/authority: Internal current driving owner only. OBSERVE reads the existing traffic
 * sample; STEP runs finite geometry/consent work on the shared scheduler. No movement or speed
 * writes: successful preparation enters DrivingPassBegin and the existing operation FSM.
 * Repeat/JIP: One two-second preparation per owner, eight-second observation and 60-second
 * context cooldown. Original deadlines never renew; owner/route/crew changes cancel. Private
 * jobs never migrate or replay. Late replies require the still-current request serial/context.
 * Arguments: 0 mode <STRING>, OBSERVE/STEP/CANCEL; 1 group <GROUP>, grpNull;
 * 2 vehicle <OBJECT>, objNull; 3 driving brain <HASHMAP>, empty;
 * 4 traffic observation <ARRAY>, []; 5 proposed m/s <NUMBER>, 0;
 * 6 preparation job <HASHMAP>, empty, internal STEP only.
 * Return: OBSERVE NUMBER qualification cap m/s (1e6 means no extra constraint);
 * CANCEL BOOL; STEP NUMBER next shared-scheduler delay or -1. Only the existing writer applies caps.
 * Bounds: one 12-station geometry slice (<=243 rays) or traffic query per 0.1-second job step,
 * <=2 seconds total. No added world discovery, permanent scheduler or collision exemption.
 * Current callers: DrivingAssistStart, DrivingAssistRelease and this finite scheduled job.
 * Example: ["OBSERVE",_group,_vehicle,_brain,_traffic,15] call WAIT_fnc_DrivingPassAdmission;
 */
params [["_mode","OBSERVE",[""]],["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],
    ["_brain",createHashMap,[createHashMap]],["_traffic",[],[[]]],["_speed",0,[0]],
    ["_job",createHashMap,[createHashMap]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {if (_mode == "STEP") then {-1} else {if (_mode == "OBSERVE") then {1e6} else {false}}};
if (_mode == "STEP") then {
    _group=_job getOrDefault ["group",grpNull];_vehicle=_job getOrDefault ["vehicle",objNull];
    _brain=_job getOrDefault ["brain",createHashMap];
};
if (_mode != "STEP" && {isNull _vehicle}) exitWith {if (_mode == "OBSERVE") then {1e6} else {false}};
private _finish={
    params ["_reason",["_started",false]];
    private _context=_job getOrDefault ["context",[]];
    _job set ["done",true];
    if (!isNull _vehicle && {(_vehicle getVariable ["WAIT_DrivingPass_Admission",createHashMap]) isEqualTo _job}) then {
        if (!_started) then {
            private _request=_vehicle getVariable ["WAIT_DrivingPass_Request",[]];
            private _requestOwned=count _request == 3 && {(_request select 0) isEqualTo _context}
                && {(_request select 2) == (_job getOrDefault ["serial",-1])};
            if (_requestOwned) then {
                private _consent=_vehicle getVariable ["WAIT_DrivingPass_Consent",[]];
                if (count _consent == 5 && {(_consent select 1) isEqualTo _context}) then {
                    [_vehicle,_group,_consent select 0] call WAIT_fnc_DrivingPassAgreementRelease;
                };
                if ((_vehicle getVariable ["WAIT_DrivingPass_Request",[]]) isEqualTo _request) then {
                    _vehicle setVariable ["WAIT_DrivingPass_Request",nil];
                };
            };
        };
        _vehicle setVariable ["WAIT_DrivingPass_Admission",nil];
        _vehicle setVariable ["WAIT_DrivingPass_AutoCooldown",[_context,serverTime+60]];
        _vehicle setVariable ["WAIT_DrivingPass_AdmissionResult",[_reason,serverTime]];
    };
    if ((missionNamespace getVariable ["WAIT_DrivingPass_Preparing",createHashMap]) isEqualTo _job) then {
        missionNamespace setVariable ["WAIT_DrivingPass_Preparing",nil];
    };
    -1
};
if (_mode == "CANCEL") exitWith {
    _job=_vehicle getVariable ["WAIT_DrivingPass_Admission",createHashMap];
    if (count _job > 0 && {!isNull _group} && {(_job get "group") != _group}) exitWith {false};
    if (count _job > 0) then {["CANCELLED"] call _finish};
    private _seen=_vehicle getVariable ["WAIT_DrivingPass_AutoSeen",[]];
    if (count _seen == 3 && {isNull _group || {((_seen select 0) select 0) == _group}}) then {
        _vehicle setVariable ["WAIT_DrivingPass_AutoSeen",nil];
    };
    private _cruise=_vehicle getVariable ["WAIT_DrivingPass_AutoCruise",[]];
    if (count _cruise == 3 && {isNull _group || {((_cruise select 0) select 0) == _group}}) then {
        _vehicle setVariable ["WAIT_DrivingPass_AutoCruise",nil];
    };true
};
if !(_mode in ["OBSERVE","STEP"]) exitWith {false};
private _enabled=[_group,"WAIT_AIPass_DrivingAssist_Passing_Enable",false] call WAIT_fnc_CortexFeatureEnabled;
if (_mode == "OBSERVE" && {!_enabled} && {isNil {_vehicle getVariable "WAIT_DrivingPass_Admission"}}
    && {isNil {_vehicle getVariable "WAIT_DrivingPass_AutoSeen"}}) exitWith {1e6};
private _current=_enabled && {!isNull _group} && {local _group} && {!isNull _vehicle} && {local _vehicle}
    && {(_group getVariable ["WAIT_Driving_Brain",createHashMap]) isEqualTo _brain}
    && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])}
    && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {vehicle leader _group == _vehicle} && {!(behaviour leader _group in ["COMBAT","STEALTH"])}
    && {[_vehicle] call WAIT_fnc_DrivingPassCanConsent};
if (_mode == "STEP") exitWith {
    if (!_current || {_job getOrDefault ["done",false]}
        || {(_vehicle getVariable ["WAIT_DrivingPass_Admission",createHashMap]) isNotEqualTo _job}
        || {(missionNamespace getVariable ["WAIT_DrivingPass_Preparing",createHashMap]) isNotEqualTo _job}
        || {(_brain getOrDefault ["generation",-1]) != (_job get "generation")}
        || {serverTime >= (_job get "deadline")}) exitWith {["OWNER_ORDER_OR_DEADLINE"] call _finish};
    private _request=_vehicle getVariable ["WAIT_DrivingPass_Request",[]];
    if (_job getOrDefault ["requested",false] && {count _request != 3
        || {(_request select 0) isNotEqualTo (_job get "context")}
        || {(_request select 2) != (_job get "serial")}}) exitWith {["REQUEST_REPLACED"] call _finish};
    private _proposal=_job get "proposal";
    private _prepared=[_proposal,_job get "prepared"] call WAIT_fnc_DrivingPassPrepare;
    _job set ["prepared",_prepared];
    private _phase=_prepared getOrDefault ["phase","REFUSED"];
    if (_phase in ["REFUSED","EXPIRED"]) exitWith {[_prepared getOrDefault ["reason",_phase]] call _finish};
    if (_phase == "READY_PROPOSAL") then {
        if !(_job getOrDefault ["requested",false]) then {
            if ([_proposal,_prepared] call WAIT_fnc_DrivingPassAgreementRequest) then {
                _job set ["requested",true];
                _job set ["serial",(_vehicle getVariable ["WAIT_DrivingPass_Request",[]]) param [2,-1]];
            };
        } else {
            private _agreement=_vehicle getVariable ["WAIT_DrivingPass_Agreement",[]];
            if (count _agreement == 5 && {(_agreement select 2) isEqualTo (_job get "context")}
                && {(_agreement select 4) == "AGREED"}) then {
                private _started=[_proposal,_prepared] call WAIT_fnc_DrivingPassBegin;
                [["BEGIN_REFUSED","ADMITTED"] select _started,_started] call _finish;
            };
        };
    };
    if (_job getOrDefault ["done",false]) then {-1} else {0.1}
};
private _old=_vehicle getVariable ["WAIT_DrivingPass_Admission",createHashMap];
if (count _old > 0 && {!(_old getOrDefault ["done",false])} && {serverTime < (_old get "deadline")}) exitWith {
    if (!_current || {([(_old get "proposal") get "vehicles"] call WAIT_fnc_DrivingPassContext) isNotEqualTo (_old get "context")}) then {
        _job=_old;["OBSERVATION_CHANGED"] call _finish;1e6
    } else {_old getOrDefault ["headwayCap",1e6]}
};
if (count _old > 0) then {_job=_old;["EXPIRED"] call _finish};
private _peer=_traffic param [1,objNull,[objNull]];
// Our extra headway can remove the ordinary close-follow cap. Continue observing only
// the same fresh peer/context while no different limiting obstacle has appeared.
private _priorSeen=_vehicle getVariable ["WAIT_DrivingPass_AutoSeen",[]];
if (isNull _peer && {count _priorSeen == 3} && {serverTime >= (_priorSeen select 2)}
    && {serverTime-(_priorSeen select 2) <= 6}) then {
    private _binding=_priorSeen select 0;
    if (count _binding == 4 && {(_binding select [0,3]) isEqualTo [_group,_brain getOrDefault ["generation",-1],_brain getOrDefault ["ownerEpoch",-1]]}) then {
        private _oldContext=_binding select 3;
        private _rows=_oldContext param [1,[],[[]]];
        private _oldPeer=(_rows param [1,[],[[]]]) param [0,objNull,[objNull]];
        if (!isNull _oldPeer && {([[_vehicle,_oldPeer]] call WAIT_fnc_DrivingPassContext) isEqualTo _oldContext}) then {_peer=_oldPeer};
    };
};
private _cruiseIdentity=[_group,_brain getOrDefault ["ownerEpoch",-1],_brain getOrDefault ["generation",-1],
    speedMode _group,[_group] call WAIT_fnc_DrivingRouteReceipt];
private _cruise=_vehicle getVariable ["WAIT_DrivingPass_AutoCruise",[]];
private _cruiseValid=count _cruise == 3 && {(_cruise select 0) isEqualTo _cruiseIdentity}
    && {serverTime >= (_cruise select 2)} && {serverTime-(_cruise select 2) <= 30};
if (_current && {isNull _peer} && {speed _vehicle > 2}) then {
    private _seenSpeed=(speed _vehicle)/3.6;
    _cruise=[_cruiseIdentity,_seenSpeed,serverTime];_cruiseValid=true;
    _vehicle setVariable ["WAIT_DrivingPass_AutoCruise",_cruise];
};
private _seenCruise=if (_cruiseValid) then {_cruise select 1} else {0};
private _capability=((getNumber (configOf _vehicle >> "maxSpeed"))*0.65/3.6) max _seenCruise;
if (speedMode _group == "LIMITED") then {_capability=_seenCruise};
_speed=_speed min _capability min (((speed _peer) max 0)/3.6+30/3.6);
private _candidate=_current && {finite _speed} && {_speed >= 5/3.6} && {_speed <= 120/3.6}
    && {!isNull _peer} && {_peer != _vehicle} && {alive _peer} && {!isNull driver _peer}
    && {group driver _peer != _group}
    && {!(behaviour driver _peer in ["COMBAT","STEALTH"])}
    && {speed _peer > 2} && {speed _peer+10 < _speed*3.6}
    && {abs (((getDir _peer-getDir _vehicle+540) mod 360)-180) <= 25}
    && {abs ((getPosASL _peer select 2)-(getPosASL _vehicle select 2)) <= 2}
    && {_vehicle distance2D _peer <= 60} && {!isNull roadAt _vehicle} && {!isNull roadAt _peer};
if (!_candidate) exitWith {_vehicle setVariable ["WAIT_DrivingPass_AutoSeen",nil];1e6};
private _context=[[_vehicle,_peer]] call WAIT_fnc_DrivingPassContext;
if (_context isEqualTo []) exitWith {1e6};
private _cooldown=_vehicle getVariable ["WAIT_DrivingPass_AutoCooldown",[]];
if (count _cooldown == 2 && {(_cooldown select 0) isEqualTo _context} && {serverTime < (_cooldown select 1)}) exitWith {1e6};
// Keep pull-out room while qualifying instead of converging on ordinary close-follow spacing.
// This is only a cap proposal; the existing writer and all collision minima retain control.
private _ownBox=boundingBoxReal _vehicle;private _peerBox=boundingBoxReal _peer;
private _ownHalfLength=(abs ((_ownBox select 0) select 1)) max (abs ((_ownBox select 1) select 1));
private _peerHalfLength=(abs ((_peerBox select 0) select 1)) max (abs ((_peerBox select 1) select 1));
private _ownHalfWidth=(abs ((_ownBox select 0) select 0)) max (abs ((_ownBox select 1) select 0));
private _peerHalfWidth=(abs ((_peerBox select 0) select 0)) max (abs ((_peerBox select 1) select 0));
private _heading=getDir _vehicle;private _forward=[sin _heading,cos _heading,0];
private _relative=(getPosASL _peer) vectorDiff (getPosASL _vehicle);
private _gap=_relative vectorDotProduct _forward;
private _lateral=abs (_relative vectorDotProduct [cos _heading,-sin _heading,0]);
if (_gap <= 0 || {_lateral > _ownHalfWidth+_peerHalfWidth+1}) exitWith {
    _vehicle setVariable ["WAIT_DrivingPass_AutoSeen",nil];1e6
};
private _pullOut=(1.5*(_ownHalfWidth+_peerHalfWidth+2+_lateral)/tan 20) max 12;
private _desired=_ownHalfLength+_peerHalfLength+_pullOut+6;
private _peerForward=((velocity _peer) vectorDotProduct _forward) max 0;
private _headwayCap=_speed min ((_peerForward+(_gap-_desired)/4) max 0);
private _identity=[_group,_brain get "generation",_brain get "ownerEpoch",_context];
private _seen=_vehicle getVariable ["WAIT_DrivingPass_AutoSeen",[]];
private _continuous=count _seen == 3 && {(_seen select 0) isEqualTo _identity}
    && {serverTime >= (_seen select 2)} && {serverTime-(_seen select 2) <= 6};
private _since=if (_continuous) then {_seen select 1} else {serverTime};
_vehicle setVariable ["WAIT_DrivingPass_AutoSeen",[_identity,_since,serverTime]];
if (serverTime-_since < 8) exitWith {_headwayCap};
private _slot=missionNamespace getVariable ["WAIT_DrivingPass_Preparing",createHashMap];
if (count _slot > 0 && {!(_slot getOrDefault ["done",false])} && {serverTime < (_slot get "deadline")}) exitWith {_headwayCap};
private _proposal=[_vehicle,_peer,_speed*3.6] call WAIT_fnc_DrivingPassPlan;
if ((_proposal getOrDefault ["status",""]) != "PROPOSAL") exitWith {
    _vehicle setVariable ["WAIT_DrivingPass_AutoCooldown",[_context,serverTime+60]];1e6
};
_job=createHashMapFromArray [["group",_group],["vehicle",_vehicle],["brain",_brain],
    ["ownerEpoch",_brain get "ownerEpoch"],["generation",_brain get "generation"],
    ["context",_proposal get "context"],["proposal",_proposal],["prepared",createHashMap],
    ["deadline",(_proposal get "observedAt")+2],["headwayCap",_headwayCap],["done",false],["requested",false],["serial",-1]];
_vehicle setVariable ["WAIT_DrivingPass_Admission",_job];
missionNamespace setVariable ["WAIT_DrivingPass_Preparing",_job];
[{params ["_job"];["STEP",grpNull,objNull,createHashMap,[],0,_job] call WAIT_fnc_DrivingPassAdmission},
    _job,0,format ["WAIT_PASS_PREP_%1_%2",str _vehicle,_brain get "generation"]] call WAIT_fnc_CortexQueueJob;
_headwayCap

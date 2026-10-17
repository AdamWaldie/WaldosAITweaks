/*
 * Author: WaldoTheWarfighter
 * Purpose: Advances finite road-pass preparation through geometry slices and fresh traffic observation.
 * Locality/authority: Caller-owned work map on the vehicle owner only. No movement, claims,
 * agreement, scheduler or public state is installed. Remote execution is refused.
 * Repeat/JIP: Pass the returned work map to continue. Its original two-second deadline and
 * copied proposal/context identity and estimate/travel/time budget never renew. Terminal refusal cannot restart the same work.
 * Arguments: 0 proposal <HASHMAP>, empty; 1 prior work <HASHMAP>, empty for a new preparation.
 * Return: HASHMAP phase SCANNING, TRAFFIC, READY_PROPOSAL, REFUSED or EXPIRED, with reason,
 * cursor, deadline, pointsATL/ASL, rayCount, context and fresh traffic observation when available.
 * One call performs at most one 12-station geometry slice (243 rays maximum) OR one bounded traffic query.
 * READY_PROPOSAL means all slices were sampled and the final observer found no conflict;
 * it grants no owner agreement, swept-volume guarantee, native steering or movement authority.
 * Current callers: trusted script preflight and experimental DrivingPassAdmission; physical acceptance remains outstanding.
 * Example: _work=[_proposal,_work] call WAIT_fnc_DrivingPassPrepare;
 */
params [["_proposal",createHashMap,[createHashMap]],["_work",createHashMap,[createHashMap]]];
private _refuse={params ["_reason",["_phase","REFUSED"]];_work set ["phase",_phase];_work set ["reason",_reason];_work};
if (isRemoteExecuted) exitWith {["REMOTE_EXECUTION"] call _refuse};
if (count _work == 0) then {
    private _vehicles=_proposal getOrDefault ["vehicles",[]];
    private _context=[_vehicles] call WAIT_fnc_DrivingPassContext;
    private _guide=_proposal getOrDefault ["guideASL",[]];
    private _at=_proposal getOrDefault ["observedAt",-1];
    private _budget=[_proposal getOrDefault ["estimatedSeconds",-1],
        _proposal getOrDefault ["requiredTravel",-1],_proposal getOrDefault ["maximumSeconds",-1],_proposal getOrDefault ["returnIndex",-1]];
    if ((_proposal getOrDefault ["status",""]) != "PROPOSAL" || {_context isEqualTo []}
        || {_context isNotEqualTo (_proposal getOrDefault ["context",[]])}
        || {_budget findIf {!(_x isEqualType 0) || {!finite _x} || {_x <= 0}} >= 0}
        || {(_budget select 0) > 24} || {(_budget select 1) > 350}
        || {(_budget select 3) != floor (_budget select 3)} || {(_budget select 3) < 2}
        || {(_budget select 3) >= count _guide-1}
        || {(_budget select 2) < (_budget select 0)} || {(_budget select 2) > 50}
        || {!(_at isEqualType 0)} || {!finite _at} || {serverTime < _at} || {serverTime-_at >= 2}
        || {!(_guide isEqualType [])} || {count _guide < 2} || {count _guide > 128}
        || {_guide findIf {!(_x isEqualType []) || {count _x != 3}
            || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}) then {
        ["INVALID_PROPOSAL"] call _refuse;
    } else {
        _work set ["phase","SCANNING"];
        _work set ["reason","GEOMETRY_PENDING"];
        _work set ["context",_context];
        _work set ["vehicles",+_vehicles];
        _work set ["guide",_guide apply {+_x}];
        _work set ["proposalAt",_at];
        _work set ["budget",+_budget];
        _work set ["deadline",_at+2];
        _work set ["cursor",0];
        _work set ["pointsATL",[]];_work set ["pointsASL",[]];
        _work set ["rayCount",0];
    };
};
private _phase=_work getOrDefault ["phase","REFUSED"];
if (_phase in ["REFUSED","EXPIRED"]) exitWith {_work};
private _deadline=_work getOrDefault ["deadline",-1];
if (!(_deadline isEqualType 0) || {!finite _deadline} || {serverTime >= _deadline}) exitWith {["PREPARATION_DEADLINE","EXPIRED"] call _refuse};
private _vehicles=_work getOrDefault ["vehicles",[]];
private _budget=[_proposal getOrDefault ["estimatedSeconds",-1],
    _proposal getOrDefault ["requiredTravel",-1],_proposal getOrDefault ["maximumSeconds",-1],_proposal getOrDefault ["returnIndex",-1]];
if ((_proposal getOrDefault ["status",""]) != "PROPOSAL"
    || {_budget isNotEqualTo (_work getOrDefault ["budget",[]])}
    || {([_vehicles] call WAIT_fnc_DrivingPassContext) isNotEqualTo (_work getOrDefault ["context",[]])}
    || {(_proposal getOrDefault ["context",[]]) isNotEqualTo (_work getOrDefault ["context",[]])}
    || {(_proposal getOrDefault ["guideASL",[]]) isNotEqualTo (_work getOrDefault ["guide",[]])}
    || {(_proposal getOrDefault ["observedAt",-1]) isNotEqualTo (_work getOrDefault ["proposalAt",-2])}
    || {(_proposal getOrDefault ["vehicles",[]]) isNotEqualTo _vehicles}
    || {_vehicles isEqualTo []} || {!local (_vehicles select 0)}) exitWith {["PROPOSAL_OR_CONTEXT_CHANGED"] call _refuse};
if (count _vehicles == 2 && {group driver (_vehicles select 0) == group driver (_vehicles select 1)}) exitWith {["SAME_GROUP"] call _refuse};
// Local receipt observation is not consent for a foreign owner. Keep that distinction
// explicit while refusing local controller/mission conflicts before costly geometry.
private _remoteOwners=[];
private _localRefused=_vehicles findIf {
    if (local _x) exitWith {!([_x] call WAIT_fnc_DrivingPassCanConsent)};
    _remoteOwners pushBackUnique (owner _x);
    false
};
if (_localRefused >= 0) exitWith {["LOCAL_CONSENT_REFUSED"] call _refuse};
_work set ["requiredRemoteOwners",_remoteOwners];
if (_phase == "SCANNING") exitWith {
    private _cursor=_work getOrDefault ["cursor",-1];
    private _slice=[_proposal,_cursor] call WAIT_fnc_DrivingPassGeometry;
    _work set ["rayCount",(_work getOrDefault ["rayCount",0])+(_slice getOrDefault ["rayCount",0])];
    if ((_slice getOrDefault ["status",""]) != "SLICE_PROPOSAL") exitWith {[_slice getOrDefault ["reason","GEOMETRY_REFUSED"]] call _refuse};
    if (serverTime >= _deadline) exitWith {["PREPARATION_DEADLINE","EXPIRED"] call _refuse};
    private _skip=[1,0] select (_cursor == 0);
    {private _points=_work get _x;_points append ((_slice get _x) select [_skip])} forEach ["pointsATL","pointsASL"];
    _work set ["cursor",_slice get "next"];
    if (_slice get "lastSlice") then {_work set ["phase","TRAFFIC"];_work set ["reason","TRAFFIC_PENDING"]};
    _work
};
if (_phase == "TRAFFIC") exitWith {
    private _traffic=[_proposal] call WAIT_fnc_DrivingPassTraffic;
    _work set ["traffic",_traffic];
    if (serverTime >= _deadline) exitWith {["PREPARATION_DEADLINE","EXPIRED"] call _refuse};
    if ((_traffic getOrDefault ["status",""]) != "TRAFFIC_OBSERVATION" || {_traffic getOrDefault ["blocked",true]}) exitWith {[_traffic getOrDefault ["reason","TRAFFIC_REFUSED"]] call _refuse};
    _work set ["phase","READY_PROPOSAL"];
    _work set ["reason","OWNER_AGREEMENT_AND_LIVE_EXECUTION_REQUIRED"];
    _work
};
if (_phase != "READY_PROPOSAL") exitWith {["INVALID_PHASE"] call _refuse};
_work
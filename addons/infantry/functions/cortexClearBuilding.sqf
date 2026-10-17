/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: A fresh task replaces the prior episode only after admission checks. A matching
 * owner resume retains original deadlines, shared room coverage and validated individual visit
 * receipts. Fresh-task tokens reject historical participation from earlier clearances. JIP
 * receives public progress; movement remains with the current group owner.
 * Orders an AI group to clear a building room by room.
 *
 * Admission validates finite, distinct model positions with a 512-position budget before
 * geometry queries and replacement cleanup. Reported points still do not prove native access.
 * A squad-aware interior element, including the leader when needed, joins the clear up to a bounded
 * capacity. Each interior lane has a lead and security partner, receives a distinct viable entrance
 * where the topology provides one, then draws the nearest unclaimed room from a
 * shared low-floor-first queue. Only roofed interior positions are clearance objectives; exposed
 * balconies and roof posts belong to garrisoning. This avoids a support partner waiting outside while only one soldier
 * attempts every room, and makes a large squad flow through the building instead of parking around it.
 * Final egress journals pending native-leg receipts and assigned exits across owner
 * migration; planning and travel share the original finite exit deadline.
 * Exterior reserves consider up to sixteen already-discovered native exits independently of
 * the four nearest interior entry choices; this does not establish complete building isolation.
 * Delayed reserve admission retains original native command/formation-leader receipts across
 * the same episode; a new individual task is not claimed before first staging.
 * Spare members above the entry capacity remain an actual reserve and replace unavailable interior
 * workers without pausing the other lanes. In a two-person entry lane, exterior security remains at the entry until the lead has physically crossed it, then follows into the first reached room and trails subsequent rooms. A worker tries its room directly
 * first, then uses a bounded set of alternate real entrances only after the direct route stalls. A
 * blocked room returns to the shared queue for another worker before it can be marked unreachable.
 * Committed units move upright at a bounded assault speed. WAIT
 * records a room only after a physical 1.5 m visit and never teleports a stuck soldier or clears a
 * room from outside. A position is visited only when a soldier physically reaches it within
 * 1.5 m. Each callback checks claimed rooms immediately and rotates a bounded remainder of the
 * topology, preventing a large building from multiplying clearance cost per worker. A casualty or incapacitation is replaced from the uncommitted reserve; without a replacement,
 * other active workers continue claiming the remaining rooms. A worker quarantined by common recovery is rotated out of its clearance lane and replaced from reserve where possible. Timeouts never clear rooms.
 * After all rooms are visited or attempted, the clearing element exits through the building entry
 * to an exterior release point before formation control is restored. This explicit egress avoids
 * abandoning soldiers on interior path nodes and provides the same entry-through-exit primitive used
 * by later movement actions. The order has a progress-renewed safety lease rather than a fixed
 * performance deadline. It preserves the group's current behaviour and combat mode: aware squads
 * remain responsive to the route, while squads already fighting keep engaging. Cleanup therefore
 * cannot overwrite a later contact or Zeus behaviour change. While clearing, the squad does not
 * flank, retreat or search, and
 * is not sent to reinforce others.
 * WAIT owns building clearance. External danger or building controllers are not co-owners of this
 * operation; specialist ownership and Zeus still invalidate it through the common eligibility gate.
 * Locality and authority: call where the group is local, or on the server, which forwards to the
 * owner. Non-server, non-owner copies do nothing.
 *
 * Review contract: Local job generations prevent replaced jobs from issuing orders. Eligibility is checked before dispatch and on each step. Public visited and unreachable position indices, retry/failure evidence, progress-renewed stall deadline, immutable episode deadline and original behaviour survive handover; local movement assignments are rebuilt.
 *
 * Arguments:
 * 0: group <GROUP or OBJECT> - the group, or a unit in it
 * 1: target <OBJECT or ARRAY> - the building, or a position (the nearest building is used)
 * 2: options <HASHMAP> (optional) - resume (default false), preserveBrain (default false for an
 *    explicit order) and operation-specific controls. Natural contact entry uses preserveBrain so
 *    live fire control and contact transitions continue around the single building movement owner.
 *    continueRoute (BOOL, default false) returns a successful clear to its unchanged plain MOVE;
 *    natural contact callers opt in. Failed/gated/no-route work retains post-clear settlement.
 *    The choice is durable on owner resume and grants no hostile-room safety claim.
 *    minimumActors (NUMBER, default 1) requires 1..16 integer task-free actors before handoff.
 *    Natural contact requests 4; explicit/resume calls retain the historical default.
 *    contactBelief (default []) is [believed position AGL ARRAY, observed serverTime NUMBER].
 *    A finite hint inside the building and at most five seconds old seeds one floor route.
 *    Its timestamp survives adoption; it never supplies live target tracking or visit credit.
 *
 * Return Value:
 * Boolean - true when the order was applied or forwarded
 *
 * Example:
 * [group this, nearestBuilding this] call WAIT_fnc_CortexClearBuilding;
 * Result: an entry element attempts successive building positions; unreachable positions leave an INCOMPLETE result.
 *
 * Current callers: mission scripts, CortexOrderLocal and building-contact/locality continuation.
 * WAIT-owned garrison post holds may enter a new clear after physical validation; the handoff
 * restores those holds without injecting a JOIN recall ahead of the new building executor.
 * Expired episodes and changed resume-order receipts are rejected before garrison/defence
 * or autonomous-task handoff; late common-operation refusal remains separately handled.
 */

params [["_group", grpNull, [grpNull, objNull]], ["_target", objNull, [objNull, []]], ["_options", createHashMap, [createHashMap]]];
if (_group isEqualType objNull) then {_group = group _group};
if (isNull _group) exitWith {false};
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (!local _group) exitWith {
    if (isServer) then {[_group, _target, _options] remoteExecCall ["WAIT_fnc_CortexClearBuilding", groupOwner _group]; true} else {false};
};
private _refuse={
    params ["_reason"];
    private _actors=(units _group) select [0,16];
    private _evidence=[serverTime,_reason,groupOwner _group,_actors apply {
        [netId _x,currentCommand _x,getUnitState _x,local _x,isPlayer _x,
            _x checkAIFeature "MOVE",_x checkAIFeature "PATH",
            _x getVariable ["WAIT_Cortex_ActorMove",[]],
            [_x] call WAIT_fnc_CortexCombatEffective]
    }];
    _group setVariable ["WAIT_Cortex_ClearAdmissionFailure",_evidence,true];
    diag_log format ["WAIT CLEAR ADMISSION REFUSED: %1",_evidence];
    false
};
if !([_group] call WAIT_fnc_CortexIsEligible) exitWith {["GROUP_INELIGIBLE"] call _refuse};
if (_target isEqualType [] && {!(count _target in [2,3])
    || {_target findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}}) exitWith {["INVALID_TARGET_POSITION"] call _refuse};
private _building = if (_target isEqualType objNull) then {_target} else {nearestBuilding _target};
if (isNull _building) exitWith {if (_options getOrDefault ["resume", false]) then {[_group] call WAIT_fnc_CortexClearRelease}; ["TARGET_ABSENT"] call _refuse};
if (!alive _building) exitWith {["TARGET_DESTROYED"] call _refuse};
if !(missionNamespace getVariable ["WAIT_AIPass_Active", false]) exitWith {
    diag_log format ["[WAIT] %1 clear building refused: the Smart AI Pass is not running on this machine.", _group];
    false
};
private _allPositions = _building buildingPos -1;
if (count _allPositions > 512) exitWith {["POSITION_BUDGET_EXCEEDED"] call _refuse};
private _seenPositions=createHashMap;
private _positions = _allPositions select {
    private _position=_x;
    private _valid=_position isEqualType [] && {count _position == 3}
        && {_position findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {[AGLToASL _position,_seenPositions,0.5] call WAIT_fnc_PositionBucketAdmit};
    if (!_valid) exitWith {false};
    private _positionASL=AGLToASL _position;
    private _roofHits=lineIntersectsSurfaces [
        _positionASL vectorAdd [0,0,0.5],_positionASL vectorAdd [0,0,10],objNull,objNull,true,4,"GEOM","NONE"
    ];
    _roofHits findIf {(_x select 2) == _building || {(_x select 3) == _building}} >= 0
};
// Exposed posts remain garrison/transit candidates. A missing owned roof is not
// permission to advertise every model position as a verified interior room.
if (_positions isEqualTo []) exitWith {
    ["NO_VALID_ROOFED_POSITIONS"] call _refuse
};
private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
// Entry selection must use the same capable/task-free contract as casualty reserves.
// An unavailable actor must not consume a lane until the later callback discovers it.
// Only a short-lived recall issued by WAIT's own completed/released clear is replaceable.
// Native JOIN from another task remains protected; locality and leader changes revoke this receipt.
private _ownedRecall={
    params ["_actor","_clearGeneration"];
    private _recall=_actor getVariable ["WAIT_Cortex_ClearRecall",[]];
    currentCommand _actor == "JOIN" && {count _recall == 4}
        && {(_recall select 0) == _clearGeneration}
        && {(_recall select 1) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {(_recall select 2) == _leader} && {time < (_recall select 3)}
};
private _admissionGeneration=_group getVariable ["WAIT_AIPass_ClearGeneration",0];
private _previous = _group getVariable ["WAIT_AIPass_ClearOrder", []];
private _resume = _options getOrDefault ["resume", false] && {_previous isNotEqualTo []} && {(_previous select 0) == _building};
// An explicit new CLEAR may replace this addon's exact indoor actor jobs. Admission remains
// read-only: only the existing validated group handoff below retires those journals.
private _replaceIndoor=!_resume && {(_options getOrDefault ["preserveBrain",false]) isEqualTo false};
private _available = (units _group) select {
    private _posted=_x getVariable ["WAIT_AIPass_GarrisonPos",[]];
    private _ownedPost=(_group getVariable ["WAIT_AIPass_Garrison",[]]) isNotEqualTo []
        && {_group getVariable ["WAIT_AIPass_GarrisonApplied",false]}
        && {_x getVariable ["WAIT_AIPass_GarrisonDisabledPath",false]}
        && {!(_x checkAIFeature "PATH")} && {_posted isNotEqualTo []}
        && {currentCommand _x in ["","STOP","ATTACK","FIRE","SUPPRESS"]}
        && {[_x,_posted] call WAIT_fnc_CortexGarrisonArrived};
    private _canMove=_x checkAIFeature "MOVE" && {_x checkAIFeature "PATH" || {_ownedPost}};
    private _reservation=_x getVariable ["WAIT_Cortex_ActorMove",[]];
    private _reservationFree=!([_x] call WAIT_fnc_CortexActorMoveReserved);
    if (!_reservationFree && {_replaceIndoor}) then {
        private _indoor=_x getVariable ["WAIT_IndoorActor_Brain",createHashMap];
        private _journal=_x getVariable ["WAIT_IndoorActor_Order",[]];
        _reservationFree=count _indoor > 0 && {count _journal == 9}
            && {!(_indoor getOrDefault ["finished",true])}
            && {(_indoor getOrDefault ["group",grpNull]) == _group}
            && {(_indoor getOrDefault ["generation",-1]) == (_journal select 0)}
            && {(_indoor getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
            && {(_journal select 1) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
            && {(_journal select 2) == _group}
            && {(_journal select 7) isEqualTo _reservation}
            && {(_indoor getOrDefault ["lease",[]]) isEqualTo _reservation};
    };
    _canMove && {[_x] call WAIT_fnc_CortexCombatEffective} && {local _x} && {!isPlayer _x}
        && {isNull objectParent _x} && {_reservationFree}
        && {_resume || {simulationEnabled _x && {!isObjectHidden _x}}}
        && {isNull (remoteControlled _x)}
        && {([_x] call WAIT_fnc_CortexExternalOwner) == ""}
        && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])
            || {[_x,_admissionGeneration] call _ownedRecall}}
};
// Natural contact requires reserve strength beyond the pair. Validate its requested minimum
// against the real task-free roster, not preliminary live headcount, before any handoff.
// Explicit calls retain their historical default; resumes can continue with surviving actors.
private _minimumActors=_options getOrDefault ["minimumActors",1];
if (!(_minimumActors isEqualType 0) || {!finite _minimumActors}
    || {_minimumActors < 1} || {_minimumActors > 16} || {_minimumActors != floor _minimumActors}) exitWith {
    ["INVALID_ACTOR_MINIMUM"] call _refuse
};
if (count _available < _minimumActors) exitWith {["INSUFFICIENT_ELIGIBLE_ACTORS"] call _refuse};
// Existing intact eligible pairs retain admission priority; remaining actors fill capacity.
private _team = +_available;
if (_team isEqualTo []) exitWith {["NO_ELIGIBLE_ACTORS"] call _refuse};
// Keep enough distinct lanes for a real squad clear without crowding every reported room node.
// The roof filter can undercount valid interior lanes on some models, so capacity uses the full
// engine position set as well as squad strength. Admit the full capable squad within the
// eight-actor concurrent limit; do not silently reserve half of a clearing squad outside.
private _squadElement = count _available;
private _topologyElement = ((count _allPositions) max 2) min 8;
private _entryCapacity = ((2 max _squadElement) min _topologyElement) min 8;
_entryCapacity = _entryCapacity min (count _team);
// Prefer intact eligible buddies before applying concurrency capacity. Selection is
// read-only here; a refused start must not publish a new pairing receipt.
private _pairedAdmission=[];
private _remainingAdmission=+_team;
{
    if (_x isEqualType [] && {count _x == 2}) then {
        private _pair=(_x arrayIntersect _x) select {_x in _remainingAdmission};
        if (count _pair == 2) then {
            _pairedAdmission append _pair;
            _remainingAdmission=_remainingAdmission-_pair;
        };
    };
} forEach ((_group getVariable ["WAIT_CombatPairs",[]]) select [0,16]);
_team = (_pairedAdmission+_remainingAdmission) select [0,_entryCapacity];
// A one-time native belief may seed a floor's route, never track an unseen live target.
// Preserve the original timestamp across owner adoption; a stale hint is not renewed.
private _contactBelief=if (_resume) then {+(_previous param [11,[],[[]]])} else {_options getOrDefault ["contactBelief",[]]};
private _validBelief=_contactBelief isEqualType [] && {count _contactBelief == 2}
    && {(_contactBelief select 0) isEqualType []} && {count (_contactBelief select 0) == 3}
    && {(_contactBelief select 0) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {(_contactBelief select 1) isEqualType 0} && {finite (_contactBelief select 1)}
    && {serverTime-(_contactBelief select 1) >= 0} && {serverTime-(_contactBelief select 1) <= 5};
if (_validBelief) then {
    private _bounds=boundingBoxReal _building;
    private _model=_building worldToModelVisual (_contactBelief select 0);
    private _low=_bounds select 0;private _high=_bounds select 1;
    _validBelief=(_model select 0) >= (_low select 0)-1 && {(_model select 0) <= (_high select 0)+1}
        && {(_model select 1) >= (_low select 1)-1} && {(_model select 1) <= (_high select 1)+1}
        && {(_model select 2) >= (_low select 2)-1} && {(_model select 2) <= (_high select 2)+1};
};
if (!_validBelief) then {_contactBelief=[]} else {_contactBelief=[+(_contactBelief select 0),_contactBelief select 1]};
private _baseBehaviour = if (_previous isEqualTo []) then {behaviour _leader} else {_previous select 3};
private _cleared = if (_resume) then {+(_previous select 1)} else {[]};
private _unreachable = if (_resume) then {+(_previous param [4, []])} else {[]};
private _retryCounts = if (_resume) then {+(_previous param [5, []])} else {[]};
private _failedBy = if (_resume) then {+(_previous param [6, _positions apply {[]}])} else {_positions apply {[]}};
if (count _failedBy != count _positions) then {_failedBy = _positions apply {[]}};
private _lastProgressAt = if (_resume) then {_previous param [7,serverTime]} else {serverTime};
private _deadline = if (_resume) then {_previous select 2} else {serverTime + 240};
// Genuine approach progress may renew the stall lease, but never the episode lifetime.
// Retain the absolute server-clock boundary across HC resume; legacy orders keep their
// already published deadline rather than gaining a fresh lifetime on each owner.
private _lifetime = (240 max (60*count _positions)) min 900;
private _hardDeadline = if (_resume) then {_previous param [10,_deadline,[0]]} else {serverTime+_lifetime};
if (serverTime >= (_deadline min _hardDeadline)) exitWith {[_group] call WAIT_fnc_CortexClearRelease; false};
// Replacing a clear must retire its engine movement orders as well as its queued job.
// Validate the new building/team first; an invalid request must preserve the current order.
// HC resume keeps the published progress/deadline rather than starting a new episode.
if (!_resume && {_previous isNotEqualTo []}) then {[_group] call WAIT_fnc_CortexClearRelease};
private _baseAttack=if (_resume) then {_previous param [8,attackEnabled _leader,[true]]} else {attackEnabled _leader};
private _nativeOrderReceipt=[_group] call WAIT_fnc_NativeOrderReceipt;
if (_resume && {(_previous param [9,_nativeOrderReceipt,[[]]]) isNotEqualTo _nativeOrderReceipt}) exitWith {
    [_group,false] call WAIT_fnc_CortexClearRelease;
    false
};

// Complete resume/deadline validation before releasing another explicit task.
// This final eligibility preflight matches the common operation's admission gate.
if !([_group,false,false,true] call WAIT_fnc_CortexIsEligible) exitWith {["GROUP_INELIGIBLE"] call _refuse};
private _preserveBrain=_options getOrDefault ["preserveBrain",false];
private _continueRoute=if (_resume) then {_previous param [12,false,[true]]} else {_options getOrDefault ["continueRoute",false]};
if (!(_continueRoute isEqualType true)) exitWith {["INVALID_CONTINUATION"] call _refuse};
if (_preserveBrain) then {
    private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
    if (count (_state getOrDefault ["drill",createHashMap]) > 0) then {
        [_group,_state,"BUILDING_CONTACT"] call WAIT_fnc_CortexFlankEnd;
    };
    [_group] call WAIT_fnc_CortexGroupMoveClear;
} else {
    [_group,false] call WAIT_fnc_CortexReleaseGroup;
};
if ((_group getVariable ["WAIT_AIPass_Garrison", []]) isNotEqualTo []) then {[_group,true,[],false] call WAIT_fnc_CortexGarrisonRelease};
if ((_group getVariable ["WAIT_AIPass_Defend", []]) isNotEqualTo []) then {[_group,false,false] call WAIT_fnc_CortexDefendRelease};
// General cleanup may remove WAIT-authored native waypoints. Receipt the resulting
// order only after this authorized handoff, never mistake our cleanup for a later edit.
_nativeOrderReceipt=[_group] call WAIT_fnc_NativeOrderReceipt;
// A fresh clear borrows the restored task baseline, not a garrison/defence-applied hold.
// A true resume retains its original reversible policy across owners.
if (!_resume) then {_baseAttack=attackEnabled _leader};
if (_previous isEqualTo []) then {_baseBehaviour=behaviour _leader};
_group setVariable ["WAIT_Cortex_ClearAdmissionFailure",nil,true];
_group setVariable ["WAIT_AIPass_ClearOrder", [_building, _cleared, _deadline, _baseBehaviour, _unreachable, _retryCounts, _failedBy, _lastProgressAt, _baseAttack, _nativeOrderReceipt, _hardDeadline, _contactBelief, _continueRoute], true];
_group setVariable ["WAIT_AIPass_ClearApplied", true];
_group setVariable ["WAIT_Cortex_ClearResult",["RUNNING",count _cleared,count _positions],true];
_group setVariable ["WAIT_Cortex_ClearEvidence",nil,true];
_group setVariable ["WAIT_Cortex_ClearReinforcements",[],true];
// This compact snapshot changes only at setup, material room/retry progress or egress. It gives
// diagnostics a live view without publishing each local pair movement or destination.
_group setVariable ["WAIT_Cortex_ClearStatus",["ENTRY",count _cleared,count _unreachable,count _positions,0,serverTime],true];
private _generation = (_group getVariable ["WAIT_AIPass_ClearGeneration", 0]) + 1;
_group setVariable ["WAIT_AIPass_ClearGeneration", _generation];
private _operation=[_group,"CLEAR",_building,_team,_positions,"ENTRY"] call WAIT_fnc_OperationStart;
if (count _operation == 0) exitWith {
    ["OPERATION_REFUSED"] call _refuse;
    // A refused operation has no worker. Retire only this attempted generation's public
    // order so discovery cannot resurrect it after a newer owner/task has taken over.
    if ((_group getVariable ["WAIT_AIPass_ClearGeneration",-1]) == _generation) then {
        _group setVariable ["WAIT_AIPass_ClearOrder",nil,true];
        _group setVariable ["WAIT_AIPass_ClearApplied",nil];
        _group setVariable ["WAIT_Cortex_ClearStatus",nil,true];
        _group setVariable ["WAIT_Cortex_ClearResult",["CANCELLED",count _cleared,count _positions],true];
    };
    false
};
// A valid new operation now owns the selected actors. Retire only its predecessor's
// matching recall so the initial building step sees STOP instead of protected JOIN.
{
    if ([_x,_generation-1] call _ownedRecall && {local _x} && {!isPlayer _x}
        && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}) then {
        doStop _x;
        _x setVariable ["WAIT_Cortex_ClearRecall",nil];
    };
} forEach _team;
// Capture admitted native intent before entry/topology planning can delay the first reserve step.
private _reserveAdmissionRows=[];
if (!_resume) then {
    _reserveAdmissionRows=(_available select [0,64]) apply {
        [_x,toUpperANSI currentCommand _x,
            (expectedDestination _x) apply {if (_x isEqualType []) then {+_x} else {_x}},formLeader _x]
    };
};
// Suppress only competing autonomous group attack assignment during the clear. Native
// targeting, weapons and suppression remain enabled. Mixed specialist/player groups retain
// their command policy; only ordinary groups acquire this exact-owned reversible setting.
private _delegationMembers=units _group;
if (count _delegationMembers <= 64
    && {_delegationMembers findIf {isPlayer _x || {[_x] call WAIT_fnc_CompatibilityExternalControl}} < 0}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
    && {((_group getVariable ["WAIT_Operation",createHashMap]) getOrDefault ["generation",-1]) == (_operation get "generation")}
    && {(_operation get "ownerEpoch") == (_group getVariable ["WAIT_AIPass_Epoch",0])}) then {
    (_operation get "restore") set ["groupAttack",[_baseAttack,false]];
    _group setVariable ["WAIT_Operation",_operation,true];
    _group enableAttack false;
};
// Initial owner adoption may reset replay markers; this successfully created job now owns them.
_group setVariable ["WAIT_AIPass_ClearApplied",true];
private _operationGeneration=_operation get "generation";
_group setVariable ["WAIT_AIPass_ClearBuilding", true, true];
private _entries=[];
private _securityEntries=[];
for "_exitIndex" from 0 to 15 do {
    private _candidate=_building buildingExit _exitIndex;
    // Model exit nodes can be buried below terrain after placement. Do not
    // make one an obligatory recovery destination or flatten it into a fake exit.
    private _candidateASL=AGLToASL _candidate;
    private _aboveTerrain=(_candidateASL select 2) >= (getTerrainHeightASL _candidate)-0.05;
    if (_candidate isNotEqualTo [0,0,0] && {_candidate distance2D _building < 50}
        && {_aboveTerrain}
        && {_entries findIf {_x distance2D _candidate < 1} < 0}) then {
        _entries pushBack _candidate;
    };
};
if (_entries isNotEqualTo []) then {
    private _entryOrigin=getPosATL _leader;
    _entries=[_entries,[],{_x distance2D _entryOrigin},"ASCEND"] call BIS_fnc_sortBy;
    // Interior entry remains bounded to four nearby choices. Exterior observation must
    // retain the other native exits already discovered, rather than silently dropping them.
    _securityEntries=+_entries;
    _entries resize ((count _entries) min 4);
};
private _entryRoute=if (_entries isEqualTo []) then {[]} else {
    private _centroid=[0,0,0];
    {_centroid=_centroid vectorAdd getPosATL _x} forEach _team;
    _centroid=_centroid vectorMultiply (1/(count _team));
    private _ranked=_entries apply {[_centroid distance2D _x,_x]};
    _ranked sort true;
    +((_ranked select 0) select 1)
};
// Build a stable continuous route rather than repeatedly choosing whichever marker is nearest
// to each individual. This prevents criss-crossing and gives every pair a clear-through sector.
private _routeOrder=[];
// Snapshot absolute heights once. Repeated remaining-node scans are array arithmetic,
// not repeated terrain-frame engine conversions for every route step (up to 512 nodes).
private _positionHeights=_positions apply {(AGLToASL _x) select 2};
private _beliefHeight=if (_contactBelief isEqualTo []) then {0} else {(AGLToASL (_contactBelief select 0)) select 2};
private _beliefSeeded=false;
private _retiredIndices=_cleared+_unreachable;
private _remaining=[];
for "_index" from 0 to ((count _positions)-1) do {
    if !(_index in _retiredIndices) then {_remaining pushBack _index};
};
private _routeCursor=if (_entryRoute isEqualTo []) then {getPosATL _building} else {_entryRoute};
while {_remaining isNotEqualTo []} do {
    private _lowest=1e9;
    {private _height=_positionHeights select _x; if (_height < _lowest) then {_lowest=_height}} forEach _remaining;
    private _floorCandidates=_remaining select {abs ((_positionHeights select _x)-_lowest) < 1.8};
    private _selectionOrigin=_routeCursor;
    if (!_beliefSeeded && {_contactBelief isNotEqualTo []}
        && {_floorCandidates findIf {abs ((_positionHeights select _x)-_beliefHeight) <= 1.5} >= 0}) then {
        _selectionOrigin=_contactBelief select 0;
        _beliefSeeded=true;
    };
    private _bestSlot=0;
    private _bestDistance=1e9;
    {
        private _distance=_selectionOrigin distance2D (_positions select _x);
        if (_distance < _bestDistance) then {_bestSlot=_remaining find _x; _bestDistance=_distance};
    } forEach _floorCandidates;
    private _positionIndex=_remaining deleteAt _bestSlot;
    _routeOrder pushBack _positionIndex;
    _routeCursor=_positions select _positionIndex;
};
// A lead/security pair keeps small clears from assigning the sole reachable room to one soldier while
// every other member waits outside. Larger squads still receive several independent lanes, each with
// a trailing security partner and its own claimed room route. Shared queue and failure evidence prevent
// lanes from crowding the same room.
private _pairs=[_group,_team] call WAIT_fnc_CombatPairs;
private _pairRoutes=_pairs apply {[]};
private _pending=+_routeOrder;
private _pairStates=[];
// Avoid turning a multi-lane clear into a queue at one doorway. Each pair initially claims a
// distinct real entrance where possible; only when there are more pairs than entrances do later
// pairs reuse the nearest entry. Retry logic below still selects another entrance after a real
// path failure, so this is dispersion rather than a permanent door reservation.
private _claimedEntryIndices=[];
{
    private _pair=_x;
    private _pairLead=_pair select 0;
    private _entryIndex=-1;
    if (_entries isNotEqualTo []) then {
        private _ranked=[];
        {_ranked pushBack [_pairLead distance2D _x,_forEachIndex]} forEach _entries;
        _ranked sort true;
        private _unclaimed=_ranked select {!((_x select 1) in _claimedEntryIndices)};
        private _choice=if (_unclaimed isEqualTo []) then {_ranked} else {_unclaimed};
        _entryIndex=(_choice select 0) select 1;
        _claimedEntryIndices pushBackUnique _entryIndex;
    };
    _pairStates pushBack [0,false,_pair apply {getPosATL _x},time,0,-1,
        time+(_forEachIndex*1.25),0,-1,_entryIndex,[],0,false];
} forEach _pairs;
_group setVariable ["WAIT_Cortex_ClearStatus",["ENTRY",count _cleared,count _unreachable,count _positions,count _pairs,serverTime],true];
private _job=createHashMapFromArray [
    ["group", _group], ["team", _team], ["started", []], ["positions", _positions], ["navigationPositions",+_allPositions], ["transitPositions",_allPositions select {!(_x in _positions)}], ["cleared", _cleared], ["building", _building], ["assigned", _team apply {[]}], ["unreachable",_unreachable], ["retryCounts",_retryCounts],
    ["entry",_entryRoute], ["entries",_entries], ["securityEntries",_securityEntries], ["pairs",_pairs], ["pairRoutes",_pairRoutes], ["pairStates",_pairStates], ["pending",_pending],
    ["deadline", _deadline], ["hardDeadline",_hardDeadline], ["baseBehaviour", _baseBehaviour], ["baseAttack",_baseAttack], ["generation", _generation], ["operationGeneration",_operationGeneration], ["failedBy",_failedBy], ["lastProgressAt",_lastProgressAt], ["visitCursor",0],
    ["continueRoute",_continueRoute],["contactBelief",_contactBelief],["nativeOrderReceipt",_nativeOrderReceipt],["buildingTransform",[getPosWorld _building,vectorDir _building,vectorUp _building]],["phase","ENTRY"],["rotatedOut",[]],["egressAssignments",[]],["egressDeadline",0],["egressProgress",[]],["egressFailed",false]
];
// Historical individual visits survive owner adoption. A fresh task gets a new token,
// even if it targets the same building in the same server frame. No movement is replayed.
private _visitContext=_group getVariable ["WAIT_Cortex_ClearVisitContext",[]];
private _visitBase=[_building,_job get "buildingTransform",_hardDeadline];
if (!_resume || {!(_visitContext isEqualType [])} || {count _visitContext != 4} || {(_visitContext select [0,3]) isNotEqualTo _visitBase}) then {
    _visitContext=_visitBase+[format ["%1:%2:%3",clientOwner,diag_tickTime,_generation]];
    _group setVariable ["WAIT_Cortex_ClearVisitContext",_visitContext,true];
};
_job set ["visitContext",+_visitContext];
// Bind delayed reserve admission to this exact episode, not the first staging callback.
// Native FOLLOW position may change with its same formation leader; that identity is retained.
private _reserveAdmission=_group getVariable ["WAIT_Cortex_ClearReserveAdmission",[]];
if (!_resume) then {
    _reserveAdmission=[+_visitContext,_reserveAdmissionRows];
    _group setVariable ["WAIT_Cortex_ClearReserveAdmission",_reserveAdmission,true];
};
private _reserveAdmissionCommands=createHashMap;
if (_reserveAdmission isEqualType [] && {count _reserveAdmission == 2}
    && {(_reserveAdmission select 0) isEqualTo _visitContext}
    && {(_reserveAdmission select 1) isEqualType []} && {count (_reserveAdmission select 1) <= 64}) then {
    {
        if (_x isEqualType [] && {count _x == 4} && {(_x select 0) isEqualType objNull}
            && {(_x select 1) isEqualType ""} && {(_x select 2) isEqualType []}
            && {(_x select 3) isEqualType objNull}) then {
            _reserveAdmissionCommands set [netId (_x select 0),+_x];
        };
    } forEach (_reserveAdmission select 1);
};
_job set ["reserveAdmissionCommands",_reserveAdmissionCommands];
private _actorVisits=createHashMap;
private _enteredActors=[];
if (_resume) then {
    {
        private _actor=_x;
        private _receipt=_actor getVariable ["WAIT_Cortex_ClearVisits",[]];
        if (_receipt isEqualType [] && {count _receipt == 3} && {(_receipt select 0) isEqualTo _group}
            && {(_receipt select 1) isEqualTo _visitContext}
            && {(_receipt select 2) isEqualType []} && {count (_receipt select 2) <= 512}) then {
            private _visited=[];
            {
                if (_x isEqualType [] && {count _x == 2}) then {
                    private _index=_x select 0;
                    if (_index isEqualType 0 && {finite _index} && {_index == floor _index}
                        && {_index >= 0} && {_index < count _positions} && {_index in _cleared}
                        && {(_x select 1) isEqualTo (_positions select _index)}) then {
                        _visited pushBackUnique _index;
                    };
                };
            } forEach (_receipt select 2);
            if (_visited isNotEqualTo []) then {
                _actorVisits set [netId _actor,_visited];
                _enteredActors pushBack _actor;
            };
        };
    } forEach (_team select [0,8]);
};
_job set ["actorVisits",_actorVisits];
_job set ["enteredActors",_enteredActors];
// Early exits remain part of this episode even while other workers sweep.
// Adopt bookkeeping only when the exact native leg or a physical arrival is still ours.
private _earlyReceipt=_group getVariable ["WAIT_Cortex_ClearEarlyExits",[]];
if (!_resume) then {_group setVariable ["WAIT_Cortex_ClearEarlyExits",nil,true]};
if (_resume && {_earlyReceipt isEqualType []} && {count _earlyReceipt == 2}
    && {(_earlyReceipt select 0) isEqualTo _visitContext}
    && {(_earlyReceipt select 1) isEqualType []} && {count (_earlyReceipt select 1) <= 8}) then {
    private _early=createHashMap;
    private _moves=_job getOrDefault ["movementTargets",createHashMap];
    private _diverted=[];
    {
        if (_x isEqualType [] && {count _x in [4,5,7]}) then {
            _x params ["_actor","_target","_until","_state",["_retryUsed",false],["_entry",[]],["_watch",[]]];
            if (_actor isEqualType objNull && {!isNull _actor} && {_actor in _team}
                && {_target isEqualType []} && {count _target == 3}
                && {_target findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {_until isEqualType 0} && {finite _until}
                && {_retryUsed isEqualType true}
                && {_entry isEqualType []} && {_watch isEqualType []}
                && {(_entry isEqualTo [] && {_watch isEqualTo []}) || {
                    count _entry == 3 && {count _watch == 3}
                        && {(_entry+_watch) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                        && {_entry in _entries}
                }}
                && {_state in ["MOVING","ARRIVED","FAILED","DIVERTED"]}) then {
                private _live=(expectedDestination _actor) param [0,[]];
                private _owned=currentCommand _actor == "MOVE" && {count _live == 3} && {_live vectorDistance _target <= 0.25};
                private _held=currentCommand _actor in ["","STOP"]
                    && {(getPosASL _actor) vectorDistance (AGLToASL _target) <= 1};
                if (_state == "DIVERTED" || {!(_owned || {_held})}) then {
                    _state="DIVERTED";
                    _diverted pushBackUnique _actor;
                    _job set ["egressFailed",true];
                } else {
                    _moves set [netId _actor,+_target];
                    if (_state == "ARRIVED" && {!_held}) then {_state="MOVING"};
                    if (_state == "FAILED") then {_job set ["egressFailed",true]};
                };
                _early set [netId _actor,[_actor,+_target,_until,_state,_retryUsed,+_entry,+_watch]];
            };
        };
    } forEach (_earlyReceipt select 1);
    _job set ["earlyExits",_early];
    _job set ["movementTargets",_moves];
    _job set ["egressDiverted",_diverted];
};
// Adopt a transform/episode-bound exit journal without issuing movement. A different
// native destination owns the actor now and must not inherit an old exit receipt.
private _egressJournal=_group getVariable ["WAIT_Cortex_ClearEgress",[]];
if (!_resume) then {_group setVariable ["WAIT_Cortex_ClearEgress",nil,true]};
if (_resume && {count _egressJournal in [10,13]} && {(_egressJournal select 0) == "EGRESS"}
    && {(_egressJournal select 4) == _building}
    && {(_egressJournal select 5) isEqualTo (_job get "buildingTransform")}
    && {(_egressJournal select 6) == _hardDeadline}
    && {(_egressJournal select 7) isEqualType 0} && {finite (_egressJournal select 7)}
    && {count (_egressJournal select 3) <= 8}
    && {count _egressJournal == 10 || {(_egressJournal select 10) isEqualTo 2
        && {(_egressJournal select 11) isEqualType []} && {(_egressJournal select 12) isEqualType []} && {count (_egressJournal select 12) <= 4}
        && {count (_egressJournal select 11)+count (_egressJournal select 3) <= 8}}}) then {
    private _assignments=[];
    private _records=[];
    private _moves=createHashMap;
    private _failed=(_egressJournal select 8) || {_job getOrDefault ["egressFailed",false]};
    {
        if (_x isEqualType [] && {count _x == 6}) then {
            _x params ["_actor","_target","_arrived","_leg","_retries","_checkpoint"];
            private _live=(expectedDestination _actor) param [0,[]];
            private _atTarget=count _target == 3
                && {(getPosASL _actor) vectorDistance (AGLToASL _target) <= 1}
                && {abs (((getPosATL _actor) select 2)-(_target select 2)) <= 1.5};
            private _ownsLeg=currentCommand _actor == "MOVE" && {count _leg == 3}
                && {count _live == 3} && {_live vectorDistance _leg <= 0.25};
            private _holdsArrival=_arrived && {_atTarget} && {currentCommand _actor in ["","STOP"]};
            if (_actor in _available && {group _actor == _group}
                && {(_assignments apply {_x select 0}) findIf {_x == _actor} < 0}
                && {count _target == 3} && {_ownsLeg || {_holdsArrival}}) then {
                _assignments pushBack [_actor,+_target,_holdsArrival];
                _moves set [netId _actor,+_leg];
                private _routeTarget=if (_checkpoint isEqualTo []) then {_target} else {_checkpoint};
                _records pushBack [_actor,(getPosATL _actor) vectorDistance _routeTarget,time,
                    (_retries max 0) min 1,+_checkpoint,time,getPosASL _actor];
            } else {_failed=true};
        } else {_failed=true};
    } forEach (_egressJournal select 3);
    // Version 2 appends pending native-leg receipts and bounded entrance-use counts.
    // Legacy ten-field journals have no pending work. Adoption never issues movement.
    private _pending=[];
    private _uses=createHashMap;
    if (count _egressJournal == 13) then {
        {
            if (_x isEqualType [] && {count _x == 2}
                && {(_x select 0) isEqualType objNull} && {(_x select 1) isEqualType []}
                && {count (_x select 1) in [0,3]}
                && {(_x select 1) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}) then {
                _x params ["_actor","_leg"];
                private _live=(expectedDestination _actor) param [0,[]];
                private _owned=currentCommand _actor in ["","STOP"]
                    || {currentCommand _actor == "MOVE" && {_leg isEqualType []} && {count _leg == 3}
                        && {count _live == 3} && {_live vectorDistance _leg <= 0.25}};
                if (_actor in _available && {group _actor == _group} && {_leg isEqualType []}
                    && {_owned} && {!(_actor in ((_assignments+_pending) apply {_x select 0}))}) then {
                    _pending pushBack [_actor,+_leg];
                    _moves set [netId _actor,+_leg];
                } else {_failed=true};
            } else {_failed=true};
        } forEach (_egressJournal select 11);
        {
            if (_x isEqualType [] && {count _x == 2}
                && {(_x select 0) isEqualType ""} && {(_x select 1) isEqualType 0}
                && {finite (_x select 1)} && {(_x select 1) >= 0} && {(_x select 1) <= 8}) then {
                _uses set [_x select 0,_x select 1];
            } else {_failed=true};
        } forEach ((_egressJournal select 12) select [0,4]);
    };
    if (_assignments isEqualTo [] && {_pending isEqualTo []}) then {_failed=true};
    _job set ["egressPending",_pending];
    _job set ["egressExitUses",_uses];
    _job set ["phase","EGRESS"];
    _team=(_assignments+_pending) apply {_x select 0};
    _job set ["team",_team];
    _job set ["egressAssignments",_assignments];
    _job set ["egressProgress",_records];
    _job set ["movementTargets",_moves];
    _job set ["egressDeadlineServer",_egressJournal select 7];
    _job set ["egressStartedServer",_egressJournal select 2];
    _job set ["egressDeadline",time+(((_egressJournal select 7)-serverTime) max 0)];
    _job set ["egressFailed",_failed];
    _job set ["entryFailed",_egressJournal select 9];
    _operation set ["participantPlatforms",createHashMapFromArray (_team apply {[netId _x,_x]})];
    _operation set ["participants",+_team];
    _operation set ["participantProgress",_team apply {[_x,getPosATL _x]}];
    _operation set ["phase","EGRESS"];
    _group setVariable ["WAIT_Operation",_operation,true];
    _group setVariable ["WAIT_Cortex_ClearStatus",["EGRESS",count _cleared,count _unreachable,count _positions,count _pairs,serverTime],true];
    diag_log format ["WAIT CLEAR EGRESS ADOPTED: %1",[_generation,count _assignments,_failed,_egressJournal select 7]];
};
// Keep reserve search consumption across a true resume, independently of local handles.
// Durable failed follow-through targets are bookkeeping, never movement/entry receipts.
private _followBudget=_group getVariable ["WAIT_Cortex_ClearFollowBudget",[]];
if (!_resume) then {_group setVariable ["WAIT_Cortex_ClearFollowBudget",nil,true]};
if (_resume && {count _followBudget == 4} && {(_followBudget select 0) == _building}
    && {(_followBudget select 1) == _hardDeadline}
    && {(_followBudget select 2) isEqualTo (_job get "buildingTransform")}) then {
    private _failures=createHashMap;
    private _exhausted=[];
    private _actors=createHashMap;
    {_actors set [netId _x,_x]} forEach ((units _group) select [0,64]);
    {
        private _row=_x;
        if (_row isEqualType [] && {count _row == 3}
            && {(_row select 0) isEqualType ""} && {(_row select 1) isEqualType []}
            && {(_row select 2) isEqualType true}) then {
            private _key=_row select 0;
            private _indices=_row select 1;
            private _actor=_actors getOrDefault [_key,objNull];
            if (!isNull _actor && {count _indices <= 3}
                && {_indices findIf {!(_x isEqualType 0) || {!finite _x}
                    || {_x < 0} || {_x >= count _positions} || {_x != floor _x}} < 0}) then {
                _failures set [_key,+_indices];
                if (_row select 2) then {_exhausted pushBackUnique _actor};
            };
        };
    } forEach ((_followBudget select 3) select [0,64]);
    _job set ["followThroughFailures",_failures];
    _job set ["followThroughExhausted",_exhausted];
};
private _stageBudget=_group getVariable ["WAIT_Cortex_ClearStageBudget",[]];
if (!_resume) then {_group setVariable ["WAIT_Cortex_ClearStageBudget",nil,true]};
if (_resume && {count _stageBudget == 4} && {(_stageBudget select 0) == _building}
    && {(_stageBudget select 1) == _hardDeadline}
    && {(_stageBudget select 2) isEqualTo (_job get "buildingTransform")}) then {
    private _counts=createHashMap;
    private _tried=createHashMap;
    private _triedEntries=createHashMap;
    private _stages=createHashMap;
    private _moves=_job getOrDefault ["movementTargets",createHashMap];
    private _actors=createHashMap;
    {_actors set [netId _x,_x]} forEach ((units _group) select [0,64]);
    {
        _x params ["_key","_count","_targets",["_stage",[]],["_entryHistory",[]]];
        _counts set [_key,(_count max 0) min 3];
        _tried set [_key,+(_targets select [0,6])];
        _triedEntries set [_key,+(_entryHistory select [0,3])];
        private _actor=_actors getOrDefault [_key,objNull];
        if (count _stage in [4,7] && {(_stage select 2) in ["APPROACH","ARRIVED","REJECTED","EXHAUSTED"]}
            && {!isNull _actor} && {local _actor} && {!isPlayer _actor} && {!(_actor in _team)}
            && {[_actor] call WAIT_fnc_CortexCombatEffective} && {isNull objectParent _actor}
            && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
            && {isNull remoteControlled _actor}
            && {([_actor] call WAIT_fnc_CortexExternalOwner) == ""}
            && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}
            && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
            && {((_stage select 2) == "APPROACH" && {currentCommand _actor == "MOVE"})
                || {(_stage select 2) != "APPROACH" && {currentCommand _actor == "STOP"}
                    && {count (_stage select 0) == 3}
                    && {(getPosASL _actor) vectorDistance (AGLToASL (_stage select 0)) <= 2}
                    && {abs (((getPosASL _actor) select 2)-((AGLToASL (_stage select 0)) select 2)) <= 0.75}}}) then {
            private _target=_stage select 0;
            private _live=(expectedDestination _actor) param [0,[]];
            if (count _target == 3 && {
                (_stage select 2) != "APPROACH"
                    || {count _live == 3 && {_live vectorDistance _target <= 0.25}}
            }) then {
                // Adopt bookkeeping only: an approach retains its exact engine route.
                // A stopped physical arrival has no live MOVE endpoint to compare.
                _stages set [_key,+_stage];
                _moves set [_key,+_target];
                _actor setVariable ["WAIT_Cortex_ClearReserve",[_generation,_group getVariable ["WAIT_AIPass_Epoch",0],+_target]];
            };
        };
    } forEach ((_stageBudget select 3) select [0,64]);
    _job set ["reserveStageSearchCounts",_counts];
    _job set ["reserveStageTriedTargets",_tried];
    _job set ["reserveStageTriedEntries",_triedEntries];
    _job set ["reserveStages",_stages];
    _job set ["movementTargets",_moves];
    _job set ["securityActors",(units _group) select {netId _x in _stages}];
};
[_job] call WAIT_fnc_BuildingOperationStart;
diag_log format ["[WAIT] %1 clearing %2 (%3 positions, %4 soldiers, %5 entrances)", _group, typeOf _building, count _positions, count _team, count _entries];
true

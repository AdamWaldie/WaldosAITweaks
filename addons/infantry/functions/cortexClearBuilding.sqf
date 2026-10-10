/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Orders an AI group to clear a building room by room.
 *
 * A squad-aware interior element, including the leader when needed, joins the clear up to a bounded
 * capacity. Each interior lane has a lead and security partner, receives a distinct viable entrance
 * where the topology provides one, then draws the nearest unclaimed room from a
 * shared low-floor-first queue. Only roofed interior positions are clearance objectives; exposed
 * balconies and roof posts belong to garrisoning. This avoids a support partner waiting outside while only one soldier
 * attempts every room, and makes a large squad flow through the building instead of parking around it.
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
 * Review contract: Local job generations prevent replaced jobs from issuing orders. Eligibility is checked before dispatch and on each step. Public visited and unreachable position indices, retry/failure evidence, progress-renewed deadline and original behaviour survive handover; local movement assignments are rebuilt.
 *
 * Arguments:
 * 0: group <GROUP or OBJECT> - the group, or a unit in it
 * 1: target <OBJECT or ARRAY> - the building, or a position (the nearest building is used)
 * 2: options <HASHMAP> (optional) - resume (default false), preserveBrain (default false for an
 *    explicit order) and operation-specific controls. Natural contact entry uses preserveBrain so
 *    live fire control and contact transitions continue around the single building movement owner.
 *
 * Return Value:
 * Boolean - true when the order was applied or forwarded
 *
 * Example:
 * [group this, nearestBuilding this] call WAIT_fnc_CortexClearBuilding;
 * Result: an entry element attempts successive building positions; unreachable positions leave an INCOMPLETE result.
 *
 * Current callers: mission scripts and the AI Orders ZEN module.
 */

params [["_group", grpNull, [grpNull, objNull]], ["_target", objNull, [objNull, []]], ["_options", createHashMap, [createHashMap]]];
if (_group isEqualType objNull) then {_group = group _group};
if (isNull _group) exitWith {false};
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (!local _group) exitWith {
    if (isServer) then {[_group, _target, _options] remoteExecCall ["WAIT_fnc_CortexClearBuilding", groupOwner _group]; true} else {false};
};
if !([_group] call WAIT_fnc_CortexIsEligible) exitWith {false};
private _building = if (_target isEqualType objNull) then {_target} else {nearestBuilding _target};
if (isNull _building) exitWith {if (_options getOrDefault ["resume", false]) then {[_group] call WAIT_fnc_CortexClearRelease}; false};
if !(missionNamespace getVariable ["WAIT_AIPass_Active", false]) exitWith {
    diag_log format ["[WAIT] %1 clear building refused: the Smart AI Pass is not running on this machine.", _group];
    false
};
private _allPositions = _building buildingPos -1;
private _positions = _allPositions select {
    private _positionASL=AGLToASL _x;
    (lineIntersectsSurfaces [_positionASL vectorAdd [0,0,0.5],_positionASL vectorAdd [0,0,10],objNull,objNull,true,1]) isNotEqualTo []
};
if (_positions isEqualTo []) then {_positions=+_allPositions};
if (_positions isEqualTo []) exitWith {false};
private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
// Entry selection must use the same capable/task-free contract as casualty reserves.
// An unavailable actor must not consume a lane until the later callback discovers it.
private _available = (units _group) select {
    private _canMove=_x checkAIFeature "MOVE" && {_x checkAIFeature "PATH"};
    private _reservation=_x getVariable ["WAIT_Cortex_ActorMove",[]];
    private _reservationFree=_reservation isEqualTo []
        || {_reservation isEqualType [] && {count _reservation == 3} && {(_reservation param [2,1e12,[0]]) <= time}};
    _canMove && {[_x] call WAIT_fnc_CortexCombatEffective} && {local _x} && {!isPlayer _x}
        && {isNull objectParent _x} && {_reservationFree}
        && {isNull (remoteControlled _x)}
        && {([_x] call WAIT_fnc_CortexExternalOwner) == ""}
        && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
private _team = +_available;
if (_team isEqualTo []) exitWith {false};
// Keep enough distinct lanes for a real squad clear without crowding every reported room node.
// The roof filter can undercount valid interior lanes on some models, so capacity uses the full
// engine position set as well as squad strength. The remainder stays available as a casualty reserve.
private _squadElement = ceil ((count _available) / 2);
private _topologyElement = ((count _allPositions) max 2) min 8;
private _entryCapacity = ((2 max _squadElement) min _topologyElement) min 8;
_entryCapacity = _entryCapacity min (count _team);
_team = _team select [0,_entryCapacity];
private _preserveBrain=_options getOrDefault ["preserveBrain",false];
if (_preserveBrain) then {
    private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
    if (count (_state getOrDefault ["drill",createHashMap]) > 0) then {
        [_group,_state,"BUILDING_CONTACT"] call WAIT_fnc_CortexFlankEnd;
    };
    [_group] call WAIT_fnc_CortexGroupMoveClear;
} else {
    [_group,false] call WAIT_fnc_CortexReleaseGroup;
};
if ((_group getVariable ["WAIT_AIPass_Garrison", []]) isNotEqualTo []) then {[_group] call WAIT_fnc_CortexGarrisonRelease};
if ((_group getVariable ["WAIT_AIPass_Defend", []]) isNotEqualTo []) then {[_group] call WAIT_fnc_CortexDefendRelease};
private _previous = _group getVariable ["WAIT_AIPass_ClearOrder", []];
private _resume = _options getOrDefault ["resume", false] && {_previous isNotEqualTo []} && {(_previous select 0) == _building};
private _baseBehaviour = if (_previous isEqualTo []) then {behaviour _leader} else {_previous select 3};
private _cleared = if (_resume) then {+(_previous select 1)} else {[]};
private _unreachable = if (_resume) then {+(_previous param [4, []])} else {[]};
private _retryCounts = if (_resume) then {+(_previous param [5, []])} else {[]};
private _failedBy = if (_resume) then {+(_previous param [6, _positions apply {[]}])} else {_positions apply {[]}};
if (count _failedBy != count _positions) then {_failedBy = _positions apply {[]}};
private _lastProgressAt = if (_resume) then {_previous param [7,serverTime]} else {serverTime};
private _deadline = if (_resume) then {_previous select 2} else {serverTime + 240};
if (serverTime >= _deadline) exitWith {[_group] call WAIT_fnc_CortexClearRelease; false};
// Replacing a clear must retire its engine movement orders as well as its queued job.
// Validate the new building/team first; an invalid request must preserve the current order.
// HC resume keeps the published progress/deadline rather than starting a new episode.
if (!_resume && {_previous isNotEqualTo []}) then {[_group] call WAIT_fnc_CortexClearRelease};
private _baseAttack=if (_resume) then {_previous param [8,attackEnabled _leader,[true]]} else {attackEnabled _leader};
_group setVariable ["WAIT_AIPass_ClearOrder", [_building, _cleared, _deadline, _baseBehaviour, _unreachable, _retryCounts, _failedBy, _lastProgressAt, _baseAttack], true];
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
for "_exitIndex" from 0 to 15 do {
    private _candidate=_building buildingExit _exitIndex;
    if (_candidate isNotEqualTo [0,0,0] && {_candidate distance2D _building < 50}
        && {_entries findIf {_x distance2D _candidate < 1} < 0}) then {
        _entries pushBack _candidate;
    };
};
if (_entries isNotEqualTo []) then {
    private _entryOrigin=getPosATL _leader;
    _entries=[_entries,[],{_x distance2D _entryOrigin},"ASCEND"] call BIS_fnc_sortBy;
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
private _remaining=[];
for "_index" from 0 to ((count _positions)-1) do {
    if !(_index in (_cleared+_unreachable)) then {_remaining pushBack _index};
};
private _routeCursor=if (_entryRoute isEqualTo []) then {getPosATL _building} else {_entryRoute};
while {_remaining isNotEqualTo []} do {
    private _lowest=1e9;
    {private _height=(_positions select _x) select 2; if (_height < _lowest) then {_lowest=_height}} forEach _remaining;
    private _floorCandidates=_remaining select {abs (((_positions select _x) select 2)-_lowest) < 1.8};
    private _bestSlot=0;
    private _bestDistance=1e9;
    {
        private _distance=_routeCursor distance2D (_positions select _x);
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
private _pairs=[];
{
    if ((_forEachIndex mod 2) == 0) then {
        _pairs pushBack [_x];
    } else {
        (_pairs select ((count _pairs)-1)) pushBack _x;
    };
} forEach _team;
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
        private _ranked=_entries apply {[_pairLead distance2D _x,_forEachIndex]};
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
    ["group", _group], ["team", _team], ["started", []], ["positions", _positions], ["cleared", _cleared], ["building", _building], ["assigned", _team apply {[]}], ["unreachable",_unreachable], ["retryCounts",_retryCounts],
    ["entry",_entryRoute], ["entries",_entries], ["pairs",_pairs], ["pairRoutes",_pairRoutes], ["pairStates",_pairStates], ["pending",_pending],
    ["deadline", _deadline], ["baseBehaviour", _baseBehaviour], ["baseAttack",_baseAttack], ["generation", _generation], ["operationGeneration",_operationGeneration], ["failedBy",_failedBy], ["lastProgressAt",_lastProgressAt], ["visitCursor",0],
    ["phase","ENTRY"],["rotatedOut",[]],["egressAssignments",[]],["egressDeadline",0],["egressReissue",0],["egressFailed",false]
];
[_job] call WAIT_fnc_BuildingOperationStart;
diag_log format ["[WAIT] %1 clearing %2 (%3 positions, %4 soldiers, %5 entrances)", _group, typeOf _building, count _positions, count _team, count _entries];
true

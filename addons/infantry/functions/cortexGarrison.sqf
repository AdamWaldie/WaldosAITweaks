/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: A new garrison releases prior assignments; published positions support adoption by a new owner, including a joining HC.
 * Orders an AI group to garrison the buildings around a point.
 *
 * Uses height-sorted, roofed positions and outward watch sectors. PATH locks only after arrival.
 * Defenders duck under fire; local handlers and assignments replay after ownership changes.
 * Positions: building positions within the radius, roofed positions first, then highest first by default or one-time randomized distribution.
 * Each soldier is sent to his own position, then held there with PATH disabled, watching outward.
 * Building assignments include their admission transform; moved/deleted structures retire stale slots.
 * Surplus actors receive pending exterior security, selected finitely by the existing garrison job.
 * Only local, combat-effective ordinary actors receive slots; protected actors cannot consume
 * an interior assignment or inflate the order's capable starting strength.
 * Suppressed or hit, he drops to a lower stance for a few seconds, then stands back up. The order
 * breaks when the group falls to WAIT_AIPass_Garrison_BreakFraction of its strength at the time of
 * the order, or its morale breaks: PATH is re-enabled and the survivors fight normally.
 * WAIT owns garrison progression. External danger or building controllers are not co-owners of
 * this operation; specialist ownership and Zeus still invalidate it through the common gate.
 * "inPlace" keeps soldiers where they already stand, for units spawned at building positions.
 * The order and each soldier's position are published once as group/unit variables, so a new owner
 * after a headless-client handover re-applies them in its discovery sweep. The Cortex garrison needs the
 * Smart AI Pass running (WAIT_AIPass_Enable); the COMPAT hand-over does not.
 * Locality and authority: call where the group is local, or on the server, which forwards to the
 * owner. Non-server, non-owner copies (for example an Eden init field on a client) do nothing.
 *
 * Admission snapshots route, owner epoch, task generations and selected actors' native command
 * destinations before planning. Changed context refuses the plan before prior-task cleanup.
 * Identical repeated commands remain observationally ambiguous; runtime races need physical testing.
 * Review contract: Plan and validate candidates before replacing existing assignments. Invalid input, empty valid geometry or exhausted planning budget preserves the previous task. The shared eligibility gate rejects player and feature-owned groups before side effects.
 *
 * Arguments:
 * 0: group <GROUP or OBJECT> - the group, or a unit in it
 * 1: centre <ARRAY or OBJECT> - ATL position or object (optional, default: leader position)
 * 2: radius <NUMBER> - search radius in metres (optional, default: 50)
 * 3: options <HASHMAP> (optional) - inPlace (default false), teleport (default false), sortByHeight <BOOL> (default true).
 * Explicit teleport places eligible assigned interior actors once when this order starts;
 * surplus exterior actors still walk. Adoption/JIP never repeats placement. This is scenario
 * placement, not evidence of building entry, clearance or accessible navigation.
 * Example instant placement: [group soldier1, getPosATL house1, 40,
 *     createHashMapFromArray [["teleport",true]]] call WAIT_fnc_CortexGarrison;
 *
 * Return Value:
 * Boolean - true when the order was applied or forwarded
 *
 * Example:
 * [group this, getPosATL this, 40] call WAIT_fnc_CortexGarrison;
 * Result: the squad occupies the nearby buildings and holds them.
 *
 * Current callers: mission scripts/init fields, WAIT_fnc_CortexOrderLocal and WAIT_fnc_CortexDiscover.
 */

params [["_group", grpNull, [grpNull, objNull]], ["_centre", [], [[], objNull]], ["_radius", 50, [0]], ["_options", createHashMap, [createHashMap]]];
if (_group isEqualType objNull) then {_group = group _group};
if (isNull _group) exitWith {false};
private _teleport = _options getOrDefault ["teleport",false];
private _sortByHeight = _options getOrDefault ["sortByHeight",true];
private _inPlace = _options getOrDefault ["inPlace",false];
if (!(_sortByHeight isEqualType true) || {!(_teleport isEqualType true)} || {!(_inPlace isEqualType true)} || {_teleport && {_inPlace}}) exitWith {false};
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (!local _group) exitWith {
    if (isServer) then {[_group, _centre, _radius, _options] remoteExecCall ["WAIT_fnc_CortexGarrison", groupOwner _group]; true} else {false};
};
if !([_group] call WAIT_fnc_CortexIsEligible) exitWith {false};
if (_centre isEqualType objNull) then {if (isNull _centre) then {_centre=[]} else {_centre = getPosATL _centre}};
private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _anchor) then {_anchor=leader _group};
if (count _centre < 2) then {_centre = getPosATL _anchor};
_centre=+_centre;
if (count _centre == 2) then {_centre pushBack 0};
if (count _centre != 3 || {_centre findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!finite _radius} || {_radius <= 0}) exitWith {false};
private _units = (units _group) select {
    [_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
        && {vehicle _x == _x} && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}
        && {!([_x] call WAIT_fnc_CortexActorMoveReserved)}
};
if (_units isEqualTo [] || {count _units > 64}) exitWith {false};

if !(missionNamespace getVariable ["WAIT_AIPass_Active", false]) exitWith {
    diag_log format ["[WAIT] %1 garrison refused: the Smart AI Pass is not running on this machine.", _group];
    false
};

// Capture observable task context before geometry work; this is admission evidence, not
// movement authority. Native planning-mode/force-replan flags are deliberately not compared.
private _admissionRoute=[_group] call WAIT_fnc_NativeOrderReceipt;
private _admissionEpoch=_group getVariable ["WAIT_AIPass_Epoch",0];
private _generationKeys=["WAIT_AIPass_ClearGeneration","WAIT_AIPass_GarrisonGeneration",
    "WAIT_AIPass_DefendGeneration","WAIT_OperationGeneration"];
private _admissionGenerations=_generationKeys apply {_group getVariable [_x,-1]};
private _admissionActors=_units apply {[_x,currentCommand _x,+((expectedDestination _x) param [0,[],[[]]]),formLeader _x]};
private _admissionCurrent={
    local _group && {(_group getVariable ["WAIT_AIPass_Epoch",0]) == _admissionEpoch}
        && {([_group] call WAIT_fnc_NativeOrderReceipt) isEqualTo _admissionRoute}
        && {(_generationKeys apply {_group getVariable [_x,-1]}) isEqualTo _admissionGenerations}
        && {_admissionActors findIf {
            _x params ["_actor","_command","_destination","_followLeader"];
            !local _actor || {group _actor != _group} || {vehicle _actor != _actor}
                || {isPlayer _actor} || {!isNull remoteControlled _actor}
                || {!([_actor] call WAIT_fnc_CortexCombatEffective)}
                || {[_actor] call WAIT_fnc_CortexActorMoveReserved}
                || {currentCommand _actor != _command}
                || {if (_command == "FOLLOW" && {!isNull _followLeader}) then {
                    formLeader _actor != _followLeader
                } else {((expectedDestination _actor) param [0,[],[[]]]) isNotEqualTo _destination}}
        } < 0}
};
// One bounded admission plan. No assignment or old-task cleanup happens during geometry reads.
private _candidateAssignments=[];
private _planningValid=true;
if (_inPlace) then {
    {_candidateAssignments pushBack [getPosATL _x,_centre getDir _x,objNull]} forEach _units;
} else {
    private _buildings=nearestObjects [_centre,["House","Building"],_radius,true];
    if (count _buildings > 64) then {_planningValid=false};
    private _candidates=[];
    private _positionsSeen=0;
    private _taken=createHashMap;
    {
        if (!_planningValid) exitWith {};
        private _building=_x;
        private _positions=_building buildingPos -1;
        _positionsSeen=_positionsSeen+count _positions;
        if (_positionsSeen > 512) exitWith {_planningValid=false};
        if (alive _building) then {
            {
                private _position=_x;
                if (count _position == 3 && {_position findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                    && {!surfaceIsWater _position} && {[AGLToASL _position,_taken,1] call WAIT_fnc_PositionBucketAdmit}) then {
                    private _positionASL=AGLToASL _position;
                    private _roofed=(lineIntersectsSurfaces [_positionASL vectorAdd [0,0,1],_positionASL vectorAdd [0,0,15],objNull,objNull,true,1]) isNotEqualTo [];
                    _candidates pushBack [[1,0] select _roofed,if (_sortByHeight) then {-(_position select 2)} else {random 1},count _candidates,_position,getPosATL _building,_building];
                };
            } forEach _positions;
        };
    } forEach (_buildings select [0,64]);
    _candidates sort true;
    _candidateAssignments=_candidates apply {[_x select 3,(_x select 4) getDir (_x select 3),_x select 5,[getPosWorld (_x select 5),vectorDir (_x select 5),vectorUp (_x select 5)]]};
};
if !(call _admissionCurrent) exitWith {
    _group setVariable ["WAIT_Cortex_GarrisonAdmissionFailure",[diag_tickTime,"PLAN_CONTEXT_CHANGED",_group getVariable ["WAIT_Cortex_LastTaskSerial",-1]]];
    diag_log format ["[WAIT] Garrison refused group=%1 reason=PLAN_CONTEXT_CHANGED; prior task retained",_group];
    false
};
if (!_planningValid || {_candidateAssignments isEqualTo []} || {!local _group}
    || {!([_group] call WAIT_fnc_CortexIsEligible)} || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {
    private _failure=["NO_VALID_POSITIONS","INVALID_OR_OVER_BUDGET_PLAN"] select (!_planningValid);
    _group setVariable ["WAIT_Cortex_GarrisonAdmissionFailure",[diag_tickTime,_failure,_group getVariable ["WAIT_Cortex_LastTaskSerial",-1]]];
    diag_log format ["[WAIT] Garrison refused group=%1 reason=INVALID_OR_OVER_BUDGET_PLAN; prior task retained",_group];
    false
};
[_group,false] call WAIT_fnc_CortexReleaseGroup;
[_group] call WAIT_fnc_CortexClearRelease;
if ((_group getVariable ["WAIT_AIPass_Garrison",[]]) isNotEqualTo []) then {[_group] call WAIT_fnc_CortexGarrisonRelease};
if ((_group getVariable ["WAIT_AIPass_Defend",[]]) isNotEqualTo []) then {[_group,false,false] call WAIT_fnc_CortexDefendRelease};
_group setVariable ["WAIT_Cortex_GarrisonCandidates",_candidateAssignments,true];
{
    private _assignment=if (_forEachIndex < count _candidateAssignments) then {
        _candidateAssignments select _forEachIndex
    } else {[getPosATL _x,0,objNull,[],"EXTERIOR_PENDING"]};
    _x setVariable ["WAIT_AIPass_GarrisonPos",_assignment,true];
} forEach _units;
// Instant placement is an explicit one-shot order option, never an approach recovery.
// It is deliberately absent from ApplyLocal, so migration and repeated discovery cannot teleport.
if (_teleport) then {
    {
        private _unit = _x;
        private _assignment = _unit getVariable ["WAIT_AIPass_GarrisonPos",[]];
        private _building = _assignment param [2,objNull];
        private _transform = _assignment param [3,[]];
        private _free=!([_unit] call WAIT_fnc_CortexActorMoveReserved);
        if (local _group && {local _unit} && {group _unit == _group} && {!isPlayer _unit}
            && {isNull remoteControlled _unit} && {isNull objectParent _unit}
            && {[_unit] call WAIT_fnc_CortexCombatEffective} && {_unit checkAIFeature "MOVE"}
            && {_free} && {!([_group,false,_unit] call WAIT_fnc_CortexExternalTakeover)}
            && {!(currentCommand _unit in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
            && {!isNull _building} && {alive _building}
            && {_transform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}) then {
            _unit setPosATL (_assignment select 0);
        };
    } forEach _units;
};
_group setVariable ["WAIT_Cortex_GarrisonPlacement",if (_inPlace) then {"IN_PLACE"} else {["WALK","INSTANT"] select _teleport},true];
_group setVariable ["WAIT_Cortex_GarrisonRoster",+_units,true];
_group setVariable ["WAIT_Cortex_GarrisonResult",nil,true];
_group setVariable ["WAIT_Cortex_GarrisonDeadline",serverTime+240,true];
_group setVariable ["WAIT_AIPass_Garrison", [_centre, _radius, count _units], true];
_group setVariable ["WAIT_AIPass_GarrisonApplied", false];
[_group,_units] call WAIT_fnc_CortexGarrisonApplyLocal;
diag_log format ["[WAIT] %1 garrisoned at %2 r=%3 (%4 soldiers)", _group, _centre, _radius, count _units];
true

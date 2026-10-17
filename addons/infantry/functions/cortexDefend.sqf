/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: A new defence replaces the prior assignment. Published assignments are reapplied by the new local owner after migration or JIP.
 * Orders an AI group to hold a defensive line facing a direction, with a rear reserve.
 * Line/reserve geometry is planned before old orders are released. Invalid, wet, steep or
 * overlapping layouts return false with prior assignments intact. Geometry is not proof of
 * native path accessibility; physical approach/arrival remains a separate requirement.
 * A changed native order, actor command, task generation or ownership epoch during planning
 * refuses the new task before cleanup. FOLLOW permits its same leader to keep moving.
 * Line and reserve slots count only local combat-effective actors without player or specialist
 * ownership or an actor movement reservation; protected actors remain outside the order's allocation and starting strength.
 *
 * About two thirds of the squad form a firing line across the facing
 * direction, spread over the given width. Lateral slots contract towards the centre when the nominal
 * point is water or a cliff-like side slope. Each soldier's spot is snapped to cover facing the threat,
 * and soldiers watch overlapping sectors (up to 30 degrees either side of the facing). The rest form a
 * reserve 40 m behind the centre; squads of three or fewer are all line. Soldiers hold with doStop
 * rather than a PATH lock, so they can still take cover and turn. The reserve is committed once
 * (WAIT_fnc_CortexDefendStep) to the weakest point of the line when a third of the line is lost, or
 * to the line spot nearest an enemy believed within 60 m of the line. The order breaks at
 * WAIT_AIPass_Garrison_BreakFraction of its strength, or when morale breaks, and the survivors then
 * fight normally.
 * The order and each soldier's spot are published once as group and unit variables, so a new owner
 * after a headless-client handover re-applies them in its discovery sweep. Zeus waypoints release it.
 * Locality and authority: call where the group is local, or on the server, which forwards to the
 * owner. Non-server, non-owner copies do nothing. Needs the Smart AI Pass running.
 *
 * Review contract: Repeated placement releases the previous defence first. The shared eligibility gate protects player squads and other features before any orders are issued.
 *
 * Arguments:
 * 0: group <GROUP or OBJECT> - the group, or a unit in it
 * 1: centre <ARRAY or OBJECT> - ATL position or object at the middle of the line
 * 2: facing <NUMBER or ARRAY or OBJECT> - compass direction, or a position/object the line faces
 * 3: width <NUMBER> - line width in metres (optional, default: 60)
 *
 * Return Value:
 * Boolean - true when the order was applied or forwarded
 *
 * Example:
 * [group this, getMarkerPos "ridge", 45, 80] call WAIT_fnc_CortexDefend;
 * Result: the squad forms an 80 m line on the ridge facing north-east, with a reserve behind it.
 *
 * Current callers: mission scripts and WAIT_fnc_CortexOrderLocal for native/optional defence tasks.
 */

params [["_group", grpNull, [grpNull, objNull]], ["_centre", [], [[], objNull]], ["_facing", 0, [0, [], objNull]], ["_width", 60, [0]]];
if (_group isEqualType objNull) then {_group = group _group};
if (isNull _group) exitWith {false};
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (!local _group) exitWith {
    if (isServer) then {[_group, _centre, _facing, _width] remoteExecCall ["WAIT_fnc_CortexDefend", groupOwner _group]; true} else {false};
};
if !([_group] call WAIT_fnc_CortexIsEligible) exitWith {false};
if !(missionNamespace getVariable ["WAIT_AIPass_Active", false]) exitWith {
    diag_log format ["[WAIT] %1 defend refused: the Smart AI Pass is not running on this machine.", _group];
    false
};
if (_centre isEqualType objNull) then {if (isNull _centre) then {_centre=[]} else {_centre = getPosATL _centre}};
private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _anchor) then {_anchor=leader _group};
if (count _centre < 2) then {_centre = getPosATL _anchor};
_centre=+_centre;
if (count _centre == 2) then {_centre pushBack 0};
if (count _centre != 3 || {_centre findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!finite _width} || {_width <= 0}) exitWith {false};
private _facingValid=true;
if !(_facing isEqualType 0) then {
    private _towards = if (_facing isEqualType objNull) then {if (isNull _facing) then {[]} else {getPosATL _facing}} else {_facing};
    _facingValid=count _towards in [2,3] && {_towards findIf {!(_x isEqualType 0) || {!finite _x}} < 0};
    if (_facingValid) then {_facing = _centre getDir _towards};
};
if (!_facingValid || {!(_facing isEqualType 0)} || {!finite _facing}) exitWith {false};
_facing=((_facing mod 360)+360) mod 360;
private _units = (units _group) select {
    [_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
        && {vehicle _x == _x} && {!([_x] call WAIT_fnc_CortexActorMoveReserved)}
        && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}
};
if (_units isEqualTo [] || {count _units > 64}) exitWith {false};
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
private _reserveCount = if (count _units >= 4) then {floor (count _units / 3)} else {0};
private _line = _units select [0, count _units - _reserveCount];
private _reserve = _units select [count _line, _reserveCount];
private _threat = _centre getPos [150, _facing];
private _spacing = _width / ((count _line - 1) max 1);
private _taken = [];
private _placements=[];
private _layoutValid=true;
private _slotValid={
    params ["_position"];
    count _position == 3 && {!surfaceIsWater _position}
        && {((surfaceNormal _position) select 2) >= 0.55}
        && {_taken findIf {_x distance2D _position < 1} < 0}
};
{
    private _offset = (_forEachIndex - (count _line - 1) / 2) * _spacing;
    private _slot=_centre getPos [_offset,_facing+90];
    if (surfaceIsWater _slot || {((surfaceNormal _slot) select 2) < 0.55}) then {
        {
            private _alternative=_centre getPos [_offset*_x,_facing+90];
            if (!surfaceIsWater _alternative && {((surfaceNormal _alternative) select 2) >= 0.55}) exitWith {_slot=_alternative};
        } forEach [0.75,0.5,0.25,0];
    };
    private _spot = ([_slot, _threat, 8, _taken, _group] call WAIT_fnc_CortexFindCover) select 0;
    if !([_spot] call _slotValid) then {_layoutValid=false};
    _taken pushBack _spot;
    private _sector = _facing + ((_forEachIndex / ((count _line - 1) max 1)) - 0.5) * 60;
    _placements pushBack [_x,[_spot,_sector,"LINE"]];
} forEach _line;
private _rearCandidates=[];
{_rearCandidates pushBack [_centre getPos [40,_facing+180+_x]]} forEach [0,-30,30,-60,60];
private _rearRoute=[_centre,_rearCandidates,_threat] call WAIT_fnc_CortexSelectAvenue;
private _rear=if (_rearRoute isEqualTo []) then {+_centre} else {+(_rearRoute select 0)};
{
    private _offset=(_forEachIndex-(count _reserve-1)/2)*5;
    private _slot=_rear getPos [_offset,_facing+90];
    if (surfaceIsWater _slot || {((surfaceNormal _slot) select 2) < 0.55}) then {_slot=+_rear};
    if !([_slot] call _slotValid) then {_layoutValid=false};
    _taken pushBack _slot;
    _placements pushBack [_x,[_slot,_facing,"RESERVE"]];
} forEach _reserve;
// Geometry queries may overlap new authority. Refuse before cleanup or assignment mutation.
if (!_layoutValid || {count _placements != count _units} || {!(call _admissionCurrent)} || {!local _group}
    || {!([_group] call WAIT_fnc_CortexIsEligible)} || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
// End transient movement only after a complete layout is ready.
[_group,false] call WAIT_fnc_CortexReleaseGroup;
[_group] call WAIT_fnc_CortexClearRelease;
if ((_group getVariable ["WAIT_AIPass_Defend", []]) isNotEqualTo []) then {[_group,false,false] call WAIT_fnc_CortexDefendRelease};
{_x params ["_actor","_assignment"];_actor setVariable ["WAIT_AIPass_DefendPos",_assignment,true]} forEach _placements;
if ((_group getVariable ["WAIT_AIPass_Garrison", []]) isNotEqualTo []) then {[_group] call WAIT_fnc_CortexGarrisonRelease};
_group setVariable ["WAIT_AIPass_Defend", [_centre, _facing, _width, count _units], true];
_group setVariable ["WAIT_AIPass_DefendApplied", false];
_group setVariable ["WAIT_Cortex_DefendNativeRoute",[_group] call WAIT_fnc_NativeOrderReceipt,true];
[_group,[],_units] call WAIT_fnc_CortexDefendApplyLocal;
diag_log format ["[WAIT] %1 defending %2 facing %3 (line %4, reserve %5)", _group, _centre, round _facing, count _line, count _reserve];
true

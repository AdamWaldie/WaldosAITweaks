/*
 * Author: WaldoTheWarfighter
 * Purpose: Commits one short terrain-screened reposition when the current contact cannot support a useful assault, flank or advance.
 * Locality / Authority: Runs only on the current group owner after normal WAIT eligibility checks. Zeus, players, authored HOLD/SENTRY orders, specialist owners and newer WAIT operations take precedence.
 * Repeat/JIP: One operation generation owns one waypoint. A public cooldown prevents route churn; locality migration retires the old generation and never replays its command blindly.
 * Arguments: 0: group <GROUP>; 1: state <HASHMAP>; 2: ordered known enemies <ARRAY>; 3: selected target index <NUMBER, default 0>; 4: assessment reason <STRING>.
 * Return Value: Boolean - true only when a physical reposition or close-threat withdrawal started.
 * Current callers: WAIT_fnc_CortexTacticalStart.
 * Example: private _started=[group player,_state,_contacts,0,"ARMOUR_OVERMATCH"] call WAIT_fnc_CortexTacticalReposition;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_state",createHashMap,[createHashMap]],
    ["_enemies",[],[[]]],
    ["_targetIndex",0,[0]],
    ["_reason","NO_SAFE_MANOEUVRE",[""]]
];
if (isNull _group || {!local _group} || {_enemies isEqualTo []}
    || {!([_group,false,false,true] call WAIT_fnc_CortexIsEligible)}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
if (count (_state getOrDefault ["drill",createHashMap]) > 0
    || {(_state getOrDefault ["movementLease",[]]) isNotEqualTo []}
    || {count (_group getVariable ["WAIT_Operation",createHashMap]) > 0}) exitWith {false};

private _leader=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
if (isNull _leader || {!alive _leader}) exitWith {false};
_targetIndex=(_targetIndex max 0) min ((count _enemies)-1);
private _record=_enemies select _targetIndex;
private _target=_record param [0,objNull,[objNull]];
private _threatPos=_record param [1,[],[[]]];
if (count _threatPos < 2) then {
    if (!isNull _target) then {_threatPos=getPosATL vehicle _target};
};
if (count _threatPos < 2) exitWith {false};
private _cooldown=_group getVariable ["WAIT_Cortex_TacticalRepositionCooldown",[]];
if (count _cooldown == 3 && {time < (_cooldown select 0)}
    && {(_cooldown select 1) == _reason} && {(_cooldown select 2) isEqualTo _target}) exitWith {false};

private _origin=getPosATL _leader;
private _distance=_origin distance2D _threatPos;
// At hand-grenade distance from protected armour, remaining in place is not a credible option.
// Use the existing finite withdrawal controller; at all other ranges retain the engagement and
// make only a short screened positional improvement.
if (_reason == "ARMOUR_OVERMATCH" && {_distance <= 120}) exitWith {
    _state set ["enemyPos",+_threatPos];
    _state set ["withdrawReason","CLOSE_ARMOUR_OVERMATCH"];
    private _withdrawing=[_group,_state] call WAIT_fnc_CortexRetreat;
    if (_withdrawing) then {
        _group setVariable ["WAIT_Cortex_TacticalReposition",["WITHDRAW",_reason,_target,serverTime],true];
    };
    _withdrawing
};

private _toward=_origin getDir _threatPos;
private _away=_threatPos getDir _origin;
private _range=switch (_reason) do {
    case "ELEVATED_FIRE_POSITION": {45};
    case "AIR_OVERMATCH": {50};
    case "INSUFFICIENT_FIREPOWER": {30};
    case "MORALE_SHAKEN": {30};
    default {40};
};
private _headings=switch (_reason) do {
    case "ELEVATED_FIRE_POSITION": {[_toward+90,_toward-90,_away+45,_away-45]};
    case "AIR_OVERMATCH": {[_toward+90,_toward-90,_away+45,_away-45,_away]};
    case "INSUFFICIENT_FIREPOWER": {[_away+45,_away-45,_toward+90,_toward-90]};
    case "MORALE_SHAKEN": {[_toward+90,_toward-90,_away+45,_away-45]};
    default {[_away+35,_away-35,_toward+90,_toward-90,_away]};
};
private _candidates=[];
{
    private _intermediate=_origin getPos [_range*0.55,_x];
    private _goal=_origin getPos [_range,_x];
    _candidates pushBack [_intermediate,_goal];
} forEach _headings;
private _route=[_origin,_candidates,_threatPos,[],_target,"INFANTRY"] call WAIT_fnc_CortexSelectAvenue;
if (_route isEqualTo []) exitWith {
    _group setVariable ["WAIT_Cortex_TacticalReposition",["BLOCKED",_reason,_target,serverTime],true];
    _group setVariable ["WAIT_Cortex_TacticalRepositionCooldown",[time+12,_reason,_target]];
    false
};
private _goal=+(_route select -1);
private _cover=[_goal,_threatPos,18,[],_group] call WAIT_fnc_CortexFindCover;
if (_cover param [1,false,[false]]) then {
    _goal=+(_cover select 0);
    _route set [(count _route)-1,_goal];
};

if !([_group,"TACTICAL_REPOSITION",true,serverTime+30] call WAIT_fnc_CortexOwnershipLease) exitWith {false};
private _participants=(units _group) select {
    alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
        && {lifeState _x != "INCAPACITATED"}
};
private _objective=[_target,_threatPos] select isNull _target;
private _operation=[_group,"REPOSITION",_objective,_participants,_route,"MOVING"] call WAIT_fnc_OperationStart;
if (count _operation == 0) exitWith {
    [_group,"TACTICAL_REPOSITION",false] call WAIT_fnc_CortexOwnershipLease;
    false
};
private _generation=_operation get "generation";
_state set ["tacticalRepositionOperationGeneration",_generation];
_state set ["movementLease",["TACTICAL_REPOSITION",time+30]];
[_group,_goal,12,"MOVE",_generation] call WAIT_fnc_CortexGroupMove;
_group setVariable ["WAIT_Cortex_TacticalReposition",[
    "MOVING",_reason,_target,serverTime,+_origin,+_goal,+_route,_generation
],true];
_group setVariable ["WAIT_Cortex_TacticalRepositionCooldown",[time+75,_reason,_target]];
true

/*
 * Author: WaldoTheWarfighter
 * Purpose: Select one bounded group-level combat intent from existing native knowledge, force capability, terrain and mission orders.
 * Locality / Authority: Read-only on the current group owner. It never reveals targets, issues commands or acquires movement ownership.
 * Repeat/JIP: Pure assessment. The caller stores the result for diagnostics and starts any operation through the normal generation owner.
 * Arguments: 0: group <GROUP>; 1: state <HASHMAP>; 2: known enemies <ARRAY>; 3: flank enabled <BOOL>; 4: advance enabled <BOOL>; 5: assault enabled <BOOL>.
 * Return Value: HashMap with intent, reason, selected index, candidate order and bounded evidence.
 * Current callers: WAIT_fnc_CortexTacticalStart.
 * Example: private _assessment=[group player,_state,_enemies,true,true,true] call WAIT_fnc_CortexTacticalAssess;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_state",createHashMap,[createHashMap]],
    ["_enemies",[],[[]]],
    ["_flankEnabled",true,[true]],
    ["_advanceEnabled",true,[true]],
    ["_assaultEnabled",true,[true]]
];
private _result=createHashMapFromArray [
    ["intent","HOLD"],["reason","NO_VIABLE_CONTACT"],["targetIndex",-1],
    ["candidates",[]],["evidence",[]]
];
if (isNull _group || {!local _group} || {_enemies isEqualTo []}) exitWith {_result};
private _leader=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
if (isNull _leader || {!alive _leader}) exitWith {_result};

private _waypointIndex=currentWaypoint _group;
private _forwardOrder=_waypointIndex < count waypoints _group
    && {waypointDescription [_group,_waypointIndex] != "WAIT AI PASS"}
    && {waypointType [_group,_waypointIndex] in ["MOVE","SAD","DESTROY"]}
    && {_leader distance2D waypointPosition [_group,_waypointIndex] > 80};
private _foot=(units _group) select {
    [_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {isNull objectParent _x}
};
private _capableAT=_foot findIf {"AT" in ([_x] call WAIT_fnc_CortexCapabilities)} >= 0;
private _houses=(getPosATL _leader) getEnvSoundController "houses";
private _trees=(getPosATL _leader) getEnvSoundController "trees";
private _forest=(getPosATL _leader) getEnvSoundController "forest";
private _concealment=(_houses+_trees+(_forest*0.5)) min 1;
private _closeRange=(missionNamespace getVariable ["WAIT_AIPass_Assault_Range",80]) min 60;
private _manoeuvre=[];
private _armourIndex=-1;
private _elevatedIndex=-1;
private _fortifiedIndex=-1;
{
    private _target=_x param [0,objNull,[objNull]];
    private _position=_x param [1,[0,0,0],[[]]];
    private _age=_x param [2,1e9,[0]];
    private _distance=_x param [3,1e9,[0]];
    if (!isNull _target && {alive _target}) then {
        private _platform=vehicle _target;
        if (_armourIndex < 0 && {_distance <= 450}
            && {_platform isKindOf "Tank" || {_platform isKindOf "Wheeled_APC_F"}}) then {_armourIndex=_forEachIndex};
        if (_target isKindOf "CAManBase" && {isNull objectParent _target}
            || {_platform isKindOf "StaticWeapon"}) then {
            _manoeuvre pushBack _forEachIndex;
            if (_elevatedIndex < 0 && {_distance > 300}
                && {((getPosASL _target) select 2) > (((eyePos _leader) select 2)+15)}
                && {_age <= 30}) then {_elevatedIndex=_forEachIndex};
            if (_fortifiedIndex < 0 && {_distance > 220 || {_platform isKindOf "StaticWeapon"}
                || {_houses > 0.35}}) then {_fortifiedIndex=_forEachIndex};
        };
    };
} forEach _enemies;

private _selected=-1;
private _intent="HOLD";
private _reason="NO_MANOEUVRE_TARGET";
private _candidates=[];
private _closePosition=_manoeuvre findIf {
    private _record=_enemies select _x;
    private _target=_record param [0,objNull,[objNull]];
    _target isKindOf "CAManBase" && {isNull objectParent _target}
        && {(_record param [2,1e9,[0]]) <= 10}
        && {(_record param [3,1e9,[0]]) >= 12}
        && {(_record param [3,1e9,[0]]) <= _closeRange}
};
if (_assaultEnabled && {_closePosition >= 0} && {count _foot >= 4}) then {
    _selected=_manoeuvre select _closePosition;
    _intent="ASSAULT";
    _reason="FRESH_CLOSE_INFANTRY";
    _candidates=["ASSAULT"];
} else {
    if (_forwardOrder) then {
        // The mission objective remains authoritative. Any live contact can provide fire context
        // while the group advances on that objective; a mobile platform must not replace it.
        _selected=_enemies findIf {
            private _target=_x param [0,objNull,[objNull]];
            !isNull _target && {alive _target} && {(_x param [3,0,[0]]) >= 60}
        };
        if (_selected >= 0 && {_advanceEnabled}) then {
            _intent="ADVANCE";
            _reason="AUTHORED_FORWARD_ORDER";
            _candidates=["ADVANCE"];
            if (_flankEnabled) then {_candidates pushBack "FLANK"};
        };
    } else {
        if (_armourIndex >= 0 && {!_capableAT}) then {
            _selected=_armourIndex;
            _reason="ARMOUR_OVERMATCH";
        } else {
            private _freshPosition=_manoeuvre findIf {
                private _record=_enemies select _x;
                (_record param [3,0,[0]]) >= 60 && {(_record param [2,1e9,[0]]) <= 10}
            };
            if (_freshPosition >= 0) then {_selected=_manoeuvre select _freshPosition};
            if (_fortifiedIndex >= 0 && {_flankEnabled}) then {
                _selected=_fortifiedIndex;
                _intent="FLANK";
                _reason="FORTIFIED_OR_DISTANT_CONTACT";
                _candidates=["FLANK"];
                if (_advanceEnabled) then {_candidates pushBack "ADVANCE"};
            } else {
                if (_elevatedIndex >= 0 && {_flankEnabled}) then {
                    _selected=_elevatedIndex;
                    _intent="FLANK";
                    _reason="ELEVATED_EXPOSED_CONTACT";
                    _candidates=["FLANK"];
                    if (_advanceEnabled) then {_candidates pushBack "ADVANCE"};
                } else {
                    if (_selected >= 0) then {
                        if (_flankEnabled && {_concealment < 0.45}) then {
                            _intent="FLANK";
                            _reason="OPEN_APPROACH";
                            _candidates=["FLANK"];
                            if (_advanceEnabled) then {_candidates pushBack "ADVANCE"};
                        } else {
                            if (_advanceEnabled) then {
                                _intent="ADVANCE";
                                _reason=["COVERED_APPROACH","FLANK_DISABLED"] select !_flankEnabled;
                                _candidates=["ADVANCE"];
                                if (_flankEnabled) then {_candidates pushBack "FLANK"};
                            } else {
                                if (_flankEnabled) then {
                                    _intent="FLANK";
                                    _reason="ADVANCE_DISABLED";
                                    _candidates=["FLANK"];
                                };
                            };
                        };
                    };
                };
            };
        };
    };
};
_result set ["intent",_intent];
_result set ["reason",_reason];
_result set ["targetIndex",_selected];
_result set ["candidates",_candidates];
_result set ["evidence",[count _foot,_capableAT,_concealment,_armourIndex,_fortifiedIndex,_elevatedIndex,_forwardOrder]];
_result

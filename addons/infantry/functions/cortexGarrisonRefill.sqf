/*
 * Author: WaldoTheWarfighter
 * Purpose: Refills one vacant interior garrison post after the arrival job has settled.
 * Locality/authority: current group owner only, through the existing group scheduler. Eligibility,
 * actor reservations and native service/movement commands are checked before replacing a slot.
 * Repeat/JIP: one promotion per settled callback. Fresh physical arrival and exit observation are required for both exterior actors.
 * Living assignments (including unconscious
 * soldiers) reserve their slots. New-owner ApplyLocal resets the pending marker before adoption.
 * Replacement actors walk; instant placement belongs only to initial explicit task admission.
 * Arguments: 0 group <GROUP>, grpNull.
 * Return: BOOL - assignment issued, not physical arrival or occupation success.
 * Current callers: WAIT_fnc_CortexGroupTick.
 * Example: [group soldier1] call WAIT_fnc_CortexGarrisonRefill;
 */
params [["_group",grpNull,[grpNull]]];
// Internal scheduled executor, not a public network order endpoint.
if (isRemoteExecuted) exitWith {false};
if (isNull _group || {!local _group} || {!([_group] call WAIT_fnc_CortexIsEligible)}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
private _order=_group getVariable ["WAIT_AIPass_Garrison",[]];
if (_order isEqualTo [] || {(_group getVariable ["WAIT_Cortex_GarrisonPending",-1]) != 0}) exitWith {false};
if !(_group getVariable ["WAIT_AIPass_GarrisonApplied",false]) exitWith {false};
private _members=units _group;
if (count _members > 64) exitWith {false};
private _living=_members select {alive _x};
private _roster=(_group getVariable ["WAIT_Cortex_GarrisonRoster",_members]) select {!isNull _x && {alive _x} && {group _x == _group}};
if (count _living/((_order param [2,1]) max 1) <= (missionNamespace getVariable ["WAIT_AIPass_Garrison_BreakFraction",0.5])) exitWith {false};
private _candidates=(_group getVariable ["WAIT_Cortex_GarrisonCandidates",[]]) select [0,64];
private _vacancy=[];
{
    private _candidate=_x;
    private _building=_candidate param [2,objNull];
    private _transform=_candidate param [3,[]];
    if (!isNull _building && {alive _building}
        && {_transform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
        && {_living findIf {
            private _assignment=_x getVariable ["WAIT_AIPass_GarrisonPos",[]];
            _assignment isNotEqualTo [] && {(_assignment param [4,"INTERIOR"]) == "INTERIOR"}
                && {(_assignment param [2,objNull]) == _building}
                && {(_assignment select 0) vectorDistance (_candidate select 0) < 1}
        } < 0}) exitWith {_vacancy=+_candidate};
} forEach _candidates;
if (_vacancy isEqualTo []) exitWith {false};
private _eligible=_living select {
    private _actor=_x;
    private _assignment=_actor getVariable ["WAIT_AIPass_GarrisonPos",[]];
    private _reservation=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
    private _free=_reservation isEqualTo [] || {_reservation isEqualType [] && {count _reservation == 3}
        && {(_reservation param [2,1e12,[0]]) <= time}};
    // A previously enrolled actor handed to a newer native task is not a new reinforcement.
    private _spare=_assignment isEqualTo [] && {!(_actor in _roster)};
    if ((_assignment param [4,""]) == "EXTERIOR" && {_actor getVariable ["WAIT_AIPass_GarrisonDisabledPath",false]}
        && {!(_actor checkAIFeature "PATH")} && {[_actor,_assignment] call WAIT_fnc_CortexGarrisonArrived}) then {
        // Never vacate the sole assigned observation post for this building exit.
        _spare=_living findIf {
            _x != _actor && {local _x} && {!isPlayer _x}
                && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)} && {[_x] call WAIT_fnc_CortexCombatEffective}
                && {_x getVariable ["WAIT_AIPass_GarrisonDisabledPath",false]} && {!(_x checkAIFeature "PATH")}
                && {private _other=_x getVariable ["WAIT_AIPass_GarrisonPos",[]];
                    (_other param [4,""]) == "EXTERIOR"
                        && {(_other param [2,objNull]) == (_assignment param [2,objNull])}
                        && {(_other param [6,[]]) isEqualTo (_assignment param [6,[]])}
                        && {[_x,_other] call WAIT_fnc_CortexGarrisonArrived}}
        } >= 0;
    };
    _spare && {local _actor} && {!isPlayer _actor} && {isNull remoteControlled _actor}
        && {isNull objectParent _actor} && {_actor checkAIFeature "MOVE"} && {_free}
        && {[_actor] call WAIT_fnc_CortexCombatEffective}
        && {!(_actor getVariable ["WAIT_AIPass_GarrisonFailed",false])}
        && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
        && {!(currentCommand _actor in ["MOVE","FOLLOW","GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
if (_eligible isEqualTo []) exitWith {false};
_eligible=[_eligible,[],{_x distance2D (_vacancy select 0)},"ASCEND"] call BIS_fnc_sortBy;
private _actor=_eligible select 0;
if (!local _group || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
if ((_actor getVariable ["WAIT_AIPass_GarrisonPos",[]]) isNotEqualTo []) then {
    [_group,false,[_actor]] call WAIT_fnc_CortexGarrisonRelease;
};
_actor setVariable ["WAIT_AIPass_GarrisonPos",_vacancy,true];
_roster pushBackUnique _actor;
_group setVariable ["WAIT_Cortex_GarrisonRoster",_roster,true];
// Only a settled job can open this fresh approach window. Existing failed routes remain failed;
// unfinished routes cannot repeatedly renew their deadline through casualty callbacks.
_group setVariable ["WAIT_Cortex_GarrisonDeadline",serverTime+90,true];
[_group] call WAIT_fnc_CortexGarrisonApplyLocal;
_group setVariable ["WAIT_Cortex_GarrisonRefill",[netId _actor,+(_vacancy select 0),serverTime],true];
true

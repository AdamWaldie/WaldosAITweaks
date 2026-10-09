/*
 * Author: WaldoTheWarfighter
 * Purpose: Give one idle exposed soldier a single bounded move to nearby physical cover after an immediate danger event.
 * Locality / Authority: Called by the group brain while it already runs in WAIT's shared scheduler.
 * It runs on the actor and group owner and yields
 * to player, Zeus, specialist, native-command and WAIT-operation ownership before selecting or issuing movement.
 * Repeat/JIP: One group lease coalesces a danger burst. Each call either retains, releases or creates
 * one finite move. A locality or generation change retires it without restoring over newer work.
 * Arguments: 0 group <GROUP>; 1 actor <OBJECT>; 2 threat position <ARRAY>; 3 danger generation <NUMBER>;
 * 4 release-only <BOOL>, false - retire the owned lease without recovery or new movement.
 * Return Value: Boolean - true while WAIT owns a finite danger-cover move, otherwise false.
 * Current callers: WAIT_fnc_CortexGroupTick.
 * Example: [group player,player,getPosATL player,1] call WAIT_fnc_DangerCoverStep;
 */

params [
    ["_group",grpNull,[grpNull]],["_actor",objNull,[objNull]],
    ["_threat",[],[[]]],["_generation",-1,[0]],["_releaseOnly",false,[true]]
];
private _clearLease={
    params [["_reason","RELEASED",[""]]];
    if (!isNull _group) then {
        _group setVariable ["WAIT_Danger_CoverPending",nil];
        _group setVariable ["WAIT_Danger_CoverDecision",[_reason,time,_actor,_generation]];
        private _lease=_group getVariable ["WAIT_Danger_CoverLease",[]];
        if (count _lease >= 2 && {(_lease select 0) isEqualTo _actor}
            && {(_generation < 0) || {(_lease select 1) == _generation}}) then {
            _group setVariable ["WAIT_Danger_CoverLease",nil];
        };
    };
    false
};
if (isNull _group || {isNull _actor} || {!local _group} || {!local _actor}
    || {!alive _actor} || {isPlayer _actor} || {group _actor != _group}) exitWith {call _clearLease};
private _lease=_group getVariable ["WAIT_Danger_CoverLease",[]];
private _moveProof=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
if (!_releaseOnly && {count _lease >= 4} && {(_lease select 0) isEqualTo _actor}
    && {(_lease select 1) == _generation} && {time < (_lease select 2)}
    && {count _moveProof == 3} && {(_moveProof select 0) == "DANGER_COVER"}
    && {(_moveProof select 1) distance2D (_lease select 3) <= 1}
    && {(_moveProof select 2) == (_lease select 2)}
    && {((expectedDestination _actor) select 0) distance2D (_lease select 3) <= 1}
    && {_generation == (_group getVariable ["WAIT_Danger_Generation",0])}
    && {missionNamespace getVariable ["WAIT_AIPass_Active",false]}
    && {[_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {((_group getVariable ["WAIT_Danger_CoverDecision",[]]) param [5,"COVER"]) != "CONCEALMENT"
        || {[_group,"WAIT_AIPass_DangerConcealment_Enable",true] call WAIT_fnc_CortexFeatureEnabled}}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
    && {count (_group getVariable ["WAIT_Operation",createHashMap]) == 0}
    && {isNull objectParent _actor}
    && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
    && {currentCommand _actor in ["","MOVE"]}) exitWith {true};
if (count _lease >= 4) then {
    _lease params ["_leasedActor","_leasedGeneration","_expires","_leasedSpot"];
    private _distance=if (isNull _leasedActor) then {-1} else {_leasedActor distance2D _leasedSpot};
    private _height=if (isNull _leasedActor) then {-1} else {abs (((getPosATL _leasedActor) select 2)-(_leasedSpot param [2,0]))};
    private _endReason=if (_releaseOnly) then {"RELEASED"} else {
        if (!isNull _leasedActor && {alive _leasedActor} && {_distance <= 2} && {_height <= 1.5}) then {"AT_DESTINATION"} else {
            ["INTERRUPTED","TIMEOUT"] select (time >= _expires)
        }
    };
    // One owner-local observation, not an accumulating history or proof of effective screening.
    _group setVariable ["WAIT_Danger_CoverEnd",[time,_leasedActor,_leasedGeneration,_endReason,_distance,_height,+_leasedSpot,clientOwner,_group getVariable ["WAIT_AIPass_Epoch",0]]];
    if (!isNull _leasedActor) then {
        private _actorMove=_leasedActor getVariable ["WAIT_Cortex_ActorMove",[]];
        if (local _leasedActor && {count _actorMove == 3}
            && {(_actorMove select 0) == "DANGER_COVER"}
            && {(_actorMove select 1) distance2D _leasedSpot <= 1}
            && {(_actorMove select 2) == _expires}) then {
            _leasedActor setVariable ["WAIT_Cortex_ActorMove",nil];
            if (!_releaseOnly && {alive _leasedActor} && {!isPlayer _leasedActor} && {group _leasedActor == _group}
                && {isNull objectParent _leasedActor} && {_leasedActor != leader _group}
                // Successful arrival is useful cover, not a reason to run back across exposure.
                // Only a failed owned approach needs this bounded return-to-formation recovery.
                && {_leasedActor distance2D _leasedSpot > 2}
                && {_leasedActor checkAIFeature "MOVE"} && {_leasedActor checkAIFeature "PATH"}
                && {((expectedDestination _leasedActor) select 0) distance2D _leasedSpot <= 1}
                && {count (_group getVariable ["WAIT_Operation",createHashMap]) == 0}
                && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
                && {!([_group] call WAIT_fnc_CortexZeusHeld)}
                && {currentCommand _leasedActor in ["","MOVE"]}) then {
                _leasedActor doFollow (leader _group);
            };
        };
    };
    _group setVariable ["WAIT_Danger_CoverLease",nil];
};
if (_releaseOnly) exitWith {["RELEASED"] call _clearLease};
if (_generation != (_group getVariable ["WAIT_Danger_Generation",0])
    || {!(missionNamespace getVariable ["WAIT_AIPass_Active",false])}
    || {!([_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[_group] call WAIT_fnc_CortexZeusHeld}) exitWith {call _clearLease};
// Recheck at the final command boundary. A danger observation recorded before a new order or operation
// must retire instead of turning its stale observation into a movement instruction.
if (count (_group getVariable ["WAIT_Operation",createHashMap]) > 0
    || {!(_actor checkAIFeature "MOVE")} || {!(_actor checkAIFeature "PATH")}
    || {!isNull objectParent _actor} || {currentCommand _actor != ""}
    || {(_actor getVariable ["WAIT_Cortex_ActorMove",[]]) isNotEqualTo []}) exitWith {
    _group setVariable ["WAIT_Danger_CoverBlockedContext",[time,currentCommand _actor,
        _actor checkAIFeature "MOVE",_actor checkAIFeature "PATH",
        count (_group getVariable ["WAIT_Operation",createHashMap]),
        _actor getVariable ["WAIT_Cortex_ActorMove",[]]]];
    ["OWNERSHIP_OR_COMMAND"] call _clearLease
};
_threat=+_threat;
if (count _threat < 2) exitWith {call _clearLease};
if (count _threat == 2) then {_threat pushBack ((getPosATL _actor) select 2)};
private _origin=getPosATL _actor;
// Search around the current actor, including after grenade evasion. An away-offset centre
// excluded useful nearby side cover before its threat screening could be evaluated.
private _decision=_group getVariable ["WAIT_Danger_CoverDecision",[]];
private _sameSearch=count _decision >= 4 && {(_decision select 2) == _actor} && {(_decision select 3) == _generation};
if (_sameSearch && {(_decision select 0) in ["NO_SCREEN","NO_DISPLACEMENT"]}) exitWith {false};
// A failed solid-cover search must not repeat every scheduler tick when visual fallback is disabled.
// A newer danger generation permits a fresh assessment.
if (_sameSearch && {(_decision select 0) == "NO_VALID_COVER"}
    && {!([_group,"WAIT_AIPass_DangerConcealment_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) exitWith {
    ["NO_SCREEN"] call _clearLease
};
// One search per callback. A failed solid-cover pass permits a visual-only pass on the next
// existing scheduler step; it never doubles the geometry work in the current callback.
private _screenMode=if (_sameSearch && {(_decision select 0) == "NO_VALID_COVER"}
    && {[_group,"WAIT_AIPass_DangerConcealment_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) then {
    "CONCEALMENT"
} else {"COVER"};
private _cover=[_origin,_threat,18,[],_group,_screenMode] call WAIT_fnc_CortexFindCover;
_cover params ["_spot","_found"];
// A small valid move can put the actor behind nearby cover. Treat negligible displacement
// separately; it is not evidence that solid cover failed and should not trigger concealment.
if (_found && {count _spot >= 2} && {_spot distance2D _origin < 0.6}) exitWith {
    ["NO_DISPLACEMENT"] call _clearLease
};
if (!_found || {count _spot < 2}
    || {_spot distance2D _origin > 18}) exitWith {
    [["NO_VALID_COVER","NO_SCREEN"] select (_screenMode == "CONCEALMENT")] call _clearLease;
    if (_screenMode == "COVER" && {[_group,"WAIT_AIPass_DangerConcealment_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) then {
        _group setVariable ["WAIT_Danger_CoverPending",[_actor,_generation,+_threat,time+4]];
    };
    false
};
if ([_group] call WAIT_fnc_CortexExternalTakeover || {[_group] call WAIT_fnc_CortexZeusHeld}
    || {count (_group getVariable ["WAIT_Operation",createHashMap]) > 0}
    || {currentCommand _actor != ""}) exitWith {call _clearLease};
_group setVariable ["WAIT_Danger_CoverPending",nil];
_group setVariable ["WAIT_Danger_CoverDecision",["COMMITTED",time,_actor,_generation,+_spot,_screenMode]];
// The observation may end before native pathing reaches cover. Retain the committed move
// independently, with a bounded travel allowance rather than a four-second universal cutoff.
private _deadline=time+((2+(_origin distance2D _spot)/2) max 4 min 12);
_actor doMove _spot;
_actor setVariable ["WAIT_Cortex_ActorMove",["DANGER_COVER",+_spot,_deadline]];
_group setVariable ["WAIT_Danger_CoverLease",[_actor,_generation,_deadline,+_spot]];
private _stats=_group getVariable ["WAIT_Danger_EngineStats",createHashMap];
_stats set ["coverMoves",((_stats getOrDefault ["coverMoves",0])+1) min 100000];
_stats set ["lastCoverActor",_actor];
_group setVariable ["WAIT_Danger_EngineStats",_stats];
true

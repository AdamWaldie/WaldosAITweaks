/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Applies a defence order on the machine that owns the group: moves soldiers to their spots and holds
 * them there facing their sectors.
 * Actor combat effectiveness and ownership are rechecked before movement and holding. Lost
 * group eligibility retires the job and published order instead of perpetually delaying it.
 *
 * Runs on the original owner and again on any new owner (WAIT_fnc_CortexDiscover), because unit
 * orders are held by the owning machine. A reserve reinforcement may pass only its newly reassigned
 * actors; established line soldiers retain their hold and route generation. A job stops each selected
 * soldier only on arrival and points him at
 * his sector. Each route leg has one native doMove owner. Each soldier has an independent
 * physical-progress watchdog: measured three-dimensional approach renews the lease; lateral
 * wandering does not. Inactivity causes a bounded route
 * refresh, and only exhausted refreshes record failure.
 * Scheduler delay and temporary Zeus ownership do not consume recovery attempts.
 * Delayed arrival/retry writes require the exact planned assignment and either the issued MOVE
 * destination or the unchanged pre-issue command. A newer command retires this actor's assignment
 * without a movement/watch write. Adoption additionally requires a matching published MOVE/HOLD
 * receipt for non-idle native commands; only explicit task callers supply fresh actors.
 * A temporarily reserved actor keeps its arrival job pending without aging its no-progress timer.
 * Locality and authority: internal owner-local executor; only server-forwarded remote context is accepted.
 * Published receipts support owner adoption, not independent client movement authority.
 *
 * Review contract: Each application resets local holding state and versions its arrival job. Old generations retire; ineligible groups receive no new movement commands.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: actors <ARRAY of OBJECT>, [] - optional changed subset; an empty array reapplies the complete
 *    published defence after initial placement or locality migration.
 * 2: fresh actors <ARRAY of OBJECT>, [] - only actors admitted by a new explicit defence
 *    or reserve commitment. Discovery never supplies this list. Both lists are limited to 64.
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [_group] call WAIT_fnc_CortexDefendApplyLocal;
 * Result: the defence line forms on this machine.
 * [_group,_reserve,_reserve] call WAIT_fnc_CortexDefendApplyLocal;
 * Result: only the newly committed reserve receives a route; the established line is untouched.
 *
 * Current callers: WAIT_fnc_CortexDefend, WAIT_fnc_CortexDefendStep and WAIT_fnc_CortexDiscover.
 */

params [["_group", grpNull, [grpNull]],["_actors",[],[[]]],["_freshActors",[],[[]]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {count _actors > 64} || {count _freshActors > 64}
    || {(_actors+_freshActors) findIf {!(_x isEqualType objNull)} >= 0}) exitWith {};
if (isNull _group || {!local _group} || {!([_group] call WAIT_fnc_CortexIsEligible)}) exitWith {};
private _fullApply=_actors isEqualTo [];
if (_fullApply) then {_actors=+units _group};
if (count _actors > 64) exitWith {};
private _nativeRoute=[_group] call WAIT_fnc_NativeOrderReceipt;
if (_nativeRoute isNotEqualTo (_group getVariable ["WAIT_Cortex_DefendNativeRoute",[]])) exitWith {
    [_group,false] call WAIT_fnc_CortexDefendRelease;
};
private _generation=_group getVariable ["WAIT_AIPass_DefendGeneration",0];
if (_fullApply || {_generation <= 0}) then {
    _generation=_generation+1;
    _group setVariable ["WAIT_AIPass_DefendGeneration",_generation];
};
_group setVariable ["WAIT_AIPass_DefendApplied", true];
private _routes=[];
private _adoptionCommandOwned={
    params ["_actor","_assignment"];
    private _command=currentCommand _actor;
    if (_actor in _freshActors || {_command == ""}) exitWith {true};
    private _receipt=_actor getVariable ["WAIT_Cortex_DefendMove",[]];
    private _valid=_receipt isEqualType [] && {count _receipt == 6}
        && {(_receipt select 0) isEqualTo _group}
        && {[1,2] findIf {!((_receipt select _x) isEqualType 0) || {!finite (_receipt select _x)} || {(_receipt select _x) < 0}} < 0}
        && {(_receipt select 2) <= (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {(_receipt select 4) isEqualTo _assignment}
        && {(_receipt select 3) isEqualType []} && {count (_receipt select 3) == 3}
        && {(_receipt select 3) findIf {!(_x isEqualType 0) || {!finite _x}} < 0};
    if (!_valid) exitWith {false};
    private _live=(expectedDestination _actor) param [0,[],[[]]];
    (_command == "MOVE" && {(_receipt select 5) == "MOVE"} && {count _live == 3}
        && {_live vectorDistance (_receipt select 3) <= 0.25})
        || {_command == "STOP" && {(_receipt select 5) == "HOLD"}
            && {(getPosATL _actor) vectorDistance (_assignment select 0) <= 3}}
};
private _rememberMove={
    params ["_actor","_target","_kind"];
    _actor setVariable ["WAIT_Cortex_DefendMove",[_group,
        _group getVariable ["WAIT_AIPass_DefendGeneration",-1],
        _group getVariable ["WAIT_AIPass_Epoch",0],+_target,
        +(_actor getVariable ["WAIT_AIPass_DefendPos",[]]),_kind],true];
};
// Recheck immediately before individual movement writes; scheduler eligibility is not a
// lease over a later Zeus, player or specialist takeover in the same callback.
private _mayIssueMovement = {
    params ["_actor"];
    private _free=!([_actor] call WAIT_fnc_CortexActorMoveReserved);
    !([_group] call WAIT_fnc_CortexExternalTakeover) && {local _actor} && {group _actor == _group}
        && {isNull objectParent _actor} && {_free} && {!isPlayer _actor}
        && {isNull remoteControlled _actor} && {[_actor] call WAIT_fnc_CortexCombatEffective}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
        && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
{
    _x setVariable ["WAIT_AIPass_DefendHolding", nil];
    _x setVariable ["WAIT_AIPass_DefendFailed",nil,true];
    private _routeGeneration=(_x getVariable ["WAIT_AIPass_DefendRouteGeneration",0])+1;
    _x setVariable ["WAIT_AIPass_DefendRouteGeneration",_routeGeneration];
    private _assignment = _x getVariable ["WAIT_AIPass_DefendPos", []];
    if ([_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
        && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)} && {_assignment isNotEqualTo []}) then {
        if ([_x,_assignment] call _adoptionCommandOwned) then {
            private _route=[_x,getPosATL _x,time,0,_routeGeneration,+_assignment,false,
                currentCommand _x,+((expectedDestination _x) param [0,[],[[]]]),formLeader _x];
            _routes pushBack _route;
            if ((getPosATL _x) vectorDistance (_assignment select 0) > 2 && {[_x] call _mayIssueMovement}) then {
                _x doMove (_assignment select 0);
                _route set [6,true];
                [_x,_assignment select 0,"MOVE"] call _rememberMove;
            };
        } else {
            // A published post alone cannot reclaim a newer native command on this owner.
            _x setVariable ["WAIT_AIPass_DefendPos",nil,true];
            _x setVariable ["WAIT_Cortex_DefendMove",nil,true];
        };
    };
} forEach _actors;
// A receipt records only commands issued by this job; it grants no general actor authority.
private _ownsRouteCommand={
    params ["_actor","_route"];
    private _command=currentCommand _actor;
    private _destination=(expectedDestination _actor) param [0,[],[[]]];
    if (_route select 6) exitWith {
        _command == "" || {_command == "MOVE" && {count _destination == 3}
            && {_destination vectorDistance ((_route select 5) select 0) <= 0.25}}
    };
    _command == (_route select 7) && {
        if (_command == "FOLLOW" && {!isNull (_route select 9)}) then {
            formLeader _actor == (_route select 9)
        } else {_destination isEqualTo (_route select 8)}
    }
};
[{
    params ["_job"];
    private _group = _job get "group";
    if (isNull _group || {!local _group} || {(_group getVariable ["WAIT_AIPass_Defend", []]) isEqualTo []}) exitWith {-1};
    if ((_group getVariable ["WAIT_AIPass_DefendGeneration", -1]) != (_job get "generation")
        || {(_group getVariable ["WAIT_AIPass_Epoch",0]) != (_job get "epoch")}
        || {([_group] call WAIT_fnc_NativeOrderReceipt) isNotEqualTo (_job get "nativeRoute")}) exitWith {-1};
    // External control has priority. Do not age or reissue an owned movement while Zeus is active.
    if !([_group] call WAIT_fnc_CortexIsEligible) exitWith {
        [_group,false] call WAIT_fnc_CortexDefendRelease;
        -1
    };
    private _mayIssueMovement = {
        params ["_actor"];
        private _free=!([_actor] call WAIT_fnc_CortexActorMoveReserved);
        !([_group] call WAIT_fnc_CortexExternalTakeover) && {local _actor} && {group _actor == _group}
            && {isNull objectParent _actor} && {_free} && {!isPlayer _actor}
            && {isNull remoteControlled _actor} && {[_actor] call WAIT_fnc_CortexCombatEffective}
            && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
            && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
            && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _pending = 0;
    private _routes=_job get "routes";
    private _ownsRouteCommand=_job get "ownsRouteCommand";
    private _rememberMove=_job get "rememberMove";
    {
        private _unit=_x;
        private _routeIndex=_routes findIf {(_x select 0) isEqualTo _unit};
        private _routeGeneration=if (_routeIndex >= 0) then {(_routes select _routeIndex) param [4,-1]} else {-1};
        private _assignment = _unit getVariable ["WAIT_AIPass_DefendPos", []];
        private _routeCurrent=_routeIndex >= 0
            && {(_unit getVariable ["WAIT_AIPass_DefendRouteGeneration",-2]) == _routeGeneration}
            && {[_unit] call WAIT_fnc_CortexCombatEffective} && {local _unit} && {!isPlayer _unit}
            && {group _unit == _group} && {_assignment isNotEqualTo []}
            && {_assignment isEqualTo ((_routes select _routeIndex) select 5)}
            && {!(_unit getVariable ["WAIT_AIPass_DefendHolding", false])}
            && {!(_unit getVariable ["WAIT_AIPass_DefendFailed",false])};
        if (_routeCurrent && {!([_unit,_routes select _routeIndex] call _ownsRouteCommand)}) then {
            // The current order belongs to somebody else. Retire metadata, never restore formation.
            _unit setVariable ["WAIT_AIPass_DefendPos",nil,true];
            _unit setVariable ["WAIT_Cortex_DefendMove",nil,true];
            _unit setVariable ["WAIT_AIPass_DefendHolding",nil];
            _unit setVariable ["WAIT_AIPass_DefendFailed",nil,true];
            _routeCurrent=false;
        };
        private _canIssue=_routeCurrent && {[_unit] call _mayIssueMovement};
        if (_routeCurrent && {!_canIssue}) then {
            // Deferral is not arrival or route failure. Keep the callback alive so an
            // expiring specialist reservation cannot silently abandon the defence post.
            _pending=_pending+1;
            (_routes select _routeIndex) set [2,time];
        };
        if (_canIssue) then {
            if ((getPosATL _unit) vectorDistance (_assignment select 0) <= 3
                && {abs (((getPosATL _unit) select 2)-((_assignment select 0) select 2)) <= 1.5}
                && {[_unit] call _mayIssueMovement}) then {
                doStop _unit;
                _unit doWatch ((_assignment select 0) getPos [60, _assignment select 1]);
                _unit setVariable ["WAIT_AIPass_DefendHolding", true];
                [_unit,_assignment select 0,"HOLD"] call _rememberMove;
            } else {
                _pending = _pending + 1;
                private _route=_routes select _routeIndex;
                _route params ["_routeUnit","_lastPosition","_lastProgress","_retries","_actorGeneration"];
                private _destination=_assignment select 0;
                // Only approach to the committed post renews progress, not circles around it.
                if ((_lastPosition vectorDistance _destination)-((getPosATL _unit) vectorDistance _destination) >= 1) then {
                    _route set [1,getPosATL _unit];
                    _route set [2,time];
                } else {
                    if (time-_lastProgress >= 15) then {
                        if (_retries < 3 && {[_unit] call _mayIssueMovement}) then {
                            _unit doMove (_assignment select 0);
                            _route set [6,true];
                            [_unit,_assignment select 0,"MOVE"] call _rememberMove;
                            _route set [2,time];
                            _route set [3,_retries+1];
                        } else {
                            _unit setVariable ["WAIT_AIPass_DefendFailed",true,true];
                            _pending=_pending-1;
                            diag_log format ["[WAIT] Defence arrival failed after bounded replans unit=%1 remaining=%2",_unit,_unit distance2D (_assignment select 0)];
                        };
                    };
                };
            };
        };
    } forEach (_job get "actors");
    [2, -1] select (_pending == 0)
}, createHashMapFromArray [["group", _group], ["actors",+_actors], ["routes",_routes], ["ownsRouteCommand",_ownsRouteCommand], ["rememberMove",_rememberMove],
    ["epoch",_group getVariable ["WAIT_AIPass_Epoch",0]], ["nativeRoute",_nativeRoute], ["generation", _generation]], 1] call WAIT_fnc_CortexQueueJob;


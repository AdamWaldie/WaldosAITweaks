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
 * physical-progress watchdog: measured travel renews the lease, inactivity causes a bounded route
 * refresh, and only exhausted refreshes record failure.
 * Scheduler delay and temporary Zeus ownership do not consume recovery attempts.
 * Locality and authority: call where the group is local.
 *
 * Review contract: Each application resets local holding state and versions its arrival job. Old generations retire; ineligible groups receive no new movement commands.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: actors <ARRAY of OBJECT>, [] - optional changed subset; an empty array reapplies the complete
 *    published defence after initial placement or locality migration.
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [_group] call WAIT_fnc_CortexDefendApplyLocal;
 * Result: the defence line forms on this machine.
 * [_group,_reserve] call WAIT_fnc_CortexDefendApplyLocal;
 * Result: only the newly committed reserve receives a route; the established line is untouched.
 *
 * Current callers: WAIT_fnc_CortexDefend, WAIT_fnc_CortexDefendStep and WAIT_fnc_CortexDiscover.
 */

params [["_group", grpNull, [grpNull]],["_actors",[],[[]]]];
if (isNull _group || {!local _group} || {!([_group] call WAIT_fnc_CortexIsEligible)}) exitWith {};
private _fullApply=_actors isEqualTo [];
if (_fullApply) then {_actors=+units _group};
private _generation=_group getVariable ["WAIT_AIPass_DefendGeneration",0];
if (_fullApply || {_generation <= 0}) then {
    _generation=_generation+1;
    _group setVariable ["WAIT_AIPass_DefendGeneration",_generation];
};
_group setVariable ["WAIT_AIPass_DefendApplied", true];
private _routes=[];
// Recheck immediately before individual movement writes; scheduler eligibility is not a
// lease over a later Zeus, player or specialist takeover in the same callback.
private _mayIssueMovement = {
    !([_group] call WAIT_fnc_CortexExternalTakeover)
};
{
    _x setVariable ["WAIT_AIPass_DefendHolding", nil];
    _x setVariable ["WAIT_AIPass_DefendFailed",nil,true];
    private _routeGeneration=(_x getVariable ["WAIT_AIPass_DefendRouteGeneration",0])+1;
    _x setVariable ["WAIT_AIPass_DefendRouteGeneration",_routeGeneration];
    private _assignment = _x getVariable ["WAIT_AIPass_DefendPos", []];
    if ([_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
        && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)} && {_assignment isNotEqualTo []}) then {
        _routes pushBack [_x,getPosATL _x,time,0,_routeGeneration];
        if (_x distance2D (_assignment select 0) > 2 && {call _mayIssueMovement}) then {
            _x doMove (_assignment select 0);
        };
    };
} forEach _actors;
[{
    params ["_job"];
    private _group = _job get "group";
    if (isNull _group || {!local _group} || {(_group getVariable ["WAIT_AIPass_Defend", []]) isEqualTo []}) exitWith {-1};
    if ((_group getVariable ["WAIT_AIPass_DefendGeneration", -1]) != (_job get "generation")) exitWith {-1};
    // External control has priority. Do not age or reissue an owned movement while Zeus is active.
    if !([_group] call WAIT_fnc_CortexIsEligible) exitWith {
        [_group,false] call WAIT_fnc_CortexDefendRelease;
        -1
    };
    private _mayIssueMovement = {
        !([_group] call WAIT_fnc_CortexExternalTakeover)
    };
    private _pending = 0;
    private _routes=_job get "routes";
    {
        private _unit=_x;
        private _routeIndex=_routes findIf {(_x select 0) isEqualTo _unit};
        private _routeGeneration=if (_routeIndex >= 0) then {(_routes select _routeIndex) param [4,-1]} else {-1};
        private _assignment = _unit getVariable ["WAIT_AIPass_DefendPos", []];
        if (_routeIndex >= 0
            && {(_unit getVariable ["WAIT_AIPass_DefendRouteGeneration",-2]) == _routeGeneration}
            && {[_unit] call WAIT_fnc_CortexCombatEffective} && {local _unit} && {!isPlayer _unit}
            && {!([_group,false,_unit] call WAIT_fnc_CortexExternalTakeover)} && {_assignment isNotEqualTo []}
            && {!(_unit getVariable ["WAIT_AIPass_DefendHolding", false])}
            && {!(_unit getVariable ["WAIT_AIPass_DefendFailed",false])}) then {
            if (_unit distance2D (_assignment select 0) <= 3) then {
                doStop _unit;
                _unit doWatch ((_assignment select 0) getPos [60, _assignment select 1]);
                _unit setVariable ["WAIT_AIPass_DefendHolding", true];
            } else {
                _pending = _pending + 1;
                private _route=_routes select _routeIndex;
                _route params ["_routeUnit","_lastPosition","_lastProgress","_retries","_actorGeneration"];
                if (_unit distance2D _lastPosition >= 1) then {
                    _route set [1,getPosATL _unit];
                    _route set [2,time];
                } else {
                    if (time-_lastProgress >= 15) then {
                        if (_retries < 3 && {call _mayIssueMovement}) then {
                            _unit doMove (_assignment select 0);
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
}, createHashMapFromArray [["group", _group], ["actors",+_actors], ["routes",_routes], ["generation", _generation]], 1] call WAIT_fnc_CortexQueueJob;


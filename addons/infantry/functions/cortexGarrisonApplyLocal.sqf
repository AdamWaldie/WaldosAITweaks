/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Applies a garrison order on the machine that owns the group: moves soldiers to their positions,
 * locks them there, and installs the duck-under-fire handlers.
 *
 * disableAI and event handlers exist only on the machine that set them, so this runs on the original
 * owner and again on any new owner (WAIT_fnc_CortexDiscover). Interior arrival requires a
 * 1.5 m/0.75 m floor-aware visit within the building bounds without an intervening building wall.
 * Exterior arrival requires a 2 m/0.75 m supported exterior pose with an actual observation ray.
 * Other actors retain their native approach. Only validated physical arrival locks PATH; a fixed safety deadline records
 * failure and leaves movement enabled rather than renewing forever around an unreachable doorway.
 * Arrival and failure release only an unchanged WAIT approach speed cap; newer speed commands survive.
 * Saved and applied speed values are published with the actor so owner adoption preserves restoration.
 * Approach stance also has a public applied-value lease for unchanged-stance restoration on release.
 * Transform-bound assignments are checked before initial/deferred commands and alternate-slot selection.
 * Reapplication preserves an already local, physically arrived PATH hold without reenabling
 * movement or issuing another stop. New owners still install their actual local hold normally.
 * Moved or deleted buildings release affected actors through the existing partial cleanup path.
 * Owner adoption preserves published exhausted-route failures; only a fresh explicit order, whose
 * release clears old assignments and failures, admits another attempt at the same position.
 * The original server-time approach deadline is public and survives owner adoption; held posts
 * remain valid after it expires, but unfinished routes cannot acquire another 240 seconds.
 * When every surviving assigned actor exhausted its route, the job records INCOMPLETE and
 * releases the failed garrison rather than retaining an empty stationary tactical intent.
 * Surplus exterior security searches at most one actor per callback and three times per actor.
 * Valid slots observe real exits, retain distinct destinations and use the original order deadline.
 * Each search counts live reservations once; failed/incapacitated actors do not claim exit coverage.
 * Physical occupants remain excluded by the shared geometry validator. Rejected-point history
 * also survives adoption so a one-exit building does not repeat the same failed cover candidate.
 * One short-range engine empty-space query can propose an uncovered alternate after rejection.
 * It must pass the same live geometry/observation checks; neither proposal proves path arrival.
 * Routes stage at a real entrance when approaching from more than 30 m, then commit directly to the
 * interior destination. The initial route releases formation once with doStop; recovery, alternate
 * entrance and reassignment legs use only one native doMove destination. Pairing a repeated stop with
 * setDestination previously created a second route owner and could leave an actor oscillating or
 * stationary at a threshold. A machine-local, damage- and transform-aware building topology cache shares that
 * entrance-anchor lookup between soldiers while refreshing a materially changed structure. The queued
 * callback restores this cache from its job payload before invoking deferred anchor recovery. Units move
 * upright at assault pace until they reach their post.
 * Nearby units try the interior destination directly, matching the engine path that works on viable
 * building models, then try up to four usable entrances nearest-first as bounded recovery.
 * Twelve seconds without two metres of three-dimensional approach progress retries the current leg twice, including commands
 * still reporting MOVE. While still approaching the building it then advances to another entrance.
 * Once the soldier has reached an entrance, an interior stall reassigns a free alternative position
 * instead of sending the soldier back outside through another door. Reassignment is attempted twice
 * before the position is reported unreachable. Opening an unlocked door does not reset the physical-progress timer. A replacement
 * order or locality change retires the old job; the new owner rebuilds its local route.
 * Handlers: Suppressed and Hit drop the soldier to a lower stance for 4-8 s, then restore the stance
 * he held when the order was applied only if the Cortex duck stance still remains.
 * Later stance changes are preserved. Handlers do nothing after release or Zeus takeover.
 * Locality and authority: call where the group is local.
 * Each actor must remain combat-effective and free of player/specialist ownership before
 * initial movement or an arrival PATH lock; captive and surrendered actors are never retasked.
 * Actor reservations and finite native service, boarding and assembly tasks defer garrison commands
 * independently, allowing other available soldiers to continue their routes. Mission-owned MOVE
 * restrictions also prevent commands; this controller never enables MOVE.
 *
 * Review contract: Arrival jobs carry a local generation token, so replacing an order retires older work. PATH restoration is recorded publicly only when this pass disables it.
 *
 * Arguments:
 * 0: group <GROUP>
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [_group] call WAIT_fnc_CortexGarrisonApplyLocal;
 * Result: the garrison is live on this machine.
 *
 * Current callers: WAIT_fnc_CortexGarrison and WAIT_fnc_CortexDiscover.
 */

params [["_group", grpNull, [grpNull]]];
if (isNull _group || {!local _group} || {!([_group] call WAIT_fnc_CortexIsEligible)}) exitWith {};
private _assignmentValid = {
    params ["_assignment"];
    private _transform=_assignment param [3,[]];
    if (_transform isEqualTo []) exitWith {true};
    private _building=_assignment param [2,objNull];
    !isNull _building && {_transform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
};
private _invalidActors=(units _group) select {
    local _x && {!([_x getVariable ["WAIT_AIPass_GarrisonPos",[]]] call _assignmentValid)}
};
if (_invalidActors isNotEqualTo []) then {[_group,true,_invalidActors] call WAIT_fnc_CortexGarrisonRelease};
if ((_group getVariable ["WAIT_AIPass_Garrison",[]]) isEqualTo []) exitWith {};
private _deadline=_group getVariable ["WAIT_Cortex_GarrisonDeadline",-1];
if (_deadline < 0) then {
    _deadline=serverTime+240;
    _group setVariable ["WAIT_Cortex_GarrisonDeadline",_deadline,true];
};
private _generation = (_group getVariable ["WAIT_AIPass_GarrisonGeneration", 0]) + 1;
_group setVariable ["WAIT_AIPass_GarrisonGeneration", _generation];
_group setVariable ["WAIT_AIPass_GarrisonApplied", true];
_group setVariable ["WAIT_Cortex_GarrisonPending",-1,true];
private _routes = createHashMap;
private _buildingTopologyCache=missionNamespace getVariable ["WAIT_Cortex_GarrisonTopology",createHashMap];
// Every later movement write is guarded again because an external controller can take
// ownership after this application passed its initial eligibility check.
private _mayIssueMovement = {
    params ["_actor"];
    private _reservation=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
    private _free=_reservation isEqualTo []
        || {_reservation isEqualType [] && {count _reservation == 3} && {(_reservation param [2,1e12,[0]]) <= time}};
    !([_group] call WAIT_fnc_CortexExternalTakeover) && {local _actor} && {group _actor == _group} && {isNull objectParent _actor}
        && {_free} && {isNull remoteControlled _actor} && {!isPlayer _actor}
        && {_actor checkAIFeature "MOVE"}
        && {[_actor] call WAIT_fnc_CortexCombatEffective}
        && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
        && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
private _rememberMove = {
    params ["_actor","_target"];
    _actor setVariable ["WAIT_Cortex_GarrisonMove",[_group,_group getVariable ["WAIT_AIPass_GarrisonGeneration",-1],_group getVariable ["WAIT_AIPass_Epoch",0],+_target],true];
};
private _buildingEntries = {
    params ["_building","_unit","_destination"];
    if (isNull _building) exitWith {[]};
    private _entries=[];
    for "_index" from 0 to 31 do {
        private _entry=_building buildingExit _index;
        // Preserve real model coordinates. Buried path nodes are not usable
        // physical recovery stops; flattening them would invent an entrance.
        private _entryASL=AGLToASL _entry;
        private _aboveTerrain=(_entryASL select 2) >= (getTerrainHeightASL _entry)-0.05;
        if (count _entry >= 3 && {_entry isNotEqualTo [0,0,0]} && {_entry distance2D _destination < 80}
            && {_aboveTerrain}) then {
            _entries pushBackUnique _entry;
        };
    };
    _entries=[_entries,[],{_x distance2D getPosATL _unit},"ASCEND"] call BIS_fnc_sortBy;
    _entries resize ((count _entries) min 4);
    _entries
};
// Shared read-only predicate also fences casualty promotions against lost exit observation.
private _assignmentArrived=WAIT_fnc_CortexGarrisonArrived;
private _buildingAnchor = {
    params ["_building","_entry","_destination"];
    if (isNull _building || {_entry isEqualTo []}) exitWith {_destination};
    private _cacheKey=netId _building;
    if (_cacheKey == "") then {_cacheKey=str _building};
    private _damage=damage _building;
    private _cached=_buildingTopologyCache getOrDefault [_cacheKey,[]];
    // Cached positions are world-space: curator movement invalidates them even
    // when the building remains undamaged. Old receipts rebuild once on use.
    private _transform=[getPosWorld _building,vectorDir _building,vectorUp _building];
    if (count _cached < 3 || {abs ((_cached select 0)-_damage) > 0.05}
        || {(_cached select 2) isNotEqualTo _transform}) then {
        _cached=[_damage,+(_building buildingPos -1),_transform];
        _buildingTopologyCache set [_cacheKey,_cached];
        missionNamespace setVariable ["WAIT_Cortex_GarrisonTopology",_buildingTopologyCache];
    };
    private _positions=+(_cached select 1);
    if (_positions isEqualTo []) exitWith {_destination};
    _positions=[_positions,[],{_x distance2D _entry},"ASCEND"] call BIS_fnc_sortBy;
    +(_positions select 0)
};
{
    private _unit = _x;
    private _assignment = _unit getVariable ["WAIT_AIPass_GarrisonPos", []];
    if (local _unit && {!isPlayer _unit} && {_assignment isNotEqualTo []} && {serverTime > _deadline}
        && {!([_unit,_assignment] call _assignmentArrived)}) then {
        // Expired adoption does not enter the ordinary route callback. Retire an unchanged
        // approach cap here, using the same actor-authority guard before any speed write.
        if ([_unit] call _mayIssueMovement
            && {!isNil {_unit getVariable "WAIT_Cortex_GarrisonForcedSpeed"}}
            && {abs ((getForcedSpeed _unit)-(_unit getVariable ["WAIT_Cortex_GarrisonAppliedSpeed",-2])) <= 0.1}) then {
            _unit forceSpeed (_unit getVariable ["WAIT_Cortex_GarrisonForcedSpeed",-1]);
        };
        _unit setVariable ["WAIT_AIPass_GarrisonFailed",true,true];
    };
    if ([_unit] call WAIT_fnc_CortexCombatEffective && {local _unit} && {!isPlayer _unit}
        && {!([_group,false,_unit] call WAIT_fnc_CortexExternalTakeover)}
        && {_assignment isNotEqualTo []} && {!(_unit getVariable ["WAIT_AIPass_GarrisonFailed",false])}
        && {[_unit] call _mayIssueMovement}) then {
        if (isNil {_unit getVariable "WAIT_AIPass_GarrisonStance"}) then {_unit setVariable ["WAIT_AIPass_GarrisonStance", unitPos _unit, true]};
        if (isNil {_unit getVariable "WAIT_Cortex_GarrisonForcedSpeed"}) then {
            _unit setVariable ["WAIT_Cortex_GarrisonForcedSpeed",getForcedSpeed _unit,true];
        };
        private _heldInPlace=(_unit getVariable ["WAIT_AIPass_GarrisonDisabledPath",false])
            && {!(_unit checkAIFeature "PATH")}
            && {!(currentCommand _unit in ["MOVE","FOLLOW"])}
            && {[_unit,_assignment] call _assignmentArrived};
        if (_unit getVariable ["WAIT_AIPass_GarrisonDisabledPath", false] && {!_heldInPlace}) then {_unit enableAI "PATH"};
        if !(_unit getVariable ["WAIT_AIPass_GarrisonHandlers", false]) then {
            _unit setVariable ["WAIT_AIPass_GarrisonHandlers", true];
            private _duck = {
                params ["_unit"];
                if (!local _unit || {isPlayer _unit} || {!([_unit] call WAIT_fnc_CortexCombatEffective)} || {(_unit getVariable ["WAIT_AIPass_GarrisonPos", []]) isEqualTo []}
                    || {!([group _unit] call WAIT_fnc_CortexIsEligible)} || {[group _unit,false,_unit] call WAIT_fnc_CortexExternalTakeover}) exitWith {};
                if (time < (_unit getVariable ["WAIT_AIPass_DuckUntil", -1])) exitWith {};
                private _until = time + 4 + random 4;
                _unit setVariable ["WAIT_AIPass_DuckUntil", _until];
                private _duckStance=["MIDDLE", "DOWN"] select ((unitPos _unit) == "MIDDLE");
                _unit setVariable ["WAIT_Cortex_GarrisonDuckStance",_duckStance,true];
                _unit setUnitPos _duckStance;
                [{
                    params ["_unit", "_until"];
                    if ([_unit] call WAIT_fnc_CortexCombatEffective && {local _unit} && {!isPlayer _unit} && {(_unit getVariable ["WAIT_AIPass_DuckUntil", -1]) == _until}
                        && {(_unit getVariable ["WAIT_AIPass_GarrisonPos", []]) isNotEqualTo []}
                        && {[group _unit] call WAIT_fnc_CortexIsEligible}
                        && {!([group _unit,false,_unit] call WAIT_fnc_CortexExternalTakeover)}) then {
                        if (unitPos _unit == (_unit getVariable ["WAIT_Cortex_GarrisonDuckStance", ""])) then {
                            _unit setUnitPos (_unit getVariable ["WAIT_AIPass_GarrisonStance", "AUTO"]);
                        };
                        _unit setVariable ["WAIT_Cortex_GarrisonDuckStance",nil,true];
                    };
                }, [_unit, _until], _until - time] call CBA_fnc_waitAndExecute;
            };
            _unit setVariable ["WAIT_AIPass_GarrisonHandlerIds", [
                ["Suppressed", _unit addEventHandler ["Suppressed", _duck]],
                ["Hit", _unit addEventHandler ["Hit", _duck]]
            ]];
        };
        // Release the former formation task only while WAIT still owns movement. A curator or
        // specialist can take over between setup and this first individual building command.
        if (!_heldInPlace && {[_unit] call _mayIssueMovement}) then {doStop _unit};
        private _destination = _assignment select 0;
        private _building = _assignment param [2,objNull];
        private _entries=if ((_assignment param [4,"INTERIOR"]) == "EXTERIOR") then {[]} else {[_building,_unit,_destination] call _buildingEntries;};
        private _approach = _entries isNotEqualTo [] && {_unit distance2D _destination > 30};
        private _entryIndex = [-1,0] select _approach;
        private _target = if (_approach) then {_entries select 0} else {_destination};
        private _anchor=if (_approach) then {[_building,_target,_destination] call _buildingAnchor} else {[]};
        _routes set [netId _unit,[_target,_approach,getPosATL _unit,time,0,[str _destination],0,_entries,_entryIndex,_anchor,false]];
        if (!([_unit,_assignment] call _assignmentArrived) && {[_unit] call _mayIssueMovement}) then {
            _unit setVariable ["WAIT_Cortex_GarrisonAppliedStance","UP",true];
            _unit setUnitPos "UP";
            _unit forceSpeed 4;
            // Record the exact value WAIT applied.  Release restores the previous value only
            // while this lease is still intact, so a later controller's forced speed survives.
            _unit setVariable ["WAIT_Cortex_GarrisonAppliedSpeed",4,true];
            _unit doMove _target; [_unit,_target] call _rememberMove;
        };
    };
} forEach units _group;
[{
    params ["_job"];
    private _group = _job get "group";
    private _rememberMove = _job get "rememberMove";
    private _buildingTopologyCache = _job get "buildingTopologyCache";
    if (isNull _group || {!local _group} || {(_group getVariable ["WAIT_AIPass_Garrison", []]) isEqualTo []}) exitWith {-1};
    if ((_group getVariable ["WAIT_AIPass_GarrisonGeneration", -1]) != (_job get "generation")) exitWith {-1};
    // Retire the hold immediately when a player, Zeus or specialist controller owns the group.
    // Returning a delay alone would leave WAIT's PATH lock and published assignment behind.
    if !([_group] call WAIT_fnc_CortexIsEligible) exitWith {
        [_group,false] call WAIT_fnc_CortexGarrisonRelease;
        -1
    };
    private _assignmentValid=_job get "assignmentValid";
    private _assignmentArrived=_job get "assignmentArrived";
    private _invalidActors=(units _group) select {
        local _x && {!([_x getVariable ["WAIT_AIPass_GarrisonPos",[]]] call _assignmentValid)}
    };
    if (_invalidActors isNotEqualTo []) then {[_group,true,_invalidActors] call WAIT_fnc_CortexGarrisonRelease};
    if ((_group getVariable ["WAIT_AIPass_Garrison",[]]) isEqualTo []) exitWith {-1};
    private _mayIssueMovement = {
        params ["_actor"];
        private _reservation=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
        private _free=_reservation isEqualTo []
            || {_reservation isEqualType [] && {count _reservation == 3} && {(_reservation param [2,1e12,[0]]) <= time}};
        private _command=currentCommand _actor;
        private _receipt=_actor getVariable ["WAIT_Cortex_GarrisonMove",[]];
        private _live=(expectedDestination _actor) param [0,[]];
        private _commandOwned=!(_command in ["MOVE","FOLLOW"])
            || {_command == "MOVE" && {count _receipt == 4}
                && {(_receipt select 0) == _group}
                && {(_receipt select 1) == (_job get "generation")}
                && {(_receipt select 2) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
                && {count _live == 3} && {count (_receipt select 3) == 3}
                && {_live vectorDistance (_receipt select 3) <= 0.25}};
        !([_group] call WAIT_fnc_CortexExternalTakeover) && {local _actor} && {group _actor == _group} && {isNull objectParent _actor}
            && {_commandOwned} && {_free} && {isNull remoteControlled _actor} && {!isPlayer _actor}
        && {_actor checkAIFeature "MOVE"}
            && {[_actor] call WAIT_fnc_CortexCombatEffective}
            && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
            && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _pending = 0;
    private _exteriorSearchBudget=1;
    {
        private _assignment = _x getVariable ["WAIT_AIPass_GarrisonPos", []];
        if ((_assignment param [4,"INTERIOR"]) == "EXTERIOR_PENDING"
            && {!(_x getVariable ["WAIT_AIPass_GarrisonFailed",false])}) then {
            private _actor=_x;
            private _attempts=_actor getVariable ["WAIT_Cortex_GarrisonExteriorAttempts",0];
            if (serverTime > (_job get "deadline") || {_attempts >= 3}) then {
                _actor setVariable ["WAIT_AIPass_GarrisonFailed",true,true];
                diag_log format ["[WAIT] Garrison exterior selection failed unit=%1 attempts=%2",_actor,_attempts];
            } else {
                _pending=_pending+1;
                if (_exteriorSearchBudget > 0 && {_actor checkAIFeature "PATH"} && {[_actor] call _mayIssueMovement}) then {
                    _exteriorSearchBudget=0;
                    _actor setVariable ["WAIT_Cortex_GarrisonExteriorAttempts",_attempts+1,true];
                    private _history=+((_actor getVariable ["WAIT_Cortex_GarrisonExteriorTried",[]]) select [0,3]);
                    private _targetHistory=+((_actor getVariable ["WAIT_Cortex_GarrisonExteriorTargets",[]]) select [0,6]);
                    private _buildings=[];
                    {
                        private _building=_x param [2,objNull];
                        if (!isNull _building && {[_x] call _assignmentValid}) then {_buildings pushBackUnique _building};
                    } forEach ((_group getVariable ["WAIT_Cortex_GarrisonCandidates",[]]) select [0,64]);
                    private _exitCounts=createHashMap;
                    private _observerLanes=[];
                    private _taken=+_targetHistory;
                    {
                        private _other=_x getVariable ["WAIT_AIPass_GarrisonPos",[]];
                        if (_x != _actor && {[_x] call WAIT_fnc_CortexCombatEffective}
                            && {!(_x getVariable ["WAIT_AIPass_GarrisonFailed",false])}
                            && {_other isNotEqualTo []}) then {
                            _taken pushBack (_other select 0);
                            if ((_other param [4,"INTERIOR"]) == "EXTERIOR") then {
                                _observerLanes pushBack [+(_other select 0),+(_other select 5)];
                                private _exitKey=str [_other param [2,objNull],_other param [6,[]]];
                                _exitCounts set [_exitKey,(_exitCounts getOrDefault [_exitKey,0])+1];
                            };
                        };
                    } forEach units _group;
                    private _ranks=[];
                    {
                        private _building=_x;
                        private _entries=[_building,_actor,getPosATL _building] call (_job get "buildingEntries");
                        {
                            private _entry=_x;
                            private _used=_exitCounts getOrDefault [str [_building,_entry],0];
                            _ranks pushBack [[0,1] select ([_building,_entry] in _history),_used,
                                _actor distance2D _entry,count _ranks,_building,+_entry];
                        } forEach _entries;
                    } forEach (_buildings select [0,16]);
                    _ranks sort true;
                    if (_ranks isNotEqualTo []) then {
                        private _row=_ranks select 0;
                        private _building=_row select 4;
                        private _entry=_row select 5;
                        _history pushBackUnique [_building,+_entry];
                        _actor setVariable ["WAIT_Cortex_GarrisonExteriorTried",_history,true];
                        private _bounds=boundingBoxReal _building;
                        private _centre=_building modelToWorld (((_bounds select 0) vectorAdd (_bounds select 1)) vectorMultiply 0.5);
                        private _outward=_centre getDir _entry;
                        private _search=_entry getPos [7,_outward];
                        private _watch=_entry getPos [2,_outward];
                        _watch set [2,(_entry select 2)+1.2];
                        private _cover=[_search,_centre,12,_taken,_group] call WAIT_fnc_CortexFindCover;
                        private _target=_cover select 0;
                        _targetHistory pushBackUnique +_target;
                        private _covered=_cover select 1;
                        private _entries=[];
                        for "_exitIndex" from 0 to 31 do {
                            private _exit=_building buildingExit _exitIndex;
                            if (count _exit == 3 && {_exit isNotEqualTo [0,0,0]}
                                && {((AGLToASL _exit) select 2) >= (getTerrainHeightASL _exit)-0.05}) then {
                                _entries pushBackUnique _exit;
                            };
                        };
                        private _valid=[_actor,_building,_target,_entry,_watch,_entries,_taken,_observerLanes] call WAIT_fnc_BuildingExteriorCandidate;
                        if (!_valid) then {
                            private _empty=[_actor,_search,_entry,_taken,_observerLanes] call WAIT_fnc_BuildingExteriorProposal;
                            if (count _empty == 3) then {
                                // This is a ground exterior proposal, never a fabricated interior node.
                                _empty set [2,0];
                                _targetHistory pushBackUnique +_empty;
                                if ([_actor,_building,_empty,_entry,_watch,_entries,_taken,_observerLanes] call WAIT_fnc_BuildingExteriorCandidate) then {
                                    _target=+_empty; _valid=true; _covered=false;
                                };
                            };
                        };
                        _actor setVariable ["WAIT_Cortex_GarrisonExteriorTargets",_targetHistory,true];
                        if (_valid && {[_actor] call _mayIssueMovement}) then {
                            _assignment=[+_target,_target getDir _watch,_building,
                                [getPosWorld _building,vectorDir _building,vectorUp _building],"EXTERIOR",+_watch,+_entry,_covered];
                            _actor setVariable ["WAIT_AIPass_GarrisonPos",_assignment,true];
                            (_job get "routes") set [netId _actor,[+_target,false,getPosATL _actor,time,0,[str _target],0,[],-1,[],false]];
                            _actor setVariable ["WAIT_Cortex_GarrisonAppliedStance","UP",true];
                            _actor setUnitPos "UP";
                            _actor setVariable ["WAIT_Cortex_GarrisonAppliedSpeed",4,true];
                            _actor forceSpeed 4;
                            _actor doMove _target; [_actor,_target] call _rememberMove;
                        };
                    };
                };
            };
        };
        // A temporarily unconscious member keeps a pending route until the order deadline.
        // Recovery before then resumes naturally without issuing movement while incapacitated.
        if (alive _x && {local _x} && {!isPlayer _x} && {lifeState _x == "INCAPACITATED"}
            && {_assignment isNotEqualTo []} && {serverTime <= (_job get "deadline")}) then {
            _pending=_pending+1;
        };
        if ([_x] call WAIT_fnc_CortexCombatEffective && {local _x} && {!isPlayer _x}
            && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}
            && {_assignment isNotEqualTo []} && {(_assignment param [4,"INTERIOR"]) != "EXTERIOR_PENDING"}
            && {_x checkAIFeature "PATH"} && {!(_x getVariable ["WAIT_AIPass_GarrisonFailed",false])}) then {
            private _openedDoor = if ((_assignment param [4,"INTERIOR"]) != "EXTERIOR" && {[_x] call _mayIssueMovement}) then {
                [_x,_assignment param [2,objNull],["GARRISON",_job get "generation"]] call WAIT_fnc_CortexBuildingDoor
            } else {false};
            if ([_x,_assignment] call _assignmentArrived) then {
                // Arrival locks are movement ownership too. Do not freeze or retask a soldier
                // whose group changed owner while this bounded callback was already running.
                if ([_x] call _mayIssueMovement) then {
                    doStop _x;
                    if (!isNil {_x getVariable "WAIT_Cortex_GarrisonForcedSpeed"}
                        && {abs ((getForcedSpeed _x)-(_x getVariable ["WAIT_Cortex_GarrisonAppliedSpeed",4])) <= 0.1}) then {
                        _x forceSpeed (_x getVariable ["WAIT_Cortex_GarrisonForcedSpeed",-1]);
                    };
                    _x setVariable ["WAIT_AIPass_GarrisonDisabledPath", true, true];
                    _x disableAI "PATH";
                    private _watch=if ((_assignment param [4,"INTERIOR"]) == "EXTERIOR") then {_assignment select 5} else {(_assignment select 0) getPos [50,_assignment select 1]};
                    _x doWatch _watch;
                };
            } else {
                if (serverTime > (_job get "deadline")) then {
                    if ([_x] call _mayIssueMovement
                        && {!isNil {_x getVariable "WAIT_Cortex_GarrisonForcedSpeed"}}
                        && {abs ((getForcedSpeed _x)-(_x getVariable ["WAIT_Cortex_GarrisonAppliedSpeed",4])) <= 0.1}) then {
                        _x forceSpeed (_x getVariable ["WAIT_Cortex_GarrisonForcedSpeed",-1]);
                    };
                    _x setVariable ["WAIT_AIPass_GarrisonFailed",true,true];
                    diag_log format ["[WAIT] Garrison arrival failed unit=%1 remaining=%2",_x,_x distance (_assignment select 0)];
                } else {
                    _pending = _pending + 1;
                    private _route = (_job get "routes") getOrDefault [netId _x,[_assignment select 0,false,getPosATL _x,time,0,[str (_assignment select 0)],0,[],-1,[],false]];
                    _route params ["_target","_approach","_lastPosition","_lastProgress","_retries","_attempted","_reassignments","_entries","_entryIndex","_anchor","_crossing"];
                    // Door requests can repeat on multi-door buildings. Reissue the current move, but
                    // only measured travel renews progress so an actor at a threshold cannot wait forever.
                    if (_openedDoor && {[_x] call _mayIssueMovement}) then {_x doMove _target; [_x,_target] call _rememberMove;};
                    if (_approach && {_x distance2D _target <= 5} && {[_x] call _mayIssueMovement}) then {
                        // Some building models expose an exterior entry but no usable interior
                        // crossing anchor. Proceed toward the assigned building position instead of
                        // issuing an empty target and aborting the owner-local garrison callback.
                        private _crossTarget=if (count _anchor >= 3) then {_anchor} else {_assignment select 0};
                        _route set [0,_crossTarget];
                        _route set [1,false];
                        _route set [10,count _anchor >= 3];
                        _route set [2,getPosATL _x];
                        _route set [3,time];
                        _x doMove _crossTarget; [_x,_crossTarget] call _rememberMove;
                    } else {
                        if (_crossing && {count _anchor >= 3} && {_x distance _anchor <= 2} && {[_x] call _mayIssueMovement}) then {
                            _route set [0,_assignment select 0]; _route set [2,getPosATL _x];
                            _route set [3,time]; _route set [4,0]; _route set [10,false];
                            _x doMove (_assignment select 0); [_x,(_assignment select 0)] call _rememberMove;
                        } else {
                        // Lateral wandering does not renew a stalled interior route. Include floor height.
                        if ((_lastPosition vectorDistance _target)-((getPosATL _x) vectorDistance _target) >= 2) then {
                            _route set [2,getPosATL _x]; _route set [3,time];
                        } else {
                            if (time-_lastProgress >= 12) then {
                                if (_retries < 2 && {[_x] call _mayIssueMovement}) then {
                                    _x doMove _target; [_x,_target] call _rememberMove;
                                    _route set [3,time]; _route set [4,_retries+1];
                                } else {
                                    // Alternate exterior entrances recover a failed approach. Once an
                                    // entrance was reached, cycling outside creates the visible door
                                    // orbit and cannot repair a broken interior navigation path.
                                    private _nextEntry=if (_approach || {_crossing}) then {_entryIndex+1} else {count _entries};
                                    if (_nextEntry < count _entries && {[_x] call _mayIssueMovement}) then {
                                        private _nextTarget=_entries select _nextEntry;
                                        _route set [0,_nextTarget];
                                        _route set [1,true];
                                        _route set [2,getPosATL _x];
                                        _route set [3,time];
                                        _route set [4,0];
                                        _route set [8,_nextEntry];
                                        _route set [9,[_assignment param [2,objNull],_nextTarget,_assignment select 0] call (_job get "buildingAnchor")];
                                        _route set [10,false];
                                        _x doMove _nextTarget; [_x,_nextTarget] call _rememberMove;
                                        diag_log format ["[WAIT] Garrison trying alternate entrance unit=%1 entrance=%2/%3 remaining=%4",_x,_nextEntry+1,count _entries,_x distance (_assignment select 0)];
                                    } else {
                                    private _occupied=(units _group) apply {
                                        private _otherAssignment=_x getVariable ["WAIT_AIPass_GarrisonPos",[]];
                                        if (_otherAssignment isEqualTo []) then {""} else {str (_otherAssignment select 0)}
                                    };
                                    private _alternatives=(_group getVariable ["WAIT_Cortex_GarrisonCandidates",[]]) select {
                                        private _key=str (_x select 0);
                                        !(_key in _attempted) && {!(_key in _occupied)} && {[_x] call _assignmentValid}
                                            && {(_x param [4,"INTERIOR"]) == (_assignment param [4,"INTERIOR"])}
                                    };
                                    if (_reassignments < 2 && {_alternatives isNotEqualTo []} && {[_x] call _mayIssueMovement}) then {
                                        private _routeUnit=_x;
                                        _alternatives=[_alternatives,[],{(_x select 0) distance2D getPosATL _routeUnit},"ASCEND"] call BIS_fnc_sortBy;
                                        private _replacement=_alternatives select 0;
                                        private _replacementDestination=_replacement select 0;
                                        private _replacementBuilding=_replacement param [2,objNull];
                                        private _replacementEntries=[_replacementBuilding,_x,_replacementDestination] call (_job get "buildingEntries");
                                        private _replacementApproach=_replacementEntries isNotEqualTo [] && {_x distance2D _replacementDestination > 30};
                                        private _replacementEntryIndex=[-1,0] select _replacementApproach;
                                        private _replacementTarget=if (_replacementApproach) then {_replacementEntries select 0} else {_replacementDestination};
                                        private _replacementAnchor=if (_replacementApproach) then {
                                            [_replacementBuilding,_replacementTarget,_replacementDestination] call (_job get "buildingAnchor")
                                        } else {[]};
                                        _attempted pushBackUnique (str _replacementDestination);
                                        _x setVariable ["WAIT_AIPass_GarrisonPos",_replacement,true];
                                        _route=[_replacementTarget,_replacementApproach,getPosATL _x,time,0,_attempted,_reassignments+1,_replacementEntries,_replacementEntryIndex,_replacementAnchor,false];
                                        _x doMove _replacementTarget; [_x,_replacementTarget] call _rememberMove;
                                        diag_log format ["[WAIT] Garrison reassigned unit=%1 remaining=%2 alternative=%3",_x,_x distance (_assignment select 0),_replacementDestination];
                                    } else {
                                        if ([_x] call _mayIssueMovement
                        && {!isNil {_x getVariable "WAIT_Cortex_GarrisonForcedSpeed"}}
                        && {abs ((getForcedSpeed _x)-(_x getVariable ["WAIT_Cortex_GarrisonAppliedSpeed",4])) <= 0.1}) then {
                        _x forceSpeed (_x getVariable ["WAIT_Cortex_GarrisonForcedSpeed",-1]);
                    };
                    _x setVariable ["WAIT_AIPass_GarrisonFailed",true,true];
                                        diag_log format ["[WAIT] Garrison arrival failed unit=%1 attempted=%2 remaining=%3",_x,count _attempted,_x distance (_assignment select 0)];
                                    };
                                    };
                                };
                            };
                        };
                        };
                    };
                    (_job get "routes") set [netId _x,_route];
                };
            };
        };
    } forEach units _group;
    _group setVariable ["WAIT_Cortex_GarrisonPending",_pending,true];
    if (_pending == 0) then {
        private _assigned=(units _group) select {
            alive _x && {(_x getVariable ["WAIT_AIPass_GarrisonPos",[]]) isNotEqualTo []}
        };
        if (_assigned isNotEqualTo [] && {_assigned findIf {!(_x getVariable ["WAIT_AIPass_GarrisonFailed",false])} < 0}) then {
            private _evidence=(_assigned select [0,16]) apply {[netId _x,getPosATL _x,+(_x getVariable ["WAIT_AIPass_GarrisonPos",[]])]};
            _group setVariable ["WAIT_Cortex_GarrisonResult",[_job get "generation","INCOMPLETE","ALL_ROUTES_FAILED",serverTime,_evidence],true];
            diag_log format ["[WAIT] Garrison incomplete: all routes failed group=%1 evidence=%2",_group,_evidence];
            [_group] call WAIT_fnc_CortexGarrisonRelease;
        };
    };
    [2, -1] select (_pending == 0)
}, createHashMapFromArray [["group", _group], ["assignmentValid",_assignmentValid], ["assignmentArrived",_assignmentArrived], ["buildingTopologyCache",_buildingTopologyCache], ["routes",_routes], ["rememberMove",_rememberMove], ["buildingEntries",_buildingEntries], ["buildingAnchor",_buildingAnchor], ["deadline", _deadline], ["generation", _generation]], 1] call WAIT_fnc_CortexQueueJob;


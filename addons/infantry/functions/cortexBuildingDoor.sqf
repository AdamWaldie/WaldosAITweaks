/*
 * Author: WaldoTheWarfighter
 * Lets an approaching soldier on an explicit building order open a recognised unlocked door.
 * Locality/authority: called only on the soldier owner; direct non-server network invocation
 * is refused. Local calls and server-dispatched owner work retain their normal actor/order gates.
 * BIS door animation has global effect.
 * Repeat/JIP: two-second building cooldown bounds requests; engine door state persists for JIP.
 * Door model metadata is cached per building on each owner; locks are always read live.
 * At most four nearby-door geometry rays check interaction visibility per call. A closed door
 * may occlude its own final 0.5 m, but an earlier wall/other object cannot justify remote opening.
 * The owner-local per-building cursor rotates after tested doors so the query budget cannot
 * permanently starve later entries. It is an observation hint, not replayable task authority.
 * Only combat-effective ordinary actors may request an opening; capture and specialist ownership
 * are rechecked independently of the group order. Indoor requests also recheck contact identity,
 * feature gates and group task priority immediately before the global animation side effect.
 * CLEAR/GARRISON requests bind the live building/transform, participant assignment and owned
 * movement receipt; generation alone cannot authorize another building or a newer native task.
 * Arguments: 0 unit <OBJECT>, default objNull; 1 building <OBJECT>, default objNull;
 * 2 context <ARRAY, []> - optional [CLEAR, GARRISON or INDOOR <STRING>, order generation <NUMBER>].
 * 3 metadata only <BOOL, false> - cache model definitions without interaction or cooldown.
 * Metadata discovery is read-only world observation and does not require an available actor.
 * STOP, disabled movement, hidden actors and disabled simulation veto opening requests.
 * Return: BOOL, an opening request was issued (not proof of entry).
 * Current callers: CortexClearBuilding, CortexGarrisonApplyLocal and IndoorActorOperation owner jobs.
 * Example: [_soldier,_house] call WAIT_fnc_CortexBuildingDoor;
 */
params [["_unit",objNull,[objNull]],["_building",objNull,[objNull]],["_context",[],[[]]],["_metadataOnly",false,[true]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (isNull _building) exitWith {false};
// Model metadata is stable for this object's lifetime. Locks and animation phases are not.
private _doors=_building getVariable ["WAIT_Cortex_DoorDefinitions",[]];
if (isNil {_building getVariable "WAIT_Cortex_DoorDefinitions"}) then {
    private _config=configOf _building;
    private _count=(getNumber (_config >> "numberOfDoors")) min 64;
    for "_index" from 1 to _count do {
        private _source=format ["Door_%1_sound_source",_index];
        if (isClass (_config >> "AnimationSources" >> _source)) then {
            private _memory=_building selectionPosition [format ["Door_%1_trigger",_index],"Memory"];
            if (_memory isNotEqualTo [0,0,0]) then {_doors pushBack [_index,_source,_memory]};
        };
    };
    _building setVariable ["WAIT_Cortex_DoorDefinitions",_doors];
};
// Discovery never opens a door or consumes the interaction cooldown.
if (_metadataOnly) exitWith {false};
private _vectorValid={
    _this isEqualType [] && {count _this == 3}
        && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
private _orderCurrent={
    if (_context isEqualTo []) exitWith {true};
    if (count _context != 2 || {!((_context select 0) isEqualType "")} || {!((_context select 1) isEqualType 0)}) exitWith {false};
    private _group=group _unit;
    if ((_context select 0) == "INDOOR") exitWith {
        private _brain=_unit getVariable ["WAIT_IndoorActor_Brain",createHashMap];
        private _destination=(expectedDestination _unit) param [0,[],[[]]];
        private _target=_brain getOrDefault ["target",[]];
        private _contact=_brain getOrDefault ["contact",objNull];
        private _engaging=getAttackTarget _unit;
        private _assigned=assignedTarget _unit;
        if ((_brain getOrDefault ["contactRequired",false] && {isNull _contact})
            || {!isNull _contact && {!alive _contact || {(side _group) getFriend (side _contact) >= 0.6}}}
            || {!isNull _engaging && {_engaging != _contact}}
            || {!isNull _assigned && {_assigned != _contact}}) exitWith {false};
        private _combatCommand=currentCommand _unit in ["ATTACK","FIRE"] && {!isNull _contact}
            && {getAttackTarget _unit == _contact}
            && {isNull assignedTarget _unit || {assignedTarget _unit == _contact}};
        local _group && {(_brain getOrDefault ["generation",-1]) == (_context select 1)}
            && {!(_brain getOrDefault ["finished",true])} && {(_brain getOrDefault ["phase",""]) == "APPROACH"}
            && {(_brain getOrDefault ["building",objNull]) == _building}
            && {(_brain getOrDefault ["group",grpNull]) == _group}
            && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
            && {(_brain getOrDefault ["operationGeneration",-1]) == (_group getVariable ["WAIT_OperationGeneration",0])}
            && {[_unit] call WAIT_fnc_IndoorActorGroupAvailable}
            && {serverTime < (_brain getOrDefault ["deadline",0])}
            && {missionNamespace getVariable ["WAIT_AIPass_Active",false]}
            && {[_group,"WAIT_AIPass_BuildingCombat_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
            && {[_group,"WAIT_AIPass_Assault_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
            && {(_group getVariable ["WAIT_AIPass_Garrison",[]]) isEqualTo []}
            && {(_group getVariable ["WAIT_AIPass_Defend",[]]) isEqualTo []}
            && {!(_group getVariable ["WAIT_AIPass_ClearBuilding",false])}
            && {getSuppression _unit < 0.5} && {combatMode _group in ["YELLOW","RED","WHITE"]}
            && {_unit checkAIFeature "MOVE"} && {_unit checkAIFeature "PATH"}
            && {currentCommand _unit in ["","MOVE"] || {_combatCommand}}
            && {_destination call _vectorValid} && {_target call _vectorValid}
            && {_destination vectorDistance _target <= 0.25}
            && {([_group] call WAIT_fnc_NativeOrderReceipt) isEqualTo (_brain getOrDefault ["route",[]])}
            && {[getPosWorld _building,vectorDir _building,vectorUp _building] isEqualTo (_brain getOrDefault ["transform",[]])}
            && {(_unit getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo (_brain getOrDefault ["lease",[]])}
    };
    private _key=switch (_context select 0) do {
        case "CLEAR": {"WAIT_AIPass_ClearGeneration"};
        case "GARRISON": {"WAIT_AIPass_GarrisonGeneration"};
        default {""};
    };
    if (!local _group || {_key == ""} || {(_group getVariable [_key,-1]) != (_context select 1)}
        || {[_unit] call WAIT_fnc_CortexActorMoveReserved}
        || {!(currentCommand _unit in ["","MOVE"])}) exitWith {false};
    if ((_context select 0) == "CLEAR") exitWith {
        private _brain=_group getVariable ["WAIT_BuildingBrain",createHashMap];
        private _job=_brain getOrDefault ["job",createHashMap];
        private _issued=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _unit,[]];
        private _live=(expectedDestination _unit) param [0,[],[[]]];
        (_group getVariable ["WAIT_AIPass_ClearBuilding",false])
            && {!(_brain getOrDefault ["cancelled",true])} && {!(_brain getOrDefault ["finished",true])}
            && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
            && {(_job getOrDefault ["generation",-1]) == (_context select 1)}
            && {(_job getOrDefault ["building",objNull]) == _building}
            && {_unit in ((_job getOrDefault ["team",[]])+(_job getOrDefault ["securityActors",[]]))}
            && {(_job getOrDefault ["buildingTransform",[]]) isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
            && {([_group] call WAIT_fnc_NativeOrderReceipt) isEqualTo (_job getOrDefault ["nativeOrderReceipt",[]])}
            && {currentCommand _unit == "" || {_issued call _vectorValid && {_live call _vectorValid}
                && {_live vectorDistance _issued <= 0.25}}}
    };
    private _assignment=_unit getVariable ["WAIT_AIPass_GarrisonPos",[]];
    private _receipt=_unit getVariable ["WAIT_Cortex_GarrisonMove",[]];
    private _live=(expectedDestination _unit) param [0,[],[[]]];
    (_group getVariable ["WAIT_AIPass_Garrison",[]]) isNotEqualTo []
        && {_assignment isEqualType []} && {count _assignment >= 4}
        && {(_assignment select 2) == _building}
        && {(_assignment select 3) isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
        && {_receipt isEqualType []} && {count _receipt == 5}
        && {(_receipt select 4) isEqualTo _assignment}
        && {(_receipt select 0) == _group} && {(_receipt select 1) == (_context select 1)}
        && {(_receipt select 2) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
        && {(_receipt select 3) call _vectorValid} && {_live call _vectorValid}
        && {currentCommand _unit == "" || {_live vectorDistance (_receipt select 3) <= 0.25}}
};
if (isNull _unit || {isNull _building} || {!local _unit} || {!([_unit] call WAIT_fnc_CortexCombatEffective)}
    || {isPlayer _unit} || {[group _unit,false,_unit] call WAIT_fnc_CortexExternalTakeover}
    || {vehicle _unit != _unit} || {!alive _building}
    || {!([group _unit] call WAIT_fnc_CortexIsEligible)}) exitWith {false};
if !(call _orderCurrent) exitWith {false};
if (serverTime < (_building getVariable ["WAIT_Cortex_DoorRequestUntil",-1])) exitWith {false};
if (_doors isEqualTo []) exitWith {false};
private _doorCount=count _doors;
private _cursor=_building getVariable ["WAIT_Cortex_DoorVisibilityCursor",0];
if (!(_cursor isEqualType 0) || {!finite _cursor}) then {_cursor=0};
_cursor=((floor _cursor) max 0) mod _doorCount;
private _nextCursor=_cursor;
private _scanDoors=(_doors select [_cursor])+(_doors select [0,_cursor]);
private _requested=false;
private _visibilityChecks=0;
{
    _x params ["_index","_source","_memory"];
    private _lock=_building getVariable [format ["bis_disabled_Door_%1",_index],0];
    // Unknown door/lock conventions are left to their mod rather than guessed or unlocked.
    if (_lock isEqualTo 0 && {(_building getVariable ["bis_disabled_Door",0]) isEqualTo 0}
        && {_building animationSourcePhase _source < 0.1}) then {
        private _position=_building modelToWorldWorld _memory;
        // Open only within interaction approach distance and on the actor's floor.
        // A nearby ground-floor actor must not open upper-storey doors remotely.
        private _near=(getPosASL _unit) vectorDistance _position <= 3
            && {abs (((getPosASL _unit) select 2)-(_position select 2)) <= 1.5};
        private _visible=false;
        if (_near && {_visibilityChecks < 4}) then {
            _visibilityChecks=_visibilityChecks+1;
            _nextCursor=(_cursor+_forEachIndex+1) mod _doorCount;
            private _hits=lineIntersectsSurfaces [eyePos _unit,_position,_unit,objNull,true,1,"GEOM","NONE"];
            _visible=_hits isEqualTo [];
            if (!_visible) then {
                private _hit=_hits select 0;
                // The closed leaf can hide its own trigger. Do not accept an intervening
                // wall just because it belongs to this same building.
                _visible=((_hit select 2) == _building || {(_hit select 3) == _building})
                    && {(_hit select 0) vectorDistance _position <= 0.5};
            };
        };
        if (_near && {_visible}
            && {(_building getVariable ["bis_disabled_Door",0]) isEqualTo 0}
            && {(_building getVariable [format ["bis_disabled_Door_%1",_index],0]) isEqualTo 0}
            && {call _orderCurrent} && {[_unit] call WAIT_fnc_CortexCombatEffective}
            && {!isPlayer _unit} && {isNull remoteControlled _unit}
            && {local _unit} && {isNull objectParent _unit} && {simulationEnabled _unit}
            && {!isObjectHidden _unit} && {_unit checkAIFeature "MOVE"} && {_unit checkAIFeature "PATH"}
            && {currentCommand _unit != "STOP"}
            && {(getPosASL _unit) vectorDistance _position <= 3}
            && {abs (((getPosASL _unit) select 2)-(_position select 2)) <= 1.5}
            && {!([group _unit,false,_unit] call WAIT_fnc_CortexExternalTakeover)}) exitWith {
            _building setVariable ["WAIT_Cortex_DoorRequestUntil",serverTime+2,true];
            [_building,_index,1] call BIS_fnc_door;
            _requested=true;
        };
    };
    if (_requested || {_visibilityChecks >= 4}) exitWith {};
} forEach _scanDoors;
_building setVariable ["WAIT_Cortex_DoorVisibilityCursor",_nextCursor];
_requested

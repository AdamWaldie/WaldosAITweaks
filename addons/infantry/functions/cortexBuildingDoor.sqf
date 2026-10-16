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
 * are rechecked independently of the group order.
 * Arguments: 0 unit <OBJECT>, default objNull; 1 building <OBJECT>, default objNull;
 * 2 context <ARRAY, []> - optional [CLEAR or GARRISON <STRING>, order generation <NUMBER>].
 * Return: BOOL, an opening request was issued (not proof of entry).
 * Current callers: CortexClearBuilding and CortexGarrisonApplyLocal owner jobs.
 * Example: [_soldier,_house] call WAIT_fnc_CortexBuildingDoor;
 */
params [["_unit",objNull,[objNull]],["_building",objNull,[objNull]],["_context",[],[[]]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
private _orderCurrent={
    if (_context isEqualTo []) exitWith {true};
    if (count _context != 2 || {!((_context select 0) isEqualType "")} || {!((_context select 1) isEqualType 0)}) exitWith {false};
    private _group=group _unit;
    private _key=switch (_context select 0) do {
        case "CLEAR": {"WAIT_AIPass_ClearGeneration"};
        case "GARRISON": {"WAIT_AIPass_GarrisonGeneration"};
        default {""};
    };
    local _group && {_key != ""} && {(_group getVariable [_key,-1]) == (_context select 1)}
};
if (isNull _unit || {isNull _building} || {!local _unit} || {!([_unit] call WAIT_fnc_CortexCombatEffective)}
    || {isPlayer _unit} || {[group _unit,false,_unit] call WAIT_fnc_CortexExternalTakeover}
    || {vehicle _unit != _unit} || {!alive _building}
    || {!([group _unit] call WAIT_fnc_CortexIsEligible)}) exitWith {false};
if !(call _orderCurrent) exitWith {false};
if (serverTime < (_building getVariable ["WAIT_Cortex_DoorRequestUntil",-1])) exitWith {false};
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

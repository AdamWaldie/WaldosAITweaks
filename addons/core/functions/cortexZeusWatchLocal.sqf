/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Versioned local handler installation removes obsolete handlers before replacement. Each joining interface installs its own watcher.
 * Installs, on each player's machine, the curator event handlers that give Zeus priority over the
 * Smart AI Pass.
 *
 * Whenever this player's native Zeus interface opens (or the optional dialog event fires), the assigned
 * curator logic gets these handlers once:
 * Plain selection is observation and does not take control. Handlers cover:
 * - group and object double-click (attributes);
 * - object edited (moved or rotated);
 * - waypoint placed, edited and deleted.
 * Each calls WAIT_fnc_CortexZeusMark for the affected group, so the pass releases it and leaves it
 * alone while Zeus commands it. Placed events supply group plus waypoint ID; edited, deleted and
 * double-clicked events supply the waypoint array. The exact index is forwarded so cleanup never has
 * to rediscover a mutable currentWaypoint. Curator event handlers fire only on the curator's machine, which is why
 * this runs on clients even though the pass itself never does. The handlers cost nothing until Zeus
 * acts, and send nothing while the pass is disabled.
 * Locality and authority: interface clients only; repeat-safe, JIP-safe.
 *
 * Review contract: Placed events carry a group and waypoint ID; edited, deleted and double-clicked
 * events carry a waypoint array. Installation is repeat-safe per curator and local to each joining interface client.
 *
 * Arguments: None.
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [] call WAIT_fnc_CortexZeusWatchLocal;
 * Result: this player's Zeus orders always take priority over the pass.
 *
 * Current callers: addon post-init and native/optional curator display-load hooks.
 */

if (!hasInterface || {missionNamespace getVariable ["WAIT_AIPass_ZeusWatchInstalled", false]}) exitWith {};
missionNamespace setVariable ["WAIT_AIPass_ZeusWatchInstalled", true];
private _install = {
    private _curator = getAssignedCuratorLogic player;
    if (isNull _curator || {_curator getVariable ["WAIT_AIPass_ZeusHandlers", false]}) exitWith {};
    _curator setVariable ["WAIT_AIPass_ZeusHandlers", true];
    private _objectGroup = {
        params ["_object"];
        if (isNull _object) exitWith {grpNull};
        if (_object isKindOf "CAManBase") exitWith {group _object};
        group effectiveCommander _object
    };
    missionNamespace setVariable ["WAIT_AIPass_ZeusObjectGroup", _objectGroup];
    _curator addEventHandler ["CuratorGroupDoubleClicked", {params ["", "_group"]; [_group] call WAIT_fnc_CortexZeusMark}];
    {
        _curator addEventHandler [_x, {
            params ["", "_entity"];
            [[_entity] call (missionNamespace getVariable ["WAIT_AIPass_ZeusObjectGroup", {grpNull}])] call WAIT_fnc_CortexZeusMark;
        }];
    } forEach ["CuratorObjectDoubleClicked", "CuratorObjectEdited"];
    _curator addEventHandler ["CuratorWaypointPlaced", {
        params ["", "_group", "_waypointID"];
        [_group,true,_waypointID] call WAIT_fnc_CortexZeusMark;
    }];
    {
        _curator addEventHandler [_x, {
            params ["", "_waypoint"];
            if (_waypoint isEqualType [] && {count _waypoint >= 2}) then {
                [_waypoint select 0,true,_waypoint select 1] call WAIT_fnc_CortexZeusMark
            };
        }];
    } forEach ["CuratorWaypointEdited", "CuratorWaypointDeleted", "CuratorWaypointDoubleClicked"];
};
missionNamespace setVariable ["WAIT_AIPass_ZeusInstallLocal", _install];
["zen_curatorDisplayLoaded", _install] call CBA_fnc_addEventHandler;
call _install;

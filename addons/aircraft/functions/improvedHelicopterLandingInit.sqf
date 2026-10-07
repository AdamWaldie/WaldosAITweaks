/*
 * Author: WaldoTheWarfighter
 * Installs the repeat-safe event-driven handlers for improved AI helicopter landings. It mirrors
 * the AI skill system: a CBA class-init event catches editor, Zeus and scripted helicopters, while
 * client and player machines. Parachutes are excluded before installing any flight controller or pin.
 * On the server, every non-UAV helicopter is excluded from automatic
 * ACE/WAIT headless-client transfer before its crew is considered for balancing. Dedicated testing
 * showed airborne helicopters losing stable flight immediately after an ACE `setGroupOwner`
 * transition, before this landing controller ever activated. Keeping the aircraft group on the
 * server avoids that engine/locality transition while still allowing WAIT AI skill values to be
 * applied to its crew. Only the machine owning an aircraft queues its bounded watcher.
 * Locality and authority: Each machine installs local class-init and ownership handlers. The
 * current helicopter owner runs the waypoint watcher; server-side ownership exclusions remain
 * with the server.
 * Repeat/JIP: A local installed flag prevents duplicate handlers. JIP and new owners install
 * their own generation-scoped job but do not share a competing flight controller.
 *
 * Arguments: None.
 *
 * Return Value: BOOL - true when the handlers are installed or were already present.
 *
 * Example: [] call WAIT_fnc_ImprovedHelicopterLandingInit;
 * Result: Returns true after handler installation or when they were already installed.
 * Current caller: init.sqf on every machine, including JIP and headless clients.
 */

if (missionNamespace getVariable ["WAIT_ImprovedHelicopterLanding_HandlerInstalledLocal", false]) exitWith {true};
missionNamespace setVariable ["WAIT_ImprovedHelicopterLanding_HandlerInstalledLocal", true];

private _install = {
    params [["_helicopter", objNull, [objNull]]];
    if (isNull _helicopter || {!(_helicopter isKindOf "Helicopter")} || {_helicopter isKindOf "ParachuteBase"} || {getNumber (configOf _helicopter >> "isUav") != 0}) exitWith {};
    // ACE Headless checks this public vehicle flag before every automatic transfer. Set it on the
    // aircraft itself so it is already effective when an empty helicopter receives crew later.
    // The server is authoritative for this compatibility boundary; clients only install locality
    // handlers and never publish competing values.
    if (isServer) then {
        _helicopter setVariable ["acex_headless_blacklist", true, true];
        _helicopter setVariable ["WAIT_Headless_HelicopterPinned", true, true];
        {
            private _crewGroup = group _x;
            if !(isNull _crewGroup) then {
                _crewGroup setVariable ["WAIT_Headless_ExcludeGroup", true, true];
                _crewGroup setVariable ["acex_headless_blacklist", true, true];
            };
        } forEach crew _helicopter;
    };
    if !(_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_LocalHandlerInstalled", false]) then {
        _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_LocalHandlerInstalled", true];
        if (isNil {_helicopter getVariable "WAIT_ImprovedHelicopterLanding_GroundAnchored"}) then {
            _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_GroundAnchored", false, true];
        };
        if (isNil {_helicopter getVariable "WAIT_ImprovedHelicopterLanding_ControlRevision"}) then {
            _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_ControlRevision", 0, true];
        };
        _helicopter addEventHandler ["Local", {
            params ["_helicopter", "_isLocal"];
            // Ownership can leave and return before the previous scheduled tracker wakes.  Advance a
            // machine-local token on both transitions so that stale workers cannot issue orders or
            // clear the replacement worker state after a rapid headless/server handoff.
            private _trackerGeneration = (_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_TrackerGenerationLocal", 0]) + 1;
            _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_TrackerGenerationLocal", _trackerGeneration];
            if (!_isLocal) then {
                // This flag is deliberately machine-local. Clear it immediately so a rapid return
                // to this machine cannot race the old tracker's scheduled loop cleanup.
                _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_TrackedLocal", false];
            };
            if (_isLocal && {!(_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_TrackedLocal", false])}) then {
                if (_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_Active", false]) then {
                    [_helicopter, false, "", true] call WAIT_fnc_ImprovedHelicopterLandingRestoreLocal;
                };
                _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_TrackedLocal", true];
                missionNamespace setVariable ["WAIT_Aircraft_LandingSchedulerActive", true];
                [] call WAIT_fnc_SchedulerReconcile;
                [WAIT_fnc_ImprovedHelicopterLandingStep, createHashMapFromArray [
                    ["helicopter", _helicopter], ["generation", _trackerGeneration],
                    ["subsystem", "AIRCRAFT"], ["jobKey", "WAIT_LANDING_" + netId _helicopter]
                ], 0.1, "WAIT_LANDING_" + netId _helicopter] call WAIT_fnc_CortexQueueJob;
            };
        }];
    };
    if (local _helicopter && {!(_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_TrackedLocal", false])}) then {
        private _trackerGeneration = (_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_TrackerGenerationLocal", 0]) + 1;
        _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_TrackerGenerationLocal", _trackerGeneration];
        _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_TrackedLocal", true];
        missionNamespace setVariable ["WAIT_Aircraft_LandingSchedulerActive", true];
        [] call WAIT_fnc_SchedulerReconcile;
        [WAIT_fnc_ImprovedHelicopterLandingStep, createHashMapFromArray [
            ["helicopter", _helicopter], ["generation", _trackerGeneration],
            ["subsystem", "AIRCRAFT"], ["jobKey", "WAIT_LANDING_" + netId _helicopter]
        ], 0.1, "WAIT_LANDING_" + netId _helicopter] call WAIT_fnc_CortexQueueJob;
    };
};
missionNamespace setVariable ["WAIT_ImprovedHelicopterLanding_InstallLocal", _install];
["Helicopter", "init", {
    params ["_helicopter"];
    [_helicopter] call (missionNamespace getVariable ["WAIT_ImprovedHelicopterLanding_InstallLocal", {}]);
}, true, [], true] call CBA_fnc_addClassEventHandler;
{[_x] call _install;} forEach (vehicles select {_x isKindOf "Helicopter"});

true

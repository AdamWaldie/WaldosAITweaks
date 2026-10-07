/*
 * Author: WaldoTheWarfighter
 * Examines one local AI helicopter's current waypoint once inside WAIT's shared bounded scheduler.
 * Supported landing orders enter the finite vector landing controller only after class, crew,
 * formation, distance, motion, lease and Zeus-authority checks pass. Ordinary MOVE waypoints remain
 * native. A multi-aircraft group releases any old exact-landing lease because one shared waypoint
 * cannot safely drive several aircraft to one touchdown point.
 *
 * Locality/authority: Owner-local observation only. It never commands a remote helicopter. The
 * finite landing controller is spawned only after the current owner and order pass every guard.
 * Repeat/JIP: The owner generation retires stale jobs after migration. State retains only the last
 * waypoint signature so unchanged orders do not rebroadcast diagnostics.
 *
 * Arguments: 0: state <HASHMAP> containing helicopter, generation, lastSignature and subsystem.
 * Return Value: NUMBER - 0.5 seconds until the next observation, or -1 when the job retires.
 * Current callers: WAIT_fnc_ImprovedHelicopterLandingInit through WAIT_fnc_CortexQueueJob.
 * Example: [WAIT_fnc_ImprovedHelicopterLandingStep,createHashMapFromArray [["helicopter",_heli],["generation",3],["subsystem","AIRCRAFT"]],0] call WAIT_fnc_CortexQueueJob;
 */

params [["_state", createHashMap, [createHashMap]]];
private _helicopter = _state getOrDefault ["helicopter", objNull];
private _generation = _state getOrDefault ["generation", -1];
if (
    isNull _helicopter
    || {!alive _helicopter}
    || {!local _helicopter}
    || {(_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_TrackerGenerationLocal", 0]) != _generation}
    || {!(missionNamespace getVariable ["WAIT_ImprovedHelicopterLanding_Enable", true])}
) exitWith {
    if (!isNull _helicopter && {local _helicopter}
        && {(_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_TrackerGenerationLocal", 0]) == _generation}) then {
        _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_TrackedLocal", false];
        _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_GearLocal", false];
        [_helicopter, false] call WAIT_fnc_ImprovedHelicopterLandingRestoreLocal;
    };
    -1
};

private _lastSignature = _state getOrDefault ["lastSignature", []];
private _pilot = currentPilot _helicopter;
private _pilotAwake = if (isNull _pilot) then {false} else {
    if (!isNil "ace_common_fnc_isAwake") then {[_pilot] call ace_common_fnc_isAwake} else {lifeState _pilot != "INCAPACITATED"}
};
if (isNull _pilot || {isPlayer _pilot} || {!isNull (remoteControlled _pilot)} || {!alive _pilot} || {!_pilotAwake}) exitWith {0.5};

private _group = group _pilot;
private _groupHelicopters = [];
{
    private _groupVehicle = vehicle _x;
    if (_groupVehicle isKindOf "Helicopter") then {_groupHelicopters pushBackUnique _groupVehicle};
} forEach units _group;

if (
    count _groupHelicopters != 1
    && {
        _helicopter getVariable ["WAIT_ImprovedHelicopterLanding_Active", false]
        || {_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_GroundAnchored", false]}
    }
) then {
    [_helicopter, false, "", true] call WAIT_fnc_ImprovedHelicopterLandingRestoreLocal;
    diag_log format ["[WAIT AI LANDING] Released controller because helicopter joined a %1-aircraft group helicopter=%2.", count _groupHelicopters, netId _helicopter];
};

private _index = currentWaypoint _group;
private _waypoints = waypoints _group;
if (_index < 0 || {_index >= count _waypoints}) exitWith {
    _state set ["lastSignature", []];
    0.5
};

private _waypoint = [_group, _index];
private _position = waypointPosition _waypoint;
private _type = toUpperANSI (waypointType _waypoint);
private _script = toLowerANSI (waypointScript _waypoint);
private _landingType = _type in ["LAND", "UNLOAD", "TR UNLOAD", "GETOUT"];
if (_type == "SCRIPTED" && {_script find "land" >= 0}) then {_landingType = true};
private _signature = [_index, _position, _type, _script];
if !(_signature isEqualTo _lastSignature) then {
    _state set ["lastSignature", _signature];
    _helicopter setVariable ["WAIT_ImprovedHelicopterLanding_TrackerState", [_index, _type, _position, _script], true];
    diag_log format ["[WAIT AI LANDING] Tracker owner=%1 helicopter=%2 waypoint=%3 type=%4 position=%5", clientOwner, netId _helicopter, _index, _type, _position];
};

private _minimumDistance = ([_helicopter, "MinimumActivationDistance", 50] call WAIT_fnc_ImprovedHelicopterLandingSetting) max 50;
private _distance = _helicopter distance2D _position;
private _triggerDistance = ((abs speed _helicopter) * ([_helicopter, "TriggerSpeedFactor", 4.2] call WAIT_fnc_ImprovedHelicopterLandingSetting))
    max ([_helicopter, "TriggerDistance", 500] call WAIT_fnc_ImprovedHelicopterLandingSetting);
private _velocity = velocity _helicopter;
private _horizontalSpeed = sqrt (((_velocity select 0) ^ 2) + ((_velocity select 1) ^ 2));
private _minimumApproachSpeed = (([_helicopter, "MinimumApproachSpeed", 55] call WAIT_fnc_ImprovedHelicopterLandingSetting) max 0) / 3.6;
private _transitAltitude = ([_helicopter, "TransitAltitude", 30] call WAIT_fnc_ImprovedHelicopterLandingSetting) max 15;
private _glideRatio = ([_helicopter, "GlideSlopeRatio", 4] call WAIT_fnc_ImprovedHelicopterLandingSetting) max 2;
private _finalCommitDistance = ([_helicopter, "FinalCommitDistance", 75] call WAIT_fnc_ImprovedHelicopterLandingSetting) max 10;
private _closeApproachDistance = ((_transitAltitude * _glideRatio) max (_finalCommitDistance * 2)) min _triggerDistance;
private _approachReady = _helicopter getVariable ["WAIT_ImprovedHelicopterLanding_ImmediateAcquisition", false]
    || {_horizontalSpeed >= _minimumApproachSpeed}
    || {_distance <= _closeApproachDistance};

if (
    _landingType
    && {count _groupHelicopters == 1}
    && {_distance > _minimumDistance}
    && {_distance <= _triggerDistance}
    && {_approachReady}
    && {isEngineOn _helicopter}
    && {!isTouchingGround _helicopter}
    && {!(_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_Exclude", false])}
    && {isNull (getSlingLoad _helicopter)}
    && {isNil {_helicopter getVariable "WAIT_Cortex_AirAttackToken"}}
    && {isNil {_helicopter getVariable "WAIT_Cortex_MissileDefenceActive"}}
    && {!([_group] call WAIT_fnc_CortexZeusHeld)}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
    && {!(_helicopter getVariable ["WAIT_ImprovedHelicopterLanding_Active", false])}
) then {
    // Recheck at the acquisition boundary because the finite controller will become the sole
    // flight owner until touchdown, abort or an external order invalidates it.
    if (local _helicopter && {currentPilot _helicopter == _pilot}
        && {!([_group] call WAIT_fnc_CortexExternalTakeover)} && {!([_group] call WAIT_fnc_CortexZeusHeld)}) then {
        diag_log format ["[WAIT AI LANDING] Controller acquiring helicopter=%1 waypoint=%2 type=%3 distance=%4 horizontalSpeed=%5 closeEnvelope=%6", netId _helicopter, _index, _type, round _distance, round (_horizontalSpeed * 3.6), round _closeApproachDistance];
        [_helicopter, _position, _type, _index, _script] spawn WAIT_fnc_ImprovedHelicopterLandingExecuteLocal;
        _state set ["lastSignature", []];
    };
};
0.5

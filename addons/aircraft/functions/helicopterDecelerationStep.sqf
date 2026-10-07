/*
 * Author: WaldoTheWarfighter
 * Samples one local AI helicopter once for the shared bounded aircraft scheduler. It replaces the
 * prior permanent per-aircraft tracker: the scheduler owns cadence, fairness and low-FPS handling,
 * while this finite step only evaluates one existing flight state and may launch one bounded
 * correction. Landing, attack, missile defence, player, Zeus and specialist ownership always win.
 *
 * Locality/authority: Runs only on the owner of its aircraft. It changes no flight controls itself;
 * the separately bounded correction owns its own short impulse sequence.
 * Repeat/JIP: A generation mismatch, locality change, disablement or deletion retires this job.
 * Arguments: 0: state <HASHMAP> with aircraft, generation, lastSpeed and lastAltitude.
 * Return Value: NUMBER - next sampling delay or -1 when retired.
 * Current callers: WAIT_fnc_HelicopterDecelerationInit through WAIT_fnc_CortexQueueJob.
 * Example: [WAIT_fnc_HelicopterDecelerationStep,createHashMapFromArray [["aircraft",_heli],["generation",2]],0,"WAIT_DECEL_1"] call WAIT_fnc_CortexQueueJob;
 */
params [['_state',createHashMap,[createHashMap]]];
private _aircraft=_state getOrDefault ['aircraft',objNull];
private _generation=_state getOrDefault ['generation',-1];
if (isNull _aircraft || {!alive _aircraft} || {!local _aircraft}
    || {(_aircraft getVariable ['WAIT_HelicopterDeceleration_GenerationLocal',0]) != _generation}
    || {!(missionNamespace getVariable ['WAIT_HelicopterDeceleration_Enable',false])}) exitWith {
    if (!isNull _aircraft && {local _aircraft} && {(_aircraft getVariable ['WAIT_HelicopterDeceleration_GenerationLocal',0]) == _generation}) then {
        _aircraft setVariable ['WAIT_HelicopterDeceleration_TrackedLocal',false];
        _aircraft setVariable ['WAIT_HelicopterDeceleration_Active',false,true];
    };
    -1
};
private _pilot=currentPilot _aircraft;
private _pilotAwake=if (isNull _pilot) then {false} else {
    if (!isNil 'ace_common_fnc_isAwake') then {[_pilot] call ace_common_fnc_isAwake} else {lifeState _pilot != 'INCAPACITATED'}
};
private _isLandingOrder={
    params ['_vehicle']; private _pilot=currentPilot _vehicle;
    if (isNull _pilot) exitWith {false}; private _group=group _pilot; private _index=currentWaypoint _group;
    if (_index < 0 || {_index >= count waypoints _group}) exitWith {false}; private _wp=[_group,_index];
    private _type=toUpperANSI waypointType _wp; private _script=toLowerANSI waypointScript _wp;
    _type in ['LAND','UNLOAD','TR UNLOAD','GETOUT'] || {_type == 'SCRIPTED' && {_script find 'land' >= 0}}
};
private _speed=abs speed _aircraft;
private _altitudeASL=(getPosASL _aircraft) select 2;
private _lastSpeed=_state getOrDefault ['lastSpeed',_speed];
private _lastAltitude=_state getOrDefault ['lastAltitude',_altitudeASL];
private _eligible=!isNull _pilot && {alive _pilot} && {_pilotAwake} && {!isPlayer _pilot}
    && {isNull remoteControlled _pilot}
    && {_aircraft isKindOf 'Helicopter'
        || {(missionNamespace getVariable ['WAIT_HelicopterDeceleration_IncludeVTOL',false]) && {_aircraft isKindOf 'VTOL_Base_F'}}};
_eligible=_eligible && {!(_aircraft getVariable ['WAIT_HelicopterDeceleration_Exclude',false])}
    && {!(_aircraft getVariable ['WAIT_Cortex_AirAttackJob',false])}
    && {isNil {_aircraft getVariable 'WAIT_Cortex_AirAttackToken'}}
    && {isNil {_aircraft getVariable 'WAIT_Cortex_MissileDefenceActive'}}
    && {!([group _pilot] call WAIT_fnc_CortexExternalTakeover)}
    && {!(_aircraft getVariable ['WAIT_HelicopterDeceleration_Active',false])}
    && {!(_aircraft getVariable ['WAIT_ImprovedHelicopterLanding_Active',false])}
    && {!([_aircraft] call _isLandingOrder)}
    && {isEngineOn _aircraft} && {canMove _aircraft}
    && {fuel _aircraft > 0} && {!isTouchingGround _aircraft} && {isNull getSlingLoad _aircraft};
if (_eligible && {
    _speed >= (missionNamespace getVariable ['WAIT_HelicopterDeceleration_MinimumSpeed',80])
    && {((getPosATL _aircraft) select 2) >= (missionNamespace getVariable ['WAIT_HelicopterDeceleration_MinimumAltitude',25])}
    && {_lastSpeed-_speed >= (missionNamespace getVariable ['WAIT_HelicopterDeceleration_MinimumSpeedLoss',4])}
    && {_altitudeASL-_lastAltitude >= (missionNamespace getVariable ['WAIT_HelicopterDeceleration_MinimumAltitudeGain',0.5])}
    && {(vectorDir _aircraft select 2) >= (missionNamespace getVariable ['WAIT_HelicopterDeceleration_MinimumNoseUp',0.02])}
}) then {[_aircraft,_speed,_altitudeASL,_isLandingOrder,_generation] spawn WAIT_fnc_HelicopterDecelerationCorrectLocal};
_state set ['lastSpeed',_speed]; _state set ['lastAltitude',_altitudeASL];
(missionNamespace getVariable ['WAIT_HelicopterDeceleration_SampleInterval',0.5]) max 0.1

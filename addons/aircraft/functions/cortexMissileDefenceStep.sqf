/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes one bounded countermeasure and flight-preserving evasion sample after an
 * incoming-missile warning. A newer warning replaces this finite response through its generation
 * token, so aircraft never accumulate parallel flare or velocity workers.
 * Locality / Authority: Must run where the aircraft is local. It changes only that locally owned
 * AI aircraft's countermeasures and, at most twice, its model-space velocity. It never creates a
 * waypoint, changes target selection, controls player aircraft or alters Dynamic AA.
 * Repeat/JIP: The scheduler owns repetition. Locality loss, eligibility loss, shutdown and a newer
 * generation retire this callback without restoring or overwriting a later flight controller.
 * Arguments:
 * 0: State <HASHMAP> - aircraft <OBJECT>, missile <OBJECT>, generation <NUMBER>, side <NUMBER>,
 *    step <NUMBER> (optional, default 0).
 * Return Value:
 * NUMBER - seconds until the next finite sample, or -1 when the response is complete/replaced.
 * Current callers: The local IncomingMissile handler installed by WAIT_fnc_CortexDiscover through
 * WAIT_fnc_CortexQueueJob.
 * Example:
 * [WAIT_fnc_CortexMissileDefenceStep,createHashMapFromArray [["aircraft",_aircraft],["missile",_missile],
 * ["generation",4],["side",1],["step",0],["subsystem","TACTICS"]],0] call WAIT_fnc_CortexQueueJob;
 * Result: a local AI aircraft emits bounded countermeasures and applies no more than two safe breaks.
 */

params [["_state",createHashMap,[createHashMap]]];
private _aircraft=_state getOrDefault ["aircraft",objNull];
private _missile=_state getOrDefault ["missile",objNull];
private _generation=_state getOrDefault ["generation",-1];
private _side=_state getOrDefault ["side",1];
private _step=_state getOrDefault ["step",0];

private _finish={
    if (!isNull _aircraft && {(_aircraft getVariable ["WAIT_Cortex_FlareBurstGeneration",-1]) == _generation}) then {
        _aircraft setVariable ["WAIT_Cortex_MissileDefenceActive",nil];
    };
    -1
};
if (isNull _aircraft || {!local _aircraft}
    || {(_aircraft getVariable ["WAIT_Cortex_FlareBurstGeneration",-1]) != _generation}
    || {!([_aircraft] call WAIT_fnc_CortexAircraftEligible)}) exitWith {call _finish};
// A known projectile disappearing after the initial sample means the threat has ended. Engines and
// addon weapons that do not expose the projectile retain the same bounded twelve-sample maximum.
if (_step > 0 && {!isNull _missile} && {!alive _missile}) exitWith {call _finish};

private _pilot=driver _aircraft;
if (!isNull _pilot && {[group _pilot,"WAIT_AIPass_AircraftFlares_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) then {
    [_aircraft] call WAIT_fnc_CortexFireCountermeasure;
};
// Two decisive, terrain-checked impulses produce a useful beam/climb without repeatedly replacing
// native flight intent. Attack, landing and braking controllers remain the flight owner.
if (_step in [0,4] && {!isNull _pilot}
    && {[group _pilot,"WAIT_AIPass_AircraftBreak_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) then {
    private _velocity=velocityModelSpace _aircraft;
    private _isPlane=_aircraft isKindOf "Plane";
    private _lateralLimit=[34,58] select _isPlane;
    private _minimumForward=[28,90] select _isPlane;
    private _vertical=[7,14] select _isPlane;
    private _candidate=[
        (((_velocity select 0)+(_side*([18,30] select _isPlane))) max -_lateralLimit) min _lateralLimit,
        (_velocity select 1) max _minimumForward,
        ((_velocity select 2)+([_vertical,_vertical*0.35] select (_step > 0))) min ([16,30] select _isPlane)
    ];
    private _future=_aircraft modelToWorldWorld (_candidate vectorMultiply 2);
    private _clearance=(_future select 2)-(getTerrainHeightASL _future);
    if (_clearance >= ([30,70] select _isPlane) && {[_aircraft] call WAIT_fnc_CortexAircraftEligible}) then {
        _aircraft setVelocityModelSpace _candidate;
    };
};
_step=_step+1;
if (_step >= 12) exitWith {call _finish};
_state set ["step",_step];
0.45+random 0.18

/*
 * Author: WaldoTheWarfighter
 * Purpose: Estimates signed forward curvature from actual travelled positions in current model space.
 * Locality / Authority: Read-only on current vehicle owner; callers store the returned measurement
 * in their existing local brain/state. No commands, public state, history scan or new scheduler.
 * Repeat/JIP: One bounded receipt resets on caller context, seats, owner, reversal, standing or
 * stale sampling. New owners start straight; historical curvature never grants path clearance.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 previous receipt <ARRAY, []>;
 * 2 controller context <ARRAY, []> binding route/configuration/epoch.
 * Return Value: ARRAY [curvature inverse metres NUMBER, local measurement receipt ARRAY].
 * Measurement: >=3 m planar displacement or >=1.5 s; samples older than 6 s reset. Curves wider
 * than 250 m count as straight. At <=1 m/s or reversing, prediction is straight and resets.
 * Current callers: DrivingAssistStart and ConvoyTick through their existing bounded callbacks.
 * Example: private _turn=[truck1,_previous,[_route,_epoch]] call WAIT_fnc_DrivingTurnTrack;
 */
params [["_vehicle",objNull,[objNull]],["_previous",[],[[]]],["_context",[],[[]]]];
if (isRemoteExecuted || {isNull _vehicle} || {!local _vehicle} || {!alive _vehicle}) exitWith {[0,[]]};
private _identity=[_context,_vehicle,driver _vehicle,effectiveCommander _vehicle,clientOwner];
private _position=_vehicle modelToWorldWorld [0,0,0];
private _fresh=[_identity,_position,time,0];
private _forward=(velocityModelSpace _vehicle) select 1;
if (!finite _forward || {_forward <= 1}) exitWith {[0,_fresh]};
if (count _previous != 4 || {(_previous select 0) isNotEqualTo _identity}
    || {time-(_previous select 2) > 6} || {time < (_previous select 2)}) exitWith {[0,_fresh]};
private _old=_vehicle worldToModel (ASLToAGL (_previous select 1));
private _distanceSquared=(_old select 0)^2+(_old select 1)^2;
private _curvature=_previous select 3;
if (_distanceSquared >= 9 || {time-(_previous select 2) >= 1.5}) then {
    _curvature=if (_distanceSquared < 1) then {0} else {2*(_old select 0)/_distanceSquared};
    if (!finite _curvature || {abs _curvature < 0.004}) then {_curvature=0};
    _fresh set [3,_curvature];
} else {_fresh=+_previous};
[_curvature,_fresh]

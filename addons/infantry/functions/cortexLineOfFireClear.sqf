/*
 * Author: WaldoTheWarfighter
 * Purpose: Veto direct/suppressive fire when a friendly, civilian or protected captive position
 * lies inside the complete firing cone, including near a target beyond 600 metres.
 * One rectangular native area query covers the full segment and maximum cone width. It includes
 * mounted people; the shooter's own platform and its occupants are excluded. Every other live
 * person or land vehicle is projected in ASL from two metres ahead to ten metres beyond the target,
 * with the existing two-metre plus approximately five-degree radial margin.
 * Locality/authority: Read-only anywhere; callers retain firing authority and ROE checks.
 * Repeat/JIP: Stateless. No handlers, public state, movement or weapon commands are issued.
 * Limits: Refuses malformed/non-finite targets, spans over 6000 m and more than 64 returned
 * candidates rather than truncating the corridor. The native query cost remains engine-dependent.
 * Position-based cone exclusion is not a hull, blast-radius, penetration, civilian-identification,
 * future-motion or continuous friendly-fire guarantee. It does not authorize building destruction.
 * Arguments: 0 shooter <OBJECT, objNull>; 1 target ASL <ARRAY, []>, exactly three finite numbers.
 * Return Value: BOOL - true only when this bounded position-based observation finds no veto.
 * Current callers: CortexFireControl, CortexVehicles, CortexCombinedArmsLocal and CortexCombinedGroundStep.
 * Example: if ([_unit,_targetASL] call WAIT_fnc_CortexLineOfFireClear) then {_unit doSuppressiveFire _targetASL};
 */

params [["_shooter",objNull,[objNull]],["_target",[],[[]]]];
if (isNull _shooter || {count _target != 3}
    || {_target findIf {!(_x isEqualType 0) || {!(finite _x)}} >= 0}) exitWith {false};
private _from=eyePos _shooter;
private _length=_from vectorDistance _target;
if (!finite _length || {_length < 0.1} || {_length > 6000}) exitWith {false};
private _direction=_from vectorFromTo _target;
private _side=side group _shooter;
private _platform=vehicle _shooter;
private _delta=_target vectorDiff _from;
private _horizontalLength=vectorMagnitude [_delta select 0,_delta select 1,0];
private _angle=(_delta select 0) atan2 (_delta select 1);
private _coneWidth=2+(_length+10)*0.087;
// Unlimited query height avoids terrain/ASL conversion excluding a person on a different floor.
// The exact three-dimensional projection below still rejects positions outside the firing cone.
// Extra longitudinal width encloses the horizontal projection of a steep or vertical cone too.
private _area=[ASLToAGL ((_from vectorAdd _target) vectorMultiply 0.5),
    _coneWidth,_horizontalLength*0.5+_coneWidth+10,_angle,true,-1];
private _candidates=_area nearEntities [["CAManBase","LandVehicle"],false,true,true];
if (count _candidates > 64) exitWith {false};
_candidates findIf {
    private _other = _x;
    private _otherSide = side group _other;
    private _protected=captive _other || {_other getVariable ["ace_captives_isSurrendering",false]}
        || {_other getVariable ["ace_captives_isHandcuffed",false]};
    // The mounted muzzle's own platform is not another friendly blocking its shot.
    if (_other == _shooter || {_other == _platform}
        || {_platform != _shooter && {vehicle _other == _platform}} || {!alive _other}
        || {!(_protected || {_otherSide == civilian} || {_side getFriend _otherSide >= 0.6})}) then {
        false
    } else {
        private _offset = (getPosASL _other vectorAdd [0, 0, 1]) vectorDiff _from;
        private _along = _offset vectorDotProduct _direction;
        _along > 2 && {_along < _length + 10}
            && {vectorMagnitude (_offset vectorDiff (_direction vectorMultiply _along)) < 2 + _along * 0.087}
    };
} < 0


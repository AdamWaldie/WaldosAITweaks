/*
 * Author: WaldoTheWarfighter
 * Purpose: Classify an actor's native command as a replaceable idle/plain-route leg or a
 * same-contact native approach that must be observed without replaying movement.
 * Locality/authority: Read-only on actor/group owner. Actual engagement identity comes from
 * getAttackTarget; assignedTarget is only a conflicting mission-target veto. No hidden pose reads.
 * Repeat/JIP: Stateless; current waypoint metadata and native command are read each call,
 * with at most one believed-position FIRE visibility query. No exact hostile transform is read.
 * Arguments: actor OBJECT objNull, contact OBJECT objNull, believed ATL ARRAY [], building OBJECT objNull.
 * Return: ARRAY [ISSUE or OBSERVE STRING, native intent STRING, native destination ARRAY,
 * bound native-known contact OBJECT], or [] for protected/unknown context. Metadata is not access proof.
 * Current caller: WAIT_fnc_IndoorActorOperation admission and pre-command validation.
 * Example: private _context=[soldier1,enemy1,[100,100,2],house1] call WAIT_fnc_IndoorActorNativeContext;
 */
params [["_actor",objNull,[objNull]],["_contact",objNull,[objNull]],
    ["_belief",[],[[]]],["_building",objNull,[objNull]]];
if (isNull _actor || {!local _actor} || {!local group _actor}) exitWith {[]};
private _vectorValid={_this isEqualType [] && {count _this == 3}
    && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
private _command=currentCommand _actor;
if !(_command in ["","MOVE","ATTACK","FIRE"]) exitWith {[]};
private _unitState=getUnitState _actor;
if (_unitState == "PLANNING") exitWith {[]};
private _engaging=getAttackTarget _actor;
private _assigned=assignedTarget _actor;
if (isNull _contact && {!isNull _engaging || {!isNull _assigned}}) exitWith {[]};
if (!isNull _contact && {(!isNull _engaging && {_engaging != _contact})
    || {!isNull _assigned && {_assigned != _contact}}}) exitWith {[]};
private _contactValid=!isNull _contact && {alive _contact} && {_contact isKindOf "CAManBase"}
    && {isNull objectParent _contact} && {(side group _actor) getFriend (side _contact) < 0.6}
    && {_actor knowsAbout _contact >= 1} && {_belief call _vectorValid} && {!isNull _building};
if (!isNull _contact && {!_contactValid}) exitWith {[]};
// A clear believed firing line is a veto on relocation, not proof of a hit or exact enemy pose.
private _nativeFiringClear=false;
if (_contactValid && {_engaging == _contact} && {_actor distance2D _belief <= 20}) then {
    _nativeFiringClear=([_actor,"FIRE",_contact] checkVisibility
        [eyePos _actor,(AGLToASL _belief) vectorAdd [0,0,1]]) >= 0.9;
};
if (_nativeFiringClear) exitWith {[]};
private _group=group _actor;
private _index=currentWaypoint _group;
private _authored=_index > 0 && {_index < count waypoints _group};
private _waypoint=[_group,_index];
if (_authored && {waypointType _waypoint != "MOVE" || {waypointScript _waypoint != ""}
    || {waypointDescription _waypoint == "WAIT AI PASS"}
    || {(waypointStatements _waypoint) isNotEqualTo ["true",""]}
    || {(waypointTimeout _waypoint) findIf {_x != 0} >= 0}
    || {synchronizedWaypoints _waypoint isNotEqualTo []}
    || {synchronizedTriggers _waypoint isNotEqualTo []}
    || {!isNull waypointAttachedObject _waypoint}
    || {!isNull waypointAttachedVehicle _waypoint}}) exitWith {[]};
private _destination=(expectedDestination _actor) param [0,[],[[]]];
if (!(_destination call _vectorValid)) then {_destination=[]};
// Preserve a native combat approach already aimed into this house. The caller may observe
// progress and use scoped door interaction; this receipt grants no existing-leg cleanup rights.
private _observe=_contactValid && {_engaging == _contact} && {_command in ["MOVE","ATTACK"]}
    && {_destination isNotEqualTo []} && {_destination vectorDistance _belief <= 2.5};
if (_observe) then {
    private _bounds=boundingBoxReal _building;
    private _model=_building worldToModel _destination;
    private _low=_bounds select 0; private _high=_bounds select 1;
    _observe=(_model select 0) > (_low select 0) && {(_model select 0) < (_high select 0)}
        && {(_model select 1) > (_low select 1)} && {(_model select 1) < (_high select 1)}
        && {(_model select 2) >= (_low select 2)-0.5} && {(_model select 2) <= (_high select 2)};
};
if (_observe) exitWith {["OBSERVE","COMBAT_APPROACH",+_destination,_engaging]};
if (_unitState == "BUSY") exitWith {[]};
private _mayIssue=_command == "" || {_command in ["ATTACK","FIRE"] && {_contactValid} && {_engaging == _contact}}
    || {_command == "MOVE" && {_authored} && {_destination isNotEqualTo []}
        && {_destination vectorDistance waypointPosition _waypoint <= 3}};
if (!_mayIssue) exitWith {[]};
private _intent=if (_contactValid && {_command in ["","ATTACK","FIRE"]}) then {"CONTACT"} else {_command};
["ISSUE",_intent,+_destination,[_engaging,_contact] select _contactValid]

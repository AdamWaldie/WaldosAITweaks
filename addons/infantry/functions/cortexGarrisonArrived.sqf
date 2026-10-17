/*
 * Author: WaldoTheWarfighter
 * Purpose: Checks actual occupation of a garrison post, including wall/floor separation and exterior exit observation.
 * Locality/authority: read-only on the current group owner; issues no commands or assignments.
 * Repeat/JIP: fresh geometry on each check, no cached success or side effects to replay.
 * Arguments: 0 actor <OBJECT>, objNull; 1 assignment <ARRAY>, [] (position, facing, building, transform, role, watch, exit).
 * Return: BOOL - physically at the post with the required geometry; not proof of hostile-room clearance.
 * Current callers: CortexGarrisonApplyLocal and CortexGarrisonRefill.
 * Example: [soldier1,soldier1 getVariable ["WAIT_AIPass_GarrisonPos",[]]] call WAIT_fnc_CortexGarrisonArrived;
 */
params [["_actor",objNull,[objNull]],["_assignment",[],[[]]]];
if (isNull _actor || {!alive _actor}) exitWith {false};
    if (count _assignment < 2 || {(_assignment param [4,"INTERIOR"]) == "EXTERIOR_PENDING"}) exitWith {false};
    private _purpose=_assignment param [4,"INTERIOR"];
    private _actual=getPosASL _actor;
    private _target=AGLToASL (_assignment select 0);
    private _radius=[1.5,2] select (_purpose == "EXTERIOR");
    if (_actual vectorDistance _target > _radius || {abs ((_actual select 2)-(_target select 2)) > 0.75}) exitWith {false};
    private _building=_assignment param [2,objNull];
    if (isNull _building) exitWith {true};
    private _bounds=boundingBoxReal _building;
    private _pose=_building worldToModel (getPosATL _actor);
    private _low=_bounds select 0;
    private _high=_bounds select 1;
    if (_purpose == "EXTERIOR") exitWith {
        private _outside=(_pose select 0) < (_low select 0)-0.5 || {(_pose select 0) > (_high select 0)+0.5}
            || {(_pose select 1) < (_low select 1)-0.5} || {(_pose select 1) > (_high select 1)+0.5};
        private _watch=_assignment param [5,[],[[]]];
        _outside && {count _watch == 3} && {!terrainIntersectASL [eyePos _actor,AGLToASL _watch]}
            && {(lineIntersectsSurfaces [eyePos _actor,AGLToASL _watch,_actor,objNull,true,1,"VIEW","NONE"]) isEqualTo []}
    };
    if ((_pose select 0) < (_low select 0) || {(_pose select 0) > (_high select 0)}
        || {(_pose select 1) < (_low select 1)} || {(_pose select 1) > (_high select 1)}
        || {(_pose select 2) < (_low select 2)} || {(_pose select 2) > (_high select 2)}) exitWith {false};
    private _hits=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.6],_target vectorAdd [0,0,0.6],_actor,objNull,true,8,"GEOM","NONE"];
    count _hits < 8 && {_hits findIf {(_x select 2) == _building || {(_x select 3) == _building}} < 0}

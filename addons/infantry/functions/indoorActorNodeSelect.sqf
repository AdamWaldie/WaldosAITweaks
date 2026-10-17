/*
 * Author: WaldoTheWarfighter
 * Purpose: Plan one actor's indoor observation destination near a supplied native contact belief.
 * Locality/authority: Read-only on the actor and group owner. No movement or access is granted.
 * Repeat/JIP: Read-only. At most 512 native positions are ranked and three roof queries are issued.
 * Up to four actor-local failed-node observations temporarily exclude matching destinations only
 * while the original owner epoch, building transform and sixty-second expiry remain valid.
 * A caller must retain the building transform, recheck authority and observe physical arrival.
 * Arguments: 0 actor <OBJECT>, objNull; 1 building <OBJECT>, objNull;
 * 2 believed ATL position <ARRAY>, []; 3 reserved ATL destinations <ARRAY>, [].
 * Return: ARRAY - one native ATL position, or [] for invalid, occupied or unroofed candidates.
 * Navigation metadata and roof ownership do not establish accessibility or a safe room.
 * Current callers: WAIT_fnc_IndoorActorOperation SELECT phase, including natural dispatch.
 * Example: private _node=[soldier1,house1,[100,100,2],[]] call WAIT_fnc_IndoorActorNodeSelect;
 */
params [["_actor",objNull,[objNull]],["_building",objNull,[objNull]],
    ["_belief",[],[[]]],["_reserved",[],[[]]]];
private _positionValid={
    _this isEqualType [] && {count _this == 3}
        && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
if (isNull _actor || {!local _actor} || {!local group _actor}
    || {isNull _building} || {!alive _building} || {!(_belief call _positionValid)}
    || {count _reserved > 16}) exitWith {[]};
// Reject unknown reservations rather than sending a second actor to an unverified destination.
if (_reserved findIf {!(_x call _positionValid)} >= 0) exitWith {[]};
private _failedNodes=[];
private _epoch=(group _actor) getVariable ["WAIT_AIPass_Epoch",0];
private _transform=[getPosWorld _building,vectorDir _building,vectorUp _building];
{
    if (_x isEqualType [] && {count _x == 5} && {(_x select 0) isEqualTo _building}
        && {(_x select 1) isEqualTo _transform} && {(_x select 2) call _positionValid}
        && {(_x select 3) isEqualType 0} && {finite (_x select 3)} && {serverTime < (_x select 3)}
        && {(_x select 4) isEqualTo _epoch}) then {_failedNodes pushBack +(_x select 2)};
} forEach ((_actor getVariable ["WAIT_IndoorActor_NodeFailures",[]]) select [0,4]);
private _positions=_building buildingPos -1;
if (count _positions > 512) exitWith {[]};
private _bounds=boundingBoxReal _building;
private _low=_bounds select 0;
private _high=_bounds select 1;
private _beliefHeight=(AGLToASL _belief) select 2;
private _origin=getPosATL _actor;
private _ranked=[];
{
    private _node=_x;
    if (_node call _positionValid) then {
        private _model=_building worldToModel _node;
        private _inside=(_model select 0) > (_low select 0) && {(_model select 0) < (_high select 0)}
            && {(_model select 1) > (_low select 1)} && {(_model select 1) < (_high select 1)}
            && {(_model select 2) >= (_low select 2)-0.5} && {(_model select 2) <= (_high select 2)};
        private _height=(AGLToASL _node) select 2;
        if (_inside && {abs (_height-_beliefHeight) <= 1.5}
            && {_reserved findIf {_x vectorDistance _node < 1.5} < 0}
            && {_failedNodes findIf {_x vectorDistance _node < 1.5} < 0}) then {
            // Belief proximity first; actor travel breaks ties without consulting enemy transforms.
            _ranked pushBack [_node distance2D _belief,_node distance2D _origin,_forEachIndex];
        };
    };
} forEach _positions;
_ranked sort true;
private _selected=[];
{
    if (_selected isNotEqualTo []) exitWith {};
    private _node=_positions select (_x select 2);
    private _asl=AGLToASL _node;
    private _hits=lineIntersectsSurfaces [_asl vectorAdd [0,0,0.4],
        _asl vectorAdd [0,0,10],_actor,objNull,true,1,"GEOM","NONE"];
    if (_hits isNotEqualTo []) then {
        private _hit=_hits select 0;
        if ((_hit select 2) == _building || {(_hit select 3) == _building}) exitWith {
            _selected=+_node;
        };
    };
} forEach (_ranked select [0,3]);
_selected

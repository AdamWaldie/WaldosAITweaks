/*
 * Author: WaldoTheWarfighter
 * Purpose: Select one fresh hostile infantry belief inside target-owned building geometry.
 * Locality/authority: read-only, current local group owner. Uses native knowledge records,
 * never a hostile live transform; does not create an operation or grant movement authority.
 * Repeat/JIP: stateless, bounded to three eligible records and at most three roof queries.
 * Results are observations for this call, not persistent access or room-clearance receipts.
 * Arguments: 0: group <GROUP>, grpNull; 1: knowledge records <ARRAY>, [], each
 * [hostile OBJECT, believed ATL ARRAY, age seconds NUMBER, range metres NUMBER, ...];
 * 2: maximum belief range <NUMBER>, 100, finite and positive (clamped to 1000).
 * Return Value: Array [building OBJECT, hostile OBJECT, [believed ATL ARRAY, server timestamp]]
 * or [] if no qualifying observation. Metadata/topology does not prove physical access.
 * Current callers: WAIT_fnc_CortexBuildingContact.
 * Example: private _contact=[group player,_knowledge,100] call WAIT_fnc_BuildingContactSelect;
 */
params [["_group",grpNull,[grpNull]],["_enemies",[],[[]]],["_range",100,[0]]];
if (isNull _group || {!local _group} || {!finite _range} || {_range <= 0}) exitWith {[]};
_range=_range min 1000;
private _records=_enemies select {
    if !(_x isEqualType []) exitWith {false};
    private _enemy=_x param [0,objNull,[objNull]];
    private _belief=_x param [1,[],[[]]];
    private _age=_x param [2,1e6,[0]];
    private _distance=_x param [3,1e6,[0]];
    count _belief == 3 && {_belief findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {finite _age} && {_age >= 0} && {_age <= 5}
        && {finite _distance} && {_distance >= 0} && {_distance <= _range}
        && {!isNull _enemy} && {_enemy isKindOf "CAManBase"} && {alive _enemy}
        && {isNull objectParent _enemy} && {(side _group) getFriend (side _enemy) < 0.6}
};
if (count _records > 3) then {_records resize 3};
private _selected=[];
{
    if (_selected isNotEqualTo []) exitWith {};
    private _enemy=_x select 0;
    private _belief=+(_x select 1);
    // Resolve the actual overhead owner first. Nearest building centres are not a
    // containment test: an adjacent small house can be closer than this house's centre.
    private _origin=AGLToASL _belief;
    private _hits=lineIntersectsSurfaces [_origin vectorAdd [0,0,0.4],
        _origin vectorAdd [0,0,20],_enemy,objNull,true,4,"GEOM","NONE"];
    if (_hits isNotEqualTo []) then {
        private _nearest=_hits select 0;
        private _building=_nearest select 3;
        if (isNull _building) then {_building=_nearest select 2};
        // Modded structural classes may derive directly from Building rather than House.
        // Native positions and this nearest owned roof still gate admission, not the label alone.
        if (!isNull _building && {_building isKindOf "House" || {_building isKindOf "Building"}}
            && {(_building buildingPos -1) isNotEqualTo []}) then {
            private _bounds=boundingBoxReal _building;
            private _low=_bounds select 0;
            private _high=_bounds select 1;
            private _model=_building worldToModel _belief;
            private _inside=(_model select 0) >= (_low select 0) && {(_model select 0) <= (_high select 0)}
                && {(_model select 1) >= (_low select 1)} && {(_model select 1) <= (_high select 1)}
                && {(_model select 2) >= (_low select 2)-0.5} && {(_model select 2) <= (_high select 2)};
            if (_inside) then {
                _selected=[_building,_enemy,[+_belief,serverTime-(_x select 2)]];
            };
        };
    };
} forEach _records;
_selected

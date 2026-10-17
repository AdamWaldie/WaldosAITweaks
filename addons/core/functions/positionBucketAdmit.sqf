/*
 * Author: WaldoTheWarfighter
 * Purpose: Admits an absolute-coordinate position into a bounded 3D duplicate index.
 * Locality/authority: computation only; mutates the caller-owned temporary HashMap, never world state.
 * Repeat/JIP: use one fresh grid per admission pass and one separation throughout. No public replay.
 * Arguments: 0 position ASL <ARRAY>, []; 1 private grid <HASHMAP>, empty; 2 separation <NUMBER>, 1 m.
 * Return: BOOL - true and records the point if no prior point is strictly closer than separation.
 * Current callers: CortexGarrison and CortexClearBuilding admission; each limits input to 512 points.
 * Work: 27 neighboring cells, at most eight admitted positions per cell; no growing full-list scan.
 * Example: private _grid=createHashMap; [getPosASL soldier1,_grid,0.5] call WAIT_fnc_PositionBucketAdmit;
 */
params [["_position",[],[[]]],["_grid",createHashMap,[createHashMap]],["_separation",1,[0]]];
if (count _position != 3 || {_position findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} >= 0}
    || {!finite _separation} || {_separation < 0.1} || {_separation > 10} || {count _grid > 512}) exitWith {false};
private _cell=_position apply {floor (_x/_separation)};
private _blocked=false;
for "_dx" from -1 to 1 do {
    if (_blocked) exitWith {};
    for "_dy" from -1 to 1 do {
        if (_blocked) exitWith {};
        for "_dz" from -1 to 1 do {
            private _key=([(_cell select 0)+_dx,(_cell select 1)+_dy,(_cell select 2)+_dz] apply {_x toFixed 0}) joinString ":";
            private _near=_grid getOrDefault [_key,[]];
            if (count _near > 8 || {_near findIf {_x vectorDistance _position < _separation} >= 0}) exitWith {_blocked=true};
        };
    };
};
if (_blocked) exitWith {false};
private _key=(_cell apply {_x toFixed 0}) joinString ":";
private _bucket=_grid getOrDefault [_key,[]];
if (count _bucket >= 8 || {count _grid >= 512 && {!(_key in _grid)}}) exitWith {false};
_bucket pushBack +_position;
_grid set [_key,_bucket];
true

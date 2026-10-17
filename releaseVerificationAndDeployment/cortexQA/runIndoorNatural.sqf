/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe natural contact-to-indoor admission and physical entry without direct START calls.
 * Locality/authority: Scheduled dedicated server, normal batch only; ordinary groups remain server-owned.
 * Repeat/JIP: Disposable fresh fixtures. Public labels/results serve observers; production completion
 * and knowledge are never injected. Invulnerable participants isolate routing from casualty timing;
 * this is not combat-effectiveness acceptance. The hostile fires using native commands.
 * Arguments: check CODE, phase CODE, wait CODE, required audit callbacks.
 * Return: Nothing. Current caller: cortexQA/runServer.sqf, indoornatural focus.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAIndoorNatural.sqf";
 */
params ["_check","_phase","_wait"];
if (!isServer || {missionNamespace getVariable ["WAIT_CortexQA_HeadlessBatch",false]}) exitWith {
    ["INDOOR-NATURAL-normal-prerequisite",false] call _check;
};
private _site=[9000,9800,0];
private _house=createVehicle ["Land_i_House_Small_01_V1_F",_site,[],0,"NONE"];
_house enableSimulationGlobal true;
// Validate the new house before spawning any participant; never repair placement during the case.
private _highestAccess=-1e12;
for "_index" from 0 to 15 do {
    private _entry=_house buildingExit _index;
    if (_entry isEqualTo [0,0,0]) exitWith {};
    _highestAccess=_highestAccess max (((AGLToASL _entry) select 2)-getTerrainHeightASL _entry);
};
private _lift=0;
if (_highestAccess < -0.05 && {_highestAccess >= -0.35}) then {
    _lift=(ceil ((0.15-_highestAccess)/0.05))*0.05;
    _house setPosATL ((getPosATL _house) vectorAdd [0,0,_lift]);
};
["INDOOR-NATURAL-placement-access",_highestAccess+_lift >= -0.05,str [_highestAccess,_lift]] call _check;
if (_highestAccess+_lift < -0.05) exitWith {deleteVehicle _house};

private _rooms=_house buildingPos -1;
["INDOOR-NATURAL-fixture-positions",_rooms isNotEqualTo []] call _check;
if (_rooms isEqualTo []) exitWith {deleteVehicle _house};
private _group=createGroup [east,true];
private _enemyGroup=createGroup [west,true];
{
    _x setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
} forEach [_group,_enemyGroup];
_enemyGroup setVariable ["WAIT_AI_Exclude",true,true];
_group setCombatMode "YELLOW";
private _actors=[];
for "_i" from 0 to 1 do {
    private _actor=_group createUnit ["O_Soldier_F",_site vectorAdd [-4+_i*5,-30,0],[],0,"NONE"];
    _actor allowDamage false;
    _actor setVariable ["WAIT_CortexQA_Label",format ["NATURAL entry %1",_i+1],true];
    _actors pushBack _actor;
};
private _enemy=_enemyGroup createUnit ["B_Soldier_F",_rooms select 0,[],0,"CAN_COLLIDE"];
_enemy allowDamage false;
_enemy setVariable ["WAIT_CortexQA_Label","NATURAL hostile (invulnerable routing fixture)",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_actors+[_enemy],true];
{_x addCuratorEditableObjects [[_house]+_actors+[_enemy],true]} forEach allCurators;
private _starts=_actors apply {getPosATL _x};
private _knowledge=[false,false];
private _admitted=[false,false];
private _visits=[false,false];
private _travel=[0,0];
private _generations=[-1,-1];
private _inside={
    params ["_actor"];
    private _position=getPosATL _actor;
    private _model=_house worldToModel _position;
    private _bounds=boundingBoxReal _house;
    private _low=_bounds select 0; private _high=_bounds select 1;
    private _roof=lineIntersectsSurfaces [(getPosASL _actor) vectorAdd [0,0,0.4],
        (getPosASL _actor) vectorAdd [0,0,10],_actor,objNull,true,1,"GEOM","NONE"];
    (_model select 0) > (_low select 0) && {(_model select 0) < (_high select 0)}
        && {(_model select 1) > (_low select 1)} && {(_model select 1) < (_high select 1)}
        && {(_model select 2) >= (_low select 2)} && {(_model select 2) <= (_high select 2)}
        && {_roof isNotEqualTo []}
        && {private _hit=_roof select 0; (_hit select 2) == _house || {(_hit select 3) == _house}}
};
["INDOOR-NATURAL-hostile-interior",[_enemy] call _inside,str (getPosATL _enemy)] call _check;
["Natural indoor contact fallback","Two soldiers must acquire native knowledge of the firing hostile, receive natural indoor jobs and physically enter. No reveal, direct START, forced doors or test-side movement helps them. Invulnerability isolates routing; this is not combat-effectiveness acceptance.",getPosATL _house] call _phase;
_enemy doTarget (_actors select 0);
_enemy doFire (_actors select 0);
private _complete=[{
    {
        private _index=_forEachIndex;
        if (_x knowsAbout _enemy >= 1) then {_knowledge set [_index,true]};
        private _journal=_x getVariable ["WAIT_IndoorActor_Order",[]];
        if (count _journal == 9) then {
            private _brain=_x getVariable ["WAIT_IndoorActor_Brain",createHashMap];
            if ((_brain getOrDefault ["contact",objNull]) == _enemy
                && {(_brain getOrDefault ["building",objNull]) == _house}) then {
                _admitted set [_index,true]; _generations set [_index,_journal select 0];
            };
        };
        _travel set [_index,(_travel select _index) max ((getPosATL _x) vectorDistance (_starts select _index))];
        if ((_admitted select _index) && {[_x] call _inside}) then {_visits set [_index,true]};
    } forEach _actors;
    _visits findIf {!_x} < 0
},90] call _wait;
["INDOOR-NATURAL-engine-knowledge",_knowledge findIf {!_x} < 0,str _knowledge] call _check;
["INDOOR-NATURAL-dispatch-admission",_admitted findIf {!_x} < 0,str [_admitted,_generations]] call _check;
["INDOOR-NATURAL-physical-entry",_complete && {_visits findIf {!_x} < 0}
    && {_travel findIf {_x < 5} < 0},str [_visits,_travel]] call _check;
["INDOOR-NATURAL-server-owner",groupOwner _group == 2 && {_actors findIf {!local _x} < 0}] call _check;
{["FINISH",_x,createHashMap] call WAIT_fnc_IndoorActorOperation; deleteVehicle _x} forEach _actors;
deleteVehicle _enemy; deleteGroup _group; deleteGroup _enemyGroup; deleteVehicle _house;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
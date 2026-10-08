/*
 * Author: WaldoTheWarfighter
 * Purpose: Verify WAIT's standalone danger-FSM ownership, exclusive finite movement lease and
 * clean Zeus replacement using physical group movement.
 * Locality / Authority: Dedicated server creates and owns the fixture. Movement and lease changes
 * run only on the current group owner; public audit labels are observer diagnostics.
 * Repeat/JIP: Creates fresh actors, removes owned waypoints and deletes the fixture on completion.
 * Arguments: 0 check <CODE>; 1 phase <CODE>; 2 wait <CODE>.
 * Return Value: Nothing.
 * Current callers: cortexQAServer.sqf compatibility focus and additive audit.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "runCompatibility.sqf";
 */
params ["_check","_phase","_wait"];

private _configuredDanger=[];
{
    private _configured=toLowerANSI getText (configFile >> "CfgVehicles" >> _x >> "fsmDanger");
    _configuredDanger pushBack [_x,_configured];
    ["COMPAT-exclusive-danger-fsm-"+toLowerANSI _x,_configured find "\z\waldo_ai_tweaks\addons\infantry\fsm\danger.fsm" >= 0,_configured] call _check;
} forEach ["SoldierWB","SoldierEB","SoldierGB"];
["COMPAT-exclusive-danger-fsm",_configuredDanger findIf {(_x select 1) find "\z\waldo_ai_tweaks\addons\infantry\fsm\danger.fsm" < 0} < 0,str _configuredDanger] call _check;

private _group=createGroup [east,true];
_group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_group setVariable ["acex_headless_blacklist",true,true];
_group setGroupIdGlobal ["WAIT QA ownership handover"];
private _units=[];
for "_i" from 0 to 2 do {
    private _unit=_group createUnit ["O_Soldier_F",[2600+(_i*3),2400,0],[],0,"NONE"];
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["OWNERSHIP SOLDIER %1",_i+1],true];
    _units pushBack _unit;
};
missionNamespace setVariable ["WAIT_CortexQA_Actors",_units,true];

[createHashMapFromArray [
    ["WAIT_AIPass_Enable",true],
    ["WAIT_AIPass_Contact_Enable",false],
    ["WAIT_AIPass_Regroup_Enable",false]
]] call WAIT_fnc_CortexTuning;
[{missionNamespace getVariable ["WAIT_AIPass_Active",false]},20] call _wait;

private _hold=[2600,2470,0];
{_x setVariable ["WAIT_CortexQA_Target",_hold,true]} forEach _units;
["COMPAT: standalone WAIT movement","The whole squad must move north and hold separate defence positions. An accepted order alone cannot pass.",_hold] call _phase;
private _starts=_units apply {getPosATL _x};
private _accepted=[_group,_hold,0,14] call WAIT_fnc_CortexDefend;
private _arrived=[{
    (_units findIf {
        private _assignment=_x getVariable ["WAIT_AIPass_DefendPos",[]];
        !alive _x || {_assignment isEqualTo []} || {_x distance2D (_assignment select 0) > 5}
    }) < 0
},90] call _wait;
private _travelled=true;
{if (_x distance2D (_starts select _forEachIndex) < 35) then {_travelled=false}} forEach _units;
["COMPAT-standalone-physical-arrival",_accepted && {_arrived} && {_travelled},str (_units apply {getPosATL _x})] call _check;
[_group] call WAIT_fnc_CortexDefendRelease;

_group setVariable ["WAIT_Cortex_MovementLease",nil,true];
private _leased=[_group,"QA-PRIMARY",true,serverTime+60] call WAIT_fnc_CortexOwnershipLease;
private _competingRefused=!([_group,"QA-COMPETING",true,serverTime+60] call WAIT_fnc_CortexOwnershipLease);
private _lease=_group getVariable ["WAIT_Cortex_MovementLease",[]];
["COMPAT-movement-lease-exclusive",_leased && {_competingRefused}
    && {count _lease == 2} && {(_lease select 0) == "QA-PRIMARY"}] call _check;
private _wrongReleaseRefused=!([_group,"QA-COMPETING",false] call WAIT_fnc_CortexOwnershipLease);
private _released=[_group,"QA-PRIMARY",false] call WAIT_fnc_CortexOwnershipLease;
["COMPAT-movement-lease-release",_wrongReleaseRefused && {_released}
    && {(_group getVariable ["WAIT_Cortex_MovementLease",[]]) isEqualTo []}] call _check;

private _handoverStart=_units apply {getPosATL _x};
private _waitDestination=[2670,2470,0];
[_group,_waitDestination,5] call WAIT_fnc_CortexGroupMove;
["COMPAT: Zeus replacement","The squad must begin the eastward WAIT move, then follow the south-west Zeus waypoint without old-route resurrection.",_waitDestination] call _phase;
private _started=[{
    private _all=true;
    {if (_x distance2D (_handoverStart select _forEachIndex) < 10) then {_all=false}} forEach _units;
    _all
},35] call _wait;
["COMPAT-zeus-handover-stimulus",_started] call _check;
[_group,true] call WAIT_fnc_CortexZeusMark;
private _replacement=[2540,2425,0];
private _wp=_group addWaypoint [_replacement,0];
_wp setWaypointType "MOVE";
_wp setWaypointCompletionRadius 4;
_group setCurrentWaypoint _wp;
{_x setVariable ["WAIT_CortexQA_Target",_replacement,true]; _x doFollow leader _group} forEach _units;
private _replacementReached=[{(_units findIf {!alive _x || {_x distance2D _replacement > 12}}) < 0},90] call _wait;
["COMPAT-zeus-replacement-physical-arrival",_started && {_replacementReached},str (_units apply {getPosATL _x})] call _check;
private _maxDrift=0;
for "_sample" from 1 to 12 do {sleep 1; {_maxDrift=_maxDrift max (_x distance2D _replacement)} forEach _units};
["COMPAT-zeus-clean-release",_replacementReached && {_maxDrift <= 15},str _maxDrift] call _check;

[_group] call WAIT_fnc_CortexReleaseGroup;
{deleteVehicle _x} forEach _units;
deleteGroup _group;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];

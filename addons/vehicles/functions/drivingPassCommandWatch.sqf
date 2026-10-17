/*
 * Author: WaldoTheWarfighter
 * Purpose: Records an observed native group STOP during one exact road pass.
 * Locality/authority: Installs on the current group/vehicle owner. The handler only records
 * interruption; it issues no AI command and grants no movement authority. Own fixed-path setup
 * is fenced by an exact temporary write marker. Engine event timing and repeated identical
 * STOP coverage remain physical test requirements; group events do not identify an actor.
 * Repeat/JIP: One finite generation/token-bound local handler. Finish/locality removes it;
 * an expired or nonlocal callback removes itself. No handler or command replay to JIP.
 * Arguments: 0 group <GROUP>, grpNull; 1 vehicle <OBJECT>, objNull;
 * 2 work <HASHMAP>, empty; 3 release <BOOL>, false. Release permits nonlocal local-EH cleanup.
 * Return: BOOL - watch installed or matching watch removed, not interruption acceptance.
 * Current callers: DrivingPassBegin/Finish, CortexLocality and DrivingOperationFinish.
 * Example: [_group,_vehicle,_work] call WAIT_fnc_DrivingPassCommandWatch;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],
    ["_work",createHashMap,[createHashMap]],["_release",false,[true]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _group}) exitWith {false};
private _old=_group getVariable ["WAIT_DrivingPass_CommandWatch",[]];
private _token=_work getOrDefault ["token",""];
private _epoch=_work getOrDefault ["epoch",-1];
private _generation=_work getOrDefault ["generation",-1];
private _remove={
    if (count _old == 6 && {(_group getVariable ["WAIT_DrivingPass_CommandWatch",[]]) isEqualTo _old}) then {
        _group removeEventHandler ["CommandChanged",_old select 4];
        _group setVariable ["WAIT_DrivingPass_CommandWatch",nil];
    };
};
if (_release) exitWith {
    if (count _old != 6 || {(_old select 0) != _vehicle}
        || {_token != "" && {(_old select 1) != _token}}
        || {_epoch >= 0 && {(_old select 2) != _epoch}}
        || {_generation >= 0 && {(_old select 3) != _generation}}) exitWith {false};
    call _remove;true
};
if (isNull _vehicle || {!local _vehicle} || {!local _group} || {_token == ""}
    || {_epoch != (_group getVariable ["WAIT_AIPass_Epoch",0])}
    || {(_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap]) isNotEqualTo _work}
    || {serverTime >= (_work getOrDefault ["deadline",-1])}) exitWith {false};
if (count _old == 6 && {(_old select [0,4]) isEqualTo [_vehicle,_token,_epoch,_generation]}) exitWith {true};
call _remove;
private _id=_group addEventHandler ["CommandChanged",{
    params ["_group","_command"];
    private _binding=_group getVariable ["WAIT_DrivingPass_CommandWatch",[]];
    if (count _binding != 6 || {(_binding select 4) != _thisEventHandler}) exitWith {};
    _binding params ["_vehicle","_token","_epoch","_generation","","_deadline"];
    if (!local _group || {!local _vehicle} || {serverTime >= _deadline}
        || {_epoch != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {
        _group removeEventHandler ["CommandChanged",_thisEventHandler];
        _group setVariable ["WAIT_DrivingPass_CommandWatch",nil];
    };
    if (toUpperANSI _command != "STOP"
        || {(_group getVariable ["WAIT_DrivingPass_CommandWriting",[]]) isEqualTo [_vehicle,_token,_epoch,_generation]}) exitWith {};
    private _work=_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap];
    if ((_work getOrDefault ["group",grpNull]) != _group
        || {(_work getOrDefault ["token",""]) != _token}
        || {(_work getOrDefault ["epoch",-1]) != _epoch}
        || {(_work getOrDefault ["generation",-1]) != _generation}) exitWith {};
    // Observation only: command execution from this engine callback is deliberately forbidden.
    _work set ["interrupted",true];
    _vehicle setVariable ["WAIT_DrivingPass_Interrupted",[_token,_epoch,_generation,clientOwner,serverTime],true];
}];
if (_id < 0) exitWith {false};
_group setVariable ["WAIT_DrivingPass_CommandWatch",[_vehicle,_token,_epoch,_generation,_id,_work get "deadline"]];
true

/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one server-owned finite brain for an accepted WAIT artillery or counter-battery mission.
 * Locality / Authority: Server only. The FSM owns mission persistence; battery-owner callbacks retain bounded observation and physical fire execution.
 * Repeat/JIP: The exact mission token reuses its brain. A newer token increments the generation and invalidates older queued work; missions are not replayed after restart.
 * Arguments: 0 fire mission <HASHMAP>; 1 initial delay <NUMBER>, default 0.
 * Return Value: Boolean - true when the exact mission has an active brain.
 * Current caller: WAIT_fnc_CortexArtilleryFire.
 * Example: [_mission,0] call WAIT_fnc_ArtilleryMissionStart;
 */
params [["_mission",createHashMap,[createHashMap]],["_delay",0,[0]]];
if (!isServer || {count _mission == 0}) exitWith {false};
private _battery=_mission getOrDefault ["battery",objNull];
private _token=_mission getOrDefault ["token",""];
private _key=_mission getOrDefault ["key",""];
if (isNull _battery || {_token == ""} || {_key == ""}) exitWith {false};
private _registered=(missionNamespace getVariable ["WAIT_AIPass_FireMissions",createHashMap]) getOrDefault [_key,createHashMap];
if (_registered isNotEqualTo _mission) exitWith {false};
private _current=_battery getVariable ["WAIT_Artillery_Brain",createHashMap];
if (count _current > 0 && {(_current getOrDefault ["token",""]) == _token}
    && {!(_current getOrDefault ["cancelled",false])} && {!(_current getOrDefault ["finished",false])}) exitWith {true};
if (count _current > 0) then {_current set ["cancelled",true];_current set ["cancelReason","REPLACED"]};
private _generation=(_battery getVariable ["WAIT_Artillery_BrainGeneration",0])+1;
private _brain=createHashMapFromArray [
    ["battery",_battery],["mission",_mission],["token",_token],["generation",_generation],
    ["phase","REQUESTED"],["pending",false],["completed",false],["finished",false],
    ["cancelled",false],["cancelReason",""],["nextAt",time+(_delay max 0)],
    ["lastStepAt",-1],["lastDelay",_delay max 0],["queuedAt",-1],["watchdogCount",0]
];
_battery setVariable ["WAIT_Artillery_BrainGeneration",_generation];
_battery setVariable ["WAIT_Artillery_Brain",_brain];
_battery setVariable ["WAIT_Artillery_Brain_State",["REQUESTED",_generation,serverTime,"STARTED"],true];
private _handle=[_mission,_generation,_brain] execFSM "\z\waldo_ai_tweaks\addons\main\fsm\artilleryMission.fsm";
_battery setVariable ["WAIT_Artillery_Brain_FSM",_handle];
true

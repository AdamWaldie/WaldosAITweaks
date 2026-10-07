/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes one bounded artillery implementation step and reports its semantic phase to the finite mission FSM.
 * Locality / Authority: Server only through WAIT's shared scheduler. Battery and observer owners still execute checked physical commands through existing callbacks.
 * Repeat/JIP: One-shot callback. Exact token, generation, brain identity and mission registry identity reject stale work; no fire command is retried after an uncertain result.
 * Arguments: 0 artillery brain <HASHMAP>.
 * Return Value: Number - always -1 because the FSM owns later scheduling.
 * Current caller: WAIT_fnc_ArtilleryMissionQueue through WAIT_fnc_CortexQueueJob.
 * Example: [_brain] call WAIT_fnc_ArtilleryMissionStep;
 */
params [["_brain",createHashMap,[createHashMap]]];
private _battery=_brain getOrDefault ["battery",objNull];
private _generation=_brain getOrDefault ["generation",-1];
private _mission=_brain getOrDefault ["mission",createHashMap];
private _token=_brain getOrDefault ["token",""];
private _cancel={
    params ["_reason"];
    _brain set ["pending",false];
    _brain set ["completed",true];
    _brain set ["finished",true];
    _brain set ["cancelled",true];
    _brain set ["cancelReason",_reason];
    -1
};
if (!isServer || {isNull _battery} || {count _mission == 0}) exitWith {["INVALID_MISSION"] call _cancel};
if (_generation != (_battery getVariable ["WAIT_Artillery_BrainGeneration",-2])
    || {(_battery getVariable ["WAIT_Artillery_Brain",createHashMap]) isNotEqualTo _brain}) exitWith {["REPLACED"] call _cancel};
private _semantic=toUpperANSI (_brain getOrDefault ["phase","REQUESTED"]);
private _registered=createHashMap;
if (_semantic != "RELOCATING") then {
    private _key=_mission getOrDefault ["key",""];
    _registered=(missionNamespace getVariable ["WAIT_AIPass_FireMissions",createHashMap]) getOrDefault [_key,createHashMap];
};
if (_semantic != "RELOCATING" && {_registered isNotEqualTo _mission || {(_mission getOrDefault ["token",""]) != _token}}) exitWith {["MISSION_RELEASED"] call _cancel};
private _delay=-1;
if (_semantic == "RELOCATING") then {
    private _activeToken=_battery getVariable ["WAIT_Cortex_ArtilleryScootToken",""];
    private _crewGroup=if (isNull driver _battery) then {grpNull} else {group driver _battery};
    private _operation=if (isNull _crewGroup) then {createHashMap} else {_crewGroup getVariable ["WAIT_Operation",createHashMap]};
    private _relocating=_activeToken == _token || {count _operation > 0 && {(_operation getOrDefault ["intent",""]) == "ARTILLERY_SCOOT"}};
    if (_relocating) then {_delay=2} else {_brain set ["finished",true];_brain set ["cancelReason","COMPLETE"]};
} else {
    _delay=[_mission] call WAIT_fnc_CortexArtilleryMissionStep;
    private _nativePhase=toUpperANSI (_mission getOrDefault ["phase","WAIT"]);
    _semantic=switch true do {
        case (_nativePhase in ["READY","WARNED"]): {"WARNING"};
        case (_nativePhase in ["PENDING","FIRING","UNCERTAIN"]): {"FIRING"};
        default {"REQUESTED"};
    };
    if (_delay < 0) then {
        if ((_battery getVariable ["WAIT_Cortex_ArtilleryScootToken",""]) == _token) then {
            _semantic="RELOCATING";
            _delay=1;
        } else {
            _brain set ["finished",true];
            _brain set ["cancelReason","COMPLETE"];
        };
    };
};
_brain set ["phase",_semantic];
_brain set ["lastStepAt",time];
_brain set ["lastDelay",_delay];
_brain set ["pending",false];
_brain set ["completed",true];
if (_delay >= 0) then {_brain set ["nextAt",time+_delay]};
_battery setVariable ["WAIT_Artillery_Brain_State",[
    _semantic,_generation,serverTime,_brain getOrDefault ["cancelReason",""],_delay,_mission getOrDefault ["phase","RELEASED"]
],true];
-1

/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes one bounded physical convoy step and derives its semantic FSM phase from the authoritative snapshot, contact evidence, recovery leases and measured predecessor gaps.
 * Locality / Authority: Runs through WAIT's shared scheduler on the convoy group owner. ConvoyTick rechecks authority at every vehicle command boundary.
 * Repeat/JIP: One-shot callback. Registry revision, configuration identity and job token reject stale work after settings changes, JIP replay or headless migration.
 * Spacing diagnostics reuse ConvoyTick's cached vehicle dimensions and aligned forward-gap rule.
 * Arguments: 0 convoy brain <HASHMAP> created by WAIT_fnc_ConvoyOperationStart.
 * Return Value: Number - always -1 because the FSM schedules each later step separately.
 * Current caller: WAIT_fnc_ConvoyOperationQueue through WAIT_fnc_CortexQueueJob.
 * Example: [_brain] call WAIT_fnc_ConvoyOperationStep;
 */
params [["_brain",createHashMap,[createHashMap]]];
private _group=_brain getOrDefault ["group",grpNull];private _configuration=_brain getOrDefault ["configuration",[]];private _registryRevision=_brain getOrDefault ["registryRevision",-1];private _token=_brain getOrDefault ["jobToken",""];
private _cancel={params ["_reason"];_brain set ["pending",false];_brain set ["completed",true];_brain set ["cancelled",true];_brain set ["cancelReason",_reason];-1};
if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith {[_brain getOrDefault ["cancelReason","CANCELLED"]] call _cancel};
if (isNull _group || {!local _group}) exitWith {["OWNERSHIP_LOST"] call _cancel};
if (_registryRevision != (missionNamespace getVariable ["WAIT_Convoy_ReceivedRevision",-2]) || {_token isNotEqualTo (_group getVariable ["WAIT_Convoy_LocalJobToken",""])}) exitWith {["REPLACED"] call _cancel};
private _entry=(missionNamespace getVariable ["WAIT_Convoy_LocalRegistry",[]]) findIf {(_x select 0) isEqualTo _group && {(_x select 1) isEqualTo _configuration}};
if (_entry < 0) exitWith {["REPLACED"] call _cancel};
if ([_group] call WAIT_fnc_CortexZeusHeld) exitWith {["ZEUS"] call _cancel};
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {["EXTERNAL_OWNER"] call _cancel};
[_group,_configuration] call WAIT_fnc_ConvoyTick;
private _state=_group getVariable ["WAIT_Convoy_LocalState",createHashMap];private _reason=toUpperANSI (_configuration param [8,"NONE"]);private _phase="CRUISE";private _delay=1;private _spacingPairs=0;private _recoveryActors=0;
if ((_configuration param [5,"TRAVEL"]) == "HALT") then {
 // Slow cadence belongs to a physically settled hold, not merely an accepted HALT flag.
 // Keep bounded braking/crew correction responsive while any local vehicle still moves.
 private _haltMoving=(_configuration param [4,[]]) findIf {!isNull _x && {local _x} && {alive _x} && {abs speed _x >= 1}} >= 0;
 _delay=[30,1] select _haltMoving;_phase=switch (_reason) do {case "ARRIVED":{"ARRIVED"};case "AMBUSH":{"CONTACT_HOLD"};case "MANUAL":{"ORDERED_HOLD"};case "IMMOBILE":{"IMMOBILE"};default {"OBSTRUCTION"}};
} else {
 if (_state getOrDefault ["contact",false]) then {_phase="CONTACT_HOLD"};
 if ((_state getOrDefault ["routeRecoveryAt",-1]) > time) then {_recoveryActors=_recoveryActors+1};
 private _followers=_state getOrDefault ["followers",createHashMap];
 {if (((_followers getOrDefault [_x,[]]) param [4,0]) > 0) then {_recoveryActors=_recoveryActors+1}} forEach (keys _followers);
 private _vehicles=_configuration param [4,[]];private _requested=_configuration param [2,30];
 private _specs=_state getOrDefault ["specs",createHashMap];
 for "_i" from 1 to (count _vehicles-1) do {
  private _vehicle=_vehicles select _i;private _front=_vehicles select (_i-1);
  if (!isNull _vehicle && {!isNull _front}) then {
   private _lv=(_specs getOrDefault [netId _vehicle,[0,0]]) param [1,0];
   private _lf=(_specs getOrDefault [netId _front,[0,0]]) param [1,0];
   private _target=_requested max ((_lv+_lf)*0.5+5);private _tolerance=(_target*0.2) max 3;private _gap=_vehicle distance2D _front;
   private _headingDifference=abs (((getDir _vehicle-getDir _front+540) mod 360)-180);
   if (_headingDifference <= 25 && {_gap <= _target*1.8}) then {
    private _direction=vectorDir _front;_direction set [2,0];
    private _delta=(getPosATL _front) vectorDiff (getPosATL _vehicle);_delta set [2,0];
    _gap=(_delta vectorDotProduct _direction) max 0;
   };
   if (_gap < (_target-_tolerance) || {_gap > (_target+_tolerance)}) then {_spacingPairs=_spacingPairs+1};
  };
 };
 if (_recoveryActors > 0) then {_phase="RECOVERY"} else {if (_phase != "CONTACT_HOLD" && {_spacingPairs > 0}) then {_phase="SPACING"}};
};
_brain set ["phase",_phase];_brain set ["spacingPairs",_spacingPairs];_brain set ["recoveryActors",_recoveryActors];_brain set ["lastStepAt",time];_brain set ["lastDelay",_delay];_brain set ["nextAt",time+_delay];_brain set ["pending",false];_brain set ["completed",true];
_group setVariable ["WAIT_Convoy_Brain_State",[_phase,_configuration param [0,-1],_registryRevision,serverTime,"",_spacingPairs,_recoveryActors],true];
-1

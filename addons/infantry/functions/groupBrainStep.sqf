/*
 * Author: WaldoTheWarfighter
 * Purpose: Execute one bounded group decision and publish the semantic phase consumed by the
 * owner-local tactical FSM.
 * Locality / Authority: Runs only through WAIT's shared scheduler on the group owner. It validates
 * locality, generation, Zeus and external ownership before invoking existing bounded feature logic.
 * Repeat/JIP: One-shot callback. It always returns -1; the FSM queues the next step only after the
 * committed delay or a danger wake. A migrated or superseded callback records cancellation only.
 * Arguments: 0: brain <HASHMAP> created by WAIT_fnc_GroupBrainStart.
 * Return Value: Number - always -1 because each FSM step is a separate coalesced scheduler job.
 * Current caller: WAIT_fnc_GroupBrainQueue through WAIT_fnc_CortexQueueJob.
 * Example: [_brain] call WAIT_fnc_GroupBrainStep;
 */

params [["_brain",createHashMap,[createHashMap]]];
private _group=_brain getOrDefault ["group",grpNull];
private _epoch=_brain getOrDefault ["ownerEpoch",-1];
private _generation=_brain getOrDefault ["generation",-1];
private _cancel={
    params ["_reason"];
    _brain set ["cancelled",true];
    _brain set ["cancelReason",_reason];
    _brain set ["pending",false];
    _brain set ["completed",true];
    -1
};
if (isNull _group) exitWith {["GROUP_NULL"] call _cancel};
if (_brain getOrDefault ["cancelled",false]) exitWith {
    [_brain getOrDefault ["cancelReason","CANCELLED"]] call _cancel
};
if (!local _group) exitWith {["OWNERSHIP_LOST"] call _cancel};
if (_epoch != (_group getVariable ["WAIT_AIPass_Epoch",0])) exitWith {["OWNER_EPOCH"] call _cancel};
if (_generation != (_group getVariable ["WAIT_GroupBrain_Generation",0])) exitWith {["SUPERSEDED"] call _cancel};
if (!(missionNamespace getVariable ["WAIT_AIPass_Active",false])) exitWith {["DISABLED"] call _cancel};
if ([_group] call WAIT_fnc_CortexZeusHeld) exitWith {["ZEUS"] call _cancel};
if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {["EXTERNAL_OWNER"] call _cancel};

private _legacyJob=createHashMapFromArray [["group",_group]];
private _responsiveUntil=_brain getOrDefault ["responsiveUntil",0];
if (_responsiveUntil > time) then {_legacyJob set ["responsiveUntil",_responsiveUntil]};
private _delay=[_legacyJob] call WAIT_fnc_CortexGroupTick;
if (isNil "_delay" || {!(_delay isEqualType 0)} || {_delay < 0}) exitWith {
    [if (_group getVariable ["WAIT_AIPass_Managed",false]) then {"RETIRED"} else {"RELEASED"}] call _cancel
};

private _state=[_group] call WAIT_fnc_CortexGroupState;
private _legacyPhase=_state getOrDefault ["phase","CALM"];
private _semanticPhase=switch (_legacyPhase) do {
    case "RETREAT": {"WITHDRAW"};
    case "CONTACT": {
        private _drill=_state getOrDefault ["drill",createHashMap];
        if (_state getOrDefault ["assaulting",false]) exitWith {"ASSAULT"};
        if (count _drill > 0) exitWith {
            private _stage=toUpperANSI (_drill getOrDefault ["stage",""]);
            private _reason=toUpperANSI (_drill getOrDefault ["stageReason",""]);
            if (_reason find "ASSAULT" >= 0 || {_stage == "ASSAULT"}) then {"ASSAULT"} else {"MANOEUVRE"}
        };
        if ((_group getVariable ["WAIT_AIPass_SupportLease",[]]) isNotEqualTo []
            || {(_state getOrDefault ["responding",false])}) exitWith {"SUPPORT"};
        "CONTACT"
    };
    default {_legacyPhase};
};
if (_group getVariable ["WAIT_AIPass_ClearBuilding",false]) then {_semanticPhase="CLEAR"};
_brain set ["legacyPhase",_legacyPhase];
_brain set ["phase",_semanticPhase];
_brain set ["lastStepAt",time];
_brain set ["lastDelay",_delay];
_brain set ["nextAt",time+_delay];
_brain set ["wakeAt",time+_delay];
_brain set ["pending",false];
_brain set ["completed",true];
_group setVariable ["WAIT_GroupBrain_State",[
    _semanticPhase,_generation,_epoch,serverTime,
    _state getOrDefault ["phaseReason","STEP"],
    _delay
],true];
-1

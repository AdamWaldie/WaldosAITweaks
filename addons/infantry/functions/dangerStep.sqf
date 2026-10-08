/*
 * Author: WaldoTheWarfighter
 * Purpose: Assess current danger, publish one finite response context and wake the existing group tactics FSM without creating a second tactical owner.
 * Locality / Authority: owner-local; never reveals targets or sends movement commands.
 * Repeat/JIP: generation-checked response context is public for diagnostics; a new owner rebuilds it from fresh observations.
 * Lower-priority observations cannot shorten the surviving response or its prompt scheduler cadence.
 * Arguments: 0: group <GROUP>, grpNull; 1: owner epoch <NUMBER>, -1; 2: generation <NUMBER>, -1.
 * Return Value: Number - next assessment delay, or -1 to finish.
 * Current callers: WAIT dangerAssessment FSM.
 * Example: [_group,0,1] call WAIT_fnc_DangerStep;
 */

params [["_group",grpNull,[grpNull]],["_epoch",-1,[0]],["_generation",-1,[0]]];
if (isNull _group || {!local _group} || {_epoch != (_group getVariable ["WAIT_AIPass_Epoch",0])}
    || {_generation != (_group getVariable ["WAIT_Danger_Generation",0])}) exitWith {-1};
private _actor=[_group] call WAIT_fnc_CortexGroupAnchor;
if (isNull _actor) then {_actor=leader _group};
// Danger response owns only its finite posture. Reuse the common narrow takeover question so
// ordinary setting changes can restore that posture, while Zeus, players and specialist owners
// retain their current state immediately.
private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;
if (_yieldToOwner) exitWith {
    [_actor,"RELEASE"] call WAIT_fnc_DangerReact;
    _group setVariable ["WAIT_Danger_Events",nil];
    _group setVariable ["WAIT_Danger_Response",nil,true];
    _group setVariable ["WAIT_Danger_Action",nil,true];
    private _brain=_group getVariable ["WAIT_GroupBrain",createHashMap];
    if (count _brain > 0) then {_brain deleteAt "responsiveUntil"};
    -1
};
if (!(missionNamespace getVariable ["WAIT_AIPass_Active",false])
    || {!([_group,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!([_group,false,true] call WAIT_fnc_CortexIsEligible)}) exitWith {
    if (!_yieldToOwner) then {[_actor,"RELEASE"] call WAIT_fnc_DangerReact};
    _group setVariable ["WAIT_Danger_Events",nil];
    _group setVariable ["WAIT_Danger_Response",nil,true];
    _group setVariable ["WAIT_Danger_Action",nil,true];
    private _brain=_group getVariable ["WAIT_GroupBrain",createHashMap];
    if (count _brain > 0) then {_brain deleteAt "responsiveUntil"};
    -1
};
if ([] call WAIT_fnc_CortexIsPaused) exitWith {
    // A pause can arrive in the same scheduler interval as a curator or specialist takeover.
    // Release only WAIT's still-owned posture; external ownership must retain its latest state.
    if (!_yieldToOwner) then {[_actor,"RELEASE"] call WAIT_fnc_DangerReact};
    _group setVariable ["WAIT_Danger_Events",nil];
    _group setVariable ["WAIT_Danger_Response",nil,true];
    _group setVariable ["WAIT_Danger_Action",nil,true];
    private _brain=_group getVariable ["WAIT_GroupBrain",createHashMap];
    if (count _brain > 0) then {_brain deleteAt "responsiveUntil"};
    -1
};
private _events=_group getVariable ["WAIT_Danger_Events",[]];
_group setVariable ["WAIT_Danger_Events",[]];
private _selected=[_events] call WAIT_fnc_DangerSelect;
if (_selected isEqualTo []) exitWith {
    private _response=_group getVariable ["WAIT_Danger_Response",[]];
    // Continue the finite FSM only while a response lease is live. This keeps the posture lease
    // and the group-brain wake context coherent without creating a persistent worker.
    if (count _response == 5 && {(_response select 4) == _generation} && {time < (_response select 3)}) then {
        0.25
    } else {
        // The last danger observation may expire after an external order has replaced the
        // operation. Do not restore a stale WAIT posture across that ownership boundary.
        if (!_yieldToOwner) then {[_actor,"RESTORE"] call WAIT_fnc_DangerReact};
        _group setVariable ["WAIT_Danger_Response",nil,true];
        _group setVariable ["WAIT_Danger_Action",nil,true];
        private _brain=_group getVariable ["WAIT_GroupBrain",createHashMap];
        if (count _brain > 0) then {_brain deleteAt "responsiveUntil"};
        -1
    }
};
_group setVariable ["WAIT_Danger_LastAssessment",+_selected];
_selected params ["_cause","_position","_observedAt"];
private _action=[_group,_selected] call WAIT_fnc_DangerActionSelect;
// A concrete native task is an ownership boundary, not a tactical response mode. The engine FSM may
// record the event and perform its observation-only FORCED state, but the assessment layer must not
// publish a group response, wake the tactical brain or retain an older WAIT posture. Otherwise a
// soldier boarding, healing, rearming or joining can be pulled into CONTACT by the same event that
// correctly classified that task as authoritative.
if (_action == "FORCED") exitWith {
    [_actor,"RELEASE"] call WAIT_fnc_DangerReact;
    _group setVariable ["WAIT_Danger_Response",nil,true];
    _group setVariable ["WAIT_Danger_Action",nil,true];
    private _forcedBrain=_group getVariable ["WAIT_GroupBrain",createHashMap];
    if (count _forcedBrain > 0) then {_forcedBrain deleteAt "responsiveUntil"};
    -1
};
// This is a finite handoff, not a target assignment or movement order. The group tactics FSM can
// respond on its already-owned scheduler cycle while retaining route, operation and external ownership.
private _responseDurations=createHashMapFromArray [["HIT",3],["EXPLOSION",2.5],["SUPPRESSED",2],["CASUALTY",2],["SCREAM",1.5],["DETECTED",1.5],["GUNFIRE",1]];
private _responseLifetime=_responseDurations getOrDefault [_cause,1];
private _response=[_cause,+_position,_observedAt,time+_responseLifetime,_generation];
private _existing=_group getVariable ["WAIT_Danger_Response",[]];
private _priority=createHashMapFromArray [["HIT",7],["EXPLOSION",6],["SUPPRESSED",5],["CASUALTY",4],["SCREAM",3],["DETECTED",2],["GUNFIRE",1]];
private _replace=_existing isEqualTo [] || {count _existing != 5}
    || {(_existing select 4) != _generation}
    || {time >= (_existing select 3)}
    || {(_priority getOrDefault [_cause,-1]) >= (_priority getOrDefault [_existing select 0,-1])};
if (_replace) then {
    // Keep the surviving highest-priority response authoritative. A lower-priority gunfire event
    // must not turn a still-live HIDE response into ENGAGE while diagnostics continue to report
    // the hit/explosion that caused it. Equal priority updates deliberately refresh the short
    // lease from the newest observation.
    [_actor,_cause,_position,_action] call WAIT_fnc_DangerReact;
    _group setVariable ["WAIT_Danger_Response",_response,true];
    _group setVariable ["WAIT_Danger_Action",[_action,_cause,_observedAt,time+_responseLifetime,_generation],true];
};
// The response that survived priority selection owns the prompt scheduler window. Using the newest
// candidate lifetime here allowed a one-second gunfire sample to shorten a still-live three-second
// HIT response even though the sample was correctly rejected above. Preserve the authoritative
// lease expiry so mixed danger cannot make the group brain fall back to its slower distance cadence.
private _effectiveResponse=_group getVariable ["WAIT_Danger_Response",[]];
private _responsiveUntil=if (count _effectiveResponse == 5
    && {(_effectiveResponse select 4) == _generation}
    && {time < (_effectiveResponse select 3)}) then {
    _effectiveResponse select 3
} else {
    time+_responseLifetime
};
// A group retains one movement/decision owner. Events only shorten its existing deadline.
private _brain=_group getVariable ["WAIT_GroupBrain",createHashMap];
if (count _brain == 0) then {
    [_group,true] call WAIT_fnc_GroupBrainStart;
    _brain=_group getVariable ["WAIT_GroupBrain",createHashMap];
};
if (count _brain > 0 && {(_brain getOrDefault ["ownerEpoch",-1]) == _epoch}
    && {time >= (_group getVariable ["WAIT_Danger_WakeAfter",0])}) then {
    _group setVariable ["WAIT_Danger_WakeAfter",time+0.5];
    _brain set ["responsiveUntil",_responsiveUntil max (_brain getOrDefault ["responsiveUntil",0])];
    _brain set ["wakeAt",time];
    _brain set ["nextAt",time];
    missionNamespace setVariable ["WAIT_AIPass_NextJobDue",time];
};
0.25

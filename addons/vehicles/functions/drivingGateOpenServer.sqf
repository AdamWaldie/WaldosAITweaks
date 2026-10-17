/*
 * Author: WaldoTheWarfighter
 * Purpose: Serialise one finite, current-owner request to open a recognised unlocked gate.
 * Locality/authority: Server only. Authenticating the vehicle/group owner is followed by live
 * route, driver, feature, gate-transform, lock and forward-geometry validation before mutation.
 * Ordinary native route intent is rechecked at admission and mutation; owned alternate STOP
 * requires its unchanged finite journal. Convoy gate requests retain their registry contract.
 * animateSource has global effect; native animation state supplies JIP, without replay commands.
 * Repeat/JIP: At most one request per gate/transform in the current vehicle route/revision,
 * with sixteen gate attempts per route. A gate-wide twelve-second opening receipt coalesces
 * simultaneous requests. No closure, timer callback, retry controller or gate ownership transfer.
 * A context-bound acknowledgement prevents repeated owner requests; delivery retries return
 * the original outcome before geometry/config work. Driver/commander identity binds queued work.
 * Initial phases are retained; already-open gates are untouched. A refused/expired request
 * grants no passage and never disables the geometry cap. Live lock changes remain authoritative.
 * Arguments: 0 payload <ARRAY, []> of named pairs: group GROUP, vehicle OBJECT, gate OBJECT,
 * route ARRAY, transform ARRAY, driver OBJECT, commander OBJECT, convoyRevision NUMBER (-1 for ordinary), expires NUMBER serverTime.
 * Return Value: BOOL - an opening was commanded or an existing opening was shared; not passability.
 * Canonical Door_N_sound_source metadata only, N=1..8, at most 64 source definitions inspected.
 * Current callers: DrivingGateRequest on the server or current headless vehicle/group owner.
 * Example: [_payload] remoteExecCall ["WAIT_fnc_DrivingGateOpenServer",2];
 */
params [["_payload",[],[[]]]];
if (!isServer || {count _payload != 9} || {_payload findIf {!(_x isEqualType []) || {count _x != 2} || {!((_x select 0) isEqualType "")}} >= 0}) exitWith {false};
private _values=createHashMapFromArray _payload;
private _group=_values getOrDefault ["group",grpNull];
private _vehicle=_values getOrDefault ["vehicle",objNull];
private _gate=_values getOrDefault ["gate",objNull];
private _requestedDriver=_values getOrDefault ["driver",objNull];
private _requestedCommander=_values getOrDefault ["commander",objNull];
private _route=_values getOrDefault ["route",[]];
private _transform=_values getOrDefault ["transform",[]];
private _revision=_values getOrDefault ["convoyRevision",-1];
private _expires=_values getOrDefault ["expires",-1];
if (!(_group isEqualType grpNull) || {!(_vehicle isEqualType objNull)} || {!(_gate isEqualType objNull)}
    || {!(_requestedDriver isEqualType objNull)} || {!(_requestedCommander isEqualType objNull)}
    || {!(_route isEqualType [])} || {!(_transform isEqualType [])} || {!(_revision isEqualType 0)}
    || {!finite _revision} || {_revision != floor _revision} || {_revision < -1}
    || {!(_expires isEqualType 0)} || {!finite _expires} || {_expires <= serverTime} || {_expires > serverTime+5}
    || {isNull _group} || {isNull _vehicle} || {isNull _gate} || {!alive _gate}) exitWith {false};
private _sender=remoteExecutedOwner;
if (_sender > 0 && {_sender != 2}
    && {_sender != groupOwner _group || {_sender != owner _vehicle} || {_sender != owner driver _vehicle}}) exitWith {false};
private _driver=driver _vehicle;
private _commander=effectiveCommander _vehicle;
if (isNull _commander) then {_commander=_driver};
if (isNull _driver || {_driver != _requestedDriver} || {_commander != _requestedCommander}
    || {!(_vehicle isKindOf "LandVehicle")} || {_vehicle isKindOf "StaticWeapon"}
    || {!alive _vehicle} || {!canMove _vehicle} || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
    || {!simulationEnabled _driver} || {isObjectHidden _driver}
    || {!simulationEnabled _commander} || {isObjectHidden _commander} || {group _driver != _group} || {group _commander != _group}
    || {isPlayer _driver} || {isPlayer _commander} || {!isNull remoteControlled _driver}
    || {!isNull remoteControlled _commander} || {!([_driver] call WAIT_fnc_CortexCombatEffective)}
    || {!([_commander] call WAIT_fnc_CortexCombatEffective)}
    || {!isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
    || {!([_group,false,false,_revision >= 0] call WAIT_fnc_CortexIsEligible)}
    || {[] call WAIT_fnc_CortexIsPaused}
    || {_route isEqualTo []} || {([_group] call WAIT_fnc_DrivingRouteReceipt) isNotEqualTo _route}
    || {_transform isNotEqualTo [getPosWorld _gate,vectorDir _gate,vectorUp _gate]}
    || {abs speed _vehicle > 8}) exitWith {false};
if ([_driver,_commander] findIf {currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]
    || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}} >= 0) exitWith {false};
if (_revision >= 0) then {
    private _registry=missionNamespace getVariable ["WAIT_Convoy_Registry",[]];
    private _index=_registry findIf {(_x select 0) == _group};
    if (_index < 0) exitWith {_revision=-2};
    private _config=(_registry select _index) select 1;
    if ((_config select 0) != _revision || {(_config select 5) != "TRAVEL"}
        || {!(_vehicle in (_config select 4))}
        || {!([_group,"WAIT_Convoy_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) then {_revision=-2};
} else {
    if (!(missionNamespace getVariable ["WAIT_AIPass_Active",false])
        || {_vehicle getVariable ["WAIT_Convoy_Active",false]}
        || {!([_group,true] call WAIT_fnc_DrivingMovementAvailable)}
        || {!([_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) then {_revision=-2};
};
if (_revision == -2 || {_revision < 0 && {!([_group,_vehicle,_route] call WAIT_fnc_DrivingGateIntent)}}) exitWith {false};
// Check the server-local attempt history before geometry/config work. A delivery retry
// receives the original outcome; it never becomes another animation or geometry scan.
private _receipt=_vehicle getVariable ["WAIT_DrivingGate_ServerAttempts",[]];
private _attempts=if (count _receipt == 4 && {(_receipt select 0) == _group} && {(_receipt select 1) isEqualTo _route} && {(_receipt select 2) == _revision}) then {+(_receipt select 3)} else {[]};
private _key=[_gate,+_transform];
private _attemptIndex=_attempts findIf {(_x select [0,2]) isEqualTo _key};
private _publishResult={
    params ["_reason","_until"];
    if (_attemptIndex >= 0) then {
        private _row=_attempts select _attemptIndex;
        _row set [2,_reason]; _row set [3,_until];
        _vehicle setVariable ["WAIT_DrivingGate_ServerAttempts",[_group,+_route,_revision,_attempts]];
    };
    private _ack=[_gate,_reason,_until,_group,+_route,_revision,+_transform];
    if ((_vehicle getVariable ["WAIT_DrivingGate_Result",[]]) isNotEqualTo _ack) then {
        _vehicle setVariable ["WAIT_DrivingGate_Result",_ack,true];
    };
};
if (_attemptIndex >= 0) exitWith {
    private _previous=_attempts select _attemptIndex;
    private _reason=_previous select 2;
    if (_reason in ["OPEN_REQUESTED","SHARED_OPENING"] && {serverTime >= (_previous select 3)}) then {_reason="OPEN_WINDOW_EXPIRED"};
    [_reason,_previous select 3] call _publishResult;
    false
};
if (count _attempts >= 16) exitWith {["ROUTE_GATE_BUDGET",serverTime] call _publishResult;false};
private _observed=[_vehicle,0,true] call WAIT_fnc_DrivingGateCap;
if ((_observed select 1) != _gate || {(_observed select 2) > 12} || {(_observed select 2) < 0}) exitWith {false};
_attemptIndex=count _attempts;
_attempts pushBack [_gate,+_transform,"VALIDATING",serverTime+5];
_vehicle setVariable ["WAIT_DrivingGate_ServerAttempts",[_group,+_route,_revision,_attempts]];
private _sources=[];
private _definitions="true" configClasses ((configOf _gate) >> "AnimationSources");
if (count _definitions <= 64) then {
    {
        private _name=configName _x;
        private _parts=(toLowerANSI _name) splitString "_";
        if (count _parts == 4) then {
            private _index=parseNumber (_parts select 1);
            if (_index >= 1 && {_index <= 8} && {_index == floor _index}
                && {toLowerANSI _name == format ["door_%1_sound_source",_index]}) then {
                _sources pushBack [_index,_name,_gate animationSourcePhase _name];
            };
        };
    } forEach _definitions;
};
private _locked={
    (_gate getVariable ["bis_disabled_Door",0]) isNotEqualTo 0
        || {_sources findIf {(_gate getVariable [format ["bis_disabled_Door_%1",_x select 0],0]) isNotEqualTo 0} >= 0}
};
private _reason=if (_sources isEqualTo []) then {"UNSUPPORTED"} else {if (call _locked) then {"LOCKED"} else {"READY"}};
if (_reason != "READY") exitWith {
    [_reason,serverTime] call _publishResult;
    false
};
private _opening=_gate getVariable ["WAIT_DrivingGate_ServerOpening",[]];
if (count _opening == 4 && {(_opening select 0) isEqualTo _transform} && {serverTime < (_opening select 2)}) exitWith {
    ["SHARED_OPENING",_opening select 2] call _publishResult;
    true
};
if (_sources findIf {(_x select 2) < 0.1} < 0) exitWith {
    ["ALREADY_OPEN_OR_MOVING",serverTime] call _publishResult;
    false
};
// Final mutation boundary: no delayed opening or stale transform survives a new order/lock.
if ((_revision < 0 && {!([_group,_vehicle,_route] call WAIT_fnc_DrivingGateIntent)
        || {!([_group,true] call WAIT_fnc_DrivingMovementAvailable)}})
    || {call _locked} || {!alive _gate} || {driver _vehicle != _driver}
    || {(effectiveCommander _vehicle) isNotEqualTo _requestedCommander && {!isNull effectiveCommander _vehicle}}
    || {group _driver != _group} || {isPlayer _driver} || {!isNull remoteControlled _driver}
    || {_sender > 0 && {_sender != 2} && {_sender != groupOwner _group || {_sender != owner _vehicle}}}
    || {_transform isNotEqualTo [getPosWorld _gate,vectorDir _gate,vectorUp _gate]}
    || {([_group] call WAIT_fnc_DrivingRouteReceipt) isNotEqualTo _route}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {
    ["REQUEST_REPLACED",serverTime] call _publishResult;
    false
};
_gate setVariable ["WAIT_DrivingGate_ServerOpening",[+_transform,+_sources,serverTime+12,_group]];
{
    if ((_x select 2) < 0.1) then {_gate animateSource [_x select 1,1]};
} forEach _sources;
["OPEN_REQUESTED",serverTime+12] call _publishResult;
true

/*
 * Author: WaldoTheWarfighter
 * Purpose: Own one finite tracked reverse leg while preserving a threat-facing hull and native turret engagement.
 * Locality/authority: Current AI group and vehicle owner only; all command boundaries yield to external ownership.
 * A vehicle-specific external driving marker blocks reverse commands and release STOP/turn writes.
 * A companion generation/seat/destination/current-route receipt binds commands and cleanup. A
 * changed receipt returns RELEASED, preventing the caller's normal forward fallback over handover.
 * Incapacitated crew cannot drive a leg; cleanup cancels only a matching recorded turn direction.
 * Fresh shared rear body-width actor/geometry observation gates each active reverse step.
 * It does not create another controller or change native collision.
 * Repeat/JIP: Generation/epoch-bound record; repeated steps retain commands. Exact unchanged
 * inherited commands may be retired by the new owner, but never replayed. Legacy records without
 * command evidence retire metadata only. No worker or JIP command replay.
 * Arguments: 0 group <GROUP>; 1 state <HASHMAP>; 2 vehicle <OBJECT>; 3 threat ATL <ARRAY>;
 * 4 mode <STRING, START>; 5 operation generation <NUMBER, -1>.
 * Return: STRING - REVERSE, COMPLETE, FALLBACK or RELEASED. Caller owns forward fallback and operation release.
 * Current callers: CortexVehicles, CortexGroupTick, CortexLocality, OperationCancel and OperationRelease.
 * Example: [group driver apc1,state,apc1,getPosATL enemy1,"START",4] call WAIT_fnc_CortexVehicleReverseStep;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],
    ["_vehicle",objNull,[objNull]],["_threat",[],[[]]],["_mode","START",[""]],["_generation",-1,[0]]];
if (isNull _group || {!local _group}) exitWith {"FALLBACK"};
private _record=_group getVariable ["WAIT_VehicleReverse",[]];
private _commandReceipt=_group getVariable ["WAIT_VehicleReverse_Command",[]];
private _commandsUnchanged={
    params ["_ownedVehicle"];
    count _commandReceipt == 6 && {(_commandReceipt select 0) == _generation}
        && {driver _ownedVehicle == (_commandReceipt select 1)}
        && {effectiveCommander _ownedVehicle == (_commandReceipt select 2)}
        && {(expectedDestination (_commandReceipt select 1)) isEqualTo (_commandReceipt select 3)}
        && {(expectedDestination (_commandReceipt select 2)) isEqualTo (_commandReceipt select 4)}
        && {([_group] call WAIT_fnc_DrivingRouteReceipt) isEqualTo (_commandReceipt select 5)}
};
private _release={
    params [["_reason","RELEASE",[""]]];
    if (count _record == 9 && {(_record select 1) == _generation}) then {
        private _ownedVehicle=_record select 0;
        // One transition snapshot explains a failed physical leg without a per-tick log stream.
        _group setVariable ["WAIT_VehicleReverseEnd",[serverTime,_reason,_generation,
            _record select 2,clientOwner,
            if (isNull _ownedVehicle) then {[]} else {getPosATL _ownedVehicle},
            if (isNull _ownedVehicle) then {-1} else {_ownedVehicle distance2D (_record select 3)},
            if (isNull _ownedVehicle) then {[]} else {vehicleMoveInfo _ownedVehicle},
            time-(_record select 6)],true];
        if (!isNull _ownedVehicle && {local _ownedVehicle}
            && {(_ownedVehicle getVariable ["WAIT_VehicleReverseOwner",[]]) isEqualTo [_group,_generation]}) then {
            // Matching markers prove the old lease, not authority over a newer external order.
            // Clear those markers on handover without sending driving commands into its owner.
            private _currentDriver=driver _ownedVehicle;
            private _currentCommander=effectiveCommander _ownedVehicle;
            private _crewStillOwned=[_currentDriver,_currentCommander] findIf {
                isNull _x || {isPlayer _x} || {!local _x} || {!isNull remoteControlled _x}
                    || {group _x != _group} || {([_x] call WAIT_fnc_CortexExternalOwner) != ""}
                    || {[_x] call WAIT_fnc_CompatibilityExternalControl}
                    || {!simulationEnabled _x} || {isObjectHidden _x}
                    || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
                    || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                    || {currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
                        "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}
            } < 0;
            if (!([_group] call WAIT_fnc_CortexExternalTakeover)
                && {_crewStillOwned} && {[_ownedVehicle] call _commandsUnchanged}
                && {isNil {_ownedVehicle getVariable "WAIT_ExternalDrivingOwner"}}) then {
                private _info=vehicleMoveInfo _ownedVehicle;
                if ((_info param [1,""]) in ["LEFT","RIGHT"]
                    && {(_info param [1,""]) == (_record select 8)}) then {_ownedVehicle sendSimpleCommand "STOPTURNING"};
                if ((_info param [0,""]) == "BACK") then {_ownedVehicle sendSimpleCommand "STOP"};
            };
            _ownedVehicle setVariable ["WAIT_VehicleReverseOwner",nil,true];
        };
        if (count _commandReceipt == 6 && {(_commandReceipt select 0) == _generation}
            && {(_group getVariable ["WAIT_VehicleReverse_Command",[]]) isEqualTo _commandReceipt}) then {
            _group setVariable ["WAIT_VehicleReverse_Command",nil,true];
        };
        if ((_group getVariable ["WAIT_VehicleReverse",[]]) isEqualTo _record) then {
            _group setVariable ["WAIT_VehicleReverse",nil,true];
        };
    };
    "RELEASED"
};
if (toUpperANSI _mode == "RELEASE") exitWith {["RELEASE"] call _release};
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
private _limits=_operation getOrDefault ["reverseLimits",[30,20,35]];
private _fallbackAuthority=(missionNamespace getVariable ["WAIT_AIPass_Active",false])
    && {[_group,"WAIT_AIPass_VehicleWithdraw_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {count _operation > 0} && {(_operation getOrDefault ["generation",-2]) == _generation}
    && {(_operation getOrDefault ["intent",""]) == "VEHICLE_WITHDRAW"}
    && {(_operation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
    && {!isNull _vehicle} && {local _vehicle} && {alive _vehicle} && {canMove _vehicle}
    && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
    && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])};
private _eligible=_fallbackAuthority && {_vehicle isKindOf "Tank"}
    && {[_group,"WAIT_AIPass_VehicleReverse_Enable",true] call WAIT_fnc_CortexFeatureEnabled};
private _driver=driver _vehicle;
private _commander=effectiveCommander _vehicle;
if (isNull _driver || {isNull _commander} || {_driver == _commander}
    || {!alive _driver} || {!alive _commander}
    || {!([_driver] call WAIT_fnc_CortexCombatEffective)}
    || {!([_commander] call WAIT_fnc_CortexCombatEffective)}
    || {!local _driver} || {!local _commander}
    || {isPlayer _driver} || {isPlayer _commander} || {group _driver != _group}
    || {group _commander != _group} || {!isNull remoteControlled _driver}
    || {!isNull remoteControlled _commander}
    || {[_driver,_commander] findIf {
        !isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])
            || {[_x] call WAIT_fnc_CortexExternalOwner != ""}
            || {!simulationEnabled _x} || {isObjectHidden _x}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
                "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}
    } >= 0}) exitWith {
    private _handover=count _record == 9 && {(_record select 1) == _generation};
    ["CREW_UNAVAILABLE"] call _release;["RELEASED","FALLBACK"] select (_fallbackAuthority && {!_handover})
};
// A matching old episode cannot acquire a replacement crew or overwrite a newer native order.
// This is handover, not failed navigation: the caller must not issue its forward fallback.
if (count _record == 9 && {(_record select 1) == _generation}
    && {(_record select 0) == _vehicle} && {!([_vehicle] call _commandsUnchanged)}) exitWith {
    ["COMMAND_OR_SEATS_CHANGED"] call _release;"RELEASED"
};
if (!_eligible) exitWith {
    ["INELIGIBLE"] call _release;["RELEASED","FALLBACK"] select _fallbackAuthority
};
// Observe only the short swept rear area of this active finite reverse leg. This is
// actor safety, not a path replacement or a global traffic scan. Keep native collisions.
private _rearDepth=(4+(abs speed _vehicle)/1.8) min 12;
private _rearClearance=[_vehicle,_rearDepth] call WAIT_fnc_DrivingRearClear;
if !(_rearClearance select 0) exitWith {
    [_rearClearance select 1] call _release; "FALLBACK"
};
if (toUpperANSI _mode == "START") exitWith {
    if (count _record == 9) exitWith {
        if ((_record select 1) == _generation && {(_record select 0) == _vehicle}) then {"REVERSE"} else {"FALLBACK"}
    };
    if (count _threat < 2 || {abs speed _vehicle > 10}) exitWith {"FALLBACK"};
    _limits=[
        (missionNamespace getVariable ["WAIT_AIPass_VehicleReverse_Distance",30]) max 10 min 60,
        (missionNamespace getVariable ["WAIT_AIPass_VehicleReverse_Timeout",20]) max 5 min 45,
        (missionNamespace getVariable ["WAIT_AIPass_VehicleReverse_FacingTolerance",35]) max 10 min 60
    ];
    private _relative=_vehicle getRelDir _threat;
    if (_relative > (_limits select 2) && {_relative < 360-(_limits select 2)}) exitWith {"FALLBACK"};
    private _origin=getPosATL _vehicle;
    private _rear=_vehicle getRelPos [(_limits select 0)+5,180];
    if (_rear distance2D _threat <= _origin distance2D _threat) exitWith {"FALLBACK"};
    private _route=[_origin,[[_rear]],_threat,[],objNull,"VEHICLE"] call WAIT_fnc_CortexSelectAvenue;
    if (_route isEqualTo [] || {lineIntersectsSurfaces [AGLToASL (_origin vectorAdd [0,0,1]),
        AGLToASL (_rear vectorAdd [0,0,1]),_vehicle,objNull,true,1,"GEOM","NONE"] isNotEqualTo []}) exitWith {"FALLBACK"};
    _operation set ["reverseLimits",+_limits];
    _group setVariable ["WAIT_Operation",_operation,true];
    _record=[_vehicle,_generation,_group getVariable ["WAIT_AIPass_Epoch",0],+_origin,+_threat,
        time+(_limits select 1),time,+_origin,"BACK"];
    _group setVariable ["WAIT_VehicleReverse",_record,true];
    _vehicle setVariable ["WAIT_VehicleReverseOwner",[_group,_generation],true];
    _vehicle sendSimpleCommand "STOPTURNING";
    _vehicle sendSimpleCommand "BACK";
    _commandReceipt=[_generation,_driver,_commander,+(expectedDestination _driver),
        +(expectedDestination _commander),[_group] call WAIT_fnc_DrivingRouteReceipt];
    _group setVariable ["WAIT_VehicleReverse_Command",_commandReceipt,true];
    "REVERSE"
};
if (count _record != 9 || {(_record select 0) != _vehicle} || {(_record select 1) != _generation}
    || {(_record select 2) != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {"FALLBACK"};
private _beforeRecord=+_record;
private _referenceThreat=+(_record select 4);
if (count _referenceThreat == 2) then {_referenceThreat pushBack 0};
private _awayAxis=(_record select 3) vectorDiff _referenceThreat;
_awayAxis set [2,0];
_awayAxis=vectorNormalized _awayAxis;
private _rearwardTravel=((getPosATL _vehicle) vectorDiff (_record select 3)) vectorDotProduct _awayAxis;
private _frontBearing=_vehicle getRelDir _referenceThreat;
if (_rearwardTravel >= (_limits select 0) && {_frontBearing <= (_limits select 2) || {_frontBearing >= 360-(_limits select 2)}}) exitWith {
    ["DISTANCE_REACHED"] call _release; "COMPLETE"
};
if (_vehicle distance2D (_record select 7) >= 2) then {_record set [6,time]; _record set [7,getPosATL _vehicle]};
if (time >= (_record select 5) || {time-(_record select 6) > 6}) exitWith {[["NO_PROGRESS","TIME_LIMIT"] select (time >= (_record select 5))] call _release; "FALLBACK"};
private _bearing=_vehicle getRelDir (_record select 4);
private _deadband=20 min ((_limits select 2)*0.6);
private _turn=if (_bearing <= _deadband || {_bearing >= 360-_deadband}) then {"STOPTURNING"} else {["LEFT","RIGHT"] select (_bearing < 180)};
if (_turn != (_record select 8)) then {
    _vehicle sendSimpleCommand _turn;
    // Native steering can cancel or lock the longitudinal command during a turn.
    // Resume reverse once when that turn is cancelled, not on every scheduler step.
    if (_turn == "STOPTURNING") then {_vehicle sendSimpleCommand "BACK"};
    _record set [8,_turn];
    // Only our guarded command write may update command receipts; route/deadline never renew.
    _commandReceipt set [3,+(expectedDestination _driver)];
    _commandReceipt set [4,+(expectedDestination _commander)];
    _group setVariable ["WAIT_VehicleReverse_Command",_commandReceipt,true];
};
if (_record isNotEqualTo _beforeRecord) then {_group setVariable ["WAIT_VehicleReverse",_record,true]};
"REVERSE"

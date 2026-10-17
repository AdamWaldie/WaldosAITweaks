/*
 * Author: WaldoTheWarfighter
 * Purpose: Restores recorded formation, attack permission, vehicle speed and unload settings;
 * retires only exact-owned follower paths before guarded native handback. A speed baseline is restored only when the
 * vehicle is leaving WAIT control, WAIT still owns the current cap and no newer controller owns it.
 * Unload policy restores from its exact lease only while its applied value remains current;
 * missing leases never authorize a guessed baseline restoration. Retained successor vehicles
 * keep their leases. Attack permission restores only while its convoy-applied value remains current.
 * A different current movement-operator group preserves the successor vehicle policy and orders.
 * Crew target cleanup also checks actor ownership and combat effectiveness; a newer target owner
 * keeps its command while obsolete convoy target metadata is retired.
 * Locality/authority: server owns registration; driving commands execute only on current owners.
 * Repeat/JIP: ordered registry snapshots replace old settings; owner-local paths rebuild on migration.
 * Public path receipts bind revision, epoch, seats and native command state; they grant no travel
 * credit. Service tasks, new native destinations and successor vehicles receive no path cancellation.
 * NEW_NATIVE_ORDER cleanup restores exact policy leases and stops only unchanged owned fixed paths;
 * replacement movement is never stopped or recalled, and route/formation restoration is suppressed.
 * A mounted crew is never recalled toward an on-foot leader. Authored waypoint metadata is retained.
 * Arguments: 0: group <GROUP>, grpNull; 1: forget baseline <BOOL>, true; 2: baseline <ARRAY>, [] reads the locally received baseline; 3: still-controlled vehicles <ARRAY>, []; 4: cancellation reason <STRING, RELEASED>.
 * Return Value: Nothing.
 * Current callers: WAIT_fnc_ConvoySync, WAIT_fnc_ConvoyTick and the convoy operation FSM.
 * Example: [convoyGroup] call WAIT_fnc_ConvoyReleaseLocal;
 */
params [["_group", grpNull, [grpNull]], ["_forget", true, [true]], ["_restore", [], [[]]], ["_keepCrew", [], [[]]], ["_reason", "RELEASED", [""]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {};
private _preserveMoves=toUpperANSI _reason == "NEW_NATIVE_ORDER";
private _navigation=_group getVariable ["WAIT_Convoy_LocalState",createHashMap];
if (_keepCrew isEqualTo [] && {local _group}) then {
    [_group,[_navigation getOrDefault ["revision",-1]],"CONVOY_RELEASED"] call WAIT_fnc_ConvoyCorridorStep;
    [_group,[_navigation getOrDefault ["revision",-1]],"CONVOY_RELEASED"] call WAIT_fnc_ConvoyBypassStep;
};
private _brain=_group getVariable ["WAIT_Convoy_Brain",createHashMap];
if (count _brain > 0 && {_forget || {toUpperANSI _reason in ["ZEUS","PLAYER","EXTERNAL","EXTERNAL_OWNER","OWNERSHIP_LOST"]}}) then {
    _brain set ["cancelled",true];
    _brain set ["cancelReason",toUpperANSI _reason];
};
if (_forget) then {
    _group setVariable ["WAIT_Convoy_Brain",nil];
    _group setVariable ["WAIT_Convoy_Brain_FSM",nil];
};
if (local _group) then {
    private _state = _group getVariable ["WAIT_Convoy_LocalState",createHashMap];
    private _generation = _state getOrDefault ["operationGeneration",-1];
    private _operation = _group getVariable ["WAIT_Operation",createHashMap];
    if (_generation >= 0 && {(_operation getOrDefault ["intent",""]) == "CONVOY"}) then {
        [_group,_generation,toUpperANSI _reason] call WAIT_fnc_OperationCancel;
    };
};
if (_restore isEqualTo []) then {_restore = _group getVariable ["WAIT_Convoy_Restore", []]};
if (_restore isNotEqualTo []) then {
    _restore params ["_formation", "_attack", "_vehicles"];
    // A feature shutdown must restore the column's own baseline. A route, curator,
    // player or specialist controller is different: it owns the replacement order and
    // the saved convoy formation, attack permission and follower paths are evidence only.
    private _externalTakeover = local _group && {[_group] call WAIT_fnc_CortexExternalTakeover};
    private _mayRestoreGroup=local _group && {!_externalTakeover};
    if (_mayRestoreGroup && {!_preserveMoves}) then {
        if (formation _group == "COLUMN") then {_group setFormation _formation};
        if (!attackEnabled _group) then {_group enableAttack _attack};
    };
    {
        _x params ["_vehicle", "_speed", "_unload"];
        if (_forget && {isServer} && {!(_vehicle in _keepCrew)} && {(_vehicle getVariable ["WAIT_Convoy_Group", grpNull]) == _group}) then {
            _vehicle setVariable ["WAIT_Convoy_Group", nil, true];
            _vehicle setVariable ["WAIT_Convoy_Active", nil, true];
        };
        {
            private _unit = _x;
            if (local _unit && {_forget} && {((_unit getVariable ["WAIT_Convoy_PassengerRevision",[]]) param [0,grpNull]) == _group}) then {
                _unit setVariable ["WAIT_Convoy_PassengerRevision",nil,true];
            };
            private _target = _unit getVariable ["WAIT_Convoy_Target", objNull];
            if (local _unit && {!isPlayer _unit} && {!isNull _target}) then {
                if ([_unit] call WAIT_fnc_CortexCombatEffective
                    && {!([group _unit,false,_unit] call WAIT_fnc_CortexExternalTakeover)}
                    && {assignedTarget _unit == _target}) then {_unit doTarget objNull};
                _unit setVariable ["WAIT_Convoy_Target", nil, true];
            };
        } forEach crew _vehicle;
        if (!(_vehicle in _keepCrew) && {local _vehicle}
            && {(_vehicle getVariable ["WAIT_Convoy_HitEHOwner",[]]) isEqualTo [_group,clientOwner]}) then {
            private _hitEH = _vehicle getVariable ["WAIT_Convoy_HitEH", -1];
            if (_hitEH >= 0) then {_vehicle removeEventHandler ["Hit", _hitEH]};
            _vehicle setVariable ["WAIT_Convoy_HitEH", nil];
            _vehicle setVariable ["WAIT_Convoy_HitEHOwner",nil];
        };
        if (local _vehicle) then {
            private _driver = driver _vehicle;
            private _externalCrew = (crew _vehicle) findIf {
                private _crewGroup = group _x;
                // The release can run after a replacement controller claimed just one crew
                // member. Do not issue a formation recall to that vehicle unless every crew
                // group remains outside the common Zeus/player/specialist handover boundary.
                [_crewGroup] call WAIT_fnc_CortexExternalTakeover
            } >= 0;
            private _movementOperator=effectiveCommander _vehicle;
            if (isNull _movementOperator) then {_movementOperator=_driver};
            private _reassignedVehicle=!isNull _movementOperator && {group _movementOperator != _group};
            private _externalVehicle=_reassignedVehicle
                || {!isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
                || {[_group] call WAIT_fnc_CompatibilityExternalControl};
            private _ownedSpeed=_vehicle getVariable ["WAIT_Convoy_OwnedSpeed",[]];
            private _ownsCurrentSpeed=count _ownedSpeed == 3
                && {(_ownedSpeed select 0) isEqualTo _group}
                && {abs ((getForcedSpeed _vehicle)-(_ownedSpeed select 2)) <= 0.1};
            if !(_vehicle in _keepCrew) then {
                if (!_externalTakeover && {!_externalCrew} && {!_externalVehicle} && {_ownsCurrentSpeed}) then {
                    _vehicle forceSpeed _speed;
                };
                if (count _ownedSpeed >= 1 && {(_ownedSpeed select 0) isEqualTo _group}) then {
                    _vehicle setVariable ["WAIT_Convoy_OwnedSpeed",nil];
                };
                private _restoreUnload=!_externalTakeover && {!_externalCrew} && {!_externalVehicle};
                [_vehicle,_group,"RELEASE",-1,_restoreUnload] call WAIT_fnc_ConvoyUnloadPolicy;
            };
            private _corridor=_vehicle getVariable ["WAIT_DrivingCorridor_Work",createHashMap];
            if (!(_vehicle in _keepCrew)
                && {((_corridor getOrDefault ["controller",[]]) param [0,""]) == "CONVOY"}) then {
                [_vehicle,_group,"CONVOY_RELEASED",!_preserveMoves,_preserveMoves] call WAIT_fnc_DrivingCorridorRelease;
            };
            private _bypass=_vehicle getVariable ["WAIT_DrivingBypass_Work",createHashMap];
            if (!(_vehicle in _keepCrew) && {((_bypass getOrDefault ["controller",[]]) param [0,""]) == "CONVOY"}) then {
                [_vehicle,_group,"CONVOY_RELEASED",!_preserveMoves,_preserveMoves,_navigation getOrDefault ["revision",-1]] call WAIT_fnc_DrivingBypassRelease;
            };
            // Retire an exact-owned steering path before native handback. Readiness is
            // insufficient: the engine can report unitReady while a fixed path still runs.
            if (!(_vehicle in _keepCrew)) then {
                [_vehicle,_group,["CONVOY"],true,_navigation getOrDefault ["revision",-1]] call WAIT_fnc_DrivingNativePathWatch;
            };
            private _movementReceipt=_vehicle getVariable ["WAIT_Convoy_MovementReceipt",[]];
            if (!(_vehicle in _keepCrew) && {count _movementReceipt == 5}
                && {(_movementReceipt select 0) == _group}
                && {(_movementReceipt select 1) == (_navigation getOrDefault ["revision",-1])}) then {
                _vehicle setVariable ["WAIT_Convoy_MovementReceipt",nil,true];
            };
            private _pathLease=_vehicle getVariable ["WAIT_Convoy_PathLease",[]];
            private _pathOwned=!isNull _driver && {!isNull _movementOperator} && {count _pathLease == 7}
                && {(_pathLease select 0) == _group}
                && {(_pathLease select 1) == (_navigation getOrDefault ["revision",-1])}
                && {(_pathLease select 2) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
                && {(_pathLease select 3) == _driver} && {(_pathLease select 4) == _movementOperator}
                && {(expectedDestination _movementOperator) isEqualTo (_pathLease select 5)};
            private _taskFree=[_driver,_movementOperator] findIf {
                isNull _x || {!local _x} || {isPlayer _x} || {!isNull remoteControlled _x}
                    || {!([_x] call WAIT_fnc_CortexCombatEffective)}
                    || {!simulationEnabled _x} || {isObjectHidden _x}
                    || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
                    || {currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}
            } < 0;
            private _mayHandBack=!_preserveMoves && {_mayRestoreGroup} && {!_externalCrew} && {!_externalVehicle}
                && {!(_vehicle in _keepCrew)} && {_taskFree}
                && {group _driver == _group} && {group _movementOperator == _group}
                && {!([_group] call WAIT_fnc_CortexExternalTakeover)};
            private _endedPath=false;
            private _mayStopOwned=_mayRestoreGroup && {!_externalCrew} && {!_externalVehicle}
                && {!(_vehicle in _keepCrew)} && {_taskFree}
                && {group _driver == _group} && {group _movementOperator == _group}
                && {!([_group] call WAIT_fnc_CortexExternalTakeover)};
            if (_mayStopOwned && {_pathOwned}) then {
                doStop _driver;
                _endedPath=true;
            };
            if (!(_vehicle in _keepCrew) && {count _pathLease == 7} && {(_pathLease select 0) == _group}
                && {(_vehicle getVariable ["WAIT_Convoy_PathLease",[]]) isEqualTo _pathLease}) then {
                _vehicle setVariable ["WAIT_Convoy_PathLease",nil,true];
            };
            // A newer native MOVE is independent of the old convoy path. Do not turn it
            // into a formation recall merely because group/vehicle ownership stayed the same.
            private _record=(_navigation getOrDefault ["followers",createHashMap]) getOrDefault [netId _vehicle,[]];
            private _committed=_record param [5,[],[[]]];
            private _live=if (isNull _movementOperator) then {[]} else {(expectedDestination _movementOperator) param [0,[]]};
            private _nativeFree=currentCommand _movementOperator != "MOVE"
                || {count _committed == 3 && {count _live == 3} && {_live vectorDistance _committed <= 0.25}};
            if (_mayRestoreGroup && {!isNull _driver} && {_mayHandBack} && {_nativeFree || {_endedPath}}) then {
                private _leader=leader _group;
                private _leaderVehicle=vehicle _leader;
                if (_driver != _leader && {_movementOperator == _driver}
                    && {_leaderVehicle != _leader} && {_leaderVehicle isKindOf "LandVehicle"}) then {
                    // An on-foot leader must not pull a released mounted crew out of its vehicle.
                    _driver doFollow leader _group;
                } else {
                    if (_endedPath) then {
                        // Wake only a plain current MOVE through its effective commander.
                        // Do not recreate waypoints, replay scripts or bypass a mission wait.
                        private _index=currentWaypoint _group;
                        if (_index > 0 && {_index < count waypoints _group}) then {
                            private _waypoint=[_group,_index];
                            private _statements=waypointStatements _waypoint;
                            private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
                            if (waypointType _waypoint == "MOVE" && {_condition == "true"}
                                && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
                                && {waypointScript _waypoint == ""} && {(waypointTimeout _waypoint param [2,0]) <= 0}
                                && {isNull waypointAttachedVehicle _waypoint} && {isNull waypointAttachedObject _waypoint}
                                && {(synchronizedTriggers _waypoint) isEqualTo []}
                                && {(synchronizedWaypoints _waypoint) isEqualTo []}
                                && {!([_group] call WAIT_fnc_CortexExternalTakeover)}) then {
                                _movementOperator doMove waypointPosition _waypoint;
                            };
                        };
                    };
                };
            };
        };
    } forEach _vehicles;
};
_group setVariable ["WAIT_Convoy_LocalState", nil];
if (_forget) then {_group setVariable ["WAIT_Convoy_Restore", nil]};

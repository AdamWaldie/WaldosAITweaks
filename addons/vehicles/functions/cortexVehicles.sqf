/*
 * Author: WaldoTheWarfighter
 * Vehicle drills for a squad in contact: dismount infantry under fire, and pull a
 * damaged vehicle back behind smoke. A targetless hit, explosion or suppression may invoke only
 * the safe-stop and passenger-exit path; target work, movement and reporting remain unavailable.
 *
 * Dismount records ownership before issuing exit commands, then cancels outstanding boarding orders.
 * Exit handlers can therefore identify the initiating controller without racing bookkeeping.
 * Crew owners publish a bounded, expiring approximate contact report for separate onboard groups.
 * A validated passenger-owner request temporarily forces the vehicle to zero speed, preserving and
 * restoring any earlier forced-speed value once that passenger squad is out or the request expires,
 * but only while the zero-speed lease remains current and no newer controller has replaced it.
 * Separate passenger groups handle only their own local cargo. Only the operating
 * crew group may order vehicle withdrawal or gunnery; convoy ownership remains excluded.
 * The operating crew also leases the engine unload-in-combat policy for an ordinary occupied
 * ground vehicle. This prevents native autonomous unloading from bypassing WAIT's passenger task,
 * safety and Zeus checks. The exact previous value is restored only while WAIT's applied value is
 * still current; convoy, external ownership and a newer policy change always win.
 * Dismount: infantry riding as cargo in a ground vehicle get out once an enemy is
 * believed within 400 m, instead of dying inside a truck. They are recorded and ordered back in when
 * the squad returns to CALM (WAIT_fnc_CortexRestoreCalm).
 * Withdraw: a vehicle that can still move but is at 50% damage or (if it carries a real weapon, not
 * just a horn or countermeasure launcher) has lost its weapons, with an enemy
 * within 800 m, fires its smoke launcher (WAIT_fnc_CortexFireCountermeasure). If the whole squad is
 * mounted, it withdraws towards one of five terrain-checked points roughly 300 m away from the enemy
 * (RETREAT phase, through an inserted waypoint). Each vehicle withdraws once per engagement.
 * Gunnery (WAIT_AIPass_VehicleGunnery_Enable): a fresh mounted danger event may orient the exact
 * affected armed platform and request one safe suppression response against an already known hostile.
 * A stopped or slow armed vehicle whose primary gunner has been lost may ask an existing dedicated
 * AI commander to change to that seat once for the exact DETECTED generation. The driver never moves.
 * An intact armed or armoured platform may also request its own smoke countermeasure once for a
 * hit, explosion or suppression generation. A slow, crew-only fighting vehicle may make one short,
 * terrain-checked jink away from a close hostile or severe impact. A stopped tracked fighting vehicle
 * may instead make one generation-owned chassis turn toward a real known hostile. Convoy, passengers
 * and any existing movement owner remain authoritative.
 * During sustained contact the AI gunner is pointed at the most dangerous
 * enemy seen in the last 15 s within 600 m: anti-tank infantry first, then armour, then anything
 * else, nearest first, held for 8 s. A fully mounted tank or APC that knows of an anti-tank soldier
 * within 60% of WAIT_AIPass_Vehicles_StandoffDistance backs off to that distance, at most once a
 * minute, through an inserted waypoint.
 * A withdrawal or standoff owns group movement until its tagged waypoint completes or its bounded
 * lease expires. Other Cortex manoeuvres may continue their combat layers but cannot replace that
 * movement. Conversely, this layer preserves and yields to every active non-vehicle movement lease
 * while continuing composable gunnery, reporting and passenger handling. A withdrawal outranks
 * standoff inside the same evaluation.
 * Vehicles owned by other WAIT features never reach this function (WAIT_fnc_CortexIsEligible).
 * Locality and authority: call where the group is local.
 *
 * Repeat/JIP: current feature gates and eligibility are rechecked. A vehicle withdrawal publishes
 * its origin, target, deadline and progress so the new group owner resumes it after migration;
 * countermeasures are not fired again. Standoff is finite and may be reassessed after adoption.
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP>
 * 2: enemies <ARRAY> - from WAIT_fnc_CortexKnowledge
 *
 * Return Value:
 * Boolean - true while vehicle withdrawal, standoff, danger jink or tracked orientation owns group movement
 *
 * Example:
 * [_group, _state, _enemies] call WAIT_fnc_CortexVehicles;
 * Result: a squad caught in its truck bails out and fights on foot.
 *
 * Current caller: WAIT_fnc_CortexGroupTick.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_enemies", [], [[]]]];
private _vehicleMove = _state getOrDefault ["movementLease",[]];
private _activeVehicleMove = false;
if (_vehicleMove isNotEqualTo []) then {
    private _vehicleOwnsLease = (_vehicleMove param [0,""]) in ["VEHICLE_WITHDRAW","VEHICLE_STANDOFF","VEHICLE_JINK","VEHICLE_ORIENT"];
    if (_vehicleOwnsLease) then {
        private _movementOwner=_vehicleMove param [0,""];
        if (_movementOwner == "VEHICLE_ORIENT") then {
            private _orientState=_state getOrDefault ["vehicleDangerOrient",[]];
            private _orientVehicle=_orientState param [1,objNull,[objNull]];
            private _marker=if (!isNull _orientVehicle) then {
                _orientVehicle getVariable ["WAIT_Danger_VehicleOrient",[]]
            } else {[]};
            private _targetPosition=_marker param [2,[],[[]]];
            _activeVehicleMove=count _marker == 5
                && {_marker param [1,grpNull,[grpNull]] == _group}
                && {serverTime < (_marker param [3,0,[0]])}
                && {count _targetPosition >= 2}
                && {!isNull _orientVehicle} && {alive _orientVehicle} && {canMove _orientVehicle}
                && {private _relative=_orientVehicle getRelDir _targetPosition; _relative > 20 && {_relative < 340}}
                && {!([_group] call WAIT_fnc_CortexExternalTakeover)};
        } else {
            _activeVehicleMove = ((waypoints _group) findIf {
                (_x select 1) >= currentWaypoint _group && {waypointDescription _x == "WAIT AI PASS"}
            } >= 0) && {time < (_vehicleMove select 1)};
        };
        if (!_activeVehicleMove) then {
            private _finishedOwner=_vehicleMove param [0,""];
            private _generation=_state getOrDefault ["vehicleOperationGeneration",-1];
            if (_generation >= 0) then {
                if (_finishedOwner == "VEHICLE_ORIENT") then {
                    private _orientState=_state getOrDefault ["vehicleDangerOrient",[]];
                    private _orientVehicle=_orientState param [1,objNull,[objNull]];
                    private _orientMarker=if (!isNull _orientVehicle) then {
                        _orientVehicle getVariable ["WAIT_Danger_VehicleOrient",[]]
                    } else {[]};
                    private _targetPosition=_orientMarker param [2,[],[[]]];
                    private _aligned=!isNull _orientVehicle && {count _targetPosition >= 2}
                        && {private _relative=_orientVehicle getRelDir _targetPosition;
                            _relative <= 20 || {_relative >= 340}};
                    if ([_group] call WAIT_fnc_CortexExternalTakeover) then {
                        [_group,_generation,"EXTERNAL_OWNER"] call WAIT_fnc_OperationCancel;
                    } else {
                        [_group,_generation,["INCOMPLETE","COMPLETE"] select _aligned,
                            ["VEHICLE_ORIENT_TIMEOUT","VEHICLE_ORIENT_ALIGNED"] select _aligned]
                            call WAIT_fnc_OperationRelease;
                    };
                } else {
                    private _intent=_group getVariable ["WAIT_Cortex_GroupMoveIntent",createHashMap];
                    private _position=_intent getOrDefault ["position",[]];
                    private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;
                    private _arrived=count _position >= 2 && {!isNull _anchor}
                        && {vehicle _anchor distance2D _position <= (_intent getOrDefault ["radius",25])};
                    [_group,_generation,["INCOMPLETE","COMPLETE"] select _arrived,
                        ["VEHICLE_MOVE_NO_ARRIVAL","OBJECTIVE_REACHED"] select _arrived] call WAIT_fnc_OperationRelease;
                };
                _state deleteAt "vehicleOperationGeneration";
            };
            if (_finishedOwner == "VEHICLE_JINK") then {
                private _jinkState=_state getOrDefault ["vehicleDangerJink",[]];
                private _jinkVehicle=_jinkState param [1,objNull,[objNull]];
                if (!isNull _jinkVehicle && {local _jinkVehicle}) then {
                    private _marker=_jinkVehicle getVariable ["WAIT_Danger_VehicleJink",[]];
                    if (_marker param [1,grpNull,[grpNull]] == _group) then {
                        _jinkVehicle setVariable ["WAIT_Danger_VehicleJink",nil,true];
                    };
                };
            };
            if (_finishedOwner == "VEHICLE_ORIENT") then {
                private _orientState=_state getOrDefault ["vehicleDangerOrient",[]];
                private _orientVehicle=_orientState param [1,objNull,[objNull]];
                if (!isNull _orientVehicle && {local _orientVehicle}) then {
                    private _marker=_orientVehicle getVariable ["WAIT_Danger_VehicleOrient",[]];
                    if (_marker param [1,grpNull,[grpNull]] == _group) then {
                        if !([_group] call WAIT_fnc_CortexExternalTakeover) then {
                            _orientVehicle sendSimpleCommand "STOPTURNING";
                        };
                        _orientVehicle setVariable ["WAIT_Danger_VehicleOrient",nil,true];
                    };
                };
                _state deleteAt "vehicleDangerOrient";
            };
            [_group,_finishedOwner,false] call WAIT_fnc_CortexOwnershipLease;
            _state deleteAt "movementLease";
        };
    } else {
        // The group tick has already validated direct tactical/support owners.
        // Yield to them without requiring a waypoint or deleting their lease.
        _activeVehicleMove = count _vehicleMove == 2 && {time < (_vehicleMove select 1)};
    };
};
// Movement ownership blocks only another destination. Reporting, dismount handling and
// gunnery remain composable for the duration of the physical move.
private _movementOwned = _activeVehicleMove;
private _vehicles = [];
{
    private _vehicle = vehicle _x;
    if (_vehicle != _x && {alive _x} && {!(_vehicle in _vehicles)} ) then {_vehicles pushBack _vehicle};
} forEach units _group;
private _externalTakeover=[_group] call WAIT_fnc_CortexExternalTakeover;
private _unloadPolicyVehicles=[];
if (!_externalTakeover
    && {[_group,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {[_group,"WAIT_AIPass_VehicleDismount_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) then {
    _unloadPolicyVehicles=_vehicles select {
        private _vehicle=_x;
        local _vehicle && {_vehicle isKindOf "LandVehicle"} && {!(_vehicle isKindOf "StaticWeapon")}
            && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
            && {effectiveCommander _vehicle in units _group}
            && {(fullCrew [_vehicle,"",false]) findIf {
                private _unit=_x select 0;
                private _role=_x select 1;
                alive _unit && {!isPlayer _unit}
                    && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
            } >= 0}
    };
};
// Reconcile the public tracked set before any early return. This also releases a vehicle whose
// commander dismounted, whose passengers left, which entered convoy control, or whose feature gate
// closed. External takeover clears proof without restoring a value into the new owner's task.
{
    if (local _x && {!(_x in _unloadPolicyVehicles)}) then {
        [_x,_group,"RELEASE",!_externalTakeover] call WAIT_fnc_CortexVehicleUnloadPolicy;
    };
} forEach +(_group getVariable ["WAIT_Cortex_UnloadPolicyVehicles",[]]);
{
    [_x,_group,"ACQUIRE"] call WAIT_fnc_CortexVehicleUnloadPolicy;
} forEach _unloadPolicyVehicles;
if (_vehicles isEqualTo []) exitWith {_movementOwned};
// Vehicle contact work can select an escape route or rank targets before it reaches the local
// crew command. A newer curator, player or specialist owner must win at that point rather than
// being followed by a stale forced speed, dismount, withdrawal or gunner request.
private _mayIssueVehicle = {
    !([_group] call WAIT_fnc_CortexExternalTakeover)
};
if (_externalTakeover) exitWith {_movementOwned};
if !([] call _mayIssueVehicle) exitWith {_movementOwned};
// Shared dismount path for identified contact and a bounded targetless danger lease. It owns only
// the stop request and local passenger exit. It never creates target knowledge or vehicle movement.
private _dismountAtThreat = {
    params ["_vehicle","_threatPosition",["_publishDanger",false,[true]]];
    if !(_vehicle isKindOf "LandVehicle" && {!(_vehicle isKindOf "StaticWeapon")}
        && {_vehicle distance2D _threatPosition < 400}
        && {[_group,"WAIT_AIPass_VehicleDismount_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) exitWith {};
    private _commandsVehicle=effectiveCommander _vehicle in units _group;
    if (_publishDanger && {_commandsVehicle} && {local _vehicle}
        && {(fullCrew [_vehicle,"",false]) findIf {
            private _unit=_x select 0;
            private _role=_x select 1;
            alive _unit && {group _unit != _group} && {side group _unit == side _group}
                && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
        } >= 0}) then {
        // The crew cannot command another group out. Publish only bounded hazard geometry so the
        // passenger owner can run the same safety checks without receiving target knowledge.
        _vehicle setVariable ["WAIT_Cortex_OnboardDanger",[_group,groupOwner _group,+_threatPosition,serverTime+30],true];
    };
    // A combined crew/passenger group has no cross-group report consumer. The same bounded
    // handshake safely stops it. A separate passenger group publishes the request for the crew
    // owner's next tick and handles only its locally owned passengers.
    private _onboardCargo=(fullCrew [_vehicle,"",false]) select {
        private _unit=_x select 0;
        private _role=_x select 1;
        alive _unit && {group _unit == _group}
            && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
    };
    if (_onboardCargo isNotEqualTo []) then {
        _vehicle setVariable ["WAIT_Cortex_DismountStopRequest",[_group,groupOwner _group,serverTime+30],true];
        if (_commandsVehicle && {local _vehicle}) then {
            if ((_vehicle getVariable ["WAIT_Cortex_DismountForcedSpeed",[]]) isEqualTo []) then {
                _vehicle setVariable ["WAIT_Cortex_DismountForcedSpeed",[getForcedSpeed _vehicle,0]];
            };
            if ([] call _mayIssueVehicle) then {_vehicle forceSpeed 0};
        };
    };
    private _cargo=(crew _vehicle) select {
        group _x == _group && {[_x,_vehicle] call WAIT_fnc_CortexPassengerReady}
    };
    if (_cargo isNotEqualTo []) then {
        private _dismounted=_state getOrDefault ["dismounted",[]];
        {
            private _unit=_x;
            // Publish ownership before GetOut handlers can observe the command.
            if (_dismounted findIf {(_x select 0) == _unit} < 0) then {
                _dismounted pushBack [_unit,_vehicle];
            };
            _state set ["dismounted", _dismounted];
            if ([] call _mayIssueVehicle && {toUpperANSI (currentCommand _unit) != "GET OUT"}) then {
                [_unit] orderGetIn false;
                unassignVehicle _unit;
                doGetOut _unit;
            };
        } forEach _cargo;
        _state set ["dismounted", _dismounted];
    };
};
// Cross-group safe-stop handshake. The passenger owner publishes only an expiring identity request;
// the vehicle authority validates current occupants and changes speed locally. This avoids remote
// driver commands, unsafe moving exits and permanent stops after an interrupted/expired handover.
{
    private _vehicle=_x;
    private _request=_vehicle getVariable ["WAIT_Cortex_DismountStopRequest",[]];
    private _saved=_vehicle getVariable ["WAIT_Cortex_DismountForcedSpeed",[]];
    private _valid=false;
    if (count _request == 3 && {local _vehicle} && {effectiveCommander _vehicle in units _group}) then {
        _request params ["_passengerGroup","_passengerOwner","_requestExpiry"];
        _valid=_passengerGroup isEqualType grpNull && {!isNull _passengerGroup}
            && {_passengerOwner isEqualType 0} && {_requestExpiry isEqualType 0}
            && {groupOwner _passengerGroup == _passengerOwner}
            && {side _passengerGroup == side _group}
            && {serverTime < _requestExpiry} && {_requestExpiry <= serverTime+30}
            && {(fullCrew [_vehicle,"",false]) findIf {
                private _unit=_x select 0;
                private _role=_x select 1;
                alive _unit && {group _unit == _passengerGroup}
                    && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
            } >= 0};
    };
    if (_valid) then {
        if (_saved isEqualTo []) then {
            _saved=[getForcedSpeed _vehicle,0];
            _vehicle setVariable ["WAIT_Cortex_DismountForcedSpeed",_saved];
        };
        if ([] call _mayIssueVehicle) then {_vehicle forceSpeed 0};
    } else {
        private _ownedStop=_saved param [1,-2];
        if (_saved isNotEqualTo [] && {local _vehicle} && {[] call _mayIssueVehicle}
            && {_ownedStop >= 0} && {abs ((getForcedSpeed _vehicle)-_ownedStop) <= 0.1}) then {
            _vehicle forceSpeed (_saved param [0,-1]);
        };
        _vehicle setVariable ["WAIT_Cortex_DismountForcedSpeed",nil];
        if (_request isNotEqualTo []) then {_vehicle setVariable ["WAIT_Cortex_DismountStopRequest",nil,true]};
    };
} forEach _vehicles;
private _dangerDismount=_state getOrDefault ["dangerDismount",[]];
if (_dangerDismount isNotEqualTo []) then {
    if (count _dangerDismount == 7) then {
        _dangerDismount params ["_dangerPosition","_dangerExpiry","_dangerProfile","_dangerCause",
            "_dangerVehicle","_dangerSource","_dangerGeneration"];
        // The current danger producer always carries the exact occupied platform. Never recover a
        // stale or malformed record by widening it to every vehicle in the group: one engine event
        // must not stop, unload, abandon or turn unrelated platforms in a mixed vehicle element.
        if (time < _dangerExpiry && {!isNull _dangerVehicle} && {_dangerVehicle in _vehicles}) then {
            private _affectedVehicles=[_dangerVehicle];
            private _dangerHostile=!isNull _dangerSource && {alive _dangerSource}
                && {(side _group) getFriend (side _dangerSource) < 0.6}
                && {(units _group) findIf {_x knowsAbout _dangerSource > 0} >= 0};
            // Targetless damage and incoming rounds justify passenger safety. Other vehicle danger
            // causes may unload only when they retain a real hostile already known by this group.
            // Merely classifying a mounted callback never fabricates a contact or empties a carrier.
            if (_dangerProfile in ["TRANSPORT","ARMED","ARMOURED"]
                && {_dangerCause in ["HIT","EXPLOSION","SUPPRESSED","GUNFIRE"] || {_dangerHostile}}) then {
                {[_x,_dangerPosition,true] call _dismountAtThreat} forEach _affectedVehicles;
            };
            {
                private _vehicle=_x;
                private _knownCloseThreat=_dangerHostile
                    && {_vehicle distance2D _dangerSource < 25};
                private _emplacementUnsafe=_dangerProfile in ["STATIC","ARTILLERY"]
                    && {!someAmmo _vehicle || {_knownCloseThreat}}
                    && {!(_vehicle isKindOf "Tank" && {count (allTurrets [_vehicle,false]) > 1})};
                private _disabledUnsafe=!(_vehicle isKindOf "StaticWeapon")
                    && {_dangerCause in ["HIT","EXPLOSION"]}
                    && {!canMove _vehicle || {damage _vehicle >= 0.85}};
                if ((_emplacementUnsafe || {_disabledUnsafe}) && {local _vehicle} && {[] call _mayIssueVehicle}) then {
                    // Abandon only the exact locally owned platform which generated the response. This
                    // is a terminal crew-safety action, not the ordinary passenger contact dismount:
                    // a mobile useful gun retains its route and crew, while an empty emplacement, a
                    // close overrun or a disabled wreck releases its own living AI occupants.
                    {
                        if (alive _x && {local _x} && {!isPlayer _x} && {group _x == _group}) then {
                            [_x] orderGetIn false;
                            unassignVehicle _x;
                            doGetOut _x;
                        };
                    } forEach crew _vehicle;
                    _vehicle setVariable ["WAIT_Danger_AbandonReason",
                        [["DISABLED","EMPLACEMENT"] select _emplacementUnsafe,_dangerCause,serverTime],true];
                };
                // An intact armed platform should not sit inert while its effective commander already
                // knows the hostile which caused this exact native danger response. Orient and request
                // one bounded suppression action, but retain the current route, speed and waypoint.
                // The generation record prevents the shared scheduler from repeating the command every
                // contact tick; ordinary native/WAIT gunnery owns subsequent target decisions.
                private _reaction=_state getOrDefault ["vehicleDangerReaction",[]];
                private _gunner=gunner _vehicle;
                private _crewRecovery=_state getOrDefault ["vehicleDangerCrewRecovery",[]];
                private _freshCrewRecovery=_dangerGeneration >= 0
                    && {_crewRecovery param [0,-2,[0]] != _dangerGeneration};
                if (_freshCrewRecovery && {_dangerHostile}
                    && {_dangerProfile in ["ARMED","ARMOURED"]}
                    && {!(_emplacementUnsafe || {_disabledUnsafe})}) then {
                    private _crewRecoveryIssued=[_group,_vehicle,_dangerSource,_dangerCause,_dangerGeneration]
                        call WAIT_fnc_CortexVehicleCrewRecover;
                    // Record both acceptance and refusal for this generation. An impossible seat
                    // change must not be reconsidered every scheduler tick during the same danger.
                    _state set ["vehicleDangerCrewRecovery",
                        [_dangerGeneration,_vehicle,_crewRecoveryIssued,serverTime]];
                    if (_crewRecoveryIssued) then {_gunner=gunner _vehicle};
                };
                private _knownHostile=_dangerHostile
                    && {!isNull _gunner} && {alive _gunner} && {local _gunner} && {!isPlayer _gunner}
                    && {(effectiveCommander _vehicle) in units _group}
                    && {(effectiveCommander _vehicle) knowsAbout _dangerSource > 0}
                    && {_dangerProfile in ["STATIC","ARMED","ARMOURED"]};
                private _freshGeneration=_dangerGeneration >= 0
                    && {_reaction param [0,-2,[0]] != _dangerGeneration};
                // Defensive smoke is independent from the gunner response: consuming one must not
                // suppress the other. Record the generation even when no compatible loaded launcher
                // exists, so a two-second danger lease cannot repeat the same inventory/config scan.
                // BLUE/GREEN, convoy, player, Zeus and specialist ownership remain authoritative.
                private _countermeasureReaction=_state getOrDefault ["vehicleDangerCountermeasure",[]];
                private _freshCountermeasureGeneration=_dangerGeneration >= 0
                    && {_countermeasureReaction param [0,-2,[0]] != _dangerGeneration};
                if (_freshCountermeasureGeneration
                    && {_dangerProfile in ["ARMED","ARMOURED"]}
                    && {_dangerCause in ["HIT","EXPLOSION","SUPPRESSED"]}
                    && {!(_emplacementUnsafe || {_disabledUnsafe})}
                    && {combatMode _group in ["YELLOW","RED"]}
                    && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
                    && {[] call _mayIssueVehicle}) then {
                    private _countermeasureFired=[_vehicle] call WAIT_fnc_CortexFireCountermeasure;
                    _state set ["vehicleDangerCountermeasure",[_dangerGeneration,_vehicle,_countermeasureFired,serverTime]];
                    _vehicle setVariable ["WAIT_Danger_VehicleCountermeasure",
                        [_dangerGeneration,effectiveCommander _vehicle,_dangerSource,serverTime,_countermeasureFired],true];
                };
                // A close hostile or severe incoming danger may justify one short escape by an
                // otherwise intact fighting vehicle. The helper owns one 25-second operation and
                // refuses convoys, passengers, foot elements and any existing movement owner.
                private _jink=_state getOrDefault ["vehicleDangerJink",[]];
                private _freshJinkGeneration=_dangerGeneration >= 0
                    && {_jink param [0,-2,[0]] != _dangerGeneration};
                if (_freshJinkGeneration && {_dangerProfile in ["ARMED","ARMOURED"]}
                    && {_dangerCause in ["HIT","EXPLOSION"] || {_knownCloseThreat}}
                    && {!(_emplacementUnsafe || {_disabledUnsafe})}) then {
                    private _jinkStarted=[_group,_state,_vehicle,_dangerPosition,_dangerSource,_dangerGeneration]
                        call WAIT_fnc_CortexVehicleJink;
                    _state set ["vehicleDangerJink",[_dangerGeneration,_vehicle,_jinkStarted,serverTime]];
                    if (_jinkStarted) then {_movementOwned=true};
                };
                // A stopped tracked fighting vehicle can turn its hull toward the exact known
                // hostile without receiving a destination. This runs after the more urgent escape
                // decision: a jink or any other movement owner refuses the orientation operation.
                private _orient=_state getOrDefault ["vehicleDangerOrient",[]];
                private _freshOrientGeneration=_dangerGeneration >= 0
                    && {_orient param [0,-2,[0]] != _dangerGeneration};
                if (_freshOrientGeneration && {_knownHostile} && {_dangerProfile == "ARMOURED"}
                    && {!(_emplacementUnsafe || {_disabledUnsafe})}
                    && {_dangerCause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE","SUPPRESSED"]}) then {
                    private _orientStarted=[_group,_state,_vehicle,_dangerPosition,_dangerSource,_dangerGeneration]
                        call WAIT_fnc_CortexVehicleOrient;
                    _state set ["vehicleDangerOrient",[_dangerGeneration,_vehicle,_orientStarted,serverTime]];
                    if (_orientStarted) then {_movementOwned=true};
                };
                // A useful static mortar answers the same real, known hostile through the finite
                // artillery mission owner. The server revalidates locality, knowledge, allegiance,
                // ammunition, range and friendly safety; this call never fires a shell directly.
                // Recording the generation before dispatch prevents one danger event from queuing
                // repeatedly while the server accepts or rejects the request.
                if (_dangerProfile == "ARTILLERY" && {_dangerHostile} && {_freshGeneration}
                    && {_vehicle isKindOf "StaticMortar"} && {!(_emplacementUnsafe || {_disabledUnsafe})}
                    && {[_group,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
                    && {combatMode _group in ["YELLOW","RED"]}
                    && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
                    && {[] call _mayIssueVehicle}) then {
                    _state set ["vehicleDangerReaction",[_dangerGeneration,_vehicle,_dangerSource,serverTime]];
                    _vehicle setVariable ["WAIT_Danger_VehicleReaction",[_dangerGeneration,_gunner,_dangerSource,serverTime],true];
                    [_vehicle,+_dangerPosition,25,"HE",1,false,"DANGER",objNull,_dangerSource] call WAIT_fnc_CortexArtilleryFire;
                };
                if (_knownHostile && {_freshGeneration} && {!(_emplacementUnsafe || {_disabledUnsafe})}
                    && {[_group,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
                    && {combatMode _group in ["YELLOW","RED"]}
                    && {unitCombatMode _gunner in ["YELLOW","RED"]}
                    && {!(_vehicle getVariable ["WAIT_Convoy_Active",false])}
                    && {[] call _mayIssueVehicle}) then {
                    private _aimPosition=aimPos _dangerSource;
                    if ([_gunner,_aimPosition] call WAIT_fnc_CortexLineOfFireClear) then {
                        _gunner doWatch _dangerSource;
                        _gunner doSuppressiveFire _aimPosition;
                        _state set ["vehicleDangerReaction",[_dangerGeneration,_vehicle,_dangerSource,serverTime]];
                        _vehicle setVariable ["WAIT_Danger_VehicleReaction",[_dangerGeneration,_gunner,_dangerSource,serverTime],true];
                    };
                };
            } forEach _affectedVehicles;
        } else {
            _state deleteAt "dangerDismount";
        };
    } else {
        _state deleteAt "dangerDismount";
    };
};
if (_enemies isEqualTo []) exitWith {_movementOwned};
private _enemyPos = (_enemies select 0) select 1;
private _selectVehicleEscape = {
    params ["_vehicle","_threatPosition","_threatObject","_distance"];
    private _origin=getPosATL _vehicle;
    private _awayBearing=_threatPosition getDir _origin;
    private _candidates=[];
    {
        _candidates pushBack [_origin getPos [_distance,_awayBearing+_x]];
    } forEach [0,-25,25,-45,45];
    private _selected=[_origin,_candidates,_threatPosition,[],_threatObject,"VEHICLE"]
        call WAIT_fnc_CortexSelectAvenue;
    if (_selected isEqualTo []) then {[]} else {_selected select ((count _selected)-1)}
};
private _withdrawn = _state getOrDefault ["withdrawn", []];
{
    private _vehicle = _x;
    private _distance = _vehicle distance2D _enemyPos;
    private _commandsVehicle = effectiveCommander _vehicle in units _group;
    // Onboard reports carry no target object or reveal. Only the actual vehicle authority
    // publishes, at most once per five seconds and only when another squad is aboard.
    if (_commandsVehicle && {local _vehicle} && {_vehicle isKindOf "LandVehicle"}
        && {(_enemies select 0) select 2 <= 10}
        && {serverTime >= (_vehicle getVariable ["WAIT_Cortex_OnboardReportDue",-1])}
        && {(crew _vehicle) findIf {alive _x && {group _x != _group} && {side group _x == side _group}} >= 0}) then {
        private _reportedPosition=[25*round ((_enemyPos select 0)/25),25*round ((_enemyPos select 1)/25),0];
        // The far scheduler tier is 20 seconds. A shorter report could expire between the
        // independently scheduled crew and passenger jobs and make a valid handover impossible.
        _vehicle setVariable ["WAIT_Cortex_OnboardReport",[_group,groupOwner _group,_reportedPosition,serverTime+35],true];
        _vehicle setVariable ["WAIT_Cortex_OnboardReportDue",serverTime+5];
    };
    [_vehicle,_enemyPos,false] call _dismountAtThreat;
    // Horns and countermeasure launchers are CfgWeapons entries too; only a real weapon makes a
    // vehicle "armed", so an unarmed truck is never treated as having lost its guns. Read live (and
    // only once canFire already says no), because Vehicle Weapon Loadout can change a vehicle's guns.
    private _hasRealWeapon = {
        ([[-1]] + allTurrets [_vehicle, true]) findIf {
            (_vehicle weaponsTurret _x) findIf {
                private _weaponConfig = configFile >> "CfgWeapons" >> _x;
                toLowerANSI (getText (_weaponConfig >> "displayName")) != "horn"
                && {getText (_weaponConfig >> "simulation") != "cmlauncher"}
            } >= 0
        } >= 0
    };
    if (_commandsVehicle && {_vehicle isKindOf "LandVehicle"} && {[_group, "WAIT_AIPass_VehicleWithdraw_Enable", true] call WAIT_fnc_CortexFeatureEnabled} && {local _vehicle} && {alive _vehicle} && {canMove _vehicle} && {!(_vehicle in _withdrawn)} && {_distance < 800}
        && {damage _vehicle >= 0.5 || {!canFire _vehicle && {call _hasRealWeapon}}}) then {
        _withdrawn pushBack _vehicle;
        _state set ["withdrawn", _withdrawn];
        [_vehicle] call WAIT_fnc_CortexFireCountermeasure;
        if ((units _group) findIf {alive _x && {vehicle _x == _x}} < 0) then {
            private _threat=(_enemies select 0) select 0;
            private _away=[_vehicle,_enemyPos,_threat,300] call _selectVehicleEscape;
            if (_away isNotEqualTo [] && {[] call _mayIssueVehicle} && {[_group,"VEHICLE_WITHDRAW",true,serverTime+120] call WAIT_fnc_CortexOwnershipLease}) then {
                private _operation=[_group,"VEHICLE_WITHDRAW",_threat,[],[_away],"MOVING"] call WAIT_fnc_OperationStart;
                if (count _operation == 0) then {
                    [_group,"VEHICLE_WITHDRAW",false] call WAIT_fnc_CortexOwnershipLease;
                } else {
                    private _reverse=[_group,_state,_vehicle,_enemyPos,"START",_operation get "generation"] call WAIT_fnc_CortexVehicleReverseStep;
                    if (_reverse != "REVERSE") then {[_group, _away, 40] call WAIT_fnc_CortexGroupMove};
                    _state set ["movementLease",["VEHICLE_WITHDRAW",time+120]];
                    _state set ["vehicleOperationGeneration",_operation get "generation"];
                    private _origin = getPosATL _vehicle;
                    _state set ["retreatStart",_origin];
                    _state set ["retreatTarget",_away];
                    _state set ["retreatProgress",[time,0,0]];
                    _group setVariable ["WAIT_Cortex_Withdrawal",["MOVING",0,0],true];
                    _group setVariable ["WAIT_Cortex_WithdrawalIntent",["VEHICLE",_origin,_away,_enemyPos,serverTime,0,0],true];
                    _movementOwned = true;
                    [_group,_state,"RETREAT","VEHICLE_DISABLED",time] call WAIT_fnc_CortexSetPhase;
                };
            };
        };
    };
    // Gunner priorities and standoff (WAIT_AIPass_VehicleGunnery_Enable): anti-tank infantry
    // first, then armour, then everything else; armour keeps its distance from known AT teams.
    if (_commandsVehicle && {alive _vehicle} && {[_group, "WAIT_AIPass_VehicleGunnery_Enable", true] call WAIT_fnc_CortexFeatureEnabled}) then {
        private _gunner = gunner _vehicle;
        private _ranked = [];
        {
            _x params ["_enemy", "_position", "_age"];
            private _distance = _vehicle distance2D _position;
            if (_age <= 15 && {_distance <= 600} && {alive _enemy}) then {
                private _priority = switch (true) do {
                    case (_enemy isKindOf "CAManBase" && {"AT" in ([_enemy] call WAIT_fnc_CortexCapabilities)}): {0};
                    case (_enemy isKindOf "Tank" || {_enemy isKindOf "Wheeled_APC_F"}): {1};
                    default {2};
                };
                _ranked pushBack [_priority, _distance, _forEachIndex];
            };
        } forEach _enemies;
        _ranked sort true;
        if (_ranked isNotEqualTo [] && {alive _gunner} && {local _gunner} && {!isPlayer _gunner}
            && {combatMode _group in ["YELLOW", "RED"]} && {unitCombatMode _gunner in ["YELLOW", "RED"]}
            && {(_gunner getVariable ["WAIT_AIPass_TargetHold", -1]) < time}) then {
            private _target = (_enemies select ((_ranked select 0) select 2)) select 0;
            if ([] call _mayIssueVehicle && {assignedTarget _gunner != _target}) then {
                _gunner doTarget _target;
            };
            // Target sharing may have assigned this contact before the vehicle layer runs. Fire refresh
            // therefore follows its own bounded hold instead of depending on a target identity change.
            if ([] call _mayIssueVehicle) then {
                _gunner doFire _target;
                _gunner setVariable ["WAIT_AIPass_TargetHold", time + 8];
                _gunner setVariable ["WAIT_AIPass_VehicleTarget", _target, true];
            };
        };
        private _standoff = missionNamespace getVariable ["WAIT_AIPass_Vehicles_StandoffDistance", 250];
        private _atIndex = _enemies findIf {
            (_x select 0) isKindOf "CAManBase" && {(_x select 2) <= 30} && {(_vehicle distance2D (_x select 1)) < _standoff * 0.6}
            && {"AT" in ([_x select 0] call WAIT_fnc_CortexCapabilities)}
        };
        if (!_movementOwned && {_state getOrDefault ["phase",""] == "CONTACT"} && {_atIndex >= 0}
            && {_vehicle isKindOf "Tank" || {_vehicle isKindOf "Wheeled_APC_F"}} && {canMove _vehicle}
            && {(units _group) findIf {alive _x && {vehicle _x == _x}} < 0} && {!([_state, "standoff"] call WAIT_fnc_CortexCooldown)}) then {
            private _atPos = (_enemies select _atIndex) select 1;
            private _atThreat=(_enemies select _atIndex) select 0;
            private _away=[_vehicle,_atPos,_atThreat,(_standoff - (_vehicle distance2D _atPos)) max 60]
                call _selectVehicleEscape;
            if (_away isNotEqualTo [] && {[] call _mayIssueVehicle} && {[_group,"VEHICLE_STANDOFF",true,serverTime+60] call WAIT_fnc_CortexOwnershipLease}) then {
                private _operation=[_group,"VEHICLE_STANDOFF",_atThreat,[],[_away],"MOVING"] call WAIT_fnc_OperationStart;
                if (count _operation == 0) then {
                    [_group,"VEHICLE_STANDOFF",false] call WAIT_fnc_CortexOwnershipLease;
                } else {
                    [_group, _away, 30] call WAIT_fnc_CortexGroupMove;
                    _state set ["movementLease",["VEHICLE_STANDOFF",time+60]];
                    _state set ["vehicleOperationGeneration",_operation get "generation"];
                    _movementOwned = true;
                    [_state, "standoff", 60] call WAIT_fnc_CortexCooldown;
                };
            };
        };
    };
} forEach _vehicles;
_movementOwned

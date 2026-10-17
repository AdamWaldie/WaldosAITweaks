"""Physical bypass proposal contract, not native steering or performance acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingBypassTests(unittest.TestCase):
    def test_stationary_vehicle_hulls_reach_bypass_without_bypassing_traffic_safety(self):
        helper=(ROOT/'addons/vehicles/functions/drivingBypassObstacleAvailable.sqf').read_text(encoding='utf-8').split('params [[',1)[1]
        for guard in ('abs speed _obstacle > 0.5','attachedTo _obstacle','attachedObjects _obstacle',
                      '!isEngineOn _obstacle','count _crew <= 64','_crew findIf {alive _x} < 0'):
            self.assertIn(guard,helper)
        for forbidden in ('setVariable','createVehicle','forceSpeed','setDriveOnPath','nearestObjects','lineIntersects'):
            self.assertNotIn(forbidden,helper)
        geometry=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text(encoding='utf-8')
        self.assertIn('_staticHulls getOrDefault',geometry)
        self.assertIn('count _staticHulls < 16',geometry)
        self.assertIn('"LandVehicle" && {!_staticHull}',geometry)
        plan=(ROOT/'addons/vehicles/functions/drivingBypassPlan.sqf').read_text(encoding='utf-8')
        self.assertEqual(plan.count('call WAIT_fnc_DrivingBypassObstacleAvailable'),2)
        step=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text(encoding='utf-8')
        self.assertEqual(step.count('call WAIT_fnc_DrivingBypassObstacleAvailable'),2)
        self.assertLess(step.rindex('call WAIT_fnc_DrivingBypassObstacleAvailable'),step.index('_vehicle setDriveOnPath'))
        following=(ROOT/'addons/vehicles/functions/drivingFollowingCap.sqf').read_text(encoding='utf-8')
        self.assertNotIn('DrivingBypassObstacleAvailable',following)

    def test_parked_fixture_requires_real_passage_and_live_occupancy_change(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runParkedBypass.sqf').read_text(encoding='utf-8')
        for marker in ('["EMPTY","WRECK","OCCUPIED"]','_ownBounds select 0','_blockBounds select 1',
                       '_lateral >= 3','_vehicle distance2D _start >= 140','"PHYSICALLY_PASSED"',
                       '_boarder assignAsDriver _blocker','[_boarder] orderGetIn true',
                       'vehicle _boarder == _blocker','"OBSTACLE_CHANGED"','time+150'):
            self.assertIn(marker,s)
        for forbidden in ('call WAIT_fnc_DrivingBypassStep','call WAIT_fnc_DrivingBypassPlan',
                          'setDriveOnPath','moveInDriver','setVariable ["WAIT_DrivingBypass_Result"',
                          'setVariable ["WAIT_DrivingBypass_Work"','forceSpeed','setPos'):
            self.assertNotIn(forbidden,s)
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('"parkedbypass"',server)
        from mod_pipeline import supported_focuses
        self.assertIn('parkedbypass',supported_focuses())

    def test_bypass_command_types_guard_execution_gate_use_and_handback(self):
        for name in ('drivingBypassStep','drivingBypassRelease','drivingGateIntent'):
            s=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            for field in ('driverTask','operatorTask','__MISSING__'):
                self.assertIn(field,s)
        step=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text(encoding='utf-8')
        for actor,key in (('_driver','driverTask'),('_operator','operatorTask')):
            self.assertIn(f'["{key}",toUpperANSI currentCommand {actor}]',step)
            self.assertIn(f'_work set ["{key}",toUpperANSI currentCommand {actor}]',step)
        release=(ROOT/'addons/vehicles/functions/drivingBypassRelease.sqf').read_text(encoding='utf-8')
        self.assertLess(release.index('getOrDefault ["driverTask"'),release.index('doStop _driver'))
        self.assertLess(release.index('getOrDefault ["operatorTask"'),release.index('_operator doMove'))

    def test_alternate_admission_preserves_vertical_destination_identity(self):
        for name in ('drivingBypassStep','drivingCorridorStep'):
            s=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            gate=s.split('private _nativeAdmissionReady={',1)[1].split('} < 0',1)[0]
            self.assertIn('count _target != 3',gate)
            self.assertIn('_target vectorDistance _destination > 3',gate)
            self.assertNotIn('distance2D',gate)
        intent=(ROOT/'addons/vehicles/functions/drivingGateIntent.sqf').read_text(encoding='utf-8')
        self.assertIn('_driverTarget vectorDistance _destination <= 3',intent)
        self.assertIn('_target vectorDistance _destination > 3',intent)

    def test_preflight_has_no_movement_or_physics_authority(self):
        for name in ('drivingBypassPlan','drivingPathGeometry'):
            body=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text().split('params [[',1)[1]
            for forbidden in ('doMove','doStop','doFollow','forceSpeed','setDriveOnPath','createVehicle',
                              'setVelocity','setPos','enableAI','spawn','waitUntil','setVariable'):
                self.assertNotIn(forbidden,body)
    def test_proposal_binds_actual_source_and_vehicle_geometry(self):
        body=(ROOT/'addons/vehicles/functions/drivingBypassPlan.sqf').read_text()
        for gate in ('time-_sampled > 1.5','_gap > 50','abs speed _vehicle > 8',
                     '(_observed select 5) != "STATIC"','_observed select 8','boundingBoxReal _obstacle',
                     'modelToWorldWorld','_radius > 12','count _guide+_segments > 24',
                     '"GEOMETRY_CHANGED"','call WAIT_fnc_DrivingPathGeometry'):
            self.assertIn(gate,body)
        self.assertEqual(body.count('call WAIT_fnc_DrivingPathGeometry'),1)
        self.assertNotIn('lineIntersectsSurfaces',body.split('params [[',1)[1])
    def test_shared_validator_keeps_three_body_heights_and_bounded_support(self):
        s=(ROOT/'addons/vehicles/functions/drivingPathGeometry.sqf').read_text()
        for gate in ('count _guide > 24','_length > 8.01','"REVERSING_PATH"','"INVALID_IGNORED_OBJECT"',
                     '"MISSING_SUPPORT"','"WET_SUPPORT"','"CROSS_SLOPE"','"LONGITUDINAL_SLOPE"',
                     '[0.5,(_height+0.5)*0.5,_height]','forEach _bodyHeights','ASLToATL _x'):
            self.assertIn(gate,s)
        corridor=(ROOT/'addons/vehicles/functions/drivingCorridorGeometry.sqf').read_text()
        self.assertIn('call WAIT_fnc_DrivingPathGeometry',corridor)
        self.assertNotIn('lineIntersectsSurfaces',corridor)
    def test_sampling_bounds_match_declared_limits(self):
        self.assertEqual(24*3+23*9,279)
        self.assertEqual(20*3+19*9,231)
        # Circumscribed clearance covers the hull at any planar orientation.
        import math
        for width,length in ((1,2),(2,5),(3,9)):
            radius=math.hypot(width,length)+1
            for angle in range(0,91,5):
                projected=abs(width*math.cos(math.radians(angle)))+abs(length*math.sin(math.radians(angle)))
                self.assertGreater(radius,projected)

    def test_executor_has_one_path_write_finite_budget_and_actual_completion(self):
        s=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text()
        self.assertEqual(s.count('setDriveOnPath'),1)
        self.assertIn('["deadline",serverTime+90]',s)
        self.assertIn('serverTime >= (_work get "deadline")',s)
        self.assertIn('_work set ["side",-1]',s)
        self.assertIn('for "_i" from 1 to 4',s)
        self.assertIn('_closest distance2D _point > 2.5',s)
        self.assertIn('modelToWorldWorld',s)
        self.assertIn('vectorDotProduct (_work get "forward") < 5',s)
        self.assertNotIn('unitReady',s)
        self.assertNotIn('set ["deadline"',s)
        self.assertIn('if (isRemoteExecuted) exitWith',s)
        self.assertIn('call _seatsAvailable',s)
        self.assertIn('bis_fnc_moduleRemoteControl_owner',s)
        self.assertNotIn('["authority",',s)
    def test_controller_preserves_other_constraints_and_excludes_other_paths(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertEqual(s.count('call WAIT_fnc_DrivingBypassStep'),1)
        self.assertIn('!_hadBypass',s)
        self.assertIn('_traffic=+_withoutObstacle;',s)
        self.assertIn('_bypass select 3',s)
        self.assertIn('_obstacleObservation select 8',s)
        self.assertIn('_capMps=_capMps min (_bypass select 1)',s)
        self.assertIn('_pedestrianCap/3.6 < (_traffic select 0)',s)
        self.assertIn('WAIT_DrivingBypass_Work',(ROOT/'addons/vehicles/functions/drivingCorridorStep.sqf').read_text())
        fsm=(ROOT/'addons/main/fsm/drivingOperation.fsm').read_text()
        for phase in ('BYPASS_PLAN','BYPASS_FOLLOW'):self.assertIn(phase,fsm)
    def test_release_requires_owned_follow_and_both_native_receipts(self):
        s=(ROOT/'addons/vehicles/functions/drivingBypassRelease.sqf').read_text()
        for marker in ('(_work get "phase") == "FOLLOW"','expectedDestination _driver',
                       'expectedDestination _operator','CortexExternalTakeover','DrivingRouteReceipt',
                       'count _cooldown >= 32','serverTime+120'):
            self.assertIn(marker,s)
        for forbidden in ('setPos','setVelocity','enableAI','addWaypoint','deleteWaypoint','spawn','waitUntil'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])

    def test_executor_rechecks_plain_order_and_both_crew_tasks_before_writes(self):
        s=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text()
        gate=s.split('private _plainRoute={',1)[1].split('private _work=',1)[0]
        for marker in ('waypointType _waypoint == "MOVE"','waypointScript _waypoint == ""',
                       'waypointTimeout','waypointAttachedVehicle','waypointAttachedObject',
                       'synchronizedWaypoints','synchronizedTriggers','call _plainRoute',
                       'DrivingMovementAvailable','CortexExternalTakeover','CortexZeusHeld',
                       'WAIT_ExternalDrivingOwner','WAIT_Convoy_Active','vehicle leader _group isEqualTo _vehicle'):
            self.assertIn(marker,gate)
        seats=s.split('private _seatsAvailable={',1)[1].split('private _plainRoute={',1)[0]
        self.assertIn('[_driver,_operator] findIf',seats)
        for task in ('"GET IN"','"SCRIPTED"','"REPAIR"','"CARRY SOLDIER"'):
            self.assertIn(task,seats)
        # Admission and the final path-write boundary both re-evaluate the same predicate.
        self.assertGreaterEqual(s.count('call _mayWrite'),2)
        self.assertLess(s.rindex('call _mayWrite'),s.index('_vehicle setDriveOnPath'))

    def test_convoy_lead_requires_its_own_registry_and_feature_gates(self):
        s=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text()
        for marker in ('WAIT_Convoy_Brain','WAIT_Convoy_ReceivedRevision','WAIT_Convoy_LocalJobToken',
                       'WAIT_Convoy_LocalRegistry','WAIT_Convoy_RouteRecovery_Enable',
                       'WAIT_Convoy_DrivingAssist_Enable','_mobile select 0','_controllerReceipt',
                       '_columnLength','_envelope','"tailDeadline"'):
            self.assertIn(marker,s)
        self.assertEqual(s.count('call WAIT_fnc_DrivingBypassPlan'),1)
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertEqual(tick.count('call WAIT_fnc_DrivingBypassStep'),1)
        self.assertIn('"CONVOY"] call WAIT_fnc_DrivingBypassStep',tick)
        self.assertIn('!_bypassPassageActive',tick)
        self.assertIn('!_hadBypass',tick)
        self.assertIn('!_bypassActive',tick)
        self.assertIn('if (!_bypassPassageActive && {!_hadBypassPassage})',tick)
        self.assertIn('CONVOY_PASSAGE_ENDED',tick)
    def test_follower_cannot_yield_source_from_lead_success_alone(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        leg=s.split('private _bypassLegClear=false;',1)[1].split('private _trafficBlocked=',1)[0]
        for marker in ('_episode get "obstacle"','_episode get "transform"','_progress param [10,[]]',
                       'expectedDestination driver _vehicle','expectedDestination _movementOperator',
                       '_nearest+1 < count _committed','vectorDotProduct _forward',
                       'call WAIT_fnc_DrivingPathGeometry','!_bypassLegClear'):
            self.assertIn(marker,leg)
        self.assertNotIn('forceSpeed',leg)
        self.assertNotIn('setDriveOnPath',leg)
    def test_column_passage_is_passive_finite_and_requires_every_vehicle(self):
        s=(ROOT/'addons/vehicles/functions/convoyBypassStep.sqf').read_text()
        for marker in ('"tailDeadline"','count _rows > 20','count _points > 24',
                       'for "_i" from 1 to 4','modelToWorldWorld','_checkpoint >= count _points',
                       '_passedCount == count _rows','"ALL_VEHICLES_PHYSICALLY_PASSED"',
                       '"ORDER_CHANGED"','"OBSTACLE_CHANGED"','"TAIL_TIMEOUT"','"VEHICLE_UNAVAILABLE"'):
            self.assertIn(marker,s)
        for forbidden in ('doStop','doMove','forceSpeed','setDriveOnPath','spawn','waitUntil','lineIntersectsSurfaces'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])
        for phase in ('BYPASS_PLAN','BYPASS_FOLLOW','BYPASS_TAIL'):
            self.assertIn(phase,(ROOT/'addons/main/fsm/convoyOperation.fsm').read_text())
    def test_convoy_cleanup_cannot_claim_ordinary_or_successor_work(self):
        s=(ROOT/'addons/vehicles/functions/drivingBypassRelease.sqf').read_text()
        for marker in ('_expectedRevision','_successor','_stopOnly','_haltCleanup','WAIT_Convoy_LocalRegistry'):
            self.assertIn(marker,s)
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        self.assertIn('_bypass getOrDefault ["controller",["ORDINARY",-1]]',ordinary)
        for filename in ('convoyReleaseLocal','convoyCrewLocal'):
            body=(ROOT/f'addons/vehicles/functions/{filename}.sqf').read_text()
            self.assertIn('WAIT_fnc_DrivingBypassRelease',body)
            self.assertIn('WAIT_fnc_ConvoyBypassStep',body)

    def test_new_follower_move_yields_before_crew_and_path_writes(self):
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        gate=tick.index('private _commandYield=')
        self.assertLess(gate,tick.index('call WAIT_fnc_ConvoyCrewLocal'))
        for marker in ('WAIT_Convoy_MovementReceipt','WAIT_Convoy_CommandYield',
                       'currentCommand _operator == "MOVE"','_was vectorDistance _now > 0.25',
                       '"NEW_NATIVE_ORDER"','(_commandYield param [0,-1]) == _revision'):
            self.assertIn(marker,tick)
        crew=(ROOT/'addons/vehicles/functions/convoyCrewLocal.sqf').read_text()
        self.assertLess(crew.index('WAIT_Convoy_CommandYield'),crew.index('WAIT_Convoy_CrewDue'))
        release=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        self.assertIn('private _mayHandBack=!_preserveMoves',release)
        self.assertIn('if (_mayRestoreGroup && {!_preserveMoves})',release)
        self.assertIn('!_preserveMoves,_preserveMoves',release)
        self.assertIn('if (_mayStopOwned && {_pathOwned})',release)

    def test_bypass_approach_allowance_ends_at_ordered_entry(self):
        s=(ROOT/'addons/vehicles/functions/convoyBypassStep.sqf').read_text()
        cap=s.split('private _room=0;',1)[1].split('_caps set [netId _vehicle,_cap];',1)[0]
        self.assertIn('if (_checkpoint == 0)',cap)
        self.assertIn('_origin distance2D (_points select 0)',cap)
        self.assertIn('-_body-6',cap)
        self.assertIn('getMass _vehicle',cap)
        self.assertIn('private _target=8/3.6',cap)
        self.assertNotIn('forceSpeed',cap)

    def test_path_support_cannot_use_vehicles_people_or_moving_props(self):
        s=(ROOT/'addons/vehicles/functions/drivingPathGeometry.sqf').read_text(encoding='utf-8')
        support=s.split('private _hit=_hits select 0;',1)[1].split('_supports pushBack',1)[0]
        self.assertIn('if (!isNull (_hit select 3)) then {_hit select 3} else {_hit select 2}',support)
        self.assertIn('_supportObject isKindOf "AllVehicles"',support)
        self.assertIn('vectorMagnitude velocity _supportObject > 0.1',support)
        self.assertIn('_reason="UNSTABLE_SUPPORT"',support)
        self.assertIn('if (_reason != "") exitWith',s)
        self.assertEqual(s.count('lineIntersectsSurfaces'),2)

    def test_stop_guard_distinguishes_reverse_from_fixed_path_acquisition(self):
        release=(ROOT / "addons/vehicles/functions/drivingRecoveryRelease.sqf").read_text(encoding="utf-8")
        self.assertIn('currentCommand _x != "STOP"', release)
        self.assertLess(release.index('currentCommand _x != "STOP"'), release.index('doStop _driver'))
        for name, actor in (("drivingBypass", "_x"), ("drivingCorridor", "_actor")):
            with self.subTest(controller=name):
                step=(ROOT / "addons/vehicles/functions" / (name+"Step.sqf")).read_text(encoding="utf-8")
                release=(ROOT / "addons/vehicles/functions" / (name+"Release.sqf")).read_text(encoding="utf-8")
                self.assertLess(step.index('doStop _driver'), step.index('_vehicle setDriveOnPath _points'))
                self.assertNotIn('currentCommand '+actor+' != "STOP"', release)
                for guard in ('expectedDestination _driver', 'expectedDestination _operator',
                              'WAIT_fnc_CortexZeusHeld', 'WAIT_fnc_CortexExternalTakeover'):
                    self.assertIn(guard, release)


class BypassObservedCheckpointTests(unittest.TestCase):
    @staticmethod
    def capture(points, previous, current, fresh=True):
        if not fresh:
            previous=current
        sweep=[b-a for a,b in zip(previous,current)]
        squared=sum(v*v for v in sweep[:2])
        index=0
        last=0
        for point in points[:4]:
            fraction=max(0,min(1,sum((point[i]-previous[i])*sweep[i] for i in (0,1))/squared)) if squared > .01 else 1
            closest=[previous[i]+sweep[i]*fraction for i in range(3)]
            if fraction < last or sum((closest[i]-point[i])**2 for i in (0,1)) > 2.5**2 or abs(closest[2]-point[2]) > 2:
                break
            last=fraction
            index+=1
        return index

    def test_delayed_callback_counts_passed_checkpoint(self):
        self.assertEqual(self.capture([(0,5,0)],(0,0,0),(0,9,0)),1)
        self.assertEqual(self.capture([(0,5,0)],(0,0,0),(0,9,0),False),0)

    def test_prefix_and_direction_are_preserved(self):
        self.assertEqual(self.capture([(5,5,0),(0,8,0)],(0,0,0),(0,10,0)),0)
        self.assertEqual(self.capture([(0,8,0),(0,3,0)],(0,0,0),(0,10,0)),1)

    def test_height_is_interpolated_and_other_floor_rejected(self):
        self.assertEqual(self.capture([(0,5,5)],(0,0,0),(0,10,10)),1)
        self.assertEqual(self.capture([(0,5,0)],(0,0,5),(0,10,5)),0)

    def test_executor_binds_capture_to_current_owner_and_fresh_short_sweep(self):
        source=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text()
        for guard in ('(_capture select 2) isEqualTo _captureOwner','serverTime-(_capture select 1) <= 3',
                      '_origin vectorDistance (_capture select 0) <= 12','_brain getOrDefault ["ownerEpoch",-1]',
                      '_fraction < _lastFraction','for "_i" from 1 to 4 do'):
            self.assertIn(guard,source)
        self.assertIn('_work set ["capture",[+_origin,serverTime,+_captureOwner]',source)
        self.assertIn('if (_index != (_work get "index")) then',source)
        self.assertIn('_brain getOrDefault ["jobToken",""]',source)
        self.assertIn('_brain getOrDefault ["generation",-1]',source)


class ConvoyBypassObservedCheckpointTests(unittest.TestCase):
    def test_capture_is_local_episode_scoped_and_bounded(self):
        source=(ROOT/'addons/vehicles/functions/convoyBypassStep.sqf').read_text()
        for marker in ('[_episode get "identity",clientOwner,_brain getOrDefault ["jobToken",""]]',
                       'serverTime-(_capture select 1) <= 3',
                       '_origin vectorDistance (_capture select 0) <= 12',
                       '_fraction < _lastFraction','_closest distance2D _point > 3.5',
                       '_group setVariable ["WAIT_Convoy_BypassCapture",nil]',
                       'private _nextCaptures=createHashMap'):
            self.assertIn(marker,source)
        self.assertNotIn('WAIT_Convoy_BypassCapture",[_captureIdentity,_nextCaptures],true',source)
        self.assertIn('if (_changed) then',source)

    def test_individual_tail_clearance_still_follows_checkpoint_capture(self):
        source=(ROOT/'addons/vehicles/functions/convoyBypassStep.sqf').read_text()
        capture=source.index('private _closest=')
        clearance=source.index('private _clear=_checkpoint >= count _points')
        completion=source.index('_passedCount == count _rows')
        self.assertLess(capture,clearance)
        self.assertLess(clearance,completion)
        self.assertIn('modelToWorldWorld [_xCoord,_yCoord,_x]',source)
        self.assertIn('for "_i" from 1 to 4',source)

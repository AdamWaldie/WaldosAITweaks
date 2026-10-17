"""Shared solid/gate observation wiring; no physical detour or braking acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingGeometryTests(unittest.TestCase):
    def test_geometry_is_one_bounded_live_observation_without_helpers(self):
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text().split('params [[',1)[1]
        self.assertEqual(s.count('lineIntersectsSurfaces'),1)
        for required in ('true,4,"GEOM","NONE"','[_left,(_left+_right)*0.5,_right]',
                         'forEach _heights','max 25 min 600','getPosWorld _object','vectorUp _object',
                         '(_normal select 2) < 0.7','_object isKindOf "LandVehicle"'):
            self.assertIn(required,s)
        for forbidden in ('createVehicle','allMissionObjects','allDead','spawn','waitUntil','setVariable',
                          'setVelocity','doMove','forceSpeed','animateSource','animationSourcePhase'):
            self.assertNotIn(forbidden,s)
    def test_support_filter_keeps_downward_undersides_as_obstructions(self):
        import re
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text(encoding='utf-8')
        # Read the actual production predicate, including a possible absolute-value regression.
        match=re.search(r'&& \{(?P<absolute>abs )?\(_normal select 2\) < (?P<cutoff>[0-9.]+)\}',s)
        self.assertIsNotNone(match)
        cutoff=float(match.group('cutoff'))
        def blocks(z):
            return (abs(z) if match.group('absolute') else z) < cutoff
        for label,z,expected in [('level support',1,False),('gentle uphill support',0.9,False),
                                 ('vertical wall',0,True),('sloping underside',-0.8,True),
                                 ('horizontal underside',-1,True)]:
            with self.subTest(surface=label):
                self.assertEqual(blocks(z),expected)

    def test_gate_adapter_preserves_only_gate_result_and_barriers_need_sources(self):
        s=(ROOT/'addons/vehicles/functions/drivingGateCap.sqf').read_text()
        self.assertIn('call WAIT_fnc_DrivingGeometryCap) select 0',s)
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text()
        self.assertIn('_gateClasses getOrDefault',s)
        self.assertIn('for "_index" from 1 to 8',s)
        self.assertIn('isClass (configOf _object >> "AnimationSources"',s)
        self.assertIn('[_gateObservation,_solidObservation]',s)
    def test_solid_constraints_reuse_existing_writers_and_fsm_queue(self):
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        convoy=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertEqual(ordinary.count('call WAIT_fnc_DrivingGeometryCap'),1)
        self.assertEqual(convoy.count('call WAIT_fnc_DrivingGeometryCap'),2)
        self.assertIn('_traffic=_obstacleObservation select [0,5]',ordinary)
        self.assertIn('_leadTraffic=_leadObstacle select [0,5]',convoy)
        self.assertIn('_traffic=_vehicleObstacle select [0,5]',convoy)
        for path in ('drivingOperation','convoyOperation'):
            self.assertIn('""OBSTACLE""',(ROOT/f'addons/main/fsm/{path}.fsm').read_text())
        release=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        self.assertIn('WAIT_DrivingAssist_Obstacle",nil',release)

    def test_turn_prediction_is_bounded_read_only_and_keeps_absolute_hull_rows(self):
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text()
        for marker in ('angularVelocityModelSpace _vehicle','_velocity <= 1','_velocity*2.5',
                       '70/57.2957795','>= 3','0.5*_bendLength,_bendLength,_horizon',
                       'count _stations-1','_front*sin _angle','_width*sin _angle',
                       '_segmentStart+_fraction*(_segmentEnd-_segmentStart)','_from vectorDistance _to'):
            self.assertIn(marker,s)
        self.assertEqual(s.count('lineIntersectsSurfaces'),1)
        self.assertNotIn('setAngularVelocity',s)
        self.assertNotIn('setVariable',s.split('params [[',1)[1])

    def test_track_measurement_resets_at_ownership_route_and_motion_boundaries(self):
        s=(ROOT/'addons/vehicles/functions/drivingTurnTrack.sqf').read_text()
        for marker in ('clientOwner','driver _vehicle','effectiveCommander _vehicle',
                       '_forward <= 1','_previous select 0) isNotEqualTo _identity',
                       'time-(_previous select 2) > 6','_distanceSquared >= 9',
                       'time-(_previous select 2) >= 1.5','abs _curvature < 0.004',
                       'worldToModel','ASLToAGL'):
            self.assertIn(marker,s)
        for forbidden in ('setVariable','spawn','waitUntil','doMove','forceSpeed','lineIntersectsSurfaces'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])
        for name in ('drivingAssistStart','convoyTick'):
            self.assertIn('call WAIT_fnc_DrivingTurnTrack',(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text())

    def test_ordinary_measurements_are_per_vehicle_and_prune_departed_roster(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertIn('private _geometryTracks=createHashMap',s)
        self.assertIn('_priorTracks getOrDefault [netId _x,[]]',s)
        self.assertIn('_geometryTracks getOrDefault [netId _vehicle,[]]',s)
        self.assertIn('_geometryTracks set [netId _vehicle,_turn select 1]',s)
        self.assertNotIn('getOrDefault ["geometryTrack",[]]',s)

    def test_native_path_hint_is_fresh_local_bounded_and_not_a_movement_writer(self):
        s=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text()
        for marker in ('"PathCalculated"','_path select [0,64]','_thisEventHandler',
                       'removeEventHandler','_expectedRevision','time-(_segment select 1) > 5',
                       'expectedDestination _driver','expectedDestination _operator',
                       '_distance < _nearDistance','_distance >= 3','_distance <= 12','(_target select 1) > 1','_walked >= 6','_oldBinding select 3'):
            self.assertIn(marker,s)
        for forbidden in ('doMove','setDriveOnPath','forceSpeed','calculatePath','createAgent','spawn','waitUntil'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])
        self.assertNotRegex(s.split('params [[',1)[1],r'setVariable\s*\[[^\n]*,\s*true\s*\]')
        for name in ('drivingAssistRelease','convoyReleaseLocal'):
            self.assertIn('call WAIT_fnc_DrivingNativePathWatch',(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text())

    def test_native_path_lookahead_is_distance_bounded_for_dense_and_sparse_nodes(self):
        s=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text(encoding='utf-8')
        selection=s.split('// Native paths may use dense nodes.',1)[1]
        for marker in ('_nearPoint=+_closest','for "_i" from (_nearIndex+1) to (count _nodes-1)',
                       '_advance=_length min (6-_walked)','_delta vectorMultiply (_advance/_length)',
                       '_floorLost','_distance >= 3','_distance <= 12'):
            self.assertIn(marker,s)
        self.assertNotIn('_nearIndex+3',selection)
        self.assertLess(selection.index('_floorLost ||'),selection.index('worldToModel'))
        # Prior next-three-node admission rejects these valid half-metre forward samples.
        dense=[i*0.5 for i in range(1,64)]
        self.assertLess(max(dense[:3]),3)
        self.assertIn(6,dense)
        # A single sparse segment also spans the desired lookahead; interpolation is required.
        self.assertLess(6,20)
        self.assertIn('_path select [0,64]',s)

    def test_native_path_subscription_expires_before_copy_and_feature_off_retires_old_revision(self):
        s=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text()
        event=s.split('private _id=_driver addEventHandler',1)[1].split('_record=[_group',1)[0]
        for marker in ('WAIT_DrivingNativePath_ValidUntil','CortexFeatureEnabled',
                       'bis_fnc_moduleRemoteControl_owner','CortexExternalOwner'):
            self.assertLess(event.index(marker),event.index('_path select [0,64]'))
        self.assertIn('[_unit,effectiveCommander _vehicle] findIf',event)
        self.assertIn('[_driver,_operator] findIf',s)
        self.assertIn('"WAIT_DrivingNativePath_ValidUntil",time+6',s)
        self.assertIn('"WAIT_DrivingNativePath_ValidUntil",nil',s)
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertIn('["CONVOY"],true] call WAIT_fnc_DrivingNativePathWatch',tick)
        release=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        self.assertIn('["CONVOY"],true,_navigation getOrDefault ["revision",-1]',release)

    def test_native_path_crossing_refuses_disconnected_near_stretches(self):
        source=(ROOT/'addons/vehicles/functions/drivingNativePathWatch.sqf').read_text(encoding='utf-8')
        for marker in ('_nearRuns=0','_inNearRun=false','_distance <= 3',
                       'if (!_inNearRun) then {_nearRuns=_nearRuns+1}',
                       '_nearIndex < 0 || {_distance < _nearDistance}',
                       '_nearIndex < 0 || {_nearRuns > 1}'):
            self.assertIn(marker,source)
        # Dense consecutive near segments are one stretch; leaving and returning is ambiguous.
        def stretches(flags):
            return sum(flag and (i==0 or not flags[i-1]) for i,flag in enumerate(flags))
        self.assertEqual(stretches([False,True,True,True,False]),1)
        self.assertEqual(stretches([True,True,False,False,True]),2)
        self.assertEqual(stretches([False]*63),0)
        # A self-crossing polyline has two separate stretches near the origin.
        # Its later northbound return must not replace the first northeast approach.
        import math
        def distance_to_segment(a,b):
            dx,dy=b[0]-a[0],b[1]-a[1]
            fraction=max(0,min(1,-(a[0]*dx+a[1]*dy)/(dx*dx+dy*dy)))
            return math.hypot(a[0]+fraction*dx,a[1]+fraction*dy)
        crossing=[(-10,-5),(8,4),(20,20),(0,-10),(0,8)]
        flags=[distance_to_segment(a,b)<=3 for a,b in zip(crossing,crossing[1:])]
        self.assertEqual(flags,[True,False,False,True])
        self.assertEqual(stretches(flags),2)
    def test_convoy_bypass_relaxation_rejects_multiple_capture_clusters_and_wrong_floor(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        gate=s.split('private _bypassLegClear=false',1)[1].split('if (!_bypassLegClear',1)[0]
        self.assertIn('count _committed <= 11',gate)
        self.assertIn('abs ((_origin select 2)-(_pointASL select 2)) <= 1.5',gate)
        self.assertIn('if (_captureRuns != 1) then {_nearest=-1}',gate)
        self.assertLess(gate.index('_captureRuns != 1'),gate.index('call WAIT_fnc_DrivingPathGeometry'))
        self.assertNotIn('doMove',gate)
        self.assertNotIn('setDriveOnPath',gate)
        def runs(points):
            flags=[(x*x+y*y)**0.5<4 and abs(z)<=1.5 for x,y,z in points]
            return sum(value and (i==0 or not flags[i-1]) for i,value in enumerate(flags))
        self.assertEqual(runs([(0,1,0),(0,5,0),(5,5,0),(0,0,0)]),2)
        self.assertEqual(runs([(0,1,0),(0,2,0),(0,5,0)]),1)
        self.assertEqual(runs([(0,0,5),(0,1,5)]),0)


class ConvoyOrderedCaptureTests(unittest.TestCase):
    """Arithmetic route cases, not native steering or physical acceptance."""
    @staticmethod
    def capture(trail, pose, previous=None):
        import math
        previous=pose if previous is None else previous
        sweep=[b-a for a,b in zip(previous,pose)]
        squared=sweep[0]**2+sweep[1]**2
        candidates=[]
        for i,point in enumerate(trail):
            t=max(0,min(1,sum((point[k]-previous[k])*sweep[k] for k in (0,1))/squared)) if squared>.01 else 1
            near=[previous[k]+t*sweep[k] for k in range(3)]
            if math.dist(near[:2],point[:2])>=18 or abs(near[2]-point[2])>1.5:
                break
            candidates.append((math.dist(pose[:2],point[:2]),i))
        return min(candidates)[1] if candidates else -1

    def test_loop_return_does_not_skip_untravelled_middle(self):
        trail=[(0,5,0),(0,10,0),(0,15,0),(10,15,0),(10,0,0),(1,0,0),(1,-10,0)]
        self.assertEqual(self.capture(trail,(0,0,0)),0)
        # A nearer return point must remain unavailable beyond an uncaptured bend.
        self.assertEqual(self.capture([(0,5,0),(0,25,0),(1,0,0)],(0,0,0)),0)

    def test_observed_straight_travel_can_pass_multiple_samples(self):
        trail=[(0,y,0) for y in range(0,61,5)]
        self.assertEqual(self.capture(trail,(0,30,0),(0,0,0)),6)
        # A missing sweep cannot justify skipping the first now-distant point.
        self.assertEqual(self.capture(trail,(0,30,0)),-1)

    def test_height_separates_overpass_and_interpolates_observed_grade(self):
        self.assertEqual(self.capture([(0,0,6),(0,5,6)],(0,0,0)),-1)
        self.assertEqual(self.capture([(0,y,y/5) for y in range(0,31,5)],(0,30,6),(0,0,0)),6)

    def test_production_uses_contiguous_capture_and_only_next_join_point(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        gate=s.split('// Advance only through a contiguous prefix',1)[1].split('if (_nearest >= 0)',1)[0]
        for marker in ('time-(_sample select 1) <= 3','vectorDistance _pose <= 100',
                       '_capture distance2D _pointASL >= 18','> 1.5}) exitWith {}',
                       '_progress set [11,[+_pose,time]]',
                       'for "_j" from _start to (_start min _frontIndex)',
                       'abs ((_point select 2)-(_origin select 2)) <= 1.5'):
            self.assertIn(marker,gate)

"""Native planning grace and finite recovery timing contracts; no live acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingPlanningGraceTests(unittest.TestCase):
    def test_stages_have_distinct_observation_windows(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('private _observationWindow=[20,30,0,60] param [_recoveryStage,60]',s)
        self.assertIn('time-_progressAt >= _observationWindow || {_reverseComplete}',s)
        refresh=s.split('case 0: {',1)[1].split('case 1:',1)[0]
        reverse=s.split('case 1: {',1)[1].split('case 2:',1)[0]
        retry=s.split('case 2: {',1)[1].split('default {',1)[0]
        self.assertIn('_recoveryUntil=["REFRESH"] call _recordRecovery',refresh)
        self.assertIn('call _recordRecovery',reverse)
        self.assertIn('_recoveryUntil=["FINAL"] call _recordRecovery',retry)
        self.assertIn('case "REFRESH":{_hard-66}',s)
        self.assertIn('default {_hard-60}',s)
        self.assertIn('serverTime >= (_scheduledRecovery get "hardDeadline")-60',s)
        self.assertIn('|| {_finalExpired}',s)
    def test_new_order_and_real_progress_reset_observation_before_admission(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        changed=s.split('(_state param [9,[]]) isNotEqualTo _routeIdentity',1)[1].split('// A follower',1)[0]
        for marker in ('_state set [5,time]','_state set [6,0]','_state set [7,-1]'):
            self.assertIn(marker,changed)
        progress=s.split('if (_recoveryStage != 2 && {!_trafficLimited} && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {_vehicle distance2D',1)[1].split('private _waypointIndex=',1)[0]
        self.assertIn('_progressAt=time',progress)
        self.assertIn('_recoveryStage=0',progress)
    def test_follower_handover_retires_owned_reverse_before_stage_reset(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        follower=s.split('vehicle leader _group isNotEqualTo _vehicle}) then {',1)[1].split('if (_state isNotEqualTo [] && {call _nativeWaiting})',1)[0]
        self.assertLess(follower.index('call WAIT_fnc_DrivingRecoveryRelease'),follower.index('_state set [6,0]'))
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        for guard in ('driverCommand','expectedDestination _operator','DrivingRouteReceipt','CortexExternalTakeover','CortexZeusHeld'):
            self.assertIn(guard,release)
        self.assertIn('_operator doFollow leader _group',release)
    def test_traffic_retry_is_finite_and_keeps_collision_caps(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        jam=s.split('// Bounded traffic replan:',1)[1].split('// Waiting behind traffic',1)[0]
        for guard in ('serverTime+80','serverTime+20','(_jam get "attempts") < 3','serverTime < (_jam get "deadline")',
                      'serverTime-(_jam get "since") >= 20','abs speed _jamPeer < 1','abs speed _vehicle < 1',
                      '_recoveryStage == 0','call _mayRecoverOrdinaryRoute','driverCommand','["yielded",true]',
                      'distance2D (_jam get "origin")) >= 15','["since",-1]'):
            self.assertIn(guard,jam)
        for forbidden in ('forceSpeed','deleteWaypoint','addWaypoint','enableAI','setVelocity','sendSimpleCommand','spawn'):
            self.assertNotIn(forbidden,jam)
        self.assertEqual(jam.count(' doMove '),1)
        self.assertLess(s.index('_vehicle forceSpeed _capMps'),s.index('// Bounded traffic replan:'))
    def test_traffic_dwell_requires_current_owner_and_fresh_samples(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        jam=s.split('// Bounded traffic replan:',1)[1].split('// Waiting behind traffic',1)[0]
        self.assertIn('[clientOwner,_brain getOrDefault ["ownerEpoch",-1],_routeIdentity,_driver,_movementOperator]',jam)
        self.assertIn('serverTime-(_jamSeen select 2) <= 6',jam)
        self.assertIn('serverTime >= (_jamSeen select 2)',jam)
        self.assertIn('if (!_jamContinuous ||',jam)
        seen=next(line for line in jam.splitlines() if 'setVariable ["WAIT_DrivingTrafficSeen"' in line)
        self.assertNotIn(',true]',seen)
        reset=jam.split('if (!_jamContinuous ||',1)[1].split('};',1)[0]
        self.assertNotIn('"deadline"',reset)
        self.assertNotIn('"attempts"',reset)
        release=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text(encoding='utf-8')
        self.assertIn('setVariable ["WAIT_DrivingTrafficSeen",nil]',release)
    def test_stationary_dwell_uses_episode_anchors_not_sliding_samples(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        dwell=s.split('private _jamOwnPose=',1)[1].split('if (_jamEligible) then {',1)[0]
        for gate in ('count _jamSeen == 5','_jamOwnPose vectorDistance (_jamSeen select 3) <= 1.5','_jamPeerPose vectorDistance (_jamSeen select 4) <= 1.5','+(_jamSeen select 3)','+(_jamSeen select 4)'):
            self.assertIn(gate,dwell)
        self.assertNotIn('"deadline"',dwell)
        self.assertNotIn('"attempts"',dwell)
        # At 0.2m/s all four-second steps are below1.5m, but twenty-second dwell is false.
        anchor=0;since=0;last=0
        for now in range(4,25,4):
            position=now*0.2
            self.assertLessEqual(position-last,1.5)
            if abs(position-anchor)>1.5:
                anchor=position;since=now
            self.assertLess(now-since,20)
            last=position
        # Vertical relocation also invalidates the ASL anchor; unchanged poses retain it.
        from math import dist
        self.assertGreater(dist((0,0,3),(0,0,0)),1.5)
        self.assertEqual(dist((0,0,0),(0,0,0)),0)
    def test_direct_native_order_blocks_route_recovery_but_not_owned_rear_handback(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        guard=s.split('private _nativeRouteIntent={',1)[1].split('private _priorOwner=',1)[0]
        self.assertIn('_command == "STOP"',guard)
        self.assertIn('if (!(_command in ["MOVE","WAIT"])) exitWith {_command == ""}',guard)
        self.assertIn('distance2D waypointPosition _waypoint <= 3',guard)
        for receipt in ('get "group"','get "route"','get "driver"','get "operator"','get "driverCommand"','get "command"'):
            self.assertIn(receipt,guard)
        self.assertIn('private _mayRecoverOrdinaryRoute={call _mayRecoverRoute && {call _nativeRouteIntent}',guard)
        self.assertIn('currentCommand _movementOperator != "STOP"',s.split('private _release=',1)[0])
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDrivingTraffic.sqf').read_text(encoding='utf-8')
        self.assertIn('(driver _follower) doMove _directDestination',audit)
        self.assertIn('DRIVING-traffic-newer-direct-MOVE-preserved',audit)
        self.assertIn('(_retry getOrDefault ["attempts",0]) > _attemptsBefore',audit)

    def test_timing_model_never_escalates_before_required_observation(self):
        windows=(20,30,0,60)
        def due(stage,elapsed,deadline_elapsed,traffic=False):
            reverse_complete=stage==2 and deadline_elapsed
            return not traffic and deadline_elapsed and (elapsed>=windows[stage] or reverse_complete)
        for stage,window in ((0,20),(1,30),(3,60)):
            self.assertFalse(due(stage,window-0.01,True))
            self.assertTrue(due(stage,window,True))
            self.assertFalse(due(stage,window+100,True,traffic=True))
        self.assertFalse(due(2,5,False))
        self.assertTrue(due(2,6,True))

    def test_non_route_native_tasks_do_not_grant_ordinary_recovery(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        guard=s.split('private _nativeRouteIntent={',1)[1].split('private _priorOwner=',1)[0]
        self.assertIn('toUpperANSI currentCommand _movementOperator', guard)
        self.assertIn('exitWith {_command == ""}', guard)
        self.assertNotIn('exitWith {true}', guard.split('private _native=',1)[0])
        self.assertIn('toUpperANSI currentCommand _driver in ["","MOVE","WAIT"]', guard)
        owned=s.split('private _recoveryOwned=',1)[1].split('if (count _recoveryWork',1)[0]
        self.assertIn('[_driver,_movementOperator] findIf', owned)
        self.assertIn('toUpperANSI currentCommand _x in ["","MOVE","WAIT"]', owned)
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        self.assertIn('toUpperANSI currentCommand _x in ["","MOVE","WAIT"]', release)

if __name__=='__main__':unittest.main()

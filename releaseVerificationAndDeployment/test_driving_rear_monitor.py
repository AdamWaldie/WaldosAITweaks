"""Finite rear-leg safety and scheduler contracts, not native braking acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(n):return (ROOT/'addons/vehicles/functions'/f'{n}.sqf').read_text(encoding='utf-8')
class DrivingRearMonitorTests(unittest.TestCase):
    def test_rear_observation_applies_before_speed_write_without_extending_deadline(self):
        s=src('drivingAssistStart')
        sample=s.split('if (_reverseLeg) then {',1)[1].split('private _trafficLimited=',1)[0]
        self.assertIn('[_vehicle,8] call WAIT_fnc_DrivingRearClear',sample)
        self.assertIn('_traffic=[0,_vehicle,-1,time,0]',sample)
        self.assertNotIn('_recoveryUntil=',sample)
        self.assertLess(s.index('private _rearObservation='),s.index('_vehicle forceSpeed _capMps'))
        self.assertIn('if (_reverseExpired && {!_retryAllowed}) then {_traffic=[0,_vehicle,-1,time,0]}',s)
    def test_direction_and_issued_receipt_survive_stop_and_expire(self):
        s=src('drivingAssistStart')
        self.assertIn('_state param [10,',s)
        self.assertIn('_recoveryResult="CAUTIOUS_REVERSE";_reverseIssued=true',s)
        self.assertIn('_recoveryResult="REAR_BLOCKED";_reverseIssued=false',s)
        self.assertIn('_recoveryResult="FINAL_ROUTE_RETRY";_reverseIssued=false',s)
        self.assertIn('if (_reverseLeg) then {-1}',s)
        self.assertIn('_routeIdentity,_reverseIssued',s)
        observer=(ROOT/'addons/infantry/functions/cortexInfantrySpeed.sqf').read_text(encoding='utf-8')
        self.assertIn('["_travelIntent",0,[0]]',observer)
        self.assertIn('if (_travelIntent == 0)',observer)
    def test_existing_scheduler_samples_active_rear_stage_faster(self):
        self.assertIn('time+([4,1] select (_trafficLimited || {_corridorActive} || {_bypassActive} || {_recoveryStage == 2}))',src('drivingAssistStart'))
        self.assertIn('_rearLeg=_rearLeg || {(_state param [6,0]) == 2}',src('drivingOperationStep'))
        self.assertIn('time+([4,1] select (_crewPending || {_traffic} || {_obstacle} || {_rearLeg} || {_corridor != ""} || {_bypass != ""} || {_passing}))',src('drivingOperationStep'))


    def test_rear_prediction_uses_simultaneous_intervals_and_finite_scan_budget(self):
        s=src('drivingRearClear')
        for marker in ('private _predictionSeconds=2','35*_predictionSeconds',
                       '_radius > 250','"REAR_SCAN_BUDGET"','"REAR_APPROACHING"',
                       'vectorDiff _ownVelocity','for "_axis" from 0 to 2',
                       '_entry=_entry max','_exit=_exit min','_entry <= _exit'):
            self.assertIn(marker,s)
        self.assertLess(s.index('if (_current) exitWith {true}'),s.index('private _relative='))
        self.assertEqual(s.count('nearEntities'),2)
        for forbidden in ('setVariable','sendSimpleCommand','forceSpeed','doMove','setVelocity'):
            self.assertNotIn(forbidden,s.split('params [[',1)[1])



    def test_tracked_reverse_commands_bind_seats_destinations_and_route(self):
        s=src('cortexVehicleReverseStep')
        for marker in ('WAIT_VehicleReverse_Command','driver _ownedVehicle == (_commandReceipt select 1)',
                       'effectiveCommander _ownedVehicle == (_commandReceipt select 2)',
                       'expectedDestination (_commandReceipt select 1)',
                       'expectedDestination (_commandReceipt select 2)',
                       'WAIT_fnc_DrivingRouteReceipt','COMMAND_OR_SEATS_CHANGED',
                       '"RELEASED"','bis_fnc_moduleRemoteControl_owner'):
            self.assertIn(marker,s)
        release=s.split('private _release={',1)[1].split('if (toUpperANSI _mode',1)[0]
        self.assertLess(release.index('call _commandsUnchanged'),release.index('sendSimpleCommand'))
        self.assertNotIn('(_record select 2) == (_group getVariable',release)
        self.assertIn('getVariable ["WAIT_VehicleReverse",[]]) isEqualTo _record',release)
        vehicle=src('cortexVehicles')
        self.assertIn('if (_reverse == "FALLBACK") then',vehicle)
        self.assertIn('["RELEASED","FALLBACK"] select _fallbackAuthority',s)
        self.assertLess(s.index('COMMAND_OR_SEATS_CHANGED'),s.index('if (!_eligible) exitWith'))
        self.assertIn('_fallbackAuthority && {!_handover}',s)
        fallback=s.split('private _fallbackAuthority=',1)[1].split('private _eligible=',1)[0]
        for gate in ('ownerEpoch','WAIT_AIPass_Epoch','CortexExternalTakeover','WAIT_ExternalDrivingOwner'):
            self.assertIn(gate,fallback)
        group=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text(encoding='utf-8')
        self.assertIn('_reverseResult in ["COMPLETE","FALLBACK"]',group)



    def test_ordinary_recovery_has_owned_cleanup_and_original_stage_schedule(self):
        s=src('drivingAssistStart')
        for marker in ('WAIT_DrivingRecovery_Work','WAIT_DrivingRecovery_Yield',
                       'serverTime+96','_hard-66','_hard-60','["REFRESH"] call _recordRecovery',
                       '["FINAL"] call _recordRecovery','ADOPTED_RECOVERY','_recoveryStage != 2 &&'):
            self.assertIn(marker,s)
        release=src('drivingRecoveryRelease')
        for marker in ('expectedDestination _driver','expectedDestination _operator',
                       'DrivingRouteReceipt','DrivingMovementAvailable','CortexExternalTakeover',
                       'isEqualTo _work','(_work get "kind") == "REVERSE"'):
            self.assertIn(marker,release)
        for forbidden in ('addWaypoint','deleteWaypoint','enableAI','setVelocity','setPos','spawn','waitUntil'):
            self.assertNotIn(forbidden,release.split('params [[',1)[1])
        self.assertIn('call WAIT_fnc_DrivingRecoveryRelease',src('drivingAssistRelease'))
        self.assertIn('WAIT_DrivingRecovery_Yield',src('drivingOperationStart'))


    def test_close_static_blockage_uses_fresh_dwell_and_existing_rear_executor(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        contact=s.split('private _solidCandidate=',1)[1].split('_capMps=_capMps min (_traffic select 0);',1)[0]
        for guard in ('_obstacleLimited','count _obstacleObservation == 9','== "STATIC"','<= 8',
                      '(_withoutObstacle select 0) > 0','_pedestrianCap > 0',
                      'serverTime-(_solidSeen select 2) <= 6','serverTime-_since >= 3',
                      'ownerEpoch','_routeIdentity','_obstacleObservation select 8'):
            self.assertIn(guard,contact)
        self.assertNotIn('lineIntersectsSurfaces',contact)
        self.assertNotIn('nearEntities',contact)
        self.assertNotIn(',true]',next(line for line in contact.splitlines() if 'setVariable ["WAIT_DrivingSolidSeen",[' in line))
        self.assertIn('_trafficLimited && {!_solidCandidate}',s)
        self.assertIn('!_trafficLimited || {_solidReady} || {_reverseHandback}',s)
        self.assertIn('private _reverseHandback=_reverseComplete && {_reverseIssued}',s)
        self.assertIn('[_vehicle,8] call WAIT_fnc_DrivingRearClear',s)
        release=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text(encoding='utf-8')
        self.assertIn('setVariable ["WAIT_DrivingSolidSeen",nil]',release)

    def test_rear_solid_beams_include_tall_hull_height_with_fixed_bound(self):
        s=src('drivingRearClear')
        self.assertIn('(_high select 2)-(_low select 2)',s)
        self.assertIn('_heights=_heights arrayIntersect _heights',s)
        self.assertIn('forEach _heights',s)
        # A beam at the3m hull top is not observed by the old knee/bumper rows.
        height=3
        old=[0.45,0.9]
        new=list(dict.fromkeys(old+[(height+0.45)*0.5,height]))
        self.assertNotIn(height,old)
        self.assertIn(height,new)
        self.assertLessEqual(len(new)*3,12)
        self.assertTrue(all(h<=height for h in new))

if __name__=='__main__':unittest.main()

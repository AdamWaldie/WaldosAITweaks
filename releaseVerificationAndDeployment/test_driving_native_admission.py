"""Alternate-path native task ownership gates; not engine movement acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class NativeAdmissionTests(unittest.TestCase):
    def test_both_seats_require_idle_or_route_matching_move_before_acquisition(self):
        for name in ('drivingBypassStep','drivingCorridorStep'):
            source=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            helper=source.split('private _nativeAdmissionReady={',1)[1].split('};',1)[0]
            for marker in ('[_driver,_operator] findIf','toUpperANSI currentCommand _x','_command != ""',
                           '_command != "MOVE"','expectedDestination _x','vectorDistance _destination > 3'):
                self.assertIn(marker,helper)
            self.assertGreaterEqual(source.count('call _nativeAdmissionReady'),2)
            self.assertEqual(source.count('setDriveOnPath'),1)
    def test_ordinary_recovery_preserves_individual_seat_reservations(self):
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        helper=assist.split('private _nativeTaskFree={',1)[1].split('private _routeIdentity=',1)[0]
        self.assertIn('!([_actor] call WAIT_fnc_CortexActorMoveReserved)',helper)
        for seat in ['_driver','_movementOperator']:
            self.assertGreaterEqual(assist.count(f'[{seat}] call _nativeTaskFree'),2)
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        guard=release.split('} forEach [_driver,_operator];',1)[0]
        self.assertIn('!([_x] call WAIT_fnc_CortexActorMoveReserved)',guard)
        self.assertLess(release.index('WAIT_fnc_CortexActorMoveReserved'),release.index('doStop _driver'))
        self.assertNotIn('setVariable ["WAIT_Cortex_ActorMove",nil]',release)

    def test_alternate_paths_preserve_seat_reservations_during_execution_and_cleanup(self):
        for name,helper in [('drivingBypassStep','_seatsAvailable'),('drivingCorridorStep','_crewReady')]:
            text=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            readiness=text.split(f'private {helper}={{',1)[1].split('} < 0',1)[0]
            self.assertIn('[_driver,_operator] findIf',readiness)
            self.assertIn('[_x] call WAIT_fnc_CortexActorMoveReserved',readiness)
            writer=text.split('private _mayWrite={',1)[1].split('};',1)[0]
            self.assertIn(f'call {helper}',writer)
        for name,actor in [('drivingBypassRelease','_x'),('drivingCorridorRelease','_actor')]:
            text=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            self.assertLess(text.index(f'!([{actor}] call WAIT_fnc_CortexActorMoveReserved)'),text.index('doStop _driver'))
            self.assertNotIn('setVariable ["WAIT_Cortex_ActorMove",nil]',text)

    def test_recovery_admission_and_handback_both_preserve_all_trigger_links(self):
        assist=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        admission=assist.split('private _recoveryOrderFree = {',1)[1].split('private _mayRecoverRoute',1)[0]
        release=(ROOT/'addons/vehicles/functions/drivingRecoveryRelease.sqf').read_text(encoding='utf-8')
        for text in [admission,release]:
            self.assertIn('(synchronizedTriggers _waypoint) isEqualTo []',text)
            self.assertIn('(synchronizedWaypoints _waypoint) isEqualTo []',text)
        self.assertNotIn('triggerActivated',admission)

    def test_pre_path_rechecks_do_not_reject_fixed_path_owned_stop(self):
        bypass=(ROOT/'addons/vehicles/functions/drivingBypassStep.sqf').read_text(encoding='utf-8')
        self.assertIn('(_work get "phase") == "PLAN"} && {!(call _nativeAdmissionReady)',bypass)
        corridor=(ROOT/'addons/vehicles/functions/drivingCorridorStep.sqf').read_text(encoding='utf-8')
        self.assertIn('(_work getOrDefault ["phase",""]) == "APPROACH"',corridor)
        self.assertIn('call _mayWrite} && {call _approachTasksReady}',corridor)
        for name in ('drivingBypassRelease','drivingCorridorRelease'):
            source=(ROOT/f'addons/vehicles/functions/{name}.sqf').read_text(encoding='utf-8')
            self.assertNotIn('call _nativeAdmissionReady',source)
if __name__=='__main__': unittest.main()

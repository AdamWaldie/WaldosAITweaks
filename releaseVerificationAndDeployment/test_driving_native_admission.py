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
                           '_command != "MOVE"','expectedDestination _x','distance2D _destination > 3'):
                self.assertIn(marker,helper)
            self.assertGreaterEqual(source.count('call _nativeAdmissionReady'),2)
            self.assertEqual(source.count('setDriveOnPath'),1)
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

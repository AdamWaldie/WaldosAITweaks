"""Admission refusal must preserve the previous task; static contracts, not path proof."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class GarrisonPreflightTests(unittest.TestCase):
    def test_candidate_validation_precedes_cleanup_and_publication(self):
        s=(ROOT/'addons/infantry/functions/cortexGarrison.sqf').read_text(encoding='utf-8')
        cleanup=s.index('call WAIT_fnc_CortexReleaseGroup')
        for guard in ('!finite _radius','count _units > 64','count _buildings > 64','_positionsSeen > 512','!surfaceIsWater _position','WAIT_fnc_PositionBucketAdmit','INVALID_OR_OVER_BUDGET_PLAN'):
            self.assertLess(s.index(guard),cleanup)
        self.assertLess(cleanup,s.index('setVariable ["WAIT_Cortex_GarrisonCandidates"'))
        self.assertEqual(s.count('nearestObjects'),1)
    def test_server_rejects_nonfinite_parameters_before_pending_requests(self):
        s=(ROOT/'addons/infantry/functions/cortexOrderDispatch.sqf').read_text(encoding='utf-8')
        for value in ('_radius','_facing','_width'):
            self.assertLess(s.index('!finite '+value),s.index('_pending set [_token'))
        self.assertIn('!finite _x',s)
if __name__=='__main__': unittest.main()

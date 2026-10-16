"""Owner/deadline/coverage contracts for garrison refill; live occupation remains pending."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class GarrisonRefillTests(unittest.TestCase):
    def test_refill_is_settled_bounded_owner_local_and_preserves_exit_cover(self):
        s=(ROOT/'addons/infantry/functions/cortexGarrisonRefill.sqf').read_text()
        for guard in ('isRemoteExecuted','local _group','CortexIsEligible','CortexExternalTakeover','GarrisonPending','count _members > 64','select [0,64]','Garrison_BreakFraction','_reservation','remoteControlled','GarrisonDisabledPath','_other param [6,[]]','GarrisonApplied','GarrisonRoster','!(_actor in _roster)'):
            self.assertIn(guard,s)
        self.assertIn('currentCommand _actor in ["MOVE","FOLLOW"',s)
        self.assertIn('call WAIT_fnc_CortexGarrisonApplyLocal',s)
        self.assertNotIn('setPosATL',s)
        self.assertNotIn('call WAIT_fnc_CortexGarrison;',s)
    def test_pending_marker_is_updated_by_existing_job_and_cleared_on_release(self):
        apply=(ROOT/'addons/infantry/functions/cortexGarrisonApplyLocal.sqf').read_text()
        self.assertIn('setVariable ["WAIT_Cortex_GarrisonPending",-1,true]',apply)
        self.assertIn('setVariable ["WAIT_Cortex_GarrisonPending",_pending,true]',apply)
        release=(ROOT/'addons/infantry/functions/cortexGarrisonRelease.sqf').read_text()
        self.assertIn('setVariable ["WAIT_Cortex_GarrisonPending",nil,true]',release)
        self.assertIn('setVariable ["WAIT_Cortex_GarrisonRefill",nil,true]',release)
    def test_refill_preserves_real_held_posts_and_requires_physical_exit_cover(self):
        apply=(ROOT/'addons/infantry/functions/cortexGarrisonApplyLocal.sqf').read_text()
        self.assertIn('private _heldInPlace=',apply)
        self.assertIn('!(_unit checkAIFeature "PATH")',apply)
        self.assertIn('&& {!_heldInPlace}) then {_unit enableAI "PATH"}',apply)
        self.assertIn('if (!_heldInPlace && {[_unit] call _mayIssueMovement}) then {doStop _unit}',apply)
        refill=(ROOT/'addons/infantry/functions/cortexGarrisonRefill.sqf').read_text()
        self.assertIn('[_actor,_assignment] call WAIT_fnc_CortexGarrisonArrived',refill)
        self.assertIn('[_x,_other] call WAIT_fnc_CortexGarrisonArrived',refill)
        physical=(ROOT/'addons/infantry/functions/cortexGarrisonArrived.sqf').read_text(encoding='utf-8')
        for guard in ('> 0.75','_outside','terrainIntersectASL','lineIntersectsSurfaces','VIEW'):
            self.assertIn(guard,physical)
        self.assertIn('!(_x checkAIFeature "PATH")',refill)
if __name__=='__main__': unittest.main()

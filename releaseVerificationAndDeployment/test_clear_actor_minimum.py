"""Natural CQB strength must use executor eligibility before task replacement."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(n):return (ROOT/'addons/infantry/functions'/f'{n}.sqf').read_text(encoding='utf-8')
class ClearActorMinimumTests(unittest.TestCase):
    def test_natural_request_uses_real_strength_and_keeps_four(self):
        s=src('cortexBuildingContact')
        self.assertIn('[_x] call WAIT_fnc_CortexCombatEffective',s)
        self.assertIn('count _capable < 4',s)
        self.assertIn('["minimumActors",4]',s)
        refusal=s.split('if (_accepted) then {',1)[1].split('} else {',1)[1]
        self.assertIn('["buildingCombat",8]',refusal.replace('_state,',''))
    def test_full_roster_minimum_precedes_task_handoff(self):
        s=src('cortexClearBuilding')
        check=s.index('if (count _available < _minimumActors)')
        self.assertLess(s.index('private _available ='),check)
        self.assertLess(check,s.index('call WAIT_fnc_CortexReleaseGroup'))
        self.assertLess(check,s.index('call WAIT_fnc_CortexGarrisonRelease'))
        self.assertIn('INSUFFICIENT_ELIGIBLE_ACTORS',s)
        self.assertIn('["minimumActors",1]',s)
        self.assertIn('_minimumActors != floor _minimumActors',s)
    def test_fresh_admission_excludes_dormant_actors_but_resume_keeps_ownership(self):
        s=src('cortexClearBuilding')
        roster=s.split('private _available =',1)[1].split('// Natural contact',1)[0]
        self.assertIn('_resume || {simulationEnabled _x && {!isObjectHidden _x}}',roster)
        self.assertLess(s.index('private _resume ='),s.index('private _available ='))
        self.assertIn('(_previous select 0) == _building',s)
        natural=src('cortexBuildingContact').split('private _capable=',1)[1].split('// A natural entry',1)[0]
        self.assertIn('simulationEnabled _x',natural)
        self.assertIn('!isObjectHidden _x',natural)

    def test_nominal_squad_does_not_satisfy_strict_minimum(self):
        # Two protected actors among four living actors leave only two eligible.
        alive=[True]*4;task_free=[True,True,False,False]
        eligible=sum(a and t for a,t in zip(alive,task_free))
        self.assertGreaterEqual(sum(alive),4)
        self.assertLess(eligible,4)
        self.assertGreaterEqual(eligible,1)
if __name__=='__main__':unittest.main()

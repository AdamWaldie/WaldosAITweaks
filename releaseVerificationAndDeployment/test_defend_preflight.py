"""Defence refusal must precede destructive task replacement; offline contracts only."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DefendPreflightTests(unittest.TestCase):
    def test_complete_layout_is_validated_before_releasing_or_writing(self):
        s=(ROOT/'addons/infantry/functions/cortexDefend.sqf').read_text()
        gate=s.index('if (!_layoutValid')
        self.assertLess(gate,s.index('call WAIT_fnc_CortexReleaseGroup'))
        self.assertLess(gate,s.index('setVariable ["WAIT_AIPass_DefendPos"'))
        self.assertIn('count _placements != count _units',s)
        for required in ('!finite _width','count _units > 64','!surfaceIsWater _position','distance2D _position < 1','_layoutValid=false','CortexExternalTakeover'):
            self.assertIn(required,s)
        self.assertIn('[_slot, _threat, 8, _taken, _group] call WAIT_fnc_CortexFindCover',s)
if __name__=='__main__': unittest.main()

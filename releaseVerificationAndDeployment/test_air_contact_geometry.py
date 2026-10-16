"""AA route knowledge boundary; static contracts are not physical acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AirContactGeometryTests(unittest.TestCase):
    def test_aa_geometry_keeps_native_report_instead_of_live_object_pose(self):
        source=(ROOT/'addons/aircraft/functions/cortexAirAttackPlan.sqf').read_text(encoding='utf-8')
        block=source.split('private _aaPositions=[];',1)[1].split('private _airPos=',1)[0]
        self.assertIn('select [0,16]',block)
        self.assertIn('_x param [0,[],[[]]]',block)
        self.assertIn('count _reportedPosition == 3',block)
        self.assertIn('!(_x isEqualType 0) || {!(finite _x)}',block)
        self.assertIn('if (_validReport &&',block)
        self.assertIn('_aaPositions pushBack (+_reportedPosition)',block)
        self.assertNotIn('getPos',block)
        self.assertNotIn('getHideFrom',block)
        self.assertEqual(block.count('nearTargets'),1)
if __name__=='__main__': unittest.main()

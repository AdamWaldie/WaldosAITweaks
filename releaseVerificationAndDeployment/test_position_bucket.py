"""Spatial-index distance/neighbor invariants; engine performance remains unmeasured."""
from pathlib import Path
import itertools,math,random,unittest
ROOT=Path(__file__).resolve().parents[1]
class PositionBucketTests(unittest.TestCase):
    def test_neighbor_grid_matches_exact_greedy_filter_across_boundaries(self):
        rng=random.Random(92)
        points=[(-1,0,0),(-0.99,0,0),(0,0,0),(0,0,3),(0.5,0,0),(1,0,0)]
        points += [tuple(rng.uniform(-8,8) for _ in range(3)) for _ in range(450)]
        for separation in (0.5,1):
            grid={}; accepted=[]; baseline=[]
            for point in points:
                cell=tuple(math.floor(v/separation) for v in point)
                nearby=[prior for offset in itertools.product((-1,0,1),repeat=3)
                        for prior in grid.get(tuple(a+b for a,b in zip(cell,offset)),[])]
                if not any(math.dist(point,prior)<separation for prior in nearby):
                    grid.setdefault(cell,[]).append(point);accepted.append(point)
                if not any(math.dist(point,prior)<separation for prior in baseline):baseline.append(point)
            self.assertEqual(accepted,baseline)
            self.assertTrue(all(len(bucket)<=8 for bucket in grid.values()))
    def test_production_uses_bounded_cells_and_absolute_coordinates(self):
        helper=(ROOT/'addons/core/functions/positionBucketAdmit.sqf').read_text(encoding='utf-8')
        for marker in ('from -1 to 1','count _near > 8','vectorDistance _position < _separation','count _grid >= 512','floor (_x/_separation)'):
            self.assertIn(marker,helper)
        self.assertEqual(helper.count('_x toFixed 0'),2)
        for name,grid,spacing in [('cortexGarrison','_taken','1'),('cortexClearBuilding','_seenPositions','0.5')]:
            source=(ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text(encoding='utf-8')
            self.assertIn(f'[AGLToASL _position,{grid},{spacing}] call WAIT_fnc_PositionBucketAdmit',source)
if __name__=='__main__': unittest.main()

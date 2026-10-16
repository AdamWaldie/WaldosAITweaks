"""Full direct-fire corridor contracts and analytic envelope checks, not engine acceptance."""
from pathlib import Path
import math
import unittest
ROOT=Path(__file__).resolve().parents[1]
class FireCorridorTests(unittest.TestCase):
    def test_query_covers_segment_and_includes_mounted_people_with_finite_budget(self):
        source=(ROOT/'addons/infantry/functions/cortexLineOfFireClear.sqf').read_text(encoding='utf-8')
        code=source.split('params [[',1)[1]
        for marker in ('count _target != 3','!(finite _x)','_length > 6000','_length < 0.1',
                       '_from vectorAdd _target','_horizontalLength*0.5+_coneWidth+10',
                       '_angle,true,-1','nearEntities [["CAManBase","LandVehicle"],false,true,true]',
                       'count _candidates > 64','vehicle _other == _platform'):
            self.assertIn(marker,code)
        self.assertEqual(code.count('nearEntities'),1)
        self.assertNotIn('min 600',code)
        self.assertLess(code.index('count _candidates > 64'),code.index('_candidates findIf'))
        for forbidden in ('doFire','doSuppressiveFire','setVariable','spawn','waitUntil'):
            self.assertNotIn(forbidden,code)
    def test_long_range_and_steep_cone_positions_fit_horizontal_query_envelope(self):
        # Native query is an envelope, not a replacement for the final 3D projection.
        # The old 600 m sphere omitted this protected person near a 1200 m target.
        self.assertGreater(math.dist((0,0,0),(0,1100,1)),600)
        for elevation in (0,30,75,90):
            angle=math.radians(elevation)
            length=1200
            axis=(0,math.cos(angle),math.sin(angle))
            perpendicular=(0,-math.sin(angle),math.cos(angle))
            width=2+(length+10)*0.087
            centre_y=length*axis[1]/2
            half_y=length*axis[1]/2+width+10
            for along in (2.1,600,1209.9):
                radial=(2+along*0.087)*0.999
                for sign in (-1,1):
                    position=tuple(along*a+sign*radial*p for a,p in zip(axis,perpendicular))
                    self.assertLessEqual(abs(position[0]),width)
                    self.assertLessEqual(abs(position[1]-centre_y),half_y)
if __name__=='__main__': unittest.main()

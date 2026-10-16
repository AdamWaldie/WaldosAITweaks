"""Measured reverse sweep regressions; no SQF/physics/performance acceptance."""
import math
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

def pose(speed,yaw,t,x,y):
    a=yaw*t
    return (-speed*(1-math.cos(a))/yaw+x*math.cos(a)+y*math.sin(a),
            -speed*math.sin(a)/yaw-x*math.sin(a)+y*math.cos(a))

class ReverseTurnTests(unittest.TestCase):
    def test_front_corner_swing_is_outside_straight_rear_strip(self):
        x,y=pose(1,0.2,2,1.5,4)
        self.assertGreater(x,1.8)
        self.assertGreater(y,0)
        # The old strip only examined y<=rear+0.5 (rear=-4 here).
        self.assertGreater(y,-3.5)

    def test_mirrored_turns_and_conservative_rotation_bound(self):
        for angle in (3,10,35,70):
            yaw=math.radians(angle)/2
            right=pose(2,yaw,2,1.5,4)
            left=pose(2,-yaw,2,-1.5,4)
            self.assertAlmostEqual(right[0],-left[0])
            self.assertAlmostEqual(right[1],left[1])
            bound=2*math.hypot(1.5,4)*math.sin(math.radians(angle)/2)
            rotated=(1.5*math.cos(yaw*2)+4*math.sin(yaw*2),
                     -1.5*math.sin(yaw*2)+4*math.cos(yaw*2))
            self.assertLessEqual(math.dist(rotated,(1.5,4)),bound+1e-10)

    def test_turn_envelope_includes_centre_translation_and_all_corners(self):
        for speed in (0.3,2,15):
            for degrees in (-70,-35,-3,3,35,70):
                yaw=math.radians(degrees)/2
                distance=speed*2
                rotation=2*math.hypot(1.8,4)*math.sin(abs(yaw))
                centre=speed*(1-math.cos(yaw*2))/abs(yaw)
                swing=rotation+centre
                for step in range(21):
                    for x in (-1.8,1.8):
                        for y in (-4,4):
                            px,py=pose(speed,yaw,step/10,x,y)
                            self.assertLessEqual(abs(px),1.8+swing+1e-9)
                            self.assertGreaterEqual(py,-4-distance-swing-1e-9)
                            self.assertLessEqual(py,4+swing+1e-9)

    def test_existing_observer_retains_straight_checks_and_bounds_work(self):
        s=(ROOT/'addons/vehicles/functions/drivingRearClear.sqf').read_text()
        self.assertIn('REAR_TURN_ENVELOPE',s)
        self.assertIn('for "_segment" from 1 to 3',s)
        self.assertIn('_actorRadius+35*_predictionSeconds',s)
        self.assertIn('_rear-_distance,_height',s)
        self.assertEqual(s.count('nearEntities'),2)
        self.assertNotIn('setVelocity',s)
        self.assertNotIn('doMove',s)

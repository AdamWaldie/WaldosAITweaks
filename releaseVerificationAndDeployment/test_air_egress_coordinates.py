"""Air egress coordinate contract; mathematical example is not engine acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AirEgressTests(unittest.TestCase):
    def test_world_velocity_uses_absolute_target_and_aircraft_displacement(self):
        source=(ROOT/'addons/aircraft/functions/cortexAirAttack.sqf').read_text()
        self.assertIn('_job set ["lastTargetPositionASL",getPosASL _target]',source)
        egress=source.split('private _awayFromTarget=',1)[1].split('// Fast fixed-wing',1)[0]
        self.assertIn('velocity _aircraft',egress)
        self.assertIn('getPosASL _aircraft',egress)
        self.assertIn('lastTargetPositionASL',egress)
        self.assertNotIn('getPosATL',egress)
    def test_terrain_relative_heights_can_invert_departure_sign(self):
        velocity=(0,100,20)
        # Same aircraft/target world poses, but terrain rises by 1000 m beneath the aircraft.
        absolute_delta=(0,100,100)
        relative_delta=(0,100,-900)
        self.assertGreater(sum(v*d for v,d in zip(velocity,absolute_delta)),0)
        self.assertLess(sum(v*d for v,d in zip(velocity,relative_delta)),0)
if __name__=='__main__': unittest.main()

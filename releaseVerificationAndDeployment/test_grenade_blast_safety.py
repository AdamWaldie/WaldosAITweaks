"""Selected-ammo grenade safety contracts; physical blast/fragment behaviour is unverified."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class GrenadeBlastSafetyTests(unittest.TestCase):
    def test_selected_ammo_is_checked_before_queue_and_again_at_release(self):
        s=(ROOT/'addons/infantry/functions/cortexThrowGrenade.sqf').read_text(encoding='utf-8')
        self.assertEqual(s.count('12 max (4*_blastRange)'),2)
        self.assertEqual(s.count('nearEntities ["CAManBase",_safetyRadius]'),2)
        self.assertLess(s.index('_muzzleIndex=-1'),s.index('private _release ='))
        release=s.split('private _unsafeRelease=false;',1)[1].split('"ALIGNED"',1)[0]
        for guard in ('_releaseAmmo','!isClass _releaseConfig','!finite _blastRange','_blastRange < 0','_distance <= _safetyRadius','_distance > 40','UNSAFE_RELEASE'):
            self.assertIn(guard,release)
    def test_radius_expands_without_shrinking_existing_floor(self):
        radius=lambda base:max(12,4*base)
        self.assertEqual(radius(0),12)
        self.assertEqual(radius(3),12)
        self.assertEqual(radius(6),24)
        self.assertEqual(radius(10),40)
if __name__=='__main__': unittest.main()

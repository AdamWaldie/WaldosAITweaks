"""Explicit scenario placement must stay outside recurring physical garrison recovery."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class GarrisonPlacementTests(unittest.TestCase):
    def test_teleport_is_opt_in_and_validated_before_releasing_orders(self):
        source=(ROOT/'addons/infantry/functions/cortexGarrison.sqf').read_text()
        self.assertIn('_options getOrDefault ["teleport",false]',source)
        self.assertIn('_teleport && {_inPlace}',source)
        self.assertLess(source.index('_teleport isEqualType true'),source.index('call WAIT_fnc_CortexReleaseGroup'))
        placement=source.split('if (_teleport) then {',1)[1].split('forEach _units;',1)[0]
        for guard in ('local _group','local _unit','CortexExternalTakeover','CortexCombatEffective','_free','remoteControlled','objectParent','currentCommand','getPosWorld _building'):
            self.assertIn(guard,placement)
        self.assertIn('_unit setPosATL (_assignment select 0)',placement)
    def test_adoption_and_clearance_do_not_inherit_instant_placement(self):
        apply=(ROOT/'addons/infantry/functions/cortexGarrisonApplyLocal.sqf').read_text()
        self.assertNotIn('setPosATL',apply)
        clear=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text()
        self.assertNotIn('GarrisonPlacement',clear)
        self.assertNotIn('setPosATL',clear)
if __name__=='__main__': unittest.main()

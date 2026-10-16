"""Shared belief selection must not manufacture indoor knowledge or movement."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class BuildingContactSelectTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.s=(ROOT/'addons/infantry/functions/buildingContactSelect.sqf').read_text()
    def test_nearest_roof_owner_and_strict_horizontal_bounds(self):
        for marker in ('private _nearest=_hits select 0','(_nearest select 2) == _building',
                       '(_nearest select 3) == _building',
                       '(_model select 0) >= (_low select 0)',
                       '(_model select 1) <= (_high select 1)'):
            self.assertIn(marker,self.s)
        self.assertNotIn('_hits findIf',self.s)
    def test_only_fresh_hostile_infantry_beliefs_with_bounded_queries(self):
        for marker in ('local _group','_age <= 5','_age >= 0','finite _distance',
                       '_distance >= 0','_distance <= _range','_range min 1000',
                       '_enemy isKindOf "CAManBase"','getFriend (side _enemy) < 0.6',
                       '_records resize 3','!(_x isEqualType [])'):
            self.assertIn(marker,self.s)
        self.assertEqual(self.s.count('lineIntersectsSurfaces'),1)
        self.assertLess(self.s.index('_records resize 3'),self.s.index('lineIntersectsSurfaces'))
        for forbidden in ('getPosATL _enemy','getPosASL _enemy','getPosWorld _enemy',
                          ' doMove ','doFollow','reveal','CortexQueueJob','_cleared pushBack'):
            self.assertNotIn(forbidden,self.s)
    def test_whole_group_admission_still_requires_real_four_and_calls_shared_selector(self):
        caller=(ROOT/'addons/infantry/functions/cortexBuildingContact.sqf').read_text()
        self.assertIn('count _capable < 4',caller)
        self.assertIn('["minimumActors",4]',caller)
        self.assertIn('[_group,_enemies,_range] call WAIT_fnc_BuildingContactSelect',caller)
        self.assertLess(caller.index('count _capable < 4'),caller.index('call WAIT_fnc_BuildingContactSelect'))
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text()
        self.assertIn('class BuildingContactSelect {file =',functions)

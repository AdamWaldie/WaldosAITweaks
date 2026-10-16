"""Exterior geometry input contracts; not native path/coverage proof."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ExteriorPreflightTests(unittest.TestCase):
    def test_all_coordinate_sets_are_finite_and_bounded_before_geometry(self):
        s=(ROOT/'addons/infantry/functions/buildingExteriorCandidate.sqf').read_text(encoding='utf-8')
        gate=s.index('if (isNull _actor ||')
        end=s.index('private _bounds=',gate)
        preflight=s[gate:end]
        self.assertIn('!finite _x',s[:gate])
        for marker in ('[_target] call _positionValid','[_entry] call _positionValid',
                       '[_watch] call _positionValid','count _entries > 64','count _taken > 128',
                       'count _observerLanes > 64','_entries findIf','_taken findIf',
                       '[_x select 0] call _positionValid','[_x select 1] call _positionValid'):
            self.assertIn(marker,preflight)
        for query in ('boundingBoxReal','worldToModel','terrainIntersectASL','lineIntersectsSurfaces','nearEntities'):
            self.assertGreater(s.index(query),end)
        self.assertIn('[false,[["inputs",false]]]',preflight)
    def test_lane_calculations_only_consume_validated_endpoints(self):
        s=(ROOT/'addons/infantry/functions/buildingExteriorCandidate.sqf').read_text(encoding='utf-8')
        self.assertEqual(s.count('private _positionValid='),1)
        self.assertNotIn('exitWith {true}',s.split('private _laneBlocked=',1)[1])
        self.assertIn('_observerLanes findIf',s.split('private _laneBlocked=',1)[1])
if __name__=='__main__':unittest.main()

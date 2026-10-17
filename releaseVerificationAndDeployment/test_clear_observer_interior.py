"""Interior receipt contracts; not physical entry or hostile-room safety."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class ClearObserverInteriorTests(unittest.TestCase):
    def test_exterior_and_foreign_roof_cannot_grant_a_visit(self):
        def receipt(inside,roof_hits,segment_hits):
            return inside and bool(roof_hits) and roof_hits[0]=="target" and not segment_hits
        self.assertFalse(receipt(False,["target"],[]))
        self.assertFalse(receipt(True,[],[]))
        self.assertFalse(receipt(True,["neighbor","target"],[]))
        self.assertFalse(receipt(True,["target"],["neighbor-wall"]))
        self.assertFalse(receipt(True,["target"],["prop"]))
        self.assertTrue(receipt(True,["target"],[]))

    def test_actual_observer_and_segment_share_existing_budget(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        observer=s.split('private _observerInside={',1)[1].split('private _roomSegmentClear=',1)[0]
        for evidence in ('getPosASL _actor','worldToModel (getPosATL _actor)',
                         '_roomGeometryBudget <= 0','_roomGeometryBudget=_roomGeometryBudget-1',
                         '_roof select 0','_interiorObservers set [_key,_ownedRoof]'):
            self.assertIn(evidence,observer)
        visit=s.split('private _atPosition=_actual vectorDistance',1)[1].split('if (_atPosition)',1)[0]
        self.assertIn('[_visitor] call _observerInside',visit)
        self.assertIn('call _roomSegmentClear',visit)
        self.assertIn('private _clear=_hits isEqualTo [];',s)
        self.assertEqual(s.count('_job set ["roomGeometryChecksLast",0]'),1)
        self.assertLess(s.index('_job set ["roomGeometryChecksLast",0]'),s.index('private _observerInside='))

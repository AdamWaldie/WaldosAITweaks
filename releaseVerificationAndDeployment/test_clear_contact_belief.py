"""Initial belief-based CQB planning contracts; not physical clearance acceptance."""
from pathlib import Path
import math,unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name):return next((ROOT/'addons').rglob(name+'.sqf')).read_text(encoding='utf-8')
class ClearContactBeliefTests(unittest.TestCase):
    def test_native_snapshot_reaches_admission_and_durable_progress(self):
        contact=source('cortexBuildingContact');start=source('cortexClearBuilding');step=source('buildingOperationStep')
        self.assertIn('call WAIT_fnc_BuildingContactSelect',contact)
        self.assertIn('[+_belief,serverTime-(_x select 2)]',source('buildingContactSelect'))
        self.assertIn('["contactBelief",_contactBelief]',contact)
        self.assertIn('_previous param [11,[],[[]]]',start)
        for check in ('!finite _x','finite (_contactBelief select 1)',
                      'serverTime-(_contactBelief select 1) >= 0',
                      'serverTime-(_contactBelief select 1) <= 5',
                      'worldToModelVisual (_contactBelief select 0)'):
            self.assertIn(check,start)
        self.assertIn('_nativeOrderReceipt, _hardDeadline, _contactBelief, _continueRoute], true]',start)
        self.assertIn('_job getOrDefault ["contactBelief",[]]',step)
        self.assertIn('["contactBelief",_contactBelief]',start)
    def test_hint_only_seeds_once_and_does_not_replace_physical_completion(self):
        start=source('cortexClearBuilding')
        plan=start.split('private _routeOrder=[];',1)[1].split('private _pairs=',1)[0]
        self.assertIn('!_beliefSeeded',plan)
        self.assertIn('_beliefSeeded=true',plan)
        self.assertIn('_selectionOrigin=_contactBelief select 0',plan)
        self.assertIn('_selectionOrigin=_routeCursor',plan)
        self.assertIn('_positionHeights=_positions apply {(AGLToASL _x) select 2}',plan)
        self.assertNotIn('_cleared pushBack',plan)
        for forbidden in ('getPosATL _enemy','getPosASL _enemy','setPos','reveal'):
            self.assertNotIn(forbidden,plan)
    def test_height_conversion_work_is_linear_not_repeated_per_remaining_node(self):
        plan=source('cortexClearBuilding').split('private _routeOrder=[];',1)[1].split('private _pairs=',1)[0]
        loop=plan.split('while {_remaining isNotEqualTo []} do {',1)[1]
        self.assertNotIn('AGLToASL',loop)
        self.assertIn('_positionHeights select _x',loop)
        self.assertIn('_beliefHeight',loop)
        self.assertIn('private _retiredIndices=_cleared+_unreachable',plan)
        self.assertNotIn('_cleared+_unreachable',loop)

    def test_reference_route_preserves_floor_order_and_every_node(self):
        def route(points,origin,belief=None):
            remaining=list(range(len(points)));result=[];seeded=False
            while remaining:
                lowest=min(points[i][2] for i in remaining)
                floor=[i for i in remaining if abs(points[i][2]-lowest)<1.8]
                selection=origin
                if not seeded and belief is not None and any(abs(points[i][2]-belief[2])<=1.5 for i in floor):
                    selection=belief;seeded=True
                best=min(floor,key=lambda i:math.dist(selection[:2],points[i][:2]))
                remaining.remove(best);result.append(best);origin=points[best]
            return result
        points=[(0,0,0),(9,0,0),(0,0,4),(9,0,4)]
        self.assertEqual(route(points,(0,-2,0)),[0,1,3,2])
        self.assertEqual(route(points,(0,-2,0),(0,0,4)),[0,1,2,3])
        self.assertEqual(route(points,(0,-2,0),(9,0,0)),[1,0,2,3])
        self.assertEqual(sorted(route(points,(0,-2,0),(9,0,4))),list(range(len(points))))
if __name__=='__main__':unittest.main()

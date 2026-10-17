"""Fixed convoy path handback must retire its own writer without claiming successor orders."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ConvoyPathHandoverTests(unittest.TestCase):
    def test_path_receipt_is_created_only_at_actual_path_write(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        block=s.split('_vehicle setDriveOnPath _path;',1)[1].split('_progress set [6',1)[0]
        for key in ['WAIT_Convoy_PathLease','_group,_revision','WAIT_AIPass_Epoch',
                    'driver _vehicle,_movementOperator','expectedDestination _movementOperator']:
            self.assertIn(key,block)
    def test_release_requires_exact_context_and_keeps_new_native_moves(self):
        s=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        block=s.split('private _pathOwned=',1)[1]
        for guard in ['count _pathLease == 7','_navigation getOrDefault ["revision",-1]',
                      'WAIT_AIPass_Epoch','(_pathLease select 3) == _driver',
                      '(_pathLease select 4) == _movementOperator','isEqualTo (_pathLease select 5)',
                      '!(_vehicle in _keepCrew)','_taskFree','_mayStopOwned && {_pathOwned}',
                      '_live vectorDistance _committed <= 0.25']:
            self.assertIn(guard,block)
        self.assertLess(block.index('doStop _driver'),block.index('_driver doFollow leader _group'))
        for command in ['deleteWaypoint','addWaypoint','enableAI','setPos','setVelocity']:
            self.assertNotIn(command,block)
    def test_on_foot_leader_and_scripted_waypoint_do_not_receive_synthetic_recall(self):
        s=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        recall=s.split('if (_driver != _leader',1)[1]
        self.assertIn('_leaderVehicle != _leader',recall)
        self.assertIn('_leaderVehicle isKindOf "LandVehicle"',recall)
        for guard in ['waypointType _waypoint == "MOVE"','_condition == "true"',
                      'waypointScript _waypoint == ""','waypointTimeout',
                      'synchronizedTriggers','synchronizedWaypoints','waypointAttachedObject']:
            self.assertIn(guard,recall)
        self.assertIn('_movementOperator doMove waypointPosition _waypoint',recall)
        self.assertLess(recall.index('if (_index > 0'),recall.index('waypointStatements _waypoint'))
        self.assertIn('checkAIFeature "MOVE"',s)
        self.assertIn('checkAIFeature "PATH"',s)
if __name__=='__main__': unittest.main()

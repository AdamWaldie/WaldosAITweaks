"""Non-MOVE authored tasks must not strand an exact-owned old clearance leader."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearNativeTaskHandoverTests(unittest.TestCase):
    def test_non_move_leader_releases_native_formation_without_fabricated_route(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        handback=s.split('if (_reason == "NEW_ORDER"',1)[1].split('forEach _handbacks;',1)[0]
        for guard in ('local _group','WAIT_AIPass_Epoch','WAIT_AIPass_ClearGeneration',
                      'currentCommand _actor == _command','_destination vectorDistance _target <= 0.25',
                      'call _actorAvailable','call _actorTaskFree','CortexExternalTakeover',
                      'call WAIT_fnc_NativeOrderReceipt','count (_group getVariable ["WAIT_Operation"'):
            self.assertIn(guard,handback)
        leader=handback.split('if (_actor == leader _group) then {',1)[1]
        self.assertIn('waypointType _waypoint == "MOVE"',leader)
        move,fallback=leader.split('_actor doMove waypointPosition _waypoint;',1)
        self.assertIn('} else {\n                            _actor doFollow leader _group;',fallback)
        for forbidden in ('addWaypoint','deleteWaypoint','setCurrentWaypoint','joinSilent','enableAI'):
            self.assertNotIn(forbidden,handback)

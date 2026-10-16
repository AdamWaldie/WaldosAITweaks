"""Follow-through destination selection must prefer available space over floor proximity."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class FollowThroughOccupancyTests(unittest.TestCase):
    def test_free_other_floor_precedes_blocked_current_floor(self):
        candidates = [(1, 0, 2.0, 3), (0, 1, 7.0, 5)]
        self.assertEqual(min(candidates)[3], 5)
        candidates += [(0, 0, 9.0, 2)]
        self.assertEqual(min(candidates)[3], 2)
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        # Locate the follow-through ranking by its unique reservation snapshot.
        rank = source.split('private _occupied=_followReservations findIf {', 1)[1].split('_ranked sort true;', 1)[0]
        self.assertLess(rank.index('[[0,1] select _occupied'), rank.index('[0,1] select (abs (_unitFloor'))
        self.assertIn('vectorDistance _positionASL < 1.5', rank)

    def test_completed_queue_establishes_yieldable_hold_without_stopping_partner(self):
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        block = source.split('if (_waitingForFloor || {_availableCandidates isEqualTo []}) then {',1)[1].split('if (_candidates isNotEqualTo []) then {',1)[0]
        for gate in ['_waitingForFloor || {_completedWorker}', '>= (2 min count _positions)',
                     'call _actorAvailable', 'call _actorTaskFree', 'call _mayIssueMovement',
                     '!([_waitingActor] call _activeOwnMove)',
                     'currentCommand _waitingActor in ["","STOP","FOLLOW"]',
                     '!(_key in _holds) || {currentCommand _waitingActor != "STOP"}',
                     'private _hold=getPosATL _waitingActor', '_holds set [_key,+_hold]']:
            self.assertIn(gate,block)
        self.assertNotIn('doMove',block)
        self.assertNotIn('doFollow',block)
        self.assertNotIn('set ["deadline"',block)

    def test_yield_preserves_unfinished_visits_ownership_and_deadline(self):
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        block = source.split('if (_ranked isNotEqualTo [] && {((_ranked select 0) select 0) == 1}) then {',1)[1].split('private _index=(_ranked select 0) select 3;',1)[0]
        for gate in ['count (_actorVisits getOrDefault [netId _x,[]]) >= _requiredVisits',
                     'currentCommand _blocker in ["","STOP"]', '!(_x in _needed)',
                     'call _roomSegmentClear', 'call _mayIssueMovement', 'continue;',
                     '_yielded pushBackUnique _blockerKey']:
            self.assertIn(gate, block)
        self.assertNotIn('set ["deadline"',block)
        self.assertNotIn('call WAIT_fnc_RecoveryStep',block)
        self.assertNotIn('_failedTargets pushBack',block)
        self.assertIn('_yieldContext+[+_yielded]',block)
        self.assertIn('(_yieldReceipt select [0,3]) isEqualTo _yieldContext',source)
        arrival=source.split('if (_arrived isNotEqualTo []',1)[1].split('doStop _unit;',1)[0]
        self.assertIn('vectorDistance (AGLToASL (_positions select (_arrived select 0))) <= 1.5',arrival)
        self.assertIn('call _roomSegmentClear',arrival)

if __name__ == '__main__':
    unittest.main()

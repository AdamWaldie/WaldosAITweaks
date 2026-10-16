"""Protect established exit cover during casualty promotion; physical flow unverified."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearPromotionCoverageTests(unittest.TestCase):
    def test_settled_observer_requires_current_physical_substitute(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        gate=s.split('private _mayPromoteReserve=',1)[1].split('private _pairRosterChanged=',1)[0]
        for marker in ('_observer != _candidate','call _reserveReady','isEqualTo _exit',
                       'WAIT_Cortex_ClearExitWatchLocal','vectorDistance (AGLToASL _post) <= 2',
                       '<= 0.75','terrainIntersectASL','"VIEW","NONE"'):
            self.assertIn(marker,gate)
        self.assertIn('if ((_stage param [2,""]) != "ARRIVED") exitWith {true}',gate)
        self.assertIn('_promotionViewBudget=_promotionViewBudget-1',gate)
        self.assertIn('if (_promotionViewBudget <= 0) exitWith {false}',gate)
        self.assertEqual(gate.count('lineIntersectsSurfaces'),1)
        self.assertNotIn('hardDeadline',gate)
    def test_no_candidate_never_falls_through_to_last_reserve(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        self.assertIn('private _replacementIndex=-1',s)
        self.assertIn('[_x] call _mayPromoteReserve',s)
        guard=s.index('if (_replacementIndex < 0) then {continue}')
        self.assertLess(guard,s.index('private _replacement=_reserves deleteAt _replacementIndex'))
        self.assertIn('private _promotionViewBudget=1',s)
        self.assertIn('promotionCandidateCursor',s)
        self.assertIn('!(_candidate in _reserves)',s)
        self.assertIn('_replacementIndex=_reserves find _x',s)
    def test_two_simultaneous_losses_cannot_spend_both_duplicate_observers(self):
        reserves=['a','b'];posts={'a':'exit','b':'exit'}
        def can_promote(candidate):
            return any(other!=candidate and posts[other]==posts[candidate] for other in reserves)
        self.assertTrue(can_promote('a'))
        reserves.remove('a')
        self.assertFalse(can_promote('b'))
    def test_early_exit_worker_can_supply_current_cover_without_becoming_a_reserve(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        pool=s.split('private _promotionObservers=',1)[1].split('private _pairRosterChanged=',1)[0]
        for marker in ('keys _earlyExits select [0,8]', 'pushBackUnique',
                       'promotionObserverCursor', 'forEach _promotionObservers',
                       '_earlyExits getOrDefault [netId _observer,[]]',
                       '(_row param [0,objNull]) == _observer',
                       '(_row param [3,""]) == "ARRIVED"',
                       '[_observer] call _actorAvailable', '[_observer] call _actorTaskFree',
                       '!(_observer in _unavailable)'):
            self.assertIn(marker,pool)
        self.assertEqual(pool.count('lineIntersectsSurfaces'),1)
        self.assertNotIn('doMove',pool)
        self.assertNotIn('doFollow',pool)
        self.assertNotIn('hardDeadline',pool)

if __name__=='__main__':unittest.main()

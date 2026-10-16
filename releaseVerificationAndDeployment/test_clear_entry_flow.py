"""Initial pair support planning must not inherit recovery's unselected lead fallback."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ClearEntryFlowTests(unittest.TestCase):
    def test_provisional_recovery_target_does_not_preempt_distinct_support_selection(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        recovery=s.split('// Partner entry recovery is independent',1)[1].split('private _entryRecovery=',1)[0]
        self.assertIn('_entryTargets getOrDefault',recovery)
        self.assertIn('_job set ["pairEntryTargets",_entryTargets]',recovery)
        self.assertNotIn('_entryTargets set [_entryKey',recovery)
        support=s.split('// Commit both actors at initial entry.',1)[1].split('if (_supportTarget isEqualTo (_positions',1)[0]
        for gate in ('_supportTarget isEqualTo []','distance2D _anchor >= 1.2','_distance >= 2.5','distance2D _anchor <= 8','min 24','lineIntersectsSurfaces'):
            self.assertIn(gate,support)
        self.assertIn('_entryTargets set [_entryKey,+_supportTarget]',support)
    def test_new_destinations_prefer_live_unoccupied_nodes_without_reserving_queue(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        helper=s.split('private _occupiedRoomTargets={',1)[1].split('// Callback-local geometry',1)[0]
        for gate in ('select [0,8]','call _actorAvailable','call _ownsCurrentMove','getPosASL _actor','simulationEnabled','isObjectHidden'):
            self.assertIn(gate,helper)
        self.assertNotIn('doMove',helper)
        claim=s.split('// Prefer free room destinations',1)[1].split('private _point=',1)[0]
        self.assertIn('if (_freeCandidates isNotEqualTo [])',claim)
        self.assertNotIn('deleteAt',claim)
        support=s.split('// Commit both actors at initial entry.',1)[1].split('if (_supportTarget isEqualTo (_positions',1)[0]
        self.assertIn('private _ranked=_freeRanks+_busyRanks',support)
        self.assertIn('if (_supportTarget isEqualTo [])',support)
        # Distinct lead claims alone cannot prevent two buddies choosing the midpoint.
        points=[(0,0),(6,0),(3,0),(3,4)]
        def ranked(anchor,occupied):
            candidates=[p for p in points if 2.5<=sum((p[i]-anchor[i])**2 for i in range(2))**.5<=8]
            return sorted(candidates,key=lambda p:(any(sum((p[i]-q[i])**2 for i in range(2))**.5<2.5 for q in occupied),sum((p[i]-anchor[i])**2 for i in range(2))))
        first=ranked(points[0],[])[0]
        self.assertEqual(first,ranked(points[1],[])[0])
        self.assertNotEqual(first,ranked(points[1],[first,points[0]])[0])
        # Occupancy never makes all native candidates disappear.
        self.assertTrue(ranked(points[1],points))
    def test_entry_and_egress_floor_checks_use_absolute_elevation(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        for target in ('_target','_point','_entryTarget','_accessPoint'):
            self.assertIn('(AGLToASL '+target+') select 2',s)
        self.assertNotIn('abs (((getPosATL _unit) select 2)',s)
        self.assertNotIn('abs (((getPosATL _entryMover) select 2)',s)
        self.assertIn('abs (((AGLToASL _x) select 2)-((AGLToASL _anchor) select 2))',s)
        # Same absolute floor, different terrain cells: old relative-height test rejects it.
        floor=20; terrain_actor=16; terrain_target=18
        self.assertGreater(abs((floor-terrain_actor)-(floor-terrain_target)),1.5)
        self.assertEqual(abs(floor-floor),0)
        # Equal relative heights can conceal genuinely different absolute floors.
        relative_height=1
        self.assertEqual(abs(relative_height-relative_height),0)
        self.assertGreater(abs((terrain_actor+relative_height)-(terrain_target+relative_height)),1.5)
    def test_security_exit_inventory_is_not_truncated_with_interior_entry_choices(self):
        admission=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')
        step=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        self.assertLess(admission.index('_securityEntries=+_entries'),admission.index('_entries resize ((count _entries) min 4)'))
        self.assertIn('["securityEntries",_securityEntries]',admission)
        reserve=step.split('// Distribute observation among real exits',1)[1].split('// Public arrival does not replay',1)[0]
        self.assertEqual(reserve.count('_job getOrDefault ["securityEntries",_job getOrDefault ["entries",[]]]'),3)
        self.assertIn('select [0,16]',reserve)
        # A rear exit must remain selectable even when four closer exits precede it.
        native_exits=[(0,1),(1,1),(2,1),(3,1),(0,20)]
        security=list(native_exits)
        interior=native_exits[:4]
        self.assertNotIn((0,20),interior)
        self.assertIn((0,20),security)
        self.assertEqual(len(interior),4)
    def test_new_security_posts_prefer_angular_spread_without_historical_coverage_credit(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        rank=s.split('// Distribute observation among real exits',1)[1].split('if (_entry isNotEqualTo []',1)[0]
        for gate in ('call _actorAvailable','call _ownsCurrentMove','vectorDistance (AGLToASL','_plannedBearings','-_minimumBearingGap','select 4'):
            self.assertIn(gate,rank)
        self.assertIn('(keys _earlyExits) select [0,8]',rank)
        self.assertIn('_observationReserveKeys select [0,8]',rank)
        self.assertEqual(rank.count('call _actorTaskFree'),2)
        self.assertEqual(rank.count('!(_actor in _rotatedOut)'),2)
        self.assertEqual(rank.count('!(_actor in _unavailable)'),2)
        self.assertNotIn('doMove',rank)
        self.assertNotIn('lineIntersectsSurfaces',rank)
        def gap(a,b):return abs((a-b+540)%360-180)
        self.assertEqual(gap(359,1),2)
        # Both exits are unassigned/untried: opposite face beats a closer adjacent door.
        options=[(0,0,-gap(5,0),4,'front'),(0,0,-gap(180,0),30,'rear')]
        self.assertEqual(min(options)[-1],'rear')
        # Actual failed proposal remains lower priority, despite its attractive bearing.
        options[1]=(1,0,-180,30,'rear')
        self.assertEqual(min(options)[-1],'front')

class ClearReserveFairnessTests(unittest.TestCase):
    def test_exterior_reserve_service_window_does_not_starve_later_actors(self):
        from pathlib import Path
        source=(Path(__file__).resolve().parents[1]/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        assert '"reserveStageCursor"' in source
        assert source.count('} forEach _stageReserves;') == 2
        assert '} forEach (_reserves select [0,8]);' not in source
        # Stable rosters larger than the callback budget must all receive service.
        for count in (9,12,16,24):
            cursor=0
            seen=set()
            for _ in range((count+7)//8):
                roster=list(range(count))
                rotated=roster[cursor:]+roster[:cursor]
                seen.update(rotated[:8])
                cursor=(cursor+8)%count
            assert seen == set(range(count))
        # Small rosters retain their existing whole-roster service without rotation.
        assert list(range(6))[:8] == list(range(6))

class ClearHolderOwnershipTests(unittest.TestCase):
    def test_prior_drill_reunion_retires_successor_owned_holders(self):
        source=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        gate=source.split('private _ownedMovers =',1)[1].split('private _holders =',1)[0]
        for marker in ('if (_ordered)', 'WAIT_OperationGeneration','WAIT_AIPass_Epoch',
                       '"participants",[]','"cancelReason",""','WAIT_Cortex_ClearHold',
                       'WAIT_AIPass_ClearGeneration','call WAIT_fnc_NativeOrderReceipt'):
            self.assertIn(marker,gate)
        self.assertNotIn('doFollow',gate)
        self.assertNotIn('doStop',gate)
        # Old drill ownership transfers to the newer task, not to a deferred recall.
        holders={'old_a','old_b','unclaimed'}
        operation={'old_a'}
        settled={'old_b'}
        remaining=holders-operation-settled
        self.assertEqual(remaining,{'unclaimed'})
        self.assertEqual(holders-holders,set())
        self.assertEqual(holders-set(),holders)

class ClearReplacementOccupancyTests(unittest.TestCase):
    def test_replacement_destinations_use_current_pairs_not_historical_prefix(self):
        source=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        helper=source.split('private _occupiedRoomTargets={',1)[1].split('// Callback-local geometry',1)[0]
        self.assertIn('getOrDefault ["pairs",[]]) select [0,4]',helper)
        self.assertIn('_workers pushBackUnique _x',helper)
        self.assertIn('_workers select [0,8]',helper)
        self.assertNotIn('get "team"',helper)
        # After one casualty, the replacement is ninth in the historical journal.
        historical=list(range(8))+['replacement']
        pairs=[['replacement',1],[2,3],[4,5],[6,7]]
        current=list(dict.fromkeys(actor for pair in pairs[:4] for actor in pair[:2]))[:8]
        self.assertNotIn('replacement',historical[:8])
        self.assertIn('replacement',current)
        self.assertNotIn(0,current)
        self.assertEqual(len(current),8)
        # Replacing both members preserves the same concurrent capacity.
        pairs[0]=['second','third']
        current=list(dict.fromkeys(actor for pair in pairs[:4] for actor in pair[:2]))[:8]
        self.assertEqual(len(current),8)
        self.assertEqual(current[:2],['second','third'])

if __name__=='__main__': unittest.main()

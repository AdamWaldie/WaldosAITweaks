"""Bounded egress planning must preserve physical completion and migration semantics."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

class ClearEgressBatchingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.step = (ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        cls.start = (ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text()

    def test_transition_does_not_search_or_command_pending_workers(self):
        transition = self.step.split('// Defer expensive exterior planning;',1)[1].split('private _phase=toUpperANSI',1)[0]
        for forbidden in ('call _chooseExteriorExit', ' doMove ', 'getPosATL _unit;'):
            self.assertNotIn(forbidden, transition)
        self.assertIn('_pending pushBack [_unit,+(_moves getOrDefault', transition)
        self.assertIn('"egressDeadlineServer",serverTime+45', transition)

    def test_one_allocation_still_services_existing_travel_and_pending_blocks_success(self):
        block = self.step.split('// End exterior planner;',1)[1].split('private _reserveReady=',1)[0]
        self.assertEqual(block.count('call _chooseExteriorExit'),1)
        self.assertEqual(block.count('_pending deleteAt 0'),1)
        self.assertIn('time < (_job get "egressDeadline")',block)
        self.assertIn('private _arrived=_pending isEqualTo [] &&',block)
        self.assertIn('if (_pending isNotEqualTo []) then {_job set ["egressFailed",true]}',block)
        self.assertIn('forEach _assignments',block)
        self.assertNotIn('serverTime+45',block)
        dispatch=block.split('private _target=',1)[1].split('private _assignments=',1)[0]
        self.assertLess(dispatch.index('call _exitMovementOwned'),dispatch.index('_unit doMove'))
        self.assertNotIn('_target=getPosATL',dispatch)

    def test_pending_adoption_is_typed_unique_and_cannot_renew_or_issue_movement(self):
        replay=self.start.split('// Adopt a transform/episode-bound exit journal',1)[1].split('// Keep reserve search consumption',1)[0]
        for marker in ('count _egressJournal in [10,13]', 'isEqualTo 2',
                       'count (_egressJournal select 11)+count (_egressJournal select 3) <= 8',
                       '(_x select 0) isEqualType objNull','count (_x select 1) in [0,3]',
                       '_assignments+_pending','_live vectorDistance _leg <= 0.25',
                       '"egressPending",_pending','"egressExitUses",_uses',
                       '((_egressJournal select 7)-serverTime) max 0'):
            self.assertIn(marker,replay)
        for forbidden in (' doMove ', 'doStop', 'doFollow','serverTime+45'):
            self.assertNotIn(forbidden,replay)

    def test_journal_and_observer_retain_incremental_assignments(self):
        journal=self.step.split('// Publish only material egress changes.',1)[1]
        self.assertIn('"egressPending",[]',journal)
        self.assertIn('"egressExitUses",createHashMap',journal)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        observation=qa.split('private _exit=_group getVariable ["WAIT_Cortex_ClearEgress",[]];',1)[1].split('forEach _egressAssignments;',1)[0]
        self.assertIn('count _exit in [4,10,13]',observation)
        self.assertIn('_egressAssignments findIf',observation)
        self.assertIn('_egressAssignments pushBack +_x',observation)
        self.assertNotIn('!_egressSeen',observation)

    def test_hc_fixture_requires_pending_roster_and_actual_exit_for_every_worker(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text()
        case=qa.split('// Separate headless-batch acceptance:',1)[1].split('if (local _group) then {[_group] call WAIT_fnc_CortexClearRelease}',1)[0]
        for marker in ('HC-CLEAR-EGRESS-pending-observed','private _pendingBefore=+',
                       'count _expectedActors == count _members',
                       'count _currentActors != count _expectedActors',
                       'forEach _pendingBefore','isNotEqualTo _leg',
                       '_targets pushBack [_actor,+(_x select 1),_x select 4]',
                       'count _targets == count _expectedActors',
                       '[_actor,_house,_target] call _observedExit'):
            self.assertIn(marker,case)
        observe=case.split('private _terminal=[{',1)[1].split('HC-CLEAR-EGRESS-journal-preserved',1)[0]
        for forbidden in (' doMove ', 'doStop','setPos','setVelocity','enableSimulation'):
            self.assertNotIn(forbidden,observe)

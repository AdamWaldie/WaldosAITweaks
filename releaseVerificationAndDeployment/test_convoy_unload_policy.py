"""Convoy unload ownership regressions; no engine or migration acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(name):return (ROOT/'addons/vehicles/functions'/f'{name}.sqf').read_text(encoding='utf-8')
class ConvoyUnloadPolicyTests(unittest.TestCase):
    def test_all_convoy_writers_use_the_exact_lease(self):
        for name in ('convoyTick','convoyCrewLocal','convoyReleaseLocal'):
            s=src(name)
            self.assertIn('call WAIT_fnc_ConvoyUnloadPolicy',s)
            self.assertNotIn('setUnloadInCombat',s)
        s=src('convoyReleaseLocal')
        self.assertIn('if !(_vehicle in _keepCrew) then {',s)
        self.assertIn('"RELEASE",-1,_restoreUnload',s)
    def test_external_mutation_blocks_even_across_revision_and_owner_changes(self):
        s=src('convoyUnloadPolicy')
        mutation=s.split('if (count _lease == 5 && {getUnloadInCombat',1)[1].split('if (count _lease == 5) then',1)[0]
        self.assertIn('WAIT_Convoy_UnloadPolicyLease",nil,true',mutation)
        self.assertIn('WAIT_Convoy_UnloadPolicyBlocked",_group,true',mutation)
        self.assertNotIn('setUnloadInCombat',mutation)
        self.assertIn('if (_blocked == _group) exitWith {false}',s)
        self.assertNotIn('_blocked == [_group,_revision]',s)
        adoption=s.split('if (count _lease == 5) then {',1)[1].split('} else {',1)[0]
        self.assertIn('_lease set [1,_revision]',adoption)
        self.assertIn('_lease set [4,clientOwner]',adoption)
        self.assertNotIn('setUnloadInCombat',adoption)
    def test_restore_requires_exact_lease_and_current_applied_value(self):
        s=src('convoyUnloadPolicy')
        release=s.split('if (_action == "RELEASE") exitWith {',1)[1].split('if (_action != "ACQUIRE"',1)[0]
        self.assertIn('count _lease == 5 && {(_lease select 0) == _group}',release)
        self.assertIn('if (_ours) then {',release)
        self.assertIn('_restore && {getUnloadInCombat _vehicle isEqualTo _applied}',release)
        self.assertIn('_vehicle setUnloadInCombat _previous',release)
        self.assertIn('if (_blocked == _group)',release)
    def test_admission_is_current_registered_and_bounded(self):
        s=src('convoyUnloadPolicy')
        for marker in ('local _vehicle','remoteExecutedOwner != 2','WAIT_Convoy_Revision',
                       'WAIT_Convoy_Group','WAIT_Convoy_Active','CortexExternalTakeover',
                       '(_lease select 1) > _revision','group _operator != _group'):
            self.assertIn(marker,s)
        executable=s.split('params [[',1)[1]
        for forbidden in ('spawn','while {','waitUntil','addEventHandler','moveIn','allVehicles'):
            self.assertNotIn(forbidden,executable)
if __name__=='__main__':unittest.main()

"""Danger-cover delayed ownership contracts; physical handover is separate acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class CoverOrderContextTests(unittest.TestCase):
    def test_cover_adoption_continuation_and_recovery_require_original_orders(self):
        source=(ROOT/'addons/infantry/functions/dangerCoverStep.sqf').read_text(encoding='utf-8')
        context=source.split('private _readOrderContext=',1)[1].split('private _moveProof=',1)[0]
        for marker in ('WAIT_AIPass_Epoch','WAIT_OperationGeneration','WAIT_fnc_NativeOrderReceipt','count _lease == 6','(_lease select 5) isEqualTo _entryContext'):
            self.assertIn(marker,context)
        self.assertEqual(source.count('if (!_releaseOnly && {_leaseContextCurrent}'),3)
        self.assertIn('[_actor,_generation,_deadline,+_spot,+_threat,+_entryContext]',source)
        self.assertIn('if (_orderChanged) exitWith {["ORDER_CHANGED"] call _clearLease}',source)
        final=source.rsplit('if (_entryContext isNotEqualTo (call _readOrderContext)',1)[1]
        self.assertLess(final.index('exitWith'),final.index('_actor doMove _spot'))
        cleanup=source.split('if (count _lease >= 4) then {',1)[1].split('if (_orderChanged) exitWith',1)[0]
        self.assertIn('_entryContext isEqualTo (call _readOrderContext)',cleanup)
        self.assertNotIn('addWaypoint',source)
        self.assertNotIn('setCurrentWaypoint',source)
if __name__=='__main__': unittest.main()

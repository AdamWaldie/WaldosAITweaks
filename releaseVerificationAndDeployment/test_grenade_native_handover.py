"""Delayed grenade release must preserve replacement authored tasks."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
class GrenadeNativeHandoverTests(unittest.TestCase):
    def test_receipt_is_captured_before_escape_and_retained_in_callback(self):
        s = (ROOT / "addons/infantry/functions/cortexGrenadeCheck.sqf").read_text()
        admission = s.split('private _grenade =', 1)[1]
        self.assertLess(admission.index('private _nativeRoute=[_group] call WAIT_fnc_NativeOrderReceipt;'), admission.index('_unit doMove _spot;'))
        self.assertIn('_group getVariable ["WAIT_AIPass_Epoch",0],_nativeRoute]', admission)
        self.assertEqual(s.count('call WAIT_fnc_CortexQueueJob'), 2)  # header example and single regroup job
    def test_legacy_rows_only_clean_up_and_new_orders_veto_follow(self):
        s = (ROOT / "addons/infantry/functions/cortexGrenadeCheck.sqf").read_text()
        callback = s.split('private _grenade =', 1)[0]
        follow = callback.index('_unit doFollow')
        for guard in ('["_nativeRoute",[],[[]]]', '_nativeRoute isNotEqualTo []',
                      '([_group] call WAIT_fnc_NativeOrderReceipt) isEqualTo _nativeRoute',
                      'count _destination == 3', '_destination vectorDistance _spot <= 0.25'):
            self.assertLess(callback.index(guard), follow)
        self.assertIn('(expectedDestination _unit) param [0,[],[[]]]', callback)
        cleanup = callback.index('_unit setVariable ["WAIT_Cortex_ActorMove",nil]')
        self.assertGreater(cleanup, follow)
        self.assertIn('if (_ownsEvasion && {local _unit}) then {', callback)
        self.assertIn('_actorMove isEqualTo ["GRENADE_EVASION",_spot,_expires]', callback)

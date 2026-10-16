"""Combined-arms contact transport admission; static/analytic, not physical acceptance."""
from pathlib import Path
import math
import unittest
ROOT=Path(__file__).resolve().parents[1]
class CombinedContactPayloadTests(unittest.TestCase):
    def test_request_server_owner_share_finite_three_coordinate_boundary(self):
        files=['cortexCombinedArmsRequest','cortexCombinedArmsServer','cortexCombinedArmsLocal']
        for name in files:
            s=(ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text(encoding='utf-8')
            self.assertIn('count _position != 3',s)
            self.assertIn('!finite _x',s)
            self.assertIn('abs _x > 1e6',s)
            boundary=s.index('count _position != 3')
            if name.endswith('Request'):
                self.assertLess(boundary,s.index('_state set ["combinedArmsDue"'))
            elif name.endswith('Server'):
                self.assertLess(boundary,s.index('_requester setVariable ["WAIT_Cortex_CombinedDue"'))
            else:
                self.assertLess(boundary,s.index('private _asset='))
    def test_invalid_positions_cannot_be_valid_contact_vectors(self):
        def admitted(p):
            return isinstance(p,list) and len(p)==3 and all(type(v) in (int,float) and math.isfinite(v) and abs(v)<=1e6 for v in p)
        for p in ([1,2],[1,2,3,4],[1,2,float('nan')],[float('inf'),2,3],[1,2,'3'],[1,2,1e6+1]):
            self.assertFalse(admitted(p),repr(p))
        self.assertTrue(admitted([1250,3500,0]))
        self.assertTrue(admitted([-1e6,1e6,-10]))
    def test_contact_receipt_is_preserved_without_fallback_or_replay_refresh(self):
        def source(name):
            return (ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text(encoding='utf-8')
        knowledge=source('cortexKnowledge')
        request=source('cortexCombinedArmsRequest')
        server=source('cortexCombinedArmsServer')
        owner=source('cortexCombinedArmsLocal')
        self.assertIn('_confidence=_group knowsAbout _enemy',knowledge)
        self.assertNotIn('_confidence=_confidence max (_x knowsAbout _enemy)',knowledge)
        self.assertIn('if (isNull _group || {!local _group}) exitWith {[[],0]}',knowledge)
        self.assertIn('_contact param [5,1,[0]]',request)
        self.assertIn('serverTime-_age,_confidence min 2.5',request)
        self.assertIn('_contactReceipt=[1,_observedAt,_confidence min 2.5]',server)
        self.assertIn('serverTime-(_contactReceipt select 1) <= 10',owner)
        self.assertIn('if (_freshReport) then {_group reveal',owner)
        self.assertIn('"NO_KNOWN_CONTACT"',owner)
        for name in ('cortexCombinedAirFallbackServer','cortexCombinedGroundFallbackServer'):
            fallback=source(name)
            self.assertIn('_fallback param [6,[],[[]]]',fallback)
            self.assertIn('+_contactReceipt',fallback)
            self.assertIn('isNotEqualTo _contactReceipt',fallback)
            self.assertNotIn('_contactReceipt=[1,serverTime',fallback)
        tick=source('cortexGroupTick')
        self.assertIn('(count _combinedRole) in [7,8]',tick)
    def test_delayed_replacement_does_not_gain_fresh_observation_or_confidence(self):
        receipt=(1,100,1.2)
        def transferable(r,now):
            return len(r)==3 and r[0]==1 and 0<=r[1]<=now+1 and now-r[1]<=10 and 0<r[2]<=2.5
        self.assertTrue(transferable(receipt,105))
        replacement=tuple(receipt)
        self.assertFalse(transferable(replacement,111))
        self.assertEqual(replacement[2],1.2)
        self.assertFalse(transferable((),105))
        self.assertFalse(transferable((1,100,3),105))
        self.assertFalse(transferable((1,200,1),105))
if __name__=='__main__':unittest.main()

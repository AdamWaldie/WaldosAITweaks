"""Smoke classification must reject explosive/mixed trees; live shell delivery is separate."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class SmokePayloadTests(unittest.TestCase):
    def test_payload_validation_precedes_smoke_leaf_acceptance(self):
        s=(ROOT/'addons/support/functions/cortexArtilleryAmmo.sqf').read_text(encoding='utf-8')
        classify=s.split('private _classifySmoke =',1)[1].split('private _profile',1)[0]
        for guard in ('_smokeChecks > 64','_depth >= 4','!finite _indirect','_indirect != 0','count _payloads <= 16','_payloads findIf {!(_x isEqualType "")','_payloads findIf {!([_x,_depth+1]'):
            self.assertIn(guard,classify)
            self.assertLess(classify.index(guard),classify.index('_simulation in ["shotsmoke","shotsmokex"]'))
        self.assertNotIn('aiAmmoUsageFlags',classify)
        self.assertNotIn('select {_x isEqualType ""}',classify)
        self.assertIn('_smokeChecks=0;',s)
    def test_smoke_gate_reaches_admission_continuation_and_owner_release(self):
        base=ROOT/'addons/support/functions'
        fire=(base/'cortexArtilleryFire.sqf').read_text(encoding='utf-8')
        self.assertIn('_mode != "SMOKE" || {[group gunner _x,"WAIT_AIPass_ArtillerySmoke_Enable"',fire)
        explicit=fire.split('if (isNull _battery || {!alive gunner _battery}',1)[1]
        self.assertLess(explicit.index('WAIT_AIPass_ArtillerySmoke_Enable'),explicit.index('WAIT_AIPass_FireSerial'))
        mission=(base/'cortexArtilleryMissionStep.sqf').read_text(encoding='utf-8')
        self.assertIn('private _blocked = _smokeBlocked',mission)
        self.assertIn('WAIT_AIPass_ArtillerySmoke_Enable',mission)
        shot=(base/'cortexArtilleryShot.sqf').read_text(encoding='utf-8')
        final=shot.split('// Safety/munition checks',1)[1]
        self.assertLess(final.index('WAIT_AIPass_ArtillerySmoke_Enable'),final.index('doArtilleryFire'))
    def test_weighted_payloads_are_validated_without_discarding_dangerous_branches(self):
        s=(ROOT/'addons/support/functions/cortexArtilleryAmmo.sqf').read_text(encoding='utf-8')
        for guard in ('count _payloadArray <= 32','count _payloadArray mod 2 == 0','!(_weight isEqualType 0)','!finite _weight','_weight < 0','_positiveWeight','_payloads pushBack _class'):
            self.assertIn(guard,s)
        self.assertNotIn('if (_weight > 0) then {_payloads',s)
        self.assertLess(s.index('_validPayload=_validPayload && {_positiveWeight}'),s.index('_payloads findIf {!([_x,_depth+1]'))
if __name__=='__main__': unittest.main()

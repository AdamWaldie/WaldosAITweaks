"""Admission refusal must preserve the previous task; static contracts, not path proof."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class GarrisonPreflightTests(unittest.TestCase):
    def test_candidate_validation_precedes_cleanup_and_publication(self):
        s=(ROOT/'addons/infantry/functions/cortexGarrison.sqf').read_text(encoding='utf-8')
        cleanup=s.index('call WAIT_fnc_CortexReleaseGroup')
        for guard in ('!finite _radius','count _units > 64','count _buildings > 64','_positionsSeen > 512','!surfaceIsWater _position','WAIT_fnc_PositionBucketAdmit','INVALID_OR_OVER_BUDGET_PLAN'):
            self.assertLess(s.index(guard),cleanup)
        self.assertLess(cleanup,s.index('setVariable ["WAIT_Cortex_GarrisonCandidates"'))
        self.assertEqual(s.count('nearestObjects'),1)
    def test_server_rejects_nonfinite_parameters_before_pending_requests(self):
        s=(ROOT/'addons/infantry/functions/cortexOrderDispatch.sqf').read_text(encoding='utf-8')
        for value in ('_radius','_facing','_width'):
            self.assertLess(s.index('!finite '+value),s.index('_pending set [_token'))
        self.assertIn('!finite _x',s)
    def test_changed_planning_context_is_refused_before_old_task_cleanup(self):
        s=(ROOT/'addons/infantry/functions/cortexGarrison.sqf').read_text()
        capture=s.index('private _admissionRoute=')
        self.assertLess(capture,s.index('nearestObjects'))
        guard=s.split('private _admissionCurrent={',1)[1].split('// One bounded admission plan.',1)[0]
        for value in ('WAIT_AIPass_Epoch','call WAIT_fnc_NativeOrderReceipt','_admissionGenerations',
                      'currentCommand _actor != _command','isNotEqualTo _destination',
                      'group _actor != _group','vehicle _actor != _actor','CortexActorMoveReserved'):
            self.assertIn(value,guard)
        refusal=s.index('if !(call _admissionCurrent) exitWith')
        self.assertLess(s.index('_candidates sort true'),refusal)
        self.assertLess(refusal,s.index('call WAIT_fnc_CortexReleaseGroup'))
        self.assertLess(s.index('PLAN_CONTEXT_CHANGED'),s.index('setVariable ["WAIT_Cortex_GarrisonCandidates"'))
        self.assertNotIn('setVariable',guard)
        self.assertIn('_command == "FOLLOW" && {!isNull _followLeader}',guard)
        self.assertIn('formLeader _actor != _followLeader',guard)

    def test_owner_failure_feedback_and_rollback_are_context_bound(self):
        s=(ROOT/'addons/infantry/functions/cortexOrderLocal.sqf').read_text()
        rollback=s.split('// Rollback owns only this exact temporary override.',1)[1].split('private _executionReason=',1)[0]
        for guard in ('isEqualTo _executionTasks','local _group','== _executionEpoch','== _serial',
                      '_liveControl isEqualTo _temporaryControl','call WAIT_fnc_NativeOrderReceipt'):
            self.assertIn(guard,rollback)
        self.assertLess(rollback.index('_liveControl isEqualTo'),rollback.index('setVariable'))
        for reason in ('PLAN_CONTEXT_CHANGED','NO_VALID_POSITIONS','bounded planning budget'):
            self.assertIn(reason,s)
        self.assertIn('(_garrisonFailure select 2) == _serial',s)
        self.assertIn('_garrisonFailure isNotEqualTo _previousGarrisonFailure',s)
        admission=(ROOT/'addons/infantry/functions/cortexGarrison.sqf').read_text()
        self.assertEqual(admission.count('setVariable ["WAIT_Cortex_GarrisonAdmissionFailure"'),2)

if __name__=='__main__': unittest.main()

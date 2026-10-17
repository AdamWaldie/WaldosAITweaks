"""Defence refusal must precede destructive task replacement; offline contracts only."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DefendPreflightTests(unittest.TestCase):
    def test_complete_layout_is_validated_before_releasing_or_writing(self):
        s=(ROOT/'addons/infantry/functions/cortexDefend.sqf').read_text()
        gate=s.index('if (!_layoutValid')
        self.assertLess(gate,s.index('call WAIT_fnc_CortexReleaseGroup'))
        self.assertLess(gate,s.index('setVariable ["WAIT_AIPass_DefendPos"'))
        self.assertIn('count _placements != count _units',s)
        for required in ('!finite _width','count _units > 64','!surfaceIsWater _position','distance2D _position < 1','_layoutValid=false','CortexExternalTakeover'):
            self.assertIn(required,s)
        self.assertIn('[_slot, _threat, 8, _taken, _group] call WAIT_fnc_CortexFindCover',s)
    def test_planning_context_is_read_only_and_rechecked_before_cleanup(self):
        s=(ROOT/'addons/infantry/functions/cortexDefend.sqf').read_text()
        capture=s.index('private _admissionRoute=')
        self.assertLess(capture,s.index('call WAIT_fnc_CortexFindCover'))
        guard=s.split('private _admissionCurrent={',1)[1].split('private _reserveCount',1)[0]
        for value in ('WAIT_AIPass_Epoch','call WAIT_fnc_NativeOrderReceipt','_admissionGenerations',
                      'currentCommand _actor != _command','isNotEqualTo _destination',
                      'group _actor != _group','vehicle _actor != _actor','CortexActorMoveReserved',
                      'formLeader _actor != _followLeader'):
            self.assertIn(value,guard)
        self.assertNotIn('setVariable',guard)
        final=s.index('if (!_layoutValid')
        self.assertIn('!(call _admissionCurrent)',s[final:s.index('// End transient movement')])
        self.assertLess(final,s.index('call WAIT_fnc_CortexReleaseGroup'))
        allocation=s.split('private _units =',1)[1].split('private _admissionRoute=',1)[0]
        self.assertIn('call WAIT_fnc_CortexActorMoveReserved',allocation)

    def test_reserve_plan_preserves_busy_actors_and_rejects_collapsed_slots(self):
        s=(ROOT/'addons/infantry/functions/cortexDefendStep.sqf').read_text()
        available=s.split('private _reserveAvailable={',1)[1].split('private _reserve =',1)[0]
        for guard in ('CortexActorMoveReserved','isNull objectParent _actor','isNull remoteControlled _actor',
                      'currentCommand _actor in ["","STOP"]','WAIT_AIPass_DefendHolding'):
            self.assertIn(guard,available)
        publication=s.index('setVariable ["WAIT_AIPass_DefendPos"')
        self.assertLess(s.index('_taken findIf {_x distance2D _position < 1}'),publication)
        self.assertLess(s.index('if (!_layoutValid'),publication)
        self.assertLess(s.index('_reserve findIf {!([_x] call _reserveAvailable)}'),publication)
        self.assertLess(publication,s.index('_state set ["reserveCommitted", true]'))

    def test_delayed_defence_cannot_reissue_over_a_new_native_command(self):
        s=(ROOT/'addons/infantry/functions/cortexDefendApplyLocal.sqf').read_text()
        receipt=s.split('private _ownsRouteCommand={',1)[1].split('[{',1)[0]
        for value in ('_command == "MOVE"','vectorDistance ((_route select 5) select 0) <= 0.25',
                      '_command == (_route select 7)','formLeader _actor == (_route select 9)',
                      '_destination isEqualTo (_route select 8)'):
            self.assertIn(value,receipt)
        retirement=s.split('// The current order belongs to somebody else.',1)[1].split('private _canIssue=',1)[0]
        self.assertIn('_routeCurrent=false',retirement)
        for command in ('doMove','doStop','doFollow','doWatch'):
            self.assertNotIn(command,retirement)
        self.assertLess(s.index('call _ownsRouteCommand)'),s.index('doStop _unit'))
        self.assertIn('_assignment isEqualTo ((_routes select _routeIndex) select 5)',s)
        self.assertEqual(s.count('_route set [6,true]'),2)

    def test_adoption_requires_bound_receipt_and_worker_stays_in_owner_epoch(self):
        s=(ROOT/'addons/infantry/functions/cortexDefendApplyLocal.sqf').read_text()
        adoption=s.split('private _adoptionCommandOwned={',1)[1].split('private _rememberMove=',1)[0]
        for value in ('count _receipt == 6','(_receipt select 4) isEqualTo _assignment',
                      '(_receipt select 2) <=','_live vectorDistance (_receipt select 3) <= 0.25',
                      '(_receipt select 5) == "HOLD"','_actor in _freshActors'):
            self.assertIn(value,adoption)
        self.assertIn('remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}',s)
        self.assertIn('count _actors > 64',s)
        self.assertIn('!= (_job get "epoch")',s)
        self.assertIn('isNotEqualTo (_job get "nativeRoute")',s)
        self.assertIn('[_x,_assignment select 0,"MOVE"] call _rememberMove',s)
        self.assertIn('[_unit,_assignment select 0,"HOLD"] call _rememberMove',s)
        discovery=(ROOT/'addons/core/functions/cortexDiscover.sqf').read_text()
        self.assertIn('[_group] call WAIT_fnc_CortexDefendApplyLocal',discovery)
        order=(ROOT/'addons/infantry/functions/cortexDefend.sqf').read_text()
        self.assertIn('[_group,[],_units] call WAIT_fnc_CortexDefendApplyLocal',order)
        release=(ROOT/'addons/infantry/functions/cortexDefendRelease.sqf').read_text()
        self.assertIn('setVariable ["WAIT_Cortex_DefendMove",nil,true]',release)
        self.assertIn('setVariable ["WAIT_Cortex_DefendNativeRoute",nil,true]',release)

    def test_release_and_reserve_need_actual_owned_command_evidence(self):
        release=(ROOT/'addons/infantry/functions/cortexDefendRelease.sqf').read_text(encoding='utf-8')
        for value in ('count _receipt == 6','(_receipt select 4) isEqualTo _assignment',
                      '_live vectorDistance (_receipt select 3) <= 0.25','{_ownedCommand}',
                      '_command in ["","STOP"]','(_receipt select 5) == "HOLD"'):
            self.assertIn(value,release)
        self.assertLess(release.index('{_ownedCommand}'),release.index('_x doWatch objNull'))
        self.assertLess(release.index('{_ownedCommand}'),release.index('_x doFollow _leader'))
        self.assertLess(release.index('_x doFollow _leader'),release.index('setVariable ["WAIT_Cortex_DefendMove",nil,true]'))
        reserve=(ROOT/'addons/infantry/functions/cortexDefendStep.sqf').read_text(encoding='utf-8')
        available=reserve.split('private _reserveAvailable={',1)[1].split('private _reserve =',1)[0]
        for value in ('count _receipt == 6','(_receipt select 4) isEqualTo _assignment',
                      '(_receipt select 5) == "HOLD"','vectorDistance (_receipt select 3) <= 3'):
            self.assertIn(value,available)

    def test_replacement_tasks_suppress_predecessor_recall(self):
        for name in ('cortexDefend','cortexGarrison','cortexClearBuilding'):
            s=(ROOT/('addons/infantry/functions/'+name+'.sqf')).read_text(encoding='utf-8')
            self.assertIn('[_group,false,false] call WAIT_fnc_CortexDefendRelease',s)
            self.assertNotIn('[_group] call WAIT_fnc_CortexDefendRelease',s)
        release=(ROOT/'addons/infantry/functions/cortexDefendRelease.sqf').read_text(encoding='utf-8')
        self.assertIn('["_recallHeld",true,[true]]',release)
        self.assertIn('[_group,_restore,_recallHeld] remoteExecCall',release)
        self.assertIn('_recallHeld && {!_externalTakeover',release)

if __name__=='__main__': unittest.main()

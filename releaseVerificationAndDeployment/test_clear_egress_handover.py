"""Egress must yield to individual destination replacement before arrival or retry."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ClearEgressHandoverTests(unittest.TestCase):
    def test_terminal_hold_contains_only_actual_settlements_and_cleans_diverted_leases(self):
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        finish = source.split('private _handbacks=[];',1)[1].split('if (_reason == "NEW_ORDER"',1)[0]
        movement = finish.split('if (_restore && {[_x] call _actorTaskFree}',1)[1].split('_x setVariable ["WAIT_Cortex_ClearForcedSpeed",nil,true]',1)[0]
        self.assertIn('!(_x in (_job getOrDefault ["egressDiverted",[]]))',movement)
        self.assertLess(movement.index('doStop _x'),movement.index('_settled pushBackUnique _x'))
        loop = finish.split('} forEach ',1)[1].split(';',1)[0]
        self.assertNotIn('egressDiverted',loop)
        hold = finish.split('if (_reason == "COMPLETE" && {_restore}',1)[1]
        self.assertIn('_settled isNotEqualTo []',hold)
        self.assertIn('WAIT_fnc_NativeOrderReceipt,+_settled]',hold)
        self.assertIn('WAIT_Cortex_ClearEarlyExits",nil,true',finish)
        release = (ROOT / 'addons/infantry/functions/cortexClearRelease.sqf').read_text(encoding='utf-8')
        self.assertIn('WAIT_Cortex_ClearEarlyExits",nil,true',release)

    def test_transition_preserves_replacement_before_first_exit_order(self):
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        transition = source.split('// Complete physical coverage and participation', 1)[1]
        admission = transition.split('private _entries=', 1)[0]
        self.assertIn('if !([_actor] call _exitMovementOwned) then', admission)
        self.assertIn('_diverted pushBackUnique _actor', admission)
        self.assertIn('deleteAt (netId _actor)', admission)
        self.assertIn('!(_actor in _diverted)', admission)
        self.assertIn('_job set ["egressFailed",true]', admission)
        self.assertIn('_job set ["egressDiverted",_diverted]', admission)
        self.assertIn('_job set ["egressPending",_pending]', transition)

    def test_individual_order_filters_arrivals_and_retry_without_losing_failure(self):
        source = (ROOT / 'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        egress = source.split('if ((_job getOrDefault ["phase","CLEAR"]) == "EGRESS") exitWith {', 1)[1]
        selection = egress.split('private _outsideExit={', 1)[0]
        self.assertIn('if !([_unit] call _exitMovementOwned) then', selection)
        self.assertIn('_diverted pushBackUnique _unit', selection)
        self.assertIn('deleteAt (netId _unit)', selection)
        self.assertIn('_x set [2,false]', selection)
        self.assertIn('!(_unit in _diverted)', selection)
        self.assertIn('if (count _assignments < count (_job get "egressAssignments")) then {_job set ["egressFailed",true]}', selection)
        self.assertIn('_assignments findIf {[_x] call _outsideExit}', egress)
        self.assertIn('forEach _assignments', egress)
        finish = source.split('private _handbacks=[];', 1)[1].split('private _delay', 1)[0]
        self.assertIn('[_x] call _exitMovementOwned', finish)

    def test_natural_continuation_is_opt_in_durable_and_after_successful_egress(self):
        admission=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text(encoding='utf-8')
        contact=(ROOT/'addons/infantry/functions/cortexBuildingContact.sqf').read_text(encoding='utf-8')
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text(encoding='utf-8')
        self.assertIn('["continueRoute",true]',contact)
        self.assertIn('_previous param [12,false,[true]]',admission)
        self.assertIn('_options getOrDefault ["continueRoute",false]',admission)
        self.assertIn('"INVALID_CONTINUATION"',admission)
        self.assertIn('_job getOrDefault ["continueRoute",false]], true]',s)
        block=s.split('// A natural clear is an interruption',1)[1].split('if (_reason == "NEW_ORDER"',1)[0]
        for guard in ('_result == "COMPLETE"','waypointType _waypoint == "MOVE"',
                      'waypointScript _waypoint == ""','waypointTimeout',
                      'synchronizedWaypoints','synchronizedTriggers','waypointAttachedObject',
                      'currentCommand _actor == "STOP"','_actor in _settled',
                      'WAIT_fnc_NativeOrderReceipt','WAIT_BuildingBrain','WAIT_Operation',
                      'WAIT_fnc_CortexExternalTakeover'):
            self.assertIn(guard,block)
        self.assertLess(s.index('call WAIT_fnc_OperationRelease'),s.index('// A natural clear is an interruption'))
        self.assertLess(block.index('[_leader] call _mayContinue'),block.index('_leader doMove'))
        self.assertLess(block.index('[_x] call _mayContinue'),block.index('_x doFollow'))
        for forbidden in ('addWaypoint','deleteWaypoint','setCurrentWaypoint','enableAI','setPos'):
            self.assertNotIn(forbidden,block)

    def test_natural_route_fixture_observes_real_handover_without_replacement_orders(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        self.assertIn('BUILD-CONTACT-physical-entry',s)
        case=s.split('// Independent natural-contact continuation case;',1)[1].split('// A newer actor destination',1)[0]
        for marker in ('BUILD-CONTINUE-native-knowledge','BUILD-CONTINUE-natural-clear-started',
                       'BUILD-CONTINUE-physical-entry','BUILD-CONTINUE-real-defender-casualty',
                       'BUILD-CONTINUE-clearance-complete','BUILD-CONTINUE-physical-room-coverage','BUILD-CONTINUE-original-route-physical',
                       'BUILD-CONTINUE-authored-route-retained','FiredMan','"Killed"'):
            self.assertIn(marker,case)
        observation=case.split('// Enable real casualty resolution',1)[1].split('call WAIT_fnc_CortexClearRelease',1)[0]
        for command in (' doMove ', ' doFollow ', 'addWaypoint','setCurrentWaypoint',
                        'call WAIT_fnc_CortexClearBuilding',' setDamage ', ' setPos', ' reveal '):
            self.assertNotIn(command,observation)
        self.assertIn('_x distance2D _origin < 25',observation)
        self.assertIn('distance2D _routeDestination) < 20',observation)
        self.assertIn('_routeOutcome == "COMPLETE"',observation)
        self.assertIn('&& {_routePhysicalClear}',observation)
        self.assertIn('call _observedRoomVisit',case)
        self.assertIn('call _observeRouteRooms;',observation)

if __name__ == '__main__':
    unittest.main()


class ClearSettlementPresenceTests(unittest.TestCase):
    def test_historical_arrival_is_not_current_settlement(self):
        arrived=True
        def retained(arrived,distance,height):
            return arrived and distance<=1 and abs(height)<=1.5
        self.assertTrue(retained(arrived,0.5,0.2))
        self.assertFalse(retained(arrived,4,0.2))
        self.assertFalse(retained(arrived,0.5,3))
        self.assertFalse(retained(False,0.5,0.2))

    def test_displacement_retires_arrival_without_renewing_budget(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        check=s.split('private _outsideExit={',1)[1].split('private _early=',1)[0]
        self.assertIn('private _stillAtPost=',check)
        self.assertIn('_unit distance2D _target <= 1',check)
        self.assertIn('&& {_stillAtPost}) exitWith {false}',check)
        self.assertIn('_assignment set [2,false]',check)
        self.assertNotIn('egressDeadline',check)
        self.assertNotIn('doMove',check)

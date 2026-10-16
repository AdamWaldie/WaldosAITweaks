"""Gate approach uses live body geometry under the existing single speed writer."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingGateCapTests(unittest.TestCase):
    def test_observation_is_bounded_live_and_has_no_world_mutation(self):
        s=(ROOT/'addons/vehicles/functions/drivingGeometryCap.sqf').read_text()
        for gate in ['modelToWorldWorld', 'true,4,"GEOM","NONE"',
                     '[_left,(_left+_right)*0.5,_right]', 'forEach _heights',
                     'max 25 min 600', '_gap-6', '_deceleration=4/_massFactor']:
            self.assertIn(gate,s)
        for command in ['animateSource','animateDoor','forceSpeed','setVelocity','doMove','remoteExec','animationSourcePhase']:
            self.assertNotIn(command,s)
        self.assertNotIn('alive _object',s)
        self.assertNotIn('damage _object',s)
        self.assertIn('[_bottom,(_bottom+_top)*0.5,_top]',s)
        self.assertIn('(_high select 2)-0.2',s)
    def test_existing_executors_combine_gate_before_speed_and_recovery(self):
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        convoy=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertLess(ordinary.index('call WAIT_fnc_DrivingGeometryCap'),ordinary.index('_vehicle forceSpeed _capMps'))
        self.assertIn('if (!_reverseLeg) then {',ordinary)
        self.assertEqual(convoy.count('call WAIT_fnc_DrivingGeometryCap'),2)
        self.assertIn('then {_leadTraffic=_leadGate}',convoy)
        self.assertIn('then {_traffic=_vehicleGate}',convoy)
        self.assertIn('!_leadTrafficBlocked',convoy)
        self.assertIn('!_trafficBlocked',convoy)
    def test_opening_request_has_server_authority_and_complete_named_payload(self):
        owner=(ROOT/'addons/vehicles/functions/drivingGateRequest.sqf').read_text()
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        for key in ['group','vehicle','gate','route','transform','driver','commander','convoyRevision','expires']:
            self.assertIn('["'+key+'",',owner)
            self.assertIn('getOrDefault ["'+key+'",',server)
        for guard in ['!isServer', 'remoteExecutedOwner', 'groupOwner _group', 'owner _vehicle',
                      'owner driver _vehicle', 'call WAIT_fnc_CortexIsEligible', 'call WAIT_fnc_CortexIsPaused',
                      '_expires <= serverTime', '_expires > serverTime+5',
                      'call WAIT_fnc_DrivingRouteReceipt', '_transform isNotEqualTo',
                      'call WAIT_fnc_DrivingGateCap', '(_observed select 1) != _gate',
                      '(_observed select 2) > 12', 'abs speed _vehicle > 8',
                      'WAIT_AIPass_Active', '!simulationEnabled _vehicle', 'isObjectHidden _vehicle']:
            self.assertIn(guard,server)
        mutation=server.split('// Final mutation boundary:',1)[1]
        self.assertLess(mutation.index('call _locked'),mutation.index('animateSource'))
        self.assertLess(mutation.index('driver _vehicle != _driver'),mutation.index('animateSource'))
        self.assertNotIn('animateSource',owner)
        self.assertIn('remoteExecCall ["WAIT_fnc_DrivingGateOpenServer",2]',owner)

    def test_gate_attempts_are_finite_and_do_not_create_passage_or_closure(self):
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        for guard in ['(_receipt select 0) == _group', '(_receipt select 1) isEqualTo _route',
                      '_attemptIndex >= 0', 'count _attempts >= 16', 'count _definitions <= 64',
                      '_index <= 8', 'bis_disabled_Door', 'SHARED_OPENING',
                      'ALREADY_OPEN_OR_MOVING', '[_x select 1,1]']:
            self.assertIn(guard,server)
        for command in ['doMove','forceSpeed','setVelocity','setDir','setPos','spawn','execFSM','CBA_fnc_waitAndExecute']:
            self.assertNotIn(command,server)
        self.assertNotIn('animateSource [_x select 1,0]',server)
        self.assertNotIn('setVariable ["bis_disabled',server)

    def test_delivery_is_bounded_and_duplicate_server_work_returns_before_geometry(self):
        owner=(ROOT/'addons/vehicles/functions/drivingGateRequest.sqf').read_text()
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        for guard in ['_attempts >= 2', 'serverTime < (_pending select 1)',
                      '(_ack select 4) isEqualTo _route', '(_ack select 6) isEqualTo _transform',
                      'OPEN_WINDOW_EXPIRED', 'REQUEST_TIMEOUT',
                      'WAIT_DrivingGate_Pending",[_context,serverTime+5,_attempts+1],true', '["driver",_driver]', '["commander",_commander]']:
            self.assertIn(guard,owner)
        self.assertLess(server.index('if (_attemptIndex >= 0) exitWith'),server.index('call WAIT_fnc_DrivingGateCap'))
        self.assertIn('_driver != _requestedDriver',server)
        self.assertIn('_commander != _requestedCommander',server)
        self.assertIn('[_gate,_reason,_until,_group,+_route,_revision,+_transform]',server)
        self.assertNotIn('animateSource',owner)

class DrivingGateIntentTests(unittest.TestCase):
    def test_gate_intent_is_checked_before_request_and_authoritative_mutation(self):
        owner=(ROOT/'addons/vehicles/functions/drivingGateRequest.sqf').read_text()
        server=(ROOT/'addons/vehicles/functions/drivingGateOpenServer.sqf').read_text()
        self.assertLess(owner.index('call WAIT_fnc_DrivingGateIntent'),owner.index('WAIT_DrivingGate_Pending'))
        self.assertEqual(server.count('call WAIT_fnc_DrivingGateIntent'),2)
        mutation=server.split('// Final mutation boundary:',1)[1]
        self.assertLess(mutation.index('call WAIT_fnc_DrivingGateIntent'),mutation.index('animateSource'))
        self.assertIn('_revision < 0',mutation)

    def test_plain_and_owned_alternate_intent_have_distinct_stop_contracts(self):
        s=(ROOT/'addons/vehicles/functions/drivingGateIntent.sqf').read_text()
        for marker in ('waypointType _waypoint != "MOVE"','synchronizedWaypoints',
                       'synchronizedTriggers','waypointAttachedObject','waypointTimeout',
                       'WAIT_DrivingBypass_Work","FOLLOW"','WAIT_DrivingCorridor_Work","CROSS"',
                       'expectedDestination _driver','expectedDestination _operator',
                       'serverTime <','"controller",[]','"phase",""]) == "APPROACH"',
                       '_driverTarget distance2D _destination <= 3'):
            self.assertIn(marker,s)
        # Plain route action requires idle or the original MOVE, not a later task.
        def plain(command, target_matches=True):
            return command=='' or command=='MOVE' and target_matches
        for command in ('STOP','WAIT','ATTACK','FOLLOW','FIRE','REARM'):
            self.assertFalse(plain(command))
        self.assertFalse(plain('MOVE',False))
        self.assertTrue(plain('MOVE'))
        self.assertTrue(plain(''))
        body=s.split('params [[',1)[1]
        for forbidden in ('setVariable','animateSource','doMove','doStop','forceSpeed','spawn','nearEntities'):
            self.assertNotIn(forbidden,body)

if __name__=='__main__': unittest.main()

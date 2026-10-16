"""Native driver handover authority/phase contracts; physical actions remain unaccepted."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingCrewTests(unittest.TestCase):
    def source(self):
        return (ROOT/'addons/vehicles/functions/drivingCrewStep.sqf').read_text(encoding='utf-8')
    def test_actions_are_once_per_phase_and_vacancy_is_observed(self):
        s=self.source().split('params [[',1)[1]
        self.assertEqual(s.count(' action ['),2)
        self.assertIn('_phase == "READY" && {!isNull _driver}',s)
        self.assertIn('driver _vehicle == _driver} && {!alive _driver}',s)
        self.assertEqual(s.count('\n    isNil {'),2)
        self.assertEqual(s.count('call _commandsOwned'),2)
        self.assertIn('_phase="VACATING_ISSUED"',s)
        self.assertIn('if (_phase in ["READY","VACATING"]) then {',s)
        self.assertIn('call _commandsOwned} && {isNull driver _vehicle}',s)
        self.assertIn('_work set ["phase","SWITCHING"]',s)
        for command in ('moveInDriver','moveOut','setPos','setVelocity','setHitPointDamage','allowDamage','enableAI','doMove','setDriveOnPath','spawn','sleep'):
            self.assertNotIn(command,s)
    def test_authority_and_original_orders_bind_late_writes(self):
        s=self.source()
        for guard in ('remoteExecutedOwner > 0','WAIT_Driving_Brain','WAIT_AIPass_Epoch','CortexZeusHeld',
                      'CortexExternalTakeover','WAIT_Convoy_Active','WAIT_ExternalDrivingOwner','DrivingMovementAvailable',
                      'count _crew <= 20','abs speed _vehicle < 1','!lockedDriver _vehicle',
                      'isPlayer _actor','group _actor != _group','currentCommand _actor in _tasks',
                      'waypointStatements','waypointScript','waypointTimeout','synchronizedTriggers',
                      'expectedDestination _candidate','expectedDestination leader _group','assignedVehicleRole _candidate',
                      'simulationEnabled _candidate','_candidate checkAIFeature "PATH"'):
            self.assertIn(guard,s)
        self.assertIn('alive _driver}) exitWith {}',s)
        self.assertIn('private _available={\n    _crew=fullCrew',s)
        self.assertIn('_previousVehicle != vehicle leader _group',s)
        self.assertIn('toLowerANSI (_x select 1) == "cargo"',s)
        self.assertEqual(s.count('call _available'),3)
    def test_vacant_seat_does_not_override_incoming_assignment(self):
        s=self.source()
        available=s.split('private _available={',1)[1].split('private _finish=',1)[0]
        self.assertIn('fullCrew [_vehicle,"driver",true]',available)
        self.assertIn('_driverSeat param [5,objNull]',available)
        self.assertIn('count _driverSeat >= 6',available)
        self.assertIn('isNull _assignedDriver || {!alive _assignedDriver} || {_assignedDriver == _candidate}',available)
    def test_deadlines_success_and_cancellation_are_not_synthetic(self):
        s=self.source()
        self.assertEqual(s.count('serverTime+25'),1)
        self.assertIn('serverTime >= (_work get "deadline")',s)
        self.assertIn('driver _vehicle == _candidate && {[_candidate] call WAIT_fnc_CortexCombatEffective}',s)
        self.assertIn('["COMPLETE","CANCELLED","EXPIRED"]',s)
        release=s.split('if (_release) exitWith {',1)[1].split('private _changed=',1)[0]
        self.assertNotIn(' action [',release)
        self.assertIn('(_brain getOrDefault ["route",[]])',release)
        finish=(ROOT/'addons/vehicles/functions/drivingOperationFinish.sqf').read_text(encoding='utf-8')
        self.assertIn('[_group,_brain,true] call WAIT_fnc_DrivingCrewStep',finish)
    def test_existing_fsm_owns_the_only_scheduler(self):
        step=(ROOT/'addons/vehicles/functions/drivingOperationStep.sqf').read_text(encoding='utf-8')
        start=(ROOT/'addons/vehicles/functions/drivingOperationStart.sqf').read_text(encoding='utf-8')
        fsm=(ROOT/'addons/main/fsm/drivingOperation.fsm').read_text(encoding='utf-8')
        self.assertIn('private _crewPending=[_group,_brain] call WAIT_fnc_DrivingCrewStep',step)
        self.assertIn('if (_crewPending) then {_phase="CREW_HANDOVER"}',step)
        self.assertIn('_crewPending || {_traffic}',step)
        self.assertIn('isNull driver _vehicle || {!alive driver _vehicle}',start)
        self.assertIn('class CrewHandover',fsm)
        self.assertNotIn('execFSM',self.source())
        source=self.source()
        self.assertLess(source.index('Normal healthy drivers'),source.index('call WAIT_fnc_DrivingRouteReceipt'))
        self.assertLess(source.index('Normal healthy drivers'),source.index('fullCrew'))

    def test_physical_fixture_uses_discovery_and_measured_results(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDrivingCrew.sqf').read_text(encoding='utf-8')
        self.assertNotIn('call WAIT_fnc_DrivingCrewStep',s)
        self.assertNotIn('setVariable ["WAIT_DrivingCrew_Work"',s)
        self.assertNotIn(' action [',s)
        self.assertIn('_vehicle distance2D _routeStart >= 35',s)
        self.assertIn('driver _vehicle == _replacement',s)
        self.assertIn('vehicle _driver != _vehicle',s)
        self.assertIn('private _moved=if (_seated) then {',s)
        self.assertLess(s.index('_driver setDamage 1'),s.index('_vehicle forceSpeed -1'))
        for case in ('"REPLACE"','"UNCONSCIOUS"','"LOCKED"','"ASSIGNED"'):
            self.assertIn(case,s)
        self.assertEqual(s.count('moveInCargo'),1)
        self.assertLess(s.index('moveInCargo'),s.index('_driver setDamage 1'))
        self.assertIn('WAIT_CortexQA_HeadlessBatch',s)
        self.assertIn('WAIT_Headless_ExcludeGroup',s)

    def test_seat_actions_do_not_require_remote_vehicle_movement_authority(self):
        s=self.source().split('params [[',1)[1]
        self.assertNotIn('local _vehicle',s)
        for proof in ('!local _group','local _actor','!local _candidate','local _driver','call _commandsOwned'):
            self.assertIn(proof,s)
        start=(ROOT/'addons/vehicles/functions/drivingOperationStart.sqf').read_text(encoding='utf-8')
        self.assertIn('(local _vehicle && {!isNull driver _vehicle}',start)
        self.assertIn('vehicle leader _group == _vehicle',start)
        driving=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('!local _vehicle',driving)
        for forbidden in ('setOwner','setGroupOwner','forceSpeed','setDriveOnPath','setVelocity','moveInDriver'):
            self.assertNotIn(forbidden,s)

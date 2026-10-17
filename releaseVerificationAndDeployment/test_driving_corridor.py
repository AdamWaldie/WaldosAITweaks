"""Corridor authority and proposal budgets; no physical steering acceptance."""
from pathlib import Path
import math
import unittest
ROOT = Path(__file__).resolve().parents[1]
class CorridorFoundationTests(unittest.TestCase):
    def test_registration_authenticates_remote_curators_and_has_no_movement_authority(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorRegister.sqf').read_text()
        body = source.split('params [[', 1)[1]
        self.assertIn('if (!isServer)', body)
        self.assertIn('getAssignedCuratorLogic', body)
        self.assertIn('WAIT_DrivingCorridorArea', body)
        self.assertIn('curatorEditableObjects _curator', body)
        self.assertIn('count _records >= 32', body)
        self.assertLess(body.index('_area setVariable'), body.index('missionNamespace setVariable'))
        for command in ('doMove', 'setDriveOnPath', 'forceSpeed', 'remoteExecCall [', 'remoteExec [', 'spawn', 'waitUntil'):
            self.assertNotIn(command, body)
    def test_geometry_cannot_move_or_flatten_the_vehicle(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorGeometry.sqf').read_text()
        body = source.split('params [[', 1)[1] + (ROOT / 'addons/vehicles/functions/drivingPathGeometry.sqf').read_text().split('params [[', 1)[1]
        for command in ('doMove', 'setDriveOnPath', 'forceSpeed', 'setPos', 'getTerrainHeightASL', 'spawn', 'waitUntil'):
            self.assertNotIn(command, body)
        self.assertIn('ASLToATL _x', body)
        self.assertIn('"MISSING_SUPPORT"', body)
        self.assertIn('"WET_SUPPORT"', body)
        self.assertIn('surfaceIsWater _sample', body)
        self.assertIn('isNull (_hit select 2)', body)
        self.assertIn('"AREA_CHANGED"', body)
        self.assertIn('"HULL_TOO_WIDE"', body)
    def test_declared_sampling_bound_holds_across_allowed_lengths(self):
        for half_length in range(5, 46):
            segments = math.ceil(2 * (half_length + 30) / 8)
            stations = segments + 1
            self.assertLessEqual(stations, 20)
            self.assertLessEqual(3 * stations + 9 * segments, 231)
            self.assertLessEqual(2 * (half_length + 30) / segments, 8)

    def test_executor_is_finite_and_uses_physical_hull_completion(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        for required in ('serverTime >= (_work get "deadline")', '"hardDeadline"',
                         '"COMMAND_CHANGED"', '"AREA_CHANGED"', 'modelToWorldWorld',
                         'vectorDotProduct _travel < 5', '"PHYSICALLY_CROSSED"',
                         '"CORRIDOR_DEPARTED"', '_work getOrDefault ["entered",false]'):
            self.assertIn(required, source)
        self.assertNotIn('unitReady', source)
        self.assertEqual(source.count('setDriveOnPath'), 1)
        for forbidden in ('addWaypoint', 'deleteWaypoint', 'enableAI', 'setPos', 'spawn', 'waitUntil'):
            self.assertNotIn(forbidden, source)
    def test_controller_owns_one_writer_and_suppresses_route_recovery(self):
        source = (ROOT / 'addons/vehicles/functions/drivingAssistStart.sqf').read_text()
        self.assertIn('call WAIT_fnc_DrivingCorridorStep', source)
        self.assertIn('[_vehicle,_group,"ROUTE_AUTHORITY_ENDED"] call WAIT_fnc_DrivingCorridorRelease', source)
        self.assertIn('_capMps=_capMps min (_corridor select 1)', source)
        self.assertIn('&& {!_corridorActive} && {!_hadCorridor}', source)
        fsm = (ROOT / 'addons/main/fsm/drivingOperation.fsm').read_text()
        for phase in ('CORRIDOR_APPROACH', 'CORRIDOR_CROSS'):
            self.assertIn(phase, fsm)
        release = (ROOT / 'addons/vehicles/functions/drivingCorridorRelease.sqf').read_text()
        self.assertLess(release.index('expectedDestination _operator'), release.index('doStop _driver;'))
        self.assertIn('call WAIT_fnc_CortexExternalTakeover', release)
    def test_full_hull_completion_does_not_accept_centre_only_crossing(self):
        # A centre ten metres past the plane still leaves a 16-metre half-length hull behind it.
        for half_length in (2, 8, 16, 23):
            extension = max(10, math.hypot(half_length, 2) + 6)
            self.assertGreaterEqual(extension - half_length, 5)
        self.assertLess(10 - 16, 5)

    def test_convoy_lead_keeps_one_executor_and_predecessor_followers(self):
        tick = (ROOT / 'addons/vehicles/functions/convoyTick.sqf').read_text()
        step = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        call = '[_group,_lead,_group getVariable ["WAIT_Convoy_Brain",createHashMap],"CONVOY"]'
        self.assertEqual(tick.count(call), 1)
        self.assertLess(tick.index(call), tick.index('private _routeWatch='))
        self.assertIn('if (!_corridorActive && {!_hadCorridor}', tick)
        self.assertIn('if (!_routeDone && {!_corridorActive} && {!_hadCorridor}', tick)
        self.assertIn('_leadLimit=_leadLimit min ((_corridor select 1)*3.6)', tick)
        for guard in ('WAIT_Convoy_LocalRegistry', 'WAIT_Convoy_LocalJobToken',
                      'WAIT_Convoy_ReceivedRevision', '(_mobile select 0) isEqualTo _vehicle',
                      'WAIT_Convoy_DrivingAssist_Enable'):
            self.assertIn(guard, step)
        self.assertIn('_convoy || {missionNamespace getVariable ["WAIT_AIPass_Active",false]}', step)
    def test_convoy_halt_release_and_lead_replacement_retire_only_matching_work(self):
        crew = (ROOT / 'addons/vehicles/functions/convoyCrewLocal.sqf').read_text()
        release = (ROOT / 'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text()
        tick = (ROOT / 'addons/vehicles/functions/convoyTick.sqf').read_text()
        halt = crew.split('if (_phase == "HALT"', 1)[1]
        self.assertLess(halt.index('doStop driver _vehicle;'), halt.index('"CONVOY_HALT",false'))
        self.assertIn('if (!(_vehicle in _keepCrew)', release)
        self.assertIn('"CONVOY_RELEASED",!_preserveMoves,_preserveMoves] call WAIT_fnc_DrivingCorridorRelease', release)
        self.assertIn('"CONVOY_LEAD_CHANGED",false,true', tick)
        fsm = (ROOT / 'addons/main/fsm/convoyOperation.fsm').read_text()
        for phase in ('CORRIDOR_APPROACH', 'CORRIDOR_CROSS'):
            self.assertIn(phase, fsm)

    def test_ordinary_cleanup_cannot_retire_a_convoy_corridor(self):
        release = (ROOT / 'addons/vehicles/functions/drivingAssistRelease.sqf').read_text()
        guard = release.split('private _corridor=', 1)[1].split('private _restore=', 1)[0]
        self.assertIn('param [0,""]) == "ORDINARY"', guard)
        self.assertLess(guard.index('== "ORDINARY"'), guard.index('call WAIT_fnc_DrivingCorridorRelease'))

    def test_convoy_uses_worst_hull_without_multiplying_geometry_probes(self):
        step = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        geometry = (ROOT / 'addons/vehicles/functions/drivingCorridorGeometry.sqf').read_text()
        self.assertEqual(step.count('call WAIT_fnc_DrivingCorridorGeometry'), 1)
        self.assertIn('count (_configuration param [4,[]]) <= 20', step)
        for dimension in range(3):
            self.assertIn(f'_envelope set [{dimension}', step)
            self.assertIn(f'_envelope param [{dimension},0]', geometry)
        self.assertIn('"INVALID_ENVELOPE"', geometry)

    def test_module_payload_values_are_parsed_and_authoritative(self):
        dialog = (ROOT / 'addons/vehicles/functions/zenDrivingCorridorModule.sqf').read_text()
        dispatch = (ROOT / 'addons/vehicles/functions/drivingCorridorDispatch.sqf').read_text()
        for key in ('mode', 'area', 'position', 'transform', 'facing', 'halfLength', 'halfWidth', 'speed', 'serial', 'expires'):
            self.assertIn(f'["{key}",', dialog)
            self.assertIn(f'getOrDefault ["{key}"', dispatch)
        self.assertLess(dispatch.index('isNull _curator'), dispatch.index('createUnit ['))
        self.assertLess(dispatch.index('_expires <= serverTime'), dispatch.index('createUnit ['))
        self.assertLess(dispatch.index('isNotEqualTo _transform'), dispatch.index('createUnit ['))
        self.assertIn('_serial == (_previous select 0)', dispatch)
        self.assertIn('count _receipts >= 64', dispatch)
        self.assertLess(dispatch.index('Corridor area budget reached'), dispatch.index('createGroup [sideLogic,true]'))
        self.assertIn('WAIT_DrivingCorridor_LocalSerial', dispatch)
        self.assertIn('addCuratorEditableObjects', dispatch)
        self.assertIn('createGroup [sideLogic,true]', dispatch)
        self.assertIn('setGroupOwner _replyOwner', dispatch)
        self.assertNotIn('createVehicle [', dispatch)
        self.assertIn('"WAIT_DrivingCorridorArea"', dispatch)
        self.assertNotIn('setDriveOnPath', dispatch)
    def test_native_module_is_disposable_and_persistent_area_has_no_recursive_module_function(self):
        config = (ROOT / 'addons/main/config.cpp').read_text()
        area = config.split('class WAIT_DrivingCorridorArea: Logic {', 1)[1].split('};', 1)[0]
        self.assertNotIn('function =', area)
        module = (ROOT / 'addons/vehicles/functions/moduleDrivingCorridor.sqf').read_text()
        self.assertIn('!_activated', module)
        self.assertIn('WAIT_processed', module)
        self.assertIn('deleteVehicle _logic;', module)
        self.assertIn('[_position,_target,_facing] call WAIT_fnc_ZenDrivingCorridorModule', module)

    def test_tail_passage_has_no_second_movement_or_speed_writer(self):
        source = (ROOT / 'addons/vehicles/functions/convoyCorridorStep.sqf').read_text().split('params [[',1)[1]
        for command in ('doMove', 'doFollow', 'doStop', 'forceSpeed', 'setDriveOnPath', 'addWaypoint',
                        'deleteWaypoint', 'setCurrentWaypoint', 'lineIntersects', 'nearEntities', 'spawn', 'waitUntil'):
            self.assertNotIn(command, source)
        self.assertIn('count _rows > 20', source)
        self.assertIn('modelToWorldWorld', source)
        self.assertIn('_crossed == count _rows && {count _rows > 0}', source)
        self.assertIn('"ALL_VEHICLES_PHYSICALLY_CROSSED","COMPLETE"', source)
        self.assertIn('"TAIL_TIMEOUT"', source)
        self.assertIn('_terminal param [6,[]]', source)
        self.assertIn('isNotEqualTo _identity', source)
        self.assertIn('["LEAD_"+(_leadResult', source)
    def test_tail_deadline_is_frozen_at_admission_and_not_renewed_by_owner(self):
        step = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        passage = (ROOT / 'addons/vehicles/functions/convoyCorridorStep.sqf').read_text()
        self.assertIn('min 1800', step)
        self.assertIn('["tailDeadline",_tailDeadline]', step)
        self.assertIn('["deadline",_work get "tailDeadline"]', passage)
        self.assertNotIn('set ["deadline"', passage)
        self.assertIn('"DESTINATION_CLEARANCE"', step)
        self.assertIn('waypointCompletionRadius _waypoint max 20', step)
    def test_tail_caps_and_settlement_use_existing_convoy_callback(self):
        tick = (ROOT / 'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertEqual(tick.count('call WAIT_fnc_ConvoyCorridorStep'), 1)
        self.assertIn('private _settled = !_passageActive && {!_bypassPassageActive} && {_routeDone}', tick)
        self.assertLess(tick.index('_limit=_limit min ((_passageCaps'), tick.index('_vehicle forceSpeed _ownedSpeed'))
        self.assertIn('"CORRIDOR_TAIL"', (ROOT / 'addons/main/fsm/convoyOperation.fsm').read_text())
    def test_tail_cleanup_matches_original_revision_and_preserves_authored_progression(self):
        passage = (ROOT / 'addons/vehicles/functions/convoyCorridorStep.sqf').read_text()
        self.assertIn('(_episode get "revision") == _revision', passage)
        self.assertIn('currentWaypoint _group < _index', passage)
        self.assertIn('WAIT_AIPass_ZeusHold', passage)
        self.assertIn('WAIT_fnc_AuthoredRouteReceipt', passage)
        crew = (ROOT / 'addons/vehicles/functions/convoyCrewLocal.sqf').read_text()
        self.assertIn('_revision >= (_passage get "revision")', crew)

    def test_separate_commander_and_driver_have_symmetric_authority_checks(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        crew = source.split('private _crewReady={',1)[1].split('private _controllerCurrent=',1)[0]
        for guard in ('[_driver,_operator] findIf', 'local _x', 'group _x != _group',
                      'vehicle _x != _vehicle', 'isPlayer _x', 'remoteControlled _x',
                      'CortexCombatEffective', 'CortexExternalOwner', 'checkAIFeature "MOVE"',
                      'checkAIFeature "PATH"', 'currentCommand _x'):
            self.assertIn(guard, crew)
        self.assertNotIn('_driver isEqualTo _operator', source)
        crossing = source.split('if (_phase == "APPROACH")',1)[1].split('if (_phase == "CROSS")',1)[0]
        self.assertLess(crossing.index('doStop _operator'), crossing.index('setDriveOnPath'))
        self.assertLess(crossing.index('doStop _driver'), crossing.index('setDriveOnPath'))
        self.assertIn('["driverCommand",+(expectedDestination _driver)]', crossing)
    def test_crossing_and_handback_preserve_both_seat_commands(self):
        source = (ROOT / 'addons/vehicles/functions/drivingCorridorStep.sqf').read_text()
        release = (ROOT / 'addons/vehicles/functions/drivingCorridorRelease.sqf').read_text()
        for text in (source, release):
            self.assertIn('expectedDestination _driver', text)
            self.assertIn('getOrDefault ["driverCommand",[]]', text)
            self.assertNotIn('enableAI', text.split('params [[',1)[1])
            self.assertNotIn('disableAI', text.split('params [[',1)[1])
        self.assertIn('vehicle _operator == _vehicle', release)
        self.assertLess(release.index('_driver doFollow _operator'), release.index('_operator doMove waypointPosition'))

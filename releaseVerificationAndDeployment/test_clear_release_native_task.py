"""Clear-release authority regressions; not physical handover acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class ClearReleaseNativeTaskTests(unittest.TestCase):
    def test_new_nonmovement_tasks_cannot_grant_formation_recall(self):
        def owned(command,matching_destination):
            return command in ("","STOP") or (command=="MOVE" and matching_destination)
        for command in ("FOLLOW","ATTACK","WAIT","FIRE","SUPPRESS","HIDE","EXPECT","JOIN","SCRIPTED"):
            self.assertFalse(owned(command,True),command)
        self.assertTrue(owned("MOVE",True))
        self.assertFalse(owned("MOVE",False))
        self.assertTrue(owned("STOP",False))
        self.assertTrue(owned("",False))

    def test_recall_boundary_requires_allowed_command_and_move_receipt(self):
        s=(ROOT/'addons/infantry/functions/cortexClearRelease.sqf').read_text()
        start=s.index('private _movementOwned=')
        end=s.index('if (_restore && {_taskFree} && {_movementOwned} && {isNull objectParent _x})',start)
        guard=s[start:end]
        self.assertIn('currentCommand _x in ["","STOP"]',guard)
        self.assertIn('currentCommand _x == "MOVE"',guard)
        self.assertIn('_destination vectorDistance _issued <= 0.25',guard)
        self.assertNotIn('!= "MOVE"',guard)
        self.assertLess(end,s.index('_x doFollow _leader',end))


class ClearFinishNativeTaskTests(unittest.TestCase):
    def test_egress_and_finish_share_the_native_task_guard(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        start=s.index('private _exitMovementOwned=')
        end=s.index('private _activeOwnMove=',start)
        self.assertIn('currentCommand _actor in ["","STOP"] || {[_actor] call _ownsCurrentMove}',s[start:end])
        self.assertIn('&& {[_x] call _exitMovementOwned}) then {',s)
        self.assertIn('if !([_unit] call _exitMovementOwned) then {',s)
        self.assertIn('if !([_actor] call _exitMovementOwned) then {',s)
        self.assertIn('_diverted pushBackUnique _unit;',s)
        self.assertIn('_diverted pushBackUnique _actor;',s)
        self.assertIn('_job set ["egressFailed",true]',s)


class EarlyExitNativeTaskTests(unittest.TestCase):
    def test_early_exit_arrival_and_recovery_preserve_native_tasks(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        service=s.split('private _earlyExits=_job getOrDefault ["earlyExits",createHashMap];',1)[1].split('// An early arrival supports ongoing clearance',1)[0]
        self.assertIn('|| {!([_actor] call _exitMovementOwned)}',service)
        self.assertLess(service.index('call _exitMovementOwned'),service.index('doStop _actor'))
        self.assertIn('_record set [3,"DIVERTED"]',service)
        self.assertIn('_job set ["egressFailed",true]',service)
        recovery=service.split('serverTime-(_motion select 1) >= 8',1)[1]
        self.assertLess(recovery.index('call _exitMovementOwned'),recovery.index('call WAIT_fnc_RecoveryStep'))


class DoorObservationAuthorityTests(unittest.TestCase):
    def test_metadata_discovery_cannot_open_or_consume_cooldown(self):
        s=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        cutoff=s.index('if (_metadataOnly) exitWith {false};')
        self.assertLess(s.index('WAIT_Cortex_DoorDefinitions'),cutoff)
        self.assertLess(cutoff,s.index('call BIS_fnc_door'))
        self.assertLess(cutoff,s.index('setVariable ["WAIT_Cortex_DoorRequestUntil"'))
        final=s.split('if (_near && {_visible}',1)[1].split('call BIS_fnc_door',1)[0]
        for gate in ('currentCommand _unit != "STOP"','local _unit','simulationEnabled _unit',
                     '!isObjectHidden _unit','checkAIFeature "MOVE"','checkAIFeature "PATH"',
                     'vectorDistance _position <= 3','isNull objectParent _unit'):
            self.assertIn(gate,final)
        caller=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        discovery=caller.split('// Before exterior actors commit',1)[1].split('private _allLocked=',1)[0]
        self.assertIn('["CLEAR",_job get "generation"],true] call WAIT_fnc_CortexBuildingDoor',discovery)

    def test_context_binds_actual_building_assignment_and_native_task(self):
        s=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        context=s.split('private _key=switch',1)[1].split('if (isNull _unit',1)[0]
        for guard in ('call WAIT_fnc_CortexActorMoveReserved','currentCommand _unit in ["","MOVE"]',
                      'getOrDefault ["building",objNull]) == _building','WAIT_AIPass_GarrisonPos',
                      '(_assignment select 2) == _building','(_assignment select 3) isEqualTo',
                      'WAIT_Cortex_GarrisonMove','_live vectorDistance (_receipt select 3) <= 0.25',
                      'call WAIT_fnc_NativeOrderReceipt','getOrDefault ["team",[]]'):
            self.assertIn(guard,context)
        garrison=(ROOT/'addons/infantry/functions/cortexGarrisonApplyLocal.sqf').read_text()
        delayed=garrison.split('private _commandOwned=',1)[1].split('private _pending =',1)[0]
        self.assertIn('_command in ["","STOP"]',delayed)
        self.assertIn('_command == "MOVE"',delayed)
        self.assertNotIn('!(_command in',delayed)

    def test_garrison_reapplication_distinguishes_fresh_actors_from_adoption(self):
        s=(ROOT/'addons/infantry/functions/cortexGarrisonApplyLocal.sqf').read_text()
        admission=s.split('private _mayIssueMovement = {',1)[1].split('private _rememberMove =',1)[0]
        for guard in ('_actor in _freshActors','count _receipt == 5',
                      '(_receipt select 4) isEqualTo _assignment','_live vectorDistance (_receipt select 3) <= 0.25',
                      'call WAIT_fnc_CortexGarrisonArrived'):
            self.assertIn(guard,admission)
        self.assertIn('!_heldInPlace && {_unit in _freshActors}',s)
        self.assertIn('private _atPost=[_unit,_assignment] call _assignmentArrived;',s)
        hold=s.split('if (_atPost &&',1)[1].split('if (!_atPost',1)[0]
        self.assertIn('call _rememberMove',hold)
        self.assertNotIn('doMove',hold)
        self.assertIn('currentCommand _unit == "MOVE"',hold)
        self.assertIn('(expectedDestination _unit) param [0,_destination]',hold)
        explicit=(ROOT/'addons/infantry/functions/cortexGarrison.sqf').read_text()
        self.assertIn('[_group,_units] call WAIT_fnc_CortexGarrisonApplyLocal',explicit)
        self.assertIn('call WAIT_fnc_CortexActorMoveReserved',explicit.split('private _units =',1)[1].split('if (_units isEqualTo',1)[0])
        refill=(ROOT/'addons/infantry/functions/cortexGarrisonRefill.sqf').read_text()
        self.assertIn('[_group,[_actor]] call WAIT_fnc_CortexGarrisonApplyLocal',refill)
        self.assertIn('currentCommand _actor in ["","STOP"]',refill)
        discover=(ROOT/'addons/core/functions/cortexDiscover.sqf').read_text()
        self.assertIn('[_group] call WAIT_fnc_CortexGarrisonApplyLocal',discover)

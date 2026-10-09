"""Cortex operational regression contracts. Engine acceptance is in cortexQA, not simulated here."""
from pathlib import Path
import json
import re
import unittest
ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'addons/main/functions/Cortex'
def source(name): return next((ROOT/'addons').rglob(name+'.sqf')).read_text(encoding='utf-8')
class CortexOperations(unittest.TestCase):
    def test_group_tactics_fsm_owns_the_persistent_ground_brain(self):
        discover=source('cortexDiscover')
        start=source('groupBrainStart')
        queue=source('groupBrainQueue')
        step=source('groupBrainStep')
        fsm=(ROOT/'addons/main/fsm/groupTactics.fsm').read_text(encoding='utf-8')
        self.assertIn('WAIT_fnc_GroupBrainStart',discover)
        self.assertNotIn('[WAIT_fnc_CortexGroupTick,_groupJob',discover)
        self.assertIn('groupTactics.fsm',start)
        self.assertIn('WAIT_fnc_CortexQueueJob',queue)
        self.assertIn('WAIT_fnc_GroupBrainStep',queue)
        self.assertIn('ownerEpoch',step)
        self.assertIn('WAIT_GroupBrain_Generation',step)
        self.assertIn('WAIT_fnc_CortexZeusHeld',step)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',step)
        self.assertIn('WAIT_fnc_CortexGroupTick',step)
        for state in ['Calm','Contact','Support','Manoeuvre','Assault','Clear','Security','Withdraw']:
            self.assertIn('class '+state,fsm)
        self.assertIn('WAIT_GroupBrain_Generation',fsm)
        self.assertIn('WAIT_fnc_CortexZeusHeld',fsm)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',fsm)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        waiting=fsm[fsm.index('class Waiting'):fsm.index('class Finished',fsm.index('class Waiting'))]
        self.assertIn('class Zeus',waiting)
        self.assertIn('class External',waiting)
        self.assertLess(waiting.index('class Zeus'),waiting.index('class SchedulerWatchdog'))
        self.assertLess(waiting.index('class External'),waiting.index('class SchedulerWatchdog'))
        self.assertIn('(_brain getOrDefault [""queuedAt"",time])+15',fsm)
        self.assertIn('WAIT_AIPass_NextJobDue',fsm)
        self.assertIn('WAIT_AIPass_ResumeGraceUntil',fsm)
        self.assertIn('WAIT_fnc_CortexIsPaused',fsm)
        self.assertIn('if (_brain getOrDefault ["cancelled",false]) exitWith',step)
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('schedulerWatchdogs=',diagnostics)
        self.assertIn('only wakes the same keyed shared-scheduler job',diagnostics)

    def test_persistent_fsm_watchdogs_only_recover_real_scheduler_starvation(self):
        for name in [
            "groupTactics.fsm",
            "buildingOperation.fsm",
            "convoyOperation.fsm",
            "supportRequest.fsm",
            "artilleryMission.fsm",
            "airAttackOperation.fsm",
        ]:
            fsm = (ROOT / "addons/main/fsm" / name).read_text(encoding="utf-8")
            with self.subTest(fsm=name):
                self.assertIn('(_brain getOrDefault [""queuedAt"",time])+15', fsm)
                self.assertNotIn('(_brain getOrDefault [""queuedAt"",time])+3', fsm)
                self.assertIn('WAIT_AIPass_ResumeGraceUntil', fsm)
                self.assertIn('WAIT_fnc_CortexIsPaused', fsm)
    def test_building_operation_fsm_owns_clearance_progression(self):
        clear=source('cortexClearBuilding')
        start=source('buildingOperationStart')
        queue=source('buildingOperationQueue')
        step=source('buildingOperationStep')
        release=source('cortexClearRelease')
        locality=source('cortexLocality')
        stop=source('cortexStop')
        fsm=(ROOT/'addons/main/fsm/buildingOperation.fsm').read_text(encoding='utf-8')
        self.assertIn('WAIT_fnc_BuildingOperationStart',clear)
        self.assertNotIn('}, createHashMapFromArray [',clear)
        self.assertIn('buildingOperation.fsm',start)
        self.assertIn('WAIT_fnc_CortexQueueJob',queue)
        self.assertIn('WAIT_fnc_BuildingOperationStep',queue)
        self.assertIn('WAIT_AIPass_ClearGeneration',step)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',step)
        self.assertIn('WAIT_fnc_OperationStep',step)
        self.assertIn('vectorDistance (AGLToASL',step)
        self.assertIn('WAIT_fnc_RecoveryStep',step)
        for state in ['Entry','Sweep','Replan','Egress']:
            self.assertIn('class '+state,fsm)
        self.assertIn('WAIT_fnc_CortexZeusHeld',fsm)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',fsm)
        self.assertIn('WAIT_fnc_CortexClearRelease',fsm)
        self.assertIn('WAIT_BuildingBrain',release)
        self.assertIn('WAIT_BuildingBrain',locality)
        self.assertIn('WAIT_BuildingBrain',stop)
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('wait-building-fsm-',diagnostics)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        waiting=fsm[fsm.index('class Waiting'):fsm.index('class Finished',fsm.index('class Waiting'))]
        self.assertIn('class Zeus',waiting)
        self.assertIn('class External',waiting)
        self.assertLess(waiting.index('class Zeus'),waiting.index('class SchedulerWatchdog'))
        self.assertLess(waiting.index('class External'),waiting.index('class SchedulerWatchdog'))
        self.assertIn('watchdogCount',start+fsm+diagnostics)
        self.assertIn('if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith {-1}',step)
    def test_convoy_operation_fsm_replaces_persistent_scheduler_job(self):
        sync=source('convoySync');adopt=source('convoyHeadlessAdoptLocal');start=source('convoyOperationStart');queue=source('convoyOperationQueue');step=source('convoyOperationStep');release=source('convoyReleaseLocal')
        fsm=(ROOT/'addons/main/fsm/convoyOperation.fsm').read_text(encoding='utf-8')
        self.assertIn('WAIT_fnc_ConvoyOperationStart',sync+adopt)
        self.assertNotIn('WAIT_fnc_ConvoyJobStep',sync+adopt)
        self.assertIn('convoyOperation.fsm',start)
        self.assertIn('WAIT_fnc_CortexQueueJob',queue)
        self.assertIn('WAIT_fnc_ConvoyOperationStep',queue)
        self.assertIn('WAIT_fnc_ConvoyTick',step)
        self.assertIn('WAIT_Convoy_ReceivedRevision',step)
        for state in ['Cruise','Spacing','Recovery','ContactHold','OrderedHold','Obstruction','Arrived']: self.assertIn('class '+state,fsm)
        self.assertIn('WAIT_fnc_CortexZeusHeld',fsm)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',fsm)
        self.assertIn('WAIT_Convoy_Brain',release)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        waiting=fsm[fsm.index('class Waiting'):fsm.index('class Finished',fsm.index('class Waiting'))]
        self.assertIn('class Zeus',waiting)
        self.assertIn('class External',waiting)
        self.assertLess(waiting.index('class Zeus'),waiting.index('class SchedulerWatchdog'))
        self.assertLess(waiting.index('class External'),waiting.index('class SchedulerWatchdog'))
        self.assertIn('watchdogCount',start+fsm+source('aiGetDiagnostics'))
        self.assertIn('if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith',step)

    def test_air_attack_operation_fsm_owns_phase_persistence(self):
        discover=source('cortexDiscover');combined=source('cortexCombinedArmsLocal')
        start=source('airAttackOperationStart');queue=source('airAttackOperationQueue');step=source('airAttackOperationStep')
        attack=source('cortexAirAttack');diagnostics=source('aiGetDiagnostics')
        fsm=(ROOT/'addons/main/fsm/airAttackOperation.fsm').read_text(encoding='utf-8')
        self.assertIn('WAIT_fnc_AirAttackOperationStart',discover+combined)
        self.assertNotIn('[WAIT_fnc_CortexAirAttack,',discover+combined)
        self.assertIn('airAttackOperation.fsm',start)
        self.assertIn('WAIT_fnc_CortexQueueJob',queue)
        self.assertIn('WAIT_fnc_AirAttackOperationStep',queue)
        self.assertIn('call WAIT_fnc_CortexAirAttack',step)
        self.assertIn('WAIT_AirAttack_BrainGeneration',start+queue+step+fsm)
        self.assertIn('current caller: wait_fnc_airattackoperationstep',attack.lower())
        for state in ['Plan','Ingress','Attack','Egress']:
            self.assertIn('class '+state,fsm)
        self.assertIn('WAIT_fnc_CortexZeusHeld',fsm)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',fsm)
        self.assertIn('call WAIT_fnc_CortexAirAttack',fsm)
        waiting=fsm[fsm.index('class Waiting'):fsm.index('class Finished',fsm.index('class Waiting'))]
        self.assertLess(waiting.index('class Zeus'),waiting.index('class SchedulerWatchdog'))
        self.assertLess(waiting.index('class External'),waiting.index('class SchedulerWatchdog'))
        self.assertIn('WAIT_AirAttack_Brain_State',diagnostics)
        stop=source('cortexStop')
        self.assertIn('WAIT_AirAttack_Brain',stop)
        self.assertIn('"CORTEX_STOPPED"',stop)
        self.assertIn('call WAIT_fnc_CortexAirAttack',stop)
        self.assertIn('WAIT_AirAttack_BrainGeneration',stop)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        self.assertIn('watchdogCount',start+fsm+diagnostics)
        self.assertIn('if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith',step)

    def test_artillery_mission_fsm_owns_fire_sequence_persistence(self):
        fire=source('cortexArtilleryFire');bounded=source('cortexArtilleryMissionStep')
        start=source('artilleryMissionStart');queue=source('artilleryMissionQueue');step=source('artilleryMissionStep')
        stop=source('cortexStop');diagnostics=source('aiGetDiagnostics')
        fsm=(ROOT/'addons/main/fsm/artilleryMission.fsm').read_text(encoding='utf-8')
        self.assertIn('WAIT_fnc_ArtilleryMissionStart',fire)
        self.assertNotIn('[WAIT_fnc_CortexArtilleryMissionStep, _mission, 0]',fire)
        self.assertIn('artilleryMission.fsm',start)
        self.assertIn('WAIT_fnc_CortexQueueJob',queue)
        self.assertIn('WAIT_fnc_ArtilleryMissionStep',queue)
        self.assertIn('call WAIT_fnc_CortexArtilleryMissionStep',step)
        self.assertIn('WAIT_AIPass_FireMissions',start+step)
        self.assertIn('WAIT_Artillery_BrainGeneration',start+queue+step+fsm)
        self.assertIn('no fire command is retried',step.lower())
        self.assertIn('current caller: wait_fnc_artillerymissionstep',bounded.lower())
        for state in ['Requested','Warning','Firing','Relocating']:
            self.assertIn('class '+state,fsm)
        self.assertIn('WAIT_Artillery_Brain',stop)
        self.assertIn('wait-artillery-fsm-',diagnostics)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        self.assertIn('watchdogCount',start+fsm+diagnostics)
        self.assertIn('if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith',step)

    def test_support_request_fsm_owns_cross_squad_persistence(self):
        server=source('cortexSupportServer');bounded=source('cortexSupportStep')
        start=source('supportRequestStart');queue=source('supportRequestQueue');step=source('supportRequestStep')
        stop=source('cortexStop');diagnostics=source('aiGetDiagnostics')
        fsm=(ROOT/'addons/main/fsm/supportRequest.fsm').read_text(encoding='utf-8')
        self.assertIn('WAIT_fnc_SupportRequestStart',server)
        self.assertNotIn('[WAIT_fnc_CortexSupportStep,_job,1]',server)
        self.assertIn('supportRequest.fsm',start)
        self.assertIn('WAIT_fnc_CortexQueueJob',queue)
        self.assertIn('WAIT_fnc_SupportRequestStep',queue)
        self.assertIn('call WAIT_fnc_CortexSupportStep',step)
        self.assertIn('WAIT_AIPass_SupportRequests',start+step)
        self.assertIn('WAIT_Support_BrainGeneration',start+queue+step+fsm)
        self.assertIn('current caller: wait_fnc_supportrequeststep',bounded.lower())
        for state in ['Discover','Reserve','Coordinate']:
            self.assertIn('class '+state,fsm)
        self.assertIn('WAIT_Support_Brain',stop)
        self.assertIn('wait-support-fsm-',diagnostics)
        self.assertIn('_brain set ["queuedAt",time]',queue)
        self.assertIn('class SchedulerWatchdog',fsm)
        self.assertIn('WAIT_fnc_CortexZeusHeld',fsm)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',fsm)
        self.assertIn('call WAIT_fnc_CortexSupportStep',fsm)
        waiting=fsm[fsm.index('class Waiting'):fsm.index('class Finished',fsm.index('class Waiting'))]
        self.assertLess(waiting.index('class Zeus'),waiting.index('class SchedulerWatchdog'))
        self.assertLess(waiting.index('class External'),waiting.index('class SchedulerWatchdog'))
        self.assertIn('watchdogCount',start+fsm+diagnostics)
        self.assertIn('if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith',step)

    def test_aircraft_controllers_share_one_generation_owned_flight_lease(self):
        acquire=source('flightLeaseAcquire');valid=source('flightLeaseValid');release=source('flightLeaseRelease')
        attack_start=source('airAttackOperationStart');attack=source('cortexAirAttack')
        landing=source('improvedHelicopterLandingExecuteLocal');landing_release=source('improvedHelicopterLandingRestoreLocal')
        landing_anchor=source('improvedHelicopterLandingAnchorLocal')
        defence=source('cortexMissileDefenceStep');deceleration=source('helicopterDecelerationCorrectLocal')
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('WAIT_FlightLease',acquire+valid+release)
        self.assertIn('WAIT_fnc_CortexZeusHeld',acquire)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',acquire)
        self.assertIn('_priority <= (_lease getOrDefault ["priority",0])',acquire)
        self.assertIn('(_lease getOrDefault ["owner",-1]) != clientOwner',acquire)
        self.assertIn('"AIR_ATTACK",_leaseToken,300',attack_start)
        self.assertIn('"AIR_ATTACK",_flightLeaseToken',attack)
        self.assertIn('"LANDING",_flightLeaseToken,500',landing)
        self.assertIn('"LANDING",str _releasedRevision',landing_release)
        self.assertIn('"LANDING",str _controlRevision',landing_anchor)
        self.assertIn('"MISSILE_DEFENCE",_flightLeaseToken,400',defence)
        self.assertIn('"DECELERATION",_flightLeaseToken,100',deceleration)
        self.assertIn('wait-flight-lease-',diagnostics)

    def test_scheduler_diagnostics_clear_transient_skip_state_after_resumption(self):
        scheduler=source('cortexSchedulerTick')
        self.assertIn('_state set ["skippedReason","PAUSED"]',scheduler)
        self.assertIn('_state deleteAt "skippedReason"',scheduler)
        self.assertLess(scheduler.index('_state set ["skippedReason","PAUSED"]'),scheduler.index('_state deleteAt "skippedReason"'))

    def test_danger_observations_preserve_one_tactical_owner(self):
        engine=source('dangerEngineSubmit')
        engine_act=source('dangerEngineAct')
        engine_continue=source('dangerEngineCanContinue')
        engine_release=source('dangerEngineRelease')
        engine_recycle=source('dangerEngineRecycle')
        vehicle_profile=source('dangerVehicleProfile')
        engine_mode=source('dangerEngineMode')
        engine_select=source('dangerEngineSelect')
        danger_cover=source('dangerCoverStep')
        danger_smoke=source('dangerSmokeStep')
        engine_fsm=(ROOT/'addons/danger/danger.fsm').read_text()
        # fsmDanger is loaded directly by the engine rather than through execFSM. The Arma FSM
        # compiler requires the named scripted-FSM envelope; a bare class parses as config text
        # during packaging but produces "FSM ... cannot be loaded" at runtime.
        self.assertTrue(engine_fsm.startswith('/*%FSM<COMPILE "scriptedFSM.cfg, Danger">*/'))
        self.assertTrue(engine_fsm.rstrip().endswith('/*%FSM</COMPILE>*/'))
        self.assertIn('/*%FSM<HEAD>*/',engine_fsm)
        self.assertRegex(engine_fsm,r'item0\[\]\s*=\s*\{"Start_Danger",0,250')
        self.assertRegex(engine_fsm,r'link44\[\]\s*=\s*\{38,39\};')
        self.assertRegex(engine_fsm,r'link45\[\]\s*=\s*\{41,40\};')
        self.assertIn('/*%FSM<STATE "Start_Danger">*/',engine_fsm)
        self.assertIn('/*%FSM<STATEINIT',engine_fsm)
        self.assertIn('/*%FSM<CONDITION',engine_fsm)
        runtime_fsm=engine_fsm.split('class FSM',1)[1]
        self.assertEqual(42,len(re.findall(r'\bitemno\s*=\s*\d+;',runtime_fsm)))
        self.assertEqual(42,len(re.findall(r'\bprecondition\s*=',runtime_fsm)))
        editor_items=[int(value) for value in re.findall(r'item(\d+)\[\]\s*=',engine_fsm.split('class FSM',1)[0])]
        self.assertEqual(list(range(42)),editor_items)
        editor_link_ids=[int(value) for value in re.findall(r'link(\d+)\[\]\s*=',engine_fsm.split('class FSM',1)[0])]
        self.assertEqual(list(range(46)),editor_link_ids)
        editor_links=[tuple(map(int,values)) for values in re.findall(r'link\d+\[\]\s*=\s*\{(\d+),(\d+)\}',engine_fsm.split('class FSM',1)[0])]
        self.assertTrue(editor_links)
        self.assertTrue(all(source_id in editor_items and target_id in editor_items for source_id,target_id in editor_links))
        engine_source=(ROOT/'tools/fsm/danger.bifsm').read_text()
        self.assertIn('InitCode=',engine_source)
        self.assertIn('Condition=',engine_source)
        request=source('dangerRequest')
        step=source('dangerStep')
        selection=source('dangerSelect')
        action=source('dangerActionSelect')
        setup=source('dangerSetup')
        scheduler=source('cortexSchedulerTick')
        contact_fixture=(ROOT/'releaseVerificationAndDeployment/cortexQA/runContact.sqf').read_text(encoding='utf-8')
        danger_load=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDangerLoad.sqf').read_text(encoding='utf-8')
        server_audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('_focus == "dangerload"',server_audit)
        self.assertIn('cortexQADangerLoad.sqf',server_audit)
        self.assertIn('DANGERLOAD-engine-event-accepted',danger_load)
        self.assertIn('DANGERLOAD-physical-reflex',danger_load)
        self.assertIn('DANGERLOAD-finite-exact-release',danger_load)
        self.assertIn('createVehicle ["GrenadeHand"',danger_load)
        self.assertNotIn('WAIT_fnc_DangerEngineSubmit',danger_load)
        self.assertIn('_holdUnits findIf {(_x getVariable ["WAIT_CortexQA_Shots",0]) > 0} >= 0',contact_fixture)
        self.assertNotIn('{{_x getVariable ["WAIT_CortexQA_Shots",0]} count _holdUnits > 0}',contact_fixture)
        self.assertIn('!local _group',request)
        self.assertIn('{local _group}',setup)
        self.assertIn('select [0,16]',request)
        self.assertIn('select [0,16]',selection)
        self.assertIn('_expires > _now',selection)
        self.assertNotIn(' sort ',selection)
        self.assertIn('WAIT_GroupBrain',step)
        self.assertIn('_brain set ["wakeAt",time]',step)
        self.assertIn('_brain set ["nextAt",time]',step)
        self.assertIn('private _effectiveResponse=_group getVariable ["WAIT_Danger_Response",[]]',step)
        self.assertIn('_effectiveResponse select 3',step)
        self.assertIn('_brain set ["responsiveUntil",_responsiveUntil max (_brain getOrDefault ["responsiveUntil",0])]',step)
        self.assertNotIn('_brain set ["responsiveUntil",time+_responseLifetime]',step)
        self.assertIn('WAIT_fnc_GroupBrainStart',step)
        self.assertIn('_state deleteAt "wakeAt"',scheduler)
        self.assertIn('getOrDefault ["wakeAt",_dueAt]',scheduler)
        self.assertIn('getOrDefault ["responsiveUntil",-1]',scheduler)
        for body in [engine,engine_act,engine_continue,engine_mode,engine_select,request,step,selection,setup]:
            body=re.sub(r"/\*.*?\*/|//[^\n]*", "", body, flags=re.DOTALL)
            for forbidden in [' reveal ', ' doMove ', ' doTarget ', 'allUnits', 'allGroups', 'CortexQueueJob']:
                self.assertNotIn(forbidden,body)
        self.assertIn('ownerEpoch',step)
        self.assertIn('WAIT_Danger_Generation',step)
        self.assertIn('WAIT_Danger_Response',step)
        self.assertIn('WAIT_Danger_Action',step)
        self.assertIn('WAIT_Danger_VehicleContext',step)
        self.assertIn('WAIT_fnc_DangerVehicleProfile',step)
        self.assertIn('WAIT_fnc_DangerSmokeStep',source('cortexGroupTick'))
        for marker in ['WAIT_AIPass_DangerSmoke_Enable','WAIT_Danger_SmokeLease','WAIT_Danger_SmokeAfter',
                       'getSuppression _x >= 0.55','["DANGER",_generation,_expires]',
                       'call WAIT_fnc_CortexThrowGrenade']:
            self.assertIn(marker,danger_smoke)
        self.assertNotIn('sleep ',danger_smoke)
        self.assertNotIn('waitUntil',danger_smoke)
        throw=source('cortexThrowGrenade')
        queued=throw.split('params ["_unit", "_muzzle", "_magazine"',1)[1]
        for marker in ['WAIT_AIPass_DangerSmoke_Enable','WAIT_Danger_Generation','WAIT_fnc_CortexExternalTakeover']:
            self.assertIn(marker,queued)
        self.assertLess(queued.index('WAIT_Danger_Generation'),queued.index('forceWeaponFire'))
        self.assertLess(queued.index('WAIT_Danger_Generation'),queued.index('_unit setDir'))
        self.assertLess(queued.index('WAIT_fnc_CortexExternalTakeover'),queued.index('_unit setDir'))
        self.assertIn('WAIT_fnc_DangerActionSelect',step)
        self.assertIn('private _actor=[_group] call WAIT_fnc_CortexGroupAnchor;',step)
        self.assertIn('[_observer,_cause,_position,_action] call WAIT_fnc_DangerReact',step)
        self.assertIn('time+_responseLifetime',step)
        self.assertIn('time >= (_existing select 3)',step)
        self.assertIn('if (_action == "FORCED") exitWith {',step)
        forced_handoff=step.split('if (_action == "FORCED") exitWith {',1)[1].split('};',1)[0]
        self.assertIn('WAIT_Danger_Response",nil,true',forced_handoff)
        self.assertIn('WAIT_Danger_Action",nil,true',forced_handoff)
        self.assertIn('deleteAt "responsiveUntil"',forced_handoff)
        self.assertNotIn('WAIT_fnc_GroupBrainStart',forced_handoff)
        self.assertNotIn('set ["wakeAt"',forced_handoff)
        self.assertLess(step.index('if (_action == "FORCED") exitWith {'),step.index('private _responseDurations='))
        tick=source('cortexGroupTick')
        self.assertIn('private _dangerTactical=_dangerActive',tick)
        self.assertIn('_responseCause in ["HIT","EXPLOSION","SUPPRESSED"]',tick)
        self.assertIn('_responseCause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"] && {_dangerActionName != "HIDE"}',tick)
        self.assertIn('(_dangerResponse param [0,"",[""]]) in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"] && {_dangerActionName == "HIDE"}',tick)
        self.assertIn('private _selectedIndex=_events findIf {_x isEqualTo _selected};',step)
        self.assertIn('_events deleteAt _selectedIndex',step)
        self.assertIn('_group setVariable ["WAIT_Danger_Events",_remaining];',step)
        self.assertLess(step.index('private _selected=[_events] call WAIT_fnc_DangerSelect;'),step.index('private _selectedIndex=_events findIf {_x isEqualTo _selected};'))
        self.assertIn('private _activeAction=_group getVariable ["WAIT_Danger_Action",[]];',step)
        self.assertIn('(_activeAction param [4,-1,[0]]) == _generation',step)
        self.assertIn('_activeAction param [5,_actor,[objNull]]',step)
        self.assertLess(step.index('private _activeAction=_group getVariable ["WAIT_Danger_Action",[]];'),step.index('private _responseCommand=toUpperANSI (currentCommand _responseActor);'))
        self.assertIn('in ["HIT","EXPLOSION","SUPPRESSED","GUNFIRE"]',tick)
        self.assertIn('_cause in [1,2,4,9]',engine_act)
        self.assertIn('private _dangerAlert=_dangerActive',tick)
        self.assertIn('in ["CASUALTY","BODY_FOUND","SCREAM"]',tick)
        self.assertIn('private _dangerVehicleSafety=_dangerActive && {_dangerActionName == "VEHICLE"};',tick)
        self.assertIn('private _dangerContact=_group getVariable ["WAIT_Danger_Contact",[]];',tick)
        self.assertIn('private _dangerVehicleContact=_dangerVehicleSafety && {_dangerConfirmed}',tick)
        self.assertIn('_enemies findIf {(_x select 0) == _dangerContactSource} >= 0',tick)
        self.assertIn('[_group,_state,[]] call WAIT_fnc_CortexVehicles;',tick)
        self.assertLess(step.index('private _replace='),step.index('WAIT_fnc_DangerReact', step.index('if (_replace) then {')))
        self.assertIn('Keep the surviving highest-priority response authoritative',step)
        self.assertIn('WAIT_Danger_Response',source('cortexGroupTick'))
        self.assertIn('private _tacticalTier=_nearTier || _dangerTactical',source('cortexGroupTick'))
        self.assertIn('private _nativeCombatResponsive=_seenCount > 0;',source('cortexGroupTick'))
        self.assertIn('_tacticalTier=_tacticalTier || {_nativeCombatResponsive};',source('cortexGroupTick'))
        self.assertIn('_delay=_delay min (["WAIT_AIPass_TickContact",2] call _get);',source('cortexGroupTick'))
        self.assertLess(source('cortexGroupTick').index('private _nativeCombatResponsive=_seenCount > 0;'),source('cortexGroupTick').index('private _navalOwnsMovement='))
        self.assertIn('if (_tacticalTier)',source('cortexGroupTick'))
        self.assertIn('_contactDelay=_contactDelay min 0.5',source('cortexGroupTick'))
        self.assertIn('if (_dangerTactical || {_dangerVehicleContact} || {_visible isNotEqualTo []}) exitWith {call _beginContact};',source('cortexGroupTick'))
        calm=source('cortexGroupTick').split('case "CALM": {',1)[1].split('case "INVESTIGATE": {',1)[0]
        self.assertLess(calm.index('_dangerTactical || {_dangerVehicleContact} || {_visible isNotEqualTo []}'),calm.index('WAIT_AIPass_AreaReport'))
        self.assertIn('private _contactPosition=if (_visible isNotEqualTo [])',source('cortexGroupTick'))
        self.assertIn('_dangerResponse param [1,getPosATL _leader]',source('cortexGroupTick'))
        self.assertIn('["DANGER_CONTACT","VISIBLE_CONTACT"] select (_visible isNotEqualTo [])',source('cortexGroupTick'))
        begin_contact=source('cortexGroupTick').split('private _beginContact = {',1)[1].split('};\n\nswitch',1)[0]
        self.assertGreaterEqual(begin_contact.count('_visible isNotEqualTo []'),3)
        for dispatch in ['WAIT_fnc_CortexContactReport','WAIT_fnc_CortexCombinedArmsRequest','WAIT_fnc_CortexReinforce']:
            self.assertIn('_visible isNotEqualTo []',begin_contact[max(0,begin_contact.index(dispatch)-500):begin_contact.index(dispatch)])
        contact=source('cortexGroupTick').split('case "CONTACT": {',1)[1].split('case "SECURITY": {',1)[0]
        self.assertIn('if (_hasTargetKnowledge) then {',contact)
        self.assertIn('if (_visible isEqualTo []) then {_state set ["enemyPos",+((_enemies select 0) select 1)]}',contact)
        self.assertIn('!_dangerActive',contact)
        self.assertIn('"DANGER_EXPIRED"',contact)
        self.assertLess(contact.index('!_dangerActive'),contact.index('WAIT_AIPass_PostContact_LostSeconds'))
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('private _schedulerQueue=(missionNamespace getVariable ["WAIT_AIPass_Jobs", []]) select [0,20];',diagnostics)
        self.assertIn('"cortex-scheduler"',diagnostics)
        self.assertIn('WAIT_Danger_ObservedContacts',diagnostics)
        self.assertIn('private _dangerObservedGroups=',diagnostics)
        self.assertIn('local observed contacts=',diagnostics)
        self.assertIn('private _dangerConfirmedGroups=',diagnostics)
        self.assertIn('confirmed handoffs=',diagnostics)
        self.assertIn('removeEventHandler',setup)
        self.assertIn('WAIT_Danger_Handlers',setup)
        self.assertNotIn('addEventHandler ["Hit"',setup)
        self.assertNotIn('addEventHandler ["Explosion"',setup)
        self.assertNotIn('addEventHandler ["Suppressed"',setup)
        self.assertNotIn('addEventHandler ["FiredNear"',setup)
        self.assertIn('if (!_enabled) exitWith {',setup)
        self.assertLess(setup.index('if (!_enabled) exitWith {'), setup.index('WAIT_Danger_Response",nil,true'))
        self.assertIn('"EnemyDetected"',setup)
        self.assertIn('WAIT_Danger_GroupHandlers',setup)
        self.assertIn('_group removeEventHandler _x',setup)
        self.assertIn('(side _observingGroup) getFriend (side _target)',setup)
        self.assertIn('private _spotters=(units _observingGroup)',setup)
        self.assertIn('_spotters resize ((count _spotters) min 12)',setup)
        self.assertIn('private _knowerIndex=_spotters findIf {_x knowsAbout _target >= 1};',setup)
        self.assertIn('&& {_leader knowsAbout _target >= 1}',setup)
        self.assertIn('else {_spotters select _knowerIndex}',setup)
        self.assertIn('private _contact=[_target,time+10,_observer];',setup)
        self.assertIn('WAIT_Danger_ObservedContacts',setup)
        self.assertIn('_observer getHideFrom _target',setup)
        self.assertIn('[_observer,"DETECTED",_dangerPosition,_target] call WAIT_fnc_DangerRequest',setup)
        knowledge=source('cortexKnowledge')
        self.assertIn('count _x in [2,3]',knowledge)
        self.assertIn('private _witnesses=[];',knowledge)
        self.assertIn('_witnesses pushBackUnique _witness',knowledge)
        self.assertIn('if (count _members > 8) then {_members resize 8};',knowledge)
        self.assertNotIn('["DETECTED",getPosATL _observer]',setup)
        self.assertIn('time+10',setup)
        self.assertIn('count _contacts > 8',setup)
        self.assertIn('"DETECTED"',request)
        self.assertIn('"DETECTED"',selection)
        self.assertIn('"EXPLOSION"',request)
        self.assertIn('"EXPLOSION"',selection)
        self.assertIn('["HIT",9],["CANFIRE",8],["SUPPRESSED",7],["CASUALTY",6],["SCREAM",5],["PROXIMITY",4],["EXPLOSION",3],["BODY_FOUND",3],["DETECTED",2],["GUNFIRE",1]',selection)
        self.assertIn('"SUPPRESSED","SCREAM","CASUALTY","BODY_FOUND"',action)
        self.assertIn('if (_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"]',action)
        self.assertIn('&& {isNull (_event param [4,objNull,[objNull]])}) exitWith {"HIDE"};',action)
        self.assertLess(action.index('if (_cause in ["DETECTED"'),action.index('exitWith {"MAINTAIN"}'))
        self.assertNotIn('getPosATL _target',setup)
        self.assertIn("_records select [0,12]",engine)
        self.assertIn('private _latestExpiry=createHashMap;',engine)
        self.assertIn('private _latestSourceExpiry=createHashMap;',engine)
        self.assertIn("_expires >= (_latestExpiry getOrDefault [_causeName,-1])",engine)
        self.assertIn("_expires >= (_latestSourceExpiry getOrDefault [_causeName,-1])",engine)
        self.assertIn("'CASUALTY'",engine)
        self.assertIn("'BODY_FOUND'",engine)
        self.assertIn("'EXPLOSION','CASUALTY','BODY_FOUND','SCREAM'",engine)
        self.assertIn("'SCREAM'",engine)
        self.assertIn("'PROXIMITY'",engine)
        self.assertIn("'CANFIRE'",engine)
        self.assertIn('WAIT_fnc_DangerRequest',engine)
        self.assertIn('_latestSource getOrDefault [_x,objNull]',engine)
        self.assertIn('private _priorSource=_prior param [4,objNull,[objNull]];',request)
        self.assertIn('private _sourceObserver=_actor;',request)
        self.assertIn('private _priorObserver=_prior param [6,_prior param [5,objNull,[objNull]],[objNull]];',request)
        self.assertIn('_priorObserver knowsAbout _priorSource > 0',request)
        self.assertIn('private _event=[_cause,+_position,time,time+2,_hostileSource,_actor,_sourceObserver];',request)
        self.assertIn('count _x in [4,5,6,7]',selection)
        self.assertIn('private _actor=_event param [5,objNull,[objNull]];',action)
        self.assertIn('group _actor != _group',action)
        self.assertIn('private _observer=_selected param [5,objNull,[objNull]];',source('dangerStep'))
        self.assertIn('private _sourceObserver=_selected param [6,_observer,[objNull]];',source('dangerStep'))
        self.assertIn('private _activeAction=_group getVariable ["WAIT_Danger_Action",[]];',source('dangerStep'))
        self.assertIn('_activeAction param [5,_actor,[objNull]]',source('dangerStep'))
        self.assertIn('_responseCommand in ["GET IN","ACTION","HEAL","REARM","JOIN"]',source('dangerStep'))
        self.assertLess(source('dangerStep').index('private _activeAction=_group getVariable'),source('dangerStep').index('private _events='))
        self.assertIn('_sourceObserver knowsAbout _source > 0',source('dangerStep'))
        self.assertIn("if (count _latest > 0 && {!(_group getVariable ['WAIT_AIPass_Managed',false])}",engine)
        self.assertIn('[_group,false,true] call WAIT_fnc_CortexIsEligible',engine)
        self.assertIn('[_group] call WAIT_fnc_DangerSetup;',engine)
        self.assertIn('[_group,true] call WAIT_fnc_GroupBrainStart',engine)
        self.assertLess(engine.index('[_group] call WAIT_fnc_DangerSetup;'),engine.index('[_group,true] call WAIT_fnc_GroupBrainStart'))
        preflight=engine.split('private _causeNames=',1)[0]
        self.assertNotIn("|| {!(_group getVariable ['WAIT_AIPass_Managed',false])}",preflight)
        self.assertIn('WAIT_Danger_EngineStats',engine)
        self.assertIn("['bootstraps'",engine)
        self.assertIn("['reflexOnlyRecords'",engine)
        self.assertIn("'ASSESS'",engine)
        self.assertIn("private _groupRelevant=if (_mode in ['FORCED','RELEASE'] || {_cause == 10}) then {false}",engine)
        self.assertIn('if (_cause in [0,3,8]) then {_hostileEngage}',engine)
        self.assertLess(engine.index('private _causeNames='),engine.index('call WAIT_fnc_GroupBrainStart'))
        self.assertIn('WAIT_Danger_EngineStats',engine_act)
        self.assertIn('WAIT_Danger_EngineResponse',engine_act)
        self.assertIn('WAIT_Danger_EngineStanceLease',engine_act)
        self.assertIn('_actor setVariable ["WAIT_Danger_EngineResponse",nil]',engine_release)
        self.assertIn('WAIT_Danger_EngineStanceLease',engine_release)
        self.assertIn('[_x] call WAIT_fnc_DangerEngineRelease',setup)
        self.assertIn('[_x] call WAIT_fnc_DangerEngineRelease',source('cortexReleaseGroup'))
        self.assertIn('DANGER-live-disable-exact-stance-release',contact_fixture)
        self.assertIn('DANGER-live-disable-reenabled',contact_fixture)
        for text in [engine_mode,engine_act,engine_continue]:
            self.assertIn('WAIT_fnc_CortexCombatEffective',text)
        self.assertIn('toUpperANSI (unitPos _actor) != _applied',engine_release)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',engine_release)
        self.assertIn('WAIT_fnc_CortexZeusHeld',engine_release)
        self.assertIn('_actor setUnitPosWeak _prior',engine_release)
        forced_block=engine_act.split('// Forced orders and vehicle crews',1)[1].split('if (_mode == "IMMEDIATE")',1)[0]
        self.assertNotIn('setUnitPos ',forced_block)
        self.assertIn('_records select [0,12]',engine_select)
        self.assertIn('private _priorities=[2,1,9,4,3,6,3,5,8,7,0]',engine_select)
        self.assertLess(engine_select.index('private _priorities='),engine_select.index('forEach (_records select [0,12])'))
        self.assertIn('currentCommand _actor in ["GET IN","ACTION","HEAL","REARM","JOIN"]',engine_mode)
        self.assertNotIn('currentCommand _actor in ["ATTACK"',engine_mode)
        self.assertLess(engine_mode.index('if (!isNull objectParent _actor)'),engine_mode.index('checkAIFeature "MOVE"'))
        self.assertIn('(side _group) getFriend (side _source) < 0.6',engine_mode)
        for danger_source in [engine_mode,engine,request,source('dangerStep'),source('dangerEngineRecycle'),setup,
                              source('cortexGroupTick'),source('cortexVehicles')]:
            self.assertNotIn('getFriend (side group _source)',danger_source)
            self.assertNotIn('getFriend (side group _dangerSource)',danger_source)
            self.assertNotIn('getFriend (side group _dangerContactSource)',danger_source)
            self.assertNotIn('private _targetGroup=group _target',danger_source)
        self.assertIn('else {"ASSESS"}',engine_mode)
        for mode in ['"RELEASE"','"FORCED"','"VEHICLE"','"IMMEDIATE"','"HIDE"','"ENGAGE"','"ASSESS"']:
            self.assertIn(mode,engine_mode+engine_fsm)
        for profile in ['"AIR"','"ARTILLERY"','"STATIC"','"ARMOURED"','"ARMED"','"TRANSPORT"']:
            self.assertIn(profile,vehicle_profile)
        self.assertLess(vehicle_profile.index('artilleryScanner'),vehicle_profile.index('StaticWeapon'))
        self.assertIn('allTurrets [_vehicle,true]',vehicle_profile)
        self.assertNotIn('doMove',vehicle_profile)
        self.assertNotIn('doTarget',vehicle_profile)
        self.assertIn('lastVehicleProfile',engine_act)
        self.assertIn('_actor setUnitPosWeak _desiredStance',engine_act)
        self.assertIn('private _committedMover=',engine_act)
        self.assertIn('_hardCover && {!_committedMover}',engine_act)
        self.assertIn('committed operation movers are never forced prone',diagnostics)
        self.assertIn('finiteCoverMoves=',diagnostics)
        self.assertIn('WAIT_fnc_DangerCoverStep',source('cortexGroupTick'))
        self.assertIn('_responseCause in ["HIT","EXPLOSION","SUPPRESSED"]',source('cortexGroupTick'))
        self.assertIn('getSuppression _actor > 0.45',engine_act)
        self.assertNotIn('_cause in [5,6]',engine_act)
        reaction=source('dangerReact')
        self.assertIn('if (_cause in ["CASUALTY","BODY_FOUND","SCREAM"]) exitWith {"ASSESS"};',reaction)
        self.assertIn('count (_group getVariable ["WAIT_Operation",createHashMap]) > 0',danger_cover)
        self.assertIn('currentCommand _actor != ""',danger_cover)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',danger_cover)
        self.assertIn('WAIT_fnc_CortexZeusHeld',danger_cover)
        self.assertIn('WAIT_fnc_CortexFindCover',danger_cover)
        self.assertIn('_actor doMove _spot',danger_cover)
        self.assertNotIn('while {',danger_cover)
        self.assertNotIn('CortexQueueJob',danger_cover)
        self.assertIn('count _threat >= 2',danger_cover)
        self.assertIn('WAIT_Danger_CoverLease',source('cortexReleaseGroup'))
        group_hide=source('dangerGroupHideStep')
        for marker in ['WAIT_Danger_GroupHideLeases','WAIT_Danger_Generation','WAIT_Operation',
                       'currentCommand _x == ""','WAIT_Cortex_ActorMove','setUnitPosWeak',
                       'groupHideResponses','lastGroupHideActors']:
            self.assertIn(marker,group_hide)
        self.assertIn('call WAIT_fnc_CortexCapabilities',group_hide)
        self.assertIn('case (_capabilities isNotEqualTo []): {30}',group_hide)
        self.assertIn('case (_role == "LEADER"): {20}',group_hide)
        self.assertIn('_ranked sort true',group_hide)
        for forbidden in [' doMove ', ' commandMove ', ' doTarget ', ' doFire ', 'forceWeaponFire',
                          'allUnits', 'allGroups', 'spawn ', 'waitUntil']:
            self.assertNotIn(forbidden,group_hide)
        self.assertIn('call WAIT_fnc_DangerGroupHideStep',source('cortexGroupTick'))
        self.assertIn('call WAIT_fnc_DangerGroupHideStep',source('cortexReleaseGroup'))
        self.assertIn('call WAIT_fnc_DangerGroupHideStep',source('dangerSetup'))
        self.assertIn('call WAIT_fnc_DangerCoverStep',source('cortexReleaseGroup'))
        self.assertIn('WAIT_fnc_CortexZeusHeld',engine_act)
        for forbidden in [' doMove ', ' commandMove ', ' doTarget ', ' doFire ', ' forceWeaponFire ', ' reveal ']:
            self.assertNotIn(forbidden,engine_act)
        self.assertIn('_queue pushBack [_dangerCause,_dangerPos,_dangerUntil,_dangerCausedBy]',engine_fsm)
        self.assertIn('_records=+(_queue select [0,12])',engine_fsm)
        self.assertIn('_queue=[]',engine_fsm)
        self.assertIn('WAIT_fnc_DangerEngineSubmit',engine_fsm)
        self.assertIn('[_this,_records,_mode] call WAIT_fnc_DangerEngineSubmit',engine_fsm)
        self.assertIn('WAIT_fnc_DangerEngineCanContinue',engine_fsm)
        self.assertIn('WAIT_fnc_DangerEngineRelease',engine_fsm)
        self.assertIn('WAIT_fnc_DangerEngineRecycle',engine_fsm)
        editor_head=engine_fsm.split('class FSM',1)[0]
        editor_items=sorted({int(value) for value in re.findall(r'item(\d+)\[\]',editor_head)})
        self.assertEqual(editor_items,list(range(len(editor_items))))
        for source_item,target_item in re.findall(r'link\d+\[\]=\{(\d+),(\d+)\}',editor_head):
            self.assertIn(int(source_item),editor_items)
            self.assertIn(int(target_item),editor_items)
        self.assertNotIn('select _accepted',engine_fsm)
        self.assertIn('_mode=[_this,_selected] call WAIT_fnc_DangerEngineMode',engine_fsm)
        self.assertIn('initState="Start_Danger"',engine_fsm)
        for final_state in ['"End_Danger"','"End_Danger_vehic"','"End_Danger_1"','"End_Forced"']:
            self.assertIn(final_state,engine_fsm)
        self.assertNotRegex(engine_fsm.lower(),r'lambs|upstream|baseline')
        self.assertIn('WAIT_AIPass_Danger_Enable',engine_continue)
        self.assertIn('WAIT_AIPass_DisabledFeatures',engine_continue)
        self.assertIn('WAIT_fnc_CortexIsPaused',engine_continue)
        self.assertIn('WAIT_fnc_CompatibilityExternalControl',engine_continue)
        self.assertIn('remoteControlled _actor',engine_continue)
        self.assertIn('WAIT_AIPass_ZeusHold',engine_continue)
        self.assertIn('WAIT_AIPass_ZeusWaypoints',engine_continue)
        self.assertIn('behaviour _actor == "CARELESS"',engine_continue)
        self.assertIn('fleeing _actor',engine_continue)
        self.assertIn('toUpperANSI (currentCommand _actor) in ["GET IN","ACTION","HEAL","REARM","JOIN"]',engine_continue)
        for expensive in ['units _group','allUnits','allGroups','CortexExternalTakeover','CortexExternalOwner','CortexZeusHeld','nearestObjects','nearEntities']:
            self.assertNotIn(expensive,engine_continue)
        mode_preflight=engine_mode.split('if (fleeing _actor',1)[0]
        self.assertIn('WAIT_AIPass_Active',mode_preflight)
        self.assertIn('WAIT_AIPass_Danger_Enable',mode_preflight)
        self.assertIn('CortexIsPaused',mode_preflight)
        for state in ['Start_Danger','Init','Evaluate_Vehicle','Reset_vehicle','Evaluate_Infantr',
                      'Roll_dodge','Stay_firm','Attack','Check_self','End_Danger','Reset_foot',
                      'Check_queue','End_Danger_vehic','Check_self_1','Check_self_2','Tactics',
                      'End_Danger_1','End_Forced']:
            self.assertIn('class '+state,engine_fsm)
        self.assertGreaterEqual(engine_fsm.count('time >= _deadline'),4)
        self.assertGreaterEqual(engine_fsm.count('WAIT_fnc_DangerEngineCanContinue'),5)
        self.assertIn('effectiveCommander (vehicle _actor) == _actor',engine_recycle)
        self.assertIn("['lastRecycleActor',_actor]",engine_recycle)
        self.assertIn("['vehicleRecycleActors',_actors]",engine_recycle)
        self.assertIn('_actor distance2D _source < 35',engine_recycle)
        self.assertIn('(side _group) getFriend (side _source) >= 0.6',engine_recycle)
        self.assertIn('[_cause,+_position,time+1.5,_source,_cycle+1]',engine_recycle)
        self.assertNotIn('[0,+_position,time+1.5,_source',engine_recycle)
        self.assertIn("case 'ENGAGE': {2}",engine_recycle)
        self.assertIn("case 'VEHICLE': {3}",engine_recycle)
        self.assertIn('boundedRecycleEnds',engine_recycle)
        self.assertIn("['boundedRecycleEndsByMode',_endsByMode]",engine_recycle)
        self.assertIn("['lastRecycleCyclesByMode',_cyclesByMode]",engine_recycle)
        for forbidden in [' doMove ', ' commandMove ', ' doTarget ', ' doFire ', ' forceWeaponFire ', ' reveal ', 'allUnits', 'allGroups']:
            self.assertNotIn(forbidden,engine_recycle)
        self.assertIn('first-contactBootstraps=',diagnostics)
        self.assertIn('reflexOnlyRecords=',diagnostics)
        self.assertIn('boundedRecycleEnds=%18',diagnostics)
        self.assertIn('lastRecycleCycles=%19',diagnostics)
        self.assertIn('groupHideResponses=%20',diagnostics)
        self.assertIn('activeGroupHideActors=%21',diagnostics)
        self.assertIn('_dangerEngineBoundedEnds',diagnostics)

        contact_audit=(ROOT/'releaseVerificationAndDeployment'/'cortexQA'/'runContact.sqf').read_text(encoding='utf-8')
        self.assertIn('"BODY_FOUND" in (_stats getOrDefault ["lastCauses",[]])',contact_audit)
        self.assertIn('DANGER-other-body-distinct-alert',contact_audit)
        self.assertIn('[_bodyActor] call _killWithRealProjectile',contact_audit)
        self.assertNotIn('call WAIT_fnc_DangerEngineSubmit',contact_audit)
        self.assertIn('WAIT_Danger_EngineStanceLease',diagnostics)
        self.assertIn('server-local stance leases=',diagnostics)
        vehicle_audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        self.assertIn('DANGER-VEHICLE-mixed-observer-domain',vehicle_audit)
        self.assertIn('count _assessment >= 7',vehicle_audit)
        self.assertIn('(_assessment select 5) == effectiveCommander _contactVehicle',vehicle_audit)
        self.assertIn('_action param [0,""] == "VEHICLE"',vehicle_audit)
        self.assertIn('(_vehicleContext select 0) == "ARMOURED"',vehicle_audit)
        self.assertIn('(_vehicleContext select 1) == _contactVehicle',vehicle_audit)
        self.assertIn('dangerVehicleProfile',source('cortexGroupTick'))
        self.assertIn('["TRANSPORT","ARMED","ARMOURED"]',source('cortexVehicles'))
        self.assertIn('WAIT_Danger_VehicleContext",nil,true',source('cortexReleaseGroup'))
        self.assertIn('Immediate stances are weak, finite and exact-owned',diagnostics)
        self.assertIn('Friendly near-fire can produce a short local reflex but cannot create group CONTACT',diagnostics)
        self.assertIn('["ERROR","ACTIVE"] select _dangerFsmOwned',diagnostics)
        self.assertIn('Native ATTACK remains eligible',diagnostics)
        self.assertIn("_mode in ['FORCED','RELEASE']",engine)
        self.assertIn("then {false}",engine.split("_mode in ['FORCED','RELEASE']",1)[1].split(';',1)[0])
        self.assertIn('private _dangerFsmPaths=["SoldierWB","SoldierEB","SoldierGB"] apply',diagnostics)
        self.assertIn('WAIT must own all west, east and independent soldier danger slots',diagnostics)
        lifecycle=(ROOT/'docs/ADDON-LIFECYCLE.md').read_text(encoding='utf-8')
        for state in ['`ASSESS`','`IMMEDIATE`','`HIDE`','`ENGAGE`','`VEHICLE`','`FORCED`','release']:
            self.assertIn(state,lifecycle)
        self.assertIn('cannot request cover movement from those causes',lifecycle)
        self.assertIn('cannot create a second movement scheduler',lifecycle)
        contact_audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runContact.sqf').read_text(encoding='utf-8')
        reflex_fixture=contact_audit.split('// Prove the engine-loaded FSM',1)[1].split('deleteGroup _reflexGroup;',1)[0]
        self.assertIn('_reflexUnit setUnitPos "AUTO";',reflex_fixture)
        self.assertNotIn('_reflexUnit setUnitPos "UP";',reflex_fixture)
        self.assertIn('toUpperANSI (unitPos _reflexUnit) == "AUTO"',reflex_fixture)
        self.assertIn('DANGER-committed-mover-not-forced-prone',reflex_fixture)
        self.assertIn('DANGER-committed-route-physical-continuity',reflex_fixture)
        self.assertIn('DANGER-idle-physical-cover',reflex_fixture)
        self.assertIn('DANGER-exact-observer-physical-cover',reflex_fixture)
        self.assertIn('DANGER-finite-group-hide',reflex_fixture)
        self.assertIn('WAIT_Danger_GroupHideLeases',reflex_fixture)
        self.assertIn('O_Soldier_LAT_F',reflex_fixture)
        self.assertIn('!(_observerSupportOne in _leasedActors)',reflex_fixture)
        self.assertIn('[_observerSupportTwo,_observerSupportThree,_observerSupportFour,_observerSupportFive]',reflex_fixture)
        self.assertIn('toUpperANSI (unitPos _observerSupportOne) == "AUTO"',reflex_fixture)
        self.assertIn('(_assessment select 5) == _observerWingman',reflex_fixture)
        self.assertIn('(_action select 5) == _observerWingman',reflex_fixture)
        self.assertIn('(_lease select 0) == _observerWingman',reflex_fixture)
        self.assertIn('DANGER-natural-finish-identity-cleared',reflex_fixture)
        self.assertIn('DANGER-close-contact-finite-reflex-handoff',reflex_fixture)
        self.assertIn('getOrDefault ["boundedRecycleEnds",0]',reflex_fixture)
        self.assertIn('getOrDefault ["boundedRecycleEndsByMode",createHashMap]',reflex_fixture)
        self.assertIn('getOrDefault ["lastRecycleCyclesByMode",createHashMap]',reflex_fixture)
        self.assertIn('getOrDefault ["ENGAGE",-1]) == 2',reflex_fixture)
        self.assertIn('WAIT_Danger_LastAssessment',reflex_fixture)
        self.assertIn('WAIT_Danger_VehicleContext',reflex_fixture)
        self.assertIn('Land_CncWall4_F',reflex_fixture)
        self.assertIn('WAIT_Danger_CoverLease',reflex_fixture)
        self.assertIn('WAIT_fnc_OperationStart',reflex_fixture)
        self.assertIn('WAIT_fnc_CortexGroupMove',reflex_fixture)
        self.assertIn('DANGER-stealth-hold-fire-low-profile',contact_audit)
        self.assertIn('_disciplineGroup setBehaviourStrong "STEALTH"',contact_audit)
        self.assertIn('(_lease select 1) == "DOWN"',contact_audit)
        self.assertIn('behaviour _actor == "STEALTH"',engine_act)
        self.assertIn('combatMode _group in ["BLUE","GREEN"]',engine_act)
        self.assertIn('!_committedMover',engine_act)
        group_tick=source('cortexGroupTick')
        observer_selection=group_tick.split('private _dangerAction=',1)[1].split('private _dangerActionName=',1)[0]
        self.assertIn('param [5,objNull,[objNull]]',observer_selection)
        self.assertIn('group _observedActor == _group',observer_selection)
        self.assertIn('[_action,_cause,_observedAt,time+_responseLifetime,_generation,_observer]',source('dangerStep'))
        scheduler_audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runScheduler.sqf').read_text(encoding='utf-8')
        danger_audit=scheduler_audit.split('// This section diagnoses the real FSM-to-existing-job bridge.',1)[1]
        self.assertIn('WAIT_GroupBrain',danger_audit)
        self.assertIn('WAIT_Danger_GroupHandlers',danger_audit)
        self.assertNotIn('getVariable ["WAIT_Cortex_GroupJob"',danger_audit)
        fsm=(ROOT/'addons/main/fsm/dangerAssessment.fsm').read_text()
        self.assertIn('_zeusToken isNotEqualTo',fsm)
        self.assertIn('WAIT_AIPass_Epoch',fsm)
        self.assertIn('""RELEASE""',fsm)
        self.assertIn('_brain=_group getVariable [""WAIT_GroupBrain"",createHashMap]',fsm)
        self.assertIn('_brain deleteAt ""responsiveUntil""',fsm)
        self.assertNotIn('WAIT_Cortex_GroupJob',fsm)
        self.assertIn('WAIT_Danger_Action',fsm)
        for contract in ['"RELEASE"','"FORCED"','"MAINTAIN"','"VEHICLE"','"HIDE"','"ENGAGE"']:
            self.assertIn(contract,action)
        self.assertIn('currentCommand _actor in ["GET IN","ACTION","HEAL","REARM","JOIN"]',action)
        self.assertNotIn('currentCommand _actor in ["ATTACK"',action)
        self.assertIn('!isNull objectParent _actor',action)
        self.assertLess(action.index('currentCommand _actor in'),action.index('WAIT_Operation'))
        self.assertLess(action.index('!isNull objectParent _actor'),action.index('WAIT_Operation'))
        for forbidden in [' doMove ', ' doTarget ', 'reveal', 'allUnits', 'allGroups']:
            self.assertNotIn(forbidden,action)
        compatibility_audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCompatibility.sqf').read_text(encoding='utf-8')
        for base in ['SoldierWB','SoldierEB','SoldierGB']:
            self.assertIn(base,compatibility_audit)
        self.assertIn('COMPAT-exclusive-danger-fsm-',compatibility_audit)
        self.assertIn('find "z\\wait\\danger\\danger.fsm"',compatibility_audit)
        self.assertNotIn('find "\\\\z\\\\waldo_ai_tweaks',compatibility_audit)

    def test_danger_static_support_is_one_actor_and_one_attempt_per_contact(self):
        support=source('cortexStaticSupport')
        group_tick=source('cortexGroupTick')
        restore=source('cortexRestoreCalm')
        for marker in [
            'WAIT_AIPass_StaticSupport_Enable','nearestObjects [_anchor,["StaticWeapon"],75,true]',
            'crew _x isEqualTo []','canFire _x','someAmmo _x','_x != leader _group',
            'assignAsGunner _weapon','orderGetIn true','WAIT_Danger_StaticAttempt',
            'WAIT_Cortex_ActorMove",["STATIC_SUPPORT"','time+20'
        ]:
            self.assertIn(marker,support)
        self.assertIn('count (_group getVariable ["WAIT_Operation",createHashMap]) > 0',support)
        self.assertIn('failed or unsuitable attempts are not retried until a later contact',support)
        self.assertNotIn('moveInGunner',support)
        self.assertNotIn('setPos',support)
        self.assertNotIn('allowDamage',support)
        self.assertIn('call WAIT_fnc_CortexStaticSupport',group_tick)
        self.assertLess(group_tick.index('call WAIT_fnc_CortexStaticSupport'),group_tick.index('call WAIT_fnc_CortexTacticalStart'))
        for marker in ['WAIT_Danger_StaticSupport','orderGetIn false','unassignVehicle','_yieldToExternal']:
            self.assertIn(marker,restore)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runContact.sqf').read_text(encoding='utf-8')
        for marker in [
            'DANGER-static-support-disabled','DANGER-static-support-physical-seat',
            'DANGER-static-support-composable-fire','DANGER-static-support-contact-cleanup',
            'gunner _staticWeapon','WAIT_CortexQA_Shots'
        ]:
            self.assertIn(marker,audit)
        for forbidden in ['moveInGunner','call WAIT_fnc_CortexStaticSupport','call WAIT_fnc_CortexRestoreCalm']:
            self.assertNotIn(forbidden,audit)

    def test_danger_static_deployment_is_finite_physical_and_owned(self):
        deploy=source('cortexStaticDeployStep')
        support=source('cortexStaticSupport')
        restore=source('cortexRestoreCalm')
        for marker in [
            'WAIT_AIPass_StaticDeploy_Enable','assembleInfo','assembleTo','"primary") == 1',
            '["PutBag",_assistant]','["Assemble",unitBackpack _assistant]',
            'nearestObjects [_deployPos,[_expectedClass],8,true]',
            'assignAsGunner _assembled','orderGetIn true',
            'WAIT_Danger_StaticDeployment','WAIT_Danger_StaticDeployAttempt',
            'lineIntersectsSurfaces','surfaceNormal _x',
            'WeaponDisassembled','["Disassemble",_weapon]',
            '["TakeBag",_primaryBag]','["TakeBag",_baseBag]',
            '"PACK_MOVING"','"PACKING"','"TAKING"','"PACKED"',
            'removeEventHandler ["WeaponDisassembled",_handler]'
        ]:
            self.assertIn(marker,deploy)
        self.assertIn('call WAIT_fnc_CortexStaticDeployStep',support)
        self.assertNotIn('moveInGunner',deploy)
        self.assertNotIn('createVehicle',deploy)
        self.assertNotIn('setPos',deploy)
        self.assertNotIn('while {',deploy)
        self.assertNotIn('CortexQueueJob',deploy)
        for marker in ['WAIT_Danger_StaticDeployment','WAIT_Danger_StaticDeployAttempt',
                       'orderGetIn false','unassignVehicle','_yieldToExternal',
                       'removeEventHandler ["WeaponDisassembled",_packHandler]',
                       'WAIT_Danger_StaticPackContext']:
            self.assertIn(marker,restore)
        group_tick=source('cortexGroupTick')
        self.assertIn('[_group,_state,[],!_ordered] call WAIT_fnc_CortexStaticDeployStep',group_tick)
        self.assertIn('_staticPack in ["PACK_MOVING","PACKING","TAKING"]',group_tick)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runContact.sqf').read_text(encoding='utf-8')
        for marker in [
            'DANGER-static-deploy-config-prerequisite',
            'DANGER-static-deploy-physical-assembly',
            'DANGER-static-deploy-real-fire',
            'DANGER-static-deploy-contact-release',
            'DANGER-static-deploy-native-pack',
            'O_HMG_01_weapon_F','O_HMG_01_support_F'
        ]:
            self.assertIn(marker,audit)
        fixture=audit[audit.index('// A carried support team must use'):audit.index('sleep 8;',audit.index('// A carried support team must use'))]
        for forbidden in ['call WAIT_fnc_CortexStaticDeployStep','moveInGunner','createVehicle [_deployExpected']:
            self.assertNotIn(forbidden,fixture)
        for setting in ['WAIT_AIPass_PostContact_Enable','WAIT_AIPass_PostContact_LostSeconds','WAIT_AIPass_PostContact_SecuritySeconds']:
            self.assertIn(setting,fixture)

    def test_danger_action_owns_posture_without_owning_movement(self):
        reaction=source('dangerReact')
        self.assertIn('"MAINTAIN",""]',reaction)
        self.assertNotIn('if (_action == "MAINTAIN") exitWith',reaction)
        self.assertIn('WAIT_Operation',reaction)
        self.assertIn('_action == "MAINTAIN" && {count _operation == 0}',reaction)
        self.assertIn('_action == "MAINTAIN" && {_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"]}',reaction)
        self.assertIn('MAINTAIN means keep the committed route, not ignore the threat',reaction)
        self.assertIn('_action == "ENGAGE"',reaction)
        self.assertIn('private _desiredCombat',reaction)
        self.assertIn('if (_action in ["FORCED","VEHICLE"]) exitWith {"ASSESS"}',reaction)
        self.assertLess(reaction.index('if (_action in ["FORCED","VEHICLE"]'),reaction.index('setBehaviour "COMBAT"'))
        self.assertIn('combatMode _group in ["BLUE","GREEN"]',reaction)
        self.assertIn('exitWith {"ASSESS"}',reaction)
        self.assertNotIn('_priorCombat in ["BLUE","GREEN"]',reaction)
        self.assertNotIn('doMove',reaction)
        self.assertNotIn('doTarget',reaction)
        self.assertIn('"EXPLOSION",2.5',reaction)

    def test_native_group_contacts_survive_a_leader_cover_blind_spot(self):
        knowledge=source('cortexKnowledge')
        setup=source('dangerSetup')
        self.assertIn('WAIT_Danger_ObservedContacts',setup)
        self.assertIn('WAIT_Danger_ObservedContacts',knowledge)
        self.assertIn('private _candidateTargets=+(_leader targets [true, _range])',knowledge)
        self.assertIn('{_candidateTargets pushBackUnique (_x select 0)} forEach _observed',knowledge)
        self.assertIn('private _knower=_members param [_members findIf {_x knowsAbout _enemy >= 1},objNull]',knowledge)
        self.assertIn('private _position=_knower getHideFrom _enemy',knowledge)
        self.assertNotIn('getPosATL (_x select 0)',knowledge)

    def test_operations_are_generation_scoped_and_zeus_cancels_before_release(self):
        start=source('operationStart')
        step=source('operationStep')
        cancel=source('operationCancel')
        release=source('operationRelease')
        zeus=source('cortexZeusMark')
        flank=source('cortexFlankStart')
        advance=source('cortexAdvanceStart')
        end=source('cortexFlankEnd')
        for required in ['intent','generation','ownerEpoch','objective','participants','route','lastProgressAt','cancelReason']:
            self.assertIn(required,start)
        self.assertIn('WAIT_OperationGeneration',start)
        self.assertIn('WAIT_fnc_OperationCancel',start)
        self.assertIn('dangerAtStart',start)
        self.assertIn('private _operationAnchor=[_group] call WAIT_fnc_CortexGroupAnchor;',start)
        self.assertIn('private _dangerPosture=(vehicle _operationAnchor) isEqualTo _operationAnchor;',start)
        self.assertIn('["dangerPosture",_dangerPosture]',start)
        self.assertIn('[_operationAnchor,_dangerCause,_dangerPosition,"MAINTAIN"] call WAIT_fnc_DangerReact',start)
        self.assertIn('[_operationAnchor,"RELEASE"] call WAIT_fnc_DangerReact',start)
        self.assertLess(start.index('_group setVariable ["WAIT_Operation",_operation,true]'),start.index('"MAINTAIN"] call WAIT_fnc_DangerReact'))
        self.assertIn('WAIT_fnc_CortexGroupMoveClear',cancel)
        self.assertIn('[_group,_generation] call WAIT_fnc_CortexGroupMoveClear',cancel)
        self.assertIn('[_group,_generation] call WAIT_fnc_CortexGroupMoveClear',release)
        for completion in [cancel,release]:
            self.assertIn('_operation getOrDefault ["ownerEpoch",-1]',completion)
            self.assertLess(completion.index('ownerEpoch'),completion.index('call WAIT_fnc_CortexGroupMoveClear'))
        self.assertIn('toUpperANSI _reason != "OWNERSHIP_LOST"',cancel)
        self.assertIn('getOrDefault ["dangerPosture",false]',cancel)
        self.assertIn('getOrDefault ["dangerPosture",false]',release)
        self.assertIn('WAIT_fnc_CortexGroupMoveClear',release)
        self.assertIn('private _dangerActor=objNull;',release)
        self.assertIn('_dangerActor=[_group] call WAIT_fnc_CortexGroupAnchor;',release)
        self.assertIn('[_dangerActor,"RELEASE"] call WAIT_fnc_DangerReact',release)
        for completion in [cancel,release]:
            self.assertIn('private _dangerEvent=_dangerResponse select [0,4];',completion)
            self.assertIn('call WAIT_fnc_DangerActionSelect',completion)
            self.assertIn('call WAIT_fnc_DangerReact',completion)
            self.assertLess(completion.index('_group setVariable ["WAIT_Operation",nil,true]'),completion.index('private _dangerEvent='))
        self.assertIn('WAIT_fnc_CortexZeusHeld',step)
        self.assertIn('participantProgress',start)
        self.assertIn('participantProgress',step)
        self.assertIn('private _actorProgressed=_currentPosition distance2D _lastPosition >= _minimum',step)
        self.assertIn('[_lastPosition,_currentPosition] select _actorProgressed',step)
        self.assertNotIn('_updated pushBack [_actor,_currentPosition];',step)
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('WAIT_Cortex_ClearStatus',clear)
        self.assertIn('material room/retry progress or egress',clear)
        self.assertIn('if (_entryTarget isEqualTo [] || {!_approachingEntry && {_entered}}) then {_target} else {_entryTarget}',clear)
        self.assertIn('lastProgressActor',step)
        self.assertIn('A leader can deliberately provide exterior security during CLEAR',step)
        self.assertIn('if (_participants isEqualTo [] && {_originalParticipants isEqualTo []}) then',step)
        self.assertIn('getOrDefault ["ownerEpoch",-1]',step)
        self.assertIn('WAIT_AIPass_Epoch',step)
        self.assertIn('exitWith {"LOST_OWNER"}',step)
        self.assertIn('WAIT_fnc_OperationCancel',zeus)
        self.assertIn('WAIT_fnc_OperationStart',flank)
        self.assertIn('WAIT_fnc_OperationStart',advance)
        retreat=source('cortexRetreat')
        self.assertIn('[_group,"WITHDRAW",_point,_participants,[_point],"MOVING"] call WAIT_fnc_OperationStart',retreat)
        self.assertIn('withdrawOperationGeneration',retreat)
        self.assertIn('WAIT_fnc_OperationRelease',source('cortexGroupTick'))
        self.assertIn('WAIT_fnc_RecoveryStep',source('cortexGroupTick'))
        self.assertIn('operationGeneration',end)
        self.assertIn('WAIT_fnc_OperationStep',source('cortexFlankStep'))
        self.assertIn('["LOST_OWNER","ZEUS","EXTERNAL","REPLACED","STALLED"]',source('cortexFlankStep'))
        self.assertIn('WAIT_fnc_RebalanceRoles',source('cortexFlankStep'))
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('cortex-clearance-active-',diagnostics)
        self.assertIn('WAIT_Cortex_ClearStatus',diagnostics)
        self.assertIn('wait-operation-',diagnostics)
        self.assertIn('lastCallbackMs',source('cortexSchedulerTick'))
        self.assertIn('queueLatency',source('cortexSchedulerTick'))
        for marker in ['maxCallbackMs','maxRecordedQueueLatencySeconds','skippedJobs=',
                       'skipReasons=','recoveryAttempts=','unavailableActors=']:
            self.assertIn(marker,diagnostics)

    def test_manoeuvre_starts_use_a_surviving_local_anchor_instead_of_requiring_the_leader(self):
        for name in ['cortexAdvanceStart','cortexFlankStart','cortexRetreat','cortexCoordinatedAssault']:
            text=source(name)
            self.assertIn('private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;',text)
            self.assertIn('if (isNull _leader) then {_leader=leader _group};',text)
            self.assertNotIn('private _leader = leader _group;',text)
    def test_combined_ground_manoeuvre_uses_common_operation_lifecycle(self):
        combined=source('cortexCombinedArmsLocal')
        step=source('cortexCombinedGroundStep')
        self.assertIn('"COMBINED_GROUND",_target,[],[_destination],"MANOEUVRE"',combined)
        self.assertIn('"operationGeneration",_operation get "generation"',combined)
        self.assertIn('WAIT_fnc_OperationRelease',step)
        self.assertIn('WAIT_fnc_OperationCancel',step)

    def test_missile_defence_uses_the_shared_bounded_scheduler(self):
        discover=source("cortexDiscover")
        defence=source("cortexMissileDefenceStep")
        functions=(ROOT/"addons/main/CfgFunctions.hpp").read_text(encoding="utf-8")
        handler=discover.split('addEventHandler ["IncomingMissile", {',1)[1].split('}];',1)[0]
        self.assertIn('WAIT_fnc_CortexMissileDefenceStep',handler)
        self.assertIn('WAIT_fnc_CortexQueueJob',handler)
        self.assertIn('"jobKey",format ["MISSILE_DEFENCE:%1",netId _vehicle]',handler)
        self.assertNotIn(' spawn ',handler)
        self.assertNotIn(' sleep ',handler)
        for marker in ['WAIT_Cortex_FlareBurstGeneration','WAIT_Cortex_MissileDefenceActive',
                       'WAIT_fnc_CortexAircraftEligible','WAIT_fnc_CortexFireCountermeasure',
                       '_step in [0,4]','_step >= 12','0.45+random 0.18']:
            self.assertIn(marker,defence)
        self.assertNotIn('spawn',defence)
        self.assertNotIn('sleep',defence)
        self.assertIn('class CortexMissileDefenceStep',functions)
    def test_cleanup_and_regroup_use_surviving_anchors_without_global_group_scans(self):
        """Cleanup and remnant recovery remain viable after leadership loss at large group counts."""
        calm=source('cortexRestoreCalm')
        self.assertIn('private _leader=[_group] call WAIT_fnc_CortexGroupAnchor;',calm)
        self.assertIn('_unit doFollow _leader;',calm)
        regroup=source('cortexRegroupStep')
        self.assertIn('_origin nearEntities ["Man",_radius]',regroup)
        self.assertIn('private _leader = [_candidate] call WAIT_fnc_CortexGroupAnchor;',regroup)
        self.assertNotIn('} forEach allGroups;',regroup)

    def test_morale_surrender_support_check_is_spatially_bounded_and_leader_resilient(self):
        """Broken squads must not scan every group or lose their surrender context during succession."""
        morale=source('cortexMorale')
        self.assertIn('private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;',morale)
        self.assertIn('_leaderPos nearEntities ["Man",300]',morale)
        self.assertNotIn('private _friendsNear = allGroups',morale)
        self.assertNotIn('allGroups findIf',morale)

    def test_fresh_heavy_armour_overmatch_withdraws_without_suicidal_manoeuvre(self):
        """A rifle squad without usable AT must leave close armour to the finite withdrawal owner."""
        morale=source('cortexMorale')
        retreat=source('cortexRetreat')
        for marker in ['private _armourIndex = _enemies findIf {',
                       '((_enemies select _armourIndex) select 2) <= 10',
                       '((_enemies select _armourIndex) select 3) <= 120',
                       'waypointType [_group,_waypointIndex] in ["HOLD","SENTRY"]',
                       '_state set ["withdrawReason","HEAVY_ARMOUR_NO_AT"]',
                       '"RETREAT"']:
            self.assertIn(marker,morale)
        self.assertLess(morale.index('_state set ["withdrawReason","HEAVY_ARMOUR_NO_AT"]'),
                        morale.index('private _pressure ='))
        self.assertIn('_state getOrDefault ["withdrawReason","MORALE_WITHDRAWAL"]',retreat)
        self.assertIn('[_group,_state,"RETREAT",_withdrawReason',retreat)

    def test_authored_hold_and_sentry_block_autonomous_movement_but_not_combat(self):
        """Stationary mission intent must gate every WAIT movement owner without disabling fire control."""
        tick=source('cortexGroupTick')
        for marker in [
            'waypointType [_group,_waypointIndex] in ["HOLD","SENTRY"]',
            'waypointDescription [_group,_waypointIndex] != "WAIT AI PASS"',
            '|| {_authoredStationary}',
        ]:
            self.assertIn(marker,tick)
        order_gate=tick.index('private _authoredStationary=')
        self.assertLess(order_gate,tick.index('[_group,_state] call WAIT_fnc_CortexCoordinatedAssault'))
        self.assertLess(order_gate,tick.index('call WAIT_fnc_CortexTacticalStart'))
        self.assertLess(order_gate,tick.index('case "SECURITY":'))
        self.assertIn('if (_outcome == "RETREAT" && {!_authoredStationary})',tick)
        self.assertIn('if (!_holdFire && {["WAIT_AIPass_FireControl_Enable", true] call _get})',tick)

    def test_direct_assault_refuses_vehicle_mounted_and_static_targets(self):
        """Close vehicle contacts must remain with weapon and standoff logic, never infantry clear-through."""
        selector=source('cortexTacticalStart')
        assessment=source('cortexTacticalAssess')
        assault=source('cortexAssaultStart')
        for text in [assessment,assault]:
            self.assertIn('_target isKindOf "CAManBase"',text)
            self.assertIn('isNull objectParent _target',text)
        self.assertIn('"UNSUITABLE_ASSAULT_TARGET"',assault)
        self.assertLess(assessment.index('_target isKindOf "CAManBase"'),
                        assessment.index('_intent="ASSAULT"'))
        self.assertIn('call WAIT_fnc_CortexTacticalAssess',selector)

    def test_autonomous_foot_manoeuvre_rejects_mobile_platform_contacts(self):
        """Vehicle contact may cause a finite safety reposition, but never a rifle assault route."""
        selector=source('cortexTacticalStart')
        assessment=source('cortexTacticalAssess')
        reposition=source('cortexTacticalReposition')
        for marker in [
            'private _manoeuvre=[];',
            '_target isKindOf "CAManBase" && {isNull objectParent _target}',
            '_platform isKindOf "StaticWeapon"',
            '_result set ["targetIndex",_selected]',
            '"ARMOUR_OVERMATCH"'
        ]:
            self.assertIn(marker,assessment)
        self.assertIn('case "REPOSITION"',selector)
        self.assertIn('_reason == "ARMOUR_OVERMATCH"',reposition)
        self.assertIn('_distance <= 120',reposition)
        self.assertIn('call WAIT_fnc_CortexSelectAvenue',reposition)
        self.assertNotIn('setPos',reposition)

    def test_medical_assistance_can_treat_a_wounded_leader_without_self_treatment(self):
        """Leader succession must not make a leader ineligible for aid or select a medic as their own patient."""
        medical=source('cortexMedicalStep')
        self.assertIn('private _casualties=_members select {damage _x >= _threshold};',medical)
        self.assertIn('if (_medic != _x && {_distance < _best}',medical)
        self.assertNotIn('_x != leader _group && {damage _x >= _threshold}',medical)

    def test_medical_assistance_is_bounded_and_yields_to_competing_owners(self):
        medical=source('cortexMedicalStep')
        tick=source('cortexGroupTick')
        self.assertIn('WAIT_AIPass_MedicalAssist_Enable',medical)
        self.assertIn('WAIT_fnc_CortexZeusHeld',medical)
        self.assertIn('WAIT_fnc_CompatibilityExternalControl',medical)
        self.assertNotIn('medicalBackend',medical)
        self.assertIn('_medic action ["HealSoldier",_casualty]',medical)
        self.assertIn('_medic doMove getPosATL _casualty',medical)
        self.assertIn('_medic doMove getPosATL _casualty',medical)
        self.assertNotIn('_medic setDestination',medical)
        self.assertNotIn('doHeal',medical)
        self.assertIn('WAIT_fnc_OperationStart',medical)
        self.assertIn('WAIT_fnc_OperationStep',medical)
        self.assertIn('WAIT_fnc_OperationCancel',medical)
        self.assertIn('WAIT_fnc_OperationRelease',medical)
        self.assertIn('private _mayIssueMedical = {',medical)
        self.assertIn('!([_group] call WAIT_fnc_CortexExternalTakeover)',medical)
        self.assertIn('if !(call _mayIssueMedical) exitWith {["CANCELLED","EXTERNAL"] call _finish};',medical)
        self.assertLess(medical.index('private _mayIssueMedical = {'),medical.index('_medic doMove getPosATL _casualty'))
        self.assertLess(medical.rindex('call _mayIssueMedical',0,medical.rindex('_medic action ["HealSoldier",_casualty]')),medical.rindex('_medic action ["HealSoldier",_casualty]'))
        self.assertIn('private _dangerResponse=_group getVariable ["WAIT_Danger_Response",[]];',medical)
        self.assertIn('private _dangerActive=count _dangerResponse == 5',medical)
        self.assertIn('if (_dangerActive) exitWith {["CANCELLED","COMBAT_RESUMED"] call _finish};',medical)
        self.assertIn('if (_dangerActive) exitWith {false};',medical)
        self.assertLess(medical.index('if (_dangerActive) exitWith {["CANCELLED","COMBAT_RESUMED"] call _finish};'),medical.index('_aid params'))
        self.assertIn('_phase in ["CALM","SECURITY"]',medical)
        self.assertIn('COMBAT_RESUMED',medical)
        self.assertIn('NO_PROGRESS',medical)
        self.assertIn('if (_distance > 4) then {',medical)
        self.assertIn('native HealSoldier action can work',medical)
        for forbidden in ['setDamage', 'setPos', 'joinSilent', 'addWaypoint']:
            self.assertNotIn(forbidden,medical)
        self.assertIn('WAIT_fnc_CortexMedicalStep',tick)

    def test_recovery_quarantines_only_an_exhausted_actor_from_common_operation_progress(self):
        start=source('operationStart')
        step=source('operationStep')
        recovery=source('recoveryStep')
        self.assertIn('["unavailable",[]]',start)
        self.assertIn('private _originalParticipants=',step)
        self.assertIn('private _unavailable=',step)
        self.assertIn('time-_startedAt >= _staleSeconds',step)
        self.assertIn('private _participants=_originalParticipants select {!(_x in _unavailable) && {!(_x in _recovering)}}',step)
        self.assertIn('Recovery actors are intentionally absent from aggregate progress',step)
        self.assertIn('_recovery set [_key,[_attempts,time,+_destination,_currentPosition]]',step)
        self.assertIn('_operation set ["unavailable",_unavailable]',step)
        self.assertIn('_recovery deleteAt (netId _actor)',step)
        rebalance=source('rebalanceRoles')
        self.assertIn('WAIT_fnc_CortexExternalTakeover',rebalance)
        self.assertIn('_operation getOrDefault ["ownerEpoch",-1]',rebalance)
        self.assertIn('private _blocked=(_operation getOrDefault ["unavailable",[]])+_excluded',rebalance)
        flank=source('cortexFlankStep')
        self.assertIn('[_group,_operationGeneration,count _units,[]] call WAIT_fnc_RebalanceRoles;',flank)
        self.assertNotIn('[_group,_operationGeneration,count _units,_units] call WAIT_fnc_RebalanceRoles;',flank)
        self.assertEqual(recovery.count('_actor doMove _destination'),1)
        self.assertNotIn('setDestination [_destination',recovery)
        self.assertNotIn('_actor enableAI "PATH"',recovery)
        self.assertIn('_operation getOrDefault ["ownerEpoch",-1]',recovery)
        self.assertIn('_recovery set [_key,[_attempts+1,time,+_destination,getPosATL _actor]]',recovery)
        self.assertNotIn('setPos',recovery)

    def test_operation_owners_exit_at_function_scope_after_terminal_common_status(self):
        convoy=source('convoyTick')
        clear=source('buildingOperationStep')
        self.assertIn('private _operationEndReason = "";',convoy)
        self.assertIn('if (_operationEndReason != "") exitWith {',convoy)
        convoy_exit=convoy.split('if (_operationEndReason != "") exitWith {',1)[1]
        self.assertIn('WAIT_fnc_ConvoyReleaseLocal',convoy_exit)
        self.assertLess(convoy.index('if (_operationEndReason != "") exitWith {'),convoy.index('formation _group != "COLUMN"'))
        self.assertIn('private _operationEndReason="";',clear)
        self.assertIn('if (_operationEndReason != "") exitWith {',clear)
        clear_exit=clear.split('if (_operationEndReason != "") exitWith {',1)[1]
        self.assertIn('[false,_operationEndReason] call _finish',clear_exit)
        self.assertLess(clear.index('if (_operationEndReason != "") exitWith {'),clear.index('private _operation=_group getVariable'))

    def test_stale_combined_ground_callback_cannot_release_replacement_lease(self):
        step=source('cortexCombinedGroundStep')
        self.assertIn('private _operationMatches=count _operation > 0',step)
        self.assertIn('(_operation getOrDefault ["generation",-2]) == _operationGeneration',step)
        self.assertIn('(_operation getOrDefault ["intent",""]) == "COMBINED_GROUND"',step)
        self.assertIn('if (_operationMatches && {(_lease param [0,""]) == "COMBINED_GROUND"}) then {',step)
        self.assertNotIn('if ((_lease param [0,""]) == "COMBINED_GROUND") then {',step)

    def test_danger_reaction_is_scoped_and_never_issues_movement(self):
        reaction=source('dangerReact')
        for forbidden in [' doMove ', ' doFollow ', ' setDestination ', 'addWaypoint']:
            self.assertNotIn(forbidden,reaction)
        self.assertIn('WAIT_Danger_ReactionLease',reaction)
        self.assertIn('WAIT_Operation',reaction)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',reaction)
        self.assertIn('"POSTURE"',reaction)
        self.assertIn('private _leaseIntact',reaction)
        self.assertIn('private _postureActor=[_group] call WAIT_fnc_CortexGroupAnchor;',reaction)
        self.assertIn('if (isNull _postureActor) then {_postureActor=leader _group};',reaction)
        self.assertIn('behaviour _postureActor == _ownedBehaviour',reaction)
        self.assertIn('behaviour _postureActor == (_lease select 1)',reaction)
        self.assertNotIn('behaviour leader _group == _ownedBehaviour',reaction)
        self.assertIn('max (_lease param [4,-1])',reaction)
        self.assertIn('"RELEASE"',reaction)
        self.assertIn('_cause == "RELEASE"',reaction)
        self.assertNotIn('WAIT_Danger_Immediate',reaction)
        step=source('dangerStep')
        self.assertIn('WAIT_fnc_DangerReact',step)
        self.assertIn('[_actor,"RELEASE"] call WAIT_fnc_DangerReact',step)
        self.assertIn('[_dangerActor,"RELEASE"] call WAIT_fnc_DangerReact',source('cortexReleaseGroup'))

    def test_engine_danger_reflex_obeys_runtime_feature_and_pause_gates(self):
        mode=source('dangerEngineMode')
        action=source('dangerEngineAct')
        for text in [mode,action]:
            self.assertIn('WAIT_AIPass_Active',text)
            self.assertIn('WAIT_AIPass_Danger_Enable',text)
            self.assertIn('WAIT_fnc_CortexFeatureEnabled',text)
            self.assertIn('WAIT_fnc_CortexIsEligible',text)
            self.assertIn('WAIT_fnc_CortexIsPaused',text)
            self.assertIn('WAIT_fnc_CortexExternalTakeover',text)
        self.assertLess(mode.index('WAIT_AIPass_Danger_Enable'),mode.index('if (fleeing _actor'))
        self.assertLess(action.index('WAIT_AIPass_Danger_Enable'),action.index('private _delays='))

    def test_danger_cleanup_never_restores_wait_posture_after_ownership_takeover(self):
        fsm=(ROOT/'addons/main/fsm/dangerAssessment.fsm').read_text(encoding='utf-8')
        step=source('dangerStep')
        setup=source('dangerSetup')
        self.assertIn('WAIT_fnc_DangerReact',fsm)
        self.assertIn('[_dangerActor,""RELEASE""] call WAIT_fnc_DangerReact',fsm)
        self.assertIn('private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;',step)
        self.assertIn('if (!_yieldToOwner) then {[_actor,"RELEASE"] call WAIT_fnc_DangerReact}',step)
        self.assertIn('if (!_yieldToOwner) then {[_actor,"RESTORE"] call WAIT_fnc_DangerReact}',step)
        self.assertIn('private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;',setup)
        self.assertIn('private _dangerActor=[_group] call WAIT_fnc_CortexGroupAnchor;',setup)
        request=source('dangerRequest')
        self.assertIn('WAIT_fnc_CortexExternalTakeover',request)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',setup)
        self.assertIn('if (_yieldToOwner) exitWith {',step)
        self.assertNotIn('WAIT_fnc_CortexExternalTakeover',fsm)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',step)
        reaction=source('dangerReact')
        tick=source('cortexGroupTick')
        self.assertIn('private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;',reaction)
        self.assertIn('if (_yieldToOwner) exitWith {',reaction)
        self.assertIn('private _dangerYield=[_group] call WAIT_fnc_CortexExternalTakeover;',tick)
        self.assertIn('private _dangerActor=[_group] call WAIT_fnc_CortexGroupAnchor;',tick)
        self.assertIn('[_dangerActor,"RESTORE"] call WAIT_fnc_DangerReact',tick)

    def test_danger_generation_cleanup_cannot_reuse_an_invalidated_fsm(self):
        request=source('dangerRequest')
        setup=source('dangerSetup')
        fsm=(ROOT/'addons/main/fsm/dangerAssessment.fsm').read_text(encoding='utf-8')
        self.assertIn('(_running select 1) == (_group getVariable ["WAIT_Danger_Generation",0])',request)
        self.assertIn('private _dangerCoverLease=_group getVariable ["WAIT_Danger_CoverLease",[]];',setup)
        self.assertIn('call WAIT_fnc_DangerCoverStep',setup)
        self.assertIn('_group setVariable ["WAIT_Danger_Generation",(_group getVariable ["WAIT_Danger_Generation",0])+1];',setup)
        generation=setup.index('_group setVariable ["WAIT_Danger_Generation"')
        self.assertGreater(setup.index('_group setVariable ["WAIT_Danger_FSM",nil];'),generation)
        for marker in ['WAIT_Danger_LastAssessment','WAIT_Danger_WakeAfter']:
            self.assertIn(f'_group setVariable ["{marker}",nil];',setup)
        # Natural finite completion must also close generation-scoped identity. Otherwise the next
        # generation can inspect the former observer's native task before selecting its own event.
        self.assertIn('_group setVariable [""WAIT_Danger_LastAssessment"",nil]',fsm)
        self.assertIn('_group setVariable [""WAIT_Danger_VehicleContext"",nil,true]',fsm)
        self.assertLess(fsm.index('WAIT_Danger_LastAssessment'),fsm.index('WAIT_Danger_Response'))

    def test_live_danger_setting_reconfigures_owner_local_observers_without_a_second_worker(self):
        callback=source('aiTweaksSettingChanged')
        self.assertIn('if (_name == "WAIT_AIPass_Danger_Enable"',callback)
        self.assertIn('{if (local _x) then {[_x] call WAIT_fnc_DangerSetup}} forEach allGroups;',callback)
        self.assertNotIn('WAIT_fnc_CortexQueueJob',callback)
        self.assertNotIn('CBA_fnc_addPerFrameHandler',callback)

    def test_group_release_yields_cleanup_to_zeus_and_other_active_owners(self):
        release=source('cortexReleaseGroup')
        self.assertIn('private _yieldToZeus=',release)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',release)
        self.assertIn('"EXTERNAL_TAKEOVER"',release)
        self.assertIn('_reason in ["ZEUS_TAKEOVER","EXTERNAL_TAKEOVER"]',release)

    def test_group_move_commits_equivalent_requests_without_waypoint_churn(self):
        move=source('cortexGroupMove')
        clear=source('cortexGroupMoveClear')
        self.assertIn('WAIT_Cortex_GroupMoveIntent',move)
        self.assertIn('private _sameRequest',move)
        self.assertIn('if (_sameRequest) exitWith {_previousWaypoint}',move)
        self.assertLess(move.index('if (_sameRequest) exitWith {_previousWaypoint}'),
                        move.index('call WAIT_fnc_CortexGroupMoveClear'))
        self.assertIn('if (isNull _group || {!local _group}',move)
        self.assertIn('[_group,false,false,true] call WAIT_fnc_CortexIsEligible',move)
        self.assertGreaterEqual(move.count('WAIT_fnc_CortexExternalTakeover'),2)
        self.assertLess(move.index('WAIT_fnc_CortexExternalTakeover'),move.index('_group addWaypoint'))
        eligible=source('cortexIsEligible')
        self.assertIn('[_group,_ignoreZeusHold] call WAIT_fnc_CortexExternalTakeover',eligible)
        self.assertIn('Direct remote control and all other',source('cortexExternalTakeover'))
        self.assertIn('if (isNull _group || {!local _group}',clear)
        self.assertIn('_group setVariable ["WAIT_Cortex_GroupMoveIntent", nil, true]',clear)
        self.assertIn('private _ownedWaypoint',clear)
        self.assertIn('["_operationGeneration", -1, [0]]',clear)
        self.assertIn('operationGeneration",-1]) != _operationGeneration',clear)
        self.assertIn('operationGeneration", _operationGeneration',move)
        self.assertIn('getOrDefault ["generation",-1]',move)
        self.assertIn('waypointDescription _ownedWaypoint == "WAIT AI PASS"',clear)
        legacy_marker='W' + 'MP AI PASS'
        self.assertNotIn(legacy_marker,move)
        self.assertNotIn(legacy_marker,clear)

    def test_building_clearance_uses_the_common_operation_lifecycle(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('[_group,"CLEAR",_building,_team,_positions,"ENTRY"] call WAIT_fnc_OperationStart',clear)
        self.assertIn('operationGeneration',clear)
        self.assertIn('WAIT_fnc_OperationStep',clear)
        self.assertIn('WAIT_fnc_OperationRelease',clear)
        self.assertIn('WAIT_fnc_OperationCancel',clear)
        self.assertIn('[false,"EXTERNAL"] call _finish',clear)

    def test_cortex_control_deduplicates_settings_and_diagnostics_explain_once(self):
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        self.assertIn('Expected evidence:',diagnostics)
        self.assertIn('not an action trigger or success result',diagnostics)
        self.assertNotIn('Trigger/inspection:',diagnostics)
        self.assertIn('private _seenTuningKeys=createHashMap',diagnostics)
        self.assertIn('_tuningSpec pushBack _x',diagnostics)
        client=(ROOT/'releaseVerificationAndDeployment/cortexQA/runClient.sqf').read_text(encoding='utf-8')
        self.assertIn('UI-01b-canonical-settings',client)
        self.assertIn('UI-registered-',client)
        self.assertIn('arrayIntersect _keys',client)

    def test_current_audits_do_not_set_removed_danger_ownership_mode(self):
        for audit in (ROOT/'releaseVerificationAndDeployment/cortexQA').glob('*.sqf'):
            self.assertNotIn('WAIT_AIPass_InfantryOwnership',audit.read_text(),audit.name)

    def test_cfgfunctions_exports_only_wait_api_without_legacy_aipass_aliases(self):
        exports=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertNotIn('class AIPass',exports)
        self.assertNotIn('Legacy mission API aliases',exports)
        self.assertIn('class CortexInit',exports)
        self.assertIn('class OperationStart',exports)
    def test_configuration_has_no_duplicate_zen_panel_or_variable_bridge(self):
        modules=(ROOT/'addons/main/bootstrap/zenRegister.sqf').read_text()
        exports=(ROOT/'addons/main/CfgFunctions.hpp').read_text()
        preinit=(ROOT/'addons/main/XEH_preInit.sqf').read_text()
        self.assertNotIn('"AI Control"',modules)
        self.assertIn('WAIT_fnc_ZenConvoyModule',modules)
        for obsolete in ['CortexControlOpenLocal','CortexControlPageLocal','AITweaksSettingsRequestServer']:
            self.assertNotIn('class '+obsolete+' ',exports)
        self.assertNotIn('WAIT_AITweaks_SettingsRequest',preinit)

    def test_cortex_control_distinguishes_master_gates_from_feature_switches(self):
        spec=source('cortexTuningSpec')
        for label in [
            'Apply WAIT skill profiles',
            'Enable Cortex automatic tactics',
            'Enable Cortex vehicle tactics',
            'Enable spotter artillery support',
            'Proactive attack-run countermeasures',
            'Missile-threat countermeasures',
            'Selected WAIT skill profile',
        ]:
            self.assertIn(label,spec)
        self.assertIn('"AIR_DEFENCE"',spec)
        self.assertNotIn('"Skill profiles",',spec)
        self.assertNotIn('"Cortex behaviours",',spec)

    def test_cortex_control_spec_has_one_canonical_row_per_setting(self):
        spec=source('cortexTuningSpec')
        keys=re.findall(r'^\s*\["(WAIT_[A-Za-z0-9_]+)"\s*,',spec,re.MULTILINE)
        self.assertGreater(len(keys),40)
        duplicates=sorted({key for key in keys if keys.count(key)>1})
        self.assertEqual([],duplicates)

    def test_cba_catalogue_has_registered_sections_and_matching_shipped_defaults(self):
        """Every CBA control must have one section and the same primitive default as aiConfig."""
        spec=source('cortexTuningSpec')
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        sections=source('aiTweaksSettingsSections')
        registration=source('aiTweaksRegisterSettings')
        section_keys=set(re.findall(r'^\s*\["([A-Z_]+)",\s*"\d\d ',sections,re.MULTILINE))
        rows=re.findall(
            r'^\s*\["(WAIT_[^"]+)",.*?,\s*"(?:CHECKBOX|SLIDER|COMBO)",\s*.*?,\s*'
            r'(true|false|-?\d+(?:\.\d+)?|"[^"]*"),\s*"([A-Z_]+)",\s*'
            r'"(?:LIVE|NEXT_OPERATION|RESTART_REQUIRED)"\],',
            spec,
            re.MULTILINE,
        )
        shipped=dict(re.findall(r'^\s*\["(WAIT_[^"]+)",\s*(.+?)\],(?:\s*//.*)?$',config,re.MULTILINE))
        self.assertGreater(len(rows),100)
        self.assertEqual([],sorted({section for _,_,section in rows}-section_keys))
        self.assertEqual([],sorted(key for key,_,_ in rows if key not in shipped))
        self.assertEqual(
            {},
            {key:(default,shipped[key].strip()) for key,default,_ in rows if shipped[key].strip()!=default},
        )
        self.assertIn('private _rows = _spec select {(_x select 6) == _section};',registration)
        self.assertIn('call CBA_fnc_addSetting;',registration)

    def test_published_cortex_defaults_match_current_core_switches(self):
        import re
        defaults=(ROOT/'cortex_defaults.md').read_text(encoding='utf-8')
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        shipped=dict(re.findall(r'^\s*\["(WAIT_[^"]+)",\s*(.+?)\],(?:\s*//.*)?$',config,re.MULTILINE))
        published=dict(re.findall(r'^\| `([^`]+)` \| `([^`]+)` \|',defaults,re.MULTILINE))
        self.assertGreater(len(shipped),100)
        self.assertEqual([],sorted(set(shipped)-set(published)))
        self.assertEqual({}, {key:(value.strip(),published[key]) for key,value in shipped.items() if published[key] != value.strip()})
        for key in ['WAIT_AIPass_CounterBattery_Enable','WAIT_AIPass_CounterBattery_RadarRange',
                    'WAIT_AIPass_CounterBattery_Delay','WAIT_AIPass_CounterBattery_RadarDelay',
                    'WAIT_AIPass_CounterBattery_Rounds']:
            self.assertIn(key,published)

    def test_counter_battery_diagnostics_report_the_automatic_default(self):
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        expected='missionNamespace getVariable ["WAIT_AIPass_CounterBattery_Mode", "AUTO"]'
        self.assertIn('["WAIT_AIPass_CounterBattery_Mode", "AUTO"]',config)
        self.assertIn(expected,diagnostics)
        self.assertNotIn('missionNamespace getVariable ["WAIT_AIPass_CounterBattery_Mode", "KNOWN"]',diagnostics)

    def test_diagnostics_master_fallbacks_match_enabled_defaults(self):
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        for key in ['WAIT_AIRebalance_Enable','WAIT_AIPass_Enable']:
            self.assertIn(f'["{key}", true]',config)
            self.assertIn(f'missionNamespace getVariable ["{key}", true]',diagnostics)
            self.assertNotIn(f'missionNamespace getVariable ["{key}", false]',diagnostics)

    def test_replacement_clear_retires_old_movement_after_validation(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        marker='if (!_resume && {_previous isNotEqualTo []}) then {[_group] call WAIT_fnc_CortexClearRelease};'
        self.assertIn(marker,text)
        self.assertLess(text.index('if (_positions isEqualTo [])'),text.index(marker))
        self.assertLess(text.index('if (_team isEqualTo [])'),text.index(marker))
        self.assertLess(text.index(marker),text.index('_group setVariable ["WAIT_AIPass_ClearOrder", [_building'))

    def test_door_audit_uses_clearance_and_measures_animation_and_entry(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8').split('// Exercise door handling',1)[1]
        self.assertIn('call WAIT_fnc_CortexClearBuilding',text)
        self.assertIn('CLEAR-door-lock-preserved',text)
        self.assertIn('CLEAR-door-unlocked-physical-entry',text)
        self.assertIn('vectorDistance (AGLToASL _position) <= 1.5',text)
        self.assertNotIn('call WAIT_fnc_CortexBuildingDoor',text)
        self.assertNotIn('call BIS_fnc_door',text)
        self.assertNotIn('animateSource [',text)

    def test_garrison_does_not_command_players_or_incapacitated_members(self):
        for name in ['cortexGarrison','cortexGarrisonApplyLocal','cortexGarrisonRelease']:
            text=source(name)
            self.assertIn('!isPlayer',text)
            self.assertIn('INCAPACITATED',text)
        release=source('cortexGarrisonRelease')
        self.assertLess(release.index('enableAI "PATH"'),release.index('if (alive _x && {!isPlayer'))

    def test_building_door_helper_preserves_locks_and_requires_local_proximity(self):
        text=source('cortexBuildingDoor')
        self.assertIn('!local _unit',text)
        self.assertIn('_lock isEqualTo 0',text)
        self.assertIn('vectorDistance _position <= 12',text)
        self.assertIn('serverTime+2',text)
        self.assertIn('isNil {_building getVariable "WAIT_Cortex_DoorDefinitions"}',text)
        self.assertLess(text.index('private _requested=false'),text.index('private _lock='))
        self.assertIn('call BIS_fnc_door',text)
        self.assertNotIn('animateSource',text)
        self.assertNotIn('setPos',text)
        self.assertNotIn('setVariable [format ["bis_disabled',text)

    def test_native_building_operations_have_no_external_delegation_path(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        garrison=source('cortexGarrison')
        for text in [clear,garrison]:
            self.assertNotIn('useBuildingBackend',text)
            self.assertNotIn('BuildingBackend',text)
        comparison=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        self.assertNotIn('useBuildingBackend',comparison)
        self.assertNotIn('compatibility-backend',comparison)
    def test_clearance_releases_casualty_and_transferred_member_reservations(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        release=text.split('// Release reservations before selection',1)[1].split('private _now',1)[0]
        self.assertIn('!alive _x',release)
        self.assertIn('group _x != _group',release)
        self.assertIn('isPlayer _x',release)
        self.assertIn('lifeState _x == "INCAPACITATED"',release)
        self.assertIn('_assigned set [_forEachIndex,[]]',release)
        self.assertIn('if (_restore) then {',text)
        release=source('cortexClearRelease')
        self.assertIn('params [["_group", grpNull, [grpNull]],["_restore",true,[true]]]',release)
        tick=source('cortexGroupTick')
        self.assertIn('[_group,false] call WAIT_fnc_CortexClearRelease',tick)

    def test_clearance_timeout_cannot_clear_rooms_or_abort_other_workers(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        timeout=text.split('if (_now-_lastProgress > _retryDelay)',1)[1].split('_state set [0,_cursor]',1)[0]
        self.assertNotIn('_cleared pushBack',timeout)
        self.assertNotIn('movementFailed',text)
        self.assertIn('_unreachable pushBackUnique _positionIndex',timeout)
        self.assertIn('_failures pushBackUnique _pairId',timeout)
        self.assertIn('count _failures >= _failureThreshold',timeout)
        self.assertIn('_x doMove _unitTarget',timeout)
        self.assertNotIn('setDestination',timeout)
        self.assertIn('private _moved=_point distance2D _moverPrevious >= 1',text)
        self.assertIn('if (_approachingEntry && {!_moved}) then {',text)
        self.assertIn('_retries < 3',timeout)
        self.assertIn('count (_job get "cleared") == count (_job get "positions")',text)

    def test_clearance_attempts_one_isolated_recovery_before_abandoning_a_room(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        recovery=text.split('private _recovery = if (_operationGeneration >= 0) then {',1)[1].split('private _pairId=format',1)[0]
        self.assertIn('call WAIT_fnc_RecoveryStep',recovery)
        self.assertIn('_recovery == "RECOVERING"',recovery)
        self.assertIn('_lastPositions=_pair apply {getPosATL _x}',recovery)
        self.assertNotIn('_unreachable pushBack',recovery)

    def test_recovery_rechecks_ownership_before_issuing_its_direct_move(self):
        recovery=source('recoveryStep')
        for requirement in ['WAIT_fnc_CortexExternalTakeover','vehicle _actor != _actor',
                            'WAIT_fnc_CortexCombatEffective','exitWith {"YIELDED"}']:
            self.assertIn(requirement,recovery)
        self.assertLess(recovery.index('exitWith {"YIELDED"}'),recovery.index('_actor doMove _destination'))
        self.assertGreaterEqual(recovery.count('WAIT_fnc_CortexExternalTakeover'),2)
        final_check=recovery.rindex('WAIT_fnc_CortexExternalTakeover')
        self.assertLess(final_check,recovery.index('_actor doMove _destination'))
        self.assertIn('private _currentOperation=',recovery[final_check:])
        self.assertIn('_currentOperation set ["recovery",_recovery]',recovery[final_check:])
        self.assertNotIn('_group setVariable ["WAIT_Operation",_operation,true]',recovery)

    def test_clearance_release_resumes_formation_after_do_stop(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        release=source('cortexClearRelease')
        self.assertIn('private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;',clear)
        self.assertIn('private _leader=[_group] call WAIT_fnc_CortexGroupAnchor;',clear)
        self.assertIn('if (isNull _leader) then {_leader=leader _group};',clear)
        self.assertIn('private _leader=[_group] call WAIT_fnc_CortexGroupAnchor;',release)
        self.assertIn('if (isNull _leader) then {_leader=leader _group};',release)
        self.assertIn('_x doFollow _leader',clear)
        self.assertIn('_x doFollow _leader',release)
        self.assertNotIn('_x commandFollow _leader',clear)
        self.assertNotIn('_x commandFollow _leader',release)

    def test_explicit_building_and_hold_orders_anchor_on_a_surviving_local_actor(self):
        """Leader loss must not turn an otherwise viable CQB, garrison or defence operation inert."""
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _entryOrigin=getPosATL _leader;',clear)
        for name in ['cortexDefend','cortexGarrison','cortexDefendRelease','cortexGarrisonRelease']:
            text=source(name)
            self.assertIn('WAIT_fnc_CortexGroupAnchor',text,name)
            self.assertIn('if (isNull _',text,name)
        flank=source('cortexFlankStep')
        self.assertIn('private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;',flank)
        self.assertIn('getPosATL ([_group] call WAIT_fnc_CortexGroupAnchor)',flank)

    def test_clearance_release_cancels_only_its_matching_common_operation(self):
        release=source('cortexClearRelease')
        self.assertIn('private _operation=_group getVariable ["WAIT_Operation",createHashMap];',release)
        self.assertIn('(_operation getOrDefault ["intent",""]) == "CLEAR"',release)
        self.assertIn('"CLEAR_RELEASE"] call WAIT_fnc_OperationCancel',release)

    def test_holding_release_restores_leader_but_yields_to_zeus_replacement(self):
        garrison=source('cortexGarrisonRelease')
        defend=source('cortexDefendRelease')
        tick=source('cortexGroupTick')
        for release in [garrison,defend]:
            self.assertIn('["_restore",true,[true]]',release)
            self.assertIn('private _externalTakeover = [_group] call WAIT_fnc_CortexExternalTakeover;',release)
            self.assertIn('private _canRestore = _restore && {!_externalTakeover};',release)
            self.assertIn('_canRestore || {!_externalTakeover && {_ownedHold',release)
            self.assertIn('_x doFollow _leader',release)
            self.assertIn('["","STOP","ATTACK","FIRE","SUPPRESS"]',release)
        self.assertIn('[_group,false] call WAIT_fnc_CortexGarrisonRelease',tick)
        self.assertIn('[_group,false] call WAIT_fnc_CortexDefendRelease',tick)

    def test_clearance_rotates_failed_position_between_workers(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _failedBy',text)
        self.assertIn('private _failureThreshold=(count (_job get "pairs")) min 2 max 1',text)
        self.assertIn('(_job get "pending") pushBackUnique _positionIndex',text)
        self.assertIn('private _pairId=format ["PAIR_%1",_pairIndex]',text)
        self.assertIn('for "_exitIndex" from 0 to 15 do',text)
        self.assertIn('private _ranked=_entries apply',text)

    def test_clearance_uses_independent_workers_and_continuous_room_routes(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _allPositions = _building buildingPos -1',text)
        self.assertIn('lineIntersectsSurfaces',text)
        self.assertIn('private _pairs=[];',text)
        self.assertIn('if ((_forEachIndex mod 2) == 0) then {',text)
        self.assertNotIn('private _pairs=_team apply {[_x]}',text)
        self.assertIn('private _team = +_available',text)
        self.assertIn('private _squadElement = ceil ((count _available) / 2)',text)
        self.assertIn('private _topologyElement = ((count _allPositions) max 2) min 8',text)
        self.assertIn('private _entryCapacity = ((2 max _squadElement) min _topologyElement) min 8',text)
        self.assertIn('private _pending=+_routeOrder',text)
        self.assertIn('private _pairRoutes=_pairs apply {[]}',text)
        self.assertIn('_pairStates pushBack [0,false',text)
        self.assertIn('_entries resize ((count _entries) min 4)',text)
        self.assertIn('private _claimedEntryIndices=[]',text)
        self.assertIn('private _unclaimed=_ranked select {!((_x select 1) in _claimedEntryIndices)}',text)
        self.assertIn('_claimedEntryIndices pushBackUnique _entryIndex',text)
        self.assertIn('_approachingEntry=false',text)
        self.assertIn('_approachingEntry=true',text)
        self.assertIn('_approachingEntry=_entryTarget isNotEqualTo []',text)
        self.assertIn('if (!_entered && {(_job get "entries") isNotEqualTo []})',text)
        self.assertIn('_unit setUnitPos "UP"',text)
        self.assertIn('_unit forceSpeed _clearSpeed',text)
        self.assertIn('WAIT_Cortex_ClearAppliedSpeed',text)
        self.assertIn('private _retryDelay=[12,4] select _commandEnded',text)
        self.assertIn('private _commandEnded=currentCommand _point in ["","STOP"];',text)
        self.assertNotIn('_pair findIf {currentCommand _x in ["","STOP"]}',text)
        self.assertIn('private _moverSlot=_moverIndex mod count _pair',text)
        progress=text.split('// Once inside, only the assigned room mover proves progress toward this room.',1)[1].split('if (_positionIndex in _cleared)',1)[0]
        self.assertIn('_point distance2D _moverPrevious >= 1',progress)
        self.assertIn('if (_approachingEntry && {!_moved}) then {',progress)
        self.assertNotIn('} forEach _pair;\n                    if (_moved) then {',progress)
        self.assertNotIn('setVehiclePosition',text)
        self.assertIn('_triedEntries pushBackUnique _entryIndex',text)
        self.assertIn('_cursor=_cursor+1',text)

    def test_clearance_workers_claim_without_node_crowding(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _point=_pair select (_moverIndex mod count _pair)',text)
        self.assertIn('private _supportTarget=[]',text)
        self.assertIn('_previousPositionIndex=_positionIndex',text)
        self.assertIn('private _unitTarget=if (_unit == _point',text)
        self.assertIn('_failureThreshold=(count (_job get "pairs")) min 2 max 1',text)
        self.assertNotIn('"ROTATE"',text)

    def test_clearance_reinforces_casualties_from_uncommitted_squad_members(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _reserves=(units _group) select',text)
        self.assertIn('_pair set [_slot,_replacement]',text)
        self.assertIn('WAIT_Cortex_ClearReinforcements',text)
        self.assertIn('lifeState _member == "INCAPACITATED"',text)

    def test_clearance_rotates_operation_quarantined_workers_without_stalling_other_lanes(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _unavailable=if ((_operation getOrDefault ["generation",-1]) == _operationGeneration',text)
        self.assertIn('(_reserved select {_x in _unavailable})',text)
        self.assertIn('|| {_member in _unavailable}) && {_reserves isNotEqualTo []})',text)
        self.assertIn('&& {!(_x in _unavailable)} && {group _x == _group}',text)
        self.assertIn('private _pair=_x select {alive _x',text)
        self.assertIn('!(_x in _unavailable)',text)

    def test_clearance_egresses_before_terminal_handover(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('(_job getOrDefault ["phase","CLEAR"]) == "EGRESS"',text)
        self.assertIn('[_unit,_entry getPos [10,_outward]]',text)
        self.assertIn('_job set ["phase","EGRESS"]',text)
        self.assertIn('_job set ["egressAssignments",_egressAssignments]',text)
        self.assertIn('_job set ["egressFailed",true]',text)
        self.assertIn('!(_job getOrDefault ["egressFailed",false])',text)

    def test_clearance_rechecks_external_ownership_at_each_movement_write(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _mayIssueMovement = {',text)
        self.assertIn('!([_group] call WAIT_fnc_CortexExternalTakeover)',text)
        self.assertIn('&& {call _mayIssueMovement}',text)
        self.assertGreaterEqual(text.count('if (call _mayIssueMovement) then {'),2)
        for command in ['_unit doMove _target;','_unit doMove _unitTarget;','_x doMove _unitTarget;']:
            index=text.index(command)
            self.assertIn('_mayIssueMovement',text[max(0,index-1000):index])
    def test_holding_operations_recheck_external_ownership_before_route_writes(self):
        garrison=source('cortexGarrisonApplyLocal')
        defend=source('cortexDefendApplyLocal')
        reserve=source('cortexDefendStep')
        for text in [garrison,defend]:
            self.assertGreaterEqual(text.count('private _mayIssueMovement = {'),2)
            self.assertIn('!([_group] call WAIT_fnc_CortexExternalTakeover)',text)
            self.assertIn('&& {call _mayIssueMovement}',text)
        self.assertIn('if (call _mayIssueMovement) then {',garrison)
        self.assertIn('private _openedDoor = if (call _mayIssueMovement)',garrison)
        self.assertIn('[_group] call WAIT_fnc_CortexExternalTakeover',reserve)
        self.assertLess(reserve.index('CortexExternalTakeover'),reserve.index('_x setVariable ["WAIT_AIPass_DefendPos"'))
        self.assertNotIn('_x doMove _position;',reserve)
        self.assertIn('[_group,_reserve] call WAIT_fnc_CortexDefendApplyLocal',reserve)

    def test_garrison_duck_handlers_yield_to_a_later_external_owner(self):
        """Suppression callbacks must not alter the posture of a Zeus or specialist-owned unit."""
        garrison=source('cortexGarrisonApplyLocal')
        duck=garrison.split('private _duck = {',1)[1].split('_unit setVariable ["WAIT_AIPass_GarrisonHandlerIds"',1)[0]
        self.assertGreaterEqual(duck.count('WAIT_fnc_CortexExternalTakeover'),2)
        self.assertIn('|| {[group _unit] call WAIT_fnc_CortexExternalTakeover}) exitWith {};',duck)
        self.assertIn('&& {!([group _unit] call WAIT_fnc_CortexExternalTakeover)}) then {',duck)

    def test_reactive_direct_commands_recheck_external_ownership(self):
        dismount=source('convoyDismountLocal')
        civilian=source('cortexCivilianReact')
        armour=source('cortexAntiArmour')
        grenade=source('cortexGrenadeCheck')
        self.assertIn('&& {!([group _unit] call WAIT_fnc_CortexExternalTakeover)}) then {',dismount)
        self.assertLess(civilian.rindex('CortexExternalTakeover'),civilian.rindex('_unit doMove _destination;'))
        self.assertGreaterEqual(armour.count('CortexExternalTakeover'),2)
        self.assertLess(armour.index('if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {false};', armour.index('if (_blocked) exitWith {')),
                        armour.index('_gunner doMove _spot;'))
        self.assertIn('&& {!([_group] call WAIT_fnc_CortexExternalTakeover)}) then {',grenade)
    def test_tactical_drills_recheck_takeover_before_bound_and_retry_commands(self):
        step=source('cortexFlankStep')
        self.assertIn('private _mayIssueMovement = {',step)
        self.assertIn('!([_group] call WAIT_fnc_CortexExternalTakeover)',step)
        self.assertIn('if (call _mayIssueMovement) then {',step)
        self.assertIn('&& {call _mayIssueMovement}) then {',step)
        for command in ['_actor doMove _rally;','_unit doMove _spot;','_unit doMove (_spots select _forEachIndex);']:
            index=step.index(command)
            self.assertIn('_mayIssueMovement',step[max(0,index-800):index])
    def test_combined_arms_and_convoy_crew_yield_at_final_command_boundaries(self):
        combined=source('cortexCombinedArmsLocal')
        ground=source('cortexCombinedGroundStep')
        crew=source('convoyCrewLocal')
        self.assertGreaterEqual(combined.count('CortexExternalTakeover'),5)
        ground_fire=combined.split('if (_role == "GROUND_FIRE") exitWith {',1)[1].split('if (_role == "GROUND_MANOEUVRE") exitWith {',1)[0]
        self.assertLess(ground_fire.index('CortexExternalTakeover'),ground_fire.index('_gunner doTarget _target'))
        self.assertNotIn('forEach crew _asset',combined)
        self.assertLess(combined.rindex('CortexExternalTakeover'),combined.index('call WAIT_fnc_AirAttackOperationStart'))
        self.assertIn('!([_group] call WAIT_fnc_CortexExternalTakeover) then {',ground)
        self.assertIn('&& {!([_group] call WAIT_fnc_CortexExternalTakeover)}) then {_gunner doTarget _target; _gunner doFire _target};',ground)
        self.assertIn('if ([_group] call WAIT_fnc_CortexExternalTakeover ||',crew)
        self.assertIn('&& {!([group _unit] call WAIT_fnc_CortexExternalTakeover)}) then {',crew)
    def test_driving_recovery_rechecks_takeover_after_sparse_terrain_sampling(self):
        driving=source('drivingAssistStart')
        self.assertIn('private _mayIssueDriving = {',driving)
        self.assertIn('!([_group] call WAIT_fnc_CortexExternalTakeover)',driving)
        self.assertIn('if !(call _mayIssueDriving) then {',driving)
        self.assertIn('[_vehicle] call WAIT_fnc_DrivingAssistRelease;',driving)
        self.assertLess(driving.index('if !(call _mayIssueDriving) then {'),driving.index('_vehicle forceSpeed _capMps;'))
        recovery=driving.split('if (_hasRoute &&',1)[1].split('switch (_recoveryStage)',1)[0]
        self.assertIn('&& {call _mayIssueDriving}',recovery)
    def test_naval_operations_release_without_overwriting_external_orders(self):
        naval=source('cortexNavalAssault')
        release=source('cortexNavalRelease')
        self.assertIn('if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {',naval)
        self.assertIn('[_group,_state,"EXTERNAL"] call WAIT_fnc_CortexNavalRelease',naval)
        self.assertLess(naval.rindex('CortexExternalTakeover'),naval.rindex('WAIT_fnc_CortexGroupMove'))
        self.assertIn('private _externalTakeover=[_group] call WAIT_fnc_CortexExternalTakeover;',release)
        self.assertIn('if (_saved isNotEqualTo [] && {!_externalTakeover} && {_ownedStop >= 0}',release)
    def test_clearance_preserves_live_behaviour_and_combat_mode(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        release=source('cortexClearRelease')
        self.assertNotIn('_group setBehaviour "COMBAT"',clear)
        self.assertNotIn('_group setBehaviour (_job get "baseBehaviour")',clear)
        self.assertNotIn('_group setBehaviour (_order select 3)',release)
        self.assertNotIn('setCombatMode',clear)
        self.assertNotIn('setCombatMode',release)

    def test_zeus_takeover_cleanup_does_not_replace_curator_movement(self):
        release=source('cortexReleaseGroup')
        restore=source('cortexRestoreCalm')
        flank_end=source('cortexFlankEnd')
        self.assertIn('private _yieldToZeus=local _group && {[_group] call WAIT_fnc_CortexZeusHeld}',release)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',release)
        self.assertIn('private _externalTakeover=_yieldToZeus || {_yieldToExternal}',release)
        self.assertIn('["RELEASE","ZEUS"] select _externalTakeover',release)
        self.assertIn('[_group, _state, false, _externalTakeover, _reason] call WAIT_fnc_CortexRestoreCalm',release)
        self.assertIn('"EXTERNAL_TAKEOVER"',release)
        self.assertIn('["_yieldToExternal",false,[true]]',restore)
        self.assertIn('if (!_yieldToExternal && {_state getOrDefault ["behaviourChanged", false]}',restore)
        self.assertIn('if (!_yieldToExternal && {_state getOrDefault ["speedChanged", false]})',restore)
        self.assertIn('preserving a newer individual command',restore)
        self.assertIn('!(_reason in ["ZEUS","OWNERSHIP_LOST"])',flank_end)
        self.assertIn('if (_mayCommand) then',flank_end)

    def test_garrison_reassigns_unreachable_positions_without_wall_clock_failure(self):
        order=source('cortexGarrison')
        apply=source('cortexGarrisonApplyLocal')
        release=source('cortexGarrisonRelease')
        self.assertIn('WAIT_Cortex_GarrisonCandidates',order)
        self.assertIn('WAIT_Cortex_GarrisonCandidates',release)
        self.assertIn('_reassignments < 2',apply)
        self.assertIn('_x setVariable ["WAIT_AIPass_GarrisonPos",_replacement,true]',apply)
        self.assertIn('!(_key in _attempted)',apply)
        self.assertIn('for "_index" from 0 to 31 do',apply)
        self.assertIn('Garrison trying alternate entrance',apply)
        self.assertIn('private _approach = _entries isNotEqualTo [] && {_unit distance2D _destination > 30}',apply)
        self.assertIn('private _target = if (_approach) then {_entries select 0} else {_destination}',apply)
        self.assertIn('private _replacementApproach=_replacementEntries isNotEqualTo []',apply)
        self.assertIn('private _replacementTarget=if (_replacementApproach)',apply)
        self.assertIn('private _replacementAnchor=if (_replacementApproach)',apply)
        self.assertIn('_entries resize ((count _entries) min 4)',apply)
        self.assertIn('if (_nextEntry < count _entries && {call _mayIssueMovement}) then',apply)
        self.assertNotIn('doStop _x; _x doMove',apply)
        self.assertIn('if (call _mayIssueMovement) then {doStop _unit}',apply)
        self.assertIn('["deadline", time + 240]',apply)
        self.assertNotIn('_job set ["deadline",(_job get "deadline") max (time+60)]',apply)

    def test_defence_recovery_uses_per_unit_physical_progress(self):
        order=source('cortexDefend')
        reserve=source('cortexDefendStep')
        self.assertIn('forEach [0.75,0.5,0.25,0]',order)
        self.assertIn('[_centre,_rearCandidates,_threat] call WAIT_fnc_CortexSelectAvenue',order)
        self.assertIn('forEach [0.65,0.35,0]',reserve)
        self.assertIn('surfaceNormal _position',reserve)
        text=source('cortexDefendApplyLocal')
        self.assertIn('_routes pushBack [_x,getPosATL _x,time,0,_routeGeneration]',text)
        self.assertIn('WAIT_AIPass_DefendRouteGeneration',text)
        self.assertIn('if (_fullApply) then {_actors=+units _group}',text)
        self.assertIn('forEach (_job get "actors")',text)
        self.assertIn('_unit distance2D _lastPosition >= 1',text)
        self.assertIn('time-_lastProgress >= 15',text)
        self.assertIn('_retries < 3',text)
        self.assertIn('_unit doMove (_assignment select 0)',text)
        self.assertNotIn('_unit setDestination',text)
        self.assertNotIn('["deadline", time + 90]',text)

    def test_defence_reserve_reinforcement_does_not_replan_the_established_line(self):
        apply=source('cortexDefendApplyLocal')
        reserve=source('cortexDefendStep')
        release=source('cortexDefendRelease')
        self.assertIn('["_actors",[],[[]]]',apply)
        self.assertIn('private _fullApply=_actors isEqualTo []',apply)
        self.assertIn('if (_fullApply || {_generation <= 0}) then {',apply)
        self.assertIn('forEach _actors',apply)
        self.assertNotIn('_group setVariable ["WAIT_AIPass_DefendApplied", false]',reserve)
        self.assertNotIn('_x doMove _position',reserve)
        self.assertIn('[_group,_reserve] call WAIT_fnc_CortexDefendApplyLocal',reserve)
        self.assertIn('WAIT_AIPass_DefendRouteGeneration',release)

    def test_clearance_renews_safety_lease_only_on_observed_progress(self):
        text=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _madeProgress=count _cleared != _before',text)
        self.assertIn('_job set ["deadline",(_job get "deadline") max (serverTime+120)]',text)
        self.assertIn('_job set ["lastProgressAt",serverTime]',text)
        self.assertNotIn('_job set ["deadline",serverTime+120]',text)

    def test_clearance_preserves_failure_evidence_after_release(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        release=source('cortexClearRelease')
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        self.assertIn('_group setVariable ["WAIT_Cortex_ClearEvidence",[+(_job get "cleared")',clear)
        self.assertIn('_group setVariable ["WAIT_Cortex_ClearEvidence",[+(_order param [1,[]])',release)
        self.assertIn('_group getVariable ["WAIT_Cortex_ClearEvidence",[]]',diagnostics)
        self.assertIn('_clearEvidence param [3,[]]',diagnostics)

    def test_building_scale_cases_use_fresh_groups_and_observed_room_visits(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        cases=text.split('// Fresh groups distinguish',1)[1]
        self.assertIn('[2,"Land_i_House_Small_01_V1_F"]',cases)
        self.assertIn('[6,"Land_i_House_Big_01_V1_F"]',cases)
        self.assertIn('[12,"Land_i_House_Big_02_V1_F"]',cases)
        self.assertIn('call WAIT_fnc_CortexClearBuilding',cases)
        self.assertIn('vectorDistance (AGLToASL _room) <= 1.5',cases)
        self.assertIn('private _clearingMembers=+_members',cases)
        self.assertNotIn('_members select [1,2]',text)
        self.assertNotIn('setPos',cases)
        self.assertNotIn('call WAIT_fnc_CortexGarrison',cases)

    def test_cqb_casualty_uses_real_reserve_and_physical_movement(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        case=text.split('// A casualty inside the clearing element',1)[1].split('// Exercise door handling',1)[0]
        self.assertIn('for "_i" from 0 to 9 do',case)
        self.assertIn('_casualty setDamage 1',case)
        self.assertIn('WAIT_Cortex_ClearReinforcements',case)
        self.assertIn('CLEAR-casualty-reserve-assigned',case)
        self.assertIn('CLEAR-casualty-reserve-physical-movement',case)
        self.assertNotIn('setPos',case)
        self.assertNotIn('moveIn',case)

    def test_building_entry_controls_cover_four_distinct_models(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8').split('missionNamespace setVariable ["WAIT_CortexQA_Actors"',1)[0]
        for building in ['Land_i_House_Small_03_V1_F','Land_i_House_Small_01_V1_F','Land_i_House_Big_01_V1_F','Land_i_House_Big_02_V1_F']:
            self.assertIn(building,text)

    def test_remount_retry_preserves_active_boarding_command(self):
        text=source('cortexGroupTick')
        self.assertIn('if (assignedVehicle _unit != _vehicle) then {_unit assignAsCargo _vehicle}',text)
        self.assertIn('if ([] call _mayIssueMovement && {toUpperANSI (currentCommand _unit) != "GET IN"}) then {[_unit] orderGetIn true}',text)

    def test_remount_yields_to_live_danger_and_command_ownership(self):
        text=source('cortexGroupTick')
        remount=text.split('private _remount = _group getVariable ["WAIT_Cortex_Remount",[]];',1)[1].split('private _contactDelay',1)[0]
        self.assertIn('_visible isNotEqualTo [] || {_dangerActive} || {_ordered}',remount)
        self.assertIn('if (_visible isNotEqualTo [] || {_dangerActive}) then {_state set ["dismounted",+_pending]};',remount)
        self.assertIn('|| {!([] call _mayIssueMovement)}',remount)
        for command in ['[_unit] orderGetIn false','unassignVehicle _unit','_unit assignAsCargo _vehicle','[_unit] orderGetIn true']:
            self.assertIn(command,remount)
            self.assertIn('_mayIssueMovement',remount[max(0,remount.index(command)-500):remount.index(command)])

    def test_replacement_boarding_audit_requires_owned_exit_and_physical_arrival(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        case=text.split('if (_replacementOrder) then {',1)[1].split('["Vehicle calm remount:',1)[0]
        self.assertIn('assignAsCargo _replacement',case)
        self.assertNotIn('moveInCargo',case)
        self.assertNotIn('call WAIT_fnc_CortexRestoreCalm',case)
        self.assertIn('REMOUNT-replacement-assignment-preserved',case)
        self.assertIn('REMOUNT-replacement-physically-boarded',case)
        self.assertIn('_ownedExit && {_replacementBoarded}',case)
        self.assertIn('assignedVehicle _x != _replacement',case)

    def test_remount_preserves_replacement_vehicle_assignment(self):
        tick=source('cortexGroupTick')
        restore=source('cortexRestoreCalm')
        self.assertIn('assignedVehicle (_x select 0) == (_x select 1)',tick)
        for text in [tick,restore]:
            self.assertIn('assignedVehicle _unit == (_x select 1)',text)
        self.assertIn('isNull assignedVehicle _unit || {assignedVehicle _unit == _vehicle}',restore)

    def test_passenger_exit_records_ownership_before_engine_commands(self):
        text=source('cortexVehicles')
        self.assertLess(text.index('_state set ["dismounted", _dismounted]'),text.index('[_unit] orderGetIn false'))
        self.assertLess(text.index('[_unit] orderGetIn false'),text.index('doGetOut _unit'))

    def test_support_fixture_preserves_occlusion_and_assigned_destination(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runSupport.sqf').read_text(encoding='utf-8')
        self.assertLess(text.index('createVehicle ["Land_CncWall4_F"'),text.index('private _listeners='))
        self.assertIn('HEARING-fixture-no-prior-contact',text)
        self.assertIn('_rally=+(_assignedLease select 3)',text)
        self.assertIn('_x distance2D (_helperStarts select (_helpers find _x)) < 15',text)
        self.assertIn('_x distance2D _rally > 45',text)
        self.assertIn('forEach _soundTrace',text)

    def test_countermeasure_inventory_is_per_vehicle_and_live(self):
        text=source('cortexFireCountermeasure')
        self.assertNotIn('CountermeasureCache',text)
        self.assertIn('_vehicle weaponsTurret _turret',text)
        self.assertIn('toLowerANSI',text)
        self.assertIn('Fired events establish actual fire',text)

    def test_artillery_baseline_retains_counter_owner(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        for gun in ['_gun','_counterGun','_emitter']:
            self.assertIn('['+gun+'] call _retainServerGun',text)
        self.assertIn('server-owner-retained',text)
        self.assertIn('local gunner _counterGun',text)

    def test_cortex_stop_invalidates_delayed_vehicle_actions(self):
        stop=source('cortexStop')
        self.assertIn('} forEach vehicles;',stop)
        for variable in ['WAIT_Cortex_ArtilleryScootToken','WAIT_Cortex_ArtilleryScootDeadline','WAIT_Cortex_ArtilleryScootPurpose','WAIT_Cortex_AttackFlarePhase','WAIT_Cortex_AttackFlareCooldown']:
            self.assertIn('setVariable ["'+variable+'",nil,true]',stop)
        self.assertIn('old CBA callback cannot become valid again after a quick restart',stop)

    def test_ai_diagnostics_feature_depth_and_queue_scope(self):
        diagnostic=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        for feature in ['Regroup','Contact','PostContact','Flank','StreetCrossing','FireControl','Morale','Surrender','GrenadeEvasion','AntiArmour','Vehicles','ContactReports','Reinforce','Artillery','CounterBattery','Airborne','AircraftFlares','Investigate','Assault','Advance','CoordinatedAssault','Stance','AmmoShare','VehicleGunnery','ArtillerySmoke','AircraftBreak','VehicleDismount','VehicleRemount','VehicleWithdraw','CoverValidation','Hearing','MountedFire','Cover','AvoidInfantry','ContactHalt','Unload']:
            self.assertIn('["'+feature+'",',diagnostic)
        self.assertIn('private _parents=+(_dependencies',diagnostic)
        self.assertIn('oldestDueSeconds=',diagnostic)
        self.assertIn('keyedJobs=',diagnostic)
        self.assertIn('private _keyedJobs=0;',diagnostic)
        self.assertIn('staleOwnerJobs=',diagnostic)
        self.assertIn('cachedNextDueSeconds=',diagnostic)
        self.assertIn('earliestQueuedDueSeconds=',diagnostic)
        self.assertIn('deadlineCacheConsistent=',diagnostic)
        self.assertIn('private _queueState=if (_cacheConsistent) then {"LOADED"} else {"ERROR"}',diagnostic)
        self.assertIn('tuning [label,current,default]',diagnostic)
        self.assertNotIn('call WAIT_fnc_CortexIsEligible',diagnostic)

    def test_ai_diagnostics_are_bounded_read_only_snapshots(self):
        diagnostic=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        self.assertNotIn('call WAIT_fnc_CortexZeusHeld',diagnostic)
        self.assertNotIn('setVariable',diagnostic)
        self.assertNotIn('smart-ai-pass',diagnostic)
        self.assertIn('call WAIT_fnc_CortexTuningSpec',diagnostic)
        self.assertIn('(_localGroups select [0,20])',diagnostic)
        self.assertIn('(units _group) select [0,8]',diagnostic)
        self.assertIn('HC private action/queue state is unavailable here, not zero',diagnostic)
        self.assertIn('confirmedShots=',diagnostic)
        self.assertIn('haltReason=',diagnostic)
        self.assertIn('(_orderedGroups select [0,20])',diagnostic)
        self.assertIn('3D-assignment-distance-or-minus1',diagnostic)
        self.assertIn('cortex-order-snapshot-scope',diagnostic)
        for ownership in ['cortex-remount-ownership-','cortex-transition-ownership-','cortex-support-ownership-','cortex-artillery-scoot-ownership-']:
            self.assertIn(ownership,diagnostic)
        self.assertIn('assignmentConflicts=',diagnostic)
        self.assertIn('intentPhase=',diagnostic)
        self.assertIn('leaseToken=',diagnostic)
        self.assertIn('pending artillery relocations total=',diagnostic)
        self.assertIn('(_scoots select [0,20])',diagnostic)

    def test_full_feature_focus_never_omits_an_all_suite(self):
        import re
        runner=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        selections=re.findall(r'if \(_focus in (\[[^\]]+\])\)',runner)
        for selection in selections:
            if '"all"' in selection:
                self.assertIn('"features"',selection)
        self.assertNotIn('if (_focus == "all")',runner)
        self.assertGreater(runner.index('if (_focus in ["all","features","coordinated","supportflows"])'),runner.index('cortexQAFire.sqf'))

    def test_other_feature_batch_and_independent_artillery(self):
        runner=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        for focus in ['mechanics','reactions','support','airborne','vehicles','fire','landing','cover','contact','profiles','scheduler','performance','lifecycle','aircraft','deceleration','gunnery','artillerysmoke','crossing','convoyseats','avoidance']:
            import re
            self.assertRegex(runner,r'if \(_focus in \[[^\]]*"features"[^\]]*"'+focus+r'"[^\]]*\]\)')
        artillery=runner.split('if (_focus in ["all","features","artillery"]) then {',1)[1].split('if (_focus in ["all","features","convoyseats"',1)[0]
        self.assertNotIn('_u1',artillery)
        self.assertIn('private _spotter=',artillery)
        self.assertIn('deleteVehicle _spotter',artillery)
        self.assertIn('deleteGroup _gunGroup',artillery)

    def test_failed_coordinated_bound_holds_until_new_sequence(self):
        end=source('cortexFlankEnd')
        self.assertIn('_reason in ["STALLED","TIME_LIMIT","RECOVERY_FAILED"]',end)
        hold=end.split('if (_holdFailedBound) then {',1)[1].split('} else {',1)[0]
        self.assertIn('doStop _x',hold)
        self.assertNotIn('disableAI "PATH"',hold)
        self.assertNotIn('supportHeld',hold)
        self.assertNotIn('_x doFollow',hold)
        self.assertIn('[_supportToken,_drill get "supportSequence",_reason]',end)
        maintain=source('cortexSupportMaintain')
        self.assertIn('if (_newMove || {!_coordinating})',maintain)
        self.assertIn('private _newMove=_moving && {(_state getOrDefault ["supportBoundSequence",-1]) != (_role select 1)}',maintain)

    def test_coordinated_clean_approach_is_additive(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        self.assertIn('[[1408,1410] call _terrainPosition,[1608,1410] call _terrainPosition]',qa)
        self.assertIn('[[1500,1470] call _terrainPosition]',qa)
        self.assertIn('["_localScreens",false,[true]]',qa)
        runner=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('if (_focus == "coordinatedbounds")',runner)
        self.assertIn('if (_focus in ["all","features","coordinatedclean"])',runner)
        self.assertIn('[_cleanCheck,_phase,_wait,[],true,true]',runner)
        self.assertIn('["CLEAN-"+_id,_passed,_detail]',runner)

    def test_coordinated_rally_screen_is_removed_before_assault_measurement(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        self.assertIn('COORD-assault-corridor-clear',qa)
        self.assertIn('{deleteVehicle _x} forEach _movementScreens;',qa)
        self.assertLess(qa.index('COORD-assault-corridor-clear'),qa.index('Movement diagnostic: concurrent coordinated bounds'))
        self.assertIn('private _allRallied=true;',qa)
        self.assertIn('private _team=_x;',qa)
        self.assertIn('if ((_team findIf {_x distance2D _area > 45}) >= 0)',qa)
        self.assertIn('_allRallied',qa)
        rally=qa.split('private _rallied=[{',1)[1].split('},120] call _wait;',1)[0]
        self.assertNotIn('(_teams findIf {',rally)

    def test_literal_qa_tuning_requests_have_transport_entries(self):
        import re
        spec = set(re.findall(r'\["(WAIT_[^"]+)"', source('cortexTuningSpec')))
        for path in (ROOT/'releaseVerificationAndDeployment/cortexQA').glob('*.sqf'):
            text = path.read_text(encoding='utf-8')
            for match in re.finditer(r'\[createHashMapFromArray\s*\[', text):
                depth, quoted, end = 1, False, match.start()+1
                # Match the call's outer array; unrelated HashMaps must not consume
                # later code and falsely treat state/diagnostic keys as settings.
                while end < len(text) and depth:
                    char = text[end]
                    if char == '"':
                        if quoted and end+1 < len(text) and text[end+1] == '"':
                            end += 2
                            continue
                        quoted = not quoted
                    elif not quoted:
                        depth += (char == '[') - (char == ']')
                    end += 1
                if not re.match(r'\s*call\s+WAIT_fnc_CortexTuning\b', text[end:]):
                    continue
                requested = set(re.findall(r'\["(WAIT_[^"]+)"', text[match.start():end]))
                self.assertFalse(requested-spec, f'{path.name}: unknown runtime settings {requested-spec}')

    def test_advance_contact_delay_is_in_authoritative_transport(self):
        self.assertIn('"WAIT_AIPass_Advance_MinContactSeconds"', source('cortexTuningSpec'))
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-requested-contact-delay', qa)

    def test_movement_roe_restores_only_the_owned_value(self):
        step = source('cortexFlankStep')
        self.assertIn('_drill set ["groupCombatMode",["RED","YELLOW"]]', step)
        self.assertIn('_group setCombatMode "YELLOW"', step)
        self.assertIn('combatMode _group != (_groupModeLease select 1)', step)
        self.assertNotIn('_group setCombatMode "BLUE"', step)
        for name in ['cortexFlankEnd', 'cortexLocality']:
            self.assertIn('combatMode _group == (_groupModeLease select 1)', source(name))
            self.assertIn('_group setCombatMode (_groupModeLease select 0)', source(name))
        checkpoint=source('cortexCheckpoint')
        self.assertIn('restoreGroupCombatMode',checkpoint)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-combat-mode-restored', qa)

    def test_tactical_bounds_use_an_owned_full_speed_lease(self):
        step=source('cortexFlankStep')
        self.assertIn('_drill set ["groupSpeedMode",[speedMode _group,"FULL"]]',step)
        self.assertIn('_group setSpeedMode "FULL"',step)
        self.assertIn('speedMode _group != (_groupSpeedLease select 1)',step)
        self.assertIn('"SPEED_CHANGED" call _end',step)
        for name in ['cortexFlankEnd','cortexLocality']:
            cleanup=source(name)
            self.assertIn('speedMode _group == (_groupSpeedLease select 1)',cleanup)
            self.assertIn('_group setSpeedMode (_groupSpeedLease select 0)',cleanup)
        self.assertIn('restoreGroupSpeedMode',source('cortexCheckpoint'))

    def test_coordinated_bound_uses_matching_role_objective_before_personal_contact(self):
        text = source('cortexFlankStep')
        self.assertIn('if (_support) then {+(_supportRole select 4)}', text)
        self.assertLess(text.index('!_supportValid'), text.index('private _enemyPos ='))
        self.assertIn('(_supportRole select 0) == _supportToken', text)
        self.assertIn('(_supportRole select 1) == (_drill get "supportSequence")', text)

    def test_tactical_handoffs_use_optional_pause_without_grenade_state_gate(self):
        text = source('cortexFlankStep')
        for stage in ['FINAL','CONSOLIDATE','CLEAR']:
            block = text.split('case "'+stage+'": {')[1].split('case ')[0]
            self.assertIn('WAIT_AIPass_Flank_BoundPause', block)
        road = text.split('case "CROSS_NEAR": {')[1].split('case "FINAL":')[0]
        self.assertIn('_drill set ["pauseUntil", _now]', road)
        self.assertNotIn('_now + 3', road)
        self.assertIn('!_support &&', text)
        self.assertIn('(_drill getOrDefault ["stage",""]) in ["PAUSE","HOLD"]', text)
        self.assertIn('_result=0;', text)
        self.assertIn('_drill set ["grenadeActionUntil",_now]', text)
        self.assertNotIn('case "GRENADE": {', text)

    def test_tactical_bounds_use_dynamic_line_defaults(self):
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        route=source('cortexPlanRoute')
        advance=source('cortexAdvanceStart')
        step=source('cortexFlankStep')
        self.assertIn('["WAIT_AIPass_Flank_BoundDistance", 55]',config)
        self.assertIn('["WAIT_AIPass_Flank_BoundPause", 0]',config)
        self.assertIn('getVariable ["WAIT_AIPass_Flank_BoundDistance", 55]',route)
        self.assertIn('getVariable ["WAIT_AIPass_Flank_BoundDistance", 55]',advance)
        self.assertIn('private _depth = 0;',step)
        self.assertNotIn('formation _group == "WEDGE"',step)
        self.assertNotIn('private _rank = ceil (_forEachIndex / 2)',step)

    def test_support_reserves_separate_rally_areas_in_durable_leases(self):
        server = source('cortexSupportServer')
        step = source('cortexSupportStep')
        self.assertIn('forEach [[80,0],[80,-30],[80,30],[80,-60],[80,60],[60,0],[100,0]]', server)
        self.assertIn('[_requesterPosition,_rallyCandidates,_enemy] call WAIT_fnc_CortexSelectAvenue', server)
        self.assertIn('["enemy",+_enemy]', server)
        self.assertIn('for "_slot" from 0 to 5 do', step)
        self.assertIn('(_other select 3) distance2D _centre < 109', step)
        self.assertIn('!surfaceIsWater _centre', step)
        self.assertIn('((surfaceNormal _centre) select 2) >= 0.55', step)
        self.assertIn('getPosATL _helperTransmitter,_rallyCandidates', step)
        self.assertIn('call WAIT_fnc_CortexSelectAvenue', step)
        self.assertIn('if (_rally isNotEqualTo []) then {', step)
        self.assertIn('_job get "expiry",_rally,_job get "at"', step)
        self.assertNotIn('_job get "expiry",+(_job get "rally")', step)
        fixture=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        self.assertIn('COORD-distinct-rally-areas', fixture)
        self.assertIn('_x distance2D _area > 45', fixture)

    def test_movement_lease_preserves_fire_and_rejects_competing_roe(self):
        step=source('cortexFlankStep')
        self.assertNotIn('call _clearAttack',step)
        self.assertIn('_group setCombatMode "YELLOW"',step)
        self.assertNotIn('_group setCombatMode "BLUE"',step)
        self.assertIn('"ROE_CHANGED" call _end',step)
        self.assertIn('combatMode _group != (_groupModeLease select 1)',step)
        stance=source('cortexStance')
        self.assertIn('in ["START","MOVE"]',stance)
        self.assertIn('+(_drill getOrDefault ["movers"',stance)
        self.assertIn('grenadeThrower',stance)

    def test_coordinated_moving_fire_is_measured_at_discharge(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        fired=qa.split('addEventHandler ["FiredMan",{')[1].split('    }];')[0]
        self.assertIn('abs speed _unit > 2',fired)
        self.assertIn('WAIT_Cortex_SupportTeams',fired)
        self.assertIn('_unit in (_teams select 5)',fired)
        self.assertIn('COORD-moving-roe-fire-at-will-disengaged',qa)
        self.assertIn('combatMode _g != "YELLOW"',qa)
        self.assertIn('_movementRoeSamples',qa)
        self.assertIn('_movementRoeViolations',qa)
        self.assertIn('WAIT_CortexQA_MovingShots',fired)
        self.assertIn('COORD-no-prolonged-empty-range-idle',qa)
        self.assertNotIn('"COORD-no-prolonged-empty-range-idle",_advanced &&',qa)
        self.assertIn('COORD-full-fire-team-physical-bounds',qa)
        self.assertIn('COORD-no-engine-attack-overrides',qa)
        self.assertIn('_stage == "MOVE"',qa)
        self.assertIn('_x distance2D _destination > 3',qa)
        self.assertIn('empty-range limit=18 s',qa)
        self.assertIn('currentCommand _x == "ATTACK"',qa)
        self.assertIn('WAIT_fnc_CortexQAInstallShotCounter',qa)
        self.assertIn('remoteExecCall ["WAIT_fnc_CortexQAInstallShotCounter",_owner]',qa)

    def test_zeus_mark_releases_cortex_immediately_on_group_owner(self):
        mark=(ROOT/'addons/infantry/functions/cortexZeusMark.sqf').read_text()
        executable=mark.split('params [',1)[1]
        self.assertLess(executable.index('setVariable ["WAIT_AIPass_ZeusHold"'),executable.index('WAIT_fnc_CortexReleaseGroup'))
        self.assertIn('[_group,false,"ZEUS_TAKEOVER"] call WAIT_fnc_CortexReleaseGroup',mark)
        self.assertIn('[_group,false,"ZEUS_TAKEOVER"] remoteExecCall ["WAIT_fnc_CortexReleaseGroup",groupOwner _group]',mark)
        self.assertIn('WAIT_Cortex_CombinedRole',mark)
        self.assertIn('WAIT_Cortex_CombinedOpportunity',mark)
        self.assertIn('WAIT_Cortex_CombinedApplied',mark)
        self.assertIn('WAIT_Cortex_ZeusOrderSnapshot',mark)
        self.assertIn('WAIT_AIPass_ZeusControlKind',mark)
        self.assertIn('["DIRECT","WAYPOINT"] select _waypoints',mark)
        self.assertIn('setVariable ["WAIT_AIPass_ZeusWaypoints",false,true]',mark)
        self.assertIn('_hold select 0',mark)
        self.assertIn('["_waypointIndex",-1,[0]]',mark)
        self.assertLess(executable.index('setVariable ["WAIT_Cortex_ZeusOrderSnapshot"'),
                        executable.index('WAIT_fnc_CortexReleaseGroup'))
        watch=(ROOT/'addons/core/functions/cortexZeusWatchLocal.sqf').read_text()
        self.assertIn('params ["", "_group", "_waypointID"]',watch)
        self.assertIn('[_group,true,_waypointID] call WAIT_fnc_CortexZeusMark',watch)
        self.assertIn('[_waypoint select 0,true,_waypoint select 1] call WAIT_fnc_CortexZeusMark',watch)
        held=source('cortexZeusHeld')
        self.assertIn('if (_kind == "WAYPOINT" && {_group getVariable ["WAIT_AIPass_ZeusWaypoints",false]}) exitWith {',held)
        self.assertIn('setVariable ["WAIT_AIPass_ZeusLocalUntil",-1]',held)
        self.assertLess(held.index('if (_kind == "WAYPOINT"'),
                        held.rindex('time < (_group getVariable ["WAIT_AIPass_ZeusLocalUntil"'))

    def test_handover_visuals_do_not_keep_stale_rally_labels(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        for description,label in [('QA FRESH ORDINARY ORDER','ORDINARY ORDER'),
                                  ('QA ZEUS REPLACEMENT','ZEUS ORDER'),
                                  ('QA UNOPPOSED HANDOVER DIAGNOSTIC','UNOPPOSED ORDER')]:
            stage=qa.split('setWaypointDescription "'+description+'";')[1].split('} forEach _teams;')[0]
            self.assertIn('WAIT_CortexQA_Label',stage)
            self.assertIn(label,stage)

    def test_coordinated_handover_marks_the_exact_replacement_order(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        zeus=qa.split('private _zeusOrigins=',1)[1].split('private _unopposedOrigins=',1)[0]
        self.assertIn('[_g,true,_wp select 1] call WAIT_fnc_CortexZeusMark',zeus)
        self.assertLess(zeus.index('_g setCurrentWaypoint _wp'),
                        zeus.index('[_g,true,_wp select 1] call WAIT_fnc_CortexZeusMark'))
        self.assertIn('_arrived < 4',zeus)
        self.assertIn('_progressed < 4',zeus)
        for setting in ['setWaypointBehaviour "AWARE"','setWaypointCombatMode "YELLOW"',
                        'setWaypointSpeed "FULL"']:
            self.assertIn(setting,zeus)

    def test_coordinated_contact_loss_removes_and_restores_engine_knowledge(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        transition=qa.split('// Remove the known target from the requester',1)[1].split('_enemy setUnitPos "AUTO";',1)[0]
        self.assertIn('hideObjectGlobal _enemy',transition)
        self.assertIn('_requester ignoreTarget [_enemy,true]',transition)
        self.assertIn('_requester ignoreTarget [_enemy,false]',transition)
        self.assertIn('_requester reveal [_enemy,4]',transition)
        self.assertIn('_enemy hideObjectGlobal false',transition)
        self.assertNotIn('createVehicle ["Land_CncWall4_F"',transition)

    def test_multi_manoeuvre_keeps_both_squads_in_tactical_range(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runMultiManoeuvre.sqf').read_text()
        self.assertIn('setVariable ["WAIT_AIPass_NearRange",5000]',qa)
        self.assertIn('setVariable ["WAIT_AIPass_FarRange",5000]',qa)
        self.assertIn('setVariable ["WAIT_AIPass_NearRange",_savedNearRange]',qa)
        self.assertIn('setVariable ["WAIT_AIPass_FarRange",_savedFarRange]',qa)
        self.assertIn('WAIT_Cortex_FlankRefusal',qa)
        self.assertIn('WAIT_Cortex_AdvanceRefusal',qa)

    def test_support_release_retires_owned_hold_after_engine_combat_relabels_it(self):
        maintain=source('cortexSupportMaintain')
        self.assertIn('_command in ["","STOP","ATTACK","FIRE","SUPPRESS"]',maintain)
        self.assertNotIn('_x != leader _group',maintain)
        self.assertIn('supportHeld is the ownership record',maintain)
        self.assertIn('group _x == _group',maintain)
        self.assertIn('WAIT_Cortex_SupportPathHold',maintain)
        cover=maintain.split('if (_coordinating) then {',1)[1]
        self.assertNotIn('disableAI "PATH"',cover)
        self.assertNotIn('setVariable ["WAIT_Cortex_SupportPathHold",true',cover)
        restore=source('cortexRestoreCalm')
        self.assertIn('group _unit == _group',restore)
        self.assertIn('WAIT_Cortex_SupportPathHold',restore)
        for text in [maintain,restore]:
            self.assertNotIn('currentCommand _x == "STOP"',text)

    def test_calm_cleanup_releases_cortex_holds_without_overwriting_new_individual_orders(self):
        restore=source('cortexRestoreCalm')
        release_hold=restore.split('private _releaseOwnedHold={',1)[1].split('};\n{',1)[0]
        self.assertIn('if (_restorePath) then {',release_hold)
        self.assertIn('_unit enableAI "PATH"',release_hold)
        self.assertIn('_unit setVariable ["WAIT_Cortex_SupportPathHold",nil,true]',release_hold)
        self.assertIn('_command in ["","STOP","ATTACK","FIRE","SUPPRESS"]',release_hold)
        self.assertIn('_returnSearchTeam && {!_yieldToExternal}',release_hold)
        self.assertIn('_unit doFollow _leader',release_hold)
        for external in ['MOVE','GET IN','GET OUT','ACTION','SCRIPTED']:
            self.assertNotIn(f'"{external}"',release_hold)
        self.assertIn('[_x,true,false] call _releaseOwnedHold',restore)
        self.assertIn('[_x,false,true] call _releaseOwnedHold',restore)
        search_release=restore.split('forEach (_state getOrDefault ["searchTeam", []])',1)[0].rsplit('{if (alive _x)',1)[-1]
        self.assertNotIn('enableAI "PATH"',search_release)

    def test_feature_registry_is_packaged_and_dispatched_by_the_standalone_pipeline(self):
        from check_cortex_coverage import audit, render_markdown
        from mod_pipeline import ALIASES
        data, errors, pending = audit(ROOT)
        self.assertEqual(errors, [])
        self.assertGreaterEqual(len(data['cases']), 65)
        self.assertIn('COMPAT', pending)
        self.assertIn('COORD', pending)
        self.assertIn('COMBINED-ARMS', pending)
        self.assertIn('AIR-ATTACK', pending)
        production = {
            path.relative_to(ROOT).as_posix()
            for path in (ROOT / 'addons').rglob('*.sqf')
        }
        assigned = [path for case in data['cases'] for path in case['production_sources']]
        self.assertEqual(production, set(assigned))
        self.assertEqual(len(assigned), len(set(assigned)))
        self.assertTrue(all((ROOT / path).is_file() for path in assigned))
        report = render_markdown(data)
        self.assertEqual(report, (ROOT / 'releaseVerificationAndDeployment/cortexQA/FEATURE_STATUS.md').read_text(encoding='utf-8'))
        for case in data['cases']:
            self.assertIn(f"| {case['id']} - {case['title']} |", report)
        pipeline = (ROOT / 'releaseVerificationAndDeployment/mod_pipeline.py').read_text(encoding='utf-8')
        server = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn("glob('run*.sqf')", pipeline)
        for source in {source for case in data['cases'] for source in case['executable_sources']}:
            if source not in ['runServer.sqf', 'runClient.sqf']:
                suffix = Path(source).stem[3:]
                staged = 'cortexQA' + ALIASES.get(suffix, suffix) + '.sqf'
                self.assertIn(staged, server)
    def test_external_ownership_markers_are_isolated_to_compatibility(self):
        compatibility = ROOT / 'addons/compatibility/functions'
        for name in ['compatibilityExternalControl.sqf', 'compatibilityPrecisionExcluded.sqf']:
            self.assertTrue((compatibility / name).is_file(), name)
        config = (ROOT / 'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class CompatibilityExternalControl', config)
        self.assertIn('class CompatibilityPrecisionExcluded', config)
        for path in (ROOT / 'addons').rglob('*.sqf'):
            if 'compatibility' not in path.parts:
                text = path.read_text(encoding='utf-8')
                self.assertNotIn('Waldo_AI_ExternalControl', text, path)
                self.assertNotIn('Waldo_AI_PrecisionExclude', text, path)

    def test_terrain_focus_requires_measured_relief_and_physical_travel(self):
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        terrain=(ROOT/'releaseVerificationAndDeployment/cortexQA/runTerrain.sqf').read_text(encoding='utf-8')
        self.assertIn('[string]$Focus=\'all\'',launcher)
        self.assertIn("mod_pipeline.py') stage $Package $runtime --focus $Focus",launcher)
        pipeline=(ROOT/'releaseVerificationAndDeployment/mod_pipeline.py').read_text(encoding='utf-8')
        self.assertIn("glob('run*.sqf')",pipeline)
        self.assertIn('if (_focus == "terrain")',server)
        self.assertIn('cortexQATerrain.sqf',server)
        self.assertIn('toLower worldName != "vr"',terrain)
        self.assertIn('_relief >= 7',terrain)
        self.assertIn('_roughness >= 0.025',terrain)
        self.assertIn('surfaceIsWater _x',terrain)
        self.assertIn('"INFANTRY"] call WAIT_fnc_CortexSelectAvenue',terrain)
        self.assertIn('"VEHICLE"] call WAIT_fnc_CortexSelectAvenue',terrain)
        self.assertIn('TERRAIN-infantry-physical-progress',terrain)
        self.assertIn('TERRAIN-vehicle-physical-progress',terrain)
        self.assertIn('TERRAIN-defence-physical-arrival',terrain)
        for battle_marker in ['TERRAIN-BATTLE-equal-force-prerequisite',
                              'TERRAIN-BATTLE-both-sides-actual-fire',
                              'TERRAIN-BATTLE-real-casualties',
                              'TERRAIN-BATTLE-multi-group-physical-progress',
                              'TERRAIN-BATTLE-production-tactics-observed',
                              'TERRAIN-BATTLE-composite-outcome',
                              'forEach [[east,"O_Soldier_F",180,"East"],[west,"B_Soldier_F",0,"West"]]',
                              '_waypoint setWaypointType "SAD"']:
            self.assertIn(battle_marker,terrain)
        terrain_battle_source=terrain.split('// The flat controller ranges')[1].split('// Find one long inland air corridor')[0]
        self.assertNotIn('allowDamage false',terrain_battle_source)
        for air_marker in ['TERRAIN-air-corridor-found','_laneRelief >= 45',
                           'TERRAIN-AIR-PLANE','TERRAIN-AIR-HELICOPTER',
                           '-terrain-plan','-physical-flight','-real-weapon-release',
                           '-target-damaged','-finite-egress']:
            self.assertIn(air_marker,terrain)
        self.assertNotIn('call WAIT_fnc_CortexAirAttackPlan',terrain)
        self.assertNotIn('call WAIT_fnc_CortexAirAttack;',terrain)
        coverage=json.loads((ROOT/'releaseVerificationAndDeployment/cortexQA/coverage.json').read_text(encoding='utf-8'))
        terrain_case=next(case for case in coverage['cases'] if case['id']=='TERRAIN')
        self.assertEqual(terrain_case['executable_sources'],['runTerrain.sqf'])
        self.assertEqual(terrain_case['status'],'implemented_partial')
        self.assertEqual(terrain_case['live_evidence'],[])
        terrain_battle=next(case for case in coverage['cases'] if case['id']=='TERRAIN-BATTLE')
        self.assertEqual(terrain_battle['executable_sources'],['runTerrain.sqf'])
        self.assertEqual(terrain_battle['status'],'implemented_partial')
        self.assertEqual(terrain_battle['live_evidence'],[])

    def test_audit_visualisation_has_a_bounded_render_cost(self):
        guide=(ROOT/'releaseVerificationAndDeployment/cortexQA/runGuide.sqf').read_text(encoding='utf-8')
        for marker in ['positionCameraToWorld [0,0,0]','private _renderDistance=2500',
                       'if (count _actors > 12) then {_actors resize 12}',
                       '_position distance (_track select (count _track-1)) > 2',
                       'if (count _track > 48) then {_track deleteRange [0,count _track-48]}',
                       'distance2D _cameraPosition <= _renderDistance']:
            self.assertIn(marker,guide)
        self.assertNotIn('if (count _track > 90) then {_track deleteAt 0}',guide)

    def test_packaged_audit_requests_the_declared_window_resolution_and_observer_zeus(self):
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        for marker in ['[int]$ResolutionWidth=3840','[int]$ResolutionHeight=2160',
                       'winW=$ResolutionWidth;','winH=$ResolutionHeight;',
                       'resolutionW=$ResolutionWidth;','resolutionH=$ResolutionHeight;',
                       '"-x=$ResolutionWidth"','"-y=$ResolutionHeight"',
                       '"-windowWidth=$ResolutionWidth"','"-windowHeight=$ResolutionHeight"',
                       'Show-AuditClientWindow $client $ClientWindowTimeoutSeconds',
                       '[WaitAuditWindow]::IsWindowVisible($client.MainWindowHandle)',
                       "'-noBattlEye'", "'-showScriptErrors'", 'sole observer Zeus slot automatically']:
            self.assertIn(marker,launcher)
        self.assertIn("$auditWindowStyle = if ($Interactive) {'Normal'} else {'Hidden'}",launcher)
        self.assertIn("Start-AuditProcess 'arma3_x64.exe'",launcher)

    def test_coordinated_handoffs_do_not_stack_fixed_tactical_pauses(self):
        text = source('cortexFlankStep')
        self.assertIn('private _teamPause=if (_support) then {0} else', text)
        self.assertIn('private _pause = if (_support) then {0} else', text)
        self.assertIn('if (_arrived) then {', text)
        self.assertNotIn('case "GRENADE": {', text)
        self.assertIn('private _teamPause=if (_support) then {0} else', text)

    def test_successful_manoeuvre_flows_into_assault_without_second_chance_roll(self):
        text=source('cortexFlankStep')
        hold=text.split('case "HOLD":',1)[1]
        assault=hold.split('private _assault =',1)[1].split('private _assaultDirection',1)[0]
        self.assertIn('if (_support) then {_assaultRange = _assaultRange max 100}',hold)
        self.assertNotIn('random 1',assault)
        self.assertIn('_drill set ["assaultGrenade",random 1 <',hold)
        self.assertIn('if (_drill getOrDefault ["assaultGrenade",false])',text)
        self.assertIn('_points pushBack [_approachPoint, "ASSAULT"]',hold)
        self.assertIn('_points pushBack [_clearPoint, "CLEAR"]',hold)

    def test_live_contact_immediately_retires_stale_transition_intent(self):
        tick=source('cortexGroupTick')
        enter=tick.split('private _enterContact = {',1)[1].split('};\nprivate _beginContact',1)[0]
        self.assertIn('setVariable ["WAIT_Cortex_TransitionIntent",nil,true]',enter)

    def test_native_waypoint_return_uses_one_bounded_recovery_without_editing_waypoints(self):
        text = source('cortexFlankStep')
        guard = text.split('private _returnedToWaypoint =')[1].split('if (_now-(_last select 3) > _timeout)')[0]
        for required in ['currentWaypoint _group ==', 'isEqualTo (_waypoint select 1)',
                         'expectedDestination _unit', '(_retry select 0) < 1',
                         '_now-(_retry select 1) >= 8']:
            self.assertIn(required, guard)
        self.assertNotIn('setWaypoint', text)
        self.assertNotIn('deleteWaypoint', text)
        self.assertLess(text.index('WAIT_fnc_CortexIsEligible'), text.index('private _returnedToWaypoint'))

    def test_bound_handoff_does_not_issue_competing_formation_orders(self):
        text = source('cortexFlankStep')
        issue = text.split('private _issue = {')[1].split('private _result =')[0]
        self.assertNotIn('_unit doFollow', issue)
        self.assertNotIn('setUnitCombatMode "BLUE"', issue)
        self.assertIn('_unit doMove _spot', issue)
        self.assertNotIn('_unit setUnitCombatMode "YELLOW"', issue)

    def test_cancelled_throw_does_not_block_assault_progression(self):
        throw = source('cortexThrowGrenade')
        self.assertIn('setVariable ["WAIT_Cortex_FragCancelled",_drillToken]', throw)
        self.assertIn('exitWith {call _cancel}', throw)
        self.assertIn('if (_thrown) exitWith {};', throw)
        self.assertNotIn('if (_thrown) exitWith {call _cancel}', throw)
        step = source('cortexFlankStep')
        self.assertNotIn('getVariable ["WAIT_Cortex_FragCancelled",""]) == _token', step)
        self.assertNotIn('"GRENADE_UNRESOLVED" call _end', step)
        self.assertIn('"ASSAULT_GRENADE_DISPATCHED"] select _queued] call WAIT_fnc_CortexDrillSetStage', step)

    def test_flank_routes_avoid_friendly_support_fire_corridors(self):
        start = source('cortexFlankStart')
        selector = source('cortexSelectAvenue')
        for marker in ['private _supportOrigins = []', 'private _supportCandidates = []',
                       'WAIT_AIPass_PublicPhase','WAIT_Cortex_SupportRole',
                       '(_supportRole select 2) == "COVER"','private _supportSpotters=',
                       '(count _friendlyFoot) min 8','private _supportKnows=',
                       '_supportSpotters findIf {_x knowsAbout _target > 0.5} >= 0',
                       '(count _supportCandidates) min 4',
                       'private _avenueCandidates=[]','[1,110,90]',
                       'call WAIT_fnc_CortexSelectAvenue']:
            self.assertIn(marker, start)
        self.assertNotIn('_friendlyLeader knowsAbout _target > 0.5', start)
        for marker in ['_lateral < 30','_pointSide*_startSide < 0',
                       'forEach [0.25,0.5,0.75]',
                       'terrainIntersectASL [_threatASL,_sampleASL]',
                       'lineIntersectsSurfaces [_rayStart,_sampleASL,_threatObject,objNull']:
            self.assertIn(marker, selector)
        self.assertNotIn('selectRandom [',start)
        self.assertNotIn('private _routeProtection = {',start)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runMultiManoeuvre.sqf').read_text()
        self.assertIn('private _fireLaneCrossings=[0,0]',qa)
        self.assertIn('-no-support-fire-lane-crossing',qa)
        self.assertIn('_lateral < 18',qa)

    def test_avenue_can_leave_own_fire_lane_but_cannot_reenter(self):
        selector=source('cortexSelectAvenue')
        for requirement in ['private _laneStates','starts inside corridor','_sample distance2D _start > 60',
                            '_laneState set [1,true]','if (_insideLiveLane) then {_valid=false}']:
            self.assertIn(requirement,selector)
        self.assertLess(selector.index('_laneState set [1,true]'),
                        selector.rindex('if (_insideLiveLane) then {_valid=false}'))

    def test_tactical_refusals_explain_trigger_failures_without_polling(self):
        flank=source('cortexFlankStart')
        for reason in ['SUPPORT_OWNS_MOVEMENT','MOVEMENT_LEASE','MORALE','INSUFFICIENT_ACTORS',
                       'NO_TARGET_IN_RANGE','NO_MANOEUVRE_ELEMENT','NO_SAFE_AVENUE']:
            self.assertIn(reason,flank)
        self.assertIn('WAIT_Cortex_FlankRefusal',flank)
        self.assertNotIn('CBA_fnc_addPerFrameHandler',flank)
        advance=source('cortexAdvanceStart')
        for reason in ['SUPPORT_OWNS_MOVEMENT','MOVEMENT_LEASE','CONTACT_DELAY','NO_TARGET',
                       'TARGET_TOO_CLOSE','AUTHORED_OBJECTIVE_TYPE','STALE_CONTACT','OBJECTIVE_REACHED',
                       'NO_MANOEUVRE_ELEMENT','NO_COVER_ELEMENT','NO_SAFE_AVENUE']:
            self.assertIn(reason,advance)
        self.assertIn('WAIT_Cortex_AdvanceRefusal',advance)
        self.assertNotIn('CBA_fnc_addPerFrameHandler',advance)
        diagnostic=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text()
        self.assertIn('cortex-tactical-refusal-',diagnostic)
        self.assertIn('WAIT_Cortex_FlankRefusal',diagnostic)
        self.assertIn('WAIT_Cortex_AdvanceRefusal',diagnostic)

    def test_group_phases_change_atomically_and_publish_bounded_history(self):
        setter=source('cortexSetPhase')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text()
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text()
        self.assertIn('class CortexSetPhase',functions)
        for marker in ['_state set ["phase",_next]','_state set ["phaseStart",_phaseStart]',
                       'setVariable ["WAIT_AIPass_PublicPhase",_next,true]',
                       'WAIT_Cortex_PhaseTransition','WAIT_Cortex_PhaseTransitions',
                       'if (count _history > 32)']:
            self.assertIn(marker,setter)
        self.assertIn('["_force",false,[true]]',setter)
        self.assertIn('getVariable ["WAIT_AIPass_PublicPhase",_localPrevious]',setter)
        self.assertNotIn('CBA_fnc_addPerFrameHandler',setter)
        self.assertIn('cortex-phase-transition-',diagnostics)
        self.assertIn('phase state changed outside the atomic transition path',diagnostics)
        for name in ['cortexGroupTick','cortexRestoreCalm','cortexRetreat','cortexVehicles','cortexLocality']:
            self.assertIn('call WAIT_fnc_CortexSetPhase',source(name))
            self.assertNotIn('_state set ["phase"',source(name))
        tick=source('cortexGroupTick')
        for reason in ['VISIBLE_CONTACT','AREA_REPORT','KNOWN_CONTACT','CONTACT_LOST',
                       'NO_SEARCH_TEAM','SEARCH_TEAM_SENT','SEARCH_COMPLETE',
                       'WITHDRAWAL_COMPLETE','WITHDRAWAL_TIMEOUT']:
            self.assertIn(reason,tick)

    def test_manoeuvres_share_one_bounded_avenue_selector(self):
        selector=source('cortexSelectAvenue')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        advance=source('cortexAdvanceStart')
        flank=source('cortexFlankStart')
        retreat=source('cortexRetreat')
        self.assertIn('class CortexSelectAvenue',functions)
        for marker in ['(count _candidates) min 8','forEach [0.25,0.5,0.75]',
                       'terrainIntersectASL [_threatASL,_sampleASL]',
                       'private _surfaceUp=(surfaceNormal _sample) select 2',
                       'private _terrainASL=getTerrainHeightASL _sample',
                       'if (surfaceIsWater _sample || {_surfaceUp < _sampleMinimumUp} || {_sampleGrade > _sampleMaximumGrade})',
                       '+2*(_terrainPenalty/(_terrainSamples max 1))',
                       '"FIRE","GEOM"','"VIEW","GEOM"','_lateral < 30',
                       '_pointSide*_startSide < 0','(ceil (_legLength/20)) max 3',
                       'min 24','private _sampleGrade=abs (_terrainASL-_previousTerrainASL)/_sampleDistance',
                       '-70*(_hardScreen/(_screenSamples max 1))',
                       '-25*(_concealed/(_screenSamples max 1))']:
            self.assertIn(marker,selector)
        self.assertLess(selector.index('private _safetySamples='),selector.index('surfaceIsWater _sample'))
        self.assertLess(selector.index('surfaceIsWater _sample'),selector.index('forEach [0.25,0.5,0.75]'))
        for vehicle_marker in ['"VEHICLE"','private _minimumSurfaceUp=[0.55,0.8]',
                               'private _maximumGrade=[1.25,0.7]',
                               'if (_onRoad) then {0.68}','if (_onRoad) then {0.9}',
                               'isOnRoad _sample','-30*(_roadSamples/(_terrainSamples max 1))']:
            self.assertIn(vehicle_marker,selector)
        self.assertNotIn('nearObjects',selector)
        self.assertNotIn('nearestTerrainObjects',selector)
        self.assertIn('call WAIT_fnc_CortexSelectAvenue',advance)
        self.assertIn('forEach [90,-90,55,-55]',advance)
        self.assertIn('call WAIT_fnc_CortexSelectAvenue',flank)
        self.assertIn('call WAIT_fnc_CortexSelectAvenue',retreat)
        self.assertIn('forEach [0, 30, -30, 60, -60]',retreat)
        flank_step=source('cortexFlankStep')
        self.assertIn('forEach [0.65,0.35,0]',flank_step)
        self.assertIn('forEach [0,-15,15,-30,30]',flank_step)
        self.assertIn('[_centroid,_assaultCandidates,_enemyPos] call WAIT_fnc_CortexSelectAvenue',flank_step)

    def test_multi_manoeuvre_audit_requires_real_drills_and_contact(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runMultiManoeuvre.sqf').read_text()
        for marker in ['private _drillSeen=[false,false]',
                       'private _expectedDrill=["FLANK","ADVANCE"]',
                       '-both-tactical-drills-observed',
                       '([0,180] select _contact)',
                       '_drillSeen select _teamIndex']:
            self.assertIn(marker,qa)
        self.assertIn('_enemyGroup setCombatMode "YELLOW"',qa)
        self.assertIn('_enemy setUnitPos "UP"',qa)
        self.assertIn('for "_index" from 0 to 5 do',qa)
        self.assertIn('private _enemies=[]',qa)

    def test_multi_manoeuvre_audit_uses_real_relief_outside_vr(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runMultiManoeuvre.sqf').read_text()
        for marker in ['private _terrainOrigin=[2200,1100,0]',
                       'private _terrainHeading=0',
                       'private _terrainScenarioReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-80,0,80,160]',
                       'for "_along" from 0 to 360 step 30',
                       'private _normal=(surfaceNormal _sample) select 2',
                       '_normal < 0.55',
                       '_grade > 0.7',
                       '_relief >= 15 && {_relief <= 120}',
                       '_x-2200,_y-1100] call _terrainWorld',
                       '-terrain-scenario',
                       'call _terrainPosition']:
            self.assertIn(marker,qa)
        self.assertIn('_enemies findIf {_leader knowsAbout _x >= 1}',qa)
        self.assertIn('_actors+_enemies',qa)
        self.assertIn('_x setDir (_x getDir _enemy)',qa)
        self.assertIn('_x setDir (_x getDir _opponent)',qa)
        self.assertIn('if (_contact && {_mode == "BOUND"}) then {',qa)
        self.assertLess(qa.index('[_prefix+"-natural-contact"'),
                        qa.index('private _wp=_x addWaypoint'))

    def test_coordinated_audit_rotates_full_platoon_geometry_onto_real_terrain(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        for marker in ['private _terrainHeading=0',
                       'private _terrainScenarioReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-220,-110,0,110,220]',
                       'for "_along" from -120 to 650 step 35',
                       '_normal < 0.55',
                       '_grade > 0.7',
                       '_relief >= 20 && {_relief <= 180}',
                       'COORD-terrain-scenario',
                       '_terrainForward vectorMultiply 100',
                       'vectorDotProduct _terrainRight']:
            self.assertIn(marker,qa)
        for position in ['[1500,1500] call _terrainPosition',
                         '[1500,1600] call _terrainPosition',
                         '[1400+_team*200+_i*3,1400] call _terrainPosition']:
            self.assertIn(position,qa)
        self.assertIn('_wall setDir _terrainHeading',qa)
        self.assertNotIn('vectorAdd [0,100,0]',qa)

    def test_bounding_advance_default_has_no_artificial_contact_wait(self):
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text()
        spec=source('cortexTuningSpec')
        advance=source('cortexAdvanceStart')
        self.assertIn('["WAIT_AIPass_Advance_MinContactSeconds", 0]',config)
        self.assertIn('["WAIT_AIPass_Advance_Cooldown", 20]',config)
        self.assertIn('"WAIT_AIPass_Advance_MinContactSeconds", "Advance contact delay"',spec)
        self.assertIn('"SLIDER", [0,300,0], 0, "MOVEMENT", "NEXT_OPERATION"]',spec)
        self.assertIn('"WAIT_AIPass_Advance_Cooldown", "Advance repeat delay"',spec)
        self.assertIn('"SLIDER", [0,180,0], 20, "MOVEMENT", "NEXT_OPERATION"]',spec)
        self.assertIn('getVariable ["WAIT_AIPass_Advance_MinContactSeconds", 0]',advance)

    def test_bounding_advance_uses_fresh_contact_when_no_waypoint_remains(self):
        advance=source('cortexAdvanceStart')
        step=source('cortexFlankStep')
        self.assertIn('private _hasAuthoredObjective = _index < count waypoints _group',advance)
        self.assertIn('if (_hasAuthoredObjective && {',advance)
        self.assertIn('!(waypointType [_group, _index] in ["MOVE", "SAD", "DESTROY"])',advance)
        self.assertIn('if (!_hasAuthoredObjective && {((_enemies select 0) select 2) > 10})',advance)
        self.assertIn('(_enemies select 0) select 1',advance)
        self.assertNotIn('if (_index >= count waypoints _group) exitWith {false}',advance)
        self.assertIn('private _waypointSnapshot = []',step)
        self.assertIn('if (_waypointIndex < count waypoints _group) then {',step)
        self.assertIn('["boundWaypoint",_waypointSnapshot]',step)

    def test_advance_uses_its_own_shorter_repeat_cooldown(self):
        end=source('cortexFlankEnd')
        self.assertIn('case "ADVANCE": {"WAIT_AIPass_Advance_Cooldown"}',end)
        self.assertIn('case "ADVANCE": {20}',end)
        self.assertIn('default {"WAIT_AIPass_Flank_Cooldown"}',end)
        self.assertIn('default {90}',end)
        self.assertIn('getVariable [_cooldownName, _cooldownDefault]',end)

    def test_coordinated_audit_ends_after_terminal_element_failures(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        for marker in ['private _movementRoleObserved=false',
                       'private _retiredSince=-1',
                       'in ["STALLED","TIME_LIMIT"]',
                       'COORD-tactical-role-observed',
                       'COORD-movement-window-terminated']:
            self.assertIn(marker,qa)

    def test_previous_holders_cannot_follow_over_replacement_drill(self):
        text = source('cortexGroupTick')
        self.assertIn('_ownedMovers = _activeDrill getOrDefault ["units",[]]', text)
        self.assertIn('!(_x in _ownedMovers)', text)
        self.assertIn('if (_holders isNotEqualTo [] && {!(_state getOrDefault ["assaulting",false])})', text)
        self.assertLess(text.index('!(_x in _ownedMovers)'), text.index('{_x doFollow _leader} forEach _rejoin'))

    def test_coordinated_report_fire_requires_live_matching_lease(self):
        text = source('cortexFireControl')
        for guard in ['(_role select 0) == (_lease select 0)', 'serverTime < (_lease select 2)',
                      '"supportToken"', 'WAIT_AIPass_CoordinatedAssault_Enable',
                      '_enemies isEqualTo [] && {_reported isEqualTo []}',
                      'WAIT_fnc_CortexLineOfFireClear']:
            self.assertIn(guard, text)
        self.assertNotIn(' reveal ', text)
        self.assertIn('private _suppressPos = +_reported;', text)

    def test_moving_bounds_preserve_native_combat_behaviour(self):
        step = source("cortexFlankStep")
        for capability in ['TARGET','AUTOTARGET','AUTOCOMBAT','PATH']:
            self.assertNotIn(f'_unit disableAI "{capability}"',step)
        self.assertNotIn('_unit setCombatBehaviour "AWARE"',step)
        self.assertNotIn('_unit setDestination',step)
        self.assertIn('"restoreCombatBehaviours"', source("cortexCheckpoint"))
        for name in ["cortexFlankStep", "cortexFlankEnd", "cortexLocality"]:
            self.assertIn('behaviour _unit == _owned', source(name))
            self.assertIn('_unit setCombatBehaviour _previous', source(name))

    def test_native_attack_is_not_fought_before_physical_no_progress(self):
        step = source("cortexFlankStep")
        self.assertNotIn('currentCommand _unit == "ATTACK"', step)
        self.assertNotIn('_unit doTarget objNull',step)
        retry=step.split('private _retry = _retries select _forEachIndex;',1)[1].split('if (_now-(_last select 3) > _timeout)',1)[0]
        self.assertIn('_now-(_last select 3) >= 8',retry)
        self.assertIn('(_retry select 0) < 1',retry)
        self.assertEqual(1,retry.count('_unit doMove'))
        self.assertNotIn('setDestination',retry)

    def test_active_support_assignment_is_adopted_by_the_new_local_owner(self):
        locality=source('cortexLocality')
        apply=source('cortexSupportApply')
        for marker in ['WAIT_AIPass_SupportLease','WAIT_AIPass_SupportStatus',
                       'serverTime < (_supportLease select 2)','["adopt",true]',
                       'call WAIT_fnc_CortexSupportApply']:
            self.assertIn(marker,locality)
        self.assertIn('_job getOrDefault ["adopt",false]',apply)
        self.assertIn('_state set ["supportBoundSequence",-1]',apply)
        self.assertIn('_state set ["arrivedAt"',apply)

    def test_tactical_bounds_use_one_native_destination_without_disabling_combat(self):
        step = source("cortexFlankStep")
        body=step.split('*/',1)[1]
        issue=step.split('private _issue = {',1)[1].split('private _result =',1)[0]
        self.assertEqual(1,issue.count('_unit doMove _spot'))
        self.assertNotIn('setDestination [',body)
        self.assertNotIn('doTarget objNull',body)
        for capability in ['TARGET','AUTOTARGET','AUTOCOMBAT','PATH']:
            self.assertNotIn(f'_unit disableAI "{capability}"',step)

    def test_suppressive_fire_talks_inside_squad_and_desynchronises_squads(self):
        fire = source("cortexFireControl")
        for token in ['WAIT_AIPass_NextSuppress', '0.25 + random 2',
                      'WAIT_AIPass_SuppressCursor', '_now + 2.5 + random 1.5']:
            self.assertIn(token, fire)
        suppression = fire.split('// Disciplined suppression', 1)[1]
        self.assertIn('if (_issued) exitWith {}', suppression)
        self.assertIn('_cursor + 1', suppression)
        self.assertGreaterEqual(fire.count('_group setVariable ["WAIT_AIPass_NextSuppress",nil]'), 2)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runFireControl.sqf').read_text()
        for token in ['FIRE-talking-guns-rotated-suppressors',
                      'FIRE-squads-not-global-volley',
                      'FIRE-multi-squad-actual-suppression',
                      'WAIT_CortexQA_SuppressOrders',
                      'WAIT_CortexQA_SuppressShots']:
            self.assertIn(token,qa)
        self.assertIn('Land_CncWall4_F',qa)
        self.assertIn('_suppressionEnemy setPosATL [2100,1460,0]',qa)
        self.assertIn('_x doTarget objNull; _x doWatch objNull',qa)
        self.assertNotIn('call WAIT_fnc_CortexFireControl',qa)

    def test_native_canfire_gets_immediate_safe_suppression_parity(self):
        fire = source("cortexFireControl")
        suppression = fire.split('// Disciplined suppression', 1)[1]
        for token in ['getOrDefault ["dangerResponse",[]]',
                      '(_dangerResponse select 0) == "CANFIRE"',
                      'WAIT_Danger_Generation',
                      '(_x select 3) > _assaultRange',
                      '(_x select 3) <= 500']:
            self.assertIn(token,suppression)
        # The parity handoff must still use the existing bounded safety path rather than
        # manufacture target knowledge, direct fire, or a second worker.
        self.assertIn('call WAIT_fnc_CortexLineOfFireClear',suppression)
        self.assertIn('_unit doSuppressiveFire _targetASL',suppression)
        self.assertNotIn('doTarget',suppression)
        self.assertNotIn('spawn',suppression)

    def test_non_infantry_sources_keep_identity_at_observation_boundaries(self):
        for name, expected, rejected in [
            ("cortexSpotterFix", "getFriend (side _enemy)", "getFriend (side group _enemy)"),
            ("cortexHearingLocal", "getFriend (side _firer)", "getFriend (side group _firer)"),
            ("convoyCrewLocal", "getFriend (side _instigator)", "getFriend (side group _instigator)"),
        ]:
            text=source(name)
            self.assertIn(expected,text)
            self.assertNotIn(rejected,text)

    def test_danger_recycle_never_substitutes_exact_hostile_position(self):
        recycle=source("dangerEngineRecycle")
        self.assertIn('private _position=_actor getHideFrom _source',recycle)
        self.assertIn('if (_position isEqualTo [0,0,0]) exitWith {[]}',recycle)
        self.assertNotIn('_position=getPosATL _source',recycle)
        self.assertIn('getPosATL _actor',recycle)
        self.assertIn('private _cycle=_record param [4,0,[0]]',recycle)
        self.assertIn('if (_cycle >= _maxCycles) exitWith',recycle)
        self.assertIn('[_cause,+_position,time+1.5,_source,_cycle+1]',recycle)

    def test_group_ticks_use_low_cost_zero_mean_jitter(self):
        tick=source("cortexGroupTick")
        self.assertIn('private _cadence = _delay / _reaction;',tick)
        self.assertIn('(_cadence + random 0.7 - 0.35) max 0.5',tick)
        self.assertIn('adding no scheduler job or polling loop',tick)
        self.assertNotIn('WAIT_fnc_CortexQueueJob, createHashMapFromArray [["group", _group]',tick)

    def test_recovery_qa_measures_continuation_after_separation(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        event=qa.split('if (!_observedRecovery && {_blockedActor in _recoveryActors}) then {')[1].split('};')[0]
        self.assertIn('getPosATL _x', event)
        self.assertIn('_restOrigins =', event)
        self.assertIn('-continued-with-blocked-actor', qa)
        self.assertIn('-physical-rejoin', qa)

    def test_rejoining_actors_keep_movement_ownership_during_halts(self):
        for name in ['cortexFireControl', 'cortexAntiArmour']:
            text = source(name)
            self.assertIn('getOrDefault ["recovery",[]]', text)
            self.assertIn('!(_x in _recovering)', text)
        text = source('cortexFireControl')
        self.assertIn('in ["START","MOVE"]', text)
        self.assertIn('WAIT_fnc_CortexCombatEffective', text)

    def test_stragglers_remain_tracked_after_live_element_quorum(self):
        step = source('cortexFlankStep')
        self.assertIn('count (_units - _blocked) >= 2', step)
        self.assertIn('ceil (count _originalElement * 0.6)', step)
        self.assertIn('_teams select (_drill getOrDefault ["teamTurn",0])', step)
        self.assertIn('_teams findIf {_actor in _x}', step)
        self.assertIn('(_teams select _teamIndex) select {_x in _main}', step)
        self.assertIn('ceil (count _units * 0.6)', step)
        self.assertIn('_attempts < 1', step)
        self.assertIn('WAIT_fnc_RecoveryStep', step)
        self.assertIn('_units = _units - _recovering', step)
        end = source('cortexFlankEnd')
        self.assertIn('_reason = "PARTIAL"', end)
        self.assertIn('forEach (_members-_stragglers)', end)
        self.assertIn('{_x doFollow leader _group} forEach _stragglers', end)

    def test_manoeuvre_elements_reinforce_and_rebalance_after_casualties(self):
        step=source('cortexFlankStep')
        for marker in ['private _fitSquad=', 'private _rankCandidates=',
                       'WAIT_Cortex_DrillReinforcements', 'TEAM_1_REBALANCE',
                       'TEAM_2_REBALANCE', '"START","CASUALTY_REINFORCEMENT"] call WAIT_fnc_CortexDrillSetStage',
                       'private _ownedPathUnits=']:
            self.assertIn(marker,step)
        self.assertIn('_x checkAIFeature "PATH" || {_x in _ownedPathUnits}',step)
        self.assertNotIn('addEventHandler ["Killed"',step)
        self.assertIn('["desiredStrength",count _element]',source('cortexFlankStart'))
        self.assertIn('["teamSizes",[count _element,count _coverElement]]',source('cortexAdvanceStart'))
        self.assertIn('["teamSizes",[count _first,count _second]]',source('cortexSupportBoundStart'))

    def test_coordinated_bound_team_contract_matches_server_reservation(self):
        start=source('cortexSupportBoundStart')
        self.assertIn('([_first,_second] select (_forEachIndex mod 2)) pushBack _x',start)
        self.assertIn('count _first < 2 || {count _second < 2}',start)
        self.assertNotIn('private _riflemen=',start)
        self.assertNotIn('CortexUnitRole',start)
        maintain=source('cortexSupportMaintain')
        self.assertIn('private _started=[_group,_state,_role] call WAIT_fnc_CortexSupportBoundStart',maintain)
        self.assertIn('[_token,_role select 1,"NOT_READY"]',maintain)
        self.assertIn('_state set ["supportBoundSequence",_role select 1]',maintain)

    def test_wait_diagnostics_explain_coordinated_failures_and_flare_modes(self):
        diagnostic=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        for marker in ['cortex-coordination-health','recordedBoundFailures=',
                       'boundFailuresByToken','WAIT_Cortex_SupportBoundResult',
                       'WAIT_Cortex_SupportAbort','groupSpeed=%8',
                       'withdrawal=[status,travel,replans]=%16',
                       'reactiveFlares=%8 attackRunFlares=%9',
                       'WAIT_Cortex_AttackRunFlares_Enable']:
            self.assertIn(marker,diagnostic)

    def test_bound_retry_is_finite_and_does_not_fabricate_progress(self):
        text = source('cortexFlankStep')
        retry = text.split('private _retry = _retries select _forEachIndex;')[1].split('if (_now-(_last select 3) > _timeout)')[0]
        self.assertIn('(_retry select 0) < 1', retry)
        self.assertIn('_now-(_retry select 1) >= 8', retry)
        self.assertIn('checkAIFeature "PATH"', retry)
        self.assertNotIn('_last set', retry)
        self.assertNotIn('setPos', retry)
        self.assertNotIn('_arrived = true', retry)

    def test_anti_armour_respects_movement_and_holding_ownership(self):
        text = source('cortexAntiArmour')
        self.assertIn('!(_x in _moving)', text)
        self.assertIn('getVariable ["WAIT_Cortex_ActorMove",[]]',text)
        self.assertIn('_now >= (_actorMove select 2)',text)
        self.assertIn('WAIT_fnc_CortexCombatEffective', text)
        blocked = text.split('// Holding/clearing owns the destination')[1]
        for guard in ['checkAIFeature "PATH"', 'checkAIFeature "MOVE"',
                      '_gunner in (_drill getOrDefault ["units",[]])',
                      'WAIT_AIPass_Garrison', 'WAIT_AIPass_Defend', 'WAIT_AIPass_ClearBuilding']:
            self.assertLess(blocked.index(guard), blocked.index('_gunner doMove'))
        self.assertIn('getOrDefault ["antiArmourRelocation",[]]',text)
        self.assertIn('expectedDestination _relocating',text)
        self.assertIn('setVariable ["WAIT_Cortex_ActorMove",["ANTI_ARMOUR"',text)
        self.assertIn('_state set ["antiArmourRelocation"',text)
        support=source('cortexSupportBoundStart')
        self.assertIn('getVariable ["WAIT_Cortex_ActorMove",[]]',support)
        self.assertIn('time >= (_actorMove select 2)',support)
        for cleanup in [source('cortexRestoreCalm'),source('cortexLocality')]:
            self.assertIn('setVariable ["WAIT_Cortex_ActorMove",nil]',cleanup)

    def test_calm_ends_drill_before_discarding_restoration_checkpoint(self):
        text = source('cortexRestoreCalm')
        end = text.index('[_group,_state,"CALM"] call WAIT_fnc_CortexFlankEnd')
        self.assertLess(end, text.index('call WAIT_fnc_CortexGroupMoveClear'))
        self.assertLess(end, text.index('setVariable ["WAIT_AIPass_Checkpoint", [], true]'))
        cleanup = source('cortexFlankEnd')
        self.assertIn('_unit enableAI _feature', cleanup)
        self.assertIn('_state deleteAt "drill"', cleanup)

    def test_cortex_stop_does_not_recall_external_groups_from_delayed_jobs(self):
        stop=source('cortexStop')
        self.assertIn('private _canRestoreGroup=local _group && {[_group,false,false,true] call WAIT_fnc_CortexIsEligible};',stop)
        self.assertIn('if (_canRestoreGroup && {!isNull (_group getVariable ["WAIT_AIPass_RegroupHost", grpNull])}) then {',stop)
        self.assertIn('if (_canRestoreGroup && {"team" in (_x select 2)}',stop)
        self.assertLess(stop.index('private _canRestoreGroup='),stop.index('doFollow leader _group'))

    def test_external_takeover_uses_one_cached_member_scan(self):
        takeover=source('cortexExternalTakeover')
        self.assertIn('private _members=units _group;',takeover)
        self.assertIn('_members findIf {[_x] call WAIT_fnc_CortexExternalOwner != ""}',takeover)
        self.assertNotIn('([leader _group] call WAIT_fnc_CortexExternalOwner)',takeover)
        self.assertNotIn('isPlayer leader _group',takeover)

    def test_delayed_vehicle_and_building_release_restore_shutdown_but_yield_to_external_owners(self):
        takeover=source('cortexExternalTakeover')
        for marker in ['_members findIf {isPlayer _x} >= 0','WAIT_fnc_CortexZeusHeld',
                       'WAIT_fnc_CortexExternalOwner','WAIT_fnc_CompatibilityExternalControl']:
            self.assertIn(marker,takeover)
        self.assertIn('if (isNull _group) exitWith {true};',takeover)
        for name in ['convoyReleaseLocal']:
            release=source(name)
            self.assertIn('private _externalTakeover = local _group && {[_group] call WAIT_fnc_CortexExternalTakeover};',release)
            expected='private _mayRestoreGroup=local _group && {!_externalTakeover};'
            self.assertIn(expected,release)
            self.assertNotIn('[_group,false,false,true] call WAIT_fnc_CortexIsEligible',release)

    def test_all_delayed_danger_and_passenger_commands_share_the_takeover_boundary(self):
        # A player, curator or specialist owner can arrive after an operation was planned. Each
        # remaining direct-command path must consult the common boundary at the point it chooses to
        # classify, restore, retry or release that earlier WAIT work.
        for name in ['dangerActionSelect','cortexReleaseGroup','recoveryStep','convoyDismountLocal']:
            self.assertIn('WAIT_fnc_CortexExternalTakeover',source(name),name)
        release=source('cortexReleaseGroup')
        self.assertIn('private _yieldToExternal=local _group && {!_yieldToZeus} && {[_group] call WAIT_fnc_CortexExternalTakeover};',release)
        recovery=source('recoveryStep')
        self.assertLess(recovery.index('WAIT_fnc_CortexExternalTakeover'),recovery.index('_actor doMove _destination'))
        passenger=source('convoyDismountLocal')
        self.assertLess(passenger.index('WAIT_fnc_CortexExternalTakeover'),passenger.index('_unit doMove _destination'))

    def test_master_stop_cancels_explicit_orders_on_their_owner(self):
        text = source('cortexStop')
        cleanup = text.split('if (local _x) then {\n')[1].split('};')[0]
        for function in ['CortexDefendRelease', 'CortexGarrisonRelease', 'CortexClearRelease']:
            self.assertIn('call WAIT_fnc_' + function, cleanup)
        for name, assignment in [('cortexDefendRelease', 'Defend'), ('cortexGarrisonRelease', 'Garrison')]:
            self.assertIn('setVariable ["WAIT_AIPass_' + assignment + '", nil, true]', source(name))
        qa = (ROOT/'releaseVerificationAndDeployment/cortexQA/runLifecycle.sqf').read_text(encoding='utf-8')
        self.assertIn('LIFE-no-old-order-resurrection', qa)
        self.assertIn('_drift <= 12', qa)

    def test_refused_headless_migration_preserves_owner_and_registry_contract(self):
        # WAIT does not select a headless client or transfer groups itself.  It adopts on the
        # confirmed destination owner, so the packaged audit must delegate to an available
        # migration provider and prove that a provider refusal leaves the actual owner and its
        # published registry untouched.
        adapter = (ROOT/'releaseVerificationAndDeployment/auditMission/initServer.sqf').read_text(encoding='utf-8')
        adopt = source('aiHeadlessAdoptLocal')
        adopt_body = adopt.split('params [', 1)[1]
        lifecycle = (ROOT/'releaseVerificationAndDeployment/cortexQA/runLifecycle.sqf').read_text(encoding='utf-8')
        self.assertIn('if !(isNil "Waldo_fnc_HeadlessMigrateGroup") exitWith {[_group,_owner] call Waldo_fnc_HeadlessMigrateGroup};', adapter)
        self.assertIn('_group setGroupOwner _owner;', adapter)
        self.assertIn('Engine-only HC transfer', adapter)
        self.assertNotIn('setGroupOwner', adopt_body)
        self.assertIn('clientOwner != _newOwner', adopt)
        self.assertIn('!local _group', adopt)
        self.assertIn('WAIT_AI_LastAdoptionKey', adopt)
        self.assertIn('WAIT_fnc_CortexLocality', adopt)
        self.assertIn('WAIT_fnc_SchedulerReconcile', adopt)
        for token in [
            'WAIT_Headless_ExcludeGroup',
            'WAIT_Headless_ManagedGroups',
            'LIFE-refused-transfer-owner-retained',
            'LIFE-refused-transfer-registry-retained',
            'groupOwner _group == _targetOwner',
            'count _records == 1',
            '(_records select 0 select 1) == _targetOwner',
        ]:
            self.assertIn(token, lifecycle)

    def test_reinforcement_readiness_requires_physical_squad_arrival(self):
        text=source('cortexSupportMaintain')
        arrival=text.split('// Contact can begin before the rally is reached.')[1]
        self.assertIn('count _fit >= 3', arrival)
        self.assertIn('_fit findIf {_x distance2D (_lease select 3) > 45} < 0', arrival)
        self.assertNotIn('currentWaypoint', arrival)
        self.assertIn('supportToken', arrival)

    def test_contact_does_not_revoke_reserved_rally(self):
        text=source('cortexGroupTick')
        enter=text.split('private _enterContact = {')[1].split('private _beginContact = {')[0]
        self.assertNotIn('CortexGroupMoveClear', enter)
        self.assertNotIn('set ["responding", false]', enter)
        self.assertIn('if (!_groupMovementOwned && {!(_state getOrDefault ["responding", false])} && {!(_state getOrDefault ["assaulting", false])})', text)
        maintain=source('cortexSupportMaintain')
        arrival=maintain.split('// Contact can begin before the rally is reached.')[1]
        self.assertNotIn('"CALM"', arrival)
        self.assertIn('"supportToken"', arrival)

    def test_post_contact_waits_for_bounded_manoeuvre_owner(self):
        text=source('cortexGroupTick')
        transition=text.split('// Smoke, terrain and buildings can briefly hide a target')[1].split('case "SECURITY"')[0]
        self.assertIn('count (_state getOrDefault ["drill",createHashMap]) > 0',transition)
        self.assertIn('_state getOrDefault ["assaulting",false]',transition)
        self.assertIn('_state getOrDefault ["responding",false]',transition)
        self.assertIn('if (!_manoeuvreActive',transition)
        self.assertLess(transition.index('if (!_manoeuvreActive'),transition.index('WAIT_AIPass_PostContact_LostSeconds'))

    def test_security_phase_preserves_and_finishes_prepared_coordinated_assault(self):
        tick=source('cortexGroupTick')
        security=tick.split('case "SECURITY": {',1)[1].split('case "SEARCH": {',1)[0]
        coordinated=source('cortexCoordinatedAssault')
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        self.assertIn('call WAIT_fnc_CortexCoordinatedAssault',security)
        self.assertIn('if (_coordinatedOwnsSecurity) exitWith {_delay = 2}',security)
        self.assertLess(security.index('call WAIT_fnc_CortexCoordinatedAssault'),security.index('WAIT_AIPass_PostContact_SecuritySeconds'))
        self.assertIn('private _publicResponders = _group getVariable ["WAIT_Cortex_SupportResponders",[]]',coordinated)
        self.assertIn('serverTime < (_lease select 2)',coordinated)
        self.assertIn('_status select 3',coordinated)
        self.assertIn('_state deleteAt "coordinated"',coordinated)
        for marker in ['COORD-contact-loss-entered-security','COORD-security-dispatches-prepared-assault']:
            self.assertIn(marker,qa)
        self.assertLess(qa.index('COORD-security-dispatches-prepared-assault'),qa.index('_enemy setUnitPos "AUTO"'))

    def test_checkpoint_repairs_public_phase_through_transition_ledger(self):
        checkpoint=source('cortexCheckpoint')
        repair=checkpoint.split('private _phase = _state getOrDefault ["phase","CALM"]',1)[1].split('// Engine MOVE commands',1)[0]
        self.assertIn('"CHECKPOINT_REPAIR"',repair)
        self.assertIn('call WAIT_fnc_CortexSetPhase',repair)
        self.assertNotIn('setVariable ["WAIT_AIPass_PublicPhase"',checkpoint)

    def test_empty_coordinated_dispatch_releases_planning_hold_immediately(self):
        server=source('cortexSupportAssaultServer')
        self.assertIn('if (_sent > 0) then {', server)
        self.assertIn('_job set ["assaultIssued",true]', server)
        empty=server.split('// Route geometry is evaluated from live positions.',1)[1]
        self.assertIn('_job set ["expiry",serverTime]',empty)
        self.assertIn('_requests deleteAt (_job get "key")',empty)
        self.assertIn('_requester setVariable ["WAIT_Cortex_SupportResponders",nil,true]',empty)
        self.assertIn('_helper setVariable ["WAIT_AIPass_SupportLease",nil,true]',empty)
        self.assertNotIn('remains retryable',server)
        requester=source('cortexCoordinatedAssault')
        self.assertIn('if (_status select 3) then {_acknowledged = true}', requester)
        self.assertIn('if (_acknowledged) exitWith {', requester)
        self.assertIn('[_group,_state,"ABORT"] call WAIT_fnc_CortexFlankEnd', requester)
        self.assertLess(requester.index('call WAIT_fnc_CortexFlankEnd'),requester.index('_state set ["coordinated",true]'))
        self.assertIn('if (time < _pendingUntil && {_publicResponders isNotEqualTo []}) exitWith {false}',requester)
        self.assertIn('_pendingUntil > 0 && {_publicResponders isEqualTo []}',requester)
        self.assertIn('[_state,"coordinated",10] call WAIT_fnc_CortexCooldown', requester)

    def test_coordinated_assault_dispatches_from_accepted_shared_contact(self):
        requester=source('cortexCoordinatedAssault')
        server=source('cortexSupportAssaultServer')
        self.assertIn('if (_responders isEqualTo []) exitWith {false}',requester)
        self.assertNotIn('serverTime - _first',requester)
        self.assertNotIn('_arrivals',requester)
        self.assertNotIn('(_status select 1) >= 0',server.split('private _rally=')[0])
        self.assertIn('private _routeOrigin=getPosATL _helperTransmitter',server)
        self.assertNotIn('private _rally=+(_lease select 3)',server)
        self.assertNotIn('(_status select 1) >= 0',server)
        self.assertIn('[_routeOrigin,_candidateRoutes,_enemy,[_supportOrigin]]',server)
        self.assertIn('([_helper] call WAIT_fnc_CortexGroupTransmitter)',server)
        self.assertIn('[_candidate] call WAIT_fnc_CortexGroupTransmitter',source('cortexSupportServer'))
        self.assertIn('private _groupTransmitter = [_group] call WAIT_fnc_CortexGroupTransmitter;',source('cortexSupportApply'))
        self.assertIn('private _directCoordinationPending = _attack isEqualTo []',source('cortexSupportApply'))
        self.assertIn('if (_okay && {_directCoordinationPending}) exitWith {',source('cortexSupportApply'))
        self.assertIn('private _dispatched=[]',server)
        self.assertIn('_job set ["leases",_dispatched]',server)
        self.assertIn('_helper setVariable ["WAIT_AIPass_SupportLease",nil,true]',server)
        self.assertIn('_requester setVariable ["WAIT_Cortex_SupportResponders",_dispatched apply',server)

    def test_coordinated_approaches_do_not_cross_support_fire_lane(self):
        server=source('cortexSupportAssaultServer')
        selector=source('cortexSelectAvenue')
        self.assertNotIn('([90,-90] select (_sent mod 2 == 1))',server)
        self.assertNotIn('private _crossesSupportLane=',server)
        self.assertIn('call WAIT_fnc_CortexSelectAvenue',server)
        self.assertIn('[_routeOrigin,_candidateRoutes,_enemy,[_supportOrigin]]',server)
        self.assertIn('_lateral < 30',selector)
        self.assertIn('private _originSide=',server)
        self.assertIn('private _desiredSide=',server)
        self.assertIn('private _candidateSide=',server)
        self.assertIn('private _sameSide=_candidateSide*_desiredSide > 0',server)
        self.assertIn('if (_sameSide && {!surfaceIsWater _candidate}',server)
        self.assertIn('_approaches findIf {_x distance2D _candidate < 60} < 0',server)
        self.assertIn('forEach [[45,90],[85,90],[65,135],[45,-90],[85,-90],[65,-135]]',server)
        self.assertNotIn('private _approachProtection=',server)
        self.assertIn('forEach [0.25,0.5,0.75]',selector)
        self.assertIn('terrainIntersectASL [_threatASL,_sampleASL]',selector)
        self.assertIn('lineIntersectsSurfaces [_rayStart,_sampleASL',selector)

    def test_coordinated_assault_waits_for_ack_before_requester_handover(self):
        tick=source('cortexGroupTick')
        coordinated=source('cortexCoordinatedAssault')
        self.assertLess(tick.index('private _coordinatedOwnsMovement = _vehicleOwnsMovement'),tick.index('call WAIT_fnc_CortexTacticalStart'))
        self.assertIn('if (!_holdFire && {_hasTargetKnowledge} && {!_ordered} && {!_coordinatedOwnsMovement})',tick)
        self.assertIn('["WAIT_AIPass_Flank_Enable", true] call _get',tick)
        self.assertIn('["WAIT_AIPass_Advance_Enable", true] call _get',tick)
        self.assertIn('_state set ["coordinatedPendingUntil",time+15]',coordinated)
        self.assertIn('if (time < _pendingUntil && {_publicResponders isNotEqualTo []}) exitWith {false}',coordinated)
        self.assertIn('false // A request alone owns no movement; acknowledgement performs the handover.',coordinated)
        self.assertIn('[_group,_state,"ABORT"] call WAIT_fnc_CortexFlankEnd',coordinated)
        self.assertIn('"coordinatedPendingUntil"',source('cortexRestoreCalm'))

    def test_live_context_chooses_action_instead_of_profile_or_idleness(self):
        selector=source('cortexTacticalStart')
        assessment=source('cortexTacticalAssess')
        flank=source('cortexFlankStart')
        advance=source('cortexAdvanceStart')
        assault=source('cortexAssaultStart')
        coordinated=source('cortexCoordinatedAssault')
        self.assertIn('call WAIT_fnc_CortexAssaultStart',selector)
        self.assertIn('private _closePosition=_manoeuvre findIf',assessment)
        self.assertIn('(_record param [3,1e9,[0]]) >= 12',assessment)
        self.assertIn('(_record param [3,1e9,[0]]) <= _closeRange',assessment)
        self.assertIn('private _freshPosition=_manoeuvre findIf',assessment)
        self.assertIn('(_record param [3,0,[0]]) >= 60',assessment)
        self.assertIn('_selected=_enemies findIf',assessment)
        self.assertIn('Any live contact can provide fire context',assessment)
        self.assertIn('_selected=_manoeuvre select _closePosition',assessment)
        self.assertIn('_selected=_manoeuvre select _freshPosition',assessment)
        self.assertIn('case "ASSAULT": {_started=[_group,_state,_orderedEnemies] call WAIT_fnc_CortexAssaultStart}',selector)
        self.assertIn('private _forwardOrder=_waypointIndex < count waypoints _group',assessment)
        self.assertIn('"FORTIFIED_OR_DISTANT_CONTACT"',assessment)
        self.assertIn('"OPEN_APPROACH"',assessment)
        self.assertIn('"COVERED_APPROACH"',assessment)
        self.assertIn('"MORALE_NOT_STEADY"',assessment)
        self.assertIn('"MORALE_SHAKEN"',assessment)
        self.assertIn('"AIR_OVERMATCH"',assessment)
        self.assertIn('"AA" in ([_x] call WAIT_fnc_CortexCapabilities)',assessment)
        self.assertIn('_platform isKindOf "Air"',assessment)
        tactical_qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runTacticalAssessment.sqf').read_text()
        for marker in ['TACTICAL-air-fixture-ready','TACTICAL-air-real-contact',
                       'TACTICAL-air-overmatch-reposition','TACTICAL-air-no-WAIT-chase',
                       'B_Heli_Attack_01_F','setVelocityModelSpace','magazinesAllTurrets']:
            self.assertIn(marker,tactical_qa)
        self.assertIn('"INSUFFICIENT_FIREPOWER"',assessment)
        self.assertIn('"ELEVATED_FIRE_POSITION"',assessment)
        self.assertIn('"CONCEALED_ELEVATED_APPROACH"',assessment)
        self.assertIn('"REPOSITION"',assessment)
        self.assertIn('"NO_SAFE_MANOEUVRE"',selector)
        self.assertIn('"MORALE_HANDOFF"',selector)
        self.assertIn('"WEAPON_LAYER_HANDOFF"',selector)
        self.assertIn('"NATIVE_CONTACT_HANDOFF"',selector)
        self.assertIn('"NATIVE_REASSESS"',selector)
        combat=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text(encoding='utf-8')
        self.assertIn('WAIT_Cortex_TacticalAssessment',combat)
        self.assertIn('-assessment-selected-intent',combat)
        self.assertIn('(_assessment select 0) == _mode',combat)
        self.assertIn('(_assessment select 5) == "STARTED"',combat)
        self.assertNotIn('CortexProfile',selector)
        self.assertNotIn('random',assessment)
        self.assertEqual(1,selector.count('call WAIT_fnc_CortexFlankStart'))
        self.assertEqual(1,selector.count('call WAIT_fnc_CortexAdvanceStart'))
        self.assertIn('["type","ASSAULT"]',assault)
        self.assertIn('["assaulting",true]',assault)
        self.assertIn('[["_group",grpNull',assault)
        self.assertIn('call WAIT_fnc_CortexSelectAvenue',assault)
        self.assertIn('call WAIT_fnc_OperationStart',assault)
        self.assertIn('call WAIT_fnc_CortexDrillStart',assault)
        self.assertNotIn('spawn',assault)
        self.assertNotIn('addWaypoint',assault)
        self.assertNotIn('random 1 >= ([_group, "flankChance"]',flank)
        self.assertNotIn('random 1 >= ([_group, "advanceChance"]',advance)
        self.assertNotIn('coordinatedChance',coordinated)
        self.assertNotIn('random 1 >= ([_group, "coordinatedChance"]',coordinated)

    def test_tactical_reposition_is_finite_generation_owned_and_yields_to_zeus(self):
        reposition=source('cortexTacticalReposition')
        selector=source('cortexTacticalStart')
        tick=source('cortexGroupTick')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        for marker in [
            'call WAIT_fnc_CortexIsEligible',
            'call WAIT_fnc_CortexExternalTakeover',
            'WAIT_Cortex_TacticalRepositionCooldown',
            'call WAIT_fnc_OperationStart',
            'call WAIT_fnc_CortexGroupMove',
            '["movementLease",["TACTICAL_REPOSITION",time+30]]',
        ]:
            self.assertIn(marker,reposition)
        self.assertIn('case "TACTICAL_REPOSITION": {"tacticalRepositionOperationGeneration"}',tick)
        self.assertIn('_reposition set [0,_movementResult]',tick)
        self.assertIn('_anchor distance2D (_record select 5) <= 12',tick)
        self.assertIn('["INCOMPLETE","COMPLETE"] select _arrived',tick)
        self.assertIn('class CortexTacticalReposition',functions)
        self.assertIn('case "REPOSITION"',selector)
        self.assertNotIn('spawn',reposition)
        self.assertNotIn('while {',reposition)
        self.assertNotIn('setPos',reposition)

    def test_direct_assault_uses_its_own_live_gate_and_cleanup_accounting(self):
        step=source('cortexFlankStep')
        end=source('cortexFlankEnd')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class CortexAssaultStart',functions)
        self.assertIn('case "ASSAULT": {"WAIT_AIPass_Assault_Enable"}',step)
        self.assertIn('case "ASSAULT": {"WAIT_AIPass_Assault_Cooldown"}',end)
        self.assertIn('case "ASSAULT": {"WAIT_AIPass_AssaultsCompleted"}',end)

    def test_tactical_assessment_audit_uses_real_contacts_and_physical_outcomes(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runTacticalAssessment.sqf').read_text(encoding='utf-8')
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('cortexQATacticalAssessment.sqf',server)
        self.assertIn('"tacticalassessment"',server)
        self.assertGreaterEqual(server.count('"dangerparity"'),3)
        self.assertIn('createVehicle ["B_APC_Wheeled_01_cannon_F"',qa)
        self.assertIn('createVehicle ["Land_Cargo_Tower_V1_F"',qa)
        self.assertIn('call WAIT_fnc_CortexKnowledge',qa)
        self.assertGreaterEqual(qa.count('private _knowledge=['),3)
        self.assertGreaterEqual(qa.count('((_knowledge select 0) findIf'),3)
        self.assertNotIn('call WAIT_fnc_CortexKnowledge) select 0) findIf',qa)
        self.assertIn('WAIT_Cortex_TacticalAssessment',qa)
        self.assertIn('"REPOSITION","ARMOUR_OVERMATCH","STARTED"',qa)
        self.assertIn('"AUTHORED_FORWARD_ORDER"',qa)
        self.assertIn('"REPOSITION","ELEVATED_FIRE_POSITION","STARTED"',qa)
        self.assertIn('TACTICAL-armour-overmatch-reposition',qa)
        self.assertIn('TACTICAL-elevated-reposition',qa)
        self.assertIn('TACTICAL-authored-order-physical-progress',qa)
        self.assertNotIn('call WAIT_fnc_CortexTacticalAssess',qa)
        self.assertNotIn(' reveal ',qa)
        self.assertNotIn('setPos',qa)

    def test_shipped_profiles_retain_legacy_movement_keys_for_configuration_compatibility(self):
        config=(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        defaults=(ROOT/'cortex_defaults.md').read_text(encoding='utf-8')
        for profile,flank,advance in [
            ('MILITIA','0.3','0.7'),
            ('LINE','0.5','0.6'),
            ('VETERAN','0.7','0.5'),
            ('ELITE','0.9','0.4'),
        ]:
            row=config.split(f'["{profile}", createHashMapFromArray ',1)[1].split(']]]',1)[0]
            self.assertIn(f'["flankChance", {flank}]',row)
            self.assertIn(f'["advanceChance", {advance}]',row)
            documented=defaults.split(f'["{profile}", createHashMapFromArray ',1)[1].split(']]]',1)[0]
            self.assertIn(f'["flankChance", {flank}]',documented)
            self.assertIn(f'["advanceChance", {advance}]',documented)

    def test_coordinated_selection_uses_bounded_server_responder_index(self):
        coordinated=source('cortexCoordinatedAssault')
        server=source('cortexSupportServer')
        step=source('cortexSupportStep')
        self.assertNotIn('allGroups',coordinated)
        self.assertIn('WAIT_Cortex_SupportResponders',coordinated)
        self.assertIn('_requester setVariable ["WAIT_Cortex_SupportResponders",[],true]',server)
        self.assertIn('private _responders = _kept apply {[_x select 0,_x select 1]}',step)
        self.assertIn('_requester setVariable ["WAIT_Cortex_SupportResponders",_responders,true]',step)
        self.assertIn('_requester setVariable ["WAIT_Cortex_SupportResponders",nil,true]',step)

    def test_support_request_failure_has_one_bounded_retry(self):
        reinforce=source('cortexReinforce')
        server=source('cortexSupportServer')
        step=source('cortexSupportStep')
        assault=source('cortexSupportAssaultServer')
        self.assertIn('WAIT_Cortex_SupportRequestState',reinforce)
        self.assertIn('_requests == 1',reinforce)
        self.assertIn('time >= _lastDispatch+20',reinforce)
        self.assertIn('_requests >= 2',reinforce)
        self.assertIn('["reinforceDispatchedAt",time]',reinforce)
        self.assertIn('"ACTIVE"',server)
        self.assertIn('"NO_RESPONDER"',step)
        self.assertIn('"NO_SAFE_ROUTE"',assault)
        self.assertIn('_job get "expiry"',assault)
        stop=source('cortexStop')
        self.assertIn('WAIT_Cortex_SupportRequestState',stop)
        self.assertIn('WAIT_Cortex_SupportResponders',stop)

    def test_infantry_support_never_routes_mounted_vehicle_crews_as_bounders(self):
        server=source('cortexSupportServer')
        step=source('cortexSupportStep')
        apply=source('cortexSupportApply')
        assault=source('cortexSupportAssaultServer')
        dismount_guard='[_x] call WAIT_fnc_CortexCombatEffective && {isNull objectParent _x}'
        self.assertIn(dismount_guard,server)
        self.assertGreaterEqual(step.count(dismount_guard),2)
        self.assertIn('private _footFit = _fit select {isNull objectParent _x}',apply)
        self.assertIn('count _footFit >= 3',apply)
        self.assertIn('_footFit findIf {"AT" in',apply)
        self.assertIn(dismount_guard,assault)

    def test_recurring_cqb_and_support_use_direct_on_foot_checks(self):
        names = [
            'cortexClearBuilding', 'cortexSupportApply', 'cortexSupportBoundStart',
            'cortexSupportMaintain', 'cortexSupportStep', 'cortexSupportCoordinateStep',
            'cortexSupportServer', 'cortexSupportAssaultServer'
        ]
        texts = [source(name) for name in names]
        for text in texts:
            self.assertIn('objectParent', text)
            self.assertNotIn('vehicle _x == _x', text)
            self.assertNotIn('vehicle _x != _x', text)

    def test_recurring_infantry_filters_use_direct_on_foot_checks(self):
        names = [
            'cortexGroupTick', 'cortexStance', 'cortexAntiArmour',
            'cortexFlankStep', 'rebalanceRoles', 'cortexAmmoShare'
        ]
        for text in [source(name) for name in names]:
            self.assertIn('objectParent', text)
            self.assertNotIn('vehicle _x == _x', text)
            self.assertNotIn('vehicle _unit == _unit', text)

    def test_external_takeover_boolean_chain_starts_with_a_boolean(self):
        takeover = source('cortexExternalTakeover')
        self.assertIn('(_members findIf {isPlayer _x} >= 0)\n||', takeover)
        self.assertNotIn('{_members findIf {isPlayer _x} >= 0}\n||', takeover)

    def test_packaged_audit_stops_after_command_boundary_preflight_failure(self):
        addon = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runAddon.sqf').read_text(encoding='utf-8')
        server = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('WAIT_fnc_CortexExternalTakeover', addon)
        self.assertIn('ADDON-command-boundary-boolean', addon)
        self.assertIn('_takeoverResult isEqualType true', addon)
        addon_call = '[_check] call compile preprocessFileLineNumbers "cortexQAAddon.sqf";'
        self.assertIn(addon_call, server)
        preflight = server.index(addon_call)
        abort = server.index('if (_failures isNotEqualTo []) exitWith {', preflight)
        first_fixture = server.index('private _group = grpNull;', preflight)
        self.assertLess(abort, first_fixture)
        early = server[abort:first_fixture]
        self.assertIn('WAIT_CortexQA_ServerDone', early)
        self.assertIn('WAIT CORTEX QA SERVER COMPLETE', early)

    def test_flank_support_lane_selection_is_spatially_bounded(self):
        flank=source('cortexFlankStart')
        self.assertIn('_enemyPos nearEntities ["Man",500]',flank)
        self.assertIn('} forEach _supportGroups;',flank)
        self.assertNotIn('} forEach allGroups;',flank)

    def test_server_opportunity_discovery_uses_spatial_candidate_sets(self):
        support=source('cortexSupportServer')
        reports=source('cortexReportServer')
        combined=source('cortexCombinedArmsServer')
        for text in [support,reports,combined]:
            self.assertIn('nearEntities ["Man",',text)
            self.assertNotIn('} forEach allGroups;',text)
        self.assertIn('} forEach _candidateGroups;',support)
        self.assertIn('} forEach _receiverGroups;',reports)
        self.assertIn('} forEach _candidateGroups;',combined)

    def test_combined_arms_opportunities_are_bounded_and_never_gate_infantry(self):
        request=source('cortexCombinedArmsRequest')
        server=source('cortexCombinedArmsServer')
        local=source('cortexCombinedArmsLocal')
        fallback=source('cortexCombinedAirFallbackServer')
        ground_step=source('cortexCombinedGroundStep')
        tick=source('cortexGroupTick')
        self.assertIn('serverTime+20+random 8',request)
        self.assertIn('remoteExecCall ["WAIT_fnc_CortexCombinedArmsServer",2]',request)
        self.assertIn('private _ground=0',server)
        self.assertIn('private _air=0',server)
        self.assertIn('WAIT_AIPass_ContactReports_Radius',server)
        self.assertIn('WAIT_AIPass_ContactReports_VoiceRange',server)
        self.assertIn('WAIT_Cortex_CombinedArms_AirRange',server)
        self.assertIn('private _orderedGroups=[]',server)
        self.assertIn('_orderedGroups sort true',server)
        self.assertIn('magazinesAllTurrets _candidateAsset',server)
        self.assertIn('Armed aircraft rank first',server)
        self.assertIn('WAIT_Cortex_CombinedAirFallback',server)
        self.assertIn('_distance <= _airRange',server)
        self.assertIn('_distance <= _groundRange',server)
        self.assertIn('_senderRadio && {_candidateRadio}',server)
        self.assertNotIn('private _range=if (_senderRadio)',server)
        self.assertNotIn('<= 1200',server)
        self.assertNotIn('CortexCanTransmit',request)
        self.assertIn('if (_ground >= 2 && {_air >= 1}) exitWith {}',server)
        self.assertIn('!isTouchingGround _asset',server)
        self.assertIn('{isTouchingGround _asset}',local)
        self.assertNotIn('speed _asset',server+local)
        self.assertNotIn('waitUntil',server+local)
        self.assertNotIn('addWaypoint',server+local)
        self.assertIn('CBA_fnc_waitAndExecute',server)
        self.assertIn('setVariable ["WAIT_Cortex_CombinedRole",nil,true]',server)
        self.assertIn('"DISPATCHED"',server)
        self.assertIn('"EXPIRED"',server)
        self.assertIn('["GROUND_FIRE","GROUND_MANOEUVRE"]',server)
        self.assertIn('_role in ["GROUND_FIRE","GROUND_MANOEUVRE","AIR_ATTACK"]',local)
        self.assertIn('WAIT_fnc_CortexCombinedGroundStep',local)
        self.assertIn('WAIT_fnc_CortexSelectAvenue',local)
        self.assertIn('_target,"VEHICLE"',local)
        self.assertIn('"NO_SAFE_ROUTE"',local)
        self.assertIn('forEach [260,320,380]',local)
        self.assertIn('forEach [180,240]',local)
        self.assertIn('"COMBINED_GROUND"',local+ground_step)
        self.assertIn('WAIT_fnc_CortexZeusHeld',ground_step)
        self.assertIn('if (_stalls >= 1)',ground_step)
        self.assertIn('[_group,_operationGeneration] call WAIT_fnc_CortexGroupMoveClear;',ground_step)
        self.assertNotIn('setPos',ground_step)
        self.assertNotIn('setVelocity',ground_step)
        self.assertNotIn('CortexCanTransmit',local)
        self.assertGreaterEqual(local.count('"APPLIED"'),2)
        self.assertIn('WAIT_Cortex_CombinedApplied',tick)
        self.assertIn('(_combinedApplied param [1,-1]) != clientOwner',tick)
        self.assertIn('_group reveal [_target,2.5]',local)
        # Shared knowledge must not become an ATTACK/pursuit order for every crew member. Only the
        # stationary fire role may explicitly target its gunner; manoeuvre and air controllers own
        # their later target/release boundary.
        role_preamble=local.split('if (_role == "GROUND_FIRE") exitWith {',1)[0]
        ground_fire=local.split('if (_role == "GROUND_FIRE") exitWith {',1)[1].split('if (_role == "GROUND_MANOEUVRE") exitWith {',1)[0]
        self.assertNotIn('doTarget',role_preamble)
        self.assertNotIn('forEach crew _asset',local)
        self.assertIn('_gunner doTarget _target',ground_fire)
        self.assertIn('_gunner doFire _target',ground_fire)
        self.assertIn('WAIT_fnc_AirAttackOperationStart',local)
        self.assertIn('private _plan=[_asset,_target] call WAIT_fnc_CortexAirAttackPlan',local)
        self.assertIn('"NO_VIABLE_WEAPON"',local)
        self.assertIn('WAIT_fnc_CortexCombinedAirFallbackServer',local)
        self.assertIn('remoteExecutedOwner != groupOwner _rejected',fallback)
        self.assertIn('FALLBACK_DISPATCHED',fallback)
        self.assertIn('WAIT_Cortex_AirAttackJob',fallback)
        self.assertIn('CBA_fnc_waitAndExecute',fallback)
        self.assertIn('["target",_target]',local)
        self.assertIn(']],0.5] call WAIT_fnc_AirAttackOperationStart',local)
        self.assertNotIn('WAIT_AIPass_CoordinatedAssault_Enable',server)
        self.assertIn('WAIT_fnc_CortexCombinedArmsRequest',tick)
        begin_contact=tick.split('private _beginContact = {',1)[1].split('};\n\nif (_visible',1)[0]
        self.assertIn('WAIT_fnc_CortexCombinedArmsRequest',begin_contact)
        first_contact_share=begin_contact.rsplit('// The first fresh contact',1)[1]
        self.assertNotIn('if (_nearTier',first_contact_share.split('WAIT_fnc_CortexCombinedArmsRequest',1)[0])
        self.assertNotIn('WAIT_AIPass_CoordinatedAssault_Enable',
                         first_contact_share.split('WAIT_fnc_CortexCombinedArmsRequest',1)[0])
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        self.assertIn('cortex-combined-role-',diagnostics)
        self.assertIn('Combined roles share an opportunity only',diagnostics)

    def test_helicopter_locality_pin_does_not_disable_cortex_flight_behaviour(self):
        eligible=source('cortexIsEligible')
        self.assertIn('WAIT_ImprovedHelicopterLanding_Active',eligible)
        self.assertNotIn('_vehicles findIf {_x getVariable ["WAIT_Headless_HelicopterPinned"',eligible)
        self.assertIn('The permanent helicopter pin prevents unstable HC transfer',eligible)

    def test_external_ai_owners_are_detected_without_blanket_mod_exclusion(self):
        owner=source('cortexExternalOwner')
        eligible=source('cortexIsEligible')
        for marker in ['WBK_AI_ISZombie','Droid_Health','WBK_Droids_VoiceType','WBK_AI_ZombieMoveSet',
                       'IMS_IsUnitInvicibleScripted','IMS_ISAI','IMS_EventHandler_Hit']:
            self.assertIn(marker,owner)
        self.assertIn('_class find "WBK_" == 0',owner)
        self.assertNotIn('_moves != ""',owner)
        self.assertIn('getText (_config >> "author")',owner)
        self.assertIn('[_unit] call WAIT_fnc_CortexExternalOwner != ""',eligible)
        self.assertNotIn('isClass (configFile >> "CfgPatches"',eligible)

    def test_wait_movement_lease_does_not_mutate_broad_external_ai_state(self):
        lease=source('cortexOwnershipLease')
        compat=(ROOT/'addons/compatibility/functions/aiTweaksDetectCompatibility.sqf').read_text(encoding='utf-8')
        self.assertIn('WAIT_Cortex_MovementLease',lease)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',lease)
        self.assertIn('_live && {(_lease select 0) != _owner}',lease)
        for forbidden in ['AlternativeBackend','Vcm_Disable','VCM_MOVE2SUP','VCM_MBUSY','VCOM_AI']:
            self.assertNotIn(forbidden,lease+compat)
        for capability in ['"meleeBackend"','"specialistBackend"']:
            self.assertIn(capability,compat)

    def test_civilian_reactions_are_event_driven_and_yield_to_wbk_and_zeus(self):
        setup=source('cortexCivilianSetup')
        react=source('cortexCivilianReact')
        init=source('cortexInit')
        stop=source('cortexStop')
        for event in ['"FiredNear"','"Explosion"','"Hit"','"Local"']:
            self.assertIn(event,setup)
        self.assertNotIn('CBA_fnc_addPerFrameHandler',setup+react)
        self.assertNotIn('while {',setup+react)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',setup)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',react)
        self.assertIn('BIS_fnc_findSafePos',react)
        self.assertIn('forEach [0,-45,45]',react)
        self.assertGreaterEqual(react.count('call WAIT_fnc_CortexSelectAvenue'),2)
        self.assertIn('if (_route isEqualTo []) exitWith {false}',react)
        self.assertIn('doMove _destination',react)
        self.assertIn('_priority <= (_active param [1,0,[0]])',react)
        self.assertIn('WAIT_Cortex_CivilianGeneration',react)
        self.assertIn('WAIT_fnc_CortexCivilianStep',react)
        self.assertIn('_active param [5,',react)
        self.assertNotIn('switchMove',react)
        step=source('cortexCivilianStep')
        self.assertIn('WAIT_Cortex_CivilianGeneration',step)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',step)
        self.assertEqual(step.count('_unit doMove _destination'),1)
        self.assertNotIn('while {',step)
        self.assertIn('"EntityCreated"',init)
        self.assertIn('WAIT_Cortex_CivilianCreatedHandler',stop)
        settings=source('aiTweaksSettingChanged')
        self.assertIn('WAIT_AIPass_CivilianReaction_Enable',settings)
        self.assertIn('call WAIT_fnc_CortexInit',settings)

    def test_aircraft_occupants_have_one_dedicated_movement_owner(self):
        eligible=source('cortexIsEligible')
        discover=source('cortexDiscover')
        tick=source('cortexGroupTick')
        attack=source('cortexAirAttack')
        self.assertIn('["_groundPass",false,[true]]',eligible)
        self.assertIn('_groundPass && {_alive findIf {',eligible)
        self.assertIn('_vehicle isKindOf "Air"',eligible)
        self.assertIn('[_group,false,true] call WAIT_fnc_CortexIsEligible',discover)
        self.assertIn('private _generallyEligible=[_group] call WAIT_fnc_CortexIsEligible',tick)
        self.assertIn('private _groundPassEligible=[_group,false,true] call WAIT_fnc_CortexIsEligible',tick)
        self.assertIn('[_group,true,"AIRCRAFT_DEDICATED"] call WAIT_fnc_CortexReleaseGroup',tick)
        self.assertIn('_stage != "" || {[_group] call WAIT_fnc_CortexIsEligible}',attack)
        self.assertIn('private _explicitlyExcluded=',attack)

    def test_partial_final_bound_does_not_complete_the_assault(self):
        coordinator=source('cortexSupportCoordinateStep')
        self.assertIn('_outcome in ["COMPLETE","PARTIAL"]',coordinator)
        self.assertIn('if (_outcome == "COMPLETE" && {_final})',coordinator)
        self.assertNotIn('if (_progressed && {_final})',coordinator)
        self.assertIn('!(_token in _completed)',coordinator)

    def test_combined_roles_use_owned_fire_team_drills_and_restore_holds(self):
        coordinator=source('cortexSupportCoordinateStep')
        self.assertNotIn('allUnits',coordinator)
        self.assertNotIn('allGroups',coordinator)
        self.assertIn('if (_old isNotEqualTo _role)',coordinator)
        self.assertIn('(_result select 0) == _token',coordinator)
        self.assertIn('serverTime+8',coordinator)
        self.assertIn('private _failuresByToken=',coordinator)
        self.assertIn('_outcome in ["COMPLETE","PARTIAL"]',coordinator)
        self.assertIn('_retired pushBackUnique _token',coordinator)
        self.assertIn('if (_failures >= 2)',coordinator)
        self.assertNotIn('_job set ["coordinationAborted",true]',coordinator)
        self.assertIn('private _boundLength=(_remaining*0.35) max 45 min 70',coordinator)
        self.assertIn('forEach [0,-18,18]',coordinator)
        self.assertIn('WAIT_fnc_CortexSelectAvenue',coordinator)
        self.assertIn('_job get "assaultEnemy",_supportOrigins',coordinator)
        self.assertIn('"INSUFFICIENT_STRENGTH"',coordinator)
        self.assertIn('[_token,serverTime,"BOUND_FAILURES",_failures]',coordinator)
        self.assertIn('[_token,serverTime,"INSUFFICIENT_STRENGTH",count _fit]',coordinator)
        self.assertIn('private _watchdog=(((_boundTimeout max 10)*4)+15) min 180',coordinator)
        self.assertNotIn('serverTime+180',coordinator)
        self.assertIn('private _maxConcurrent=(count _teams) min 2',coordinator)
        self.assertIn('for "_slot" from count _active to (_maxConcurrent-1)',coordinator)
        self.assertIn('_active pushBack [_group,_sequence,serverTime+_watchdog',coordinator)
        self.assertIn('distance2D _goal < 60',coordinator)
        self.assertIn('if ((_activeRaw select 0) isEqualType grpNull)',coordinator)
        start=source('cortexSupportBoundStart')
        self.assertIn('["teams",[_first,_second]]',start)
        self.assertIn('["SUPPORT_BOUND","FINAL"] select _final',start)
        self.assertIn('WAIT_fnc_CortexDrillStart',start)
        self.assertIn('"supportHeld"',source('cortexCheckpoint'))
        for name in ['cortexRetreat','cortexRestoreCalm']:
            self.assertIn('"supportHeld"',source(name))
            self.assertIn('WAIT_fnc_CortexSupportAck',source(name))
        maintain=source('cortexSupportMaintain')
        self.assertIn('private _abort = _group getVariable ["WAIT_Cortex_SupportAbort",[]]',maintain)
        self.assertIn('count _abort == 4 && {(_abort select 0) == _token}',maintain)
        self.assertIn('call _releaseSupport;',maintain)
        self.assertIn('_helper setVariable ["WAIT_Cortex_SupportAbort",nil,true]',source('cortexSupportStep'))

    def test_contacted_peer_can_join_coordinated_assault_without_calm_rally_gate(self):
        apply=source('cortexSupportApply')
        self.assertIn('private _contactPeer = _phase in ["CONTACT","SECURITY"]',apply)
        self.assertIn('_phase == "CALM" || {_contactPeer}',apply)
        self.assertIn('[0.2,0.65] select _contactPeer',apply)
        self.assertNotIn('(_state getOrDefault ["phase","CALM"]) == "CALM"',apply)
        self.assertIn('private _supportEnabled',apply)
        self.assertIn('WAIT_AIPass_Reinforce_Enable',apply)
        self.assertIn('WAIT_AIPass_CoordinatedAssault_Enable',apply)
        server=source('cortexSupportServer')
        support_step=source('cortexSupportStep')
        maintain=source('cortexSupportMaintain')
        for text in [server,support_step,maintain]:
            self.assertIn('WAIT_AIPass_Reinforce_Enable',text)
            self.assertIn('WAIT_AIPass_CoordinatedAssault_Enable',text)
        self.assertIn('|| {!_supportEnabled}',maintain)
        tick=source('cortexGroupTick')
        self.assertIn('// Shared support discovery is needed by either ordinary reinforcement or coordinated assault.',tick)
        self.assertIn('if (!_holdFire && {!_nearTier} && {!_ordered}',tick)
        step=source('cortexFlankStep')
        self.assertIn('(_supportRole select 1) == (_drill get "supportSequence")',step)
        self.assertIn('WAIT_AIPass_CoordinatedAssault_Enable',step)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text(encoding='utf-8')
        for check in ['COORD-inter-squad-role-exchange','COORD-concurrent-squad-bounds','COORD-concurrent-lanes-separated','COORD-inter-squad-physical-cover','COORD-intra-squad-physical-cover']:
            self.assertIn(check,qa)
        self.assertIn('abs speed _x > 2',qa)
        self.assertIn('_shots-(_shotCounts select _i)',qa)
        operation=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombinedOperation.sqf').read_text(encoding='utf-8')
        self.assertIn('["WAIT_AIPass_Reinforce_Enable",false]',operation)
        self.assertIn('["WAIT_AIPass_Reinforce_MaxResponders",0]',operation)
        self.assertIn('COMBINED-OP-independent-coordination-gate',operation)
        self.assertIn('private _lastInfantryShotCount=0',operation)
        self.assertIn('_movingGroups == 0 && {_infantryShotCount == _lastInfantryShotCount}',operation)
        self.assertIn('longest infantry movement/fire lull=',operation)

    def test_assault_preserves_group_attack_setting(self):
        apply=source('cortexSupportApply')
        self.assertNotIn('enableAttack false',apply)
        self.assertNotIn('set ["baseAttack",attackEnabled _group]',apply)
        self.assertNotIn('enableAttack false',source('cortexSupportBoundStart'))
        maintain=source('cortexSupportMaintain')
        self.assertEqual(1, maintain.count('call _restoreAttack;'))
        # Support release has distinct lease, feature and ownership-transition paths.  Do not
        # couple this preservation check to their exact count as finite-operation cleanup adds
        # valid cancellation reasons without changing group attack ownership.
        self.assertGreaterEqual(maintain.count('call _releaseSupport;'),2)
        self.assertIn('enableAttack (_state getOrDefault ["baseAttack",true])', maintain)
        self.assertIn('"baseAttack", "attackChanged"', source('cortexCheckpoint'))
        self.assertIn('enableAttack (_state getOrDefault ["baseAttack",true])', source('cortexRestoreCalm'))

    def test_support_reservation_requires_a_shared_executable_mode(self):
        server=source('cortexSupportServer')
        step=source('cortexSupportStep')
        apply=source('cortexSupportApply')
        maintain=source('cortexSupportMaintain')
        self.assertIn('private _requesterReinforce',server)
        self.assertIn('private _requesterCoordinated',server)
        self.assertIn('[_configuredMaximum,_configuredMaximum max 2] select _requesterCoordinated',server)
        for text in [step,apply,maintain]:
            self.assertIn('private _sharedReinforce',text)
            self.assertIn('private _sharedCoordinated',text)
            self.assertIn('_sharedReinforce || {_sharedCoordinated}',text)
        self.assertIn('private _directCoordinationPending = _attack isEqualTo [] && {_sharedCoordinated}',apply)
        self.assertIn('private _attackAllowed = _attack isNotEqualTo [] && {_sharedCoordinated}',apply)

    def test_zeus_handover_preserves_replacement_attack_setting(self):
        restore=source('cortexRestoreCalm')
        flank_end=source('cortexFlankEnd')
        self.assertIn('if (!_yieldToExternal && {_state getOrDefault ["attackChanged",false]})',restore)
        self.assertIn('!(_reason in ["ZEUS","OWNERSHIP_LOST"])',flank_end)
        self.assertIn('if (_mayCommand && {_state getOrDefault ["attackChanged",false]})',flank_end)

    def test_zeus_takeover_releases_explicit_orders_without_waypoint(self):
        text=source('cortexGroupTick').split('if (!_generallyEligible)')[1].split('// Survivor regroup')[0]
        self.assertIn('if ([_group] call WAIT_fnc_CortexZeusHeld) then', text)
        for name in ['CortexGarrisonRelease','CortexDefendRelease','CortexClearRelease']:
            self.assertIn('call WAIT_fnc_'+name, text)
        self.assertNotIn('getVariable ["WAIT_AIPass_ZeusWaypoints"', text)

    def test_garrison_duck_cleanup_preserves_later_stance(self):
        apply=source('cortexGarrisonApplyLocal')
        release=source('cortexGarrisonRelease')
        self.assertIn('if (unitPos _unit == (_unit getVariable ["WAIT_Cortex_GarrisonDuckStance", ""]))', apply)
        self.assertIn('if (unitPos _x == (_x getVariable ["WAIT_Cortex_GarrisonDuckStance", ""]))', release)
        self.assertIn('!([group _unit] call WAIT_fnc_CortexIsEligible)', apply)
        delayed=apply.split('params ["_unit", "_until"];')[1].split('}, [_unit, _until]')[0]
        self.assertIn('&& {[group _unit] call WAIT_fnc_CortexIsEligible}', delayed)
        for text in [apply, release]:
            self.assertIn('setVariable ["WAIT_Cortex_GarrisonDuckStance",nil,true]', text)

    def test_surrender_releases_orders_before_captive_handover(self):
        text=source('cortexSurrender')
        for guard in ['!local _group','WAIT_fnc_CortexIsEligible','WAIT_AIPass_Surrender_Enable']:
            self.assertLess(text.index(guard),text.index('createVehicle'))
        for release in ['CortexGarrisonRelease','CortexDefendRelease','CortexClearRelease','CortexReleaseGroup']:
            self.assertLess(text.index(release),text.index('call ace_captives_fnc_setSurrendered'))
        self.assertIn('WAIT_fnc_CortexCombatEffective',text)

    def test_grenade_evasion_regroup_does_not_overwrite_new_actions(self):
        text=source('cortexGrenadeCheck')
        callback=text.split('params ["_unit","_group","_spot","_hold"];')[1].split('private _grenade =',1)[0]
        for guard in ['GRENADE_EVASION','group _unit == _group','vehicle _unit == _unit','WAIT_fnc_CortexCombatEffective','WAIT_AIPass_ZeusHold','expectedDestination _unit','_unit in (_drill']:
            self.assertLess(callback.index(guard),callback.index('doFollow'))
        self.assertLess(callback.index('doFollow'),callback.index('setVariable ["WAIT_Cortex_ActorMove",nil]'))
        self.assertIn('if (_ownsEvasion && {local _unit}) then {',callback)
        self.assertIn('setVariable ["WAIT_Cortex_ActorMove",["GRENADE_EVASION"',text)
        self.assertIn('count _actorMove != 3 || {time >= (_actorMove select 2)}',text)
        self.assertIn('setVariable ["WAIT_Cortex_ActorMove",nil]',callback)
        self.assertIn('[WAIT_fnc_CortexGrenadeCheck,createHashMapFromArray [["regroup",_regroupActors]],6] call WAIT_fnc_CortexQueueJob',text)
        self.assertIn('"WAIT_AIPass_GrenadeEvasion_Enable",true] call WAIT_fnc_CortexFeatureEnabled',text)
        self.assertNotIn('CBA_fnc_waitAndExecute',text)

    def test_grenade_evasion_temporarily_outranks_support_cover_hold(self):
        grenade=source('cortexGrenadeCheck')
        self.assertIn('private _supportHeld = _state getOrDefault ["supportHeld",[]]',grenade)
        self.assertIn('_unit checkAIFeature "PATH" || {_unit in _supportHeld}',grenade)
        self.assertIn('_unit enableAI "PATH"',grenade)
        self.assertIn('_state set ["supportHeld",_supportHeld-[_unit]]',grenade)
        maintain=source('cortexSupportMaintain')
        self.assertIn('getVariable ["WAIT_Cortex_ActorMove",[]]',maintain)
        self.assertIn('time >= (_actorMove select 2)',maintain)

    def test_tactical_drills_do_not_consume_reserved_actors(self):
        for name in ['cortexFlankStart','cortexAdvanceStart']:
            text=source(name)
            self.assertIn('getVariable ["WAIT_Cortex_ActorMove",[]]',text)
            self.assertIn('count _actorMove != 3 || {time >= (_actorMove select 2)}',text)

    def test_queued_grenade_rechecks_takeover_and_frag_safety(self):
        text=source('cortexThrowGrenade')
        callback=text.split('params ["_unit", "_muzzle", "_magazine"')[1]
        for guard in ['WAIT_fnc_CortexCombatEffective','WAIT_fnc_CortexIsEligible','WAIT_AIPass_ZeusHold','_magazine in magazines _unit','_distance < 8','_distance > 40','nearEntities ["CAManBase",12]']:
            self.assertIn(guard,callback)
        self.assertLess(callback.index('WAIT_AIPass_ZeusHold'),callback.index('forceWeaponFire'))
        self.assertLess(callback.index('!= _drillToken'),callback.index('forceWeaponFire'))

    def test_retreat_releases_drill_before_capturing_attack_control(self):
        text=source('cortexRetreat')
        self.assertLess(text.index('call WAIT_fnc_CortexFlankEnd'),text.index('set ["baseAttack"'))
        self.assertIn('_group enableAttack false',text)
        self.assertIn('_state set ["behaviourChanged",true]',text)
        self.assertIn('_state set ["baseBehaviour",behaviour _leader]',text)

    def test_retreat_keeps_fire_while_leasing_engine_pursuit_mode(self):
        retreat=source('cortexRetreat')
        restore=source('cortexRestoreCalm')
        checkpoint=source('cortexCheckpoint')
        self.assertIn('combatMode _group == "RED"',retreat)
        self.assertIn('_state set ["retreatCombatMode",["RED","YELLOW"]]',retreat)
        self.assertIn('_group setCombatMode "YELLOW"',retreat)
        self.assertNotIn('_group setCombatMode "BLUE"',retreat)
        self.assertIn('combatMode _group == (_retreatModeLease select 1)',restore)
        self.assertIn('_group setCombatMode (_retreatModeLease select 0)',restore)
        self.assertIn('!_yieldToExternal',restore)
        self.assertIn('"retreatCombatMode"',checkpoint)
        self.assertIn('"retreatCombatMode"',restore.split('{_state deleteAt _x} forEach [',1)[1])

    def test_every_explicit_infantry_order_transitions_into_physical_retreat(self):
        tick=source('cortexGroupTick')
        block=tick.split('private _retreatStarted=false',1)[1].split('_state set ["armourSeen"',1)[0]
        for release in ['CortexGarrisonRelease','CortexDefendRelease','CortexClearRelease']:
            self.assertIn(f'call WAIT_fnc_{release}',block)
        self.assertEqual(1,block.count('call WAIT_fnc_CortexRetreat'))
        self.assertGreater(block.index('call WAIT_fnc_CortexRetreat'),block.index('switch (true)'))
        self.assertIn('if (_retreatStarted) exitWith {}',block)

    def test_infantry_withdrawal_releases_support_holds_and_owns_its_route(self):
        retreat=source('cortexRetreat')
        support=retreat.split('private _supportHeld=',1)[1].split('{_state deleteAt _x}',1)[0]
        self.assertIn('_x enableAI "PATH"',support)
        self.assertIn('_x doFollow _leader',support)
        self.assertIn('WAIT_Cortex_SupportPathHold',support)
        self.assertIn('_state set ["movementLease",["INFANTRY_WITHDRAW",time+_remaining]]',retreat)
        self.assertLess(retreat.index('CortexGroupMove'),retreat.index('["INFANTRY_WITHDRAW",time+_remaining]'))

    def test_infantry_withdrawal_requires_progress_and_replans_without_teleport(self):
        retreat=source('cortexRetreat')
        tick=source('cortexGroupTick')
        restore=source('cortexRestoreCalm')
        for marker in ['set ["retreatStart",_origin]',
                       'set ["retreatTarget",_point]',
                       'set ["retreatProgress",[time,_bestTravel,_replans]]']:
            self.assertIn(marker,retreat)
        retreat_case=tick.split('case "RETREAT":')[1]
        for marker in ['_travel < 30','_now-_progressAt >= 15','_travel >= _bestTravel+3','_replans < 4',
                       'forEach [30,-30,60,-60]','_candidate distance2D _target >= 20',
                       'call WAIT_fnc_CortexSelectAvenue','WAIT_fnc_CortexGroupMove',
                       'WAIT_Cortex_Withdrawal']:
            self.assertIn(marker,retreat_case)
        self.assertNotIn('setPos',retreat_case)
        self.assertIn('"retreatStart", "retreatTarget", "retreatProgress"',restore)
        self.assertIn('setVariable ["WAIT_Cortex_Withdrawal",nil,true]',restore)
        self.assertIn('_operationState=[_group,_generation,3,15] call WAIT_fnc_OperationStep',retreat_case)
        self.assertIn('_operation=_group getVariable ["WAIT_Operation",createHashMap]',retreat_case)
        self.assertIn('private _unavailable=_operation getOrDefault ["unavailable",[]]',retreat_case)
        self.assertIn('private _recoveryRecord=_recovery getOrDefault [netId _x,[]]',retreat_case)
        self.assertIn('if (_operationState in ["ZEUS","EXTERNAL","LOST_OWNER","REPLACED"]) exitWith {',retreat_case)

    def test_trapped_withdrawal_uses_bounded_dry_fallback_and_keeps_fighting(self):
        retreat=source('cortexRetreat')
        tick=source('cortexGroupTick')
        self.assertIn('forEach [0.75,0.5,0.25]',retreat)
        self.assertIn('forEach [0,45,-45,90,-90,135,-135,180]',retreat)
        self.assertIn('["BLOCKED",0,0]',retreat)
        contact=tick.split('case "CONTACT": {',1)[1].split('case "SECURITY": {',1)[0]
        self.assertIn('private _retreatStarted=false',contact)
        self.assertIn('_state set ["retreatRetryAt",_now+10]',contact)
        self.assertIn('if (_retreatStarted) exitWith {}',contact)
        self.assertLess(contact.index('if (_retreatStarted) exitWith {}'),contact.index('CortexFireControl'))
        self.assertNotIn('if (_outcome == "RETREAT") exitWith {',contact)

    def test_infantry_withdrawal_resumes_across_locality_without_replaying_effects(self):
        retreat=source('cortexRetreat')
        locality=source('cortexLocality')
        tick=source('cortexGroupTick')
        restore=source('cortexRestoreCalm')
        self.assertIn('WAIT_Cortex_WithdrawalIntent',retreat)
        self.assertIn('["INFANTRY",_origin,_point,_enemyPos,_startedAt,_replans,_bestTravel]',retreat)
        self.assertIn('if (!_resuming) then {',retreat)
        effects=retreat.split('if (!_resuming) then {',2)[2]
        self.assertIn('CortexThrowGrenade',effects)
        self.assertIn('CortexArtilleryFire',effects)
        self.assertIn('private _withdrawalIntent',locality)
        self.assertGreater(locality.index('CortexRetreat'),locality.index('CortexRestoreCalm'))
        self.assertIn('[_group,_adopted,_withdrawalIntent] call WAIT_fnc_CortexRetreat',locality)
        self.assertIn('time-_elapsed,_resuming] call WAIT_fnc_CortexSetPhase',retreat)
        self.assertIn('_intent set [5,_replans]',tick)
        self.assertIn('_intent set [6,_bestTravel]',tick)
        self.assertIn('setVariable ["WAIT_Cortex_WithdrawalIntent",nil,true]',restore)

    def test_withdrawal_smoke_cannot_leave_the_route_owner_staring_at_the_screen(self):
        text=source('cortexRetreat')
        self.assertIn('_smokers=(_smokers select {_x != _leader})+(_smokers select {_x == _leader});',text)
        self.assertIn('if ([_x, _enemyPos, "SMOKE"] call WAIT_fnc_CortexThrowGrenade) exitWith {};',text)
        self.assertNotIn('CBA_fnc_waitAndExecute',text)
        self.assertNotIn('_smoker doMove',text)
        self.assertNotIn('_smoker doFollow',text)

    def test_clear_release_never_recalls_an_externally_owned_group(self):
        release=source('cortexClearRelease')
        self.assertIn('private _externalTakeover = [_group] call WAIT_fnc_CortexExternalTakeover;',release)
        self.assertIn('then {_restore=false}',release)
        self.assertLess(release.index('then {_restore=false}'),release.index('if (_restore) then {_x doFollow _leader}'))
    def test_building_handover_never_restores_or_locks_wait_state_after_takeover(self):
        clear_release=source('cortexClearRelease')
        clear_job=source('cortexClearBuilding')+source('buildingOperationStep')
        garrison_release=source('cortexGarrisonRelease')
        garrison_apply=source('cortexGarrisonApplyLocal')
        # Replacement orders may set posture and speed independently. Cleanup only restores either
        # after a normal WAIT release, never after the shared external-ownership boundary fired.
        self.assertIn('if (_restore && {unitPos _x == "UP"}',clear_release)
        self.assertIn('if (_restore && {!isNil {_x getVariable "WAIT_Cortex_ClearForcedSpeed"}}',clear_release)
        self.assertIn('if (_restore && {unitPos _x == "UP"}',clear_job)
        self.assertIn('if (_restore && {!isNil {_x getVariable "WAIT_Cortex_ClearForcedSpeed"}}',clear_job)
        self.assertIn('if (unitPos _x == (_x getVariable ["WAIT_Cortex_GarrisonDuckStance", ""])) then {',garrison_release)
        self.assertIn('if (!_externalTakeover) then {',garrison_release)
        self.assertIn('if (!_externalTakeover && {getForcedSpeed _x ==',garrison_release)
        # The garrison job must release its own PATH lock at loss of eligibility and recheck
        # ownership before its arrival hold or first individual move can mutate a unit.
        self.assertIn('[_group,false] call WAIT_fnc_CortexGarrisonRelease;',garrison_apply)
        self.assertIn('if (call _mayIssueMovement) then {doStop _unit};',garrison_apply)
        arrival=garrison_apply.split('if (_x distance (_assignment select 0) <= 2) then {',1)[1].split('} else {',1)[0]
        self.assertIn('if (call _mayIssueMovement) then {',arrival)
        self.assertLess(arrival.index('if (call _mayIssueMovement) then {'),arrival.index('_x disableAI "PATH"'))
    def test_locality_handover_uses_a_surviving_anchor_for_restoration_and_search(self):
        """A handoff during leader succession must restore only toward a viable local actor."""
        locality=source('cortexLocality')
        self.assertIn('private _restoreAnchor=[_group] call WAIT_fnc_CortexGroupAnchor;',locality)
        self.assertIn('_x doFollow _restoreAnchor',locality)
        self.assertIn('private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;',locality)
        self.assertIn('if (isNull _leader) then {_leader=leader _group};',locality)

    def test_post_contact_movement_resumes_across_locality_with_original_deadline(self):
        checkpoint=source('cortexCheckpoint')
        locality=source('cortexLocality')
        restore=source('cortexRestoreCalm')
        for marker in ['WAIT_Cortex_TransitionIntent','["INVESTIGATE","SEARCH"]','_startedAt+_duration','searchTeam']:
            self.assertIn(marker,checkpoint)
        self.assertIn('serverTime < (_transitionIntent select 3)',locality)
        self.assertIn('_withdrawalIntent isEqualTo []',locality)
        self.assertIn('CortexZeusHeld',locality)
        self.assertIn('private _transitionResumeEligible=',locality)
        self.assertIn('!(_transitionResumeEligible || {_withdrawalResumeEligible})',locality)
        self.assertIn('[_group,_adopted,_transitionPhase,"OWNERSHIP_RESUME",time-((serverTime-_startedAt) max 0),true] call WAIT_fnc_CortexSetPhase',locality)
        self.assertIn('CortexGroupMove',locality)
        self.assertIn('doMove',locality)
        self.assertNotIn('CBA_fnc_waitAndExecute',locality)
        self.assertIn('setVariable ["WAIT_Cortex_TransitionIntent",nil,true]',restore)

    def test_vehicle_withdrawal_records_and_resumes_physical_progress(self):
        vehicles=source('cortexVehicles')
        locality=source('cortexLocality')
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        for marker in ['_state set ["retreatStart",_origin]',
                       '_state set ["retreatTarget",_away]',
                       '_state set ["retreatProgress",[time,0,0]]',
                       '["VEHICLE",_origin,_away,_enemyPos,serverTime,0,0]']:
            self.assertIn(marker,vehicles)
        for terrain_marker in ['private _selectVehicleEscape = {','forEach [0,-25,25,-45,45]',
                               'WAIT_fnc_CortexSelectAvenue','_threatObject,"VEHICLE"']:
            self.assertIn(terrain_marker,vehicles)
        vehicle_resume=locality.split('== "VEHICLE"',1)[1]
        self.assertIn('CortexGroupMove',vehicle_resume)
        self.assertIn('["VEHICLE_WITHDRAW",time+((120-_elapsed) max 3)]',vehicle_resume)
        self.assertIn('[_group,_adopted,"RETREAT","VEHICLE_OWNERSHIP_RESUME",time-_elapsed,true] call WAIT_fnc_CortexSetPhase',vehicle_resume)
        self.assertNotIn('CortexFireCountermeasure',vehicle_resume)
        for marker in [
            'WITHDRAW-MIGRATION-headless-prerequisite',
            'WITHDRAW-MIGRATION-production-start',
            'WITHDRAW-MIGRATION-owner-resume',
            'WITHDRAW-MIGRATION-start-preserved',
            'WITHDRAW-MIGRATION-physical-continuation',
            'WITHDRAW-MIGRATION-no-smoke-replay',
            'WITHDRAW-MIGRATION-crew-retained',
            'WITHDRAW-MIGRATION-zeus-physical-replacement',
            'WITHDRAW-MIGRATION-zeus-no-resurrection',
            'WAIT_fnc_HeadlessMigrateGroup',
            'VEHICLE_OWNERSHIP_RESUME',
        ]:
            self.assertIn(marker,audit)
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('[string]$Focus=\'all\'',launcher)
        self.assertIn('mod_pipeline.py\') stage $Package $runtime --focus $Focus',launcher)
        self.assertIn('"stateflows"',server)

    def test_mounted_survivors_withdraw_instead_of_selecting_impossible_surrender(self):
        morale=source('cortexMorale')
        self.assertIn('private _allOnFoot = _alive findIf {vehicle _x != _x} < 0',morale)
        surrender=morale.split('if (_allOnFoot',1)[1]
        self.assertIn('WAIT_AIPass_Surrender_Enable',surrender)

    def test_replacement_orders_release_owned_garrison_and_defence_holds(self):
        for name,marker in [
            ('cortexDefendRelease','WAIT_AIPass_DefendHolding'),
            ('cortexGarrisonRelease','WAIT_AIPass_GarrisonDisabledPath')]:
            code=source(name)
            self.assertIn(marker,code)
            self.assertIn('toUpperANSI currentCommand _x',code)
            self.assertIn('["","STOP","ATTACK","FIRE","SUPPRESS"]',code)
            self.assertIn('private _externalTakeover = [_group] call WAIT_fnc_CortexExternalTakeover;',code)
            self.assertIn('private _canRestore = _restore && {!_externalTakeover};',code)
            self.assertIn('_canRestore || {!_externalTakeover && {_ownedHold',code)
            for external in ['MOVE','GET IN','GET OUT','ACTION','SCRIPTED']:
                self.assertNotIn(f'"{external}"',code)

    def test_garrison_restores_only_the_speed_lease_it_applied(self):
        apply=source('cortexGarrisonApplyLocal')
        release=source('cortexGarrisonRelease')
        self.assertIn('setVariable ["WAIT_Cortex_GarrisonAppliedSpeed",4]',apply)
        self.assertIn('getForcedSpeed _x == (_x getVariable ["WAIT_Cortex_GarrisonAppliedSpeed",-2])',release)
        self.assertIn('setVariable ["WAIT_Cortex_GarrisonAppliedSpeed",nil]',release)

    def test_vehicle_movement_owns_its_waypoint_until_physical_completion(self):
        vehicles=source('cortexVehicles')
        tick=source('cortexGroupTick')
        restore=source('cortexRestoreCalm')
        self.assertIn('getOrDefault ["movementLease",[]]',vehicles)
        self.assertIn('waypointDescription _x == "WAIT AI PASS"',vehicles)
        self.assertIn('private _movementOwned = _activeVehicleMove',vehicles)
        self.assertIn('if (_enemies isEqualTo []) exitWith {_movementOwned}',vehicles)
        self.assertIn('_state set ["movementLease",["VEHICLE_WITHDRAW",time+120]]',vehicles)
        self.assertIn('_state set ["movementLease",["VEHICLE_STANDOFF",time+60]]',vehicles)
        self.assertIn('if (!_movementOwned && {_state getOrDefault ["phase",""] == "CONTACT"}',vehicles)
        self.assertIn('private _coordinatedOwnsMovement = _vehicleOwnsMovement',tick)
        self.assertIn('!_vehicleOwnsMovement',tick)
        self.assertIn('(_state getOrDefault ["phase",""]) == "CONTACT"',tick)
        self.assertIn('"movementLease"',restore)
        self.assertIn('private _groupMovementOwned = count _movementLease == 2',tick)
        self.assertIn('if (!_groupMovementOwned && {_movementLease isNotEqualTo []})',tick)

    def test_vehicle_combat_layer_preserves_other_movement_owners(self):
        vehicles=source('cortexVehicles')
        self.assertIn('in ["VEHICLE_WITHDRAW","VEHICLE_STANDOFF","VEHICLE_JINK","VEHICLE_ORIENT"]',vehicles)
        self.assertIn('if (_vehicleOwnsLease) then',vehicles)
        self.assertIn('_activeVehicleMove = count _vehicleMove == 2',vehicles)
        non_vehicle=vehicles.split('} else {',1)[1].split('};',1)[0]
        self.assertNotIn('deleteAt "movementLease"',non_vehicle)

    def test_vehicle_gunnery_refreshes_fire_when_contact_was_already_shared(self):
        vehicles=source('cortexVehicles')
        target_change=vehicles.index('if ([] call _mayIssueVehicle && {assignedTarget _gunner != _target}) then {')
        target_change_end=vehicles.index('};',target_change)
        fire=vehicles.index('_gunner doFire _target;',target_change)
        hold=vehicles.index('_gunner setVariable ["WAIT_AIPass_TargetHold", time + 8]',fire)
        self.assertGreater(fire,target_change_end)
        self.assertGreater(hold,fire)

    def test_artillery_scoot_waits_for_and_acquires_shared_movement_ownership(self):
        mission=source('cortexArtilleryMissionStep')
        scoot=source('cortexArtilleryScoot')
        locality=source('cortexLocality')
        tick=source('cortexGroupTick')
        self.assertIn('setVariable ["WAIT_Cortex_ArtilleryScootToken",_scootToken,true]',mission)
        self.assertIn('setVariable ["WAIT_Cortex_ArtilleryScootDeadline",serverTime+120,true]',mission)
        self.assertIn('[_battery,_scootToken] remoteExecCall ["WAIT_fnc_CortexArtilleryScoot", owner _battery]',mission)
        self.assertIn('getVariable ["WAIT_Cortex_ArtilleryScootToken",""] != _token',scoot)
        self.assertIn('if (_busy) exitWith {',scoot)
        self.assertIn('CBA_fnc_waitAndExecute',scoot)
        self.assertIn('_state set ["movementLease",["ARTILLERY_SCOOT",time+120]]',scoot)
        self.assertIn('WAIT_fnc_CortexSelectAvenue',scoot)
        self.assertIn('objNull,"VEHICLE"',scoot)
        self.assertIn('[_vehicle,_scootToken] call WAIT_fnc_CortexArtilleryScoot',locality)
        self.assertLess(locality.index('CortexRestoreCalm'),locality.index('CortexArtilleryScoot'))
        self.assertIn('if (!_groupMovementOwned && {!(_state getOrDefault ["responding", false])',tick)
        self.assertGreaterEqual(tick.count('!_groupMovementOwned'),3)

    def test_support_cleanup_does_not_delete_a_newer_shared_movement_route(self):
        maintain=source('cortexSupportMaintain')
        self.assertIn('private _movementLeaseActive = count _movementLease == 2',maintain)
        self.assertIn('private _supportOwnsMovement = _movementLeaseActive',maintain)
        self.assertIn('["SUPPORT_RALLY","COORDINATED_ASSAULT"]',maintain)
        self.assertIn('if (_operationGeneration >= 0',maintain)
        self.assertIn('&& {(_supportOwnsMovement || {!_movementLeaseActive})}',maintain)
        self.assertIn('if (_supportOwnsMovement) then {_state deleteAt "movementLease"}',maintain)
        self.assertIn('private _operationEndReason=""',maintain)
        self.assertIn('if (_operationState == "STALLED") then {_operationEndReason="NO_PROGRESS"}',maintain)
        self.assertIn('if (_operationEndReason != "") exitWith {',maintain)
        self.assertNotIn('if (_operationState in ["ZEUS","EXTERNAL","LOST_OWNER","REPLACED"]) exitWith {',maintain)

    def test_all_group_manoeuvres_use_one_shared_movement_owner(self):
        tick=source('cortexGroupTick')
        apply=source('cortexSupportApply')
        maintain=source('cortexSupportMaintain')
        end=source('cortexFlankEnd')
        self.assertIn('case "TACTICAL_DRILL"',tick)
        self.assertIn('case "COORDINATED_ASSAULT"',tick)
        for name in ['cortexFlankStart','cortexAdvanceStart']:
            code=source(name)
            self.assertIn('getOrDefault ["movementLease",[]]',code)
            self.assertIn('["lastStep",time]',code)
            self.assertIn('_state set ["movementLease",["TACTICAL_DRILL",time+90]]',code)
        self.assertIn('(_movementLease select 0) == "TACTICAL_DRILL"',end)
        self.assertIn('!_movementLeaseActive || {_supportOwnsMovement} || {_replaceLocalDrill}',apply)
        self.assertIn('_state set ["movementLease",["SUPPORT_RALLY",time+(_expiry-serverTime)]]',apply)
        self.assertIn('_state set ["movementLease",["COORDINATED_ASSAULT",time+(_expiry-serverTime)]]',apply)
        self.assertIn('case "SUPPORT_RALLY"',maintain)

    def test_every_finite_group_move_holds_one_wait_movement_lease(self):
        lease=source('cortexOwnershipLease')
        self.assertIn("WAIT_Cortex_MovementLease",lease)
        self.assertIn("exclusive ownership of the group's WAIT movement domain",lease)
        for name in ['cortexFlankStart','cortexAdvanceStart']:
            code=source(name)
            self.assertIn('[_group,"TACTICAL_DRILL",true,serverTime+90]',code)
            self.assertIn('EXTERNAL_MOVEMENT_BUSY',code)
        step=source('cortexFlankStep')
        end=source('cortexFlankEnd')
        self.assertIn('[_group,"TACTICAL_DRILL",true,serverTime+90]',step)
        self.assertIn('[_group,"TACTICAL_DRILL",false]',end)
        retreat=source('cortexRetreat')
        tick=source('cortexGroupTick')
        self.assertIn('[_group,"INFANTRY_WITHDRAW",true,serverTime+_remainingLease]',retreat)
        self.assertIn('[_group,"INFANTRY_WITHDRAW",false]',tick)
        vehicles=source('cortexVehicles')
        self.assertIn('[_group,"VEHICLE_WITHDRAW",true,serverTime+120]',vehicles)
        self.assertIn('[_group,"VEHICLE_STANDOFF",true,serverTime+60]',vehicles)
        combined=source('cortexCombinedArmsLocal')
        combined_end=source('cortexCombinedGroundStep')
        self.assertIn('[_group,"COMBINED_GROUND",true,_expiry]',combined)
        self.assertIn('[_group,"COMBINED_GROUND",false]',combined_end)
        scoot=source('cortexArtilleryScoot')
        self.assertIn('[_group,"ARTILLERY_SCOOT",true,serverTime+120]',scoot)
        self.assertIn('[_group,_movementOwner,false]',tick)

    def test_tactical_drill_scheduler_silence_restores_owned_ai_state(self):
        step=source('cortexFlankStep')
        tick=source('cortexGroupTick')
        support=source('cortexSupportBoundStart')
        scheduler=source('cortexSchedulerTick')
        end=source('cortexFlankEnd')
        self.assertIn('_drill set ["lastStep",time]',step)
        self.assertIn('_state set ["movementLease",["TACTICAL_DRILL",time+90]]',step)
        self.assertIn('["lastStep",time]',support)
        self.assertIn('time-_lastDrillStep > _drillWatchdog',tick)
        self.assertIn('[_group,_state,"SCHEDULER_STALLED"] call WAIT_fnc_CortexFlankEnd',tick)
        self.assertIn('WAIT_AIPass_ResumeGraceUntil',tick)
        self.assertIn('WAIT_AIPass_ResumeGraceUntil',scheduler)
        self.assertIn('SCHEDULER_STALLED',end)

    def test_finite_tactical_drills_use_one_owner_local_fsm(self):
        launcher=source('cortexDrillStart')
        self.assertIn('!local _group',launcher)
        self.assertIn('execFSM "\\z\\waldo_ai_tweaks\\addons\\main\\fsm\\tacticalDrill.fsm"',launcher)
        self.assertIn('completedFSM _existingHandle',launcher)
        self.assertIn('WAIT_Cortex_DrillFSM',launcher)
        self.assertIn('call WAIT_fnc_CortexQueueJob',launcher)
        for name in ['cortexFlankStart','cortexAdvanceStart','cortexSupportBoundStart']:
            start=source(name)
            self.assertIn('call WAIT_fnc_CortexDrillStart',start)
            self.assertNotIn('WAIT_fnc_CortexFlankStep,',start)
        fsm=(ROOT/'addons/main/fsm/tacticalDrill.fsm').read_text(encoding='utf-8')
        self.assertIn('fsmName = "WAIT finite tactical drill"',fsm)
        self.assertIn('call WAIT_fnc_CortexFlankStep',fsm)
        self.assertIn('!local _group',fsm)
        self.assertIn('_thisFSM',fsm)
        self.assertIn('class SchedulerWatchdog',fsm)
        self.assertIn('""jobKey"",""WAIT_DRILL_""',fsm)
        self.assertIn('_job get ""jobKey""] call WAIT_fnc_CortexQueueJob',fsm)
        self.assertIn('])+15)',fsm)
        self.assertIn('WAIT_Cortex_DrillFSMJob',fsm+source('aiGetDiagnostics'))
        self.assertNotIn('allGroups',fsm)
        self.assertNotIn('allUnits',fsm)

    def test_fsm_interrupts_restore_only_the_matching_operation(self):
        fsm=(ROOT/'addons/main/fsm/tacticalDrill.fsm').read_text()
        self.assertIn('class ZeusPriority',fsm)
        self.assertIn('class ExternalOwnership',fsm)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',fsm)
        self.assertIn('""RELEASE""] call WAIT_fnc_CortexDrillInterrupt',fsm)
        self.assertIn('class Disabled',fsm)
        self.assertIn('isNotEqualTo _zeusToken',fsm)
        self.assertIn('WAIT_AIPass_ZeusWaypoints',fsm)
        self.assertIn('_job set [""cancelled"",true]',fsm)
        self.assertIn('call WAIT_fnc_CortexDrillInterrupt',fsm)
        interrupt=source('cortexDrillInterrupt')
        for guard in ['!local _group', '!= _epoch', '!= _token', '_reason in ["ZEUS","RELEASE"]']:
            self.assertIn(guard,interrupt)
        self.assertIn('call WAIT_fnc_CortexFlankEnd',interrupt)
        self.assertNotIn('doMove',interrupt)
        self.assertNotIn('allGroups',fsm)
        self.assertNotIn('nearEntities',fsm)

    def test_calm_requester_fully_releases_responder_reservation(self):
        tick=source('cortexGroupTick')
        calm=tick.split('case "CALM": {',1)[1].split('if (_visible isNotEqualTo [])',1)[0]
        self.assertIn('remoteExecCall ["WAIT_fnc_CortexSupportAck",2]',calm)
        self.assertIn('["SUPPORT_RALLY","COORDINATED_ASSAULT"]',calm)
        self.assertIn('_state deleteAt "movementLease"',calm)
        for key in ['supportToken','responding','respondingTo','respondUntil','arrivedAt','assaulting']:
            self.assertIn(f'"{key}"',calm)

    def test_live_actor_escape_survives_contact_transition(self):
        tick=source('cortexGroupTick')
        begin=tick.split('private _beginContact = {',1)[1].split('switch (_state get "phase")',1)[0]
        self.assertIn('getVariable ["WAIT_Cortex_ActorMove",[]]',begin)
        self.assertIn('count _actorMove != 3 || {_now >= (_actorMove select 2)}',begin)
        self.assertLess(begin.index('count _actorMove'),begin.index('_x doFollow _leader'))

    def test_post_contact_transitions_do_not_churn_combat_or_actor_moves(self):
        tick=source('cortexGroupTick')
        self.assertIn('private _hasLiveActorMove = {',tick)
        search=tick.split('case "SEARCH": {',1)[1].split('case "REGROUP": {',1)[0]
        self.assertIn('_team select {!(_x call _hasLiveActorMove)}',search)
        regroup=tick.split('case "REGROUP": {',1)[1].split('case "RETREAT": {',1)[0]
        self.assertIn('private _reserved = _members select {_x call _hasLiveActorMove}',regroup)
        self.assertIn('_members - _reserved',regroup)
        self.assertIn('_unit distance2D _leader <= 8',regroup)
        self.assertIn('"consolidationRoutes"',regroup)
        self.assertIn('_unit doMove _target',regroup)
        self.assertIn('_unit distance2D _lastPos >= 2',regroup)
        self.assertIn('_now - _lastProgressAt >= 10',regroup)
        self.assertIn('_retries < 1',regroup)
        self.assertNotIn('"consolidateIssued"',regroup)
        self.assertIn('_reserved isEqualTo []',regroup)
        self.assertNotIn('doTarget objNull',regroup)
        self.assertNotIn('doWatch objNull',regroup)

    def test_known_contact_investigation_has_no_random_idle_gate(self):
        tick=source('cortexGroupTick')
        calm=tick.split('case "CALM": {',1)[1].split('case "INVESTIGATE": {',1)[0]
        known=calm.split('&& {_enemies isNotEqualTo []}',1)[1]
        self.assertNotIn('random 1',known)
        self.assertIn('_investigationPreference > 0',known)
        self.assertIn('_investigationRange',known)
        self.assertIn('(0.5 + 0.5 * _investigationPreference)',calm)
        self.assertLess(known.index('_investigationPreference > 0'),known.index('[_state, "investigate", 120]'))

    def test_runtime_phase_gates_release_active_investigation_and_post_contact_work(self):
        tick=source('cortexGroupTick')
        gates=tick.split('// Runtime switches are authoritative permissions',1)[1].split('// Soldiers holding ground',1)[0]
        self.assertIn('_activePhase == "INVESTIGATE"',gates)
        self.assertIn('WAIT_AIPass_Investigate_Enable',gates)
        for phase in ['SECURITY','SEARCH','REGROUP']:
            self.assertIn(f'"{phase}"',gates)
        self.assertIn('WAIT_AIPass_PostContact_Enable',gates)
        self.assertIn('[_group,_state,true,false,_closedReason] call WAIT_fnc_CortexRestoreCalm',gates)
        self.assertIn('["POSTCONTACT_DISABLED","INVESTIGATION_DISABLED"]',gates)
        self.assertIn('_activePhase = "CALM"',gates)
        restore=source('cortexRestoreCalm')
        self.assertIn('_state getOrDefault ["searchTeam", []]',restore)
        self.assertIn('[_group] call WAIT_fnc_CortexGroupMoveClear',restore)

    def test_calm_handover_reasons_distinguish_completion_control_and_gate_closure(self):
        tick=source('cortexGroupTick')
        for reason in ['INVESTIGATION_GATE_CLOSED','POSTCONTACT_DISABLED','INVESTIGATION_DISABLED',
                       'INVESTIGATION_COMPLETE','INVESTIGATION_TIMEOUT','CONTACT_ENDED',
                       'AUTHORED_ORDER','REGROUP_TIMEOUT','REGROUP_COHESIVE']:
            self.assertIn(f'"{reason}"',tick)
        self.assertIn('"ONBOARD_REPORT_EXPIRED"',source('cortexOnboardContact'))
        self.assertIn('"OWNERSHIP_ADOPTED"',source('cortexLocality'))
        self.assertIn('"CORTEX_STOPPED"',source('cortexStop'))
        self.assertIn('"SURRENDER"',source('cortexSurrender'))
        self.assertIn('"ZEUS_TAKEOVER"',source('cortexZeusMark'))
        lifecycle=(ROOT/'releaseVerificationAndDeployment/cortexQA/runLifecycle.sqf').read_text()
        self.assertIn('LIFE-stop-transition-reason',lifecycle)
        self.assertIn('LIFE-zeus-transition-reason',lifecycle)
        self.assertIn('WAIT_Cortex_PhaseTransition',lifecycle)

    def test_lifecycle_audit_migrates_active_semantic_state_and_yields_to_zeus(self):
        lifecycle=(ROOT/'releaseVerificationAndDeployment/cortexQA/runLifecycle.sqf').read_text()
        for marker in [
            'LIFE-state-investigation-start',
            'LIFE-state-owner-resume',
            'LIFE-state-deadline-preserved',
            'LIFE-state-physical-continuation',
            'LIFE-state-zeus-replacement-arrival',
            'LIFE-state-zeus-no-resurrection',
            'OWNERSHIP_RESUME',
        ]:
            self.assertIn(marker,lifecycle)
        for marker in [
            'LIFE-search-natural-contact',
            'LIFE-search-production-start',
            'LIFE-search-owner-resume',
            'LIFE-search-deadline-preserved',
            'LIFE-search-physical-continuation',
            'LIFE-search-zeus-release',
            'LIFE-retreat-production-start',
            'LIFE-retreat-initial-smoke',
            'LIFE-retreat-owner-resume',
            'LIFE-retreat-start-preserved',
            'LIFE-retreat-physical-continuation',
            'LIFE-retreat-no-smoke-replay',
            'LIFE-retreat-zeus-no-resurrection',
        ]:
            self.assertIn(marker,lifecycle)
        self.assertIn('call WAIT_fnc_CortexRetreat',lifecycle)
        self.assertIn('WAIT_AIPass_AreaReport',lifecycle)

    def test_withdrawal_migration_respects_zeus_and_feature_gates(self):
        locality=source('cortexLocality')
        self.assertIn('WAIT_AIPass_Morale_Enable',locality)
        self.assertIn('WAIT_AIPass_Vehicles_Enable',locality)
        self.assertIn('WAIT_AIPass_VehicleWithdraw_Enable',locality)
        self.assertIn('switch (_withdrawalKind)',locality)
        self.assertIn('!([_group] call WAIT_fnc_CortexZeusHeld)',locality)
        self.assertIn('(_withdrawalIntent select 0) in ["INFANTRY","VEHICLE"]',locality)

    def test_reaction_audit_requires_terminal_retreat_and_surrender_handoffs(self):
        reactions=(ROOT/'releaseVerificationAndDeployment/cortexQA/runReactions.sqf').read_text()
        self.assertIn('SURRENDER-terminal-transition',reactions)
        self.assertIn('RETREAT-regroup-transition',reactions)
        self.assertIn('(_x param [1,""]) == "CONTACT"',reactions)
        self.assertIn('(_x param [3,""]) == "SURRENDER"',reactions)
        self.assertIn('(_x param [1,""]) == "RETREAT"',reactions)
        self.assertIn('(_x param [2,""]) == "REGROUP"',reactions)
        self.assertIn('(_x param [3,""]) == "WITHDRAWAL_COMPLETE"',reactions)

    def test_support_gate_closure_rejects_server_token_and_clears_local_role(self):
        text=source('cortexSupportMaintain')
        release=text.split('private _releaseSupport={',1)[1].split('if (_lease isEqualTo []',1)[0]
        self.assertIn('count _lease == 6',release)
        self.assertIn('_token == (_lease select 0)',release)
        self.assertIn('remoteExecCall ["WAIT_fnc_CortexSupportAck",2]',release)
        for key in ['supportToken','responding','respondingTo','respondUntil','arrivedAt','assaulting']:
            self.assertIn(f'"{key}"',release)
        invalid=text.split('if (_lease isEqualTo []',1)[1].split('if (_state getOrDefault ["assaulting"',1)[0]
        self.assertIn('call _releaseSupport',invalid)
        coordinated=text.split('if (_state getOrDefault ["assaulting"',1)[1].split('// Contact can begin',1)[0]
        self.assertIn('WAIT_AIPass_CoordinatedAssault_Enable',coordinated)
        self.assertIn('call _releaseSupport',coordinated)

    def test_pending_remount_survives_locality_change_without_extending_deadline(self):
        text=source('cortexLocality')
        self.assertIn('private _remountIntent = _group getVariable ["WAIT_Cortex_Remount",[]]',text)
        resume=text.split('// Restore semantic boarding intent',1)[1].split('// Rebuild semantic post-contact intent',1)[0]
        self.assertIn('serverTime < (_remountIntent select 0)',resume)
        self.assertIn('!([_group] call WAIT_fnc_CortexZeusHeld)',resume)
        self.assertIn('assignedVehicle _unit == _vehicle',resume)
        self.assertIn('local _unit',resume)
        self.assertIn('WAIT_AIPass_Vehicles_Enable',resume)
        self.assertIn('WAIT_AIPass_VehicleRemount_Enable',resume)
        self.assertIn('[_remountIntent select 0,+_pendingRemount]',resume)
        self.assertNotIn('serverTime+',resume)

    def test_locality_adoption_rechecks_transition_feature_gates_before_moving(self):
        text=source('cortexLocality')
        resume=text.split('// Rebuild semantic post-contact intent',1)[1].split('// The old owner',1)[0]
        gate=resume.split('private _transitionGateOpen',1)[1].split('if (_transitionGateOpen',1)[0]
        self.assertIn('WAIT_AIPass_Investigate_Enable',gate)
        self.assertIn('WAIT_AIPass_ContactReports_Enable',gate)
        self.assertIn('WAIT_AIPass_Hearing_Enable',gate)
        self.assertIn('WAIT_AIPass_PostContact_Enable',gate)
        self.assertLess(resume.index('if (_transitionGateOpen'),resume.index('doMove'))
        self.assertIn('setVariable ["WAIT_Cortex_TransitionIntent",nil,true]',resume)

    def test_delayed_counterbattery_and_scoot_recheck_live_owner_gates(self):
        counter=source('cortexCounterBattery')
        delayed=counter.split('params ["_vehicle", "_side", "_position", "_generation"]',1)[1]
        self.assertIn('WAIT_AIPass_CounterBattery_Enable',delayed)
        mission=source('cortexArtilleryMissionStep')
        self.assertIn('setVariable ["WAIT_Cortex_ArtilleryScootPurpose",_mission get "purpose",true]',mission)
        scoot=source('cortexArtilleryScoot')
        for item in ['WAIT_Cortex_ArtilleryScootPurpose','WAIT_AIPass_Artillery_Enable',
                     'WAIT_AIPass_CounterBattery_Enable','WAIT_AIPass_Artillery_ShootAndScoot',
                     'WAIT_AIPass_CounterBattery_ShootAndScoot','call _clear; false']:
            self.assertIn(item,scoot)
        self.assertLess(scoot.index('missionNamespace getVariable [_scootSetting,true]'),scoot.index('CortexGroupMove'))

    def test_remnant_regroup_releases_only_its_owned_unit_holds(self):
        regroup=source('cortexRegroupStep')
        finish=regroup.split('private _finish = {',1)[1].split('if (isNull _group',1)[0]
        self.assertIn('_state getOrDefault ["held",[]]',finish)
        self.assertIn('currentCommand _x',finish)
        self.assertIn('["","STOP","ATTACK","FIRE","SUPPRESS"]',finish)
        self.assertIn('_x doFollow (leader group _x)',finish)
        self.assertIn('_state set ["held",+_movers]',regroup)
        self.assertIn('_held deleteAt (_held find _x)',regroup)
        self.assertNotIn('"MOVE"',finish)
        self.assertNotIn('"GET IN"',finish)
        self.assertIn('_group selectLeader (_movers select 0)',regroup)
        self.assertIn('_group move _target',regroup)
        self.assertNotIn('{doStop _x; _x doMove _target} forEach _movers',regroup)

    def test_remnant_regroup_never_replaces_an_external_order_during_cleanup(self):
        regroup=source('cortexRegroupStep')
        guard=regroup.split('private _mayRestoreHeld = {',1)[1].split('private _finish = {',1)[0]
        finish=regroup.split('private _finish = {',1)[1].split('if (isNull _group',1)[0]
        self.assertIn('WAIT_fnc_CortexExternalTakeover',guard)
        self.assertIn('if ([_group] call _mayRestoreHeld) then {',finish)
        self.assertLess(finish.index('if ([_group] call _mayRestoreHeld) then {'),
                        finish.index('_x doFollow (leader group _x)'))
        stalled=regroup.split('if (time - (_state get "lastProgress")',1)[1]
        self.assertLess(stalled.index('if ([_group] call _mayRestoreHeld) then {'),
                        stalled.index('doFollow leader _group'))

    def test_cover_stance_bounds_rays_and_rotates_units(self):
        text=source('cortexStance')
        self.assertIn('{abs speed _unit < 1}',text)
        self.assertIn('if (_sampled >= 2) exitWith {}', text)
        self.assertIn('set ["stanceCursor",(_index+1) mod _count]', text)
        self.assertIn('setVariable ["WAIT_AIPass_StanceAt", _now + 10]', text)
        self.assertEqual(3,text.count('call _blocked;'))

    def test_cover_stance_requires_clearance_above_protection(self):
        text=source('cortexStance')
        self.assertIn('case (_lowBlocked && {!_middleBlocked}): {"MIDDLE"}', text)
        self.assertIn('case ((_lowBlocked || {_middleBlocked}) && {!_highBlocked}): {"UP"}', text)
        self.assertNotIn('case ([0.5] call _blocked): {"DOWN"}', text)
        self.assertIn('default {"AUTO"}', text)

    def test_stance_cleanup_preserves_external_override(self):
        for name in ['cortexRestoreCalm','cortexGroupTick']:
            self.assertIn('if (toUpperANSI (unitPos _x) == (_x getVariable ["WAIT_Cortex_AppliedStance",""])) then {_x setUnitPos "AUTO"}', source(name))
        stance=source('cortexStance')
        self.assertIn('_currentStance != (_unit getVariable ["WAIT_Cortex_AppliedStance",""])', stance)
        self.assertIn('setVariable ["WAIT_Cortex_AppliedStance",_stance,true]', stance)

    def test_support_movement_has_priority_over_new_drills(self):
        for name in ['cortexFlankStart', 'cortexAdvanceStart']:
            text = source(name)
            guard = 'if (_state getOrDefault ["responding", false] || {_state getOrDefault ["assaulting", false]}) exitWith {'
            self.assertIn(guard, text)
            if name == 'cortexFlankStart':
                self.assertIn('SUPPORT_OWNS_MOVEMENT', text)
            self.assertNotIn('_group enableAttack false',text)

    def test_assault_contact_does_not_force_combat_mode(self):
        text = source('cortexGroupTick').split('private _beginContact = {')[1].split('switch (_state get "phase")')[0]
        guard = 'if (!(_state getOrDefault ["assaulting", false]) && {behaviour _leader in ["SAFE", "AWARE"]}) then {'
        self.assertIn(guard, text)
        self.assertLess(text.index(guard), text.index('_group setBehaviour "COMBAT"'))
        self.assertNotIn('disableAI "AUTOCOMBAT"', text)

    def test_stalled_bounds_cannot_complete_or_advance(self):
        text = source('cortexFlankStep')
        move = text.split('case "MOVE":')[1].split('case "PAUSE":')[0]
        self.assertIn('["TIME_LIMIT","STALLED"] select _stalled', move)
        self.assertIn('_result = _reason call _end', move)
        self.assertIn('if (_arrived) then', move)
        self.assertNotIn('if (_arrived ||', move)
        end = source('cortexFlankEnd')
        self.assertIn('if (_reason == "COMPLETE") then', end)
        self.assertIn('WAIT_Cortex_DrillResult', end)

    def test_recovery_cannot_launch_a_one_soldier_bound(self):
        text = source('cortexFlankStep')
        self.assertIn('private _movingAvailable=(_teams select _turn) select {_x in _units};', text)
        self.assertIn('count _movingAvailable < 2 && {count _coverAvailable > 2', text)
        self.assertIn('count _movingAvailable == 1 && {count _coverAvailable == 2}', text)
        self.assertIn('_pendingRecovery isEqualTo []', text)
        self.assertIn('RECOVERY_REINFORCEMENT', text)
        self.assertIn('TEAM_%1_RECOVERY', text)
        self.assertIn('if (_waitForTeam) exitWith {1.5};', text)
        self.assertIn('(_x select 1) >= 1', text)
        self.assertIn('if (_teamRecoveryFailed) exitWith {"RECOVERY_FAILED" call _end};', text)

    def test_manoeuvres_preserve_covering_element_attack_assignment(self):
        for name in ['cortexFlankStart','cortexAdvanceStart','cortexSupportApply','cortexSupportBoundStart']:
            self.assertNotIn('_group enableAttack false',source(name))
        step=source('cortexFlankStep')
        for feature in ['TARGET','AUTOTARGET']:
            self.assertNotIn(f'_unit disableAI "{feature}"',step)
        self.assertNotIn('_unit disableAI "AUTOCOMBAT"',step)
        self.assertNotIn('_unit setCombatBehaviour "AWARE"',step)

    def test_every_ai_setting_has_an_acceptance_case(self):
        import re, json
        data=json.loads((ROOT/'releaseVerificationAndDeployment/cortexQA/coverage.json').read_text(encoding='utf-8'))
        actual=set(re.findall(r'^\s*\["(WAIT_[^"]+)"\s*,',(ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8'),re.M))
        declared=[key for case in data['cases'] for key in case['settings']]
        self.assertEqual(actual,set(declared))
        self.assertEqual(len(declared),len(set(declared)))
        controls=[key for case in data['cases'] for key in case.get('controls',[])]
        self.assertEqual({
            'WAIT_AIPass_Exclude',
            'WAIT_AIPass_Profile',
            'WAIT_HelicopterDeceleration_Exclude',
        },set(controls))
        self.assertEqual(len(controls),len(set(controls)))
        self.assertEqual(len(data['cases']),len({case['id'] for case in data['cases']}))
        for case in data['cases']:
            self.assertTrue(case['setup'] and case['expected'])
            self.assertIn('production_sources',case)
            self.assertNotEqual(case['status'],'passed')

    def test_preflight_runs_before_order_state_changes(self):
        text = source('cortexOrderLocal')
        self.assertLess(text.index('call WAIT_fnc_CortexOrderReason'),text.index('setVariable ["WAIT_AIPass_ZeusWaypoints"'))
        self.assertIn('_oldHold',text)
        self.assertIn('false, clientOwner, "The squad changed owner',text)
    def test_exclude_cleans_all_posted_orders_immediately(self):
        text=source('cortexOrderLocal').split('case "EXCLUDE":')[1].split('case "RETURN":')[0]
        for name in ['ClearRelease','GarrisonRelease','DefendRelease','ReleaseGroup']:
            self.assertIn('WAIT_fnc_Cortex'+name,text)
    def test_no_building_garrison_cannot_report_success(self):
        text=source('cortexGarrison')
        self.assertLess(text.index('Refuse an empty search'),text.index('call WAIT_fnc_CortexClearRelease'))
    def test_explicit_native_order_dispatch_has_no_distance_or_module_selection_gate(self):
        dispatch = source('cortexOrderDispatch')
        local = source('cortexOrderLocal')
        self.assertIn('private _group = _settings getOrDefault ["group", grpNull];', dispatch)
        self.assertIn('remoteExecCall ["WAIT_fnc_CortexOrderLocal", groupOwner _group];', dispatch)
        self.assertNotIn('distance2D', dispatch)
        self.assertNotIn('nearestObjects', dispatch)
        self.assertIn('[_group,_order,_building] call WAIT_fnc_CortexOrderReason', local)
        self.assertIn('if (isNull _group || {!local _group}', local)
        self.assertIn('(units _group) findIf {isPlayer _x}', local)

    def test_cba_is_the_single_authoritative_setting_store(self):
        register = source('aiTweaksRegisterSettings')
        changed = source('aiTweaksSettingChanged')
        tuning = source('cortexTuning')
        self.assertIn('call CBA_fnc_addSetting', register)
        self.assertIn('true, _callback, _activation == "RESTART_REQUIRED"', register)
        self.assertIn('missionNamespace setVariable [_name, _value];', changed)
        self.assertIn('CBA handles callback/JIP replay.', tuning)
        self.assertIn('call CBA_settings_fnc_set', tuning)
        self.assertIn('private _revision = (missionNamespace getVariable ["WAIT_AIPass_SettingsRevision",0])+1;', tuning)
        self.assertNotIn('publicVariable "WAIT_AIPass_Settings', tuning)

    def test_tuning_is_server_validated_and_does_not_accept_client_snapshot_rollback(self):
        tuning = source('cortexTuning')
        self.assertIn('if (!isServer) exitWith {', tuning)
        self.assertIn('remoteExecCall ["WAIT_fnc_CortexTuning", 2];', tuning)
        self.assertIn('only the server or an assigned curator may change it.', tuning)
        self.assertIn('private _spec = [] call WAIT_fnc_CortexTuningSpec;', tuning)
        self.assertIn('_updates pushBack [_variable, _value];', tuning)
        self.assertIn('CBA is the sole effective configuration store.', tuning)
        self.assertNotIn('WAIT_AIPass_SettingsApplied', tuning)
    def test_engine_suite_uses_real_commands_and_ui_handlers(self):
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        client=(ROOT/'releaseVerificationAndDeployment/cortexQA/runClient.sqf').read_text(encoding='utf-8')
        audit_init=(ROOT/'releaseVerificationAndDeployment/auditMission/initServer.sqf').read_text(encoding='utf-8')
        for function in ['CortexOrderDispatch','HeadlessMigrateGroup','SimpleAiConvoy','CortexArtilleryFire']:
            self.assertIn('call WAIT_fnc_'+function,server)
        self.assertIn('addEventHandler ["Fired"',server)
        self.assertIn('CBA_settings_fnc_get',client)
        self.assertNotIn('setVariable ["WAIT_AIPass_Aggression"',client)
        self.assertIn('Waldo_fnc_HeadlessMigrateGroup',audit_init)
        self.assertIn('Engine-only HC transfer',audit_init)

    def test_cortex_exports_have_no_legacy_forwarding_aliases(self):
        import re
        text=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        exports=dict(re.findall(r'class (\w+) \{file = "([^"]+)";',text))
        self.assertFalse([name for name in exports if name.startswith('AIPass')])
        self.assertNotIn('WAIT_fnc_AIPass',text)
        for path in (ROOT/'addons').rglob('*.sqf'):
            self.assertNotIn('WAIT_fnc_AIPass',path.read_text(encoding='utf-8'),path)
    def test_headless_diagnostics_are_read_only_and_bound_their_snapshot(self):
        diagnostics = source('aiGetDiagnostics')
        self.assertIn('if !(isServer) exitWith', diagnostics)
        self.assertIn('private _hcOwners = (entities "HeadlessClient_F") apply {owner _x};', diagnostics)
        self.assertIn('WAIT_AI_LastHeadlessAdoption', diagnostics)
        self.assertIn('WAIT_fnc_CompatibilityHeadlessRecord', diagnostics)
        self.assertIn('select [0,20]', diagnostics)
        self.assertNotIn('setGroupOwner', diagnostics)
        self.assertNotIn('doMove', diagnostics)

    def test_focused_convoy_keeps_contact_scenarios(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertNotIn('if (_focus != "convoy")',text)
        for case in ['AMB-01-real-enemy-fire','AMB-04-pinned-halt','AMB-07-operating-crew']:
            self.assertIn(case,text)
        for suite in ['cortexQACombat.sqf','cortexQAMechanics.sqf']:
            self.assertIn(suite,text)

    def test_garrison_recovery_does_not_require_finished_move(self):
        text=source('cortexGarrisonApplyLocal')
        self.assertIn('time-_lastProgress >= 12',text)
        self.assertIn('_retries < 2',text)
        self.assertIn('_x doMove _target',text)
        self.assertNotIn('_x setDestination',text)
        self.assertIn('private _nextEntry=if (_approach || {_crossing}) then {_entryIndex+1} else {count _entries}',text)
        self.assertIn('private _target = if (_approach) then {_entries select 0} else {_destination}',text)
        self.assertIn('_unit forceSpeed 4',text)
        self.assertIn('_unit setUnitPos "UP"',text)
        self.assertIn('_entries resize ((count _entries) min 4)',text)
        self.assertIn('private _replacementEntries=',text)
        self.assertNotIn('_job set ["deadline",(_job get "deadline") max (time+60)]',text)

    def test_garrison_reuses_and_invalidates_its_local_building_topology(self):
        """Entry anchors should not re-enumerate every room once per defender."""
        text=source('cortexGarrisonApplyLocal')
        self.assertIn('WAIT_Cortex_GarrisonTopology',text)
        self.assertIn('private _buildingTopologyCache=',text)
        self.assertIn('private _cached=_buildingTopologyCache getOrDefault',text)
        self.assertIn('abs ((_cached select 0)-_damage) > 0.05',text)
        self.assertIn('_cached=[_damage,+(_building buildingPos -1)]',text)
        self.assertIn('private _positions=+(_cached select 1)',text)
        self.assertNotIn('if (_openedDoor) then {_route set [3,time]',text)
        self.assertNotIn('unitReady _x',text)

    def test_building_comparison_is_additive_and_measures_arrival(self):
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        self.assertIn('ORD-04b-garrison-arrival',server)
        self.assertIn('DIAG-open-door-garrison',server)
        self.assertIn('cortexQABuildings.sqf',server)
        comparison=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        self.assertIn('_unit distance _target <= 2',comparison)
        for case in ['format ["CLEAR-fresh-%1-accepted"','CLEAR-casualty-order-accepted','CLEAR-door-order-accepted']:
            self.assertIn(case,comparison)
        self.assertNotIn('useBuildingBackend',comparison)
        self.assertNotIn('setPos',comparison)

    def test_consolidation_orders_follow_and_does_not_call_timeout_arrival(self):
        text=source('cortexGroupTick')
        self.assertIn('_x doFollow _leader',text)
        self.assertIn('_state getOrDefault ["consolidationRoutes", createHashMap]',text)
        self.assertIn('_routes set [_key, [_target, getPosATL _unit, _now, 0]]',text)
        self.assertIn('_record set [3, _retries + 1]',text)
        self.assertNotIn('_state set ["consolidateIssued", _now]',text)
        self.assertIn('"consolidationRoutes"',source('cortexRestoreCalm'))
        self.assertIn('["CONSOLIDATING", "INCOMPLETE"] select _expired',text)
        self.assertIn('_gathered == count _members',text)
        self.assertIn('call WAIT_fnc_CortexClearRelease',text)
        self.assertNotIn('distance2D _leader > 60',text)

    def test_bound_progress_uses_its_own_explicit_index(self):
        text=source('cortexFlankStep')
        self.assertNotIn('_units apply {[_x distance2D (_spots select _forEachIndex)',text)
        self.assertIn('{_progress pushBack [_x distance2D (_spots select _forEachIndex),_now,getPosATL _x,_now]} forEach _units',text)

    def test_visual_audit_suites_are_staged_and_dispatched_by_the_standalone_pipeline(self):
        server = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        pipeline = (ROOT / 'releaseVerificationAndDeployment/mod_pipeline.py').read_text(encoding='utf-8')
        self.assertIn("glob('run*.sqf')", pipeline)
        for suite in ['Reactions', 'Support', 'Airborne']:
            self.assertIn('cortexQA' + suite + '.sqf', server)
        for case in ['ORD-04b-garrison-arrival', 'CNV-08-destination-halt', 'AMB-04-pinned-halt', 'ART-04-finite-burst']:
            self.assertIn(case, server)

    def test_convoy_resume_keeps_local_trails_and_does_not_project_recovery(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertIn('["frontTrails", _resumeTrails]',text)
        self.assertIn('["followers", _resumeFollowers]',text)
        self.assertNotIn('_front getPos [_desiredGap',text)
        self.assertNotIn('if (!_contact && {_stretch > 3}) then {_leadLimit = 0}',text)
        matrix=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text()
        for case in ['BASELINE-WHEELED','BASELINE-TRACKED','BASELINE-MIXED','-resume-forward-progress','-resume-no-turnaround','-stop-fraction']:
            self.assertIn(case,matrix)

    def test_infantry_explicit_fire_respects_group_and_unit_roe(self):
        for name in ['cortexFireControl','cortexAntiArmour']:
            text=source(name)
            self.assertIn('combatMode _group in ["YELLOW","RED"]',text)
            self.assertIn('unitCombatMode _x in ["YELLOW","RED"]',text)

    def test_convoy_spacing_does_not_trim_navigation_to_a_short_stop(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        self.assertNotIn('_frontDistance > _desiredGap * 0.7',text)
        self.assertNotIn('_frontDistance < _gap',text)
        self.assertIn('private _limit = (_frontSpeed + (_controlGap-_desiredGap)*0.4) max 0;',text)

    def test_native_convoy_follower_commits_a_trail_destination_between_refreshes(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        native=text.split('if (_native && {_path isNotEqualTo []}) then {',1)[1].split('} else {',1)[0]
        self.assertIn('private _committedDestination=_progress param [5,[]];',native)
        self.assertIn('_committedDestination distance2D _destination > 8',native)
        self.assertNotIn('currentCommand driver _vehicle in ["","STOP"]',native)
        self.assertIn('_progress set [5,+_destination];',native)
        self.assertEqual(native.count('driver _vehicle doMove _destination;'),1)

    def test_steering_convoy_follower_keeps_one_committed_path_between_trail_samples(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        steering=text.split('} else {\n                if (count _path >= 2) then {',1)[1].split('\n            };\n        } else {',1)[0]
        self.assertIn('private _committedPathDestination=_progress param [6,[]];',steering)
        self.assertIn('_committedPathDestination distance2D _pathDestination > 8',steering)
        self.assertIn('_vehicle setDriveOnPath _path;',steering)
        self.assertIn('_progress set [6,+_pathDestination];',steering)
        self.assertNotIn('_path apply {_x + [_limit / 3.6]}',steering)
        self.assertIn('[getPosATL _vehicle, time, -1, _trailBase, 0, [], []]',text)
        self.assertNotIn('_progress = [getPosATL _vehicle, time, _progress select 2, _progress select 3]',text)

    def test_convoy_spacing_cannot_stabilize_a_lateral_wedge(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        self.assertIn('private _controlGap = _gap;',text)
        self.assertIn('_controlGap=(_delta vectorDotProduct _direction) max 0;',text)
        self.assertIn('private _lateralOffset = 0;',text)
        self.assertIn('_lateralOffset > _tolerance',text)
        self.assertIn('_pairGap=(_delta vectorDotProduct _direction) max 0;',text)

    def test_convoy_snapshot_preserves_navigation_before_release(self):
        text=(ROOT/'addons/vehicles/functions/convoySync.sqf').read_text()
        self.assertLess(text.index('private _navigation ='),text.index('[_group, true, _configuration select 7'))
        self.assertIn('_keepCrew isEqualTo (_configuration select 4)',text)
        self.assertIn('setVariable ["WAIT_Convoy_LocalState",_navigation]',text)

    def test_building_clearance_bounds_topology_arrival_checks(self):
        clear=source('cortexClearBuilding')+source('buildingOperationStep')
        self.assertIn('private _visitBudget=(count _positions) min 24;',clear)
        self.assertIn('private _visitCursor=(_job getOrDefault ["visitCursor",0]) mod (count _positions);',clear)
        self.assertIn('_visitIndices pushBackUnique _claimed',clear)
        self.assertIn('} forEach _visitIndices;',clear)
        self.assertIn('} forEach _activeWorkers;',clear)
        self.assertIn('["visitCursor",0]',clear)

    def test_building_clearance_replays_after_a_group_returns_to_a_previous_owner(self):
        discovery=source('cortexDiscover')
        lost_owner=discovery.split('if (!local _group) then {',1)[1].split('};',1)[0]
        self.assertIn('WAIT_AIPass_GarrisonApplied',lost_owner)
        self.assertIn('WAIT_AIPass_DefendApplied',lost_owner)
        self.assertIn('WAIT_AIPass_ClearApplied',lost_owner)
        self.assertIn('WAIT_fnc_CortexClearBuilding',discovery)

    def test_locality_handoff_retires_old_operation_before_semantic_resume(self):
        locality=source('cortexLocality')
        cancellation=locality.split('private _navalIntent',1)[1].split('call WAIT_fnc_CortexHearingLocal',1)[0]
        self.assertIn('private _previousOperation=_group getVariable ["WAIT_Operation",createHashMap];',cancellation)
        self.assertIn('"OWNERSHIP_LOST"] call WAIT_fnc_OperationCancel',cancellation)
        self.assertLess(locality.index('"OWNERSHIP_LOST"] call WAIT_fnc_OperationCancel'),
                        locality.index('[_group,true] call WAIT_fnc_CortexHearingLocal'))

    def test_convoy_uses_the_shared_budgeted_scheduler(self):
        sync=source('convoySync')
        queue=source('convoyOperationQueue')
        step=source('convoyOperationStep')
        scheduler=source('cortexSchedulerTick')
        reconcile=source('schedulerReconcile')
        self.assertNotIn('CBA_fnc_addPerFrameHandler',sync)
        self.assertIn('WAIT_fnc_ConvoyOperationStart',sync)
        self.assertIn('WAIT_fnc_CortexQueueJob',queue)
        self.assertIn('WAIT_Convoy_SchedulerActive',sync)
        self.assertIn('WAIT_fnc_ConvoyTick',step)
        self.assertIn('registryRevision',step)
        self.assertRegex(step, r'(?m)^-1\s*$')
        self.assertIn('case "CONVOY"',scheduler)
        self.assertIn('case "CONVOY"',reconcile)

    def test_convoy_travel_has_one_matching_operation_and_terminal_halt(self):
        tick=source('convoyTick')
        release=source('convoyReleaseLocal')
        eligible=source('cortexIsEligible')
        operation_step=source('operationStep')
        self.assertIn('[_group,"CONVOY",_objective,[],[_objective],"TRAVEL"] call WAIT_fnc_OperationStart',tick)
        self.assertIn('if !([_group,false,false,true] call WAIT_fnc_CortexIsEligible) exitWith',tick)
        self.assertIn('_state set ["ownerSuspended",true]',tick)
        self.assertIn('_group setVariable ["WAIT_Operation",nil,true]',tick)
        self.assertIn('["operationGeneration",_operation getOrDefault ["generation",-1]]',tick)
        self.assertIn('[_group,_operationGeneration,3,120,true] call WAIT_fnc_OperationStep',tick)
        self.assertIn('[_group,_generation,"COMPLETE","ARRIVED"] call WAIT_fnc_OperationRelease',tick)
        self.assertIn('[_group,_generation,_reason] call WAIT_fnc_OperationCancel',tick)
        self.assertIn('[_group,_generation,toUpperANSI _reason] call WAIT_fnc_OperationCancel',release)
        self.assertIn('_allowFeatureOwner',eligible)
        self.assertIn('_allowFeatureOwner',operation_step)
        operation_start=source('operationStart')
        self.assertIn('!([_group,false,false,true] call WAIT_fnc_CortexIsEligible)',operation_start)
        self.assertLess(operation_start.index('CortexIsEligible'),operation_start.index('private _previous'))

    def test_operation_callers_handle_an_unavailable_owner_before_they_issue_work(self):
        callers={
            'cortexAirAttack': 'if (count _operation == 0)',
            'cortexAdvanceStart': 'if (count _operation == 0) exitWith',
            'cortexClearBuilding': 'if (count _operation == 0) exitWith {false}',
            'cortexCombinedArmsLocal': 'if (count _operation == 0) exitWith',
            'cortexFlankStart': 'if (count _operation == 0) exitWith',
            'cortexMedicalStep': 'if (count _operation == 0) exitWith {false}',
            'cortexRetreat': 'if (count _operation == 0) exitWith',
            'cortexSupportApply': 'if (count _operation == 0) exitWith',
            'cortexArtilleryScoot': 'if (count _operation == 0) exitWith',
            'cortexVehicles': 'if (count _operation == 0)',
            'cortexNavalAssault': 'if (count _crewOperationRecord == 0) exitWith {',
        }
        for name,guard in callers.items():
            self.assertIn(guard,source(name),name)
        convoy=source('convoyTick')
        self.assertIn('ownerSuspended',convoy)
        self.assertLess(convoy.index('ownerSuspended'),convoy.index('call WAIT_fnc_OperationStart'))
    def test_vehicle_withdraw_and_standoff_use_finite_operation_generations(self):
        vehicles=source('cortexVehicles')
        self.assertIn('[_group,"VEHICLE_WITHDRAW",_threat,[],[_away],"MOVING"] call WAIT_fnc_OperationStart',vehicles)
        self.assertIn('[_group,"VEHICLE_STANDOFF",_atThreat,[],[_away],"MOVING"] call WAIT_fnc_OperationStart',vehicles)
        self.assertIn('["vehicleOperationGeneration",_operation get "generation"]',vehicles)
        self.assertIn('["VEHICLE_MOVE_NO_ARRIVAL","OBJECTIVE_REACHED"] select _arrived',vehicles)
        self.assertIn('vehicle _anchor distance2D _position',vehicles)
        self.assertIn('["MOVEMENT_NO_ARRIVAL","OBJECTIVE_REACHED"] select _arrived',source('cortexGroupTick'))
        self.assertIn('_state deleteAt "vehicleOperationGeneration"',vehicles)

    def test_artillery_scoot_uses_a_finite_operation_and_group_cleanup(self):
        scoot=source('cortexArtilleryScoot')
        tick=source('cortexGroupTick')
        self.assertIn('[_group,"ARTILLERY_SCOOT",_spot,[],[_spot],"MOVING"] call WAIT_fnc_OperationStart',scoot)
        self.assertIn('["artilleryScootOperationGeneration",_operation get "generation"]',scoot)
        self.assertIn('case "ARTILLERY_SCOOT": {"artilleryScootOperationGeneration"};',tick)
        self.assertIn('[_group,_generation,_movementResult,_movementReason] call WAIT_fnc_OperationRelease',tick)

    def test_convoy_recovers_only_the_same_unchanged_final_route(self):
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        for marker in ['WAIT_Convoy_RouteRecovery_Enable','["routeWatch",',
                       'currentWaypoint _group >= count waypoints _group',
                       'waypointPosition _watchedWaypoint distance2D _watchedPosition < 2',
                       '_watchedRadius max 20)+75','_group setCurrentWaypoint _watchedWaypoint',
                       'WAIT_Convoy_RouteRecoveries']:
            self.assertIn(marker,tick)
        recovery=tick.split('private _routeWatch=',1)[1].split('private _routeDone',1)[0]
        for forbidden in ['addWaypoint','deleteWaypoint','setPos','setVelocity','setDamage','setFuel']:
            self.assertNotIn(forbidden,recovery)

    def test_convoy_classifies_a_confirmed_physical_block_without_bypassing_it(self):
        tick=source('convoyTick')
        halt=source('convoyHaltServer')
        registration=source('simpleAiConvoy')
        classifier=tick.split('private _classifyStall = {',1)[1].split('private _vehicles =',1)[0]
        self.assertIn('nearestObjects [_vehicle, ["LandVehicle", "Static"], 20, true]',classifier)
        self.assertIn('!(_candidate in _registered)',classifier)
        self.assertIn('["STALLED", "OBSTRUCTION"] select',classifier)
        for forbidden in ['doMove','doFollow','setDriveOnPath','setPos','setVelocity','setDamage','setFuel']:
            self.assertNotIn(forbidden,classifier)
        self.assertIn('([_lead] call _classifyStall)',tick)
        self.assertIn('([_vehicle] call _classifyStall)',tick)
        self.assertIn('"OBSTRUCTION"',halt)
        self.assertIn('"OBSTRUCTION"',registration)
        self.assertIn('_reason in ["STALLED", "OBSTRUCTION"]',registration)

    def test_convoy_owns_eligible_driving_and_releases_for_real_takeover(self):
        start=(ROOT/'addons/vehicles/functions/simpleAiConvoy.sqf').read_text(encoding='utf-8')
        release=(ROOT/'addons/vehicles/functions/convoyReleaseLocal.sqf').read_text(encoding='utf-8')
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        for forbidden in ['drivingBackend','HBQAD_Pause','HBQAD_PreventDisembark','CompatibilityState']:
            self.assertNotIn(forbidden,start+release+diagnostics)
        self.assertIn('General Driving and Convoy are separate WAIT use cases',start)
        self.assertIn('drivingAssist=%3 routeRecoveryEnabled=%4',diagnostics)
        self.assertIn('WAIT owns eligible convoy movement',diagnostics)
        self.assertIn('never teleports, repairs or ignores a physical roadblock',diagnostics)
        self.assertIn('private _externalCrew',release)
        self.assertIn('[_crewGroup] call WAIT_fnc_CortexExternalTakeover',release)
        self.assertIn('{!_externalCrew}',release)

    def test_convoy_release_does_not_restore_over_an_external_group_owner(self):
        release=source('convoyReleaseLocal')
        self.assertIn('private _externalTakeover = local _group && {',release)
        self.assertIn('private _mayRestoreGroup=local _group && {!_externalTakeover};',release)
        self.assertIn('if (_mayRestoreGroup) then {',release)
        self.assertIn('if (_mayRestoreGroup && {!isNull _driver}',release)
        self.assertLess(release.index('private _mayRestoreGroup='),release.index('setFormation _formation'))

    def test_convoy_speed_restore_is_a_vehicle_scoped_lease(self):
        tick=source('convoyTick')
        crew=source('convoyCrewLocal')
        release=source('convoyReleaseLocal')
        self.assertGreaterEqual(tick.count('setVariable ["WAIT_Convoy_OwnedSpeed",[_group,_revision,_ownedSpeed]]'),3)
        self.assertIn('setVariable ["WAIT_Convoy_OwnedSpeed",[_group,_revision,0]]',crew)
        self.assertIn('private _ownsCurrentSpeed=count _ownedSpeed == 3',release)
        self.assertIn('abs ((getForcedSpeed _vehicle)-(_ownedSpeed select 2)) <= 0.1',release)
        self.assertIn('if (!_externalTakeover && {!_externalCrew} && {!_externalVehicle} && {_ownsCurrentSpeed}) then {',release)
        self.assertIn('if !(_vehicle in _keepCrew) then {',release)
        restore=release.split('if !(_vehicle in _keepCrew) then {',1)[1].split('_vehicle setUnloadInCombat _unload;',1)[0]
        self.assertIn('_vehicle forceSpeed _speed;',restore)
        self.assertNotIn('_vehicle forceSpeed _speed;',release.split('if !(_vehicle in _keepCrew) then {',1)[0])

    def test_convoy_tick_does_not_issue_late_driver_commands_after_external_takeover(self):
        tick=source('convoyTick')
        self.assertIn('private _mayIssueDriving = {',tick)
        self.assertIn('!([_group] call WAIT_fnc_CortexExternalTakeover)',tick)
        self.assertIn('[_group,false,_restore,_registered,"EXTERNAL"] call WAIT_fnc_ConvoyReleaseLocal;',tick)
        for command in ['_lead forceSpeed _ownedSpeed',
                        '(driver _lead) doMove _watchedPosition',
                        'driver _vehicle doMove _destination',
                        '_vehicle setDriveOnPath _path']:
            self.assertLess(tick.rindex('[] call _mayIssueDriving',0,tick.index(command)+len(command)),tick.index(command))

    def test_group_tick_does_not_rejoin_or_search_over_a_new_external_owner(self):
        tick=source('cortexGroupTick')
        self.assertIn('private _mayIssueMovement = {',tick)
        self.assertIn('!([_group] call WAIT_fnc_CortexExternalTakeover)',tick)
        for command in ['{_x doFollow _leader} forEach _rejoin',
                        '{_x doMove (_target getPos [4 + _forEachIndex * 4, random 360])} forEach _team',
                        '{_x doMove (_searchPos getPos [4 + _forEachIndex * 4, random 360])} forEach _team',
                        '_unit doMove _target']:
            self.assertLess(tick.rindex('[] call _mayIssueMovement',0,tick.index(command)+len(command)),tick.index(command))

    def test_vehicle_contact_commands_yield_to_external_owner_at_issue_time(self):
        vehicles=source('cortexVehicles')
        self.assertIn('private _mayIssueVehicle = {',vehicles)
        self.assertIn('!([_group] call WAIT_fnc_CortexExternalTakeover)',vehicles)
        self.assertIn('if !([] call _mayIssueVehicle) exitWith {_movementOwned};',vehicles)
        for command in ['_vehicle forceSpeed 0',
                        'doGetOut _unit',
                        '_gunner doTarget _target',
                        '_gunner doFire _target',
                        '[_group,"VEHICLE_WITHDRAW",true,serverTime+120] call WAIT_fnc_CortexOwnershipLease']:
            self.assertLess(vehicles.rindex('[] call _mayIssueVehicle',0,vehicles.index(command)+len(command)),vehicles.index(command))

    def test_ordinary_vehicle_unload_policy_is_exact_owned_and_restorable(self):
        policy=source('cortexVehicleUnloadPolicy')
        vehicles=source('cortexVehicles')
        release=source('cortexReleaseGroup')
        stop=source('cortexStop')
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class CortexVehicleUnloadPolicy',functions)
        self.assertIn('effectiveCommander _vehicle) in units _group',policy)
        self.assertIn('WAIT_Convoy_Active',policy)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',policy)
        self.assertIn('getUnloadInCombat _vehicle isEqualTo _applied',policy)
        self.assertIn('_vehicle setUnloadInCombat _previous;',policy)
        self.assertIn('WAIT_Cortex_UnloadPolicyBlocked',policy)
        self.assertNotIn('while {',policy)
        self.assertNotIn('spawn',policy)
        self.assertIn('WAIT_AIPass_VehicleDismount_Enable',vehicles)
        self.assertIn('fullCrew [_vehicle,"",false]',vehicles)
        self.assertIn('[_x,_group,"ACQUIRE"] call WAIT_fnc_CortexVehicleUnloadPolicy;',vehicles)
        self.assertIn('[_x,_group,"RELEASE",!_externalTakeover] call WAIT_fnc_CortexVehicleUnloadPolicy;',vehicles)
        self.assertIn('WAIT_Cortex_UnloadPolicyVehicles',release)
        self.assertIn('"RELEASE",!_externalTakeover',release)
        self.assertIn('WAIT_Cortex_UnloadPolicyLease',stop)
        self.assertIn('vehicle-passenger-ownership',diagnostics)
        self.assertIn('blockedExternalMutations=',diagnostics)
        self.assertIn('invalidLeases=',diagnostics)

    def test_ordinary_vehicle_unload_policy_preserves_external_mutation(self):
        policy=source('cortexVehicleUnloadPolicy')
        mutation=policy.split('if (count _lease == 5 && {getUnloadInCombat _vehicle isNotEqualTo (_lease select 3)})',1)[1]
        mutation=mutation.split('if (count _lease == 5) then {',1)[0]
        self.assertIn('WAIT_Cortex_UnloadPolicyLease",nil,true',mutation)
        self.assertIn('WAIT_Cortex_UnloadPolicyBlocked",[_group,_epoch],true',mutation)
        self.assertNotIn('setUnloadInCombat',mutation)

    def test_expired_support_reservation_does_not_restore_attack_over_a_new_owner(self):
        maintain=source('cortexSupportMaintain')
        self.assertIn('private _externalTakeover = [_group] call WAIT_fnc_CortexExternalTakeover;',maintain)
        self.assertIn('private _mayRestoreGroup=!_externalTakeover;',maintain)
        self.assertIn('if (_mayRestoreGroup && {_state getOrDefault ["attackChanged",false]})',maintain)
        self.assertLess(maintain.index('private _mayRestoreGroup='),maintain.index('private _restoreAttack='))

    def test_coordinated_support_exits_before_a_late_external_owner_can_start_or_hold(self):
        """A support callback must retire before allocating a bound or taking PATH from a new owner."""
        maintain=source('cortexSupportMaintain')
        bound=source('cortexSupportBoundStart')
        release=maintain.split('private _releaseSupport={',1)[1].split('private _abort =',1)[0]
        self.assertIn('if (_externalTakeover) exitWith {',release)
        self.assertIn('["EXTERNAL"] call _releaseSupport;',release)
        self.assertLess(release.index('if (_externalTakeover) exitWith {'),maintain.index('doStop _x;'))
        self.assertIn('if ([_group] call WAIT_fnc_CortexExternalTakeover) exitWith {false};',bound)
        self.assertLess(bound.index('CortexExternalTakeover'),bound.index('_state set ["drill",'))

    def test_convoy_driving_assist_is_bounded_and_does_not_take_route_ownership(self):
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        for marker in ['WAIT_Convoy_DrivingAssist_Enable','["roadLookAt",time+3]',
                       'roadsConnectedTo _road','_travel >= 70','["roadAssist",',
                       '["leadSpeedLimit",[_leadLimit,time]]','private _pathTurn=0;',
                       'private _pathGrade=0;']:
            self.assertIn(marker,tick)
        assist=tick.split('// One bounded road walk per convoy',1)[1].split('// During contact',1)[0]
        for forbidden in ['addWaypoint','deleteWaypoint','setCurrentWaypoint','setDriveOnPath',
                          'setPos','setVelocity','setDamage','setFuel']:
            self.assertNotIn(forbidden,assist)
        self.assertLessEqual(assist.count('nearRoads'),1)


    def test_convoy_grade_uses_absolute_elevation_for_roads_and_trails(self):
        tick=source('convoyTick')
        road=tick.split('// One bounded road walk per convoy',1)[1].split('// During contact',1)[0]
        self.assertIn('getPosASL _road',road)
        self.assertIn('getPosASL _nextRoad',road)
        self.assertNotIn('getPosATL',road)
        trail=tick.split('private _pathGrade=0;',1)[1].split('private _pathCap=',1)[0]
        self.assertIn('(ATLToASL _b) select 2',trail)
        self.assertIn('(ATLToASL _c) select 2',trail)
        self.assertIn('abs (_heightC-_heightB)/_segment',trail)

    def test_convoy_matrix_checks_physical_column_and_halt_notifies_curators(self):
        matrix=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text()
        for marker in ['CNVM-terrain-scenario','for "_heading" from 0 to 315 step 45',
                       'for "_along" from -180 to 1000 step 50',
                       '_normal < 0.65','_grade > 0.8','_relief >= 30',
                       'vectorDotProduct _terrainForward','vectorDotProduct _terrainRight',
                       '-single-file']:
            self.assertIn(marker,matrix)
        self.assertIn('_maxLateral <= 8',matrix)
        text=(ROOT/'addons/vehicles/functions/simpleAiConvoy.sqf').read_text()
        self.assertIn('getAssignedCuratorUnit',text)
        self.assertIn('pushBackUnique owner _curator',text)
        self.assertIn('CORTEX CONVOY STOPPED',text)
        self.assertLess(text.index('== "HALT"}) exitWith {true}'),text.index('CORTEX CONVOY STOPPED'))

    def test_convoy_avoidance_audit_uses_route_relative_real_terrain_checks(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoyAvoidance.sqf').read_text()
        for marker in ['private _terrainReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-20,0,20]',
                       'for "_along" from -110 to 650 step 25',
                       '((surfaceNormal _sample) select 2) < 0.65',
                       '_grade > 0.8',
                       '_relief >= 15',
                       'CNV-AVOID-terrain-scenario',
                       'call _terrainPosition',
                       'vectorDotProduct _terrainRight > 15',
                       'vectorDotProduct _terrainForward > _pedestrianAlong+30']:
            self.assertIn(marker,qa)
        self.assertIn('No dry three-lane vehicle corridor',qa)
        self.assertNotIn('getPosATL _man select 0 > 4215',qa)
        self.assertNotIn('getPosATL _lead select 1 > _pedestrianY+30',qa)

    def test_convoy_seat_audit_runs_wheeled_and_tracked_cases_over_real_relief(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoySeats.sqf').read_text()
        for marker in ['private _terrainReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-20,0,20]',
                       'for "_along" from -80 to 2500 step 50',
                       '((surfaceNormal _sample) select 2) < 0.65',
                       '_grade > 0.8',
                       '_relief >= 40',
                       'SEATS-terrain-scenario',
                       'call _terrainPosition',
                       '_v setDir _terrainHeading']:
            self.assertIn(marker,qa)
        self.assertIn('No dry three-lane 2.5 km corridor',qa)
        self.assertIn('["TRACKED-","O_APC_Tracked_02_cannon_F"]',qa)

    def test_remount_retries_physical_boarding_and_cancels_on_contact(self):
        restore=source('cortexRestoreCalm')
        tick=source('cortexGroupTick')
        self.assertIn('[serverTime+60,+_boarding]',restore)
        self.assertIn('serverTime >= _deadline',tick)
        self.assertIn('vehicle (_x select 0) != (_x select 1)',tick)
        self.assertIn('_visible isNotEqualTo [] || {_dangerActive} || {_ordered}',tick)
        self.assertIn('[_unit] orderGetIn false;',tick)
        self.assertIn('unassignVehicle _unit;',tick)
        self.assertNotIn('moveInCargo',tick)

    def test_recovery_halts_preserve_passengers_and_validate_vehicle(self):
        tick=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        halt=(ROOT/'addons/vehicles/functions/convoyHaltServer.sqf').read_text(encoding='utf-8')
        api=(ROOT/'addons/vehicles/functions/simpleAiConvoy.sqf').read_text(encoding='utf-8')
        self.assertEqual(tick.count('if (_attempts > 3)'),2)
        self.assertNotIn('doFollow driver _front',tick)
        self.assertIn('_blockedVehicle in (_configuration select 4)',halt)
        self.assertIn('if !(_reason in ["STALLED", "OBSTRUCTION"]) then',api)
        self.assertIn('"OBSTRUCTION"',halt)
        self.assertNotIn('setPos',tick)
        self.assertNotIn('disableCollisionWith',tick)

    def test_convoy_can_acquire_forward_trail_beyond_initial_capture_radius(self):
        text=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        self.assertIn('if (_nearest < 0)',text)
        self.assertIn('(_delta vectorDotProduct _heading) > _length*0.5',text)
        self.assertIn('_nearest + ([1,0] select _joining)',text)
        self.assertIn('if (count _state > 0 && {!_sameLine})',text)
        self.assertNotIn('driver _lead doMove (waypointPosition',text)

    def test_convoy_retains_actual_seat_for_crew_and_both_cargo_group_layouts(self):
        text=(ROOT/'addons/vehicles/functions/convoyCrewLocal.sqf').read_text(encoding='utf-8')
        self.assertIn('_assignedOccupant != _unit',text)
        for role in ['assignAsDriver','assignAsCommander','assignAsGunner','assignAsCargoIndex','assignAsTurret']:
            self.assertIn(role,text)
        self.assertNotIn('moveIn',text)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runConvoySeats.sqf').read_text(encoding='utf-8')
        self.assertIn('forEach [_convoy,_cargoGroup]',qa)
        self.assertIn('addEventHandler ["GetOutMan"',qa)
        self.assertIn('SEATS-travel-no-exits',qa)
        self.assertIn('SEATS-halt-operating-crew-retained',qa)
        self.assertIn('{deleteVehicle _x} forEach _actors',qa)

    def test_deceleration_old_owner_cannot_clear_new_worker(self):
        base=ROOT/'addons/aircraft/functions'
        init=(base/'helicopterDecelerationInit.sqf').read_text(encoding='utf-8')
        self.assertIn('GenerationLocal",0])+1',init)
        self.assertIn('WAIT_fnc_HelicopterDecelerationStep',init)
        self.assertIn('["subsystem", "AIRCRAFT"]',init)
        self.assertIn('WAIT_Aircraft_DecelerationSchedulerActive',init)
        step=(base/'helicopterDecelerationStep.sqf').read_text(encoding='utf-8')
        self.assertIn("getOrDefault ['generation',-1]",step)
        self.assertIn('WAIT_Cortex_AirAttackJob',step)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',step)
        self.assertNotIn('while {',step)
        self.assertNotIn('uiSleep',step)
        correction=(base/'helicopterDecelerationCorrectLocal.sqf').read_text(encoding='utf-8')
        self.assertIn('["_generation",-1,[0]]',correction)
        self.assertIn('WAIT_Cortex_AirAttackJob',correction)
        cleanup=correction[correction.rindex('if (!isNull _aircraft'):]
        self.assertIn('local _aircraft',cleanup)
        self.assertIn('WAIT_fnc_FlightLeaseRelease',cleanup)
        self.assertIn('WAIT_HelicopterDeceleration_GenerationLocal',correction)
        self.assertIn('== _generation',correction)
        self.assertFalse((base/'helicopterDecelerationTrackLocal.sqf').exists())

    def test_aircraft_scheduler_is_independent_from_tactical_master_gate(self):
        scheduler=source('cortexSchedulerTick')
        reconcile=source('schedulerReconcile')
        callback=source('aiTweaksSettingChanged')
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('WAIT_Aircraft_SchedulerActive',scheduler)
        self.assertIn('case "AIRCRAFT": {"WAIT_Aircraft_SchedulerActive"}',scheduler)
        self.assertIn('case "AIRCRAFT": {_aircraft};',reconcile)
        self.assertIn('if (_subsystem in ["CONVOY", "AIRCRAFT"]) then {_jobPaused=false};',scheduler)
        self.assertIn('!(_subsystem in ["CONVOY", "AIRCRAFT"])',scheduler)
        self.assertIn('find "WAIT_DECEL_" == 0',scheduler)
        self.assertIn('find "WAIT_LANDING_" == 0',scheduler)
        self.assertIn('WAIT_HelicopterDeceleration_GenerationLocal", (_x getVariable',callback)
        self.assertIn('WAIT_Aircraft_DecelerationSchedulerActive", false',callback)
        self.assertIn('WAIT_fnc_SchedulerReconcile',callback)
        self.assertIn('"aircraft-scheduler-health"',diagnostics)
        self.assertIn('serverLocalJobs=%1 landingObservers=%2 decelerationObservers=%3',diagnostics)
        self.assertIn('This owner-local snapshot excludes aircraft currently owned by clients or headless clients',diagnostics)

    def test_landing_tracker_generation_prevents_stale_owner_cleanup(self):
        base=ROOT/'addons/aircraft/functions'
        init=(base/'improvedHelicopterLandingInit.sqf').read_text(encoding='utf-8')
        step=(base/'improvedHelicopterLandingStep.sqf').read_text(encoding='utf-8')
        self.assertIn('TrackerGenerationLocal", 0]) + 1',init)
        self.assertIn('WAIT_fnc_ImprovedHelicopterLandingStep',init)
        self.assertIn('["subsystem", "AIRCRAFT"]',init)
        self.assertIn('WAIT_Aircraft_LandingSchedulerActive',init)
        self.assertIn('getOrDefault ["generation", -1]',step)
        self.assertIn('TrackerGenerationLocal", 0]) != _generation',step)
        self.assertIn('TrackerGenerationLocal", 0]) == _generation',step)
        self.assertNotIn('while {',step)
        self.assertNotIn('uiSleep',step)
        self.assertFalse((base/'improvedHelicopterLandingTrackLocal.sqf').exists())

    def test_air_attack_reads_driver_weapons_outside_turret_inventory(self):
        text=(ROOT/'addons/aircraft/functions/cortexAirAttackPlan.sqf').read_text(encoding='utf-8')
        self.assertIn('(weapons _aircraft)+(_aircraft weaponsTurret [-1])',text)
        self.assertIn('_driverWeapons arrayIntersect _driverWeapons',text)
        self.assertIn('private _loadedMagazines=magazinesAllTurrets _aircraft',text)
        self.assertIn('CfgMagazines" >> _loadedMagazine >> "pylonWeapon',text)
        self.assertIn('_pylonWeapon in _stationWeapons',text)
        self.assertIn('forEach _loadedMagazines',text)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text(encoding='utf-8')
        self.assertIn('private _ended=if (!_started) then {false}',qa)
        self.assertNotIn('moveInTurret',qa)
        self.assertNotIn('_airGroup createUnit',qa)

    def test_deceleration_releases_changed_order_before_impulse(self):
        text=(ROOT/'addons/aircraft/functions/helicopterDecelerationCorrectLocal.sqf').read_text(encoding='utf-8')
        for marker in ['waypointPosition _wp','waypointType _wp','waypointScript _wp','waypointSpeed _wp',
                       'currentPilot _aircraft == _entryPilot','WAIT_fnc_CortexExternalTakeover','ORDER_CHANGED']:
            self.assertIn(marker,text)
        self.assertIn('&& {call _ownsOrder}',text)
        self.assertLess(text.index('&& {call _ownsOrder}'),text.index('_aircraft addForce'))

    def test_aircraft_controllers_yield_to_full_takeover_before_flight_writes(self):
        helper=source('cortexExternalTakeover')
        for marker in ['remoteControlled _x','bis_fnc_moduleRemoteControl_owner']:
            self.assertIn(marker,helper)
        deceleration=(ROOT/'addons/aircraft/functions/helicopterDecelerationStep.sqf').read_text(encoding='utf-8')
        correction=(ROOT/'addons/aircraft/functions/helicopterDecelerationCorrectLocal.sqf').read_text(encoding='utf-8')
        landing=(ROOT/'addons/aircraft/functions/improvedHelicopterLandingExecuteLocal.sqf').read_text(encoding='utf-8')
        self.assertIn('WAIT_fnc_CortexExternalTakeover',deceleration)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',correction)
        self.assertGreaterEqual(landing.count('WAIT_fnc_CortexExternalTakeover'),2)
        final=landing.split('actual mutation boundary',1)[1]
        self.assertLess(final.index('WAIT_fnc_CortexExternalTakeover'),final.index('setVectorDirAndUp'))
        anchor=(ROOT/'addons/aircraft/functions/improvedHelicopterLandingAnchorLocal.sqf').read_text(encoding='utf-8')
        self.assertGreaterEqual(anchor.count('WAIT_fnc_CortexExternalTakeover'),2)
        self.assertLess(anchor.index('WAIT_fnc_CortexExternalTakeover', anchor.index('EXTERNAL_REPOSITION')),anchor.index('_helicopter addForce'))
        airborne=source('cortexAirborneCheck')
        self.assertLess(airborne.index('WAIT_fnc_CortexExternalTakeover'),airborne.index('_aircraft flyInHeight'))
        eligible=source('cortexAircraftEligible')
        self.assertIn('WAIT_fnc_CortexExternalTakeover',eligible)

    def test_deceleration_impulse_uses_elapsed_simulation_time(self):
        text=(ROOT/'addons/aircraft/functions/helicopterDecelerationCorrectLocal.sqf').read_text(encoding='utf-8')
        self.assertIn('time - _lastImpulseTime',text)
        self.assertIn('min 0.1',text)
        self.assertIn('min ((_climbRate - _maximumClimbRate) max 0)',text)
        self.assertNotIn('_acceleration * _interval',text)

    def test_deceleration_observes_before_braking_order(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDeceleration.sqf').read_text(encoding='utf-8')
        self.assertLess(text.index('private _startSpeed=abs speed'), text.index('_wp setWaypointPosition'))
        self.assertLess(text.index('_id+": braking"'), text.index('private _startSpeed=abs speed'))
        for name in ['helicopterDecelerationStep','helicopterDecelerationCorrectLocal']:
            code=next((ROOT/'addons').rglob(name+'.sqf')).read_text(encoding='utf-8')
            self.assertIn('WAIT_HelicopterDeceleration_IncludeVTOL',code)

    def test_deceleration_exclusion_uses_a_live_braking_envelope(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runDeceleration.sqf').read_text(encoding='utf-8')
        exclusion=text.split('// A per-aircraft opt-out',1)[1]
        self.assertIn('WAIT_HelicopterDeceleration_Exclude",true,true',exclusion)
        self.assertIn('speed _excludedAircraft >= 120',exclusion)
        self.assertIn('_excludedWp setWaypointSpeed "LIMITED"',exclusion)
        self.assertIn('WAIT_HelicopterDeceleration_Active',exclusion)
        self.assertIn('DECEL-aircraft-exclusion-live-envelope',exclusion)
        self.assertIn('DECEL-aircraft-exclusion-route-preserved',exclusion)

    def test_qa_suites_are_additive_and_staged_by_the_standalone_pipeline(self):
        server = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        pipeline = (ROOT / 'releaseVerificationAndDeployment/mod_pipeline.py').read_text(encoding='utf-8')
        self.assertIn("glob('run*.sqf')", pipeline)
        for name in ['Deceleration', 'Aircraft', 'Lifecycle', 'Coordinated', 'Profiles', 'Scheduler', 'ArtillerySmoke', 'Contact', 'Avoidance', 'Landing', 'Cover', 'Gates', 'Gunnery', 'Seats', 'Buildings', 'ConvoyMatrix', 'Combat', 'Mechanics', 'Reactions', 'Support', 'Airborne', 'Vehicles', 'Fire']:
            self.assertIn('cortexQA' + name + '.sqf', server)
        matrix = (ROOT / 'releaseVerificationAndDeployment/cortexQA/runConvoyMatrix.sqf').read_text(encoding='utf-8')
        self.assertIn('{deleteVehicle (_x select 0)} forEach _fixtureCrew', matrix)
        self.assertIn('-operating-crew-retained', matrix)

    def test_drill_steps_cannot_adopt_a_replacement_action(self):
        step=source('cortexFlankStep')
        self.assertLess(step.index('private _token ='),step.index('private _end ='))
        self.assertIn('_token != (_drill getOrDefault ["token",""])',step)
        for name in ['cortexFlankStart','cortexAdvanceStart']:
            code=source(name)
            self.assertIn('["token",_token]',code)
            self.assertIn('[_group,_token] call WAIT_fnc_CortexDrillStart',code)
            self.assertIn('WAIT_Cortex_DrillSerial',code)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-stale-step-no-mutation',qa)
        self.assertIn('_before isEqualTo _after',qa)

    def test_drill_failure_distinguishes_progress_timeout_and_qa_expiry(self):
        step=source('cortexFlankStep')
        self.assertIn('["TIME_LIMIT","STALLED"] select _stalled',step)
        self.assertIn('(_last select 0)-_remaining >= 0.5',step)
        self.assertIn('WAIT_Cortex_DrillFailure',step)
        self.assertIn('currentCommand _unit,expectedDestination _unit',step)
        self.assertIn('_now-(_last select 3) > _timeout',step)
        self.assertIn('_unit distance2D (_last select 2) >= 0.5',step)
        self.assertNotIn('_combatModes pushBack [_unit,"RED","BLUE"]',step)
        self.assertIn('_group setCombatMode "YELLOW"',step)
        self.assertNotIn('_group setCombatMode "BLUE"',step)
        self.assertNotIn('_unit disableAI "AUTOTARGET"',step)
        self.assertNotIn('_disabled pushBack [_unit,"AUTOTARGET"]',step)
        fire=source('cortexFireControl')
        self.assertIn('private _movingMembers = _eligible arrayIntersect _drillUnits',fire)
        self.assertIn('} forEach _members;',fire)
        self.assertNotIn('} forEach (_members + _movingMembers);',fire)
        self.assertIn('replace their owned LEADER PLANNED destination with native ATTACK pursuit',fire)
        self.assertNotIn('_disabled pushBack [_unit,"TARGET"]',step)
        for capability in ['WEAPONAIM', 'FIREWEAPON']:
            self.assertNotIn(f'_unit disableAI "{capability}"',step)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-observation-completed',qa)
        coordinated=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCoordinated.sqf').read_text()
        for marker in ['COORD-base-actual-supporting-fire','COORD-team-%1-actual-fire','from 0 to 5','from 1 to 5']:
            self.assertIn(marker,coordinated)
        for marker in ['WAIT_fnc_CortexQASetCombatMode','WAIT_CortexQA_CombatModeReceipt',
                       'WAIT_CortexQA_FiredManOwner','COORD-shot-sampler-',
                       'WAIT_Cortex_DrillTransition']:
            self.assertIn(marker,coordinated)
        self.assertNotIn('{_x setCombatMode "RED"} forEach',coordinated)
        self.assertNotIn('private _state=_g getVariable ["WAIT_AIPass_State"',coordinated)

    def test_successive_advance_exchanges_only_after_arrival(self):
        start=source('cortexAdvanceStart')
        step=source('cortexFlankStep')
        self.assertIn('["teams",[_element,_coverElement]]',start)
        self.assertIn('["units", _onFoot]',start)
        self.assertIn('_drill set ["teamTurn",1]',step)
        self.assertIn('if (_arrived) then',step)
        self.assertIn('forEach (_fit - _units)',step)
        self.assertIn('[-8,8] select',step)
        fire=source('cortexFireControl')
        self.assertIn('_drill getOrDefault ["movers",_drill getOrDefault ["units",[]]]',fire)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        for marker in ['-both-elements-bounded','-cover-held-during-bounds','-actual-covering-fire']:
            self.assertIn(marker,qa)

    def test_assault_transition_covers_advance_and_crosses_fixed_objective(self):
        step=source('cortexFlankStep')
        hold=step[step.index('    case "HOLD":'):]
        self.assertNotIn('== "FLANK"',hold.split('private _assault =')[1].split('private _assaultDirection')[0])
        self.assertIn('_enemyPos getPos [20,_crossingDirection]',hold)
        self.assertIn('forEach [0,-15,15,-30,30]',hold)
        self.assertIn('[_centroid,_assaultCandidates,_enemyPos] call WAIT_fnc_CortexSelectAvenue',hold)
        self.assertIn('["assaultObjective",+_enemyPos]',hold)
        self.assertIn('_drill get "assaultDirection"',step)
        self.assertIn('if (_assaulting && {!_assaultEnabled})',step)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-physical-clear-through',qa)
        self.assertIn('vectorDotProduct _forward) < 10',qa)
        self.assertIn('count _clearThroughTeams >= ([1,2] select _advance)',qa)

    def test_assault_frag_is_opportunistic_and_never_blocks_movement(self):
        step=source('cortexFlankStep')
        hold=step[step.index('    case "HOLD":'):]
        self.assertNotIn('"FRAG"',hold)
        self.assertIn('case "ASSAULT": {',step)
        self.assertNotIn('case "GRENADE": {',step)
        self.assertNotIn('"GRENADE_UNRESOLVED" call _end',step)
        self.assertIn('"START","ASSAULT_COMMITTED"] call WAIT_fnc_CortexDrillSetStage',step)
        self.assertNotIn('_drill set ["pauseUntil", _now + 1]',step)
        self.assertIn('_drill set ["pauseUntil",_now]',step)
        self.assertIn('_drill set ["grenadeActionUntil",_now]',step)
        grenade=source('cortexThrowGrenade')
        self.assertIn('addEventHandler ["FiredMan"',grenade)
        self.assertIn('removeEventHandler ["FiredMan",_thisEventHandler]',grenade)
        self.assertIn('[_unit,_handler],10',grenade)

    def test_assault_handoffs_issue_movement_without_an_extra_scheduler_turn(self):
        step=source('cortexFlankStep')
        commitment=step.split('"START","ASSAULT_COMMITTED"]')[1].split('} else {')[0]
        self.assertIn('_drill set ["index",count _points-2]',commitment)
        self.assertIn('_drill set ["teamTurn",0]',commitment)
        self.assertIn('call _issue',commitment)
        self.assertNotIn('pauseUntil',commitment)
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-transition-assault-no-idle-turn',qa)
        self.assertIn('_commitIndex+1 < count _caseTransitions',qa)
        approach=step.rsplit('case "ASSAULT": {',1)[1].split('case "CONSOLIDATE":')[0]
        crossing=approach
        self.assertNotIn('if (!_queued) then {',approach)
        self.assertIn('_drill set ["index",(_drill get "index")+1]',crossing)
        self.assertIn('call _issue',crossing)
        self.assertIn('"FRAG"] call WAIT_fnc_CortexThrowGrenade',approach)

    def test_combat_grenade_qa_measures_projectile_and_hold(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        for marker in ['FLANK-GRENADE','-actual-frag-deployed','-grenade-dispatch-observed','-grenade-clear-through',
                       '-transition-grenade-dispatch-no-idle-turn', '_records pushBack [_projectile,time,getPosATL _unit]',
                       'ASSAULT_GRENADE_DISPATCHED']:
            self.assertIn(marker,qa)
        self.assertIn('["WAIT_AIPass_Assault_Enable",_case != "ADVANCE-CLOSE"]',qa)

    def test_manoeuvre_transitions_are_public_bounded_and_audited(self):
        helper=source('cortexDrillSetStage')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text(encoding='utf-8')
        self.assertIn('class CortexDrillSetStage',functions)
        for marker in ['WAIT_Cortex_DrillTransition','WAIT_Cortex_DrillTransitions',
                       'count _history > 64','setVariable ["WAIT_Cortex_DrillTransitions",_history,true]']:
            self.assertIn(marker,helper)
        for name,reason in [('cortexFlankStart','FLANK_ACCEPTED'),
                            ('cortexAdvanceStart','ADVANCE_ACCEPTED'),
                            ('cortexSupportBoundStart','COORDINATED_BOUND_ACCEPTED')]:
            text=source(name)
            self.assertIn('["stage",""]',text.replace(' ',''))
            self.assertIn(reason,text)
            self.assertIn('call WAIT_fnc_CortexDrillSetStage',text)
        self.assertIn('"ENDED",_reason] call WAIT_fnc_CortexDrillSetStage',source('cortexFlankEnd'))
        self.assertNotIn('_drill set ["stage"',source('cortexFlankStep'))
        for marker in ['-transition-start','-transition-move','-transition-ended','-transition-order',
                       '-transition-assault-committed','-transition-clear-through','-transition-grenade-dispatch-no-idle-turn']:
            self.assertIn(marker,qa)

    def test_grenade_dispatch_keeps_listener_cleanup_owned(self):
        self.assertIn('_flight set [4,time]',source('cortexThrowGrenade'))
        self.assertNotIn('((_flight select 4)+8)',source('cortexFlankStep'))
        end=source('cortexFlankEnd')
        self.assertIn('(_flight select 0) == (_drill getOrDefault ["token",""])',end)
        self.assertIn('removeEventHandler ["FiredMan",_handler]',end)

    def test_pending_assault_frag_rechecks_gate_and_migration_retires_listener(self):
        grenade=source('cortexThrowGrenade')
        callback=grenade[grenade.index('params ["_unit", "_muzzle"'):]
        self.assertIn('WAIT_AIPass_Assault_Enable',callback)
        self.assertLess(callback.index('WAIT_AIPass_Assault_Enable'),callback.index('forceWeaponFire'))
        locality=source('cortexLocality')
        self.assertIn('removeEventHandler ["FiredMan",_fragHandler]',locality)
        self.assertLess(locality.index('WAIT_Cortex_FragHandler'),locality.index('if (!_gained'))

    def test_reaction_qa_keeps_previous_cancellations_and_adds_assault_disable(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runReactions.sqf').read_text()
        self.assertIn('["CAPTIVE","ZEUS","DRILL-REPLACED","ASSAULT-DISABLED"]',qa)
        self.assertIn('_shots == 0',qa)
        self.assertIn('_after == _before',qa)
        self.assertIn('["WAIT_AIPass_Assault_Enable",false]',qa)

    def test_multi_withdrawal_audit_uses_separate_measured_terrain_lanes(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runReactions.sqf').read_text()
        for marker in ['private _withdrawTerrainReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-45,0,45]',
                       'for "_along" from -180 to 100 step 20',
                       '_normal < 0.55',
                       '_grade > 0.75',
                       '_relief >= 12',
                       'MULTI-WITHDRAW-terrain-scenario',
                       'call _withdrawPosition',
                       'vectorDotProduct (_withdrawForward vectorMultiply -1)',
                       'MULTI-WITHDRAW-distinct-terrain-lanes']:
            self.assertIn(marker,qa)
        self.assertIn('if (!_withdrawTerrainReady) then {',qa)
        self.assertIn('No dry three-lane corridor',qa)

    def test_support_audit_rotates_hearing_reports_and_reinforcement_over_terrain(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runSupport.sqf').read_text()
        for marker in ['private _terrainReady=worldName == "VR"',
                       'for "_heading" from 0 to 315 step 45',
                       'forEach [-100,0,100]',
                       'for "_along" from -80 to 220 step 20',
                       '((surfaceNormal _sample) select 2) < 0.55',
                       '_grade > 0.75',
                       '_relief >= 12',
                       'SUPPORT-terrain-scenario',
                       'call _terrainPosition',
                       '_wall setDir _terrainHeading']:
            self.assertIn(marker,qa)
        for local in ['[1600,1070,0]','[1600,1190,0]','[1450,1100,0]',
                      '[1500+_i*3,1050,0]','[1600,1290,0]','[1600,1120,0]']:
            self.assertIn('['+local+'] call _terrainPosition',qa)
        self.assertIn('No dry three-lane sector',qa)

    def test_assault_qa_requires_cover_element_to_consolidate_physically(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-physical-consolidation',qa)
        self.assertIn('(_members - _element) apply {[_x,getPosATL _x]}',qa)
        self.assertIn('_x distance2D _clearedObjective > 35',qa)
        self.assertIn('_x distance2D leader _group > 35',qa)
        self.assertIn('(_x select 0) distance2D (_x select 1) < 30',qa)

    def test_flank_consolidates_support_through_existing_movement_job(self):
        step=source('cortexFlankStep')
        self.assertIn('private _allUnits = +_units;',step)
        self.assertIn('private _fit = +_allUnits;',step)
        self.assertLess(step.index('private _allUnits = +_units;'),step.index('private _fit = +_allUnits;'))
        self.assertNotIn('private _fit = +_units;',step)
        self.assertIn('_points pushBack [_rally,"CONSOLIDATE"]',step)
        self.assertIn('_drill set ["units",_allUnits + _support]',step)
        self.assertIn('_teams = [+_allUnits,+_support]',step)
        self.assertIn('_drill set ["teamTurn",1]',step)
        self.assertIn('case "CONSOLIDATE": {',step)
        self.assertIn('_drill set ["finishFlank",true]',step)
        self.assertIn('else {+_centroid}',step)
        self.assertIn('getOrDefault ["consolidating",false]) exitWith {_result = "COMPLETE" call _end}',step)
        self.assertIn('getPos [12,_drill get "assaultDirection"]',step)

    def test_bound_progresses_on_physical_role_quorum_and_recovers_laggards(self):
        step=source('cortexFlankStep')
        self.assertIn('private _minimumArrivals = ((ceil (count _units * 0.6)) max 2) min count _units;',step)
        self.assertIn('private _boundAge = _now - (_drill get "boundStart");',step)
        self.assertIn('private _lateMoverProgressing = _lateMovers findIf',step)
        self.assertIn('_now - ((_progress select _progressIndex) select 3) <= 3',step)
        self.assertIn('_boundAge >= 6',step)
        self.assertIn('!_lateMoverProgressing || {_boundAge >= 12}',step)
        self.assertIn('count _arrivedUnits >= _minimumArrivals',step)
        self.assertIn('private _stragglers = _units - _arrivedUnits;',step)
        self.assertIn('_recovery pushBack [_straggler,0,_now]',step)
        self.assertIn('Bound role complete',step)
        self.assertNotIn('setPos',step)
        self.assertIn('_drill set ["arrivedUnits",[]]',step)
        self.assertIn('if !(_unit in _previousArrivals) then {',step)

    def test_frontage_audit_measures_only_physical_halts_with_two_actor_tolerance(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        measurement=qa.split('// Recovery movement across the scene is not the halt',1)[1].split('if (diag_tickTime >= _nextLog)',1)[0]
        self.assertIn('if (_physicalArrival) then {',measurement)
        self.assertIn('private _minimumWidth = [2.25,3] select (count _moving > 2)',measurement)
        self.assertIn('_width >= _minimumWidth',measurement)

    def test_bound_recovery_preserves_combat_targeting(self):
        step=source('cortexFlankStep')
        recovery=step.split('// Recovery stays in this existing bounded group job',1)[1].split('private _recoverySnapshot',1)[0]
        self.assertIn('_actor doMove _rally',recovery)
        self.assertNotIn('_actor doTarget objNull',recovery)
        self.assertNotIn('_actor doWatch objNull',recovery)

    def test_late_combat_result_preserves_deadline_and_measures_consolidation(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-late-physical-consolidation',qa)
        self.assertIn('_ending = +_lateResult',qa)
        self.assertIn('["LATE: STILL RUNNING","LATE: ENDED"] select _lateEnded',qa)
        self.assertLess(qa.index('-observation-completed'),qa.index('_ending = +_lateResult'))

    def test_grenade_thrower_is_not_retasked_by_fire_or_antiarmour(self):
        for name in ['cortexFireControl','cortexAntiArmour']:
            code=source(name)
            self.assertIn('getOrDefault ["grenadeActionUntil",-1]',code)
            self.assertIn('pushBackUnique (_drill getOrDefault ["grenadeThrower",objNull])',code)

    def test_packaged_audit_skips_lobby_and_assigns_the_observer(self):
        description=(ROOT/'releaseVerificationAndDeployment/auditMission/description.ext').read_text(encoding='utf-8')
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        mission=(ROOT/'releaseVerificationAndDeployment/auditMission/mission.sqm').read_text(encoding='utf-8')
        serverAudit=(ROOT/'releaseVerificationAndDeployment/auditMission/initServer.sqf').read_text(encoding='utf-8')
        self.assertIn('skipLobby=1;',description)
        self.assertIn('player="PLAYER COMMANDER"',mission)
        self.assertIn('addOns[]={"A3_Characters_F","A3_Characters_F_BLUFOR","A3_Map_VR"}',mission)
        self.assertIn('addOnsAuto[]={"A3_Characters_F","A3_Characters_F_BLUFOR","A3_Map_VR"}',mission)
        self.assertIn('_observer assignCurator _curator;',serverAudit)
        self.assertIn('WAIT AUDIT OBSERVER ZEUS READY',serverAudit)
        self.assertIn('skips role selection and assigns the sole observer Zeus slot automatically',launcher)


    def test_combat_mode_fixture_waits_and_reports_expected_and_actual_modes(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('-fixture-combat-mode',qa)
        self.assertLess(qa.index('private _modeReady'),qa.index('private _originalModes'))
        self.assertIn('_members findIf {unitCombatMode _x != _fixtureCombatMode}',qa)
        self.assertIn('_originalModes apply {[netId (_x select 0),_x select 1]}',qa)

    def test_consolidation_handover_requires_support_movement(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('FLANK-ZEUS-CONSOLIDATE',qa)
        self.assertIn('_interruptionActors = +(_live getOrDefault ["movers",[]])',qa)
        self.assertIn('_x in _interruptionActors && {_x distance2D (_origins select _forEachIndex) >= 8}',qa)
        self.assertIn('_stageReady && {_travel}',qa)

    def test_assault_approach_leaves_margin_for_frag_exclusion(self):
        step=source('cortexFlankStep')
        self.assertIn('_enemyPos getPos [20,_crossingDirection+180]',step)
        grenade=source('cortexThrowGrenade')
        self.assertIn('nearEntities ["CAManBase",12]',grenade)

    def test_assault_checks_carriers_across_both_arrived_elements(self):
        step=source('cortexFlankStep')
        assault=step[step.index('case "ASSAULT": {'):step.index('case "CONSOLIDATE": {')]
        self.assertIn('private _throwers = _fit select',assault)
        self.assertIn('call WAIT_fnc_CortexThrowGrenade) exitWith',assault)
        self.assertNotIn('selectRandom',assault)

    def test_advance_grenade_case_requires_first_element_actual_throw(self):
        qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('ADVANCE-GRENADE',qa)
        self.assertIn('_singleCarrier = (_teams select 0) select 0',qa)
        self.assertIn('_unit removeMagazine _x',qa)
        self.assertIn('-first-element-carrier-fired',qa)
        self.assertIn('count (_singleCarrier getVariable ["WAIT_CortexQA_FragShots",[]]) > 0',qa)

    def test_event_jobs_adopt_before_reserving_and_queuing(self):
        for name, reservation in [
            ('cortexRegroupOnKill', '_group setVariable ["WAIT_AIPass_RegroupQueued", true]'),
            ('cortexAirborneCheck', '_aircraft setVariable ["WAIT_AIPass_DropUntil", time + 30')]:
            text = source(name)
            adoption = text.index('[_group,true] call WAIT_fnc_CortexLocality')
            self.assertLess(adoption, text.index(reservation))
            self.assertLess(adoption, text.index('] call WAIT_fnc_CortexQueueJob'))

    def test_airborne_drop_yields_before_each_jump_and_before_post_landing_orders(self):
        step=source('cortexAirborneDropStep')
        self.assertGreaterEqual(step.count('WAIT_fnc_CortexExternalTakeover'),2)
        drop=step.split('if ((_job get "phase") == "DROP") exitWith {',1)[1].split('// LAND',1)[0]
        landing=step.split('// LAND',1)[1]
        self.assertLess(drop.index('WAIT_fnc_CortexExternalTakeover'),drop.index('WAIT_fnc_CortexParachuteJump'))
        self.assertLess(landing.index('WAIT_fnc_CortexExternalTakeover'),landing.index('_group addWaypoint'))

    def test_attack_run_flares_are_separate_gated_owner_job(self):
        text=source('cortexAttackRunFlares')
        for requirement in ['local _aircraft','CortexIsEligible','CortexAircraftEligible','WAIT_Cortex_AttackRunFlares_Enable','isTouchingGround','vectorDotProduct','closest','APPROACH','DEPARTURE','serverTime+30','CortexFireCountermeasure','effectiveCommander _aircraft','gunner _aircraft','commander _aircraft','crew _aircraft','assignedTarget _x']:
            self.assertIn(requirement,text)
        self.assertNotIn('reveal ',text)
        self.assertNotIn('setVelocity',text)
        self.assertNotIn('addWaypoint',text)
        self.assertIn('burstExpires',text)
        self.assertIn('burstNext',text)
        self.assertIn('if ([_aircraft] call WAIT_fnc_CortexFireCountermeasure)',text)
        spec=source('cortexTuningSpec')
        settings=source('aiConfig')
        discover=source('cortexDiscover')
        controller=source('cortexAirAttack')
        self.assertIn('WAIT_Cortex_AttackRunFlares_Enable',spec)
        self.assertIn('WAIT_Cortex_AttackRunFlares_Enable',settings)
        self.assertIn('WAIT_Cortex_AttackRunFlares_Enable',discover)
        self.assertIn('WAIT_Cortex_AttackRunFlares_Enable',controller)
        self.assertIn('CortexFeatureEnabled',discover)
        self.assertIn('CortexFireCountermeasure',controller)

    def test_standoff_release_remains_on_the_inbound_side_of_the_target(self):
        planner=source('cortexAirAttackPlan')
        standoff=planner.split('case "STANDOFF": {',1)[1].split('case "STRAFE": {',1)[0]
        self.assertIn('_attack=[-1800,0] call _point;',standoff)
        self.assertIn('_attack=[-650,0] call _point;',standoff)
        self.assertNotIn('_attack=[1800,0] call _point;',standoff)
        self.assertNotIn('_attack=[650,0] call _point;',standoff)

    def test_fixed_wing_standoff_preserves_its_inbound_release_leg(self):
        controller=source('cortexAirAttack')
        self.assertIn('(_job getOrDefault ["pattern",""]) != "STANDOFF"',controller)
        self.assertIn('Guided stand-off weapons instead retain their',controller)

    def test_standoff_uses_one_guided_release_then_closes_before_overflight(self):
        controller=source('cortexAirAttack')
        self.assertIn('private _standoffPass=(_job getOrDefault ["pattern",""]) == "STANDOFF"',controller)
        self.assertIn('private _desiredShots=if (_standoffPass) then {1}',controller)
        self.assertIn('private _standoffWindowClosed=_standoffPass',controller)
        self.assertIn('private _standoffRange=_aircraft distance _target',controller)
        self.assertIn('_standoffRange <= _standoffMinimumRange+150',controller)
        self.assertIn('_standoffForwardAlignment > 0.75',controller)

    def test_air_attack_counts_only_the_planned_weapon_and_magazine(self):
        controller=source('cortexAirAttack')
        self.assertIn('WAIT_Cortex_AirAttackSelectedWeapon',controller)
        self.assertIn('WAIT_Cortex_AirAttackSelectedMagazine',controller)
        self.assertIn('private _selectedRelease=_weapon == _selectedWeapon',controller)
        self.assertIn('&& {_selectedMagazine != ""} && {_magazine == _selectedMagazine};',controller)
        self.assertIn('if (_selectedRelease) then {',controller)
        self.assertIn('&& {(_x select 0) == _selectedMagazine}',controller)
        self.assertNotIn('(_x select 0) == _selectedMagazine || {(_x select 0) in compatibleMagazines _weapon}',controller)

    def test_adaptive_air_attack_is_bounded_physical_and_zeus_safe(self):
        planner=source('cortexAirAttackPlan')
        for requirement in ['nearTargets ([8000,5000]','select [0,16]','WAIT_Cortex_AirAmmoFacts',
                            'magazinesAllTurrets','airLock','aiAmmoUsageFlags','STANDOFF','OFFSET','HOOK','STRAFE','BOMB','LATERAL',
                            'INTERCEPT','_airToAir','airWeapon','airWeaponTurret','pylonWeapon','hardpoints','indirectHit']:
            self.assertIn(requirement,planner)
        for requirement in ['groundWeapon','groundTurret','_groundCandidates','_hasGun=_groundCandidates findIf {(_x select 4) == "GUN"}','shotbullet','shotshell',
                            'shotrocket','shotmissile','shotbomb','_rocketHint','selectedWeapon','selectedSimulation','selectedWeaponClass',
                            '_simulation in ["shotbullet","shotshell"]',
                            '_simulation in ["shotbullet","shotshell","shotrocket","shotbomb"]']:
            self.assertIn(requirement,planner)
        self.assertIn('private _standoff=_simulation == "shotmissile"',planner)
        self.assertIn('&& {_guidedGround} && {!_antiAir} && {!_bombHint}',planner)
        self.assertIn('_bombHint || {_rocketHint || {_simulation in ["shotbullet","shotshell","shotrocket","shotbomb"]',planner)
        self.assertIn('private _armouredTarget=_targetArmour >= 180',planner)
        self.assertIn('if (_standoffAvailable) then {"STANDOFF"} else {if (_hasRocket) then {"OFFSET"} else {""}}',planner)
        self.assertIn('if (_hasRocket) then {_choices append ["OFFSET",0.18,"HOOK",0.22]}',planner)
        self.assertNotIn('private _hasRunWeapon=_hasGun || {_hasRocket}',planner)
        self.assertNotIn('allUnits',planner)

        self.assertNotIn('nearEntities',planner)
        for requirement in ['fullCrew _aircraft','_aircraft weaponsTurret _turret','_personTurret',
                            'WAIT_Cortex_AirAttackPattern','_lateralTurret','_lateralTurretPath',
                            'toLowerANSI _role in ["gunner","commander","turret"]',
                            'standoffWeapon','WAIT_Cortex_AirStandoffBlockedUntil',
                            '[-1200,750]','[900,750]','[2200,1100]','[-8500,-4500]',
                            '["BOMB",[0.08,0.22] select _armouredTarget]',
                            'private _forwardIngress=(_toIngress vectorDotProduct _deliveryAxis) >= 100',
                            'private _bearingAngle=[22,38] select (_pattern == "HOOK")',
                            'vectorNormalized _toAttack']:
            self.assertIn(requirement,planner)
        self.assertNotIn('private _choices=["STRAFE",0.3,"LATERAL"',planner)
        controller=source('cortexAirAttack')
        for requirement in ['local _aircraft','WAIT_Cortex_AirAttack_Enable','CortexExternalTakeover','CortexZeusHeld',
                            'addEventHandler ["Fired"','ownedWaypointName','setWaypointPosition',
                            'limitSpeed','INGRESS','ATTACK','EGRESS','GROUND_CLEARANCE','EGRESS_NONPROGRESS',
                            'routeSignature','AUTHORED_ROUTE_CHANGED','CortexFireCountermeasure','WAIT_Cortex_AirAttackOutcome',
                            'aimedAtTarget','fireAtTarget','NO_FIRE_SOLUTION','attackStartedAt',
                            'stageBestDistance','stageProgressAt','INGRESS_NONPROGRESS','ATTACK_NONPROGRESS',
                            'weaponDirection _weapon','WAIT_Cortex_AirFireSolution','private _validSolution=',
                            '_range >= _minimumRange','private _nativeFixedBasket=']:
            self.assertIn(requirement,controller)
        self.assertNotIn('_pilot doMove _destination',controller)
        self.assertNotIn('_pilot commandMove _destination',controller)
        self.assertNotIn('_pilot setDestination [_destination',controller)
        self.assertIn('waypoints _group apply {[waypointPosition _x,waypointType _x]}',controller)
        self.assertNotIn('[count waypoints _group,_waypointIndex,_resumePosition',controller)
        self.assertIn('private _target=_job getOrDefault ["target",objNull]',controller)
        self.assertIn('private _leadSeconds=[16,5] select (_stage == "ATTACK")',controller)
        self.assertIn('private _nativeAttackWaypoint=_isPlane && {_stage == "ATTACK"}',controller)
        self.assertIn('_job getOrDefault ["selectedWeapon",""]',controller)
        self.assertIn('format ["WAIT_AIR_%1",_plan get "token"]',controller)
        self.assertNotIn('WAIT_CORTEX_AIR_',controller)
        self.assertIn('_job set ["groundWeapon",_plan getOrDefault ["groundWeapon",""]]',controller)
        self.assertIn('_job set ["groundTurret",_plan getOrDefault ["groundTurret",[]]]',controller)
        self.assertIn('_isPlane && {speed _aircraft < 40}',controller)
        self.assertIn('serverTime+0.8+random 0.8',controller)
        self.assertIn('flareINGRESS',controller)
        self.assertIn('flareEGRESS',controller)
        self.assertIn('private _captureRadii=_job getOrDefault',controller)
        self.assertIn('private _captureRadius=_captureRadii select _stageIndex',controller)
        for profile in ['stageAltitudes','stageSpeeds','captureRadii','attackMinimum']:
            self.assertIn(profile,planner)
            self.assertIn(profile,controller)
        self.assertIn('private _deliveryAltitude=600+random 100',planner)
        self.assertIn('private _deliveryAltitude=620+random 80',planner)
        self.assertIn('private _deliveryAltitude=650+random 90',planner)
        self.assertIn('private _approachAltitude=_deliveryAltitude+550',planner)
        self.assertIn('vectorAdd (velocity _aircraft)',controller)
        self.assertIn('private _launchAlignment=',controller)
        self.assertIn('private _bombImpactError=',controller)
        self.assertIn('_bombImpactError <= 55',controller)
        self.assertIn('private _deliveryTerrainClear=_job getOrDefault ["terrainViable",true]',controller)
        self.assertNotIn('private _terminalAssist=',controller)
        self.assertNotIn('_aircraft setVectorDirAndUp',controller)
        self.assertIn('configFile >> "CfgAmmo" >> _ammoClass >> "airFriction"',controller)
        self.assertIn('for "_integrationIndex" from 0 to 119',controller)
        self.assertIn('private _integrationPosition=getPosASL _aircraft',controller)
        self.assertIn('private _targetAltitude=aimPos _target select 2',controller)
        self.assertNotIn('private _integrationPosition=getPosATL _aircraft',controller)
        self.assertIn('_job getOrDefault ["deliveryAssistSamples",[]]',controller)
        self.assertIn('_job getOrDefault ["deliveryAssistActive",false],_deliveryTerrainClear',controller)
        self.assertNotIn('_aircraft setVelocity ',controller)
        self.assertNotIn('_aircraft setPos',controller)
        self.assertIn('private _minimumTerrainClearance=[45,300] select _isPlane',planner)
        self.assertIn('for "_legIndex" from 0 to 2',planner)
        self.assertIn('private _sampleSteps=((ceil (_legLength/300)) max 6) min 36',planner)
        self.assertIn('for "_sampleIndex" from ([1,0] select !_joinLeg) to _sampleSteps',planner)
        self.assertIn('forEach [-_terrainCorridor,0,_terrainCorridor]',planner)
        self.assertIn('private _terrainASL=getTerrainHeightASL _samplePoint',planner)
        self.assertIn('private _terrainRequiredLift=0;',planner)
        self.assertIn('_terrainViable=_terrainViable && {_terrainRequiredLift <= _terrainLiftLimit}',planner)
        self.assertIn('if (!_terrainViable) exitWith {createHashMap}',planner)
        self.assertIn('private _routePoints=[_airPos,_ingress,_attack,_egress]',planner)
        self.assertIn('private _joinLeg=_legIndex == 0',planner)
        self.assertIn('_joinLeg && {_fraction <= 0.2}',planner)
        self.assertIn('_clearanceDeficit/_fraction',planner)
        self.assertIn('_terrainClearanceSamples pushBack',planner)
        self.assertIn('_terrainLift*(_x select 1)',planner)
        self.assertIn('_stageAltitudes=_stageAltitudes apply {_x+_terrainLift}',planner)
        self.assertIn('["terrainLift",_terrainLift]',planner)
        self.assertIn('["terrainClearanceMinimum",_terrainClearanceMinimum]',planner)
        self.assertIn('["terrainSampleCount",_terrainSampleCount]',planner)
        self.assertIn('["terrainCorridor",_terrainCorridor]',planner)
        self.assertIn('["terrainRequiredLift",_terrainRequiredLift]',planner)
        self.assertIn('["terrainViable",_terrainViable]',planner)
        self.assertIn('_job set ["terrainRequiredLift",_plan getOrDefault',controller)
        self.assertIn('_job getOrDefault ["terrainRequiredLift",0]',controller)
        self.assertIn('["targetPosition",+_targetPos]',planner)
        self.assertIn('private _stagePassed=',controller)
        self.assertIn('private _ingressBehind=',controller)
        self.assertIn('vectorDotProduct (_destination vectorDiff getPosATL _aircraft)',controller)
        self.assertIn('_aircraft distance2D _target <= 9500',controller)
        self.assertIn('_ownedWaypoint setWaypointPosition [getPosATL _target,0]',controller)
        self.assertIn('private _nativeAttackWaypoint=_isPlane && {_stage == "ATTACK"}',controller)
        self.assertIn('setWaypointType "DESTROY"',controller)
        self.assertIn('setWaypointCombatMode "RED"',controller)
        self.assertIn('_ownedWaypoint waypointAttachVehicle _target',controller)
        self.assertIn('_ownedWaypoint waypointAttachVehicle objNull',controller)
        self.assertIn('_job getOrDefault ["airToAir",false]',controller)
        self.assertIn('native attached DESTROY order',controller)
        self.assertNotIn('deliveryCommitted',controller)
        self.assertIn('attackShotBaseline',controller)
        self.assertIn('if (_turret isEqualTo [-1]) then {_pilot}',controller)
        self.assertIn('assignedTarget _x isEqualTo _ownedTarget',controller)
        self.assertIn('_x doTarget objNull',controller)
        self.assertIn('_x doWatch objNull',controller)
        self.assertNotIn('_group reveal [_fireTarget,4]',controller)
        handover_cleanup=controller.split('if (_reason in ["CONTROL_RELEASED","AUTHORED_ROUTE_CHANGED"]) then {',1)[1].split('if (!(_reason in ["CONTROL_RELEASED","AUTHORED_ROUTE_CHANGED"])) then {',1)[0]
        self.assertNotIn('doTarget objNull',handover_cleanup)
        self.assertNotIn('doWatch objNull',handover_cleanup)
        self.assertIn('_operator doFire _fireTarget',controller)
        self.assertNotIn('_operator doFire _target',controller)
        self.assertNotIn('_operator commandTarget _target',controller)
        self.assertLess(
            controller.index('_operator doTarget _fireTarget'),
            controller.index('private _fixedUnguided=_turret isEqualTo [-1]'),
        )
        self.assertIn('_job getOrDefault ["releaseDetail",[]]',controller)
        self.assertIn('getPosATL _aircraft,velocity _aircraft',controller)
        self.assertIn('"vehicleOwner",owner _aircraft,"groupOwner",groupOwner _group',controller)
        self.assertIn('private _effectiveCapture=_captureRadius+([0,150] select !_isPlane)',controller)
        self.assertIn('private _lateralWeaponEntry=!_isPlane',controller)
        self.assertIn('_pattern == "LATERAL" || {_forwardAlignment > 0.35}',controller)
        self.assertIn('_stage != "" || {[_group] call WAIT_fnc_CortexIsEligible}',controller)
        self.assertIn('_aircraft selectWeaponTurret [_weapon,_turret]',controller)
        self.assertIn('!(_job getOrDefault ["weaponSelected",false])',controller)
        self.assertIn('_job set ["weaponSelected",true]',controller)
        self.assertIn('_operator doWatch _fireTarget',controller)
        self.assertIn('private _pilotSurfaceStation=_isPlane && {!_airContact} && {_turret isEqualTo [-1]}',controller)
        target_block=controller.split('if (!isNull _operator && {alive _operator} && {!(_job getOrDefault ["targetCommanded",false])}) then {',1)[1].split('private _range=',1)[0]
        self.assertIn('if (!_pilotSurfaceStation) then {',target_block)
        self.assertNotIn('_aircraft doTarget',target_block)
        self.assertNotIn('_aircraft doWatch',target_block)
        self.assertIn('private _nativeFixedBasket=',controller)
        self.assertIn('private _minimumAim=0;',controller)
        self.assertNotIn('&& {_aimed >= _minimumAim}',controller)
        self.assertIn('_fired=_aircraft fireAtTarget [_fireTarget,_weapon]',controller)
        self.assertIn('private _pilotSurfaceRelease=_pilotSurfaceStation',controller)
        self.assertIn('"NATIVE_PILOT_REQUEST"',controller)
        self.assertNotIn('_operator forceWeaponFire [_weapon,_mode]',controller)
        self.assertIn('private _deliveryPassed=false;',controller)
        self.assertIn('_deliveryAlong >= 350',controller)
        self.assertIn('[_group,_job,"EGRESS","DELIVERY_WINDOW_PASSED"]',controller)
        self.assertIn('_reason="DELIVERY_MISSED"',controller)
        self.assertNotIn('private _nativePlaneDelivery=',controller)
        self.assertIn('if (_validSolution && {!_pilotSurfaceRelease} && {_requestAvailable}',controller)
        self.assertIn('serverTime < _requestAt+3',controller)
        self.assertIn('_requestAttempts < 2',controller)
        self.assertIn('_job set ["fireRequestAttempts",0]',controller)
        self.assertIn('_projectile setMissileTarget [_guidedTarget,true]',controller)
        self.assertIn('_projectile setMissileTargetPos (aimPos _guidedTarget)',controller)
        self.assertIn('[1100,9000,0.97]',controller)
        self.assertIn('selectedWeaponClass",""]) == "GUIDED"',controller)
        self.assertNotIn('selectedSimulation",""]) == "shotmissile"',controller)
        self.assertIn('case "GUN": {0.15+random 0.25}',controller)
        self.assertIn('case "ROCKET": {0.45+random 0.55}',controller)
        self.assertIn('(_x select 0) == _selectedMagazine',controller)
        self.assertIn('_job set ["lateralPilotFeatures",_lateralPilotFeatures]',controller)
        self.assertNotIn('_group enableAttack false',controller)
        self.assertIn('_finishGroup enableAttack (_job getOrDefault ["previousAttackEnabled",true])',controller)
        self.assertIn('case "BOMB"',controller)
        self.assertIn('case "GUN": {120}',controller)
        self.assertIn('case "BOMB": {2}',controller)
        self.assertIn('private _deliveryWindow=switch _weaponClass do',controller)
        self.assertIn('_reason == "DELIVERY_SAFETY_FLOOR") then {120}',controller)
        self.assertIn('private _currentAGL=(getPosATL _aircraft) select 2;',controller)
        self.assertIn('private _verticalSpeed=(velocity _aircraft) select 2;',controller)
        self.assertIn('_lookaheadClearances=[1.5,3] apply',controller)
        self.assertIn('getTerrainHeightASL _futurePosition',controller)
        self.assertIn('selectMin _lookaheadClearances < 120',controller)
        self.assertIn('_aircraft flyInHeight _safeRecoveryHeight',controller)
        self.assertIn('"agl",_currentAGL,"verticalSpeed",_verticalSpeed',controller)
        self.assertIn('"lookaheadClearances",_lookaheadClearances',controller)
        self.assertIn('_job set ["terrainLift",_plan getOrDefault ["terrainLift",0]]',controller)
        self.assertIn('"TARGET_DESTROYED"',controller)
        self.assertIn('_job set ["targetDestroyed",true]',controller)
        self.assertIn('private _liveShots=_aircraft getVariable ["WAIT_Cortex_AirAttackShots",0]',controller)
        self.assertIn('(!isNull _target && {!alive _target}) || {_liveShots > 0}',controller)
        self.assertIn('[_group,_job,"EGRESS","TARGET_DESTROYED"]',controller)
        self.assertIn('if (_reason == "COMPLETE") then {',controller)
        self.assertIn('if (_job getOrDefault ["targetDestroyed",false]) then {',controller)
        discovery=source('cortexDiscover')
        self.assertIn('_pilot nearTargets ([8000,5000] select !(_vehicle isKindOf "Plane"))',discovery)
        self.assertIn('_knownTargets select _knownIndex) param [4,objNull]',discovery)
        self.assertNotIn('_pilot targets [true,[8000,5000]',discovery)
        self.assertNotIn('ACTUAL_FIRE_NONPROGRESS',controller)
        aircraft_qa=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text()
        self.assertIn('private _fixtureStationWeapons={',aircraft_qa)
        self.assertIn('(weapons _aircraft)+(_aircraft weaponsTurret [-1])',aircraft_qa)
        self.assertIn('_pylonWeapon in _stationWeapons',aircraft_qa)
        self.assertIn('"DELIVERY_MISSED"',aircraft_qa)
        self.assertIn('-missed-pass-egresses-without-circle',aircraft_qa)
        self.assertIn('_postPassNet/_postPassTravel >= 0.5',aircraft_qa)
        self.assertIn('private _physicalTransitions=',aircraft_qa)
        self.assertIn('count (_physicalTransitions arrayIntersect _physicalTransitions) >= 2',aircraft_qa)
        self.assertIn('private _releaseWait=[4,20] select',aircraft_qa)
        self.assertIn('_selectedWeaponClass in ["ROCKET","BOMB","GUIDED"]',aircraft_qa)
        self.assertIn('private _selectedMagazine=_initialPlan param [26,""];',aircraft_qa)
        self.assertIn('_id+"-selected-station-loaded"',aircraft_qa)
        self.assertIn('(_x select 0) == _selectedMagazine',aircraft_qa)
        self.assertIn('private _physicalImpact=damage _plannedTargetObject > 0',aircraft_qa)
        self.assertIn('private _plannedTargetObject=_initialPlan param [3,_target]',aircraft_qa)
        self.assertIn('private _terrainLift=_initialPlan param [27,0]',aircraft_qa)
        self.assertIn('private _terrainClearanceMinimum=_initialPlan param [28,0]',aircraft_qa)
        self.assertIn('private _terrainSampleCount=_initialPlan param [29,0]',aircraft_qa)
        self.assertIn('private _terrainCorridor=_initialPlan param [30,0]',aircraft_qa)
        self.assertIn('private _plannedTargetPosition=_initialPlan param [31,getPosATL _target]',aircraft_qa)
        self.assertIn('private _terrainRequiredLift=_initialPlan param [32,0]',aircraft_qa)
        self.assertIn('private _terrainViable=_initialPlan param [33,false]',aircraft_qa)
        self.assertIn('_id+"-ground-target-stationary"',aircraft_qa)
        self.assertIn('_target setPosATL _targetPosition',aircraft_qa)
        self.assertIn('_id+"-terrain-envelope"',aircraft_qa)
        self.assertIn('_id+"-terrain-scenario-relief"',aircraft_qa)
        self.assertIn('worldName == "VR" || {_terrainRelief >= 30}',aircraft_qa)
        self.assertIn('_id+"-terrain-aware-terminal-delivery"',aircraft_qa)
        self.assertIn('_sampleAircraft getVariable ["WAIT_Cortex_AirFireSolution",[]]',aircraft_qa)
        self.assertIn('count _x >= 23 && {_x param [21,false]}',aircraft_qa)
        self.assertNotIn('_solution >= 0.35',controller)
        self.assertIn('WAIT_Cortex_ZeusOrderSnapshot',controller)
        self.assertIn('private _snapshot=',controller)
        self.assertIn('private _handoverWaypoints=waypoints _handoverGroup',controller)
        self.assertIn('_handoverGroup setCurrentWaypoint _authoredWaypoint',controller)
        self.assertNotIn('_handoverGroup setCurrentWaypoint [_handoverGroup,_authoredWaypointOffset]',controller)
        self.assertNotIn('(crew _aircraft) doFollow leader _handoverGroup',controller)
        self.assertNotIn('_handoverPilot commandMove _handoverPosition',controller)
        self.assertNotIn('_handoverPilot setDestination [_handoverPosition',controller)
        self.assertIn('assignedTarget _x isEqualTo _ownedTarget',controller)
        self.assertNotIn('_x commandTarget objNull',controller)
        self.assertNotIn('_handoverPilot doFollow leader _handoverGroup',controller)
        self.assertNotIn('(driver _aircraft) doMove _handoverPosition',controller)
        self.assertNotIn('(crew _aircraft) doFollow leader _group',controller)
        self.assertIn('WAIT_Cortex_AirHandoverLease',controller)
        self.assertIn('private _resumeExternal',controller)
        self.assertIn('[group _x] call WAIT_fnc_CortexExternalTakeover',controller)
        self.assertIn('{!_resumeExternal}',controller)
        self.assertNotIn('private _deadline=serverTime+90',controller)
        self.assertNotIn('_handoverPilot setUnitCombatMode "BLUE"',controller)
        self.assertNotIn('_handoverGroup setBehaviourStrong "CARELESS"',controller)
        self.assertNotIn('_handoverPilot setCombatBehaviour "CARELESS"',controller)
        self.assertIn('_handoverGroup setBehaviourStrong _authoredBehaviour',controller)
        self.assertIn('_handoverGroup setSpeedMode _authoredSpeed',controller)
        self.assertIn('_handoverGroup setCombatMode _authoredCombatMode',controller)
        self.assertIn('(_snapshot param [4,waypointType _authoredWaypoint]) == "MOVE"',controller)
        self.assertIn('_handoverGroup move _handoverPosition',controller)
        self.assertNotIn('_handoverGroup setCombatMode "BLUE"',controller)
        # One native height hint at a real stage transition is permitted because Arma does not use
        # MOVE point Z as a dependable flight profile. Direct handover may clear that persistent
        # hint once from Zeus' selected destination, but must never become a polling controller.
        self.assertEqual(controller.count('_aircraft flyInHeight (_stageAltitudes select _stageIndex)'),1)
        handover=controller.split('if (_reason in ["CONTROL_RELEASED","AUTHORED_ROUTE_CHANGED"]) then {',1)[1].split('// On an ordinary finite end',1)[0]
        self.assertEqual(handover.count('_aircraft flyInHeight'),1)
        self.assertIn('private _handoverHeight=if (count _handoverPosition >= 3',handover)
        self.assertIn('_aircraft flyInHeight [_handoverHeight,false]',handover)
        self.assertNotIn('_aircraft flyInHeight [_handoverHeight,true]',handover)
        self.assertIn('"ZEUS_IMMEDIATE_HANDOVER"',controller)
        self.assertNotIn('_handoverPilot doMove _handoverPosition',controller)
        self.assertNotIn('"FORCE_REPLAN"',controller)
        self.assertNotIn('"FORWARD_IMPULSE"',controller)
        self.assertNotIn('_handoverAircraft setVelocity [',controller)
        self.assertIn('WAIT_Cortex_AirHandoverRecovery',controller)
        self.assertIn('WAIT_Cortex_AirHandoverResult',controller)
        self.assertIn('expectedDestination _handoverPilot',controller)
        self.assertNotIn('"ZEUS_TRANSIT_GUARD"',controller)
        self.assertIn('egressStartPosition',controller)
        self.assertIn('private _egressTravel=',controller)
        self.assertIn('private _awayFromTarget=',controller)
        self.assertIn('WAIT_Cortex_AirAttackBlockedUntil',controller)
        self.assertNotIn('createVehicle [_laserClass,getPosATL _target,[],0,"CAN_COLLIDE"]',controller)
        self.assertNotIn('_guidanceTarget attachTo [_target,[0,0,0]]',controller)
        self.assertIn('_job set ["fireTarget",_target]',controller)
        self.assertIn('WAIT_Cortex_AirAttackGuidanceTarget',controller)
        self.assertIn('private _requestPending=',controller)
        self.assertEqual(controller.count('fireAtTarget [_fireTarget,_weapon]'),1)
        self.assertEqual(controller.count('forceWeaponFire [_weapon,_mode]'),0)
        discover=source('cortexDiscover')
        self.assertIn('!(_vehicle isKindOf "Plane") || {speed _vehicle >= 40}',discover)
        self.assertEqual(controller.count('addWaypoint [_destination,0]'),1)
        self.assertEqual(controller.count('deleteWaypoint'),1)
        self.assertIn('setWaypointName _ownedWaypointName',controller)
        self.assertIn('waypointName _x != _ownedWaypointName',controller)
        self.assertIn('format ["AIR_%1",_plan get "pattern"]',controller)
        self.assertIn('call WAIT_fnc_OperationStart',controller)
        self.assertIn('operationGeneration',controller)
        self.assertIn('["ATTACK"] call _setOperationPhase',controller)
        self.assertIn('["EGRESS"] call _setOperationPhase',controller)
        self.assertIn('call WAIT_fnc_OperationRelease',controller)
        self.assertIn('call WAIT_fnc_OperationCancel',controller)
        self.assertNotIn('call WAIT_fnc_OperationStep',controller)
        self.assertIn('WAIT_Cortex_AirAttackJob',discover)
        self.assertIn('WAIT_fnc_AirAttackOperationStart',discover)
        self.assertIn('_pilot nearTargets ([8000,5000] select !(_vehicle isKindOf "Plane"))',discover)
        self.assertIn('["target",_airAttackTarget]',discover)
        self.assertIn('serverTime >= (_vehicle getVariable ["WAIT_Cortex_AirAttackBlockedUntil",0])',discover)
        stop=source('cortexStop')
        for requirement in ['WAIT_Cortex_AirAttackPlan','WAIT_Cortex_AirAttackJob','WAIT_Cortex_AirFireSolution',
                            'WAIT_Cortex_AirAttackTarget','WAIT_Cortex_AirAttackGuidedWeapon',
                            'removeEventHandler ["Fired"','limitSpeed -1','previousAttackEnabled']:
            self.assertIn(requirement,stop)
        spec=source('cortexTuningSpec')
        settings=source('aiConfig')
        self.assertIn('WAIT_Cortex_AirAttack_Enable',spec)
        self.assertIn('WAIT_Cortex_AirAttack_Enable',settings)
        self.assertIn('WAIT_Cortex_AirAttack_Enable',discover)
        self.assertIn('WAIT_Cortex_AirAttack_Enable',controller)
        diagnostics=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text()
        for requirement in ['adaptiveAirAttacks','activeAirAttacks','cortex-air-attack-',
                            'lastCountermeasureRequest','actualShots','observedAA']:
            self.assertIn(requirement,diagnostics)

        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text()
        for requirement in ['AIR-HANDOVER-NATIVE-CONTROL-started',
                            'AIR-HANDOVER-NATIVE-CONTROL-replacement-travel',
                            'AIR-HANDOVER-NATIVE-CONTROL-no-cortex-owner',
                            '-immediate-zeus-handover',
                            '-dedicated-aircraft-owner','WAIT_AIPass_Managed',
                            'WAIT_AIPass_State']:
            self.assertIn(requirement,audit)
        native=audit.split('// Paired native waypoint-replacement control.',1)[1].split(
            '// Adaptive attacks remain separate',1)[0]
        self.assertIn('["WAIT_Cortex_AirAttack_Enable",false]',native)
        self.assertIn('["WAIT_AIPass_Exclude",true,true]',native)
        self.assertIn('distance2D _nativeReplacement <= 350',native)

    def test_air_attack_rechecks_authority_at_native_command_boundaries(self):
        """Planning must not leak one late flight, targeting or fire command after a takeover."""
        controller=source('cortexAirAttack')
        self.assertIn('private _mayControlAircraft = {',controller)
        for boundary in ['_startFailure="CONTROL_RELEASED"',
                         'if (_unsafeDelivery && {!([] call _mayControlAircraft)}) exitWith',
                         'if (_commandedStage != _stage && {!([] call _mayControlAircraft)}) exitWith',
                         'if (_stage == "ATTACK" && {!([] call _mayControlAircraft)}) exitWith']:
            self.assertIn(boundary,controller)
        self.assertLess(controller.index('private _mayControlAircraft = {'),controller.index('_aircraft limitSpeed (_stageSpeeds select _stageIndex);'))
        self.assertLess(controller.index('if (_commandedStage != _stage && {!([] call _mayControlAircraft)}) exitWith'),controller.index('_aircraft limitSpeed (_stageSpeeds select _stageIndex);'))
        self.assertLess(controller.index('if (_stage == "ATTACK" && {!([] call _mayControlAircraft)}) exitWith'),controller.index('_aircraft fireAtTarget'))

    def test_aircraft_crew_never_acquire_generic_group_ownership(self):
        eligibility=source('cortexIsEligible')
        self.assertIn('["_allowFeatureOwner",false,[true]]',eligibility)
        self.assertIn('_groundPass && {_alive findIf',eligibility)
        self.assertIn('_vehicle isKindOf "Air"',eligibility)
        discover=source('cortexDiscover')
        self.assertIn('private _groundEligible = [_group,false,true] call WAIT_fnc_CortexIsEligible',discover)
        self.assertIn('[_group,true,"AIRCRAFT_DEDICATED"] call WAIT_fnc_CortexReleaseGroup',discover)
        self.assertIn('private _eligible = _groundEligible',discover)
        tick=source('cortexGroupTick')
        self.assertIn('private _groundPassEligible=[_group,false,true] call WAIT_fnc_CortexIsEligible',tick)
        self.assertIn('[_group,true,"AIRCRAFT_DEDICATED"] call WAIT_fnc_CortexReleaseGroup',tick)
        locality=source('cortexLocality')
        air_guard=locality.split('call WAIT_fnc_CortexRestoreCalm;',1)[1].split('// A delegated building task',1)[0]
        self.assertIn('vehicle _x isKindOf "Air"',air_guard)
        self.assertIn('exitWith {}',air_guard)

    def test_cortex_air_leases_exclude_other_flight_controllers(self):
        for name in ['helicopterDecelerationCorrectLocal','improvedHelicopterLandingExecuteLocal']:
            path = next((ROOT/'addons').rglob(name+'.sqf'))
            text=path.read_text(encoding='utf-8')
            self.assertIn('WAIT_fnc_FlightLeaseAcquire',text,name)
            self.assertIn('WAIT_fnc_FlightLeaseValid',text,name)

    def test_direct_zeus_aircraft_orders_exclude_auxiliary_flight_controllers(self):
        for name in ['helicopterDecelerationStep','helicopterDecelerationCorrectLocal',
                     'improvedHelicopterLandingStep','improvedHelicopterLandingExecuteLocal']:
            path = next((ROOT/'addons').rglob(name+'.sqf'))
            text=path.read_text(encoding='utf-8')
            self.assertTrue(
                'WAIT_fnc_CortexZeusHeld' in text or 'WAIT_fnc_CortexExternalTakeover' in text,
                name
            )

    def test_attack_run_flare_jobs_are_not_queued_for_ineligible_aircraft(self):
        discover=source('cortexDiscover')
        block=discover.split('private _attackFlareEligible',1)[1].split('if (_attackFlareEligible',1)[0]
        for requirement in ['!isNull _pilot','alive _pilot','!isPlayer _pilot','!unitIsUAV _vehicle',
                            'WAIT_Cortex_AttackRunFlares_Enable','CortexFeatureEnabled',
                            'CortexIsEligible','CortexAircraftEligible']:
            self.assertIn(requirement,block)

    def test_delayed_missile_flare_bursts_are_generation_owned(self):
        discover=source('cortexDiscover')
        defence=source('cortexMissileDefenceStep')
        for requirement in ['WAIT_Cortex_FlareBurstGeneration',
                            'WAIT_Cortex_MissileDefenceActive',
                            'WAIT_Cortex_LastIncomingMissile',
                            'WAIT_fnc_CortexMissileDefenceStep',
                            'WAIT_fnc_CortexQueueJob']:
            self.assertIn(requirement,discover)
        for requirement in ['params [["_state",createHashMap,[createHashMap]]]',
                            '!= _generation',
                            '_step in [0,4]',
                            '!isNull _missile} && {!alive _missile',
                            '_step >= 12',
                            '_aircraft setVelocityModelSpace _candidate']:
            self.assertIn(requirement,defence)
        self.assertNotIn(' spawn ',discover)
        self.assertNotIn(' sleep ',discover)
        stop=source('cortexStop')
        self.assertIn('WAIT_Cortex_FlareBurstGeneration',stop)
        self.assertIn('WAIT_Cortex_MissileDefenceActive',stop)
        self.assertLess(stop.index('WAIT_Cortex_FlareBurstGeneration'),
                        stop.index('WAIT_AIPass_FlaresHandler", nil'))

    def test_keyed_scheduler_jobs_coalesce_only_when_the_caller_requests_it(self):
        queue=source('cortexQueueJob')
        self.assertIn('["_jobKey", "", [""]]',queue)
        self.assertIn('if (_jobKey == "") then {_jobKey = _state getOrDefault ["jobKey", ""]}',queue)
        self.assertIn('if (_jobKey != "") then {',queue)
        self.assertIn('WAIT_AIPass_Jobs',queue)
        self.assertIn('WAIT_AIPass_PendingJobs',queue)
        self.assertIn('_existingState set ["wakeAt", _dueAt]',queue)
        self.assertIn('_pending pushBack [_dueAt, _job, _state]',queue)

    def test_attack_flare_audit_preserves_missile_cases_and_uses_real_flight(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text()
        for item in ['AIR-paired-real-threats','AIR-real-firing-solution','AIR-real-missile-fired',
                     'AIR-real-missile-warning','AIR-cortex-defeats-guided-threat',
                     'O_Heli_Attack_02_dynamicLoadout_F','O_Plane_CAS_02_dynamicLoadout_F',
                     '-moving-airborne-precondition','setVelocityModelSpace','-physical-flight',
                     '-approach-release','-departure-release','-ammunition-consumed','-no-cortex-release',
                     'addEventHandler ["Fired"','_group reveal [_target,4]']:
            self.assertIn(item,text)
        self.assertIn('["WAIT_Cortex_AirAttack_Enable",false]',text)
        self.assertNotIn('call WAIT_fnc_CortexAttackRunFlares',text)
        self.assertNotIn('call WAIT_fnc_CortexFireCountermeasure',text)
        stop=source('cortexStop')
        self.assertLess(stop.index('WAIT_Cortex_AttackFlareJob'),stop.index('if (!isNull _group) then',stop.index('private _jobs')))

    def test_air_attack_audit_proves_patterns_fire_flares_and_handover(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text()
        for item in ['AIR-ATTACK-HELI-LATERAL','AIR-ATTACK-PLANE-STRAFE','AIR-ATTACK-PLANE-OFFSET',
                     'AIR-ATTACK-PLANE-HOOK','AIR-ATTACK-PLANE-AA','AIR-ATTACK-PLANE-INTERCEPT',
                     'AIR-ATTACK-PLANE-BOMB','AIR-ATTACK-PLANE-GUIDED','-target-destroyed',
                     '-armed-live-operator','-damageable-target-prerequisite',
                     '-fixture-armed-preflight','private _loadedStations=','private _fixtureArmed=',
                     'AIR-ATTACK-ZEUS-HANDOVER','AIR-ATTACK-DISABLED','-air-contact-intercept-plan',
                     '-physical-plan-start','-aa-aware-pattern','-actual-weapon-fire',
                      '-pattern-specific-flight-profile','-delivery-axis-crosses-target',
                      '-safe-flight-envelope','-weapon-matches-manoeuvre','-effective-release',
                      '-physical-profile-change','AIR-ATTACK-distinct-fixed-wing-profiles',
                     '-continuous-useful-flight',
                     '-visible-countermeasures','-safe-crew-egress','CortexZeusMark',
                     'WAIT_CortexQA_AttackStageShots','WAIT_CortexQA_AdaptiveShots",0]) > 0',
                     'WAIT_Cortex_AirAttackBlockedUntil",serverTime+300',
                     '-zeus-snapshot-exact','-zeus-replacement-travel','-no-old-plan-resurrection','-explicit-state-flow',
                     '-explicit-interruption-transition','-pilot-features-restored','-lateral-capable-turret','setVelocityModelSpace']:
            self.assertIn(item,text)
        for item in ['WAIT_Cortex_AirHandoverRecovery','WAIT_ImprovedHelicopterLanding_Active',
                     'WAIT_ImprovedHelicopterLanding_LastResult','WAIT_HelicopterDeceleration_Active',
                     'WAIT_HelicopterDeceleration_LastResult','checkAIFeature _x','unitReady _handoverPilot',
                     'canMove _aircraft','isEngineOn _aircraft','fuel _aircraft','damage _aircraft']:
            self.assertIn(item,text)
        self.assertIn('WAIT_CortexQA_ReleaseSamplesStarted',text)
        self.assertIn('if (!_fixtureArmed) then {_group setVariable ["WAIT_AIPass_Exclude",true,true]}',text)
        self.assertIn('"O_Truck_03_transport_F"',text)
        self.assertNotIn('"O_Quadbike_01_F"',text)
        self.assertIn('[_group,true,_replacementWaypoint select 1] call WAIT_fnc_CortexZeusMark',text)
        self.assertIn('private _replacementWaypoint=_group addWaypoint [_replacement,0]',text)
        self.assertIn('_group setCurrentWaypoint _replacementWaypoint',text)
        self.assertLess(text.index('_group setCurrentWaypoint _replacementWaypoint'),
                        text.index('[_group,true,_replacementWaypoint select 1] call WAIT_fnc_CortexZeusMark'))
        self.assertIn('setWaypointSpeed "FULL"',text)
        self.assertIn('findIf {(_x select 1) == "DEPARTURE"}',text)
        self.assertNotIn('missionNamespace getVariable ["WAIT_AIPass_ZeusHoldSeconds",120]',text)
        self.assertNotIn('call WAIT_fnc_CortexAirAttack;',text)
        self.assertNotIn('call WAIT_fnc_CortexAirAttackPlan;',text)
        guide=(ROOT/'releaseVerificationAndDeployment/cortexQA/runGuide.sqf').read_text()
        for item in ['WAIT_Cortex_AirAttackPlan','actual shots','observed AA','CountermeasureLastRequest']:
            self.assertIn(item,guide)
        diagnostic=(ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text()
        self.assertIn('cortex-air-attack-snapshot-limits',diagnostic)

    def test_onboard_reports_are_expiring_owner_validated_cargo_only(self):
        text=source('cortexOnboardContact')
        for item in ['groupOwner _reporter == _owner','group effectiveCommander _vehicle == _reporter','serverTime < _expiry','serverTime+35','CortexPassengerReady','CortexIsEligible','CortexRestoreCalm','WAIT_Cortex_DismountStopRequest']:
            self.assertIn(item,text)
        self.assertLess(text.index('_state set ["dismounted"'),text.index('doGetOut'))
        self.assertNotIn(' reveal ',text)
        self.assertNotIn('doMove',text)
        tick=source('cortexGroupTick')
        self.assertIn('if (!_ordered && {_visible isEqualTo []}',tick)

    def test_danger_only_contact_does_not_authorise_target_dependent_tactics(self):
        tick=source('cortexGroupTick')
        self.assertIn('private _hasTargetKnowledge = _enemies isNotEqualTo [];',tick)
        self.assertIn('Danger geometry is deliberately approximate',tick)
        for dispatch in [
            'WAIT_fnc_CortexAntiArmour',
            'WAIT_fnc_CortexArtilleryRequest',
            'WAIT_fnc_CortexReinforce',
            'WAIT_fnc_CortexCoordinatedAssault',
            'WAIT_fnc_CortexTacticalStart'
        ]:
            contact=tick.split('case "CONTACT": {',1)[1]
            call=contact.index(dispatch)
            guard=contact.rfind('_hasTargetKnowledge',0,call)
            self.assertGreaterEqual(guard,0,dispatch)
            self.assertLess(call-guard,500,dispatch)
        # Local immediate response and vehicle stop restoration still run without target identity.
        contact=tick.split('case "CONTACT": {',1)[1]
        self.assertIn('WAIT_fnc_CortexMorale',contact)
        self.assertIn('WAIT_fnc_CortexStance',contact)
        self.assertIn('WAIT_fnc_CortexVehicles',contact)
        self.assertIn('_state set ["contactKnowledge",(_state getOrDefault ["contactKnowledge",false]) || {_hasTargetKnowledge}];',tick)
        self.assertIn('_state set ["contactKnowledge",true];',contact)
        self.assertIn('if (!_manoeuvreActive && {!_dangerActive}',contact)
        self.assertIn('&& {!(_state getOrDefault ["contactKnowledge",false])}) exitWith {',contact)
        self.assertIn('"DANGER_EXPIRED"',contact)
        self.assertIn('"contactKnowledge"',source('cortexRestoreCalm'))

    def test_cross_group_dismount_safe_stop_is_owner_validated_and_reversible(self):
        vehicles=source('cortexVehicles')
        for item in ['WAIT_Cortex_DismountStopRequest','groupOwner _passengerGroup == _passengerOwner',
                     'effectiveCommander _vehicle in units _group','getForcedSpeed _vehicle',
                     '_vehicle forceSpeed 0','WAIT_Cortex_DismountForcedSpeed',
                     '[_group,groupOwner _group,serverTime+30]']:
            self.assertIn(item,vehicles)
        release=source('cortexReleaseGroup')
        stop=source('cortexStop')
        for text in [release,stop]:
            self.assertIn('WAIT_Cortex_DismountForcedSpeed',text)
            self.assertIn('WAIT_Cortex_DismountStopRequest',text)

    def test_danger_only_vehicle_response_uses_safe_dismount_without_target_work(self):
        tick=source('cortexGroupTick')
        vehicles=source('cortexVehicles')
        restore=source('cortexRestoreCalm')
        self.assertIn('_state set ["dangerDismount",[+_dangerPosition,time+30,_vehicleProfile,_dangerCause,_dangerVehicle,_dangerSource,_dangerGeneration]];',tick)
        self.assertIn('if (count _dangerDismount == 7) then {',vehicles)
        self.assertIn('private _affectedVehicles=[_dangerVehicle];',vehicles)
        self.assertIn('{_dangerVehicle in _vehicles}',vehicles)
        self.assertNotIn('else {_vehicles}',vehicles)
        self.assertIn('if (_vehicleProfile != "") then {',tick)
        self.assertIn('_dangerCause in ["HIT","EXPLOSION","SUPPRESSED","GUNFIRE"] || {_dangerHostile}',vehicles)
        self.assertIn('_dangerProfile in ["TRANSPORT","ARMED","ARMOURED"]',vehicles)
        self.assertIn('WAIT_Danger_VehicleContext',tick)
        self.assertLess(vehicles.index('private _dangerDismount='),vehicles.index('if (_enemies isEqualTo []) exitWith'))
        danger_segment=vehicles.split('private _dangerDismount=',1)[1].split('if (_enemies isEqualTo []) exitWith',1)[0]
        for token in ['_knownCloseThreat','_emplacementUnsafe','_disabledUnsafe','WAIT_Danger_AbandonReason']:
            self.assertIn(token,danger_segment)
        self.assertIn('call _dismountAtThreat',danger_segment)
        helper=vehicles.split('private _dismountAtThreat = {',1)[1].split('// Cross-group safe-stop handshake',1)[0]
        for marker in ['WAIT_Cortex_DismountStopRequest','WAIT_Cortex_DismountForcedSpeed',
                       'WAIT_Cortex_OnboardDanger','WAIT_fnc_CortexPassengerReady',
                       'orderGetIn false','unassignVehicle','doGetOut']:
            self.assertIn(marker,helper)
        for forbidden in ['doTarget','doFire','WAIT_fnc_CortexGroupMove','WAIT_fnc_OperationStart']:
            self.assertNotIn(forbidden,helper)
            self.assertNotIn(forbidden,danger_segment)
        self.assertIn('"dangerDismount"',restore)
        onboard=source('cortexOnboardContact')
        self.assertIn('WAIT_Cortex_OnboardDanger',onboard)
        self.assertNotIn(' reveal ',onboard)
        for cleanup in [source('cortexReleaseGroup'),source('cortexStop')]:
            self.assertIn('WAIT_Cortex_OnboardDanger',cleanup)

    def test_contact_dismount_speed_restore_requires_the_owned_zero_cap(self):
        vehicles=source('cortexVehicles')
        release=source('cortexReleaseGroup')
        stop=source('cortexStop')
        self.assertGreaterEqual(vehicles.count('[getForcedSpeed _vehicle,0]'),2)
        for text in [vehicles,release,stop]:
            self.assertIn('param [1,-2]',text)
            self.assertIn('abs ((getForcedSpeed',text)
            self.assertIn('-_ownedStop) <= 0.1',text)
        self.assertIn('if (!_externalTakeover && {_saved isNotEqualTo []}',release)

    def test_countermeasure_inventory_includes_modded_person_turrets(self):
        for name in ['cortexFireCountermeasure','cortexVehicles']:
            text=source(name)
            self.assertIn('allTurrets [_vehicle, true]',text)
            self.assertNotIn('allTurrets [_vehicle, false]',text)

    def test_passenger_migration_retains_intent_without_immediate_boarding(self):
        text=source('cortexLocality')
        self.assertIn('_adopted set ["dismounted",_passengers]',text)
        self.assertIn('assignedVehicle _unit == _vehicle',text)
        self.assertIn('_adopted set ["onboardContactUntil",serverTime+30]',text)
        self.assertNotIn('orderGetIn true',text)

    def test_passenger_audit_checks_readiness_and_fixture_motion(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text()
        self.assertLess(text.index('DISMOUNT-fixture-controller-ready'),text.index('private _enemyGroup=createGroup'))
        for item in ['DISMOUNT-fixture-stationary-held','DISMOUNT-fixture-safe-stop-observed','REMOUNT-group-membership-independent','REMOUNT-original-groups-retained']:
            self.assertIn(item,text)
        for item in ['DANGER-VEHICLE-fixture-moving','DANGER-VEHICLE-native-explosion',
                     'DANGER-VEHICLE-bounded-safety-lease','DANGER-VEHICLE-safe-stop',
                     'DANGER-VEHICLE-passengers-physically-exit','DANGER-VEHICLE-operating-crew-retained',
                     'DANGER-VEHICLE-no-invented-combat','DANGER-VEHICLE-contact-fixture-ready',
                     'DANGER-VEHICLE-effective-commander-persistence',
                     'DANGER-VEHICLE-known-hostile-finite-reaction',
                     'DANGER-VEHICLE-finite-countermeasure',
                     'DANGER-STATIC-empty-crew-released','DANGER-STATIC-useful-crew-retained',
                     'DANGER-STATIC-no-invented-combat']:
            self.assertIn(item,text)
        self.assertIn('private _spawnRealGrenade={',text)
        self.assertIn('addEventHandler ["FiredMan"',text)
        self.assertIn('forceWeaponFire ["HandGrenadeMuzzle","HandGrenadeMuzzle"]',text)
        self.assertIn('WAIT CORTEX QA FIXTURE ERROR: native grenade firing produced no projectile',text)
        self.assertIn('private _sourceGroup=createGroup [west,true]',text)
        self.assertIn('_source hideObjectGlobal true',text)
        self.assertIn('_grenade setVelocity [0,0,-4]',text)
        self.assertGreaterEqual(text.count('call _spawnRealGrenade'),6)
        self.assertNotIn('attackTarget',text)
        self.assertIn('abs speed _dangerTruck > 5',text)
        self.assertIn('O_APC_Wheeled_02_rcws_v2_F',text)
        self.assertIn('effectiveCommander _contactVehicle',text)
        self.assertIn('count _actors == 1',text)
        self.assertIn('WAIT_Danger_VehicleReaction',text)
        mounted=text.split('// A three-person armoured crew',1)[1].split('deleteGroup _contactCrewGroup;',1)[0]
        for forbidden in [' reveal ', ' doTarget ', ' doFire ', ' forceWeaponFire ', ' call WAIT_fnc_DangerEngineSubmit']:
            self.assertNotIn(forbidden,mounted)
        self.assertNotIn('vehicle _x != _x',text)

    def test_mounted_danger_reacts_once_without_taking_route_ownership(self):
        text=source('cortexVehicles')
        danger=text.split('private _dangerDismount=',1)[1].split('if (_enemies isEqualTo []) exitWith',1)[0]
        for marker in ['vehicleDangerReaction','_dangerGeneration','WAIT_Danger_VehicleReaction',
                       'call WAIT_fnc_CortexLineOfFireClear','doSuppressiveFire _aimPosition']:
            self.assertIn(marker,danger)
        suppression=danger.split('// An intact armed platform',1)[1].split('// Defensive smoke is independent',1)[0]
        for forbidden in ['CortexGroupMove','addWaypoint','forceSpeed','setVelocity']:
            self.assertNotIn(forbidden,suppression)

    def test_vehicle_danger_jink_is_short_generation_owned_and_subordinate(self):
        registry=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        vehicles=source('cortexVehicles')
        jink=source('cortexVehicleJink')
        self.assertIn('class CortexVehicleJink',registry)
        for marker in [
            'WAIT_AIPass_VehicleJink_Enable','WAIT_Convoy_Active','CortexExternalTakeover',
            'count (_group getVariable ["WAIT_Operation",createHashMap]) > 0',
            '(_state getOrDefault ["movementLease",[]]) isNotEqualTo []',
            'fullCrew [_vehicle,"",false]','vehicle _x == _x','abs speed _vehicle > 25',
            'WAIT_fnc_CortexSelectAvenue','["VEHICLE_JINK",time+25]',
            'WAIT_fnc_OperationStart','WAIT_fnc_CortexGroupMove','WAIT_Danger_VehicleJink'
        ]:
            self.assertIn(marker,jink)
        for forbidden in ['setPos','setVelocity','moveIn','allowDamage','disableCollisionWith','while {']:
            self.assertNotIn(forbidden,jink)
        self.assertIn('vehicleDangerJink',vehicles)
        self.assertIn('_dangerCause in ["HIT","EXPLOSION"] || {_knownCloseThreat}',vehicles)
        self.assertIn('["VEHICLE_WITHDRAW","VEHICLE_STANDOFF","VEHICLE_JINK","VEHICLE_ORIENT"]',vehicles)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        for marker in ['DANGER-VEHICLE-jink-disabled','DANGER-VEHICLE-jink-operation-owned',
                       'DANGER-VEHICLE-jink-physical-travel','DANGER-VEHICLE-jink-crew-retained']:
            self.assertIn(marker,audit)

    def test_tracked_vehicle_danger_orientation_is_finite_generation_owned_and_route_safe(self):
        registry=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        orient=source('cortexVehicleOrient')
        vehicles=source('cortexVehicles')
        self.assertIn('class CortexVehicleOrient',registry)
        for marker in [
            'WAIT_AIPass_VehicleGunnery_Enable','WAIT_Convoy_Active','CortexExternalTakeover',
            'isKindOf "Tank"','abs speed _vehicle > 5',
            'count (_group getVariable ["WAIT_Operation",createHashMap]) > 0',
            '(_state getOrDefault ["movementLease",[]]) isNotEqualTo []',
            'WAIT_fnc_CortexOwnershipLease','WAIT_fnc_OperationStart',
            '["VEHICLE_ORIENT",time+8]','sendSimpleCommand (["LEFT","RIGHT"]',
            'WAIT_Danger_VehicleOrient'
        ]:
            self.assertIn(marker,orient)
        for forbidden in ['setDir','setVectorDir','setVelocity','setPos','doMove','commandMove','addWaypoint','while {']:
            self.assertNotIn(forbidden,orient)
        self.assertIn('vehicleDangerOrient',vehicles)
        self.assertIn('_dangerProfile == "ARMOURED"',vehicles)
        self.assertIn('sendSimpleCommand "STOPTURNING"',vehicles)
        for marker in ['WAIT_fnc_OperationCancel','VEHICLE_ORIENT_TIMEOUT','VEHICLE_ORIENT_ALIGNED',
                       '["INCOMPLETE","COMPLETE"] select _aligned']:
            self.assertIn(marker,vehicles)
        self.assertIn('["VEHICLE_WITHDRAW","VEHICLE_STANDOFF","VEHICLE_JINK","VEHICLE_ORIENT"]',vehicles)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        for marker in ['DANGER-VEHICLE-orient-disabled','DANGER-VEHICLE-orient-operation-owned',
                       'DANGER-VEHICLE-orient-physical-alignment','DANGER-VEHICLE-orient-no-travel',
                       'DANGER-VEHICLE-orient-crew-retained']:
            self.assertIn(marker,audit)

    def test_mounted_danger_recovers_a_lost_gunner_without_sacrificing_the_driver(self):
        registry=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        recovery=source('cortexVehicleCrewRecover')
        vehicles=source('cortexVehicles')
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text(encoding='utf-8')
        self.assertIn('class CortexVehicleCrewRecover',registry)
        for marker in ['_cause != "DETECTED"','abs speed _vehicle >= 20','WAIT_Convoy_Active',
                       'WAIT_AIPass_VehicleGunnery_Enable','CortexExternalTakeover','CortexZeusHeld']:
            self.assertIn(marker,recovery)
        self.assertIn('_candidate=commander _vehicle',recovery)
        self.assertIn('_candidate == driver _vehicle',recovery)
        self.assertIn('_candidate assignAsGunner _vehicle',recovery)
        self.assertIn('_candidate action ["MoveToGunner",_vehicle]',recovery)
        for forbidden in ['moveInGunner','createUnit','commandMove','doMove','forceSpeed','setVelocity']:
            self.assertNotIn(forbidden,recovery)
        self.assertIn('vehicleDangerCrewRecovery',vehicles)
        self.assertIn('DANGER-VEHICLE-gunner-loss-recovered',audit)
        self.assertIn('DANGER-VEHICLE-driver-role-preserved',audit)

    def test_armoured_danger_countermeasure_is_generation_owned_and_route_neutral(self):
        text=source('cortexVehicles')
        danger=text.split('// Defensive smoke is independent',1)[1].split('// A useful static mortar',1)[0]
        for marker in ['vehicleDangerCountermeasure','_dangerGeneration','["ARMED","ARMOURED"]',
                       '["HIT","EXPLOSION","SUPPRESSED"]','combatMode _group in ["YELLOW","RED"]',
                       'WAIT_Convoy_Active','WAIT_fnc_CortexFireCountermeasure',
                       'WAIT_Danger_VehicleCountermeasure']:
            self.assertIn(marker,danger)
        self.assertLess(danger.index('_state set ["vehicleDangerCountermeasure"'),
                        danger.index('WAIT_Danger_VehicleCountermeasure'))
        for forbidden in ['CortexGroupMove','addWaypoint','forceSpeed','setVelocity','doMove','commandMove']:
            self.assertNotIn(forbidden,danger)

    def test_danger_mortar_uses_the_finite_artillery_owner_and_live_gates(self):
        vehicles=source('cortexVehicles')
        fire=source('cortexArtilleryFire')
        step=source('cortexArtilleryMissionStep')
        shot=source('cortexArtilleryShot')
        danger=vehicles.split('// A useful static mortar',1)[1].split('// An intact armed platform',1)[0]
        for marker in ['_dangerProfile == "ARTILLERY"','_vehicle isKindOf "StaticMortar"',
                       '"DANGER",objNull,_dangerSource','WAIT_fnc_CortexArtilleryFire']:
            self.assertIn(marker,danger)
        for forbidden in ['doArtilleryFire','commandArtilleryFire','createVehicle']:
            self.assertNotIn(forbidden,danger)
        for text in [fire,step,shot]:
            self.assertIn('WAIT_AIPass_Danger_Enable',text)
            self.assertIn('WAIT_AIPass_Vehicles_Enable',text)
            self.assertIn('WAIT_AIPass_VehicleGunnery_Enable',text)
            self.assertIn('CortexExternalTakeover',text)
        self.assertIn('["SUPPORT", "COUNTER", "DANGER"]',fire)
        self.assertIn('_battery isKindOf "StaticMortar"',fire)
        self.assertIn('_commander knowsAbout _enemy <= 0',fire)
        self.assertIn('_target distance2D (getPosATL _enemy) > 75',fire)
        self.assertIn('["burstsLeft", if (_mode == "SMOKE" || {_danger}) then {1}',fire)
        self.assertIn('["opening", !_danger]',fire)
        self.assertIn('WAIT_AIPass_NextDangerFire',fire+step)
        self.assertIn('if ((_mission get "phase") == "READY" && {(_mission get "mode") == "HE"}) exitWith',step)
        self.assertIn('_battery doArtilleryFire [_aim, _magazine, 1]',shot)
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        for case in ['DANGER-MORTAR-real-hostile-fire','DANGER-MORTAR-natural-knowledge',
                     'DANGER-MORTAR-finite-owner','DANGER-MORTAR-lethal-warning',
                     'DANGER-MORTAR-one-real-round','DANGER-MORTAR-finite-release',
                     'DANGER-MORTAR-crew-retained','DANGER-MORTAR-support-remained-disabled']:
            self.assertIn(case,audit)
        mortar=audit.split('// A useful static mortar',1)[1].split('// Real enemy artillery events',1)[0]
        self.assertIn('_dangerEnemy doFire gunner _gun',mortar)
        self.assertNotIn(' reveal ',mortar)
        self.assertNotIn('call WAIT_fnc_CortexArtilleryFire',mortar)

    def test_stationary_passenger_comparison_is_explicit_and_additive(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runVehicleDrills.sqf').read_text()
        self.assertIn('if (_stationary) then {(driver _truck) disableAI "PATH"}',text)
        self.assertIn('DISMOUNT-crew-report-physical-exit',text)
        self.assertIn('_driverDetected && {_enabledStartedMounted} && {_dismounted} && {_ownedExit}',text)
        self.assertIn('DISMOUNT-contact-physical-exit',text)
        self.assertIn('[false,true],[true,true],[false,true,false,true]',text)

    def test_contact_transition_audit_requires_physical_search_and_resumption(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runContact.sqf').read_text()
        for case in ['DANGER-disabled-real-stimulus-inert','DANGER-live-gate-reenabled','DANGER-authored-hold-fire-preserved','DANGER-casualty-alert-no-contact','DANGER-release-mode-no-tactical-handoff','DANGER-active-zeus-replacement','DANGER-leader-loss-physical-continuation','DANGER-forced-order-no-tactical-handoff','DANGER-active-response-native-order-interrupt']:
            self.assertIn(case,text)
        self.assertIn('[_reflexGroup,true,_zeusWaypoint select 1] call WAIT_fnc_CortexZeusMark',text)
        self.assertIn('private _spawnRealGrenade={',text)
        self.assertIn('addEventHandler ["FiredMan"',text)
        self.assertIn('forceWeaponFire ["HandGrenadeMuzzle","HandGrenadeMuzzle"]',text)
        self.assertIn('WAIT CORTEX QA FIXTURE ERROR: native grenade firing produced no projectile',text)
        self.assertIn('private _sourceGroup=createGroup [west,true]',text)
        self.assertIn('_source hideObjectGlobal true',text)
        self.assertIn('_source setAmmo [_rifle,30]',text)
        self.assertIn('_spawn set [2,(_spawn param [2,0]) + 2]',text)
        self.assertIn('_grenade setVelocity [0,0,-4]',text)
        disabled=text.split('// The configured engine FSM remains installed',1)[1].split('// Prove the engine-loaded FSM',1)[0]
        self.assertIn('call _spawnRealGrenade',disabled)
        self.assertIn('["WAIT_AIPass_Danger_Enable",false]',disabled)
        self.assertIn('["WAIT_AIPass_Danger_Enable",true]',disabled)
        self.assertNotIn('call WAIT_fnc_DangerEngineSubmit',disabled)
        casualty=text.split('// A real same-group death',1)[1].split('// Prove the engine-loaded FSM',1)[0]
        self.assertIn('[_casualtyActor] call _killWithRealProjectile',casualty)
        self.assertIn('private _bodyGroup=createGroup [east,true]',casualty)
        self.assertIn('[_bodyActor] call _killWithRealProjectile',casualty)
        self.assertIn('getOrDefault ["HIDE",0]',casualty)
        self.assertIn('== "CALM"',casualty)
        self.assertIn('combatMode _casualtyGroup == "BLUE"',casualty)
        released=text.split('// CARELESS is an authored mission state',1)[1].split('// Prove the engine-loaded FSM',1)[0]
        self.assertIn('_releaseGroup setBehaviourStrong "CARELESS"',released)
        self.assertIn('"acceptedRecords",0',released)
        self.assertIn('== _releaseAcceptedBefore',released)
        self.assertIn('behaviour _releaseUnit == "CARELESS"',released)
        forced=text.split('// A concrete native boarding task',1)[1].split('deleteGroup _forcedGroup;',1)[0]
        self.assertIn('"acceptedRecords",0',forced)
        self.assertIn('== _forcedAcceptedBefore',forced)
        for case in ['CONTACT-natural-reacquisition','TRANS-contact-postcontact-sequence','TRANS-search-contact-interruption','TRANS-search-physical-approach','TRANS-regroup-physical-cohesion','TRANS-calm-new-orders-physical-arrival','TRANS-no-old-search-order-resurrection']:
            self.assertIn(case,text)
        self.assertIn('_searchTravel >= 15 && {_searchApproach}',text)
        self.assertIn('(_state getOrDefault ["searchTeam",[]]) isEqualTo []',text)
        self.assertIn('"SEARCH INTERRUPTION: NATURAL CONTACT"',text)
        self.assertIn('(_x param [1,""]) == "SEARCH"',text)
        self.assertIn('(_x param [2,""]) == "CONTACT"',text)
        self.assertNotIn('_state set ["phase"',text)
        self.assertIn('TRANS-published-phase-ledger',text)
        self.assertIn('WAIT_Cortex_PhaseTransitions',text)
        self.assertIn('private _publishedSecurity=_publishedPhases find "SECURITY"',text)
        self.assertIn('private _findPublishedAfter={',text)
        self.assertIn('[_publishedPhases,"CALM",_publishedRegroup] call _findPublishedAfter',text)
        self.assertNotIn('_forEachIndex > _publishedRegroup',text)
        self.assertIn('count _phaseHistory <= 32',text)
        self.assertNotIn('call WAIT_fnc_CortexRestoreCalm',text)

    def test_combat_start_failure_reports_independent_tactical_refusals(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('WAIT_Cortex_FlankRefusal',text)
        self.assertIn('WAIT_Cortex_AdvanceRefusal',text)
        self.assertIn('getOrDefault ["movementLease",[]]',text)
        self.assertIn('[_prefix+"-started",_started,str _startRefusal]',text)

    def test_combat_audit_proves_action_specific_contact_selection(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runCombat.sqf').read_text()
        self.assertIn('"ASSAULT-MULTI-CONTACT"',text)
        self.assertIn('[_group] call WAIT_fnc_CortexKnowledge',text)
        self.assertIn('_nearestDistance < 12 && {_viableIndex > 0}',text)
        self.assertIn('-viable-contact-selected',text)
        self.assertIn('(_drill getOrDefault ["target",objNull]) == (_enemies select 1)',text)
        self.assertNotIn('reveal [',text)

    def test_calm_cleanup_retires_onboard_contact_deadline(self):
        text=source('cortexRestoreCalm')
        cleanup=text[text.index('{_state deleteAt _x} forEach [',text.index('private _boarding')):]
        self.assertIn('"onboardContactUntil"',cleanup)

    def test_attack_flare_ammo_check_counts_only_actual_countermeasure_magazines(self):
        text=(ROOT/'releaseVerificationAndDeployment/cortexQA/runAircraft.sqf').read_text()
        self.assertIn('_firedMagazines pushBackUnique (_x select 4)',text)
        self.assertIn('if ((_x select 0) in _firedMagazines)',text)
        self.assertIn('_magazinesBefore getOrDefault [_x,0]',text)

    def test_naval_assault_uses_existing_scheduler_and_finite_external_ownership(self):
        naval=source('cortexNavalAssault')
        release=source('cortexNavalRelease')
        tick=source('cortexGroupTick')
        vehicles=source('cortexVehicles')
        compat=(ROOT/'addons/compatibility/functions/aiTweaksDetectCompatibility.sqf').read_text(encoding='utf-8')
        self.assertIn('WAIT_AIPass_NavalAssault_Enable',naval)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',naval)
        self.assertNotIn('navalBackend',compat)
        self.assertIn('WAIT_Cortex_NavalOperation',naval)
        self.assertIn('WAIT_Cortex_NavalOperation',source('cortexLocality'))
        for marker in ['surfaceIsWater _landing','surfaceIsWater _approach',
                       'surfaceNormal _shore','CortexOwnershipLease','NAVAL_ASSAULT',
                       'WAIT_Cortex_NavalPlan','doGetOut _unit','NAVAL_LANDING']:
            self.assertIn(marker,naval)
        implementation=naval.split('*/',1)[1]
        for forbidden in ['allGroups','allUnits','while {','waitUntil','setPos','setVelocity','setDamage','setFuel','setDriveOnPath']:
            self.assertNotIn(forbidden,implementation)
        self.assertIn('call WAIT_fnc_CortexNavalAssault',tick)
        self.assertIn('call WAIT_fnc_CortexNavalRelease',source('cortexReleaseGroup'))
        self.assertIn('WAIT_Cortex_NavalForcedSpeed',release)
        self.assertIn('WAIT_Cortex_NavalOperation',release)
        self.assertIn('_vehicle isKindOf "LandVehicle"',vehicles)

    def test_support_acceptance_uses_a_surviving_anchor_but_keeps_radio_qualification(self):
        """A dead or pinned formal leader cannot reject a viable local support element."""
        apply=source('cortexSupportApply')
        self.assertIn('private _anchor=[_group] call WAIT_fnc_CortexGroupAnchor;',apply)
        self.assertIn('!isNull _anchor',apply)
        self.assertIn('behaviour _anchor != "CARELESS"',apply)
        self.assertIn('getSuppression _anchor',apply)
        self.assertIn('WAIT_fnc_CortexGroupTransmitter',apply)

    def test_pending_coordination_acknowledges_without_idling_the_responder(self):
        apply=source('cortexSupportApply')
        pending=apply.split('if (_okay && {_directCoordinationPending}) exitWith {',1)[1].split('};',1)[0]
        self.assertIn('WAIT_fnc_CortexSupportAck',pending)
        for forbidden in ['WAIT_fnc_CortexOwnershipLease','WAIT_fnc_OperationStart','movementLease','set ["responding"']:
            self.assertNotIn(forbidden,pending)
        self.assertLess(apply.index('if (_okay && {_directCoordinationPending}) exitWith {'),apply.index('call WAIT_fnc_CortexOwnershipLease'))
        self.assertIn('private _replaceLocalDrill = _attackAllowed && {_movementOwner == "TACTICAL_DRILL"}',apply)
        self.assertIn('[_group,_state,"ABORT"] call WAIT_fnc_CortexFlankEnd',apply)
        self.assertLess(apply.index('call WAIT_fnc_CortexFlankEnd'),apply.index('call WAIT_fnc_CortexOwnershipLease'))
    def test_support_reservations_use_the_common_generation_lifecycle(self):
        apply=source('cortexSupportApply')
        maintain=source('cortexSupportMaintain')
        tick=source('cortexGroupTick')
        for marker in ['WAIT_fnc_OperationStart','"SUPPORT_RALLY"','"COORDINATED_ASSAULT"',
                       'supportOperationGeneration','"ACCEPTED"']:
            self.assertIn(marker,apply)
        for marker in ['WAIT_fnc_OperationStep','WAIT_fnc_OperationCancel',
                       'supportOperationGeneration','"LEASE_EXPIRED"','"SERVER_RETIREMENT"',
                       '"FEATURE_DISABLED"','"ZEUS"','"EXTERNAL"']:
            self.assertIn(marker,maintain)
        self.assertIn('case "SUPPORT_RALLY": {"supportOperationGeneration"};',tick)
        self.assertNotIn('[_group] call WAIT_fnc_CortexGroupMoveClear;',apply)
        self.assertIn('[_group,_operationGeneration] call WAIT_fnc_CortexGroupMoveClear;',maintain)
        self.assertIn('if (_operationGeneration >= 0',maintain)

    def test_naval_release_is_token_scoped_and_never_forces_boarding(self):
        release=source('cortexNavalRelease')
        for marker in ['(_plan select 0) == _token','(_plan select 1) == _group',
                       'forceSpeed (_saved param [0,-1])','CortexGroupMoveClear',
                       'NAVAL_ASSAULT','NAVAL_LANDING']:
            self.assertIn(marker,release)
        self.assertIn('abs ((getForcedSpeed _boat)-_ownedStop) <= 0.1',release)
        self.assertIn('[_group,_operationGeneration] call WAIT_fnc_CortexGroupMoveClear;',release)
        self.assertNotIn('[_group] call WAIT_fnc_CortexGroupMoveClear;',release)
        self.assertIn('if (_operationGeneration >= 0 &&',release)
        self.assertIn('WAIT_Cortex_NavalForcedSpeed",[getForcedSpeed _boat,0]',source('cortexNavalAssault'))
        for forbidden in ['moveIn','orderGetIn true','assignAs','setPos','deleteVehicle']:
            self.assertNotIn(forbidden,release)

    def test_confirmed_building_contact_enters_single_clearance_owner(self):
        """Fresh native indoor contact must select CQB without a second tactical controller."""
        contact=source('cortexBuildingContact')
        clear=source('cortexClearBuilding')
        tick=source('cortexGroupTick')
        spec=source('cortexTuningSpec')
        sections=source('aiTweaksSettingsSections')
        functions=(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        for marker in ['WAIT_AIPass_BuildingCombat_Enable','WAIT_AIPass_BuildingCombat_Range']:
            self.assertIn(marker,spec)
            self.assertIn(marker,contact)
        self.assertIn('["BUILDINGS", "03 Infantry", "07 Buildings and CQB"]',sections)
        self.assertIn('class CortexBuildingContact',functions)
        for marker in ['(_x param [2,1e6,[0]]) <= 5','isNull objectParent _enemy',
                       'boundingBoxReal _candidateBuilding','worldToModelVisual','lineIntersectsSurfaces',
                       '(_x select 2) == _candidateBuilding','count _capable < 4',
                       '["preserveBrain",true]','WAIT_fnc_CortexClearBuilding']:
            self.assertIn(marker,contact)
        for forbidden in [' setPos ',' moveIn ',' allowDamage ',' disableAI ']:
            self.assertNotIn(forbidden,contact)
        self.assertIn('private _preserveBrain=_options getOrDefault ["preserveBrain",false];',clear)
        preserved=clear.split('if (_preserveBrain) then {',1)[1].split('} else {',1)[0]
        self.assertNotIn('WAIT_fnc_CortexReleaseGroup',preserved)
        self.assertIn('WAIT_fnc_CortexGroupMoveClear',preserved)
        self.assertIn('WAIT_fnc_CortexBuildingContact',tick)
        self.assertLess(tick.index('WAIT_fnc_CortexCoordinatedAssault'),tick.index('WAIT_fnc_CortexBuildingContact'))
        self.assertLess(tick.index('WAIT_fnc_CortexBuildingContact'),tick.index('WAIT_fnc_CortexTacticalStart'))

    def test_natural_building_contact_has_physical_audit(self):
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runBuildingComparison.sqf').read_text(encoding='utf-8')
        for marker in ['BUILD-CONTACT-native-knowledge','BUILD-CONTACT-natural-clear-started',
                       'BUILD-CONTACT-physical-entry','WAIT_AIPass_BuildingCombat_Enable',
                       'WAIT_AIPass_BuildingCombat_Range','knowsAbout _contactEnemy']:
            self.assertIn(marker,audit)
        natural=audit.split('// Natural building contact acceptance.',1)[1]
        for forbidden in [' reveal ','WAIT_fnc_CortexClearBuilding','setPos','moveIn','disableAI "PATH"']:
            self.assertNotIn(forbidden,natural)

    def test_naval_delivery_tracks_crew_and_passenger_generations_separately(self):
        naval=source('cortexNavalAssault')
        release=source('cortexNavalRelease')
        for marker in ['WAIT_fnc_OperationStart','"NAVAL_ASSAULT"','"NAVAL_LANDING"',
                       'navalOperationGeneration','"APPROACH"','"EGRESS"']:
            self.assertIn(marker,naval)
        for marker in ['navalOperationGeneration','WAIT_fnc_OperationRelease',
                       'WAIT_fnc_OperationCancel','NAVAL_']:
            self.assertIn(marker,release)

    def test_naval_audit_requires_real_coast_travel_dismount_and_cleanup(self):
        audit=(ROOT/'releaseVerificationAndDeployment/cortexQA/runNaval.sqf').read_text(encoding='utf-8')
        runner=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8')
        launcher=(ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        for marker in ['for "_bearing" from 0 to 350 step 10','surfaceIsWater _water',
                       'NAVAL-terrain-coast','forEach [false,true]',
                       'NAVAL-"+_suffix+"-physical-water-travel',
                       'NAVAL-"+_suffix+"-physical-dismount',
                       'NAVAL-"+_suffix+"-dry-egress',
                       'NAVAL-"+_suffix+"-crew-retained',
                       'NAVAL-"+_suffix+"-finite-cleanup']:
            self.assertIn(marker,audit)
        post_setup=audit.split('} forEach [false,true];',1)[0].split('private _start=getPosATL _boat;',1)[1]
        for forbidden in ['setPos','moveInCargo','addWaypoint','setVariable ["WAIT_Cortex_NavalPlan"']:
            self.assertNotIn(forbidden,post_setup)
        self.assertIn('cortexQANaval.sqf',runner)
        self.assertIn("mod_pipeline.py') stage $Package $runtime --focus $Focus",launcher)
        self.assertIn("glob('run*.sqf')", (ROOT/'releaseVerificationAndDeployment/mod_pipeline.py').read_text(encoding='utf-8'))



    def test_general_driving_assist_is_separate_from_convoys_and_preserves_native_routes(self):
        start=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        release=(ROOT/'addons/vehicles/functions/drivingAssistRelease.sqf').read_text(encoding='utf-8')
        spec=source('cortexTuningSpec')
        group_tick=source('cortexGroupTick')
        self.assertIn('WAIT_AIPass_DrivingAssist_Enable',spec)
        self.assertIn('Convoy driving is configured separately',spec)
        sections=source('aiTweaksSettingsSections')
        self.assertIn('["DRIVING", "05 Vehicles", "01 General driving and route safety"]',sections)
        self.assertIn('true, "DRIVING", "NEXT_OPERATION"',spec)
        self.assertIn('["CONVOY_DRIVING", "06 Convoys", "02 Driving and route safety"]',sections)
        self.assertIn('WAIT_Convoy_Active',start)
        self.assertIn('WAIT_fnc_DrivingAssistRelease',start)
        self.assertIn('private _yieldToOwner=[_group] call WAIT_fnc_CortexExternalTakeover;',start)
        self.assertIn('getTerrainHeightASL _sample',start)
        self.assertIn('time+4',start)
        self.assertIn('private _capMps=_cap/3.6;',start)
        self.assertIn('if (_saved > 0) then {_capMps=_capMps min _saved};',start)
        self.assertIn('forceSpeed _capMps',start)
        self.assertIn('["WAIT_DrivingAssist_State",[_capMps,',start)
        self.assertIn('WAIT_fnc_DrivingAssistStart',group_tick)
        self.assertIn('WAIT_DrivingAssist_Restore',release)
        self.assertIn('WAIT_DrivingAssist_State',release)
        self.assertIn('abs ((getForcedSpeed _vehicle)-_ownedCap) <= 0.1',release)
        self.assertIn('abs ((getForcedSpeed _vehicle)-_ownedCap) > 0.1',start)
        self.assertIn('forceSpeed (_restore param [0,-1])',release)
        self.assertIn('WAIT_DrivingAssist_Vehicles',source('cortexReleaseGroup'))
        diagnostics=source('aiGetDiagnostics')
        self.assertIn('general-driving',diagnostics)
        self.assertIn('capKmh=%2',diagnostics)
        self.assertIn('_capMps*3.6',diagnostics)

    def test_danger_lifecycle_uses_a_live_group_actor_for_leader_loss_cleanup(self):
        """A dead original leader cannot strand a short danger posture or operation record."""
        setup=source('dangerSetup')
        start=source('operationStart')
        fsm=(ROOT/'addons/main/fsm/dangerAssessment.fsm').read_text(encoding='utf-8')
        for text in [setup,start,fsm]:
            self.assertIn('WAIT_fnc_CortexGroupAnchor',text)
        self.assertIn('getPosATL _operationAnchor',start)
        self.assertIn('[_dangerActor,""RELEASE""] call WAIT_fnc_DangerReact',fsm)

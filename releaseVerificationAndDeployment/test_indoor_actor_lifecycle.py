"""Staged actor investigation must retain finite, scoped ownership contracts."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class IndoorActorLifecycleTests(unittest.TestCase):
    def test_start_cannot_replace_existing_actor_or_group_owners(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        start=s.split('if (_mode == "START") exitWith {',1)[1].split('private _current=',1)[0]
        for guard in ('WAIT_Cortex_ActorMove','WAIT_IndoorActor_Order','WAIT_IndoorActor_Brain',
                      'WAIT_Operation','WAIT_fnc_IndoorActorNativeContext','WAIT_IndoorActor_Cooldown',
                      'serverTime-(_belief select 1) > 5','select [0,16]','count _investigators >= 2'):
            self.assertIn(guard,start)
        self.assertIn('(serverTime+45) min ((_belief select 1)+30)',start)
        self.assertEqual(s.count('_actor doMove _node;'),1)
        self.assertIn('WAIT_IndoorActor_Serial',start)
        self.assertIn('_brain,0,_brain get "jobKey"',s)
        self.assertNotIn('netId _actor',s)
        for forbidden in ('setPosATL','setVelocity','forceSpeed','joinSilent','setDamage','doFire'):
            self.assertNotIn(forbidden,s)
    def test_finish_preserves_new_tasks_and_can_run_with_features_disabled(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        finish=s.split('if (_mode == "FINISH") exitWith {',1)[1].split('if (_mode == "START")',1)[0]
        for guard in ('_generation','_epoch','_oldGroup == _group','WAIT_OperationGeneration',
                      'WAIT_fnc_NativeOrderReceipt','currentCommand _actor == "MOVE"',
                      '_destination vectorDistance _target <= 0.25','isEqualTo _lease',
                      '_reservation isEqualTo _lease || {_migration && {_reservation isEqualTo []}}'):
            self.assertIn(guard,finish)
        self.assertIn('call _releaseAvailable',finish)
        self.assertNotIn('call _available',finish)
        self.assertIn('isNotEqualTo "INDOOR_INVESTIGATE"',finish)
        self.assertIn('_lease call _copyArray',s)
        self.assertIn('(_brain get "route") call _copyArray',s)
        for name in ('cortexLocality','cortexStop'):
            self.assertIn('WAIT_fnc_IndoorActorOperation',(ROOT/f'addons/core/functions/{name}.sqf').read_text())
        self.assertIn('WAIT_fnc_IndoorActorOperation',(ROOT/'addons/infantry/functions/cortexReleaseGroup.sqf').read_text())
    def test_arrival_is_not_a_room_clear_and_has_finite_failure(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        for guard in ('_height <= 1','_segment isEqualTo []','_roof isNotEqualTo []',
                      '(_hit select 2) == _building','NO_PROGRESS','VISITED','BUILDING_CHANGED'):
            self.assertIn(guard,s)
        self.assertNotIn('_cleared pushBack',s)
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        self.assertNotIn('WAIT_fnc_IndoorActorOperation',tick)
        fsm=(ROOT/'addons/main/fsm/indoorActor.fsm').read_text()
        self.assertIn('serverTime >= (_brain getOrDefault',fsm)
        self.assertIn('""QUEUE""',fsm)
    def test_planner_has_distinct_native_positions_and_bounded_geometry(self):
        s=(ROOT/'addons/infantry/functions/indoorActorNodeSelect.sqf').read_text()
        for guard in ('count _positions > 512','_reserved findIf',
                      'abs (_height-_beliefHeight) <= 1.5','_ranked select [0,3]',
                      'private _hit=_hits select 0','_selected isNotEqualTo []'):
            self.assertIn(guard,s)
        self.assertEqual(s.count('lineIntersectsSurfaces'),1)
        self.assertNotIn('getPosATL _enemy',s)

    def test_physical_fixture_has_real_prerequisites_and_no_positive_shortcuts(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runIndoorActors.sqf').read_text()
        for guard in ('INDOOR-idle-owner-prerequisite','INDOOR-pair-physical-entry',
                      'INDOOR-pair-destinations','INDOOR-same-actor-repeat',
                      'INDOOR-stale-belief-refused','INDOOR-reservation-refused',
                      'INDOOR-stop-refused','INDOOR-native-move-handover',
                      '_visits findIf {!_x} < 0','_travel findIf {_x < 5} < 0',
                      '_repeatVisited','_outside','_destinationKept','_targetsStable',
                      '_repeatGeneration > (_generations select 0)','_interruptGeneration'):
            self.assertIn(guard,s)
        self.assertIn('call WAIT_fnc_IndoorActorOperation',s)
        for forbidden in ('BIS_fnc_door','enableAI','setDestination','WAIT_IndoorActor_Cooldown",nil',
                          'setVariable ["WAIT_IndoorActor_Result"','_unit setPos','_actor setPos'):
            self.assertNotIn(forbidden,s)
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text()
        self.assertIn('if (_focus == "indooractors") exitWith',server)
        self.assertIn('cortexQAIndoorActors.sqf',server)
        from mod_pipeline import supported_focuses
        self.assertIn('indooractors',supported_focuses())

    def test_locality_retires_old_private_pointer_even_without_public_journal(self):
        s=(ROOT/'addons/core/functions/cortexLocality.sqf').read_text()
        start=s.index('private _indoor=_unit getVariable')
        end=s.index('// Event-handler IDs',start)
        block=s[start:end]
        self.assertLess(block.index('_indoor set ["finished",true]'),block.index('["TRANSFER"'))
        self.assertIn('isEqualTo _indoor',block)
        self.assertLess(block.index('["TRANSFER"'),block.index('_unit setVariable ["WAIT_IndoorActor_Brain",nil]'))
        self.assertIn('_unit setVariable ["WAIT_IndoorActor_FSM",nil]',block)
        stop=(ROOT/'addons/core/functions/cortexStop.sqf').read_text()
        self.assertEqual(stop.count('call WAIT_fnc_IndoorActorOperation'),1)
        early=stop.split('call WAIT_fnc_IndoorActorOperation',1)[0].rsplit('private _indoor=',1)[1]
        self.assertIn('count _indoor > 0',early)
        self.assertNotIn('select [0,16]',stop.split('call WAIT_fnc_IndoorActorOperation',1)[1].split('CortexHearingLocal',1)[0])
    def test_owner_helpers_are_installed_and_server_authenticated(self):
        init=(ROOT/'releaseVerificationAndDeployment/auditMission/init.sqf').read_text()
        for name in ('cortexQAPerformanceOwner.sqf','cortexQAIndoorActorOwner.sqf'):
            self.assertIn('preprocessFileLineNumbers "'+name+'"',init)
        self.assertIn('!isNil "WAIT_CortexQA_IndoorActorAckServer"',init)
        helper=(ROOT/'releaseVerificationAndDeployment/cortexQA/runIndoorActorOwner.sqf').read_text()
        for guard in ('remoteExecutedOwner != 2','local _actor','local group _actor',
                      '_serial <=','WAIT_CortexQA_IndoorConsumed','WAIT_CortexQA_IndoorPending',
                      '(_pending select 2) != _sender','owner _actor != _sender',
                      'count _brain == 0','WAIT_IndoorActor_Order','_actor doMove _goal'):
            self.assertIn(guard,helper)
        for forbidden in ('setVariable ["WAIT_IndoorActor_Order"','setVariable ["WAIT_IndoorActor_Result"','enableAI','setPos'):
            self.assertNotIn(forbidden,helper)
        performance=(ROOT/'releaseVerificationAndDeployment/cortexQA/runPerformanceOwner.sqf').read_text()
        self.assertEqual(performance.count('remoteExecutedOwner != 2'),3)
    def test_hc_fixture_requires_real_transfer_and_physical_new_work(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runIndoorActorsHC.sqf').read_text()
        for guard in ('Waldo_fnc_HeadlessMigrateGroup','Waldo_Headless_Clients',
                      'call WAIT_fnc_HeadlessMigrateGroup','"COMPANION"','owner _actor == _owner',
                      '"STATUS",_owner','"MOVE",_owner','-hc-native-physical',
                      '-return-pointer-retired','-old-callback-overlap','-returned-repeat-physical',
                      '_repeatGeneration > _oldGeneration','call _physicalVisit','_repeatDeadline',
                      'if (_localRetired) then','_targetKept'):
            self.assertIn(guard,s)
        for forbidden in ('setGroupOwner','BIS_fnc_door','enableAI','setDestination',
                          'setVariable ["WAIT_IndoorActor_Cooldown"','_actor setPos'):
            self.assertNotIn(forbidden,s)

    def test_native_context_binds_actual_contact_and_protects_mission_paths(self):
        s=(ROOT/'addons/infantry/functions/indoorActorNativeContext.sqf').read_text()
        for guard in ('getAttackTarget _actor','assignedTarget _actor','_assigned != _contact',
                      '_engaging != _contact','_actor knowsAbout _contact >= 1','"PLANNING"',
                      'waypointType _waypoint != "MOVE"','waypointScript _waypoint != ""',
                      'waypointStatements','waypointTimeout','synchronizedTriggers',
                      'synchronizedWaypoints','waypointAttachedObject','waypointAttachedVehicle',
                      '_unitState == "BUSY"','_nativeFiringClear','_destination vectorDistance _belief <= 2.5'):
            self.assertIn(guard,s)
        self.assertIn('["OBSERVE","COMBAT_APPROACH"',s)
        self.assertNotIn('getPosATL _contact',s)
        for command in (' doMove ','doFollow','doTarget','doFire','setDestination'):
            self.assertNotIn(command,s)
    def test_native_observation_does_not_issue_until_a_measured_stall(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        observe=s.split('if ((_admission select 0) == "OBSERVE" && {!_escalate}) exitWith {',1)[1].split('if (_escalate',1)[0]
        self.assertNotIn('doMove',observe)
        self.assertNotIn('set ["issued",true]',observe)
        for guard in ('serverTime-(_brain get "progressAt") < 12','["escalations",1]',
                      '_reserved pushBack +(_brain get "target")','currentCommand _actor == "FIRE"',
                      'getUnitState _actor == "PLANNING"','contactRequired','vectorDistance (_brain get "progressPosition") >= 1','_admission isNotEqualTo (_brain get "admission")'):
            self.assertIn(guard,s)
        self.assertEqual(s.count('["deadline",_deadline]'),1)
        finish=s.split('if (_mode == "FINISH") exitWith {',1)[1].split('if (_mode == "START")',1)[0]
        self.assertIn('private _ownsLeg=_issued',finish)
        self.assertIn('_actor doMove waypointPosition _waypoint;',finish)
    def test_routine_group_reposition_cannot_steal_an_actor_leg(self):
        s=(ROOT/'addons/infantry/functions/cortexTacticalReposition.sqf').read_text()
        guard=s.index('if ((units _group) findIf {_x call _actorReserved}')
        self.assertLess(s.index('call WAIT_fnc_CortexRetreat'),guard)
        self.assertLess(guard,s.index('call WAIT_fnc_CortexFindCover'))
        self.assertLess(guard,s.index('call WAIT_fnc_CortexOwnershipLease'))
        for marker in ('_lease isEqualTo []','finite (_lease select 2)','!_expired'):
            self.assertIn(marker,s)

    def test_door_side_effect_rechecks_contact_and_higher_priority_tasks(self):
        s=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        indoor=s.split('if ((_context select 0) == "INDOOR") exitWith {',1)[1].split('private _key=switch',1)[0]
        for guard in ('contactRequired','isNull _contact','!alive _contact','_engaging != _contact',
                      '_assigned != _contact','WAIT_AIPass_Active','WAIT_AIPass_BuildingCombat_Enable',
                      'WAIT_AIPass_Assault_Enable','WAIT_AIPass_Garrison','WAIT_AIPass_Defend',
                      'WAIT_AIPass_ClearBuilding','_destination call _vectorValid','_target call _vectorValid',
                      'getSuppression _unit < 0.5','checkAIFeature "PATH"'):
            self.assertIn(guard,indoor)
        final=s.split('if (_near && {_visible}',1)[1].split('call BIS_fnc_door',1)[0]
        self.assertIn('call _orderCurrent',final)

    def test_existing_disjoint_roster_requires_current_bounded_actor_ownership(self):
        s=(ROOT/'addons/infantry/functions/indoorActorGroupAvailable.sqf').read_text()
        for guard in ('participantsRequired','ownerEpoch','WAIT_OperationGeneration','cancelReason',
                      'count _participants > 64','_participants isEqualTo []','group _x != _group',
                      'WAIT_Cortex_GroupMoveIntent','supportHeld','WAIT_AIPass_ClearBuilding',
                      '!(_actor in _participants)','["ADVANCE","FLANK","ASSAULT"]'):
            self.assertIn(guard,s)
        actor=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        self.assertEqual(actor.count('call WAIT_fnc_IndoorActorGroupAvailable'),5)
        self.assertIn('WAIT_OperationGeneration',actor)
        door=(ROOT/'addons/infantry/functions/cortexBuildingDoor.sqf').read_text()
        self.assertIn('[_unit] call WAIT_fnc_IndoorActorGroupAvailable',door)

    def test_disjoint_generation_acknowledgement_never_renews_actor_work(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        acknowledgement=s.split('private _operationGeneration=_group getVariable',1)[1].split('if (!(call _available)',1)[0]
        for guard in ('count (_group getVariable ["WAIT_Operation",createHashMap]) > 0',
                      'WAIT_fnc_IndoorActorGroupAvailable','(_journal select 0) == (_brain get "generation")',
                      '(_journal select 1) == (_brain get "ownerEpoch")','(_journal select 2) == _group',
                      '(_journal select 3) == (_brain get "operationGeneration")',
                      '(_journal select 7) isEqualTo (_brain get "lease")','_journal set [3,_operationGeneration]'):
            self.assertIn(guard,acknowledgement)
        for forbidden in ('doMove','doFollow','set ["deadline"','set ["lease"','set ["target"','set ["progressAt"'):
            self.assertNotIn(forbidden,acknowledgement)

    def test_natural_dispatch_is_bounded_and_does_not_claim_the_squad(self):
        s=(ROOT/'addons/infantry/functions/indoorActorDispatch.sqf').read_text()
        for guard in ('"indoorActors",8','select [0,16]','_admitted >= 2','knowsAbout _contact >= 1',
                      'distance2D (_belief select 0) <= (_range min 40)','WAIT_AIPass_BuildingCombat_Range','WAIT_IndoorActor_Cooldown',
                      'WAIT_fnc_IndoorActorGroupAvailable','WAIT_fnc_BuildingContactSelect',
                      '["contact",_contact]','["belief",_belief]'):
            self.assertIn(guard,s)
        for forbidden in ('doMove','doFollow','getPosATL _contact','setVariable ["WAIT_Operation"'):
            self.assertNotIn(forbidden,s)
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        self.assertLess(tick.index('call WAIT_fnc_CortexBuildingContact'),tick.index('call WAIT_fnc_IndoorActorDispatch'))
        self.assertLess(tick.index('call WAIT_fnc_IndoorActorDispatch'),tick.index('call WAIT_fnc_CortexTacticalStart'))
        clear=(ROOT/'addons/infantry/functions/cortexBuildingContact.sqf').read_text()
        self.assertLess(clear.index('WAIT_IndoorActor_Actors'),clear.index('call WAIT_fnc_CortexClearBuilding'))

    def test_natural_fixture_requires_engine_discovery_and_real_dispatch(self):
        s=(ROOT/'releaseVerificationAndDeployment/cortexQA/runIndoorNatural.sqf').read_text()
        for guard in ('INDOOR-NATURAL-placement-access','INDOOR-NATURAL-engine-knowledge','INDOOR-NATURAL-dispatch-admission',
                      'INDOOR-NATURAL-physical-entry','knowsAbout _enemy >= 1',
                      '_brain getOrDefault ["contact"','_brain getOrDefault ["building"',
                      '_travel findIf {_x < 5} < 0','_roof isNotEqualTo []'):
            self.assertIn(guard,s)
        for forbidden in ('["START"','call WAIT_fnc_IndoorActorDispatch','call WAIT_fnc_CortexGroupTick',
                          ' reveal ','BIS_fnc_door','setVariable ["WAIT_IndoorActor_Result"','enableAI','_actor setPosATL','_enemy setPosATL'):
            self.assertNotIn(forbidden,s)
        from mod_pipeline import supported_focuses
        self.assertIn('indoornatural',supported_focuses())
        pipeline=(ROOT/'releaseVerificationAndDeployment/mod_pipeline.py').read_text()
        self.assertIn("('indooractors','indooractorshc','indoornatural')",pipeline)

    def test_post_contact_and_boarding_treat_unknown_reservations_as_owned(self):
        tick=(ROOT/'addons/infantry/functions/cortexGroupTick.sqf').read_text()
        predicate=tick.split('private _hasLiveActorMove = {',1)[1].split('private _get =',1)[0]
        for guard in ('_actorMove isEqualTo []','_actorMove isEqualType []',
                      'finite (_actorMove select 2)','count (_actorMove select 1) == 3','!_expired'):
            self.assertIn(guard,predicate)
        passenger=(ROOT/'addons/vehicles/functions/cortexPassengerReady.sqf').read_text()
        for guard in ('if (_reserved) exitWith {false}','!finite (_reservation select 2)',
                      'count (_reservation select 1) != 3','findIf {!(_x isEqualType 0) || {!finite _x}} >= 0'):
            self.assertIn(guard,passenger)

    def test_failed_indoor_nodes_are_temporary_scoped_observations(self):
        actor=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        cache=actor.split('// A failed issued leg',1)[1].split('_actor setVariable ["WAIT_IndoorActor_Result"',1)[0]
        for guard in ('!_migration','_issued','"NO_PROGRESS"','_oldGroup == _group',
                      'serverTime+60','select [0,4]','_failed deleteAt 0','_transform call _copyArray'):
            self.assertIn(guard,cache)
        self.assertNotIn('true]',cache)
        planner=(ROOT/'addons/infantry/functions/indoorActorNodeSelect.sqf').read_text()
        for guard in ('_failedNodes findIf','(_x select 1) isEqualTo _transform',
                      'serverTime < (_x select 3)','(_x select 4) isEqualTo _epoch','select [0,4]'):
            self.assertIn(guard,planner)
        self.assertNotIn('setVariable',planner)

    def test_fresh_group_adoption_precedes_actor_publication(self):
        s=(ROOT/'addons/infantry/functions/indoorActorOperation.sqf').read_text()
        start=s.split('if (_mode == "START") exitWith {',1)[1].split('private _current=',1)[0]
        adopt=start.index('[_group,true] call WAIT_fnc_CortexLocality')
        self.assertLess(start.index('if !(call _available)'),adopt)
        self.assertLess(adopt,start.index('private _admission='))
        self.assertLess(adopt,start.index('_actor setVariable ["WAIT_IndoorActor_Order"'))
        recheck=start[adopt:start.index('private _admission=')]
        for guard in ('call _available','WAIT_AIPass_Adopted','WAIT_AIPass_Epoch','serverTime-(_belief select 1) > 5'):
            self.assertIn(guard,recheck)

    def test_explicit_clear_preflight_can_replace_only_matching_indoor_jobs(self):
        s=(ROOT/'addons/infantry/functions/cortexClearBuilding.sqf').read_text()
        preflight=s.split('private _replaceIndoor=',1)[1].split('// Natural contact requires',1)[0]
        for guard in ('!_resume','"preserveBrain",false','isEqualTo false','WAIT_fnc_CortexActorMoveReserved',
                      'count _journal == 9','"finished",true','"generation",-1','"ownerEpoch",-1',
                      '(_journal select 2) == _group','(_journal select 7) isEqualTo _reservation',
                      '(_indoor getOrDefault ["lease",[]]) isEqualTo _reservation'):
            self.assertIn(guard,preflight)
        for forbidden in ('setVariable','call WAIT_fnc_IndoorActorOperation','doMove','doFollow'):
            self.assertNotIn(forbidden,preflight)
        self.assertLess(s.index('INVALID_ACTOR_MINIMUM'),s.index('call WAIT_fnc_CortexReleaseGroup'))
        self.assertLess(s.index('NO_VALID_ROOFED_POSITIONS'),s.index('private _replaceIndoor='))

    def test_explicit_release_retires_indoor_jobs_without_generic_group_reset(self):
        s=(ROOT/'addons/infantry/functions/cortexOrderLocal.sqf').read_text()
        release=s.split('case "RELEASE": {',1)[1].split('case "EXCLUDE": {',1)[0]
        for guard in ('WAIT_IndoorActor_Brain','WAIT_IndoorActor_Order','["FINISH",_x,_indoor]',
                      '_released=_released || {_retired}','forEach units _group'):
            self.assertIn(guard,release)
        self.assertNotIn('select [0,16]',release)
        self.assertNotIn('WAIT_fnc_CortexReleaseGroup',release)
        self.assertNotIn('doMove',release)
        self.assertNotIn('doFollow',release)

    def test_garrison_and_defend_use_same_reservation_boundary(self):
        for name,expected in [('cortexGarrison',3),('cortexGarrisonApplyLocal',4),('cortexDefendApplyLocal',2)]:
            text=(ROOT/('addons/infantry/functions/'+name+'.sqf')).read_text()
            self.assertEqual(text.count('call WAIT_fnc_CortexActorMoveReserved'),expected,name)
            self.assertNotIn('_reservation param [2,1e12,[0]]',text)
        garrison=(ROOT/'addons/infantry/functions/cortexGarrison.sqf').read_text()
        teleport=garrison.split('if (_teleport) then {',1)[1]
        self.assertLess(teleport.index('call WAIT_fnc_CortexActorMoveReserved'),teleport.index('_unit setPosATL'))
        self.assertIn('{_free}',teleport)

    def test_defend_deferred_actor_keeps_arrival_job_alive(self):
        s=(ROOT/'addons/infantry/functions/cortexDefendApplyLocal.sqf').read_text()
        deferred=s.split('if (_routeCurrent && {!_canIssue}) then {',1)[1].split('if (_canIssue) then {',1)[0]
        self.assertIn('_pending=_pending+1',deferred)
        self.assertIn('set [2,time]',deferred)
        for command in ('doMove','doStop','doFollow','enableAI','forceSpeed'):
            self.assertNotIn(command,deferred)
        self.assertIn('group _unit == _group',s)
        self.assertIn('[2, -1] select (_pending == 0)',s)
    def test_garrison_deferral_preserves_original_deadline_and_retries(self):
        s=(ROOT/'addons/infantry/functions/cortexGarrisonApplyLocal.sqf').read_text()
        deferred=s.split('// A reservation defers both route retries',1)[1].split('private _openedDoor',1)[0]
        for guard in ('serverTime <= (_job get "deadline")','_pending=_pending+1',
                      '_deferredRoute set [3,time]','WAIT_AIPass_GarrisonFailed','group _x == _group'):
            self.assertIn(guard,deferred)
        self.assertNotIn('serverTime+',deferred)
        self.assertNotIn('doMove',deferred)
        self.assertIn('&& {[_x] call _mayIssueMovement}) then {',deferred)
    def test_release_paths_preserve_unknown_actor_reservations(self):
        for name in ('cortexClearRelease','cortexDefendRelease','cortexGarrisonRelease','dangerEngineRelease'):
            s=(ROOT/('addons/infantry/functions/'+name+'.sqf')).read_text()
            self.assertIn('call WAIT_fnc_CortexActorMoveReserved',s,name)
            self.assertNotIn('_reservation param [2,',s,name)
        danger=(ROOT/'addons/infantry/functions/dangerEngineRelease.sqf').read_text()
        self.assertLess(danger.index('call WAIT_fnc_CortexActorMoveReserved'),danger.index('_actor setUnitPosWeak'))
    def test_clearance_workers_and_reserves_share_reservation_boundary(self):
        s=(ROOT/'addons/infantry/functions/buildingOperationStep.sqf').read_text()
        available=s.split('private _actorAvailable={',1)[1].split('private _actorTaskFree=',1)[0]
        reserve=s.split('private _reserveReady={',1)[1].split('private _reserves=',1)[0]
        for boundary in (available,reserve):
            self.assertIn('call WAIT_fnc_CortexActorMoveReserved',boundary)
            self.assertNotIn('_reservation param [2,',boundary)
        for guard in ('_stageCommandFree','call _ownsCurrentMove','!(_candidate in _unavailable)',
                      'WAIT_fnc_CompatibilityExternalControl'):
            self.assertIn(guard,reserve)
    def test_post_clear_reserved_stop_retains_changed_order_handover(self):
        s=(ROOT/'addons/infantry/functions/groupBrainStep.sqf').read_text()
        hold=s.split('private _clearHold=',1)[1].split('private _legacyJob=',1)[0]
        retry=hold.split('// A newer individual order retires',1)[1]
        for guard in ('currentCommand _x == "STOP"','group _x == _group',
                      'call WAIT_fnc_CortexActorMoveReserved','_deferred pushBackUnique _x',
                      '_clearHold select 0,_clearHold select 1,_clearHold select 2,_deferred'):
            self.assertIn(guard,retry)
        self.assertNotIn('doFollow',retry)
        self.assertNotIn('doMove',retry)
        self.assertIn('!([_x] call WAIT_fnc_CortexActorMoveReserved)',hold)
    def test_garrison_refill_cannot_spend_reserved_exit_cover(self):
        s=(ROOT/'addons/infantry/functions/cortexGarrisonRefill.sqf').read_text()
        other=s.split('// Never vacate the sole assigned observation post',1)[1].split('} >= 0;',1)[0]
        for guard in ('!([_x] call WAIT_fnc_CortexActorMoveReserved)',
                      'currentCommand _x in ["","STOP"]','isNull remoteControlled _x',
                      'isNull objectParent _x','call WAIT_fnc_CortexGarrisonArrived'):
            self.assertIn(guard,other)
        self.assertIn('private _free=!([_actor] call WAIT_fnc_CortexActorMoveReserved)',s)
    def test_stretched_convoy_does_not_count_reverse_motion_as_forward_progress(self):
        s=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text()
        pacing=s.split('if (_gap > _target*2) then {',1)[1].split('_leadLimit=_leadLimit min _catchup',1)[0]
        self.assertNotIn('abs speed _follower',pacing)
        self.assertIn('velocityModelSpace _follower select 1',pacing)
        self.assertIn('max 0)*3.6',pacing)
        self.assertIn('_followerForwardKmh',pacing)
        self.assertIn('max 5',pacing)
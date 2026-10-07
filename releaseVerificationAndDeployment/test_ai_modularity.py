"""Static integration contracts; these checks do not simulate Arma or prove runtime behaviour."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'addons/main/functions/Cortex'
def src(name):
    return re.sub(r'^/\*.*?\*/\s*', '', next((ROOT/'addons').rglob(name+'.sqf')).read_text(encoding='utf-8-sig'), flags=re.S)
class AIModularityContracts(unittest.TestCase):
    def test_full_ownership_mode_uses_the_registered_wait_enum(self):
        discovery=src('cortexDiscover')
        lease=src('cortexOwnershipLease')
        spec=src('cortexTuningSpec')
        self.assertIn('[["SPLIT","WAIT"]', spec)
        self.assertIn('== "WAIT"',discovery)
        self.assertIn('_mode == "WAIT"',lease)
        self.assertNotIn('== "' + 'W' + 'MP"',discovery)
        self.assertIn('!_dangerWaitMode || {!_eligible}',discovery)
        self.assertIn('WAIT_AIPass_DangerBackendBaseline',discovery)

    def test_drill_loses_ownership_before_modes_and_does_not_regroup(self):
        step = src('cortexFlankStep')
        self.assertLess(step.index('"OWNERSHIP_LOST" call _end'), step.index('_group setCombatMode'))
        end = src('cortexFlankEnd')
        self.assertIn('_reason in ["ZEUS","OWNERSHIP_LOST"]', end)
        self.assertIn('if (_mayCommand) then {{_x doFollow _leader}', end)
        self.assertIn('private _hold = _mayCommand', end)

    def test_child_switches_are_registered_by_cba_and_react_on_current_owners(self):
        config = (ROOT/'addons/main/settings/aiConfig.sqf').read_text(encoding='utf-8')
        spec = src('cortexTuningSpec')
        register = src('aiTweaksRegisterSettings')
        changed = src('aiTweaksSettingChanged')
        names = ['VehicleDismount','VehicleRemount','VehicleWithdraw','CoverValidation','Hearing']
        names = ['WAIT_AIPass_'+name+'_Enable' for name in names] + [
            'WAIT_Convoy_'+name+'_Enable' for name in ['MountedFire','Cover','AvoidInfantry','ContactHalt','Unload']
        ]
        for name in names:
            self.assertIn('"'+name+'"',config)
            self.assertEqual(spec.count('"'+name+'"'),1)
        # CBA is the sole settings authority. WAIT registers every declared row and defers
        # runtime work until postInit, where callbacks change only the current owner's work.
        for contract in ['WAIT_fnc_CortexTuningSpec', 'CBA_fnc_addSetting',
                         'WAIT_fnc_AITweaksSettingChanged', 'WAIT_AITweaks_CBASettingsRegistered']:
            self.assertIn(contract,register)
        self.assertIn('missionNamespace setVariable [_name, _value]',changed)
        self.assertIn('WAIT_AITweaks_PostInitComplete',changed)
        self.assertIn('WAIT_AIPass_Danger_Enable',changed)
        self.assertIn('if (local _x) then {[_x] call WAIT_fnc_DangerSetup}',changed)
        self.assertIn('"CHECKBOX"',src('cortexTuning'))
    def test_group_opt_out_cannot_enable_a_global_switch(self):
        gate = src('cortexFeatureEnabled')
        self.assertLess(gate.index('missionNamespace getVariable'),gate.index('WAIT_AIPass_DisabledFeatures'))
        self.assertIn('WAIT_fnc_CompatibilityExternalControl',src('cortexIsEligible'))
        self.assertIn('WAIT_fnc_CortexFeatureEnabled',src('cortexFlankStep'))
        self.assertIn('WAIT_fnc_CortexFeatureEnabled',src('cortexRegroupStep'))
    def test_capability_is_live_ammo_not_exclusive_role(self):
        text = src('cortexCapabilities')
        self.assertIn('magazinesAmmoFull _unit',text)
        self.assertIn('_rounds > 0',text)
        self.assertIn('_magazine in _compatible',text)
        self.assertIn('/ 256',text)
        self.assertIn('/ 512',text)
        self.assertNotIn('leader group',text)
        for name in ['cortexAntiArmour','cortexMorale','cortexSupportApply']:
            self.assertIn('WAIT_fnc_CortexCapabilities',src(name))
    def test_passengers_share_safety_checks_and_cleanup_does_not_board(self):
        text = src('cortexPassengerReady')
        for check in ['local _unit','isPlayer','WAIT_fnc_CortexCombatEffective','abs speed _vehicle','surfaceIsWater','lineIntersectsSurfaces','fullCrew','emptyPositions']:
            self.assertIn(check,text)
        dismount = src('convoyDismountLocal')
        self.assertIn('WAIT_fnc_CortexExternalTakeover',dismount)
        self.assertIn('private _operator =',dismount)
        for name in ['cortexVehicles','cortexRestoreCalm']:
            self.assertIn('WAIT_fnc_CortexPassengerReady',src(name))
        locality=src('cortexLocality')
        self.assertIn('"OWNERSHIP_ADOPTED"',locality)
        self.assertIn('call WAIT_fnc_CortexRestoreCalm',locality)
        self.assertIn('private _restoreEligible=[_group,false,false,true] call WAIT_fnc_CortexIsEligible',locality)
        self.assertIn('false, !_restoreEligible, "OWNERSHIP_ADOPTED"',locality)
        restore = src('cortexRestoreCalm')
        self.assertIn('!_yieldToExternal && {_ownedHold}',restore)
        release=src('cortexReleaseGroup')
        self.assertIn('[_group, _state, false, _externalTakeover, _reason] call WAIT_fnc_CortexRestoreCalm',release)
        self.assertIn('_externalTakeover=_yieldToZeus || {_yieldToExternal}',release)
        self.assertIn('"EXTERNAL_TAKEOVER"',release)
        self.assertIn('WAIT_fnc_CortexZeusHeld',release)
        self.assertIn('WAIT_fnc_CortexExternalTakeover',release)
        for name in ['dangerActionSelect','dangerReact','dangerStep','dangerRequest']:
            text=src(name)
            self.assertTrue(
                '(units _group) findIf {[_x] call WAIT_fnc_CortexExternalOwner != ""}' in text
                or 'WAIT_fnc_CortexExternalTakeover' in text
            )
        for name in ['convoyTick','convoyCrewLocal']:
            self.assertIn('private _externalCrew',src(name))
    def test_report_transport_contains_positions_not_enemy_objects(self):
        report = src('cortexContactReport')
        self.assertIn('+(_x select 1)',report)
        self.assertIn('serverTime - (_x select 2)',report)
        self.assertIn('private _reporters=',report)
        self.assertIn('if (count _reporters > 8) then {_reporters resize 8}',report)
        self.assertIn('_confidence=_confidence max (_x knowsAbout _target)',report)
        self.assertNotIn('leader _group knowsAbout (_x select 0)',report)
        for name in ['cortexReportServer','cortexReportLocal']:
            text = src(name)
            self.assertNotIn(' reveal ',text)
            self.assertIn('WAIT_fnc_CortexFeatureEnabled',text)
            self.assertIn('serverTime',text)
        self.assertIn('groupOwner _receiver',src('cortexReportServer'))
        self.assertIn('from 1 to 8',src('cortexReportServer'))
    def test_support_reserves_before_dispatch_and_checks_owner_ack(self):
        step = src('cortexSupportStep')
        reservation = step.index('setVariable ["WAIT_AIPass_SupportLease",_lease,true]')
        self.assertLess(reservation,step.index('remoteExecCall ["WAIT_fnc_CortexSupportLocal",groupOwner'))
        self.assertIn('groupOwner _helper != _owner',step)
        self.assertIn('from 1 to 8',step)
        ack = src('cortexSupportAck')
        self.assertIn('[_replyOwner,groupOwner _group] call WAIT_fnc_HeadlessResolveSender',ack)
        self.assertIn('_lease isNotEqualTo _snapshot',ack)
        self.assertLess(ack.index('(_lease select 0) != _token'),ack.index('set [4,'))
    def test_support_waits_for_snapshot_and_revalidates_before_moving(self):
        text = src('cortexSupportApply')
        move = text.index('call WAIT_fnc_CortexGroupMove')
        for check in ['_current isNotEqualTo _lease','serverTime < _expiry','WAIT_fnc_CortexIsEligible','WAIT_fnc_CortexCapabilities','WAIT_AIPass_Garrison','WAIT_AIPass_Defend','artilleryScanner']:
            self.assertLess(text.index(check),move)
        self.assertIn('WAIT_AIPass_SupportRequests',src('cortexStop'))
        self.assertIn('WAIT_fnc_CortexGroupMoveClear',src('cortexSupportMaintain'))
    def test_assault_uses_existing_reservations_across_owners(self):
        text = src('cortexSupportAssaultServer')
        for contract in ['[_replyOwner,groupOwner _requester] call WAIT_fnc_HeadlessResolveSender','assaultIssued','WAIT_AIPass_SupportStatus','WAIT_AIPass_CoordinatedAssault_Enable','groupOwner _helper']:
            self.assertIn(contract,text)
        self.assertNotIn('local _x',src('cortexCoordinatedAssault'))
    def test_hearing_is_optional_bounded_and_cleaned(self):
        text = src('cortexHearingLocal')
        self.assertIn('"FiredNear"',text)
        self.assertIn('removeEventHandler',text)
        self.assertIn('serverTime+20',text)
        self.assertIn('50*round',text)
        self.assertNotIn(' reveal ',text)
        self.assertNotIn('allGroups',text)
        self.assertNotIn('allUnits',text)
        self.assertIn('WAIT_fnc_CortexHearingLocal',src('cortexStop'))
        self.assertIn('WAIT_fnc_CortexHearingLocal',src('cortexLocality'))
    def test_cover_and_infantry_checks_are_bounded(self):
        cover = src('cortexFindCover')
        for value in ['_objects resize 10','min 25','surfaceNormal','GEOM','WAIT_AIPass_CoverValidation_Enable']:
            self.assertIn(value,cover)
        drive = src('cortexInfantrySpeed')
        self.assertIn('count _people > 32',drive)
        self.assertIn('min 30',drive)
        self.assertNotIn('doMove',drive)
        self.assertNotIn('forceSpeed',drive)
    def test_convoy_checks_each_crew_and_passenger_group(self):
        text = (ROOT/'addons/vehicles/functions/convoyCrewLocal.sqf').read_text(encoding='utf-8')
        for feature in ['MountedFire','Unload','Cover']:
            self.assertIn('[group _unit,"WAIT_Convoy_'+feature+'_Enable",true]',text)
        for contract in ['fullCrew','_seats set','_unit doTarget _enemy','WAIT_fnc_CortexPassengerReady']:
            self.assertIn(contract,text)
    def test_disable_cleans_stance_targeting_and_pending_automatic_drop(self):
        tick = src('cortexGroupTick')
        for contract in ['WAIT_AIPass_Stance_Enable','setUnitPos "AUTO"','WAIT_AIPass_VehicleTarget','doTarget objNull']:
            self.assertIn(contract,tick)
        self.assertIn('WAIT_AIPass_Airborne_Enable',src('cortexAirborneDropStep'))
        self.assertIn('"forced", _force',src('cortexAirborneCheck'))
    def test_artillery_rechecks_actual_rounds(self):
        for name in ['cortexArtilleryAmmo','cortexArtilleryShot']:
            self.assertIn('magazinesAllTurrets',src(name))
            self.assertIn('(_x select 2) > 0',src(name))
        self.assertIn('WAIT_fnc_CortexFeatureEnabled',src('cortexArtilleryShot'))
    def test_danger_handover_is_scoped_and_restores_prior_state(self):
        lease = src('cortexOwnershipLease')
        for contract in ['WAIT_Cortex_OwnershipLease','lambs_danger_disableGroupAI','_baseline','serverTime','WAIT_AIPass_DangerBackendDisabledByPass',
                         'lambs_danger_isExecutingTactic','lambs_danger_forceMove','lambs_main_currentTactic','WAIT_Cortex_OwnershipBusyRefusals']:
            self.assertIn(contract,lease)
        self.assertLess(lease.index('lambs_danger_isExecutingTactic'),lease.index('setVariable ["lambs_danger_disableGroupAI", true'))
        self.assertIn('CortexOwnershipLease',(ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8'))
        apply = src('cortexSupportApply')
        maintain = src('cortexSupportMaintain')
        self.assertIn('[_group,"SUPPORT",true,_expiry] call WAIT_fnc_CortexOwnershipLease',apply)
        self.assertIn('[_group,"SUPPORT",false] call WAIT_fnc_CortexOwnershipLease',maintain)
        self.assertIn('(_dangerLease select 0) == "SUPPORT"',maintain)
        self.assertIn('[_group,"SUPPORT",false] call WAIT_fnc_CortexOwnershipLease',src('cortexRestoreCalm'))
        self.assertIn('[_group,"SUPPORT",false] call WAIT_fnc_CortexOwnershipLease',src('cortexRetreat'))
        self.assertIn('[_group,"SUPPORT",false] call WAIT_fnc_CortexOwnershipLease',src('cortexGroupTick'))
        self.assertIn('[_group,"",false] call WAIT_fnc_CortexOwnershipLease',src('cortexReleaseGroup'))
        self.assertIn('serverTime >= (_dangerLease select 2)',src('cortexDiscover'))
        self.assertIn('WAIT_AIPass_DangerBackendBaseline',src('cortexDiscover'))
        self.assertIn('WAIT_AIPass_DangerBackendBaseline',src('cortexReleaseGroup'))
    def test_danger_config_companions_are_detected_but_never_disabled(self):
        compat = (ROOT/'addons/compatibility/functions/aiTweaksDetectCompatibility.sqf').read_text(encoding='utf-8')
        diagnostics = (ROOT/'addons/core/functions/aiGetDiagnostics.sqf').read_text(encoding='utf-8')
        lease = src('cortexOwnershipLease')
        for patch in ['lambs_turrets','lambs_suppression','lambs_rpg']:
            self.assertIn(patch,compat)
            self.assertIn("WAIT_fnc_CompatibilityAvailable",diagnostics)
            self.assertNotIn(patch+' setVariable',lease)
        self.assertIn('config companions remain active in every mode',diagnostics)
class ExtendedSourceOwnershipContracts(unittest.TestCase):
    def test_standalone_foundation_requires_only_infrastructure(self):
        config = (ROOT/'addons/main/config.cpp').read_text(encoding='utf-8')
        launcher = (ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text(encoding='utf-8')
        self.assertIn('requiredAddons[] = {"cba_main", "cba_xeh", "A3_Modules_F", "WAIT_core", "WAIT_infantry", "WAIT_vehicles", "WAIT_aircraft", "WAIT_support", "WAIT_compatibility"}', config)
        self.assertNotIn('@LAMBS_Danger.fsm', launcher)
        self.assertNotIn('fsmDanger =', config)

    def test_active_external_operations_are_read_only_and_bounded(self):
        owner = src('cortexExternalOwner')
        for marker in ['PDCO_activeLeaseId', 'PDCO_garrisonActive', 'PDCO_garrisonPending',
                       'PDTB_jobId', 'smai_ownedMove', 'smai_pendingTargetGroup']:
            self.assertIn(marker, owner)
        self.assertIn('assignedVehicle _unit', owner)
        self.assertIn('vehicle _unit', owner)
        self.assertNotIn('setVariable', owner)
        self.assertNotIn('allGroups', owner)
        self.assertNotIn('allUnits', owner)
        self.assertNotIn('call _patch', owner)

    def test_aircraft_cannot_bypass_external_operation_ownership(self):
        aircraft = src('cortexAircraftEligible')
        self.assertIn('[_aircraft] call WAIT_fnc_CompatibilityExternalControl', aircraft)
        self.assertIn('[_x] call WAIT_fnc_CortexExternalOwner != ""', aircraft)
        self.assertIn('WAIT_fnc_CortexExternalOwner', src('cortexIsEligible'))

    def test_specialist_actors_are_excluded_from_skill_layers_as_well_as_tactics(self):
        profile = src('aiApplyProfile')
        adoption = src('aiHeadlessAdoptLocal')
        diagnostics = src('aiGetDiagnostics')
        self.assertIn('[_unit] call WAIT_fnc_CortexExternalOwner != ""', profile)
        self.assertIn('[_x] call WAIT_fnc_CortexExternalOwner == ""', adoption)
        self.assertIn('_hcGroups = _hcGroups select', diagnostics)
        self.assertIn('[_unit] call WAIT_fnc_CortexExternalOwner == ""', diagnostics)

    def test_specialist_detection_does_not_exclude_unrelated_custom_animation_sets(self):
        owner = src('cortexExternalOwner')
        self.assertIn('_class find "WBK_" == 0', owner)
        self.assertNotIn('_moves != ""', owner)

    def test_fixed_wing_release_is_a_bounded_native_request(self):
        controller = src('cortexAirAttack')
        self.assertIn('"NATIVE_PILOT_REQUEST"', controller)
        self.assertIn('_operator doFire _fireTarget', controller)
        self.assertIn('private _pilotSurfaceRelease=_isPlane && {!_airContact}', controller)
        self.assertIn('private _requestPending=', controller)
        self.assertNotIn('_operator forceWeaponFire', controller)
        self.assertNotIn('_aircraft setVelocity ', controller)

    def test_aircraft_cleanup_uses_per_crew_engine_commands(self):
        controller = src('cortexAirAttack')
        self.assertNotIn('(crew _aircraft) commandTarget objNull;', controller)
        self.assertNotIn('(crew _aircraft) doFollow leader _resumeGroup;', controller)
        self.assertIn('_x commandTarget objNull}} forEach crew _aircraft;', controller)
        self.assertIn('_x doFollow leader _resumeGroup}} forEach crew _aircraft;', controller)

class AddonSettingLifecycleContracts(unittest.TestCase):
    def test_optional_handlers_reconcile_after_postinit_only(self):
        callback = (ROOT/'addons/core/functions/aiTweaksSettingChanged.sqf').read_text(encoding='utf-8')
        gate = callback.index('WAIT_AITweaks_PostInitComplete')
        for setting in ['WAIT_AIPass_GrenadeEvasion_Enable', 'WAIT_AIPass_CivilianReaction_Enable']:
            self.assertGreater(callback.index(setting), gate)
        self.assertIn('WAIT_AIPass_Active', callback)
        self.assertIn('call WAIT_fnc_CortexInit', callback)
        self.assertNotIn('addPerFrameHandler', callback)
        self.assertNotIn('allUnits', callback)
        installer = src('cortexInit')
        self.assertIn('removeMissionEventHandler ["ProjectileCreated"', installer)
        self.assertIn('removeMissionEventHandler ["EntityCreated"', installer)
        self.assertIn('[_x,true] call WAIT_fnc_CortexCivilianSetup', installer)

    def test_setting_presentation_preserves_identifiers_and_uses_product_language(self):
        spec = src('cortexTuningSpec')
        self.assertIn('"WAIT_AIPass_InfantryOwnership", "Infantry controller ownership"', spec)
        self.assertNotIn('"COMPAT integration"', spec)
        for phrase in ['external naval controller takes', 'Simple Civilian Behaviour owns']:
            self.assertNotIn(phrase, spec)

class SharedSchedulerLifecycleContracts(unittest.TestCase):
    def test_skills_and_tactics_share_one_installer(self):
        self.assertIn('call WAIT_fnc_SchedulerReconcile', src('cortexInit'))
        self.assertIn('call WAIT_fnc_SchedulerReconcile', src('aiRebalanceInit'))
        self.assertNotIn('addPerFrameHandler', src('aiRebalanceInit'))
        self.assertNotIn('addPerFrameHandler', src('cortexInit'))
        self.assertIn('call CBA_fnc_addPerFrameHandler', src('schedulerReconcile'))

    def test_stops_preserve_the_other_runtime_and_stale_work_cannot_restart(self):
        for name in ['cortexStop', 'aiRebalanceStop']:
            self.assertIn('call WAIT_fnc_SchedulerReconcile', src(name))
            self.assertNotIn('call CBA_fnc_removePerFrameHandler', src(name))
        self.assertNotIn('setVariable ["WAIT_AIPass_Jobs", []]', src('cortexStop'))
        self.assertIn('WAIT_AI_LightingGeneration', src('aiRebalanceStop'))
        self.assertIn('exitWith {-1}', src('aiLightingStep'))
        self.assertIn('WAIT_AI_LightingGeneration', src('schedulerReconcile'))

    def test_lighting_is_bounded_and_does_not_pause_with_manoeuvres(self):
        step = src('aiLightingStep')
        self.assertNotIn('allUnits', step)
        self.assertIn('_cursor + 9', step)
        self.assertIn('_signature isNotEqualTo', step)
        self.assertIn('_paused && {!_skillsJob}', src('cortexSchedulerTick'))
        self.assertIn('&& {!_skillsJob}', src('cortexSchedulerTick'))

class HeadlessOwnershipContracts(unittest.TestCase):
    def test_compatible_headless_handoff_is_adopted_without_a_second_balancer(self):
        init = src('aiRebalanceInit')
        tactics_init = src('cortexInit')
        adopt = src('aiHeadlessAdoptLocal')
        bridge = src('compatibilityHeadlessBridge')
        revision = src('compatibilityHeadlessRevision')
        self.assertIn('"Waldo_Headless_GroupMigrated"', bridge)
        self.assertIn('"WAIT_Compatibility_HeadlessMigrated"', bridge)
        self.assertIn('call CBA_fnc_globalEvent', bridge)
        self.assertIn('WAIT_fnc_CompatibilityHeadlessBridge', init)
        self.assertIn('WAIT_fnc_CompatibilityHeadlessBridge', tactics_init)
        self.assertIn('"WAIT_Compatibility_HeadlessMigrated"', init)
        self.assertIn('WAIT_fnc_AIHeadlessAdoptLocal', init)
        self.assertIn('[_group, _previousOwner, _newOwner, "ACE"] call WAIT_fnc_AIHeadlessAdoptLocal', init)
        self.assertIn('private _adoption=_group getVariable ["WAIT_AI_LastHeadlessAdoption",[]]', init)
        self.assertNotIn('forEach units _group;\n            diag_log format ["[WAIT AI] ACE HC adoption', init)
        self.assertIn('"ace_headless_groupTransferPost"', tactics_init)
        self.assertIn('WAIT_fnc_AIHeadlessAdoptLocal', tactics_init)
        self.assertIn('WAIT_AIPass_Active', tactics_init)
        self.assertIn('clientOwner == _newOwner', init)
        self.assertIn('local _group', init)
        self.assertIn('if (_tacticsActive && {!(_group getVariable ["WAIT_AIPass_Adopted",false])}) then {', adopt)
        self.assertIn('[_group,true] call WAIT_fnc_CortexLocality', adopt)
        self.assertNotIn('setVariable ["WAIT_AIPass_Epoch", (_group getVariable', adopt)
        self.assertIn('_skillsActive || {_tacticsActive}', adopt)
        self.assertNotIn('Waldo_Headless_LastAdoption', adopt)
        self.assertIn('WAIT_fnc_CompatibilityHeadlessRevision', adopt)
        self.assertIn('WAIT_fnc_CompatibilityHeadlessRecord', revision)
        self.assertIn('_providerRevision', adopt)
        self.assertIn('_newOwner < 2', adopt)
        self.assertNotIn('_newOwner <= 2', adopt)
        self.assertIn('format ["%1:%2:%3:%4"', adopt)
        self.assertIn('WAIT_fnc_CortexDiscover', adopt)
        self.assertIn('WAIT_fnc_SchedulerReconcile', adopt)
        self.assertNotIn('setGroupOwner', adopt)
        self.assertNotIn('Waldo_fnc_HeadlessMigrateGroup', adopt)
    def test_headless_return_to_server_restarts_wait_on_the_actual_destination(self):
        init = src('aiRebalanceInit')
        tactics_init = src('cortexInit')
        self.assertIn('_newOwner >= 2', init)
        self.assertNotIn('!isDedicated', init)
        self.assertNotIn('!isDedicated', tactics_init)
        self.assertIn('isServer || {!hasInterface}', init)
        self.assertIn('isServer || {!hasInterface}', tactics_init)
        self.assertIn('clientOwner == _newOwner', init)
        self.assertIn('clientOwner == _newOwner', tactics_init)

    def test_convoy_restarts_only_its_destination_local_scheduler_after_hc_handoff(self):
        sync = src('convoySync')
        adopt = src('convoyHeadlessAdoptLocal')
        step = src('convoyOperationStep')
        functions = (ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('"ace_headless_groupTransferPost"', sync)
        self.assertIn('"WAIT_Compatibility_HeadlessMigrated"', sync)
        self.assertIn('WAIT_fnc_CompatibilityHeadlessBridge', sync)
        self.assertIn('WAIT_fnc_ConvoyHeadlessAdoptLocal', sync)
        self.assertIn('clientOwner == _newOwner', sync)
        self.assertNotIn('Waldo_Headless_LastAdoption', adopt)
        self.assertIn('WAIT_fnc_CompatibilityHeadlessRevision', adopt)
        self.assertIn('WAIT_Convoy_LocalState",nil', adopt)
        self.assertIn('WAIT_fnc_ConvoyCrewLocal', adopt)
        self.assertIn('WAIT_fnc_ConvoyOperationStart', adopt)
        self.assertIn('WAIT_Convoy_LocalJobToken', adopt)
        self.assertIn('WAIT_Convoy_LocalJobToken', step)
        self.assertNotIn('setGroupOwner', adopt)
        self.assertNotIn('doMove', adopt)
        self.assertNotIn('orderGetIn', adopt)
        self.assertIn('class ConvoyHeadlessAdoptLocal', functions)

    def test_headless_provider_identifiers_are_isolated_to_compatibility(self):
        for name in ['aiHeadlessAdoptLocal', 'cortexInit', 'aiRebalanceInit', 'convoyHeadlessAdoptLocal', 'convoySync']:
            self.assertNotIn('Waldo_Headless_', src(name))
        functions = (ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class CompatibilityHeadlessBridge', functions)
        self.assertIn('class CompatibilityHeadlessRevision', functions)
    def test_diagnostics_use_the_compatibility_adoption_record_and_report_resumed_work(self):
        diagnostics = src('aiGetDiagnostics')
        self.assertIn('call WAIT_fnc_CompatibilityHeadlessRecord', diagnostics)
        self.assertNotIn('Waldo_Headless_LastAdoption', diagnostics)
        self.assertIn('private _convoyHandoffMissing=', diagnostics)
        self.assertIn('missingCompatibilityHandoffRestart=', diagnostics)
        self.assertIn('activeConvoysMissingCompatibilityRestart=', diagnostics)
        self.assertIn('companionHandoff=%7 waitHandoff=%8', diagnostics)
        self.assertIn('companionHandoff=%10 waitOperation=%11', diagnostics)
    def test_lifecycle_audit_records_the_actual_wait_adoption_evidence(self):
        lifecycle = (ROOT/'releaseVerificationAndDeployment/cortexQA/runLifecycle.sqf').read_text(encoding='utf-8')
        self.assertIn('_group getVariable ["Waldo_Headless_LastAdoption",[]]', lifecycle)
        self.assertNotIn('_group getVariable ["WAIT_Headless_LastAdoption",[]]', lifecycle)

class StandaloneApiMigrationContracts(unittest.TestCase):
    def test_runtime_settings_use_cba_authority(self):
        tuning = src('cortexTuning')
        self.assertIn('call CBA_settings_fnc_set', tuning)
        self.assertIn('true, "server", false', tuning)
        self.assertNotIn('missionNamespace setVariable [_x select 0, _x select 1, true]', tuning)
        self.assertLess(tuning.index('if (!isServer)'), tuning.index('call CBA_settings_fnc_set'))

    def test_start_stop_requests_have_only_cba_configuration_authority(self):
        for name, setting in [('cortexInit', 'WAIT_AIPass_Enable'), ('cortexStop', 'WAIT_AIPass_Enable'),
                              ('aiRebalanceInit', 'WAIT_AIRebalance_Enable'), ('aiRebalanceStop', 'WAIT_AIRebalance_Enable')]:
            body = src(name)
            self.assertIn('call WAIT_fnc_CortexTuning', body)
            self.assertNotRegex(body, r'setVariable \["'+setting+r'",[^\n]*true\]')
            self.assertNotIn('RuntimeInit', body)
        init = src('aiRebalanceInit')
        stop = src('aiRebalanceStop')
        self.assertIn('WAIT_AI_RebalanceInitPending', init)
        self.assertIn('WAIT_AI_RebalanceInitPending", false', stop)
        self.assertIn('missionNamespace getVariable ["WAIT_AIRebalance_Mode", "AUTO"]', init)
        post = (ROOT/'addons/main/XEH_postInit.sqf').read_text()
        self.assertIn('(isServer || {!hasInterface})', post)

    def test_effective_settings_completion_precedes_owner_startup(self):
        pre = (ROOT/'addons/main/XEH_preInit.sqf').read_text()
        post = (ROOT/'addons/main/XEH_postInit.sqf').read_text()
        self.assertIn('["CBA_settingsInitialized", {', pre)
        event = pre.index('["CBA_settingsInitialized", {')
        self.assertGreater(pre.index('WAIT_AITweaks_SettingsReady", true'), event)
        self.assertIn('XEH_postInit.sqf', pre[event:])
        self.assertLess(post.index('WAIT_AITweaks_SettingsReady'), post.index('WAIT_AITweaks_PostInitComplete'))
        for name in ['cortexInit', 'aiRebalanceInit']:
            self.assertIn('if !(missionNamespace getVariable ["WAIT_AITweaks_SettingsReady", false]) exitWith', src(name))

    def test_function_registration_has_no_old_tag_alias(self):
        config = (ROOT/'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class WAIT {', config)
        self.assertNotIn('class Waldo {', config)
        for path in (ROOT/'addons').rglob('*.sqf'):
            self.assertNotIn('Waldo_fnc_', path.read_text(encoding='utf-8'), str(path))

class SemanticComponentContracts(unittest.TestCase):
    def test_required_components_have_unique_packaged_prefixes(self):
        main = (ROOT/'addons/main/config.cpp').read_text()
        for component in ['core', 'infantry', 'vehicles', 'aircraft', 'support', 'compatibility']:
            self.assertIn('"WAIT_'+component+'"', main)
            prefix = (ROOT/'addons'/component/'$PBOPREFIX$').read_text().strip()
            self.assertEqual(prefix, 'z\\waldo_ai_tweaks\\addons\\'+component)
        compatibility = (ROOT/'addons/compatibility/config.cpp').read_text()
        self.assertIn('class Waldo_AI_Tweaks_Main', compatibility)

    def test_one_scheduler_implementation_and_all_components_are_scanned(self):
        schedulers = list((ROOT/'addons').rglob('cortexSchedulerTick.sqf'))
        self.assertEqual(len(schedulers), 1)
        self.assertIn('core', schedulers[0].parts)
        validator = (ROOT/'releaseVerificationAndDeployment/sqf_validator.py').read_text()
        self.assertIn("['addons',", validator)

if __name__ == '__main__': unittest.main()

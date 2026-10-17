"""Reject stale packages and incomplete evidence; stage the complete retained audit payload."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from mod_pipeline import ROOT, seal, stage, verify, release_gate, supported_focuses

class PackagePipelineTests(unittest.TestCase):
    def test_road_passing_stage_requires_real_terrain_and_separate_normal_batch(self):
        mission=stage(self.folder,Path(self.temp.name)/'road-pass','roadpassing',world='Altis')
        self.assertEqual(mission.name,'WAIT_Audit.Altis')
        sqm=(mission/'mission.sqm').read_text(encoding='utf-8')
        self.assertIn('A3_Map_Altis',sqm)
        self.assertNotIn('HeadlessClient_F',sqm)
        self.assertIn('cortexQARoadPassing.sqf',(mission/'cortexQAServer.sqf').read_text(encoding='utf-8'))
        self.assertTrue((mission/'cortexQARoadPassing.sqf').is_file())
        self.assertIn('[16600,12800,0]',(mission/'initServer.sqf').read_text(encoding='utf-8'))
        for world,batch in [('VR','normal'),('Altis','headless')]:
            with self.assertRaisesRegex(ValueError,'Altis and a separate normal batch'):
                stage(self.folder,Path(self.temp.name)/f'bad-road-{world}-{batch}','roadpassing',world=world,batch_mode=batch)
        with self.assertRaises(ValueError):
            stage(self.folder,Path(self.temp.name)/'baseline-road','roadpassing',world='Altis',native_baseline=True)

    def test_terrain_building_baseline_uses_altis_mission_identity(self):
        mission=stage(self.folder,Path(self.temp.name)/'terrain-buildings','nativebuildings',native_baseline=True,world='Altis')
        self.assertEqual(mission.name,'WAIT_Audit.Altis')
        sqm=(mission/'mission.sqm').read_text()
        self.assertIn('A3_Map_Altis',sqm)
        self.assertNotIn('A3_Map_VR',sqm)
        self.assertIn('position[]={16600,0,12800}',sqm)
        self.assertEqual(json.loads((mission.parent/'audit-manifest.json').read_text())['world'],'Altis')
        with self.assertRaises(ValueError):
            stage(self.folder,Path(self.temp.name)/'invalid-terrain','all',world='Altis')

    def test_native_building_diagnostics_cannot_promote_wait(self):
        evidence=Path(self.temp.name)/'native-report.json'
        evidence.write_text(json.dumps({'focus':'nativebuildings','status':'PASS','complete':True}))
        with self.assertRaisesRegex(ValueError,'Native building diagnostics'):
            release_gate(self.folder,evidence)

    def test_native_buildings_does_not_start_addon_dependent_runner(self):
        mission=stage(self.folder,Path(self.temp.name)/'native-buildings','nativebuildings',native_baseline=True)
        server=(mission/'initServer.sqf').read_text()
        self.assertIn('cortexQANativeBuildings.sqf',server)
        self.assertNotIn('cortexQAServer.sqf',server)
        runner=(mission/'cortexQANativeBuildings.sqf').read_text()
        self.assertIn('BUILD-NATIVE-addon-absent',runner)
        self.assertIn('[_check,_phase,_wait,true]',runner)
        self.assertIn('cortexQAGuide.sqf',(mission/'initPlayerLocal.sqf').read_text())
        self.assertTrue(json.loads((mission.parent/'audit-manifest.json').read_text())['native_baseline'])
        with self.assertRaises(ValueError):
            stage(self.folder,Path(self.temp.name)/'loaded-buildings','nativebuildings')

    def setUp(self):
        (ROOT/'.test-tmp').mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=ROOT/'.test-tmp')
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)/'package'
        (self.folder/'addons').mkdir(parents=True)
        (self.folder/'addons/main.pbo').write_bytes(b'packaged fixture')
        with patch('mod_pipeline.subprocess.check_output', side_effect=['a'*40+'\n', '']):
            self.record = seal(self.folder)

    def test_changed_deleted_and_added_files_rejected(self):
        pbo = self.folder/'addons/main.pbo'
        pbo.write_bytes(b'changed')
        with self.assertRaises(ValueError): verify(self.folder)
        pbo.unlink()
        with self.assertRaises(ValueError): verify(self.folder)
        pbo.write_bytes(b'packaged fixture')
        (self.folder/'extra.sqf').write_text('extra')
        with self.assertRaises(ValueError): verify(self.folder)

    def test_stage_resolves_every_retained_suite_reference(self):
        mission = stage(self.folder, Path(self.temp.name)/'audit', 'airskills')
        self.assertEqual(len(list(mission.glob('cortexQA*.sqf'))),
                         len(list((ROOT/'releaseVerificationAndDeployment/cortexQA').glob('run*.sqf'))))
        identity = (mission/'auditIdentity.sqf').read_text()
        self.assertIn(self.record['fingerprint'], identity)
        self.assertIn('"airskills"', identity)
        self.assertTrue((mission.parent/'@WaldosAITweaks/addons/main.pbo').is_file())
        with self.assertRaises(ValueError): stage(self.folder, mission.parent, 'airskills')

    def test_standalone_native_stage_has_no_addon_function_dependency(self):
        mission=stage(self.folder,Path(self.temp.name)/'native','standaloneperformance',native_baseline=True)
        manifest=json.loads((mission.parent/'audit-manifest.json').read_text())
        self.assertTrue(manifest['native_baseline'])
        self.assertIn('"WAIT_QA_PerfExpectedLoaded",false',(mission/'auditIdentity.sqf').read_text())
        for name in ('initServer.sqf','initPlayerLocal.sqf','cortexQAStandalonePerformance.sqf'):
            self.assertNotIn('WAIT_fnc_', (mission/name).read_text())
        self.assertIn('WAIT AUDIT OBSERVER ZEUS READY',(mission/'initServer.sqf').read_text())
        self.assertNotIn('HeadlessClient_F',(mission/'mission.sqm').read_text())
        self.assertIn('B_Soldier_F',(mission/'mission.sqm').read_text())
        with self.assertRaises(ValueError):
            stage(self.folder,Path(self.temp.name)/'invalid','airskills',native_baseline=True)

    def test_release_rejects_incomplete_wrong_and_unsigned_evidence(self):
        evidence = Path(self.temp.name)/'results.json'
        for report in ({'status':'PASS', 'complete':False},
                       {'status':'PASS', 'complete':True, 'source_fingerprint':'wrong'},
                       {'status':'PASS', 'complete':True, 'source_fingerprint':self.record['fingerprint']}):
            evidence.write_text(json.dumps(report))
            with self.assertRaises(ValueError): release_gate(self.folder, evidence)

    def test_fsm_is_config_syntax_and_budgeted(self):
        fsm = (ROOT/'addons/main/fsm/tacticalDrill.fsm').read_text()
        self.assertNotIn('\\"', fsm)
        self.assertIn('call WAIT_fnc_CortexQueueJob', fsm)
        self.assertNotIn('class TokenChanged', fsm)
        launcher = (ROOT/'addons/infantry/functions/cortexDrillStart.sqf').read_text()
        self.assertIn('}) exitWith {true};', launcher)

    def test_workflows_inspect_the_packaged_engine_danger_fsm(self):
        for workflow in ('testing.yml','candidate.yml'):
            source=(ROOT/'.github/workflows'/workflow).read_text()
            self.assertIn('hemtt utils config inspect addons/danger/danger.fsm',source)
            self.assertNotIn('addons/infantry/fsm/danger.fsm',source)

    def test_launcher_keeps_packaged_content_and_resolution(self):
        launcher = (ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text()
        for expected in ('-noBattlEye','3840','2160','WAIT AUDIT SERVER READY','StageOnly','@WaldosAITweaks'):
            self.assertIn(expected, launcher)
        self.assertNotIn('Stop-Process', launcher)
        self.assertNotIn('-filePatching', launcher)
        self.assertIn('$manifest.package.dirty -ne $false', launcher)
        self.assertIn("$manifest.package.commit -notmatch '^[0-9a-f]{40}$'", launcher)
        gate=launcher.index('Audit launch requires a clean committed package')
        self.assertGreater(gate, launcher.index('if ($StageOnly)'))
        self.assertLess(gate, launcher.index("$server=Start-AuditProcess"))

        self.assertIn("if ($Interactive) {'Normal'} else {'Hidden'}", launcher)
        self.assertIn("'-name=WAIT_Audit',$modArg) -Interactive", launcher)
        self.assertIn('"-name=WAIT_HC$i"', launcher)
        for option in ('-cfg=$clientConfig', '-x=$ResolutionWidth', '-y=$ResolutionHeight', '-noPause'):
            self.assertIn(option, launcher)
        self.assertIn('ClientReadyTimeoutSeconds=180', launcher)
        self.assertIn("'WAIT AUDIT OBSERVER ZEUS READY'", launcher)
        self.assertIn('this batch is not valid', launcher)
        self.assertIn("$ServerOnly -and $Focus -ne 'dangerload'", launcher)
        self.assertIn('WAIT danger loader diagnostic entered WAIT_Audit.VR server-side', launcher)
        self.assertIn('$stageDefaultDependencies=!$Mods.Count', launcher)
        self.assertIn("Join-Path $stagedMod 'meta.cpp'", launcher)
        self.assertIn("@((Join-Path $runtime '@WaldosAITweaks'))+$launchMods", launcher)

    def test_observer_has_curator_on_join_and_respawn(self):
        server = (ROOT/'releaseVerificationAndDeployment/auditMission/initServer.sqf').read_text()
        self.assertIn('_observer assignCurator _curator', server)
        self.assertNotIn('_curator assignCurator _observer', server)
        self.assertIn('getAssignedCuratorLogic _current != _curator', server)
        self.assertIn('_current assignCurator _curator', server)
        self.assertIn('addCuratorEditableObjects [allUnits + vehicles,true]', server)
        self.assertIn('WAIT_CortexQA_Focus", "all"]) isEqualTo "dangerload"', server)

    def test_phase_observer_placement_preserves_production_distance_gates(self):
        server=(ROOT/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text()
        phase=server.split('private _phase = {')[1].split('private _readyUntil')[0]
        self.assertIn('isPlayer _x',phase)
        self.assertIn('HeadlessClient_F',phase)
        self.assertIn('vehicle _x == _x',phase)
        self.assertIn('remoteExecCall ["setPosATL",_x]',phase)
        self.assertIn('_position getPos [150,225]',phase)
        self.assertNotIn('FarRange',phase)
        self.assertNotIn('allUnits',phase)

    def test_indoor_hc_stage_requires_real_provider_and_installs_owner_helpers(self):
        from stage_headless_provider import REQUIRED
        for mode,provider in [('normal',None),('headless',None)]:
            with self.assertRaisesRegex(ValueError,'real provider'):
                stage(self.folder,Path(self.temp.name)/('invalid-indoor-'+mode),'indooractorshc',batch_mode=mode,headless_provider=provider)
        provider=Path(self.temp.name)/'indoor-provider'
        source=provider/'MissionScripts/Headless'; source.mkdir(parents=True)
        for name in REQUIRED:(source/name).write_text('/* provider contract fixture only */\ntrue;')
        mission=stage(self.folder,Path(self.temp.name)/'indoor-hc','indooractorshc',batch_mode='headless',headless_provider=provider)
        init=(mission/'init.sqf').read_text()
        self.assertIn('compatibilityHeadlessProvider',init)
        self.assertIn('cortexQAPerformanceOwner.sqf',init)
        self.assertIn('cortexQAIndoorActorOwner.sqf',init)
        self.assertTrue((mission/'cortexQAIndoorActorsHC.sqf').is_file())
        manifest=json.loads((mission.parent/'audit-manifest.json').read_text())
        self.assertEqual(manifest['batch_mode'],'headless')
        self.assertEqual(manifest['focus'],'indooractorshc')
        from mod_pipeline import mission_hashes
        self.assertEqual(mission_hashes(mission),manifest['mission_files'])

    def test_focused_indoor_fixture_results_cannot_promote_whole_addon(self):
        evidence=Path(self.temp.name)/'indoor-report.json'
        for focus in ('indooractors','indooractorshc'):
            evidence.write_text(json.dumps({'focus':focus,'status':'PASS','complete':True}))
            with self.assertRaisesRegex(ValueError,'Focused individual indoor fixtures'):
                release_gate(self.folder,evidence)

    def test_indoor_actor_normal_focus_stages_real_payload_and_rejects_hc_mix(self):
        mission=stage(self.folder,Path(self.temp.name)/'indoor-normal','indooractors',batch_mode='normal')
        fixture=(mission/'cortexQAIndoorActors.sqf').read_text()
        self.assertIn('INDOOR-pair-physical-entry',fixture)
        self.assertIn('INDOOR-native-move-handover',fixture)
        self.assertIn('if (_focus == "indooractors") exitWith',(mission/'cortexQAServer.sqf').read_text())
        manifest=json.loads((mission.parent/'audit-manifest.json').read_text())
        self.assertEqual(manifest['focus'],'indooractors')
        self.assertEqual(manifest['batch_mode'],'normal')
        self.assertIn('cortexQAIndoorActors.sqf',manifest['mission_files'])
        with self.assertRaisesRegex(ValueError,'separate batch'):
            stage(self.folder,Path(self.temp.name)/'indoor-invalid-hc','indooractors',batch_mode='headless')

    def test_focuses_follow_real_dispatch_and_invalid_focus_is_rejected(self):
        self.assertIn('performancemixed', supported_focuses())
        self.assertIn('airskills', supported_focuses())
        with self.assertRaises(ValueError): stage(self.folder, Path(self.temp.name)/'bad', 'unknown')

    def test_signed_matching_evidence_and_dirty_commit_gate(self):
        (self.folder/'addons/main.pbo.fixture.bisign').write_bytes(b'signature fixture')
        (self.folder/'keys').mkdir()
        (self.folder/'keys/fixture.bikey').write_bytes(b'public key fixture')
        with patch('mod_pipeline.subprocess.check_output', side_effect=['a'*40+'\n', '']):
            record=seal(self.folder)
        evidence=Path(self.temp.name)/'pass.json'
        evidence.write_text(json.dumps(dict(status='PASS',complete=True,source_fingerprint=record['fingerprint'])))
        release_gate(self.folder, evidence)
        record['dirty']=True
        (self.folder/'wait-build.json').write_text(json.dumps(record))
        with self.assertRaises(ValueError): release_gate(self.folder,evidence)

    def test_optional_policy_is_sealed_staged_and_requires_its_own_signature(self):
        policy=self.folder/'optionals/@waldo_ai_tweaks_turret_aiming/addons/policy.pbo'
        policy.parent.mkdir(parents=True)
        policy.write_bytes(b'optional policy fixture')
        (self.folder/'addons/main.pbo.fixture.bisign').write_bytes(b'core signature fixture')
        (self.folder/'keys').mkdir()
        (self.folder/'keys/fixture.bikey').write_bytes(b'public key fixture')
        evidence=Path(self.temp.name)/'optional-evidence.json'
        def reseal():
            with patch('mod_pipeline.subprocess.check_output', side_effect=['a'*40+'\n','']):
                record=seal(self.folder)
            evidence.write_text(json.dumps(dict(status='PASS',complete=True,source_fingerprint=record['fingerprint'])))
            return record
        record=reseal()
        self.assertIn(policy.relative_to(self.folder).as_posix(),record['files'])
        with self.assertRaisesRegex(ValueError,'signed PBOs'):
            release_gate(self.folder,evidence)
        policy.with_name(policy.name+'.fixture.bisign').write_bytes(b'optional signature fixture')
        reseal()
        release_gate(self.folder,evidence)
        mission=stage(self.folder,Path(self.temp.name)/'optional-stage','all')
        staged=mission.parent/'@WaldosAITweaks'/policy.relative_to(self.folder)
        self.assertEqual(staged.read_bytes(),policy.read_bytes())
        policy.write_bytes(b'changed optional policy')
        with self.assertRaisesRegex(ValueError,'changed after sealing'):
            verify(self.folder)
    def test_normal_and_headless_batches_have_distinct_sealed_identity(self):
        for mode, value in [('normal','false'),('headless','true')]:
            mission=stage(self.folder,Path(self.temp.name)/('batch-'+mode),'all',batch_mode=mode)
            manifest=json.loads((mission.parent/'audit-manifest.json').read_text())
            self.assertEqual(manifest['batch_mode'],mode)
            self.assertIn('"WAIT_CortexQA_HeadlessBatch",'+value,(mission/'auditIdentity.sqf').read_text())
        with self.assertRaisesRegex(ValueError,'dedicated headless batch'):
            stage(self.folder,Path(self.temp.name)/'invalid-normal','lifecycle',headless_provider=Path(self.temp.name))

    def test_native_headless_stage_installs_all_machines_and_seals_provider_files(self):
        from stage_headless_provider import REQUIRED
        provider=Path(self.temp.name)/'provider'
        source=provider/'MissionScripts/Headless'; source.mkdir(parents=True)
        for name in REQUIRED:
            (source/name).write_text('/* native provider fixture */\ntrue;')
        mission=stage(self.folder,Path(self.temp.name)/'native-hc','lifecycle',headless_provider=provider,batch_mode='headless')
        manifest=json.loads((mission.parent/'audit-manifest.json').read_text())
        self.assertEqual(manifest['headless_provider']['scope'],'EXPLICIT_NATIVE_TRANSFERS_ONLY')
        for name in ('initServer.sqf','initPlayerLocal.sqf','init.sqf'):
            self.assertIn(r'compatibilityHeadlessProvider\init.sqf',(mission/name).read_text())
        for name in REQUIRED:
            self.assertIn('compatibilityHeadlessProvider/'+name,manifest['mission_files'])
        from mod_pipeline import mission_hashes
        self.assertEqual(mission_hashes(mission),manifest['mission_files'])
        nested=mission/'compatibilityHeadlessProvider'/REQUIRED[0]
        nested.write_text('modified provider')
        self.assertNotEqual(mission_hashes(mission),manifest['mission_files'])
        with self.assertRaises(ValueError):
            stage(self.folder,Path(self.temp.name)/'invalid-perf','standaloneperformance',headless_provider=provider)

if __name__ == '__main__':
    unittest.main()

"""Reject stale packages and incomplete evidence; stage the complete retained audit payload."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from mod_pipeline import ROOT, seal, stage, verify, release_gate, supported_focuses

class PackagePipelineTests(unittest.TestCase):
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

    def test_launcher_keeps_packaged_content_and_resolution(self):
        launcher = (ROOT/'releaseVerificationAndDeployment/launch_mod_audit.ps1').read_text()
        for expected in ('-noBattlEye','3840','2160','WAIT AUDIT SERVER READY','StageOnly','@WaldosAITweaks'):
            self.assertIn(expected, launcher)
        self.assertNotIn('Stop-Process', launcher)
        self.assertNotIn('-filePatching', launcher)
        self.assertIn("if ($Interactive) {'Normal'} else {'Hidden'}", launcher)
        self.assertIn("'-name=WAIT_Audit',$modArg) -Interactive", launcher)
        for option in ('-cfg=$clientConfig', '-x=$ResolutionWidth', '-y=$ResolutionHeight', '-noPause'):
            self.assertIn(option, launcher)

    def test_observer_has_curator_on_join_and_respawn(self):
        server = (ROOT/'releaseVerificationAndDeployment/auditMission/initServer.sqf').read_text()
        self.assertIn('_observer assignCurator _curator', server)
        self.assertNotIn('_curator assignCurator _observer', server)
        self.assertIn('getAssignedCuratorLogic _current != _curator', server)
        self.assertIn('_current assignCurator _curator', server)
        self.assertIn('addCuratorEditableObjects [allUnits + vehicles,true]', server)

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

if __name__ == '__main__':
    unittest.main()

import copy
import json
from pathlib import Path
import tempfile
import unittest
from report_standalone_performance import read_run, compare

class StandalonePerformanceReportTests(unittest.TestCase):
    def fixture(self,folder,loaded):
        folder.mkdir()
        (folder/'server').mkdir()
        manifest=dict(focus='standaloneperformance',native_baseline=not loaded,resolution=[3840,2160],
                      headlessClients=0,dependencySources=['cba'],package=dict(dirty=False,fingerprint='same'),
                      mission_files={'mission.sqm':'same','cortexQAStandalonePerformance.sqf':'same'})
        (folder/'audit-manifest.json').write_text(json.dumps(manifest))
        identity=[loaded,'z/wait/danger/danger.fsm' if loaded else 'native.fsm',50,300,'INFANTRY_PATROL',2]
        result=[loaded,True,1000,10,20,30,50,300,50,1,True]
        text='WAIT STANDALONE PERF IDENTITY: '+json.dumps(identity)+'\n'
        text+='WAIT STANDALONE PERF RESULT: '+json.dumps(result)+'\nWAIT STANDALONE PERF COMPLETE\n'
        (folder/'server/run.rpt').write_text(text)
        return read_run(folder)

    def test_thresholds_and_scope(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            native=self.fixture(root/'native',False)
            wait=self.fixture(root/'wait',True)
            wait['result'][3:6]=[10.5,22,33]
            self.assertEqual(compare(native,wait)['status'],'PASS')
            wait['result'][4]=22.01
            self.assertEqual(compare(native,wait)['status'],'FAIL')
            self.assertEqual(compare(native,wait)['scope'],'INFANTRY_PATROL_50')

    def test_mismatched_and_dirty_candidates_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            native=self.fixture(root/'native',False)
            wait=self.fixture(root/'wait',True)
            for key,value in [('headlessClients',2),('resolution',[1920,1080]),('dependencySources',['different'])]:
                changed=copy.deepcopy(wait)
                changed['manifest'][key]=value
                with self.assertRaises(ValueError): compare(native,changed)
            wait['manifest']['package']['dirty']=True
            with self.assertRaises(ValueError): compare(native,wait)

    def test_missing_completion_and_dead_observer_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory)/'native'
            self.fixture(folder,False)
            log=folder/'server/run.rpt'
            text=log.read_text()
            log.write_text(text.replace('WAIT STANDALONE PERF COMPLETE',''))
            with self.assertRaises(ValueError): read_run(folder)
            log.write_text(text.replace('50, 300, 50, 1, true','50, 300, 50, 1, false'))
            with self.assertRaises(ValueError): read_run(folder)

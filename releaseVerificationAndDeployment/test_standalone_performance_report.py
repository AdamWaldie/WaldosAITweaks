import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from report_standalone_performance import read_run, compare, main

class StandalonePerformanceReportTests(unittest.TestCase):
    def fixture(self,folder,loaded):
        folder.mkdir()
        (folder/'server').mkdir()
        manifest=dict(focus='standaloneperformance',world='VR',batch_mode='normal',headless_provider=None,native_baseline=not loaded,resolution=[3840,2160],
                      headlessClients=0,performance_composition='infantry',dependencySources=['cba'],package=dict(dirty=False,fingerprint='a'*64),
                      mission_files={'mission.sqm':'b'*64,'cortexQAStandalonePerformance.sqf':'c'*64})
        (folder/'audit-manifest.json').write_text(json.dumps(manifest))
        identity=[loaded,'z/wait/danger/danger.fsm' if loaded else 'native.fsm',50,300,'INFANTRY_PATROL',2]
        result=[loaded,True,1000,10,20,30,50,300,50,1,True]
        text='WAIT STANDALONE PERF IDENTITY: '+json.dumps(identity)+'\n'
        text+='WAIT STANDALONE PERF COMPOSITION: [50,50,0,0,0,0]\n'
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
            for key,value in [('world','Altis'),('batch_mode','headless'),('headless_provider',{'id':'different'})]:
                changed=copy.deepcopy(wait)
                changed['manifest'][key]=value
                with self.assertRaises(ValueError): compare(native,changed)
                del changed['manifest'][key]
                with self.assertRaises(ValueError): compare(native,changed)
            wait['manifest']['package']['dirty']=True
            with self.assertRaises(ValueError): compare(native,wait)

    def test_declared_mixed_run_cannot_report_infantry_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory)/'native'
            self.fixture(folder,False)
            manifest=json.loads((folder/'audit-manifest.json').read_text())
            manifest['performance_composition']='mixed'
            (folder/'audit-manifest.json').write_text(json.dumps(manifest))
            with self.assertRaises(ValueError): read_run(folder)

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

    def test_cli_writes_invalid_evidence_and_fails_for_missing_content(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            self.fixture(root/'native',False)
            self.fixture(root/'wait',True)
            log=root/'native/server/run.rpt'
            log.write_text(log.read_text()+'Warning Message: dependent on downloadable content\n')
            output=root/'result.json'
            with patch('sys.argv',['report',str(root/'native'),str(root/'wait'),'--output',str(output)]), patch('builtins.print'):
                self.assertEqual(main(),1)
            report=json.loads(output.read_text())
            self.assertEqual(report['status'],'INVALID')
            self.assertIn('invalidate',report['reason'])
            self.assertNotIn('median_overhead_percent',report)

    def test_missing_or_wrong_physical_composition_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory)/'native'
            self.fixture(folder,False)
            log=folder/'server/run.rpt'
            original=log.read_text()
            marker='WAIT STANDALONE PERF COMPOSITION: [50,50,0,0,0,0]\n'
            for replacement in ['', 'WAIT STANDALONE PERF COMPOSITION: [50,49,1,0,0,0]\n']:
                log.write_text(original.replace(marker,replacement))
                with self.assertRaises(ValueError): read_run(folder)

    def test_mixed_composition_requires_exact_vehicle_classes(self):
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory)/'native'
            self.fixture(folder,False)
            manifest=json.loads((folder/'audit-manifest.json').read_text())
            manifest['performance_composition']='mixed'
            (folder/'audit-manifest.json').write_text(json.dumps(manifest))
            log=folder/'server/run.rpt'
            original=log.read_text().replace('INFANTRY_PATROL','MIXED_PATROL')
            original=original.replace('[50,50,0,0,0,0]','[50,25,7,8,5,5]')
            log.write_text(original)
            self.assertEqual(read_run(folder)['composition'],[50,25,7,8,5,5])
            log.write_text(original.replace('[50,25,7,8,5,5]','[50,25,8,7,5,5]'))
            with self.assertRaises(ValueError): read_run(folder)

    def test_malformed_provenance_is_invalid_not_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory)/'native'
            self.fixture(folder,False)
            path=folder/'audit-manifest.json'
            original=json.loads(path.read_text())
            mutations=[{'package':{}},{'package':{'dirty':False,'fingerprint':''}},
                       {'package':{'dirty':0,'fingerprint':'a'*64}},
                       {'mission_files':{}},{'mission_files':{'mission.sqm':'same'}},
                       {'mission_files':{'auditIdentity.sqf':'a'*64}},
                       {'mission_files':{'mission.sqm':'a'*64}},
                       {'native_baseline':1}]
            for mutation in mutations:
                changed=copy.deepcopy(original);changed.update(mutation)
                path.write_text(json.dumps(changed))
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    read_run(folder)

    def test_boolean_frame_times_and_malformed_rows_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory)/'native'
            self.fixture(folder,False)
            path=folder/'server/run.rpt';original=path.read_text()
            marker='WAIT STANDALONE PERF RESULT: '
            row=json.loads(next(line.split(marker)[1] for line in original.splitlines() if marker in line))
            invalid=[None,{},'not a result']
            for index in (2,3,4,5,6,7,8,9):
                changed=copy.deepcopy(row);changed[index]=True;invalid.append(changed)
            for result in invalid:
                text='\n'.join(marker+json.dumps(result) if marker in line else line for line in original.splitlines())+'\n'
                path.write_text(text)
                with self.subTest(result=result), self.assertRaises(ValueError):
                    read_run(folder)

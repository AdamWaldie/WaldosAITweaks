"""Compare completed, matched 50-group patrol runs; never establishes full combat acceptance."""
import argparse
import json
import math
from pathlib import Path
import re


def read_run(folder):
    manifest=json.loads((folder/'audit-manifest.json').read_text())
    if not isinstance(manifest,dict) or type(manifest.get('native_baseline')) is not bool:
        raise ValueError('Explicit boolean run role is required')
    package=manifest.get('package')
    fixtures=manifest.get('mission_files')
    digest=lambda value: isinstance(value,str) and re.fullmatch(r'[0-9a-fA-F]{64}',value) is not None
    if not isinstance(package,dict) or package.get('dirty') is not False or not digest(package.get('fingerprint')):
        raise ValueError('Clean candidate with a SHA-256 fingerprint is required')
    if (not isinstance(fixtures,dict) or not {'mission.sqm','cortexQAStandalonePerformance.sqf'} <= fixtures.keys() or any(
            not isinstance(name,str) or not name or not digest(value) for name,value in fixtures.items())):
        raise ValueError('Hashed mission fixture inventory is required')
    logs=list((folder/'server').glob('*.rpt'))
    if len(logs) != 1:
        raise ValueError('Exactly one server RPT is required')
    text=logs[0].read_text(encoding='utf-8-sig',errors='replace')
    if 'WAIT STANDALONE PERF COMPLETE' not in text or 'WAIT STANDALONE PERF INVALID:' in text:
        raise ValueError('Performance run is incomplete or invalid')
    if any(marker in text for marker in ('Error in expression','dependent on downloadable content','Cannot load')):
        raise ValueError('Runtime errors or missing content invalidate the comparison')
    def row(marker):
        lines=[line.split(marker,1)[1] for line in text.splitlines() if marker in line]
        if len(lines) != 1:
            raise ValueError('Exactly one identity and result are required')
        raw=lines[0].strip().rstrip('"').replace('""','"').replace('\\','\\\\')
        return json.loads(raw)
    identity=row('WAIT STANDALONE PERF IDENTITY: ')
    result=row('WAIT STANDALONE PERF RESULT: ')
    composition=row('WAIT STANDALONE PERF COMPOSITION: ')
    if (not isinstance(identity,list) or not isinstance(result,list) or not isinstance(composition,list)
            or len(identity) != 6 or len(result) != 11 or identity[2] != 50
            or identity[4] not in ('INFANTRY_PATROL','MIXED_PATROL')):
        raise ValueError('Unexpected fixture or result schema')
    if (any(type(identity[i]) is not int for i in (2,3,5))
            or any(type(result[i]) is not int for i in (2,6,7,8,9))
            or any(type(value) is not int or value < 0 for value in composition)
            or not isinstance(identity[1],str)):
        raise ValueError('Counts and runtime identity have invalid types')
    scenario={'infantry':'INFANTRY_PATROL','mixed':'MIXED_PATROL'}.get(manifest.get('performance_composition'))
    if scenario != identity[4] or identity[3] <= 0 or (scenario == 'INFANTRY_PATROL' and identity[3] != 300):
        raise ValueError('Scenario declaration or actor count mismatch')
    expected_composition=[50,50,0,0,0,0] if scenario == 'INFANTRY_PATROL' else [50,25,7,8,5,5]
    if composition != expected_composition:
        raise ValueError('Physical vehicle composition mismatch')
    expected=not manifest.get('native_baseline',False)
    if identity[0] is not expected or result[0] is not expected or result[1] is not True:
        raise ValueError('Addon identity or physical fixture failed')
    if expected != ('wait' in identity[1].lower()) or identity[5] != 2:
        raise ValueError('Danger FSM identity or server ownership mismatch')
    if result[2] < 100 or result[6:9] != [50,identity[3],50] or result[9:] != [1,True]:
        raise ValueError('Samples, movement, actor survival or observer validation failed')
    if any(type(value) not in (int,float) or not math.isfinite(value) or value <= 0 for value in result[3:6]):
        raise ValueError('Invalid frame-time measurement')
    if not result[3] <= result[4] <= result[5]:
        raise ValueError('Invalid quantile ordering')
    return dict(manifest=manifest,identity=identity,result=result,composition=composition)


def compare(native,wait):
    a,b=native['manifest'],wait['manifest']
    if a.get('native_baseline') is not True or b.get('native_baseline') is not False:
        raise ValueError('Native and WAIT run roles must differ')
    for key in ('focus','world','batch_mode','headless_provider','resolution','headlessClients','dependencySources','performance_composition'):
        if key not in a or key not in b or a[key] != b[key]:
            raise ValueError(f'Unmatched launch field: {key}')
    if a['world'] != 'VR':
        raise ValueError('Standalone patrol benchmark requires VR terrain')
    if a['focus'] != 'standaloneperformance':
        raise ValueError('Wrong benchmark scope')
    if a['package']['dirty'] or b['package']['dirty'] or a['package']['fingerprint'] != b['package']['fingerprint']:
        raise ValueError('Comparison requires the same clean candidate provenance')
    fixtures=lambda m: {k:v for k,v in m['mission_files'].items() if k != 'auditIdentity.sqf'}
    if fixtures(a) != fixtures(b):
        raise ValueError('Mission fixtures differ')
    if native['identity'][2:5] != wait['identity'][2:5]:
        raise ValueError('Group/actor composition differs')
    overhead=[(wait['result'][i]/native['result'][i]-1)*100 for i in (3,4)]
    return dict(scope=native['identity'][4]+'_50',status='PASS' if overhead[0] <= 5+1e-9 and overhead[1] <= 10+1e-9 else 'FAIL',
                median_overhead_percent=overhead[0],p95_overhead_percent=overhead[1],
                native=native['result'],wait=wait['result'],
                limitation='Patrol only; combat behavior, queue growth and stalled operations remain unaccepted.')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('native',type=Path)
    parser.add_argument('wait',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    try:
        report=compare(read_run(args.native),read_run(args.wait))
    except (ValueError, OSError) as error:
        report=dict(status="INVALID",reason=str(error),native_runtime=str(args.native),wait_runtime=str(args.wait))
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    return 0 if report['status'] == 'PASS' else 1

if __name__ == '__main__':
    raise SystemExit(main())

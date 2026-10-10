"""Compare completed, matched 50-group patrol runs; never establishes full combat acceptance."""
import argparse
import json
import math
from pathlib import Path
import re


def read_run(folder):
    manifest=json.loads((folder/'audit-manifest.json').read_text())
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
    if len(identity) != 6 or len(result) != 11 or identity[2:5] != [50,300,'INFANTRY_PATROL']:
        raise ValueError('Unexpected fixture or result schema')
    expected=not manifest.get('native_baseline',False)
    if identity[0] is not expected or result[0] is not expected or result[1] is not True:
        raise ValueError('Addon identity or physical fixture failed')
    if expected != ('wait' in identity[1].lower()) or identity[5] != 2:
        raise ValueError('Danger FSM identity or server ownership mismatch')
    if result[2] < 100 or result[6:9] != [50,300,50] or result[9:] != [1,True]:
        raise ValueError('Samples, movement, actor survival or observer validation failed')
    if any(not isinstance(value,(int,float)) or not math.isfinite(value) or value <= 0 for value in result[3:6]):
        raise ValueError('Invalid frame-time measurement')
    if not result[3] <= result[4] <= result[5]:
        raise ValueError('Invalid quantile ordering')
    return dict(manifest=manifest,identity=identity,result=result)


def compare(native,wait):
    a,b=native['manifest'],wait['manifest']
    if a.get('native_baseline') is not True or b.get('native_baseline') is not False:
        raise ValueError('Native and WAIT run roles must differ')
    for key in ('focus','resolution','headlessClients','dependencySources'):
        if key not in a or a[key] != b.get(key):
            raise ValueError(f'Unmatched launch field: {key}')
    if a['focus'] != 'standaloneperformance':
        raise ValueError('Wrong benchmark scope')
    if a['package']['dirty'] or b['package']['dirty'] or a['package']['fingerprint'] != b['package']['fingerprint']:
        raise ValueError('Comparison requires the same clean candidate provenance')
    fixtures=lambda m: {k:v for k,v in m['mission_files'].items() if k != 'auditIdentity.sqf'}
    if fixtures(a) != fixtures(b):
        raise ValueError('Mission fixtures differ')
    overhead=[(wait['result'][i]/native['result'][i]-1)*100 for i in (3,4)]
    return dict(scope='INFANTRY_PATROL_50',status='PASS' if overhead[0] <= 5+1e-9 and overhead[1] <= 10+1e-9 else 'FAIL',
                median_overhead_percent=overhead[0],p95_overhead_percent=overhead[1],
                native=native['result'],wait=wait['result'],
                limitation='Patrol only; combat, mixed forces, queue growth and stalled operations remain unaccepted.')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('native',type=Path)
    parser.add_argument('wait',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    report=compare(read_run(args.native),read_run(args.wait))
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    return 0 if report['status'] == 'PASS' else 1

if __name__ == '__main__':
    raise SystemExit(main())

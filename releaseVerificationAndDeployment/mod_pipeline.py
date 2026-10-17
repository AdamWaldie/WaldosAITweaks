"""Package provenance, disposable audit staging and release evidence for WAIT."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tomllib

ROOT = Path(__file__).resolve().parents[1]
ALIASES = {'BuildingComparison': 'Buildings', 'ConvoySeats': 'Seats',
           'ConvoyAvoidance': 'Avoidance', 'FireControl': 'Fire', 'VehicleDrills': 'Vehicles'}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def mission_hashes(folder):
    rows = {}
    for path in sorted(folder.rglob('*')):
        if path.is_symlink():
            raise ValueError(f'Audit content cannot contain links: {path}')
        if path.is_file():
            rows[path.relative_to(folder).as_posix()] = digest(path)
    return rows

def inventory(folder):
    rows = {}
    for path in sorted(folder.rglob('*')):
        if path.is_symlink():
            raise ValueError(f'Packaged content cannot contain links: {path}')
        if path.is_file() and path.name != 'wait-build.json':
            rows[path.relative_to(folder).as_posix()] = digest(path)
    if not any(name.startswith('addons/') and name.endswith('.pbo') for name in rows):
        raise ValueError('No packaged addon PBO found')
    return rows

def seal(folder, root=ROOT):
    rows = inventory(folder)
    git = ['git', '-c', f'safe.directory={root.as_posix()}', '-C', str(root)]
    commit = subprocess.check_output(git + ['rev-parse', 'HEAD'], text=True).strip()
    dirty = bool(subprocess.check_output(git + ['status', '--porcelain'], text=True).strip())
    version = tomllib.loads((root/'.hemtt/project.toml').read_text())['version']
    record = dict(schema=1, commit=commit, dirty=dirty,
                  version='.'.join(str(version[k]) for k in ('major', 'minor', 'patch')),
                  files=rows, fingerprint=hashlib.sha256(json.dumps(rows, sort_keys=True).encode()).hexdigest())
    (folder/'wait-build.json').write_text(json.dumps(record, indent=2)+'\n')
    return record

def verify(folder):
    record = json.loads((folder/'wait-build.json').read_text())
    rows = inventory(folder)
    if rows != record['files'] or record['fingerprint'] != hashlib.sha256(json.dumps(rows, sort_keys=True).encode()).hexdigest():
        raise ValueError('Package changed after sealing; rebuild and stage a fresh audit')
    return record

def supported_focuses(root=ROOT):
    server=(root/'releaseVerificationAndDeployment/cortexQA/runServer.sqf').read_text(encoding='utf-8-sig')
    values=set()
    for array, single in re.findall(r'_focus\s+(?:in\s+(\[[^\]]*\])|==\s*("[^"]+"))', server):
        parsed=json.loads(array or single)
        values.update(parsed if isinstance(parsed, list) else [parsed])
    values.add("standaloneperformance")
    values.add("nativebuildings")
    return sorted(values)

def stage(package, destination, focus, root=ROOT, native_baseline=False, performance_composition="infantry", headless_provider=None, batch_mode="normal", world="VR"):
    if world not in ('VR', 'Altis') or (world != 'VR' and focus not in ('nativebuildings','roadpassing')):
        raise ValueError('Altis supports only nativebuildings or roadpassing')
    if focus == 'roadpassing' and (world != 'Altis' or batch_mode != 'normal'):
        raise ValueError('Road passing requires Altis and a separate normal batch')
    if focus not in supported_focuses(root):
        raise ValueError(f'Unknown audit focus: {focus}')
    if native_baseline and focus not in ('standaloneperformance', 'nativebuildings'):
        raise ValueError('Native baseline requires an addon-independent focus')
    if focus == 'nativebuildings' and not native_baseline:
        raise ValueError('Native building comparison requires addon-absent baseline')
    if performance_composition not in ('infantry','mixed'):
        raise ValueError('Unknown performance composition')
    if batch_mode not in ('normal', 'headless'):
        raise ValueError('Unsupported audit batch mode')
    if focus == 'indooractorshc' and (batch_mode != 'headless' or not headless_provider):
        raise ValueError('Individual indoor HC fixtures require a dedicated headless batch and real provider')
    if focus in ('indooractors','indoornatural') and batch_mode != 'normal':
        raise ValueError('Individual indoor normal fixtures require a separate batch from HC migration')
    if headless_provider and batch_mode != 'headless':
        raise ValueError('Headless providers require a dedicated headless batch')
    if headless_provider and focus == 'standaloneperformance':
        raise ValueError('Native headless integration is separate from server-owned performance')
    record = verify(package)
    if destination.exists():
        raise ValueError('Audit destination already exists; each run needs a fresh directory')
    destination.mkdir(parents=True)
    shutil.copytree(package, destination/'@WaldosAITweaks')
    mission = destination/f'WAIT_Audit.{world}'
    shutil.copytree(root/'releaseVerificationAndDeployment/auditMission', mission)
    for path in (root/'releaseVerificationAndDeployment/cortexQA').glob('run*.sqf'):
        suffix = path.stem[3:]
        shutil.copyfile(path, mission/f'cortexQA{ALIASES.get(suffix, suffix)}.sqf')
    # Preserve the established reporter marker while proving the packaged addon identity.
    (mission/'auditIdentity.sqf').write_text(
        '''/*
 * Author: WaldoTheWarfighter
 * Purpose: Identify the packaged audit and select its batch.
 * Locality: Every audit machine; server publishes focus. Repeat-safe; JIP reads server focus.
 * Arguments: None. Return: Nothing.
 * Callers: audit initServer.sqf and initPlayerLocal.sqf.
 * Example: call compile preprocessFileLineNumbers "auditIdentity.sqf";
 */
'''
        f'diag_log "WAIT CORTEX QA SOURCE|fingerprint={record["fingerprint"]}";\n'
        'diag_log format ["WAIT AUDIT DEPENDENCIES|owner=%1|server=%2|interface=%3|patches=%4|observerClass=%5",clientOwner,isServer,hasInterface,["A3_Characters_F","A3_Characters_F_BLUFOR","A3_Map_VR"] apply {[_x,isClass (configFile >> "CfgPatches" >> _x)]},isClass (configFile >> "CfgVehicles" >> "B_Soldier_F")];\n'
        'diag_log format ["WAIT AUDIT CHARACTER CONFIG|owner=%1|sources=%2|danger=%3|required=%4",clientOwner,["Man","CAManBase","SoldierWB","SoldierEB","SoldierGB","B_Soldier_F"] apply {[_x,configSourceAddonList (configFile >> "CfgVehicles" >> _x)]},getText (configFile >> "CfgVehicles" >> "B_Soldier_F" >> "fsmDanger"),["A3_Characters_F","A3_Characters_F_BLUFOR","WAIT_danger"] apply {[_x,getArray (configFile >> "CfgPatches" >> _x >> "requiredAddons"),count getArray (configFile >> "CfgPatches" >> _x >> "units"),(getArray (configFile >> "CfgPatches" >> _x >> "units")) select [0,8]]}];\n'
        'call {private _activated=activatedAddons apply {toLowerANSI _x}; diag_log format ["WAIT AUDIT ADDON ACTIVATION|owner=%1|patches=%2|observerRequired=%3",clientOwner,["A3_Characters_F","A3_Characters_F_BLUFOR","A3_Map_VR","WAIT_danger"] apply {[_x,(toLowerANSI _x) in _activated]},unitAddons "B_Soldier_F"]};\n'
        f'if (isServer) then {{missionNamespace setVariable ["WAIT_CortexQA_Focus","{focus}",true]; missionNamespace setVariable ["WAIT_CortexQA_HeadlessBatch",{str(batch_mode == "headless").lower()},true]}};\n')
    if focus == 'standaloneperformance':
        for name in ('initServer.sqf', 'initPlayerLocal.sqf', 'mission.sqm'):
            shutil.copyfile(root/'releaseVerificationAndDeployment/standalonePerformance'/name, mission/name)
        with (mission/'auditIdentity.sqf').open('a') as identity:
            identity.write(f'if (isServer) then {{missionNamespace setVariable ["WAIT_QA_PerfExpectedLoaded",{str(not native_baseline).lower()},true]}};\n')
            identity.write(f'if (isServer) then {{missionNamespace setVariable ["WAIT_QA_PerfComposition","{performance_composition}",true]}};\n')
    if focus == 'nativebuildings':
        for name in ('initServer.sqf', 'initPlayerLocal.sqf', 'mission.sqm'):
            shutil.copyfile(root/'releaseVerificationAndDeployment/standalonePerformance'/name, mission/name)
        server_init = mission/'initServer.sqf'
        server_init.write_text(server_init.read_text().replace('cortexQAStandalonePerformance.sqf', 'cortexQANativeBuildings.sqf'), encoding='utf-8')
        with (mission/'initPlayerLocal.sqf').open('a') as client_init:
            client_init.write('\nplayer setCaptive true;\n[] execVM "cortexQAGuide.sqf";\ndiag_log "WAIT CORTEX QA CLIENT COMPLETE: 0 finding(s) []";\n')
    if focus == 'roadpassing':
        # A normal observer mission has no HC slots; keep the addon-dependent audit initializers.
        shutil.copyfile(root/'releaseVerificationAndDeployment/standalonePerformance/mission.sqm',mission/'mission.sqm')
    if world == 'Altis':
        sqm=mission/'mission.sqm'
        sqm.write_text(sqm.read_text(encoding='utf-8').replace('A3_Map_VR','A3_Map_Altis').replace('position[]={5800,0,5800}','position[]={16600,0,12800}'),encoding='utf-8')
        identity=mission/'auditIdentity.sqf'
        identity.write_text(identity.read_text(encoding='utf-8').replace('A3_Map_VR','A3_Map_Altis'),encoding='utf-8')
        if focus == 'roadpassing':
            server_init=mission/'initServer.sqf'
            server_init.write_text(server_init.read_text(encoding='utf-8').replace('[5800,5800,0]','[16600,12800,0]'),encoding='utf-8')
    provider_evidence = None
    if headless_provider:
        from stage_headless_provider import stage_provider
        provider_evidence = stage_provider(headless_provider, mission)
        prefix = r"""/*
 * Author: WaldoTheWarfighter
 * Purpose: Install the real companion HC provider before this audit machine starts its fixtures.
 * Locality/authority: Every machine installs functions; native server transfer authority is retained.
 * Repeat/JIP: Provider-local sentinel coalesces repeated initialization and supports joining HCs.
 * Arguments: None. Return: Nothing. Callers: engine audit initialization.
 * Example: Join the generated native headless integration audit.
 */
call compile preprocessFileLineNumbers "compatibilityHeadlessProvider\init.sqf";
"""
        for name in ('initServer.sqf', 'initPlayerLocal.sqf', 'init.sqf'):
            target = mission/name
            original = target.read_text(encoding='utf-8-sig') if target.exists() else ''
            target.write_text(prefix+original, encoding='utf-8')
    missing = []
    for path in mission.glob('*.sqf'):
        for name in re.findall(r'(?:execVM|preprocessFileLineNumbers)\s+"(cortexQA[^"\\]+\.sqf)"', path.read_text(encoding='utf-8-sig')):
            if not (mission/name).is_file():
                missing.append(name)
    if missing:
        raise ValueError(f'Missing audit payloads: {sorted(set(missing))}')
    (destination/'audit-manifest.json').write_text(json.dumps(dict(package=record, focus=focus, world=world, batch_mode=batch_mode, native_baseline=native_baseline, performance_composition=performance_composition, headless_provider=provider_evidence,
        mission_files=mission_hashes(mission)), indent=2)+'\n')
    return mission

def release_gate(package, evidence):
    record = verify(package)
    report = json.loads(evidence.read_text())
    if report.get('focus') == 'nativebuildings':
        raise ValueError('Native building diagnostics cannot accept a WAIT release')
    if report.get('focus') in ('indooractors','indooractorshc','indoornatural'):
        raise ValueError('Focused individual indoor fixtures cannot accept a WAIT release')
    if record['dirty']:
        raise ValueError('Release requires a clean committed build')
    if report.get('status') != 'PASS' or not report.get('complete'):
        raise ValueError('Release requires completed passing server/client evidence')
    if report.get('source_fingerprint') != record['fingerprint']:
        raise ValueError('Evidence belongs to a different packaged build')
    if any(not list(pbo.parent.glob(pbo.name+'.*.bisign')) for pbo in package.rglob('*.pbo')) or not list((package/'keys').glob('*.bikey')):
        raise ValueError('Release requires signed PBOs and public keys')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    for command in ('seal', 'verify', 'release-gate'):
        child = commands.add_parser(command)
        child.add_argument('package', type=Path)
        if command == 'release-gate':
            child.add_argument('evidence', type=Path)
    child = commands.add_parser('stage')
    child.add_argument('package', type=Path)
    child.add_argument('destination', type=Path)
    child.add_argument('--focus', default='all', choices=supported_focuses())
    child.add_argument('--native-baseline', action='store_true')
    child.add_argument('--world', choices=['VR','Altis'], default='VR')
    child.add_argument('--performance-composition', choices=['infantry','mixed'], default='infantry')
    child.add_argument('--headless-provider', type=Path)
    child.add_argument('--batch-mode', choices=['normal','headless'], default='normal')
    args = parser.parse_args()
    if args.command == 'stage':
        print(stage(args.package.resolve(), args.destination.resolve(), args.focus, native_baseline=args.native_baseline, performance_composition=args.performance_composition, headless_provider=args.headless_provider, batch_mode=args.batch_mode, world=args.world))
    elif args.command == 'seal':
        print(json.dumps(seal(args.package.resolve()), indent=2))
    elif args.command == 'verify':
        print(verify(args.package.resolve())['fingerprint'])
    else:
        release_gate(args.package.resolve(), args.evidence.resolve())
        print('Packaged release evidence verified')

if __name__ == '__main__':
    main()

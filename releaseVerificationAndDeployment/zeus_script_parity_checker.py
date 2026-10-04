#!/usr/bin/env python3
"""Check WAIT's shared CBA/script settings and generated reference."""
import argparse
import json
from pathlib import Path
import re
import sys
ROOT = Path(__file__).resolve().parents[1]
REFERENCE = 'docs/SETTINGS-REFERENCE.md'

def settings(root=ROOT):
    rows=[]
    source=(root/'addons/core/functions/cortexTuningSpec.sqf').read_text()
    arrays={name:json.loads(raw) for name,raw in re.findall(r'private\s+(_\w+)\s*=\s*(\[[^;]+\]);', source) if name in {'_profiles','_profileLabels','_skillProfiles'}}
    arrays['_skillLabels']=arrays['_skillProfiles']
    for line in (root/'addons/core/functions/cortexTuningSpec.sqf').read_text().splitlines():
        if re.match(r'\s*\["WAIT_',line):
            line=re.sub(r'_(?:profiles|profileLabels|skillProfiles|skillLabels)\b', lambda m: json.dumps(arrays[m.group(0)]), line)
            rows.append(json.loads(line.strip().rstrip(',')))
    if not rows:
        raise ValueError('No setting rows parsed')
    return rows

def render(rows):
    text = '# Settings reference\n\n'
    text += ('Generated from `CortexTuningSpec`; edit that source and regenerate this page. '
             'These global options are available through CBA Addon Options. '
             'CBA owns persistence and JIP synchronization. The variable keys remain the script API. '
             'Custom tactical and skill profiles extend the listed built-in choices at runtime. Server validation clamps slider input and rejects unsupported selections.\n\n'
             'Defaults describe configuration, not confirmed behavioural acceptance. See '
             '[current inventory](CURRENT-INVENTORY.md) and [operations](MODDING-AND-OPERATIONS.md) '
             'for validation limits.\n\n'
             'Live controls follow their owner-local update or worker callback. Next-operation controls '
             'are guaranteed for new intent; active work keeps committed destinations and may read safety '
             'values earlier. Restart-required controls need a mission restart. No current runtime option '
             'changes irreversible engine configuration.\n\n'
             '| Variable | Label | Type | Default | Range / choices | Activation | Purpose |\n'
             '| --- | --- | --- | --- | --- | --- | --- |\n')
    for key,label,help_text,kind,options,default,activation in rows:
        fields=[f'`{key}`',label,kind,json.dumps(default),json.dumps(options),activation,help_text]
        text += '| ' + ' | '.join(str(f).replace('|','\\|') for f in fields) + ' |\n'
    return text

def audit(root=ROOT):
    rows=settings(root); problems=[]; seen=set()
    for row in rows:
        key,label,help_text,kind,options,default,activation=row
        if key in seen: problems.append('duplicate setting: '+key)
        seen.add(key)
        if not label.strip() or not help_text.strip(): problems.append('missing setting help: '+key)
        valid = (kind=='CHECKBOX' and isinstance(default,bool) and options==[])
        if kind=='SLIDER': valid=len(options)==3 and options[0]<=default<=options[1]
        if kind=='COMBO': valid=len(options)==2 and len(options[0])==len(options[1]) and default in options[0]
        if not valid: problems.append('invalid setting type/options/default: '+key)
        if activation not in {'LIVE','NEXT_OPERATION','RESTART_REQUIRED'}:
            problems.append('invalid setting activation: '+key)
    for name in ['aiTweaksRegisterSettings.sqf','cortexTuning.sqf']:
        if 'call WAIT_fnc_CortexTuningSpec' not in next((root/'addons').rglob(name)).read_text():
            problems.append('settings consumer bypasses shared specification: '+name)
    config=(root/'addons/main/CfgFunctions.hpp').read_text()
    exports=re.findall(r'class\s+(\w+)\s*\{\s*file\s*=\s*"([^"]+)"',config)
    seen_exports=set()
    for name,raw in exports:
        if name.lower() in seen_exports: problems.append('duplicate function export: '+name)
        seen_exports.add(name.lower())
        path=raw.replace('\\','/').removeprefix('/z/waldo_ai_tweaks/')
        if not (root/path).is_file(): problems.append('missing exported source: '+raw)
    ref=root/REFERENCE
    if not ref.exists() or ref.read_text(encoding='utf-8')!=render(rows):
        problems.append('settings reference is stale; run zeus_script_parity_checker.py --write-reference')
    return problems

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write-reference',action='store_true')
    args=parser.parse_args()
    if args.write_reference: (ROOT/REFERENCE).write_text(render(settings()),encoding='utf-8')
    problems=audit()
    print('\n'.join(problems) if problems else f'CBA/script parity and {len(settings())} documented settings passed')
    sys.exit(bool(problems))

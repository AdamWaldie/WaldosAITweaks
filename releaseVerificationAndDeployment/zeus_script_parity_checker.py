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

def sections(root=ROOT):
    source=(root/'addons/core/functions/aiTweaksSettingsSections.sqf').read_text()
    return [json.loads(line.strip().rstrip(',')) for line in source.splitlines()
            if re.match(r'\s*\["[A-Z_]+"',line)]

def render(rows, layout=None):
    layout = sections() if layout is None else layout
    text = ('# Settings reference\n\n'
            'Generated from `CortexTuningSpec` and `AITweaksSettingsSections`. '
            'CBA pages are numbered by use case, with enable gates before tuning. '
            'Keys, values, defaults and activation policy remain the script and persistence contract. '
            'CBA owns server enforcement and JIP synchronization. Custom profiles extend choices at runtime.\n\n'
            'Live options follow the owner update; next-operation controls preserve committed intent. '
            'Configuration is not behavioural acceptance; see [inventory](CURRENT-INVENTORY.md).\n\n'
            'Vehicle combat and passengers use the Vehicles page. Registered convoy travel, driving and '
            'passengers use the separate Convoys page. Convoy road assistance currently applies only '
            'to registered convoys; it is not a general driving controller.\n\n')
    current_page = None
    for section, page, heading in layout:
        group = [row for row in rows if row[6] == section]
        if not group:
            continue
        if page != current_page:
            text += '## ' + page + '\n\n'
            current_page = page
        text += '### ' + heading + '\n\n'
        text += '| Variable | Label | Type | Default | Range / choices | Activation | Purpose |\n'
        text += '| --- | --- | --- | --- | --- | --- | --- |\n'
        group.sort(key=lambda row: '_Enable' not in row[0])
        for key,label,help_text,kind,options,default,section,activation in group:
            fields=[f'`{key}`',label,kind,json.dumps(default),json.dumps(options),activation,help_text]
            text += '| ' + ' | '.join(str(f).replace('|','\\|') for f in fields) + ' |\n'
        text += '\n'
    return text.rstrip() + "\n"

def audit(root=ROOT):
    rows=settings(root); problems=[]; seen=set()
    layout=sections(root)
    section_keys=[row[0] for row in layout]
    if len(section_keys) != len(set(section_keys)): problems.append("duplicate settings section")
    for row in rows:
        key,label,help_text,kind,options,default,section,activation=row
        if section not in section_keys: problems.append("unknown settings section: "+key)
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
    if not ref.exists() or ref.read_text(encoding='utf-8')!=render(rows,layout):
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

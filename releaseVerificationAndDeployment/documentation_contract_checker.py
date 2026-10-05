#!/usr/bin/env python3
"""WAIT adaptation of WAIT source-header and documentation contracts."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
HEADER = re.compile(r'\s*(?:#include[^\n]*\n\s*)*/\*(.*?)\*/', re.S)
FIELDS = {
    'arguments with types/defaults': r'\bArguments(?:\s+to\s+\w+)?\s*:',
    'return value': r'\bReturn(?:\s+Value)?\s*:',
    'locality/authority': r'\bLocality(?:\s*(?:/|and)\s*Authority)?\s*:',
    'repeat/JIP': r'\bRepeat\s*/\s*JIP\s*:',
    'current callers': r'\b(?:Current\s+Callers?|Called\s+by|Callers?)\s*:',
    'real example': r'\bExample\s*:',
}

def audit_header(source):
    match = HEADER.match(source.lstrip('\ufeff'))
    if not match:
        return ['missing opening documentation block']
    header = match.group(1)
    findings = []
    if not re.search(r'Author:\s*WaldoTheWarfighter\b', header):
        findings.append('author must be WaldoTheWarfighter')
    for label, pattern in FIELDS.items():
        if not re.search(pattern, header, re.I):
            findings.append('missing ' + label)
    # Purpose may be descriptive prose rather than a redundant Purpose: label.
    prose = re.sub(r'^\s*\*?\s*.*?:.*$', '', header, flags=re.M)
    if len(re.findall(r'[A-Za-z]+', prose)) < 3 and not re.search(r'Purpose:\s*\S.+', header):
        findings.append('missing useful purpose description')
    return findings

def local_links(path, root):
    findings = []
    source = re.sub(r'```.*?```', '', path.read_text(encoding='utf-8-sig'), flags=re.S)
    for raw in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', source):
        target = raw.split(' "', 1)[0].strip('<>')
        if re.match(r'^[A-Za-z][A-Za-z0-9+.-]*:', target) or target.startswith('#'):
            continue
        target = unquote(target.split('#', 1)[0])
        resolved = (path.parent / target).resolve()
        if not resolved.is_relative_to(root.resolve()):
            findings.append('local link escapes repository: ' + target)
        elif not resolved.exists():
            findings.append('missing local link/image: ' + target)
    return findings

def audit(root=ROOT):
    findings = []
    scripts = list((root/'addons').rglob('*.sqf')) + list((root/'releaseVerificationAndDeployment/cortexQA').glob('*.sqf')) + list((root/'releaseVerificationAndDeployment/auditMission').glob('*.sqf'))
    for path in sorted(scripts):
        findings.extend(f'{path.relative_to(root)}: {f}' for f in audit_header(path.read_text(encoding='utf-8-sig')))
    for path in [root/'README.md', root/'CONTRIBUTING.md', *sorted((root/'docs').glob('*.md'))]:
        findings.extend(f'{path.relative_to(root)}: {f}' for f in local_links(path, root))
    return findings

if __name__ == '__main__':
    problems = audit()
    print('\n'.join(problems) if problems else 'Source headers and documentation links passed')
    sys.exit(bool(problems))

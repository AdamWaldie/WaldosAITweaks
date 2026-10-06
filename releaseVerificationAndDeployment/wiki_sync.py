#!/usr/bin/env python3
"""Generate GitHub wiki pages from the repository documentation.

docs/ stays the source of truth. `build` writes wiki pages to a folder; the wiki workflow publishes
that folder. `check` builds into a temporary folder and fails on broken wiki-internal links.
"""
from pathlib import Path
import argparse
import re
import sys
import tempfile
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPO = 'https://github.com/AdamWaldie/WaldosAITweaks'
LINK = re.compile(r'(!?\[[^\]]*\]\()([^)\s]+)((?:\s+"[^"]*")?\))')
FENCE = re.compile(r'(```.*?```)', re.S)
# Sidebar sections; generated pages missing here are listed under "More guides".
SECTIONS = [
    ('Start here', ['Home', 'Overview']),
    ('Using WAIT', ['Smart-AI-Pass', 'Waldos-AI-Tweak', 'SETTINGS-REFERENCE']),
    ('Architecture and operations', ['ADDON-LIFECYCLE', 'MODDING-AND-OPERATIONS', 'CAPABILITY-REGISTRY', 'CURRENT-INVENTORY']),
    ('Project status and migration', ['DELIVERY-GOAL', 'IMPLEMENTATION-PROGRESS', 'API-MIGRATION', 'CBA-MIGRATION', 'EXTRACTION-BOUNDARY', 'REFERENCE-BOUNDARY']),
]

def sources(root=ROOT):
    """Map wiki page name to source file. docs/wiki/ holds wiki-only pages such as Home."""
    pages = {'Overview': root/'README.md'}
    for path in sorted((root/'docs').glob('*.md')) + sorted((root/'docs/wiki').glob('*.md')):
        if path.stem in pages:
            raise ValueError(f'duplicate wiki page name {path.stem}: {pages[path.stem]} and {path}')
        pages[path.stem] = path
    if 'Home' not in pages:
        raise ValueError('docs/wiki/Home.md is required for the wiki home page')
    return pages

def title(path, name=None):
    if name in ('Home', 'Overview'):
        return name
    match = re.search(r'^#\s+(.+?)\s*$', path.read_text(encoding='utf-8-sig'), re.M)
    return match.group(1) if match else path.stem.replace('-', ' ')

def rewrite(text, path, pages, root, repo, branch):
    """Point local links at wiki pages, or at the repository for files the wiki does not carry."""
    by_file = {source.resolve(): name for name, source in pages.items()}

    def replace(match):
        prefix, target, suffix = match.groups()
        if re.match(r'^[A-Za-z][A-Za-z0-9+.-]*:', target) or target.startswith('#'):
            return match.group(0)
        file_part, _, anchor = target.partition('#')
        anchor = '#' + anchor if anchor else ''
        resolved = (path.parent / unquote(file_part)).resolve()
        if resolved in by_file:
            return prefix + by_file[resolved] + anchor + suffix
        relative = resolved.relative_to(root.resolve()).as_posix()
        kind = 'tree' if resolved.is_dir() else ('raw' if prefix.startswith('!') else 'blob')
        return f'{prefix}{repo}/{kind}/{branch}/{relative}{anchor}{suffix}'

    # Leave fenced code untouched; link syntax inside examples is literal.
    return ''.join(part if part.startswith('```') else LINK.sub(replace, part) for part in FENCE.split(text))

def sidebar(pages):
    lines = []
    sections = SECTIONS + [('More guides', sorted(set(pages) - {n for _, names in SECTIONS for n in names}))]
    for heading, names in sections:
        names = [name for name in names if name in pages]
        if not names:
            continue
        lines += [f'**{heading}**', '']
        lines += [f'- [{title(pages[name], name)}]({name})' for name in names]
        lines.append('')
    return '\n'.join(lines)

def build(out, root=ROOT, repo=DEFAULT_REPO, branch='main'):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    pages = sources(root)
    for name, path in pages.items():
        text = rewrite(path.read_text(encoding='utf-8-sig'), path, pages, root, repo, branch)
        (out/f'{name}.md').write_text(text, encoding='utf-8')
    (out/'_Sidebar.md').write_text(sidebar(pages), encoding='utf-8')
    (out/'_Footer.md').write_text(
        f'_Generated from [`docs/`]({repo}/tree/{branch}/docs) on `{branch}`. '
        'Edit the repository documentation; direct wiki edits are overwritten on the next sync._\n',
        encoding='utf-8')
    return sorted(pages)

def audit(out, repo=DEFAULT_REPO):
    """Return broken wiki-internal links (errors) and absolute wiki links to absent pages (warnings)."""
    out = Path(out)
    names = {path.stem for path in out.glob('*.md')}
    errors, warnings = [], []
    for path in sorted(out.glob('*.md')):
        text = FENCE.sub('', path.read_text(encoding='utf-8'))
        for _, target, _ in LINK.findall(text):
            page = target.split('#', 1)[0]
            if target.startswith(repo + '/wiki/'):
                page = page[len(repo + '/wiki/'):] or 'Home'
                if page not in names:
                    warnings.append(f'{path.name}: wiki link to missing page {page}')
            elif not re.match(r'^[A-Za-z][A-Za-z0-9+.-]*:', target) and page and page not in names:
                errors.append(f'{path.name}: broken wiki link {target}')
    return errors, warnings

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('mode', choices=['build', 'check'])
    parser.add_argument('out', nargs='?', help='output folder for build')
    parser.add_argument('--repo', default=DEFAULT_REPO, help='repository web URL used for non-wiki links')
    parser.add_argument('--branch', default='main')
    args = parser.parse_args(argv)
    if args.mode == 'build' and not args.out:
        parser.error('build requires an output folder')
    with tempfile.TemporaryDirectory() as temp:
        out = args.out if args.mode == 'build' else temp
        pages = build(out, repo=args.repo, branch=args.branch)
        errors, warnings = audit(out, args.repo)
    for warning in warnings:
        print('warning: ' + warning)
    for error in errors:
        print('error: ' + error)
    if not errors:
        print(f'Wiki generation passed: {len(pages)} pages')
    return bool(errors)

if __name__ == '__main__':
    sys.exit(main())

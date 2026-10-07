"""Wiki generation from docs/: page mapping, link rewriting and broken-link detection."""
from pathlib import Path
import tempfile
import unittest
import wiki_sync as wiki

ROOT = Path(__file__).resolve().parents[1]
REPO = 'https://github.com/example/repo'

class WikiSyncTests(unittest.TestCase):
    def setUp(self):
        folder = ROOT/'.test-tmp'; folder.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=folder)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)/'repo'
        (self.root/'docs/wiki').mkdir(parents=True)
        (self.root/'addons').mkdir()
        (self.root/'README.md').write_text('# Product\n[guide](docs/Guide.md#setup) [contrib](CONTRIBUTING.md)')
        (self.root/'CONTRIBUTING.md').write_text('# Contributing')
        (self.root/'docs/Guide.md').write_text('# Guide\n[back](../README.md) [src](../addons) ![img](shot.png)\n```\n[code](Guide.md)\n```')
        (self.root/'docs/wiki/Home.md').write_text('# Home\n[guide](../Guide.md) [overview](../../README.md)')
        self.out = Path(self.temp.name)/'out'

    def test_repository_documentation_builds_without_broken_wiki_links(self):
        wiki.build(self.out)
        self.assertEqual(wiki.audit(self.out)[0], [])
        self.assertTrue((self.out/'Home.md').read_text().startswith('# Waldos AI Tweaks'))

    def test_rewrites_local_links_to_wiki_pages_and_repository_files(self):
        pages = wiki.build(self.out, root=self.root, repo=REPO)
        self.assertEqual(pages, ['Guide', 'Home', 'Overview'])
        self.assertEqual((self.out/'Overview.md').read_text(), f'# Product\n[guide](Guide#setup) [contrib]({REPO}/blob/main/CONTRIBUTING.md)')
        guide = (self.out/'Guide.md').read_text()
        self.assertIn('[back](Overview)', guide)
        self.assertIn(f'[src]({REPO}/tree/main/addons)', guide)
        self.assertIn(f'![img]({REPO}/raw/main/docs/shot.png)', guide)
        self.assertIn('[code](Guide.md)', guide)
        self.assertEqual((self.out/'Home.md').read_text(), '# Home\n[guide](Guide) [overview](Overview)')
        sidebar = (self.out/'_Sidebar.md').read_text()
        self.assertIn('- [Home](Home)', sidebar)
        self.assertIn('**More guides**', sidebar)
        self.assertIn('- [Guide](Guide)', sidebar)

    def test_requires_custom_home_and_unique_page_names(self):
        (self.root/'docs/wiki/Home.md').unlink()
        with self.assertRaisesRegex(ValueError, 'Home.md is required'):
            wiki.sources(self.root)
        (self.root/'docs/wiki/Home.md').write_text('# Home')
        (self.root/'docs/wiki/Guide.md').write_text('# Duplicate')
        with self.assertRaisesRegex(ValueError, 'duplicate wiki page name Guide'):
            wiki.sources(self.root)

    def test_reports_broken_internal_links_and_warns_on_absent_absolute_pages(self):
        self.out.mkdir()
        (self.out/'Home.md').write_text(f'[gone](Missing) [old]({REPO}/wiki/Old) [ok](Home#top) [web](https://example.com)')
        errors, warnings = wiki.audit(self.out, REPO)
        self.assertEqual(errors, ['Home.md: broken wiki link Missing'])
        self.assertEqual(warnings, ['Home.md: wiki link to missing page Old'])

if __name__ == '__main__':
    unittest.main()

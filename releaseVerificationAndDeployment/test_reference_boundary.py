"""Product reference boundary; technical identifiers are confined to adapters and compatibility tests."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PATTERN = re.compile(r'compatibility|alternativeBackend|external controller|external controller|protocol[_ ]ai|steamcommunity\.com/sharedfiles|pinned[_ ]?down|\bIMS\b|\bWBK\b', re.I)

class ReferenceBoundary(unittest.TestCase):
    def test_product_and_production_have_no_source_references(self):
        files = list((ROOT/'addons').rglob('*')) + list((ROOT/'docs').rglob('*'))
        files += list((ROOT/'releaseVerificationAndDeployment/cortexQA').glob('*.md'))
        files += [ROOT/'README.md',ROOT/'CONTRIBUTING.md',ROOT/'cortex_defaults.md']
        for path in files:
            if not path.is_file() or 'compatibility' in path.parts:
                continue
            if path.suffix not in {'.sqf','.hpp','.cpp','.md','.json'}:
                continue
            self.assertIsNone(PATTERN.search(path.read_text(encoding='utf-8')),str(path.relative_to(ROOT)))

    def test_adapter_state_access_preserves_absent_markers_and_public_writes(self):
        adapter=(ROOT/'addons/compatibility/functions/compatibilityState.sqf').read_text()
        self.assertIn('["_value",nil]',adapter)
        self.assertIn('_entity getVariable [_key,_value]',adapter)
        self.assertIn('_entity setVariable [_key,_value,_public]',adapter)
        self.assertIn('if (_key == "") exitWith {false}',adapter)

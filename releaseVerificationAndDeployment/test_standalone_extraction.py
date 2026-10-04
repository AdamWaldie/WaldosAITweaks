import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class StandaloneExtractionContracts(unittest.TestCase):
    def test_registered_sqf_files_exist_and_document_authority(self):
        functions = (ROOT / "functions.hpp").read_text(encoding="utf-8")
        paths = re.findall(r'file\s*=\s*"([^"]+\.sqf)"', functions)
        self.assertGreater(len(paths), 100)
        for relative in paths:
            path = ROOT / relative.replace("\\", "/")
            self.assertTrue(path.is_file(), relative)
            header = path.read_text(encoding="utf-8")[:8000]
            self.assertIn("Author: WaldoTheWarfighter", header, relative)
            self.assertRegex(header, r"(?i)locality|authority", relative)
            self.assertRegex(header, r"(?i)repeat|JIP", relative)

    def test_bootstrap_replaces_wmp_runtime_dependency(self):
        start = (ROOT / "bootstrap/start.sqf").read_text(encoding="utf-8")
        self.assertIn('MissionConfig\\aiConfig.sqf', start)
        self.assertIn('Waldo_FeatureRuntimeSnapshotReceived", true', start)
        self.assertIn("Waldo_fnc_CortexInit", start)
        self.assertIn("Waldo_fnc_CortexZeusWatchLocal", start)

    def test_wmp_systems_are_outside_the_standalone_tree(self):
        forbidden = ("DynamicAA", "DynamicAO", "Economy", "TransportServices", "Paradrop")
        all_paths = {path.as_posix() for path in ROOT.rglob("*")}
        for subsystem in forbidden:
            self.assertFalse(any(f"/{subsystem}/" in path for path in all_paths), subsystem)

    def test_product_boundary_is_documented(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        for name in ("Dynamic AA", "Dynamic AO", "CBA_A3", "Zeus", "JIP"):
            self.assertIn(name, readme)


if __name__ == "__main__":
    unittest.main()

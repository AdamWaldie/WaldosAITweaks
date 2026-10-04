import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class StandaloneExtractionContracts(unittest.TestCase):
    def test_registered_sqf_files_exist_and_document_authority(self):
        functions = (ROOT / "addons/main/CfgFunctions.hpp").read_text(encoding="utf-8")
        paths = re.findall(r'file\s*=\s*"([^"]+\.sqf)"', functions)
        self.assertGreater(len(paths), 100)
        for relative in paths:
            relative = relative.replace("\\", "/")
            relative = relative.removeprefix("/z/waldo_ai_tweaks/")
            path = ROOT / relative
            self.assertTrue(path.is_file(), relative)
            header = path.read_text(encoding="utf-8")[:8000]
            self.assertIn("Author: WaldoTheWarfighter", header, relative)
            self.assertRegex(header, r"(?i)locality|authority", relative)
            self.assertRegex(header, r"(?i)repeat|JIP", relative)

    def test_cba_xeh_replaces_mission_bootstrap(self):
        config = (ROOT / "addons/main/config.cpp").read_text(encoding="utf-8")
        pre = (ROOT / "addons/main/XEH_preInit.sqf").read_text(encoding="utf-8")
        post = (ROOT / "addons/main/XEH_postInit.sqf").read_text(encoding="utf-8")
        self.assertIn('requiredAddons[] = {"cba_main", "cba_xeh", "zen_main", "lambs_danger", "lambs_wp"}', config)
        self.assertIn("Extended_PreInit_EventHandlers", config)
        self.assertIn("Extended_PostInit_EventHandlers", config)
        self.assertIn("addons\\main\\settings\\aiConfig.sqf", pre)
        self.assertIn('Waldo_AITweaks_SettingsReady", true', pre)
        self.assertIn("Waldo_fnc_CortexInit", post)
        self.assertIn("Waldo_fnc_CortexZeusWatchLocal", post)

    def test_wmp_systems_are_outside_the_standalone_tree(self):
        forbidden = ("DynamicAA", "DynamicAO", "Economy", "TransportServices", "Paradrop")
        all_paths = {path.as_posix() for path in ROOT.rglob("*")}
        for subsystem in forbidden:
            self.assertFalse(any(f"/{subsystem}/" in path for path in all_paths), subsystem)

    def test_production_has_no_wmp_private_system_coupling(self):
        production = "\n".join(
            path.read_text(encoding="utf-8-sig")
            for path in (ROOT / "addons/main").rglob("*")
            if path.suffix in {".sqf", ".hpp"}
        )
        for private_name in (
            "Waldo_DynamicAA_",
            "Waldo_DynamicAO_",
            "Waldo_TransportService_",
            "Waldo_Paradrop_",
            "Waldo_Gunship_",
            "Waldo_ServerOwnedFeature",
        ):
            self.assertNotIn(private_name, production)
        self.assertIn("Waldo_AI_ExternalControl", production)
        self.assertIn("Waldo_AI_PrecisionExclude", production)

    def test_packaging_files_define_one_namespaced_addon(self):
        self.assertTrue((ROOT / ".hemtt/project.toml").is_file())
        self.assertEqual(
            (ROOT / "addons/main/$PBOPREFIX$").read_text(encoding="utf-8").strip(),
            "z\\waldo_ai_tweaks\\addons\\main",
        )
        config = (ROOT / "addons/main/config.cpp").read_text(encoding="utf-8")
        self.assertIn("class Waldo_AI_Tweaks_Main", config)
        self.assertIn("zen_main", config)

    def test_cba_settings_and_compatibility_are_native_addon_services(self):
        pre = (ROOT / "addons/main/XEH_preInit.sqf").read_text(encoding="utf-8")
        functions = (ROOT / "addons/main/CfgFunctions.hpp").read_text(encoding="utf-8")
        settings = (ROOT / "addons/main/functions/aiTweaksRegisterSettings.sqf").read_text(encoding="utf-8")
        compat = (ROOT / "addons/main/functions/aiTweaksDetectCompatibility.sqf").read_text(encoding="utf-8")
        self.assertIn("Waldo_fnc_AITweaksRegisterSettings", pre)
        self.assertIn("Waldo_fnc_AITweaksDetectCompatibility", pre)
        self.assertIn("AITweaksRegisterSettings", functions)
        self.assertIn("CBA_fnc_addSetting", settings)
        self.assertIn("_this] call Waldo_fnc_AITweaksSettingChanged", settings)
        self.assertNotIn("params ['_value']", settings)
        self.assertIn('"zen_main"', (ROOT / "addons/main/config.cpp").read_text(encoding="utf-8"))
        for capability in ("dangerBackend", "alternativeBackend", "meleeBackend", "webKnight", "drivingBackend", "navalBackend"):
            self.assertIn(f'"{capability}"', compat)

    def test_product_boundary_is_documented(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        for name in ("Dynamic AA", "Dynamic AO", "CBA_A3", "Zeus", "JIP"):
            self.assertIn(name, readme)


if __name__ == "__main__":
    unittest.main()

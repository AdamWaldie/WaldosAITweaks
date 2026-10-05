import shutil
import tempfile
import unittest
from pathlib import Path
import documentation_contract_checker as docs
import zeus_script_parity_checker as parity

ROOT=Path(__file__).resolve().parents[1]
class DocumentationContractTests(unittest.TestCase):
    def setUp(self):
        folder=ROOT/'.test-tmp'; folder.mkdir(exist_ok=True)
        self.temp=tempfile.TemporaryDirectory(dir=folder)
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)

    def test_repository_contract(self):
        self.assertEqual(docs.audit(), [])
        self.assertEqual(parity.audit(), [])

    def test_rejects_missing_header_and_machine_author(self):
        self.assertIn('missing opening documentation block',docs.audit_header('true'))
        source=(ROOT/'addons/main/XEH_preInit.sqf').read_text()
        self.assertIn('author must be WaldoTheWarfighter',docs.audit_header(source.replace('WaldoTheWarfighter','Codex')))

    def test_rejects_missing_lifecycle_documentation(self):
        source=(ROOT/'addons/main/XEH_preInit.sqf').read_text()
        self.assertIn('missing repeat/JIP', docs.audit_header(source.replace('Repeat/JIP:','Other:')))

    def test_link_check_ignores_code_and_external_links_but_rejects_missing_images(self):
        p=self.root/'guide.md'; p.write_text('[site](https://example.com)\n```\n[code](missing.md)\n```\n![image](absent.png)')
        self.assertEqual(docs.local_links(p,self.root),['missing local link/image: absent.png'])

    def copy_settings_contract(self):
        shutil.copytree(ROOT/'addons',self.root/'addons')
        (self.root/'docs').mkdir()
        shutil.copyfile(ROOT/parity.REFERENCE,self.root/parity.REFERENCE)

    def test_detects_settings_documentation_drift(self):
        self.copy_settings_contract()
        (self.root/parity.REFERENCE).write_text('stale')
        self.assertTrue(any('stale' in f for f in parity.audit(self.root)))

    def test_detects_duplicate_settings_and_bypassed_shared_spec(self):
        self.copy_settings_contract()
        p=self.root/'addons/core/functions/cortexTuningSpec.sqf'
        s=p.read_text(); s=s.replace('["WAIT_HelicopterDeceleration_Enable",','["WAIT_ImprovedHelicopterLanding_Enable",'); p.write_text(s)
        p=self.root/'addons/core/functions/aiTweaksRegisterSettings.sqf'
        p.write_text(p.read_text().replace('call WAIT_fnc_CortexTuningSpec','call WAIT_fnc_Unrelated'))
        problems=parity.audit(self.root)
        self.assertTrue(any('duplicate setting' in f for f in problems))
        self.assertTrue(any('bypasses' in f for f in problems))

    def test_rejects_unsupported_activation_policy(self):
        self.copy_settings_contract()
        p=self.root/'addons/core/functions/cortexTuningSpec.sqf'
        p.write_text(p.read_text().replace(', "LIVE"]', ', "IMMEDIATE_MAGIC"]', 1))
        self.assertTrue(any('invalid setting activation' in f for f in parity.audit(self.root)))

    def test_rejects_unknown_setting_sections(self):
        self.copy_settings_contract()
        p=self.root/'addons/core/functions/cortexTuningSpec.sqf'
        p.write_text(p.read_text().replace('"CONVOY_TRAVEL", "NEXT_OPERATION"', '"UNLISTED", "NEXT_OPERATION"', 1))
        self.assertTrue(any('unknown settings section' in f for f in parity.audit(self.root)))

    def test_convoy_and_vehicle_use_cases_are_separate_and_complete(self):
        rows=parity.settings()
        layout={row[0]:row[1:] for row in parity.sections()}
        self.assertEqual(8,len({row[0] for row in layout.values()}))
        self.assertEqual(len(rows),sum(sum(row[6]==section for row in rows) for section in layout))
        for row in rows:
            if row[0].startswith('WAIT_Convoy_'):
                self.assertEqual('06 Convoys',layout[row[6]][0])
            if row[0].startswith('WAIT_AIPass_Vehicle'):
                self.assertEqual('05 Vehicles',layout[row[6]][0])
        registration=(ROOT/'addons/core/functions/aiTweaksRegisterSettings.sqf').read_text()
        self.assertLess(registration.index('find "_Enable" >= 0'), registration.index('find "_Enable" < 0'))
        self.assertNotIn('_name find "Convoy"', (ROOT/'addons/core/functions/cortexTuningSpec.sqf').read_text())

    def test_zen_is_optional_and_native_zeus_orders_remain_available(self):
        config=(ROOT/'addons/main/config.cpp').read_text()
        inventory=(ROOT/'docs/CURRENT-INVENTORY.md').read_text()
        readme=(ROOT/'README.md').read_text()
        zen=(ROOT/'addons/main/bootstrap/zenRegister.sqf').read_text()
        self.assertNotIn('zen_main',config.lower())
        self.assertIn('ZEN is optional',inventory)
        self.assertIn('native Zeus orders',inventory)
        self.assertIn('ZEN is optional',readme)
        self.assertIn('isNil "zen_custom_modules_fnc_register"',zen)

    def test_cba_uses_shared_activation_without_a_second_settings_writer(self):
        registration=(ROOT/'addons/core/functions/aiTweaksRegisterSettings.sqf').read_text()
        tuning=(ROOT/'addons/core/functions/cortexTuning.sqf').read_text()
        self.assertIn('_activation == "RESTART_REQUIRED"',registration)
        self.assertIn('Existing operations keep their committed intent',registration)
        self.assertIn('call CBA_settings_fnc_set',tuning)
        self.assertNotIn('CortexSettingsLocal',tuning)
        self.assertFalse((ROOT/'addons/core/functions/cortexSettingsLocal.sqf').exists())
        controls={row[0]:row[-1] for row in parity.settings()}
        self.assertEqual(controls['WAIT_AIPass_TickBudgetMs'],'LIVE')
        self.assertEqual(controls['WAIT_AIPass_Morale_RetreatDistance'],'NEXT_OPERATION')
        self.assertEqual(controls['WAIT_AIPass_InfantryOwnership'],'NEXT_OPERATION')

if __name__=='__main__': unittest.main()

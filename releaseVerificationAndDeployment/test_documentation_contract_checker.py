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

if __name__=='__main__': unittest.main()

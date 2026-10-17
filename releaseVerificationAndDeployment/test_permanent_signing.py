"""Fail closed on absent/malformed signing secrets and untrusted package inventories."""
import base64
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import sign_release as signing

class PermanentSigningTests(unittest.TestCase):
    def test_missing_or_malformed_secret_is_rejected(self):
        for value in (None, '', '{}', '{', json.dumps({'privateKey':'!!!','publicKey':'!!!'})):
            with self.subTest(value=value), self.assertRaises(ValueError):
                signing.decode_pair(value)

    def test_wrong_authority_and_fingerprint_are_rejected(self):
        good=b'WaldoTheWarfighter\0test-public'
        identity=dict(signing.IDENTITY,publicKeySHA256=hashlib.sha256(good).hexdigest())
        with patch.object(signing,'IDENTITY',identity):
            signing.validate_keys(b'WaldoTheWarfighter\0test-private',good)
            for private,public in ((b'Other\0private',good),(b'WaldoTheWarfighter\0private',good+b'changed')):
                with self.assertRaises(ValueError): signing.validate_keys(private,public)

    def test_check_rejects_missing_signatures_and_private_material(self):
        with tempfile.TemporaryDirectory() as folder:
            package=Path(folder); (package/'addons').mkdir(); (package/'keys').mkdir()
            (package/'addons/a.pbo').write_bytes(b'pbo')
            public=b'WaldoTheWarfighter\0test-public'
            (package/'keys/WaldoTheWarfighter.bikey').write_bytes(public)
            identity=dict(signing.IDENTITY,publicKeySHA256=hashlib.sha256(public).hexdigest())
            with patch.object(signing,'IDENTITY',identity):
                with self.assertRaisesRegex(ValueError,'inventory'): signing.check(package,'unused')
                (package/'addons/a.pbo.WaldoTheWarfighter.bisign').write_bytes(b'signature')
                (package/'leak.biprivatekey').write_bytes(b'forbidden')
                with self.assertRaisesRegex(ValueError,'private material'): signing.check(package,'unused')

    def test_pin_includes_ordering_and_compiled_sqf_fixes(self):
        patch_text=(signing.ROOT/'releaseVerificationAndDeployment/armake2-sorted-signing.patch').read_text()
        self.assertIn('files_sorted.sort_by_key',patch_text)
        self.assertIn('ext != "sqfc"',patch_text)
        self.assertEqual(signing.IDENTITY['publicKeySHA256'],'297f847320561498d0c04e8db2e0570f60b770f1f932adcdcc20c45c2275c889')
    def test_signing_preserves_build_provenance_instead_of_current_checkout(self):
        with tempfile.TemporaryDirectory() as folder:
            package=Path(folder); (package/'addons').mkdir()
            (package/'addons/a.pbo').write_bytes(b'packed-source')
            source={'schema':1,'commit':'original-build-commit','dirty':True,'version':'0.1.0','files':{},'fingerprint':'old'}
            result=signing.seal_signed(package,source)
            self.assertEqual(result['commit'],'original-build-commit')
            self.assertTrue(result['dirty'])
            self.assertEqual(result['version'],'0.1.0')
            self.assertNotEqual(result['fingerprint'],'old')
            self.assertEqual(signing.verify(package),result)
            self.assertEqual(source['fingerprint'],'old')

    def test_unsigned_optional_pbo_cannot_pass_main_addon_inventory(self):
        with tempfile.TemporaryDirectory() as folder:
            package=Path(folder); (package/'addons').mkdir(); (package/'keys').mkdir()
            (package/'addons/main.pbo').write_bytes(b'main')
            (package/'addons/main.pbo.WaldoTheWarfighter.bisign').write_bytes(b'signature')
            optional=package/'optionals/@policy/addons'; optional.mkdir(parents=True)
            (optional/'policy.pbo').write_bytes(b'optional')
            public=b'WaldoTheWarfighter\0public'
            (package/'keys/WaldoTheWarfighter.bikey').write_bytes(public)
            identity=dict(signing.IDENTITY,publicKeySHA256=hashlib.sha256(public).hexdigest())
            with patch.object(signing,'IDENTITY',identity), patch.object(signing.subprocess,'run') as tool:
                with self.assertRaisesRegex(ValueError,'inventory'): signing.check(package,'unused')
                tool.assert_not_called()

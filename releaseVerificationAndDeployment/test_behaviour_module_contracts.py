"""Review gate for behaviour modules; this is not a semantic or runtime proof.

New native/optional modules must update the reviewed inventory and task contract.
CBA remains the configuration surface. Task parameters are deliberately allowed.
"""
import json
import re
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def module_inventory(config, registration):
    config = re.sub(r'/\*.*?\*/|//[^\n]*', '', config, flags=re.S)
    declarations = re.findall(r'class\s+(\w+)\s*:\s*(\w+)\s*\{', config)
    parents = dict(declarations)
    def is_module(name):
        seen = set()
        while name in parents and name not in seen:
            seen.add(name)
            name = parents[name]
            if name == 'Module_F':
                return True
        return False
    native = {name for name in parents if is_module(name)}
    zen = set(re.findall(r'\[\s*"[^"]+"\s*,\s*"([^"]+)"', registration))
    return native, zen


def validate_contracts(root):
    record = json.loads((root/'releaseVerificationAndDeployment/behaviour_module_contracts.json').read_text())
    config = '\n'.join(p.read_text(encoding='utf-8-sig') for p in (root/'addons').rglob('*') if p.suffix in ('.cpp', '.hpp'))
    registration = '\n'.join(p.read_text(encoding='utf-8-sig') for p in (root/'addons').rglob('*.sqf') if 'zen_custom_modules_fnc_register' in p.read_text(encoding='utf-8-sig'))
    native, zen = module_inventory(config, registration)
    errors = []
    if record.get('configuration_surface') != 'CBA':
        errors.append('Addon configuration belongs in CBA')
    if native != set(record['native_classes']) or zen != set(record['zen_labels']):
        errors.append('Module inventory changed: review behaviour contracts before exposing new controls')
    for contract in record['contracts']:
        for key in ('behaviour', 'target', 'parameters', 'handlers', 'executor', 'authority', 'termination', 'guide', 'physical_acceptance'):
            if not contract.get(key):
                errors.append(f'Missing task contract field: {key}')
        for path in contract['handlers']:
            source = (root/path).read_text()
            if contract['executor'] not in source:
                errors.append(f'Handler has no declared task dispatch: {path}')
            if re.search(r'CBA_fnc_(?:addSetting|setSetting)|WAIT_fnc_CortexTuning|WAIT_fnc_DrivingControl', source, re.I):
                errors.append(f'Settings control in behaviour handler: {path}')
        if not (root/contract['guide']).is_file():
            errors.append('Missing behaviour guide')
    return errors


class BehaviourModuleContractTests(unittest.TestCase):
    def test_current_modules_have_reviewed_behaviour_contracts(self):
        self.assertEqual(validate_contracts(ROOT), [])

    def test_inventory_detects_new_modules_and_inherited_variants(self):
        native, zen = module_inventory('''class NewTask: Module_F { };
            class Variant: NewTask {}; class Unrelated: Thing {};''',
            '["Waldos AI Tweaks", "New task", {}] call zen_custom_modules_fnc_register;')
        self.assertEqual(native, {'NewTask', 'Variant'})
        self.assertEqual(zen, {'New task'})

    def test_settings_module_would_change_reviewed_inventory(self):
        config = (ROOT/'addons/main/config.cpp').read_text()
        registration = (ROOT/'addons/main/bootstrap/zenRegister.sqf').read_text()
        before = module_inventory(config, registration)
        after = module_inventory(config+'\nclass WAIT_ModuleDrivingEnable: Module_F {};',
                                 registration+'\n["Waldos AI Tweaks", "Driving: enable", {}];')
        self.assertNotEqual(before, after)


if __name__ == '__main__':
    unittest.main()


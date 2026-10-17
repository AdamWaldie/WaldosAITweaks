"""Defence modules must dispatch real scoped tasks; offline wiring is not physical acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def src(name): return (ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text()
class DefendModuleTests(unittest.TestCase):
    def test_dialog_parameters_are_sent_validated_and_consumed(self):
        zen=src('zenDefendModule'); dispatch=src('cortexOrderDispatch'); local=src('cortexOrderLocal')
        for key in ('width','facing'):
            self.assertIn('["'+key+'",round _'+key+']',zen)
            self.assertIn('getOrDefault ["'+key+'",',dispatch)
            self.assertIn('getOrDefault ["'+key+'",',local)
        self.assertIn('["order","DEFEND"]',zen)
        self.assertIn('(_width max 15) min 150',dispatch)
        self.assertIn('((_facing mod 360)+360) mod 360',dispatch)
        self.assertIn('case "DEFEND": {[_group, _position, _facing, (_width max 15) min 150]',local)
    def test_native_defence_reuses_authenticated_task_path(self):
        module=src('moduleGarrison'); config=(ROOT/'addons/main/config.cpp').read_text()
        self.assertIn('WAIT_operation = "DEFEND"',config)
        self.assertIn('class WAIT_ModuleDefend: WAIT_ModuleGarrison',config)
        self.assertIn('call WAIT_fnc_ZenDefendModule',module)
        self.assertIn('["order",_order]',module)
        self.assertIn('["width",60]',module)
        self.assertIn('call WAIT_fnc_CortexOrderDispatch',module)
        self.assertNotIn('nearestObjects',module)
    def test_task_controls_do_not_mutate_addon_settings(self):
        zen=src('zenDefendModule')
        self.assertIn('[15,150,60,0]',zen)
        self.assertNotIn('CBA_settings_fnc_set',zen)
        self.assertNotIn('setVariable ["WAIT_AIPass_',zen)
        self.assertNotIn('setPosATL',zen)
if __name__=='__main__': unittest.main()

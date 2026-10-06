"""Static safeguards for bounded squad communication fallbacks."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(name: str) -> str:
    matches = list(ROOT.glob(f"addons/**/functions/{name}.sqf"))
    if len(matches) != 1:
        raise AssertionError(f"Expected one source for {name}, got {matches}")
    return matches[0].read_text(encoding="utf-8")


class GroupCommunicationTests(unittest.TestCase):
    def test_group_transmitter_prefers_leader_but_falls_back_to_a_living_wingman(self):
        transmitter = source("cortexGroupTransmitter")
        self.assertIn('private _leader = leader _group;', transmitter)
        self.assertIn('_members = [_leader] + (_members - [_leader]);', transmitter)
        self.assertIn('(_members select [0, 12])', transmitter)
        self.assertIn('[_x] call WAIT_fnc_CortexCanTransmit', transmitter)
        for forbidden in ['reveal ', 'doMove', 'doFollow', 'setVariable']:
            self.assertNotIn(forbidden, transmitter)

    def test_coordination_uses_group_communication_without_creating_target_knowledge(self):
        callers = [
            'cortexSupportServer', 'cortexSupportApply', 'cortexSupportAssaultServer',
            'cortexReinforce', 'cortexCombinedArmsServer', 'cortexReportServer',
            'cortexReportLocal', 'cortexArtilleryFire', 'cortexRetreat',
        ]
        for caller in callers:
            self.assertIn('WAIT_fnc_CortexGroupTransmitter', source(caller), caller)
        report = source('cortexReportServer')
        self.assertIn('private _transmitter = [_sender] call WAIT_fnc_CortexGroupTransmitter;', report)
        self.assertIn('private _senderPosition = getPosATL ([_transmitter, leader _sender] select isNull _transmitter);', report)
        self.assertIn('leader _x distance2D _senderPosition <= _range', report)
        self.assertIn('leader _receiver distance2D _senderPosition > _range', source('cortexReportLocal'))
        self.assertNotIn(' reveal ', report)
        self.assertNotIn('doTarget', report)

    def test_group_transmitter_is_registered_as_a_wait_function(self):
        config = (ROOT / 'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class CortexGroupTransmitter', config)
        self.assertIn('cortexGroupTransmitter.sqf', config)


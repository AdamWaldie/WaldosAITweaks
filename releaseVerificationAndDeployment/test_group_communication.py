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
        report_local = source('cortexReportLocal')
        self.assertIn('private _transmitter = [_sender] call WAIT_fnc_CortexGroupTransmitter;', report)
        self.assertIn('private _senderPosition = getPosATL ([_transmitter, leader _sender] select isNull _transmitter);', report)
        self.assertIn('leader _x distance2D _senderPosition <= _range', report)
        self.assertIn('private _receiverTransmitter = [_receiver] call WAIT_fnc_CortexGroupTransmitter;', report_local)
        self.assertIn('private _receiverPosition = getPosATL ([_receiverTransmitter, leader _receiver] select isNull _receiverTransmitter);', report_local)
        self.assertIn('_receiverPosition distance2D _senderPosition > _range', report_local)
        self.assertNotIn(' reveal ', report)
        self.assertNotIn('doTarget', report)

    def test_support_and_combined_arms_use_live_communication_anchors(self):
        support = source('cortexSupportServer')
        apply = source('cortexSupportApply')
        step = source('cortexSupportStep')
        assault = source('cortexSupportAssaultServer')
        combined = source('cortexCombinedArmsServer')
        self.assertIn('private _requesterPosition=getPosATL _requesterTransmitter;', support)
        self.assertIn('_candidateTransmitter distance2D _requesterPosition', support)
        self.assertIn('_groupTransmitter distance2D _requesterTransmitter', apply)
        self.assertIn('private _requesterTransmitter = [_requester] call WAIT_fnc_CortexGroupTransmitter;', step)
        self.assertIn('private _helperTransmitter = [_helper] call WAIT_fnc_CortexGroupTransmitter;', step)
        self.assertIn('private _supportOrigin=getPosATL _requesterTransmitter;', assault)
        self.assertIn('private _routeOrigin=getPosATL _helperTransmitter;', assault)
        self.assertIn('private _requesterAnchor=if (isNull _requesterTransmitter)', combined)
        self.assertIn('_candidateAnchor distance2D _requesterAnchor', combined)

    def test_group_transmitter_is_registered_as_a_wait_function(self):
        config = (ROOT / 'addons/main/CfgFunctions.hpp').read_text(encoding='utf-8')
        self.assertIn('class CortexGroupTransmitter', config)
        self.assertIn('cortexGroupTransmitter.sqf', config)


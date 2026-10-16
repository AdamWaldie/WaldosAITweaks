"""Keep complete CI at review boundaries without duplicate development builds."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ActionsUsagePolicyTests(unittest.TestCase):
    def test_only_main_push_and_ready_prs_auto_validate_with_manual_draft_escape(self):
        s=(ROOT/'.github/workflows/testing.yml').read_text()
        trigger=s.split('on:',1)[1].split('concurrency:',1)[0]
        self.assertIn('push:\n    branches: [main]',trigger)
        self.assertIn('pull_request:\n    branches: [main]',trigger)
        self.assertIn('ready_for_review',trigger)
        self.assertIn('workflow_dispatch:',trigger)
        self.assertIn("github.event_name != 'pull_request' || github.event.pull_request.draft == false",s)
        self.assertIn('github.event.pull_request.number || github.ref',s)
        self.assertIn('cancel-in-progress: true',s)
        self.assertIn('timeout-minutes: 30',s)
        self.assertIn('retention-days: 7',s)
        for gate in ('python -m unittest discover','sqf_validator.py','config_style_checker.py',
                     'documentation_contract_checker.py','wiki_sync.py check','zeus_script_parity_checker.py',
                     'performance_audit.py','check_cortex_coverage.py','hemtt build --no-bin',
                     'mod_pipeline.py seal'):
            self.assertIn(gate,s)
    def test_release_and_candidate_stay_deliberate(self):
        candidate=(ROOT/'.github/workflows/candidate.yml').read_text()
        deploy=(ROOT/'.github/workflows/deploy.yml').read_text()
        self.assertIn('workflow_dispatch:',candidate)
        self.assertIn('types: [published]',deploy)

    def test_hemtt_installer_uses_authenticated_release_api(self):
        for filename in ('testing.yml','candidate.yml','deploy.yml'):
            source=(ROOT/'.github/workflows'/filename).read_text()
            self.assertIn('GITHUB_TOKEN: ${{ github.token }}',source)

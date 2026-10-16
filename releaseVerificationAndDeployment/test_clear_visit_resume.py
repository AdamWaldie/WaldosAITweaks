"""CQB historical participation survives only its original task and room topology."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def source(name):
    return (ROOT/'addons/infantry/functions'/f'{name}.sqf').read_text(encoding='utf-8')

class ClearVisitResumeTests(unittest.TestCase):
    def test_adoption_requires_episode_actor_and_exact_room_identity(self):
        text=source('cortexClearBuilding')
        block=text.split('// Historical individual visits survive owner adoption.',1)[1].split('// Adopt a transform/episode-bound exit journal',1)[0]
        for gate in ['if (_resume)', '(_receipt select 0) isEqualTo _group',
                     '(_receipt select 1) isEqualTo _visitContext', '_index in _cleared',
                     '(_x select 1) isEqualTo (_positions select _index)',
                     'count (_receipt select 2) <= 512', '_team select [0,8]']:
            self.assertIn(gate,block)
        self.assertNotIn('doMove',block)
        self.assertNotIn('setPos',block)
        self.assertIn('_job set ["actorVisits",_actorVisits]',block)
        self.assertIn('_job set ["enteredActors",_enteredActors]',block)

    def test_new_tasks_cannot_reuse_old_receipts(self):
        text=source('cortexClearBuilding')
        self.assertIn('if (!_resume || {!(_visitContext isEqualType [])} || {count _visitContext != 4}',text)
        self.assertIn('clientOwner,diag_tickTime,_generation',text)
        self.assertIn('_visitBase=[_building,_job get "buildingTransform",_hardDeadline]',text)

    def test_publish_coalesces_only_new_physical_observations(self):
        text=source('buildingOperationStep')
        observation=text.split('if (_atPosition) then {',1)[1].split('if !(_positionIndex in _cleared)',1)[0]
        self.assertIn('if !(_positionIndex in _visited)',observation)
        self.assertIn('_visitChangedActors pushBackUnique _visitor',observation)
        publish=text.split('// Coalesce physical observations',1)[1].split('// Claimed rooms',1)[0]
        self.assertIn('call _mayIssueMovement',publish)
        self.assertIn('local _actor && {group _actor == _group}',publish)
        self.assertIn('_visitChangedActors select [0,8]',publish)
        self.assertIn('_visits select [0,512]',publish)
        self.assertGreater(text.index('// Coalesce physical observations'),text.index('} forEach _visitWorkers;'))

if __name__=='__main__':unittest.main()

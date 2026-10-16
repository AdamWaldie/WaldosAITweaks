"""Road observation boundaries and speed policy; no native steering acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class DrivingRoadCapTests(unittest.TestCase):
    def test_shared_observer_is_bounded_read_only_and_absolute(self):
        s=(ROOT/'addons/vehicles/functions/drivingRoadCap.sqf').read_text(encoding='utf-8')
        for marker in ('from 1 to 8','count _allConnected > 16','_road in _visited',
                       '_travel >= 70','[_road] call _readRoadGeometry','[_nextRoad] call _readRoadGeometry','_cap=_cap min 15'):
            self.assertIn(marker,s)
        executable=s.split('params [[',1)[1]
        for forbidden in ('forceSpeed','doMove','setCurrentWaypoint','setDriveOnPath',
                          'addWaypoint','createVehicle','spawn','waitUntil','setVariable'):
            self.assertNotIn(forbidden,executable)
        self.assertEqual(s.count('nearRoads'),1)
    def test_grade_uses_asl_road_endpoints_including_within_piece_slope(self):
        s=(ROOT/'addons/vehicles/functions/drivingRoadCap.sqf').read_text(encoding='utf-8')
        geometry=s.split('private _readRoadGeometry={',1)[1].split('if (!isNull _road)',1)[0]
        for gate in ['getRoadInfo _piece', '_info param [6,[],[[]]]', '_info param [7,[],[[]]]',
                     '(_begin vectorAdd _end) vectorMultiply 0.5',
                     'abs ((_end select 2)-(_begin select 2))/_length',
                     'if (_bridge) exitWith {[[],0,false]}', 'finite _x']:
            self.assertIn(gate,geometry)
        self.assertNotIn('getTerrainHeightASL',geometry)
        self.assertNotIn('set [2,0]',geometry)
        self.assertIn('_maximumGrade max (_roadGeometry select 1)',s)
        self.assertIn('_maximumGrade max (_nextGeometry select 1)',s)
        self.assertIn('if (!(_nextGeometry select 2)) exitWith {_overBudget=true}',s)

    def test_both_modes_consume_the_observer_before_owned_speed_commands(self):
        ordinary=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        convoy=(ROOT/'addons/vehicles/functions/convoyTick.sqf').read_text(encoding='utf-8')
        self.assertLess(ordinary.index('call WAIT_fnc_DrivingRoadCap'),ordinary.index('_vehicle forceSpeed _capMps'))
        self.assertIn('_cap=_cap min (_roadObservation select 0)',ordinary)
        self.assertIn('["roadLookAt",time+3]',convoy)
        self.assertIn('["roadAssist",_roadObservation]',convoy)
        self.assertEqual(convoy.count('call WAIT_fnc_DrivingRoadCap'),1)
    def test_policy_never_raises_requested_or_existing_lower_speed(self):
        def cap(requested,turn,grade,junction,dense=False):
            result=min(120,max(0,requested))
            if turn>70:result=min(result,18)
            elif turn>45:result=min(result,25)
            elif turn>25:result=min(result,35)
            if junction:result=min(result,30)
            if grade>0.2:result=min(result,18)
            elif grade>0.12:result=min(result,25)
            if dense:result=min(result,15)
            return result
        for requested in (0,5,15,30,70,120):
            for turn in (0,25,26,45,46,70,71):
                for grade in (0,0.12,0.13,0.2,0.21):
                    for junction in (False,True):
                        self.assertLessEqual(cap(requested,turn,grade,junction),requested)
        self.assertEqual(cap(70,71,0,False),18)
        self.assertEqual(cap(70,0,0.21,False),18)
        self.assertEqual(cap(5,71,0.21,True),5)
        self.assertEqual(cap(70,0,0,False,True),15)
if __name__=='__main__':unittest.main()

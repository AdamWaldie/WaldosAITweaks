"""Pedestrian safety policy regressions; native braking remains unverified."""
import math
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class PedestrianSpeedTests(unittest.TestCase):
    def test_braking_envelope_stops_at_bumper_and_never_raises_request(self):
        def cap(request,gap,mass):
            a=4/min(2.5,max(1,1+(mass-3000)/7000))
            room=max(0,gap-3)
            return min(request,max(0,math.sqrt((4*a)**2+2*a*room)-4*a)*3.6)
        for mass in (1000,10000,40000):
            for request in (0,1,3,5,30,70,120):
                self.assertEqual(cap(request,2,mass),0)
                values=[cap(request,gap,mass) for gap in (0,3,5,10,30,100)]
                self.assertEqual(values,sorted(values))
                self.assertTrue(all(0<=v<=request for v in values))
        self.assertLess(cap(70,30,40000),cap(70,30,1000))
    def test_shared_owner_path_and_recovery_suppression(self):
        s=(ROOT/'addons/vehicles/functions/drivingAssistStart.sqf').read_text(encoding='utf-8')
        self.assertIn('[_vehicle,_capMps*3.6,_group,true,_travelIntent] call WAIT_fnc_CortexInfantrySpeed',s)
        self.assertLess(s.index('private _pedestrianCap='),s.index('_vehicle forceSpeed _capMps'))
        self.assertIn('_traffic=[_pedestrianCap/3.6,_vehicle,-1,time,0]',s)
        self.assertIn('if ((_trafficLimited && {!_solidCandidate}) || {_corridorActive} || {_hadCorridor} || {_bypassActive} || {_hadBypass}) then {',s)
        self.assertIn('if (_recoveryStage != 2) then {',s)
        self.assertIn('RECOVERY_PAUSED',s)
        self.assertIn('if (_recoveryStage != 2 && {!_trafficLimited} && {!_corridorActive} && {!_hadCorridor} && {!_bypassActive} && {!_hadBypass} && {_vehicle distance2D',s)
    def test_hull_geometry_and_bounded_read_only_observation(self):
        s=(ROOT/'addons/infantry/functions/cortexInfantrySpeed.sqf').read_text(encoding='utf-8')
        for marker in ('count _people > 32','min 250','_person modelToWorld',
                       '_vehicle worldToModel','_maxZ >=','_minZ <=','-_low','_minY-_edge-3'):
            if marker=='-_low': marker='-(_low select 1)'
            self.assertIn(marker,s)
        executable=s.split('params [[',1)[1]
        for forbidden in ('forceSpeed','doMove','spawn','setVariable','waitUntil'):
            self.assertNotIn(forbidden,executable)
        self.assertEqual(s.count('nearEntities'),1)
if __name__=='__main__':unittest.main()

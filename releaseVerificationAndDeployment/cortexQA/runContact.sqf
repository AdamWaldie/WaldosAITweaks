/*
 * Author: WaldoTheWarfighter
 * Tests explicit fire-discipline preservation, a real targetless explosion reflex with physical
 * cover, exact release, danger during committed movement, close-contact persistence, active Zeus
 * replacement and leader loss, then
 * real occlusion, physical exposure, sight loss, post-contact flow and reacquisition without injected
 * knowledge, including live contact interrupting an active search.
 * Locality/authority: scheduled server audit; both fixture groups pinned against HC distributors.
 * Repeat/JIP: fresh actors and walls; public visual targets; removes only its own fixtures.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>; required audit callbacks.
 * Return: Nothing. Current caller: cortexQAServer.sqf.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAContact.sqf";
 */
params ["_check","_phase","_wait"];
// A projectile created with createVehicle has no firing actor and does not reliably enter Arma's
// native danger queue. Fire a real hand grenade from an excluded hostile actor, capture the
// engine-created projectile, then place that already-attributed shot above the fixture. WAIT state
// is never injected by the audit. The temporary firer remains alive through the fuse and is cleaned
// after the engine has delivered the explosion.
private _spawnRealGrenade={
    params [["_position",[0,0,0],[[]]]];
    private _sourceGroup=createGroup [west,true];
    _sourceGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _sourceGroup setVariable ["acex_headless_blacklist",true,true];
    _sourceGroup setVariable ["WAIT_AIPass_Exclude",true,true];
    _sourceGroup setCombatMode "BLUE";
    private _sourcePosition=+_position;
    _sourcePosition set [2,0];
    _sourcePosition=_sourcePosition getPos [80,0];
    private _source=_sourceGroup createUnit ["B_Soldier_F",_sourcePosition,[],0,"NONE"];
    _source allowDamage false;
    _source hideObjectGlobal true;
    _source disableAI "MOVE";
    _source disableAI "TARGET";
    _source disableAI "AUTOTARGET";
    _source setVariable ["acex_headless_blacklist",true,true];
    _source setVariable ["WAIT_CortexQA_Projectile",objNull];
    _source addMagazine "HandGrenade";
    _source addEventHandler ["FiredMan",{
        params ["_unit","","","","","","_projectile"];
        _unit setVariable ["WAIT_CortexQA_Projectile",_projectile];
    }];
    _source forceWeaponFire ["HandGrenadeMuzzle","HandGrenadeMuzzle"];
    private _deadline=diag_tickTime+2;
    waitUntil {
        sleep 0.05;
        !isNull (_source getVariable ["WAIT_CortexQA_Projectile",objNull]) || {diag_tickTime >= _deadline}
    };
    private _grenade=_source getVariable ["WAIT_CortexQA_Projectile",objNull];
    if (isNull _grenade) then {
        diag_log "WAIT CORTEX QA FIXTURE ERROR: native grenade firing produced no projectile";
    } else {
        private _spawn=+_position;
        _spawn set [2,(_spawn param [2,0]) + 2];
        _grenade setPosATL _spawn;
        _grenade setVelocity [0,0,-4];
    };
    [_source,_sourceGroup] spawn {
        params ["_source","_sourceGroup"];
        sleep 12;
        deleteVehicle _source;
        deleteGroup _sourceGroup;
    };
    _grenade
};
// Scripted damage and an unattributed createVehicle bullet do not reliably create native casualty
// danger. Fire a real rifle round from an excluded same-side actor, capture its engine projectile,
// then place the attributed shot on the casualty. This tests Arma's death/body danger causes rather
// than calling WAIT or manufacturing its state.
private _killWithRealProjectile={
    params [["_actor",objNull,[objNull]]];
    if (isNull _actor) exitWith {objNull};
    private _sourceGroup=createGroup [east,true];
    _sourceGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _sourceGroup setVariable ["acex_headless_blacklist",true,true];
    _sourceGroup setVariable ["WAIT_AIPass_Exclude",true,true];
    _sourceGroup setCombatMode "BLUE";
    private _sourcePosition=(getPosATL _actor) getPos [100,0];
    private _source=_sourceGroup createUnit ["O_Soldier_F",_sourcePosition,[],0,"NONE"];
    _source allowDamage false;
    _source disableAI "MOVE";
    _source disableAI "TARGET";
    _source disableAI "AUTOTARGET";
    _source setVariable ["acex_headless_blacklist",true,true];
    _source setVariable ["WAIT_CortexQA_Projectile",objNull];
    _source addEventHandler ["FiredMan",{
        params ["_unit","","","","","","_projectile"];
        _unit setVariable ["WAIT_CortexQA_Projectile",_projectile];
    }];
    private _rifle=primaryWeapon _source;
    _source selectWeapon _rifle;
    _source setAmmo [_rifle,30];
    // Selection is asynchronous on a newly spawned actor. A fixed quarter-second delay could
    // capture an empty muzzle/mode and never fire, falsely failing every later casualty check.
    private _readyDeadline=diag_tickTime+5;
    waitUntil {
        sleep 0.05;
        private _readyState=weaponState _source;
        (currentWeapon _source == _rifle && {(_readyState param [1,""]) != ""}
            && {(_readyState param [2,""]) != ""} && {(_readyState param [4,0]) > 0})
            || {diag_tickTime >= _readyDeadline}
    };
    private _weaponState=weaponState _source;
    _source forceWeaponFire [_weaponState param [1,currentWeapon _source],_weaponState param [2,"Single"]];
    private _deadline=diag_tickTime+2;
    waitUntil {
        sleep 0.02;
        !isNull (_source getVariable ["WAIT_CortexQA_Projectile",objNull]) || {diag_tickTime >= _deadline}
    };
    private _projectile=_source getVariable ["WAIT_CortexQA_Projectile",objNull];
    if (isNull _projectile) exitWith {
        diag_log format ["WAIT CORTEX QA FIXTURE ERROR: native rifle firing produced no projectile; local=%1 simulation=%2 currentWeapon=%3 before=%4 after=%5 modes=%6 behaviour=%7 combatMode=%8",
            local _source,simulationEnabled _source,currentWeapon _source,_weaponState,weaponState _source,
            getArray (configFile >> "CfgWeapons" >> _rifle >> "modes"),behaviour _source,combatMode _sourceGroup];
        deleteVehicle _source;
        deleteGroup _sourceGroup;
        objNull
    };
    private _impact=eyePos _actor vectorAdd [0,0,-0.25];
    private _origin=_impact vectorAdd [-2,0,0];
    _projectile setPosASL _origin;
    _projectile setVelocity ((_impact vectorDiff _origin) vectorMultiply 450);
    [_source,_sourceGroup] spawn {
        params ["_source","_sourceGroup"];
        sleep 5;
        deleteVehicle _source;
        deleteGroup _sourceGroup;
    };
    _projectile
};
[createHashMapFromArray [
    ["WAIT_AIPass_Enable",true],["WAIT_AIPass_Contact_Enable",true],["WAIT_AIPass_Regroup_Enable",false],
    ["WAIT_AIPass_Flank_Enable",false],["WAIT_AIPass_Advance_Enable",false],
    ["WAIT_AIPass_FireControl_Enable",false],["WAIT_AIPass_Morale_Enable",false],
    ["WAIT_AIPass_Reinforce_Enable",false],["WAIT_AIPass_ContactReports_Enable",false],
    ["WAIT_AIPass_Artillery_Enable",false],["WAIT_AIPass_CoordinatedAssault_Enable",false]
]] call WAIT_fnc_CortexTuning;

// The configured engine FSM remains installed when its live CBA gate is off, so prove that the
// disabled path is inert under a real engine-delivered explosion. Native animation may still react;
// only WAIT-authored stance, cover, response and tactical phase are prohibited.
private _disabledGroup=createGroup [east,true];
_disabledGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_disabledGroup setVariable ["acex_headless_blacklist",true,true];
_disabledGroup setCombatMode "BLUE";
private _disabledUnit=_disabledGroup createUnit ["O_Soldier_F",[2260,1350,0],[],0,"NONE"];
_disabledUnit allowDamage false;
_disabledUnit setUnitPos "AUTO";
_disabledUnit setVariable ["acex_headless_blacklist",true,true];
_disabledUnit setVariable ["WAIT_CortexQA_Label","DANGER DISABLED",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_disabledUnit],true];
[createHashMapFromArray [["WAIT_AIPass_Danger_Enable",false]]] call WAIT_fnc_CortexTuning;
private _disabledReady=[{!(missionNamespace getVariable ["WAIT_AIPass_Danger_Enable",true])},10] call _wait;
private _disabledOrigin=getPosATL _disabledUnit;
private _disabledTransitionsBefore=count (_disabledGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]);
["Danger FSM: disabled physical stimulus","A real grenade detonates beside this isolated soldier while Danger response is disabled. Native animation is allowed, but WAIT must not take stance, cover, response or CONTACT ownership.",_disabledOrigin] call _phase;
private _disabledGrenade=[_disabledOrigin getPos [7,90]] call _spawnRealGrenade;
sleep 4;
private _disabledTransitions=(_disabledGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]) select [_disabledTransitionsBefore];
private _disabledInert=(_disabledUnit getVariable ["WAIT_Danger_EngineStanceLease",[]]) isEqualTo []
    && {(_disabledGroup getVariable ["WAIT_Danger_Response",[]]) isEqualTo []}
    && {(_disabledGroup getVariable ["WAIT_Danger_Action",[]]) isEqualTo []}
    && {(_disabledGroup getVariable ["WAIT_Danger_CoverLease",[]]) isEqualTo []}
    && {((_disabledGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["phase","CALM"]) == "CALM"}
    && {_disabledTransitions findIf {(_x param [2,""]) == "CONTACT"} < 0};
["DANGER-disabled-real-stimulus-inert",_disabledReady && {_disabledInert},str [unitPos _disabledUnit,_disabledTransitions,_disabledGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]]] call _check;
deleteVehicle _disabledGrenade;
deleteVehicle _disabledUnit;
deleteGroup _disabledGroup;
[createHashMapFromArray [["WAIT_AIPass_Danger_Enable",true]]] call WAIT_fnc_CortexTuning;
private _enabledReady=[{missionNamespace getVariable ["WAIT_AIPass_Danger_Enable",false]},10] call _wait;
["DANGER-live-gate-reenabled",_enabledReady] call _check;

// A live CBA change must also retire a response which already owns a weak actor stance. This is
// distinct from starting disabled: the engine FSM has physically reacted, so cleanup must prove
// exact restoration rather than merely showing that no callback was accepted.
private _liveDisableGroup=createGroup [east,true];
_liveDisableGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_liveDisableGroup setVariable ["acex_headless_blacklist",true,true];
_liveDisableGroup setCombatMode "BLUE";
private _liveDisableUnit=_liveDisableGroup createUnit ["O_Soldier_F",[2280,1350,0],[],0,"NONE"];
_liveDisableUnit allowDamage false;
_liveDisableUnit setUnitPos "AUTO";
_liveDisableUnit setVariable ["acex_headless_blacklist",true,true];
_liveDisableUnit setVariable ["WAIT_CortexQA_Label","DANGER LIVE DISABLE",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_liveDisableUnit],true];
["Danger FSM: live gate cleanup","A real explosion first creates a finite WAIT stance. Danger is then disabled while that lease is active; the soldier must return to AUTO immediately without waiting for natural expiry.",getPosATL _liveDisableUnit] call _phase;
private _liveDisableGrenade=[(getPosATL _liveDisableUnit) getPos [7,90]] call _spawnRealGrenade;
private _liveDisableReacted=[{
    (_liveDisableUnit getVariable ["WAIT_Danger_EngineStanceLease",[]]) isNotEqualTo []
        && {stance _liveDisableUnit in ["CROUCH","PRONE"]}
},10] call _wait;
["DANGER-live-disable-real-reflex",_liveDisableReacted,str [
    _liveDisableUnit getVariable ["WAIT_Danger_EngineEntry",[]],
    _liveDisableUnit getVariable ["WAIT_Danger_EngineStanceLease",[]],
    stance _liveDisableUnit,
    _liveDisableGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]
]] call _check;
[createHashMapFromArray [["WAIT_AIPass_Danger_Enable",false]]] call WAIT_fnc_CortexTuning;
private _liveDisableReleased=[{
    !(missionNamespace getVariable ["WAIT_AIPass_Danger_Enable",true])
        && {(_liveDisableUnit getVariable ["WAIT_Danger_EngineStanceLease",[]]) isEqualTo []}
        && {(_liveDisableUnit getVariable ["WAIT_Danger_EngineResponse",[]]) isEqualTo []}
        && {toUpperANSI (unitPos _liveDisableUnit) == "AUTO"}
        && {(_liveDisableGroup getVariable ["WAIT_Danger_Response",[]]) isEqualTo []}
},10] call _wait;
["DANGER-live-disable-exact-stance-release",_liveDisableReacted && {_liveDisableReleased},str [
    ["reflexDelivered",_liveDisableReacted,"released",_liveDisableReleased],
    unitPos _liveDisableUnit,
    _liveDisableUnit getVariable ["WAIT_Danger_EngineStanceLease",[]],
    _liveDisableUnit getVariable ["WAIT_Danger_EngineResponse",[]],
    _liveDisableGroup getVariable ["WAIT_Danger_Response",[]]
]] call _check;
deleteVehicle _liveDisableGrenade;
deleteVehicle _liveDisableUnit;
deleteGroup _liveDisableGroup;
[createHashMapFromArray [["WAIT_AIPass_Danger_Enable",true]]] call WAIT_fnc_CortexTuning;
private _liveDisableReenabled=[{missionNamespace getVariable ["WAIT_AIPass_Danger_Enable",false]},10] call _wait;
["DANGER-live-disable-reenabled",_liveDisableReenabled] call _check;

// BLUE is an explicit authored hold-fire instruction. With the live danger gate enabled, a real
// explosion must still reach the engine FSM and may produce a finite actor stance, but it cannot
// promote fire discipline or enter the group tactical state.
private _disciplineGroup=createGroup [east,true];
_disciplineGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_disciplineGroup setVariable ["acex_headless_blacklist",true,true];
_disciplineGroup setCombatMode "BLUE";
private _disciplineUnit=_disciplineGroup createUnit ["O_Soldier_F",[2270,1350,0],[],0,"NONE"];
_disciplineUnit allowDamage false;
_disciplineUnit setVariable ["acex_headless_blacklist",true,true];
_disciplineUnit setVariable ["WAIT_CortexQA_Label","AUTHORED HOLD FIRE",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_disciplineUnit],true];
private _disciplineStatsBefore=(_disciplineGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0];
private _disciplineTransitionsBefore=count (_disciplineGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]);
["Danger FSM: authored hold fire","A real grenade detonates beside an invulnerable soldier under an authored BLUE order. The local reflex may run, but WAIT must retain BLUE and never begin CONTACT.",getPosATL _disciplineUnit] call _phase;
private _disciplineGrenade=[(getPosATL _disciplineUnit) getPos [7,90]] call _spawnRealGrenade;
private _disciplineObserved=[{
    ((_disciplineGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0]) > _disciplineStatsBefore
},12] call _wait;
sleep 4;
private _disciplineTransitions=(_disciplineGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]) select [_disciplineTransitionsBefore];
["DANGER-authored-hold-fire-preserved",_disciplineObserved && {combatMode _disciplineGroup == "BLUE"}
    && {_disciplineTransitions findIf {(_x param [2,""]) == "CONTACT"} < 0},str [combatMode _disciplineGroup,_disciplineTransitions,_disciplineGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]]] call _check;
deleteVehicle _disciplineGrenade;
// Contact awareness is still useful under an explicit hold-fire order, but it must not silently
// become permission for WAIT fire, reinforcement, artillery or manoeuvre. Enable those gates for
// this isolated group, expose a real hostile and require the authored BLUE order to remain in charge.
[createHashMapFromArray [
    ["WAIT_AIPass_Flank_Enable",true],["WAIT_AIPass_Advance_Enable",true],
    ["WAIT_AIPass_FireControl_Enable",true],["WAIT_AIPass_Reinforce_Enable",true],
    ["WAIT_AIPass_ContactReports_Enable",true],["WAIT_AIPass_Artillery_Enable",true],
    ["WAIT_AIPass_CoordinatedAssault_Enable",true]
]] call WAIT_fnc_CortexTuning;
_disciplineGroup setBehaviourStrong "STEALTH";
_disciplineUnit setUnitPos "AUTO";
private _disciplineEnemyGroup=createGroup [west,true];
_disciplineEnemyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_disciplineEnemyGroup setVariable ["acex_headless_blacklist",true,true];
_disciplineEnemyGroup setVariable ["WAIT_AIPass_Exclude",true,true];
_disciplineEnemyGroup setCombatMode "BLUE";
private _disciplineEnemy=_disciplineEnemyGroup createUnit ["B_Soldier_F",[2270,1375,0],[],0,"NONE"];
_disciplineEnemy allowDamage false;
_disciplineEnemy disableAI "PATH";
_disciplineEnemy setDir 180;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_disciplineUnit,_disciplineEnemy],true];
["Danger FSM: known contact under authored hold fire","The soldier naturally sees a real hostile while BLUE. WAIT may record awareness and CONTACT, but must issue no fire, support, artillery or manoeuvre operation and must preserve BLUE.",getPosATL _disciplineEnemy] call _phase;
private _disciplineKnown=[{
    (([_disciplineGroup] call WAIT_fnc_CortexKnowledge) select 0) findIf {(_x select 0) == _disciplineEnemy} >= 0
        && {(_disciplineGroup getVariable ["WAIT_AIPass_PublicPhase",""]) == "CONTACT"}
},20] call _wait;
private _disciplineLowProfile=[{
    private _lease=_disciplineUnit getVariable ["WAIT_Danger_EngineStanceLease",[]];
    count _lease >= 2 && {(_lease select 1) == "DOWN"}
},12] call _wait;
sleep 8;
private _disciplineState=_disciplineGroup getVariable ["WAIT_AIPass_State",createHashMap];
private _disciplineCooldowns=_disciplineState getOrDefault ["cooldowns",createHashMap];
private _disciplineNoTactics=(_disciplineGroup getVariable ["WAIT_Operation",createHashMap]) isEqualTo createHashMap
    && {(_disciplineGroup getVariable ["WAIT_Cortex_SupportResponders",[]]) isEqualTo []}
    && {(_disciplineGroup getVariable ["WAIT_Cortex_CombinedRole",[]]) isEqualTo []}
    && {!("combinedArmsDue" in _disciplineState)}
    && {(_disciplineState getOrDefault ["reinforceRequested",0]) == 0}
    && {!("artillery" in _disciplineCooldowns)};
["DANGER-known-contact-hold-fire-no-tactics",_disciplineKnown && {_disciplineNoTactics}
    && {combatMode _disciplineGroup == "BLUE"},str [combatMode _disciplineGroup,_disciplineGroup getVariable ["WAIT_Operation",createHashMap],_disciplineGroup getVariable ["WAIT_Cortex_SupportResponders",[]]]] call _check;
["DANGER-stealth-hold-fire-low-profile",_disciplineLowProfile
    && {combatMode _disciplineGroup == "BLUE"}
    && {(_disciplineUnit getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo []},str [_disciplineLowProfile,unitPos _disciplineUnit,getPosATL _disciplineUnit,combatMode _disciplineGroup,_disciplineUnit getVariable ["WAIT_Cortex_ActorMove",[]]]] call _check;
deleteVehicle _disciplineEnemy;
deleteGroup _disciplineEnemyGroup;
deleteVehicle _disciplineUnit;
deleteGroup _disciplineGroup;

// HOLD and SENTRY waypoints are authored stationary intent even when fire is permitted. A real
// hostile may be engaged through native combat, but WAIT must not replace the waypoint with an
// investigation, support rally, coordinated route, building entry, flank, advance or assault.
private _holdGroup=createGroup [east,true];
_holdGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_holdGroup setVariable ["acex_headless_blacklist",true,true];
_holdGroup setCombatMode "YELLOW";
_holdGroup setBehaviourStrong "COMBAT";
private _holdUnits=[];
for "_i" from 0 to 3 do {
    private _unit=_holdGroup createUnit ["O_Soldier_F",[2340+_i*2,1350,0],[],0,"NONE"];
    _unit allowDamage false;
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["AUTHORED HOLD %1",_i+1],true];
    _holdUnits pushBack _unit;
};
private _holdOrigin=getPosATL leader _holdGroup;
private _holdWaypoint=_holdGroup addWaypoint [_holdOrigin,0];
_holdWaypoint setWaypointType "HOLD";
_holdWaypoint setWaypointCombatMode "YELLOW";
private _holdEnemyGroup=createGroup [west,true];
_holdEnemyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_holdEnemyGroup setVariable ["acex_headless_blacklist",true,true];
_holdEnemyGroup setVariable ["WAIT_AIPass_Exclude",true,true];
_holdEnemyGroup setCombatMode "BLUE";
private _holdEnemy=_holdEnemyGroup createUnit ["B_Soldier_F",[2340,1395,0],[],0,"NONE"];
_holdEnemy allowDamage false;
_holdEnemy disableAI "PATH";
_holdEnemy setDir 180;
{_x setVariable ["WAIT_CortexQA_Shots",0]; _x addEventHandler ["Fired",{params ["_unit"]; _unit setVariable ["WAIT_CortexQA_Shots",(_unit getVariable ["WAIT_CortexQA_Shots",0])+1]}]} forEach _holdUnits;
missionNamespace setVariable ["WAIT_CortexQA_Actors",_holdUnits+[_holdEnemy],true];
["Danger FSM: authored HOLD permits fire without movement","Four riflemen naturally detect a close hostile while an ordinary HOLD waypoint is active. Native fire is expected, but WAIT must create no movement operation or replacement waypoint and the squad must remain around its authored position.",getPosATL _holdEnemy] call _phase;
private _holdContact=[{
    (_holdGroup getVariable ["WAIT_AIPass_PublicPhase",""]) == "CONTACT"
        && {_holdUnits findIf {(_x getVariable ["WAIT_CortexQA_Shots",0]) > 0} >= 0}
},35] call _wait;
sleep 10;
private _holdShots=0;
{_holdShots=_holdShots+(_x getVariable ["WAIT_CortexQA_Shots",0])} forEach _holdUnits;
private _holdTravel=0;
{_holdTravel=_holdTravel max (_x distance2D _holdOrigin)} forEach _holdUnits;
private _holdState=_holdGroup getVariable ["WAIT_AIPass_State",createHashMap];
private _holdPreserved=waypointType [_holdGroup,currentWaypoint _holdGroup] == "HOLD"
    && {(_holdGroup getVariable ["WAIT_Operation",createHashMap]) isEqualTo createHashMap}
    && {(_holdState getOrDefault ["drill",createHashMap]) isEqualTo createHashMap}
    && {(_holdGroup getVariable ["WAIT_Cortex_SupportResponders",[]]) isEqualTo []}
    && {(waypoints _holdGroup) findIf {waypointDescription _x == "WAIT AI PASS"} < 0}
    && {_holdTravel < 20};
["DANGER-authored-HOLD-native-fire-no-WAIT-movement",_holdContact && {_holdPreserved},str [_holdShots,_holdTravel,waypointType [_holdGroup,currentWaypoint _holdGroup],_holdGroup getVariable ["WAIT_Operation",createHashMap]]] call _check;
{deleteVehicle _x} forEach _holdUnits;
deleteVehicle _holdEnemy;
deleteGroup _holdGroup;
deleteGroup _holdEnemyGroup;
[createHashMapFromArray [
    ["WAIT_AIPass_Flank_Enable",false],["WAIT_AIPass_Advance_Enable",false],
    ["WAIT_AIPass_FireControl_Enable",false],["WAIT_AIPass_Reinforce_Enable",false],
    ["WAIT_AIPass_ContactReports_Enable",false],["WAIT_AIPass_Artillery_Enable",false],
    ["WAIT_AIPass_CoordinatedAssault_Enable",false]
]] call WAIT_fnc_CortexTuning;

// A real same-group death must reach the native danger FSM as alerting evidence without inventing
// an attacker or converting the surviving group into CONTACT. Morale and role replacement consume
// the actual casualty independently; this stage tests only the immediate danger ownership boundary.
private _casualtyGroup=createGroup [east,true];
_casualtyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_casualtyGroup setVariable ["acex_headless_blacklist",true,true];
_casualtyGroup setCombatMode "BLUE";
private _casualtySurvivor=_casualtyGroup createUnit ["O_Soldier_F",[2280,1350,0],[],0,"NONE"];
private _casualtyActor=_casualtyGroup createUnit ["O_Soldier_F",[2283,1350,0],[],0,"NONE"];
_casualtySurvivor allowDamage false;
{_x setVariable ["acex_headless_blacklist",true,true]} forEach [_casualtySurvivor,_casualtyActor];
_casualtySurvivor setVariable ["WAIT_CortexQA_Label","CASUALTY ALERT SURVIVOR",true];
_casualtyActor setVariable ["WAIT_CortexQA_Label","REAL SAME-GROUP CASUALTY",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_casualtySurvivor,_casualtyActor],true];
private _casualtyHideBefore=((_casualtyGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["modes",createHashMap]) getOrDefault ["HIDE",0];
private _casualtyTransitionsBefore=count (_casualtyGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]);
["Danger FSM: casualty alert is not contact","One soldier is killed by real damage beside his squad-mate. The survivor may take a finite local hide posture, but WAIT must not invent an attacker, change group combat posture or enter CONTACT.",getPosATL _casualtyActor] call _phase;
private _casualtyProjectile=[_casualtyActor] call _killWithRealProjectile;
private _casualtyKilled=[{!alive _casualtyActor},5] call _wait;
private _casualtyObserved=[{
    private _stats=_casualtyGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
    ((_stats getOrDefault ["modes",createHashMap]) getOrDefault ["HIDE",0]) > _casualtyHideBefore
},12] call _wait;
sleep 4;
private _casualtyTransitions=(_casualtyGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]) select [_casualtyTransitionsBefore];
private _casualtyNoContact=_casualtyTransitions findIf {(_x param [2,""]) == "CONTACT"} < 0
    && {((_casualtyGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["phase","CALM"]) == "CALM"}
    && {(_casualtyGroup getVariable ["WAIT_Danger_ReactionLease",[]]) isEqualTo []}
    && {combatMode _casualtyGroup == "BLUE"}
    && {(([_casualtyGroup] call WAIT_fnc_CortexKnowledge) select 0) isEqualTo []};
["DANGER-casualty-alert-no-contact",_casualtyKilled && {_casualtyObserved} && {_casualtyNoContact},str [_casualtyGroup getVariable ["WAIT_Danger_EngineStats",createHashMap],_casualtyTransitions,combatMode _casualtyGroup]] call _check;
deleteVehicle _casualtyProjectile;
deleteVehicle _casualtyActor;
deleteVehicle _casualtySurvivor;
deleteGroup _casualtyGroup;

// Engine cause 6 is discovery of another body, not loss of a member from the observer's squad.
// Keep the observer facing the actor before real damage is applied, then require WAIT's native FSM
// bridge to preserve that distinction without an injected danger callback or target reveal.
private _bodyObserverGroup=createGroup [east,true];
_bodyObserverGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_bodyObserverGroup setVariable ["acex_headless_blacklist",true,true];
_bodyObserverGroup setCombatMode "BLUE";
private _bodyObserver=_bodyObserverGroup createUnit ["O_Soldier_F",[2310,1350,0],[],0,"NONE"];
_bodyObserver allowDamage false;
_bodyObserver setVariable ["acex_headless_blacklist",true,true];
private _bodyGroup=createGroup [east,true];
_bodyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_bodyGroup setVariable ["acex_headless_blacklist",true,true];
private _bodyActor=_bodyGroup createUnit ["O_Soldier_F",[2318,1350,0],[],0,"NONE"];
removeAllWeapons _bodyActor;
_bodyActor disableAI "MOVE";
_bodyActor setVariable ["acex_headless_blacklist",true,true];
_bodyObserver setDir (_bodyObserver getDir _bodyActor);
_bodyObserver setVariable ["WAIT_CortexQA_Label","OTHER-BODY OBSERVER",true];
_bodyActor setVariable ["WAIT_CortexQA_Label","OTHER-GROUP BODY",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_bodyObserver,_bodyActor],true];
private _bodyTransitionsBefore=count (_bodyObserverGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]);
["Danger FSM: other body is not squad casualty","A soldier faces a nearby actor from another group before that actor is killed by real damage. Native cause 6 must remain BODY_FOUND, never CASUALTY, and must not authorise CONTACT or movement.",getPosATL _bodyActor] call _phase;
sleep 1;
private _bodyProjectile=[_bodyActor] call _killWithRealProjectile;
private _bodyKilled=[{!alive _bodyActor},5] call _wait;
private _bodyObserved=[{
    private _stats=_bodyObserverGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
    "BODY_FOUND" in (_stats getOrDefault ["lastCauses",[]])
},12] call _wait;
sleep 2;
private _bodyStats=_bodyObserverGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
private _bodyLastCauses=_bodyStats getOrDefault ["lastCauses",[]];
private _bodyTransitions=(_bodyObserverGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]) select [_bodyTransitionsBefore];
private _bodySeparated=_bodyKilled && {_bodyObserved}
    && {!("CASUALTY" in _bodyLastCauses)}
    && {_bodyTransitions findIf {(_x param [2,""]) == "CONTACT"} < 0}
    && {((_bodyObserverGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["phase","CALM"]) == "CALM"}
    && {combatMode _bodyObserverGroup == "BLUE"};
["DANGER-other-body-distinct-alert",_bodySeparated,str [_bodyStats,_bodyTransitions,combatMode _bodyObserverGroup]] call _check;
deleteVehicle _bodyActor;
deleteVehicle _bodyProjectile;
deleteVehicle _bodyObserver;
deleteGroup _bodyGroup;
deleteGroup _bodyObserverGroup;

// CARELESS is an authored mission state and maps to RELEASE in the engine FSM. A real stimulus may
// be observed for diagnostics, but it must be filtered before group submission in the same frame.
private _releaseGroup=createGroup [east,true];
_releaseGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_releaseGroup setVariable ["acex_headless_blacklist",true,true];
_releaseGroup setCombatMode "BLUE";
private _releaseUnit=_releaseGroup createUnit ["O_Soldier_F",[2340,1350,0],[],0,"NONE"];
_releaseUnit allowDamage false;
_releaseUnit setVariable ["acex_headless_blacklist",true,true];
_releaseGroup setBehaviourStrong "CARELESS";
_releaseUnit setVariable ["WAIT_CortexQA_Label","CARELESS RELEASE OWNER",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_releaseUnit],true];
private _releaseStatsBefore=_releaseGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
private _releaseSubmissionsBefore=_releaseStatsBefore getOrDefault ["submissions",0];
private _releaseAcceptedBefore=_releaseStatsBefore getOrDefault ["acceptedRecords",0];
private _releaseTransitionsBefore=count (_releaseGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]);
["Danger FSM: authored CARELESS release","A real grenade detonates near an invulnerable CARELESS soldier. WAIT may record the engine stimulus, but must discard it before group planning and preserve the authored state.",getPosATL _releaseUnit] call _phase;
private _releaseGrenade=[(getPosATL _releaseUnit) getPos [7,90]] call _spawnRealGrenade;
private _releaseObserved=[{
    ((_releaseGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0]) > _releaseSubmissionsBefore
},12] call _wait;
sleep 2;
private _releaseStatsAfter=_releaseGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
private _releaseTransitions=(_releaseGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]) select [_releaseTransitionsBefore];
private _releaseInert=(_releaseStatsAfter getOrDefault ["acceptedRecords",0]) == _releaseAcceptedBefore
    && {(_releaseGroup getVariable ["WAIT_Danger_Response",[]]) isEqualTo []}
    && {(_releaseGroup getVariable ["WAIT_Danger_Action",[]]) isEqualTo []}
    && {(_releaseGroup getVariable ["WAIT_Danger_ReactionLease",[]]) isEqualTo []}
    && {behaviour _releaseUnit == "CARELESS"}
    && {_releaseTransitions findIf {(_x param [2,""]) == "CONTACT"} < 0};
["DANGER-release-mode-no-tactical-handoff",_releaseObserved && {_releaseInert},str [_releaseStatsAfter,behaviour _releaseUnit,_releaseTransitions]] call _check;
deleteVehicle _releaseGrenade;
deleteVehicle _releaseUnit;
deleteGroup _releaseGroup;

// Prove the engine-loaded FSM with a real targetless explosion before introducing any enemy. The
// fixture reads production diagnostics but never calls DangerEngineSubmit, writes a response, or
// assigns phase. Its authored AUTO scripted stance provides an exact baseline that the production
// lease can observe and restore; a higher-priority commanded UP stance would suppress the reflex.
private _reflexGroup=createGroup [east,true];
_reflexGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_reflexGroup setVariable ["acex_headless_blacklist",true,true];
_reflexGroup setCombatMode "BLUE";
private _reflexUnit=_reflexGroup createUnit ["O_Soldier_F",[2300,1350,0],[],0,"NONE"];
_reflexUnit allowDamage false;
_reflexUnit setUnitPos "AUTO";
_reflexUnit setVariable ["acex_headless_blacklist",true,true];
_reflexUnit setVariable ["WAIT_CortexQA_Label","TARGETLESS EXPLOSION REFLEX",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_reflexUnit],true];
// A real solid wall sits on the far side of the actor from the grenade. This turns the cover response
// into a physical test instead of treating an accepted danger record or generated destination as success.
private _dangerCoverWall=createVehicle ["Land_CncWall4_F",[2296,1350,0],[],0,"CAN_COLLIDE"];
_dangerCoverWall setDir 90;
private _reflexStart=getPosATL _reflexUnit;
["Danger FSM: targetless explosion","A real grenade will detonate beside the isolated invulnerable soldier. He must duck, move behind the solid wall, release WAIT's exact scripted-stance lease and return to AUTO and CALM without acquiring or searching for an enemy.",getPosATL _reflexUnit] call _phase;
private _statsBefore=(_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0];
private _coverMovesBefore=(_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["coverMoves",0];
private _grenade=[(getPosATL _reflexUnit) getPos [7,90]] call _spawnRealGrenade;
private _nativeStimulus=[{
    ((_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0]) > _statsBefore
},12] call _wait;
private _physicalReflex=[{
    (_reflexUnit getVariable ["WAIT_Danger_EngineStanceLease",[]]) isNotEqualTo []
        && {stance _reflexUnit in ["CROUCH","PRONE"]}
},8] call _wait;
private _physicalCover=[{
    ((_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["coverMoves",0]) > _coverMovesBefore
        && {_reflexUnit distance2D _reflexStart >= 2}
},16] call _wait;
private _released=[{
    (_reflexUnit getVariable ["WAIT_Danger_EngineStanceLease",[]]) isEqualTo []
        && {toUpperANSI (unitPos _reflexUnit) == "AUTO"}
        && {((_reflexGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["phase","CALM"]) == "CALM"}
},12] call _wait;
private _reflexKnowledge=([_reflexGroup] call WAIT_fnc_CortexKnowledge) select 0;
private _reflexTransitions=_reflexGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]];
["DANGER-native-targetless-explosion",_nativeStimulus,str [
    _reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap],
    (units _reflexGroup) apply {[_x,_x getVariable ["WAIT_Danger_EngineEntry",[]],local _x,currentCommand _x,behaviour _x]}
]] call _check;
["DANGER-physical-finite-reflex",_nativeStimulus && {_physicalReflex},str [unitPos _reflexUnit,stance _reflexUnit]] call _check;
["DANGER-idle-physical-cover",_nativeStimulus && {_physicalCover},str [getPosATL _reflexUnit,_reflexStart,_reflexGroup getVariable ["WAIT_Danger_CoverLease",[]],
    _reflexGroup getVariable ["WAIT_Danger_CoverDecision",[]],_reflexGroup getVariable ["WAIT_Danger_CoverBlockedContext",[]]]] call _check;
["DANGER-exact-posture-and-calm-release",_nativeStimulus && {_released} && {_reflexKnowledge isEqualTo []}
    && {_reflexTransitions findIf {(_x param [2,""]) == "SECURITY" || {(_x param [2,""]) == "SEARCH"}} < 0},
    str [unitPos _reflexUnit,_reflexKnowledge,_reflexTransitions,_reflexUnit getVariable ["WAIT_Danger_EngineReleaseEvidence",[]]]] call _check;
deleteVehicle _grenade;

// Prove a multi-member group preserves the native observer through the group-budgeted cover pass.
// The leader is deliberately too far away and path-disabled to receive or steal the physical move;
// a real explosion beside the wingman must make that same wingman take the single bounded cover leg.
private _observerGroup=createGroup [east,true];
_observerGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_observerGroup setVariable ["acex_headless_blacklist",true,true];
_observerGroup setCombatMode "BLUE";
private _observerLeader=_observerGroup createUnit ["O_Soldier_F",[2450,1250,0],[],0,"NONE"];
private _observerWingman=_observerGroup createUnit ["O_Soldier_F",[2530,1250,0],[],0,"NONE"];
private _observerSupportOne=_observerGroup createUnit ["O_Soldier_LAT_F",[2529,1244,0],[],0,"NONE"];
private _observerSupportTwo=_observerGroup createUnit ["O_Soldier_F",[2529,1254,0],[],0,"NONE"];
private _observerSupportThree=_observerGroup createUnit ["O_Soldier_F",[2533,1244,0],[],0,"NONE"];
private _observerSupportFour=_observerGroup createUnit ["O_Soldier_F",[2533,1250,0],[],0,"NONE"];
private _observerSupportFive=_observerGroup createUnit ["O_Soldier_F",[2533,1256,0],[],0,"NONE"];
{
    _x allowDamage false;
    _x setUnitPos "AUTO";
    _x setVariable ["acex_headless_blacklist",true,true];
} forEach [_observerLeader,_observerWingman,_observerSupportOne,_observerSupportTwo,
    _observerSupportThree,_observerSupportFour,_observerSupportFive];
_observerLeader disableAI "PATH";
_observerLeader setVariable ["WAIT_CortexQA_Label","DISTANT GROUP LEADER",true];
_observerWingman setVariable ["WAIT_CortexQA_Label","NATIVE DANGER OBSERVER",true];
_observerSupportOne setVariable ["WAIT_CortexQA_Label","AT READINESS RESERVED",true];
_observerSupportTwo setVariable ["WAIT_CortexQA_Label","FINITE GROUP HIDE 1",true];
_observerSupportThree setVariable ["WAIT_CortexQA_Label","FINITE GROUP HIDE 2",true];
_observerSupportFour setVariable ["WAIT_CortexQA_Label","FINITE GROUP HIDE 3",true];
_observerSupportFive setVariable ["WAIT_CortexQA_Label","FINITE GROUP HIDE 4",true];
private _observerWall=createVehicle ["Land_CncWall4_F",[2526,1250,0],[],0,"CAN_COLLIDE"];
_observerWall setDir 90;
private _observerStart=getPosATL _observerWingman;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_observerLeader,_observerWingman,_observerSupportOne,_observerSupportTwo,
    _observerSupportThree,_observerSupportFour,_observerSupportFive],true];
["Danger FSM: observer cover and squad readiness","A real explosion occurs beside the separated wingman. The native danger record must retain him as its observer, the one bounded cover move must move that same soldier rather than the distant leader, and four ordinary riflemen must lower profile before the squad's loaded AT gunner.",getPosATL _observerWingman] call _phase;
sleep 2;
private _observerCoverBefore=(_observerGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["coverMoves",0];
private _observerGrenade=[(getPosATL _observerWingman) getPos [7,90]] call _spawnRealGrenade;
private _observerGroupHide=[{
    private _leases=_observerGroup getVariable ["WAIT_Danger_GroupHideLeases",[]];
    private _leasedActors=_leases apply {_x param [0,objNull]};
    count _leases == 4
        && {!(_observerSupportOne in _leasedActors)}
        && {[_observerSupportTwo,_observerSupportThree,_observerSupportFour,_observerSupportFive]
            findIf {!(_x in _leasedActors)} < 0}
},8] call _wait;
private _observerCover=[{
    private _assessment=_observerGroup getVariable ["WAIT_Danger_LastAssessment",[]];
    private _action=_observerGroup getVariable ["WAIT_Danger_Action",[]];
    private _lease=_observerGroup getVariable ["WAIT_Danger_CoverLease",[]];
    count _assessment >= 6
        && {(_assessment select 5) == _observerWingman}
        && {count _action >= 6}
        && {(_action select 5) == _observerWingman}
        && {count _lease >= 4}
        && {(_lease select 0) == _observerWingman}
        && {((_observerGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["coverMoves",0]) > _observerCoverBefore}
        && {_observerWingman distance2D _observerStart >= 2}
},18] call _wait;
["DANGER-finite-group-hide",_observerGroupHide,str [_observerGroup getVariable ["WAIT_Danger_GroupHideLeases",[]],
    [_observerSupportOne] call WAIT_fnc_CortexCapabilities,unitPos _observerSupportOne,
    unitPos _observerSupportTwo,unitPos _observerSupportThree,unitPos _observerSupportFour,unitPos _observerSupportFive]] call _check;
["DANGER-exact-observer-physical-cover",_observerCover,str [_observerGroup getVariable ["WAIT_Danger_LastAssessment",[]],_observerGroup getVariable ["WAIT_Danger_Action",[]],_observerGroup getVariable ["WAIT_Danger_CoverLease",[]],getPosATL _observerLeader,getPosATL _observerWingman]] call _check;
private _observerGenerationClosed=[{
    (_observerGroup getVariable ["WAIT_Danger_FSM",[]]) isEqualTo []
        && {(_observerGroup getVariable ["WAIT_Danger_LastAssessment",[]]) isEqualTo []}
        && {(_observerGroup getVariable ["WAIT_Danger_VehicleContext",[]]) isEqualTo []}
        && {(_observerGroup getVariable ["WAIT_Danger_Response",[]]) isEqualTo []}
        && {(_observerGroup getVariable ["WAIT_Danger_Action",[]]) isEqualTo []}
        && {(_observerGroup getVariable ["WAIT_Danger_GroupHideLeases",[]]) isEqualTo []}
        && {toUpperANSI (unitPos _observerSupportOne) == "AUTO"}
        && {toUpperANSI (unitPos _observerSupportTwo) == "AUTO"}
        && {toUpperANSI (unitPos _observerSupportThree) == "AUTO"}
        && {toUpperANSI (unitPos _observerSupportFour) == "AUTO"}
        && {toUpperANSI (unitPos _observerSupportFive) == "AUTO"}
},12] call _wait;
["DANGER-natural-finish-identity-cleared",_observerCover && {_observerGenerationClosed},str [
    _observerGroup getVariable ["WAIT_Danger_FSM",[]],
    _observerGroup getVariable ["WAIT_Danger_LastAssessment",[]],
    _observerGroup getVariable ["WAIT_Danger_VehicleContext",[]],
    _observerGroup getVariable ["WAIT_Danger_Response",[]],
    _observerGroup getVariable ["WAIT_Danger_Action",[]]
]] call _check;
deleteVehicle _observerGrenade;
deleteVehicle _observerWall;
{deleteVehicle _x} forEach [_observerLeader,_observerWingman,_observerSupportOne,_observerSupportTwo,
    _observerSupportThree,_observerSupportFour,_observerSupportFive];
deleteGroup _observerGroup;

// A severe danger response may add one carried smoke screen, but the operation never waits for it.
// Use an ordinary waypoint rather than a WAIT-owned drill: a real explosion must produce a real
// smoke projectile and the same actor must continue to the authored destination.
private _smokeGroup=createGroup [east,true];
_smokeGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_smokeGroup setVariable ["acex_headless_blacklist",true,true];
_smokeGroup setCombatMode "YELLOW";
private _smokeUnit=_smokeGroup createUnit ["O_Soldier_F",[2640,1250,0],[],0,"NONE"];
_smokeUnit allowDamage false;
_smokeUnit addMagazine "SmokeShell";
_smokeUnit setVariable ["acex_headless_blacklist",true,true];
_smokeUnit setVariable ["WAIT_CortexQA_Label","DANGER SMOKE MOVER",true];
_smokeUnit setVariable ["WAIT_CortexQA_SmokeShots",0,true];
_smokeUnit addEventHandler ["FiredMan",{
    params ["_unit","_weapon","_muzzle","_mode","_ammo"];
    if (_weapon == "Throw" && {toLowerANSI getText (configFile >> "CfgAmmo" >> _ammo >> "simulation") in ["shotsmoke","shotsmokex"]}) then {
        _unit setVariable ["WAIT_CortexQA_SmokeShots",(_unit getVariable ["WAIT_CortexQA_SmokeShots",0])+1,true];
    };
}];
private _smokeStart=getPosATL _smokeUnit;
private _smokeDestination=_smokeStart getPos [55,90];
private _smokeWaypoint=_smokeGroup addWaypoint [_smokeDestination,0];
_smokeWaypoint setWaypointType "MOVE";
_smokeWaypoint setWaypointSpeed "FULL";
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_smokeUnit],true];
["Danger FSM: non-blocking smoke","The moving soldier has one carried smoke grenade. A real explosion must trigger one physical smoke throw while his ordinary waypoint remains authoritative; he must continue to the destination rather than waiting on the throw.",_smokeDestination] call _phase;
private _smokeMoving=[{_smokeUnit distance2D _smokeStart >= 4},20] call _wait;
private _smokeGrenade=[(getPosATL _smokeUnit) getPos [7,90]] call _spawnRealGrenade;
private _smokeThrown=[{(_smokeUnit getVariable ["WAIT_CortexQA_SmokeShots",0]) == 1},18] call _wait;
private _smokeArrived=[{_smokeUnit distance2D _smokeDestination < 7},55] call _wait;
private _smokeStats=_smokeGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
["DANGER-severe-response-real-smoke",_smokeMoving && {_smokeThrown}
    && {(_smokeStats getOrDefault ["smokeResponses",0]) == 1},str [_smokeUnit getVariable ["WAIT_CortexQA_SmokeShots",0],_smokeStats]] call _check;
["DANGER-smoke-does-not-block-route",_smokeMoving && {_smokeThrown} && {_smokeArrived}
    && {waypointPosition _smokeWaypoint distance2D _smokeDestination < 1},str [getPosATL _smokeUnit,_smokeDestination,currentCommand _smokeUnit]] call _check;
deleteVehicle _smokeGrenade;
deleteVehicle _smokeUnit;
deleteGroup _smokeGroup;

// Repeat the real engine stimulus while the same actor owns a committed WAIT route. The immediate
// FSM may lower his profile, but its lease must never request DOWN and repeated danger must not
// cancel, replace or arrest the operation's physical travel.
private _movementStart=getPosATL _reflexUnit;
private _movementDestination=_movementStart getPos [45,90];
private _movementOperation=[_reflexGroup,"ADVANCE",_movementDestination,[_reflexUnit],[_movementDestination],"MANOEUVRE"] call WAIT_fnc_OperationStart;
private _movementGeneration=_movementOperation getOrDefault ["generation",-1];
[_reflexGroup,_movementDestination,4,"MOVE",_movementGeneration] call WAIT_fnc_CortexGroupMove;
_reflexUnit setVariable ["WAIT_CortexQA_Target",_movementDestination,true];
["Danger FSM: movement continuity","The soldier now follows a committed WAIT route through another real explosion. The danger reflex may crouch, but it must not request prone, replace the route or stop physical progress.",_movementDestination] call _phase;
private _movementStarted=[{_reflexUnit distance2D _movementStart >= 4},20] call _wait;
private _movementStatsBefore=(_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0];
private _movementGrenade=[(getPosATL _reflexUnit) getPos [7,90]] call _spawnRealGrenade;
private _movementDanger=[{
    ((_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0]) > _movementStatsBefore
},12] call _wait;
private _requestedProne=false;
private _routeGenerationIntact=true;
for "_sample" from 1 to 12 do {
    sleep 0.25;
    private _lease=_reflexUnit getVariable ["WAIT_Danger_EngineStanceLease",[]];
    if (count _lease >= 2 && {toUpperANSI (_lease select 1) == "DOWN"}) then {_requestedProne=true};
    private _currentOperation=_reflexGroup getVariable ["WAIT_Operation",createHashMap];
    if (count _currentOperation == 0 || {(_currentOperation getOrDefault ["generation",-2]) != _movementGeneration}) then {_routeGenerationIntact=false};
};
private _movementArrived=[{_reflexUnit distance2D _movementDestination < 6},45] call _wait;
["DANGER-committed-mover-not-forced-prone",_movementStarted && {_movementDanger} && {!_requestedProne},str [_requestedProne,unitPos _reflexUnit,stance _reflexUnit]] call _check;
["DANGER-committed-route-physical-continuity",_movementStarted && {_movementDanger} && {_routeGenerationIntact} && {_movementArrived},str [getPosATL _reflexUnit,_movementDestination,_movementGeneration,_reflexGroup getVariable ["WAIT_Operation",createHashMap]]] call _check;
deleteVehicle _movementGrenade;
[_reflexGroup,_movementGeneration,"AUDIT_COMPLETE"] call WAIT_fnc_OperationCancel;

// Prove the engine FSM sustains a real close hostile contact rather than ending after its first
// short posture. No target, reveal, doFire or synthetic danger is injected: the opponents must
// acquire and engage through the engine, and the finite recycle counter must advance while the
// hostile remains alive and known.
private _closeGroup=createGroup [west,true];
_closeGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_closeGroup setVariable ["WAIT_AIPass_Exclude",true,true];
_closeGroup setVariable ["acex_headless_blacklist",true,true];
private _closeTarget=_closeGroup createUnit ["B_Soldier_F",(getPosATL _reflexUnit) getPos [25,90],[],0,"NONE"];
_closeTarget allowDamage false;
_closeTarget disableAI "PATH";
_closeTarget setVariable ["acex_headless_blacklist",true,true];
_closeTarget setVariable ["WAIT_CortexQA_Label","CLOSE HOSTILE CONTACT",true];
_reflexUnit allowDamage false;
_reflexUnit setDir (_reflexUnit getDir _closeTarget);
_closeTarget setDir (_closeTarget getDir _reflexUnit);
_reflexGroup setCombatMode "RED";
private _closeShots=0;
private _closeShotHandler=_reflexUnit addEventHandler ["FiredMan",{missionNamespace setVariable ["WAIT_CortexQA_CloseDangerShots",(missionNamespace getVariable ["WAIT_CortexQA_CloseDangerShots",0])+1]}];
missionNamespace setVariable ["WAIT_CortexQA_CloseDangerShots",0];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_reflexUnit,_closeTarget],true];
private _recyclesBefore=(_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["recycles",0];
private _boundedRecycleEndsBefore=(_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["boundedRecycleEnds",0];
["Danger FSM: close hostile persistence","The two invulnerable opponents face each other at 25 metres. WAIT must retain the native contact across finite response cycles while native AI fires; no target or fire command is injected by the audit.",getPosATL _closeTarget] call _phase;
private _closePersistent=[{
    private _stats=_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
    (_stats getOrDefault ["recycles",0]) > _recyclesBefore
        && {(missionNamespace getVariable ["WAIT_CortexQA_CloseDangerShots",0]) > 0}
        && {_reflexUnit knowsAbout _closeTarget > 0}
},25] call _wait;
_closeShots=missionNamespace getVariable ["WAIT_CortexQA_CloseDangerShots",0];
["DANGER-close-contact-physical-persistence",_closePersistent,str [_closeShots,_reflexUnit knowsAbout _closeTarget,_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]]] call _check;
private _finiteReflexHandoff=[{
    private _stats=_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
    private _endsByMode=_stats getOrDefault ["boundedRecycleEndsByMode",createHashMap];
    private _cyclesByMode=_stats getOrDefault ["lastRecycleCyclesByMode",createHashMap];
    (_stats getOrDefault ["boundedRecycleEnds",0]) > _boundedRecycleEndsBefore
        && {(_endsByMode getOrDefault ["ENGAGE",0]) > 0}
        && {(_cyclesByMode getOrDefault ["ENGAGE",-1]) == 2}
        && {_reflexUnit knowsAbout _closeTarget > 0}
        && {(missionNamespace getVariable ["WAIT_CortexQA_CloseDangerShots",0]) > 0}
},12] call _wait;
["DANGER-close-contact-finite-reflex-handoff",_finiteReflexHandoff,str [_closeShots,_reflexUnit knowsAbout _closeTarget,_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap],_reflexGroup getVariable ["WAIT_Cortex_Phase",""]]] call _check;
_reflexUnit removeEventHandler ["FiredMan",_closeShotHandler];
missionNamespace setVariable ["WAIT_CortexQA_CloseDangerShots",nil];
deleteVehicle _closeTarget;
deleteGroup _closeGroup;

// A curator replacement order is the strongest live interruption edge. Trigger a real engine
// response, prove it became active, then install and mark an ordinary replacement waypoint through
// the production Zeus boundary. No danger action, cover move or stale response may return afterward.
_reflexGroup setCombatMode "YELLOW";
_reflexGroup setBehaviourStrong "AWARE";
private _zeusOrigin=getPosATL _reflexUnit;
private _zeusStatsBefore=(_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0];
private _zeusGrenade=[_zeusOrigin getPos [7,90]] call _spawnRealGrenade;
private _zeusDangerActive=[{
    ((_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0]) > _zeusStatsBefore
        && {(_reflexGroup getVariable ["WAIT_Danger_Response",[]]) isNotEqualTo []}
},12] call _wait;
private _zeusDestination=_zeusOrigin getPos [55,270];
private _zeusWaypoint=_reflexGroup addWaypoint [_zeusDestination,0];
_zeusWaypoint setWaypointType "MOVE";
_zeusWaypoint setWaypointBehaviour "AWARE";
_zeusWaypoint setWaypointCombatMode "YELLOW";
_zeusWaypoint setWaypointCompletionRadius 3;
_reflexGroup setCurrentWaypoint _zeusWaypoint;
[_reflexGroup,true,_zeusWaypoint select 1] call WAIT_fnc_CortexZeusMark;
_reflexUnit setVariable ["WAIT_CortexQA_Target",_zeusDestination,true];
["Danger FSM: Zeus replaces active response","A real explosion first activates the danger response. A production Zeus waypoint then takes ownership immediately; the soldier must travel to it without an old cover or danger command returning.",_zeusDestination] call _phase;
private _zeusCleared=[{
    (_reflexGroup getVariable ["WAIT_Danger_Response",[]]) isEqualTo []
        && {(_reflexGroup getVariable ["WAIT_Danger_Action",[]]) isEqualTo []}
        && {(_reflexGroup getVariable ["WAIT_Danger_CoverLease",[]]) isEqualTo []}
},12] call _wait;
private _zeusArrived=[{alive _reflexUnit && {_reflexUnit distance2D _zeusDestination < 7}},55] call _wait;
private _zeusStable=true;
for "_sample" from 1 to 8 do {sleep 0.5; if (_reflexUnit distance2D _zeusDestination > 10) then {_zeusStable=false}};
["DANGER-active-zeus-replacement",_zeusDangerActive && {_zeusCleared} && {_zeusArrived} && {_zeusStable},str [getPosATL _reflexUnit,_zeusDestination,_reflexGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]]] call _check;
deleteVehicle _zeusGrenade;

// Leader loss during a finite response must change the viable group anchor without ending the
// squad's ordinary movement. The explosion is native, the casualty is real damage and the final
// movement uses a normal group waypoint; no direct danger or operation callback is injected.
private _leaderLossGroup=createGroup [east,true];
_leaderLossGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_leaderLossGroup setVariable ["acex_headless_blacklist",true,true];
_leaderLossGroup setCombatMode "YELLOW";
private _lostLeader=_leaderLossGroup createUnit ["O_Soldier_F",[2420,1350,0],[],0,"NONE"];
private _newLeader=_leaderLossGroup createUnit ["O_Soldier_F",[2423,1350,0],[],0,"NONE"];
_lostLeader allowDamage false;
_newLeader allowDamage false;
{_x setVariable ["acex_headless_blacklist",true,true]} forEach [_lostLeader,_newLeader];
_leaderLossGroup selectLeader _lostLeader;
_lostLeader setVariable ["WAIT_CortexQA_Label","DANGER LEADER CASUALTY",true];
_newLeader setVariable ["WAIT_CortexQA_Label","DANGER SURVIVING ANCHOR",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_lostLeader,_newLeader],true];
private _leaderLossStatsBefore=(_leaderLossGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0];
private _leaderLossGrenade=[(getPosATL _lostLeader) getPos [7,90]] call _spawnRealGrenade;
private _leaderDangerActive=[{
    ((_leaderLossGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0]) > _leaderLossStatsBefore
        && {(_leaderLossGroup getVariable ["WAIT_Danger_Response",[]]) isNotEqualTo []}
},12] call _wait;
_lostLeader allowDamage true;
_lostLeader setDamage 1;
private _successorSelected=[{!alive _lostLeader && {leader _leaderLossGroup == _newLeader}},15] call _wait;
private _leaderLossDestination=[2485,1350,0];
private _leaderLossWaypoint=_leaderLossGroup addWaypoint [_leaderLossDestination,0];
_leaderLossWaypoint setWaypointType "MOVE";
_leaderLossWaypoint setWaypointBehaviour "AWARE";
_leaderLossWaypoint setWaypointCombatMode "YELLOW";
_leaderLossWaypoint setWaypointCompletionRadius 3;
_leaderLossGroup setCurrentWaypoint _leaderLossWaypoint;
_newLeader setVariable ["WAIT_CortexQA_Target",_leaderLossDestination,true];
["Danger FSM: leader loss continuity","A real explosion activates the squad response, then its leader becomes a casualty. The living successor must take command and physically continue the ordinary route while the finite response expires.",_leaderLossDestination] call _phase;
private _successorArrived=[{alive _newLeader && {_newLeader distance2D _leaderLossDestination < 7}},60] call _wait;
private _leaderDangerReleased=[{
    (_leaderLossGroup getVariable ["WAIT_Danger_Response",[]]) isEqualTo []
        && {(_leaderLossGroup getVariable ["WAIT_Danger_Action",[]]) isEqualTo []}
},12] call _wait;
["DANGER-leader-loss-physical-continuation",_leaderDangerActive && {_successorSelected} && {_successorArrived} && {_leaderDangerReleased},str [leader _leaderLossGroup,getPosATL _newLeader,_leaderLossDestination,_leaderLossGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]]] call _check;
deleteVehicle _leaderLossGrenade;
deleteVehicle _lostLeader;
deleteVehicle _newLeader;
deleteGroup _leaderLossGroup;

// A concrete native boarding task must remain the movement owner through a real danger event. The
// fixture waits for the engine GET IN command before detonating the grenade, then requires WAIT's
// FORCED branch to remain observation-only while the soldier physically reaches the assigned seat.
// No WAIT response, phase, target, movement or synthetic danger is written by this test.
private _forcedGroup=createGroup [east,true];
_forcedGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_forcedGroup setVariable ["acex_headless_blacklist",true,true];
_forcedGroup setCombatMode "BLUE";
private _forcedUnit=_forcedGroup createUnit ["O_Soldier_F",[2360,1350,0],[],0,"NONE"];
_forcedUnit allowDamage false;
_forcedUnit setVariable ["acex_headless_blacklist",true,true];
_forcedUnit setVariable ["WAIT_CortexQA_Label","FORCED BOARDING OWNER",true];
private _forcedVehicle=createVehicle ["O_Truck_03_transport_F",[2440,1350,0],[],0,"NONE"];
_forcedVehicle allowDamage false;
_forcedVehicle setDir 270;
_forcedUnit assignAsCargo _forcedVehicle;
[_forcedUnit] orderGetIn true;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_forcedUnit,_forcedVehicle],true];
["Danger FSM: native boarding ownership","The soldier has an ordinary engine GET IN task before a real grenade detonates. WAIT must observe FORCED, never publish infantry tactical authority, and allow physical boarding to finish.",getPosATL _forcedVehicle] call _phase;
private _forcedReady=[{toUpperANSI (currentCommand _forcedUnit) == "GET IN"},10] call _wait;
private _forcedModesBefore=((_forcedGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["modes",createHashMap]) getOrDefault ["FORCED",0];
private _forcedAcceptedBefore=(_forcedGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["acceptedRecords",0];
private _forcedTransitionCount=count (_forcedGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]);
private _forcedGrenade=[(getPosATL _forcedUnit) getPos [7,90]] call _spawnRealGrenade;
private _forcedNoHandoff=[{
    private _stats=_forcedGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
    private _modes=_stats getOrDefault ["modes",createHashMap];
    (_modes getOrDefault ["FORCED",0]) > _forcedModesBefore
        && {(_forcedGroup getVariable ["WAIT_Danger_Response",[]]) isEqualTo []}
        && {(_forcedGroup getVariable ["WAIT_Danger_Action",[]]) isEqualTo []}
        && {((_forcedGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["phase","CALM"]) == "CALM"}
},12] call _wait;
private _forcedTaskPreserved=true;
private _forcedBoarded=[{
    if (toUpperANSI currentCommand _forcedUnit == "GET IN") then {
        private _stats=_forcedGroup getVariable ["WAIT_Danger_EngineStats",createHashMap];
        if ((_forcedGroup getVariable ["WAIT_Danger_Response",[]]) isNotEqualTo []
            || {(_stats getOrDefault ["acceptedRecords",0]) != _forcedAcceptedBefore}
            || {((_forcedGroup getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["phase","CALM"]) == "CONTACT"}) then {_forcedTaskPreserved=false};
    };
    vehicle _forcedUnit == _forcedVehicle
},35] call _wait;
private _forcedTransitions=(_forcedGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]) select [_forcedTransitionCount];
private _forcedNeverContact=_forcedTransitions findIf {(_x param [2,""]) == "CONTACT"} < 0;
["DANGER-forced-order-no-tactical-handoff",_forcedReady && {_forcedNoHandoff} && {_forcedBoarded} && {_forcedTaskPreserved},
    str [currentCommand _forcedUnit,vehicle _forcedUnit,_forcedGroup getVariable ["WAIT_Danger_EngineStats",createHashMap],_forcedTransitions]] call _check;
deleteVehicle _forcedGrenade;
deleteVehicle _forcedUnit;
deleteVehicle _forcedVehicle;
deleteGroup _forcedGroup;

// A native order can also arrive after a real response is already active. This additive case first
// proves physical engine-FSM delivery, then assigns an ordinary cargo seat. WAIT must release the
// exact response actor promptly and the engine must finish boarding without a renewed tactical wake.
private _interruptGroup=createGroup [east,true];
_interruptGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_interruptGroup setVariable ["acex_headless_blacklist",true,true];
_interruptGroup setCombatMode "BLUE";
private _interruptUnit=_interruptGroup createUnit ["O_Soldier_F",[2420,1350,0],[],0,"NONE"];
_interruptUnit allowDamage false;
_interruptUnit setVariable ["acex_headless_blacklist",true,true];
_interruptUnit setVariable ["WAIT_CortexQA_Label","ACTIVE DANGER TO NATIVE ORDER",true];
private _interruptVehicle=createVehicle ["O_Truck_03_transport_F",[2450,1350,0],[],0,"NONE"];
_interruptVehicle allowDamage false;
_interruptVehicle setDir 270;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_interruptUnit,_interruptVehicle],true];
["Danger FSM: live response interrupted by native order","A real grenade must first activate WAIT's finite response. A later ordinary GET IN task must then remove that response before the soldier physically boards, without WAIT reissuing movement.",getPosATL _interruptVehicle] call _phase;
private _interruptSubmissionsBefore=(_interruptGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0];
private _interruptGrenade=[(getPosATL _interruptUnit) getPos [7,90]] call _spawnRealGrenade;
private _interruptDangerActive=[{
    ((_interruptGroup getVariable ["WAIT_Danger_EngineStats",createHashMap]) getOrDefault ["submissions",0]) > _interruptSubmissionsBefore
        && {(_interruptGroup getVariable ["WAIT_Danger_Response",[]]) isNotEqualTo []}
        && {(_interruptGroup getVariable ["WAIT_Danger_Action",[]]) isNotEqualTo []}
},12] call _wait;
_interruptUnit assignAsCargo _interruptVehicle;
[_interruptUnit] orderGetIn true;
private _interruptCommandReady=[{toUpperANSI (currentCommand _interruptUnit) == "GET IN"},10] call _wait;
private _interruptReleased=[{
    (_interruptGroup getVariable ["WAIT_Danger_Response",[]]) isEqualTo []
        && {(_interruptGroup getVariable ["WAIT_Danger_Action",[]]) isEqualTo []}
        && {(_interruptGroup getVariable ["WAIT_Danger_VehicleContext",[]]) isEqualTo []}
},5] call _wait;
private _interruptBoarded=[{vehicle _interruptUnit == _interruptVehicle},35] call _wait;
["DANGER-active-response-native-order-interrupt",_interruptDangerActive && {_interruptCommandReady}
    && {_interruptReleased} && {_interruptBoarded},str [currentCommand _interruptUnit,vehicle _interruptUnit,
    _interruptGroup getVariable ["WAIT_Danger_EngineStats",createHashMap],
    _interruptGroup getVariable ["WAIT_Cortex_PhaseTransitions",[]]]] call _check;
deleteVehicle _interruptGrenade;
deleteVehicle _interruptUnit;
deleteVehicle _interruptVehicle;
deleteGroup _interruptGroup;

deleteVehicle _dangerCoverWall;
deleteVehicle _reflexUnit;
deleteGroup _reflexGroup;

private _group=createGroup [east,true];
private _opposition=createGroup [west,true];
{
    _x setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
    _x setCombatMode "BLUE";
} forEach [_group,_opposition];
_opposition setVariable ["WAIT_AIPass_Exclude",true,true];
private _walls=[];
for "_i" from -4 to 4 do {
    private _wall=createVehicle ["Land_CncWall4_F",[2000+_i*4,1450,0],[],0,"CAN_COLLIDE"];
    _wall setDir 0;
    _walls pushBack _wall;
};
private _units=[];
for "_i" from 0 to 1 do {
    private _unit=_group createUnit ["O_Soldier_F",[1998+_i*4,1350,0],[],0,"NONE"];
    _unit setDir 0;
    _unit disableAI "PATH";
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["OBSERVER %1",_i+1],true];
    _units pushBack _unit;
};
private _enemy=_opposition createUnit ["B_Soldier_F",[2000,1470,0],[],0,"NONE"];
_enemy setDir 180;
_enemy setVariable ["acex_headless_blacklist",true,true];
_enemy setVariable ["WAIT_CortexQA_Label","HIDDEN ENEMY: MUST WALK INTO VIEW",true];
_enemy disableAI "PATH";
missionNamespace setVariable ["WAIT_CortexQA_Actors",_units+[_enemy],true];
["Contact: hidden enemy","The two observers face the concrete screen. The enemy behind it must remain unknown. This checks real sight rays and engine knowledge; no reveal command is used.",[2000,1400,0]] call _phase;
private _blocked=_units findIf {
    private _rays=lineIntersectsSurfaces [eyePos _x,eyePos _enemy,_x,_enemy,true,-1,"VIEW","GEOM"];
    _rays findIf {(_x select 2) in _walls || {(_x select 3) in _walls}} < 0
} < 0;
["CONTACT-fixture-occlusion",_blocked] call _check;
private _hidden=true;
for "_i" from 1 to 15 do {
    sleep 1;
    if ((([_group] call WAIT_fnc_CortexKnowledge) select 0) findIf {(_x select 0) == _enemy} >= 0) then {_hidden=false};
};
["CONTACT-no-hidden-acquisition",_blocked && {_hidden},str (_units apply {_x knowsAbout _enemy})] call _check;
["Contact: physical exposure","Watch the enemy walk around the screen to the yellow destination. Observers must naturally detect him there. The cyan trace is actual travel; setting a contact flag cannot pass this stage.",[2000,1420,0]] call _phase;
private _destination=[2040,1450,0];
_enemy setVariable ["WAIT_CortexQA_Target",_destination,true];
_enemy enableAI "PATH";
_enemy doMove _destination;
private _arrived=[{alive _enemy && {_enemy distance2D _destination < 3}},65] call _wait;
["CONTACT-enemy-physical-exposure",_arrived,str getPosATL _enemy] call _check;
private _detected=[{
    private _knowledge=([_group] call WAIT_fnc_CortexKnowledge) select 0;
    _knowledge findIf {(_x select 0) == _enemy && {(_x select 2) <= 5}} >= 0
},45] call _wait;
["CONTACT-natural-visible-acquisition",_arrived && {_detected},str (_units apply {_x targetKnowledge _enemy})] call _check;
["CONTACT-live-contact-phase",_detected && {[{((_group getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["phase",""]) == "CONTACT"},15] call _wait}] call _check;
// Losing sight must age knowledge rather than continuously refreshing a hidden target.
private _hiddenDestination=[2000,1470,0];
["Contact: lose visual contact","The same enemy walks back behind the concrete screen. Watch the cyan travel and remaining distance. Once every observer's sight line is blocked, the last-seen age must increase; remembered contact is allowed, fresh hidden sight is not.",[2000,1450,0]] call _phase;
_enemy setVariable ["WAIT_CortexQA_Target",_hiddenDestination,true];
_enemy doMove _hiddenDestination;
private _hiddenArrival=[{_enemy distance2D _hiddenDestination < 3},65] call _wait;
private _hiddenAgain=_units findIf {
    private _rays=lineIntersectsSurfaces [eyePos _x,eyePos _enemy,_x,_enemy,true,-1,"VIEW","GEOM"];
    _rays findIf {(_x select 2) in _walls || {(_x select 3) in _walls}} < 0
} < 0;
["CONTACT-reocclusion-physical-prerequisite",_hiddenArrival && {_hiddenAgain},str getPosATL _enemy] call _check;
sleep 12;
private _remembered=([_group] call WAIT_fnc_CortexKnowledge) select 0;
["CONTACT-hidden-sighting-ages",_detected && {_hiddenArrival} && {_hiddenAgain} && {_remembered findIf {(_x select 0) == _enemy && {(_x select 2) <= 5}} < 0},str (_units apply {_x targetKnowledge _enemy})] call _check;
["Contact: reacquire the same enemy","The enemy walks out again. Without reveal, a forced contact flag or new actors, the observers must produce a fresh natural sighting. This checks the full visible-hidden-visible transition.",[2020,1450,0]] call _phase;
_enemy setVariable ["WAIT_CortexQA_Target",_destination,true];
_enemy doMove _destination;
private _returned=[{_enemy distance2D _destination < 3},65] call _wait;
private _reacquired=[{(([_group] call WAIT_fnc_CortexKnowledge) select 0) findIf {(_x select 0) == _enemy && {(_x select 2) <= 5}} >= 0},45] call _wait;
["CONTACT-natural-reacquisition",_hiddenArrival && {_hiddenAgain} && {_returned} && {_reacquired},str (_units apply {_x targetKnowledge _enemy})] call _check;
// Add physical lifecycle acceptance after the original sight-loss comparisons.
// Remove the stimulus, not Cortex state. Release fixture-only observer path locks.
[createHashMapFromArray [["WAIT_AIPass_PostContact_Enable",true]]] call WAIT_fnc_CortexTuning;
private _contactBeforeRemoval=((_group getVariable ["WAIT_AIPass_State",createHashMap]) getOrDefault ["phase",""]) == "CONTACT";
private _lastPosition=getPosATL _enemy;
deleteVehicle _enemy;
{_x enableAI "PATH"; _x setVariable ["WAIT_CortexQA_Target",_lastPosition,true]} forEach _units;
private _sequence=[];
private _transitionSamples=[];
private _searchStart=createHashMap;
private _searchTravel=0;
private _searchApproach=false;
private _lastPhase="";
private _searchInterrupted=false;
private _searchReleased=false;
private _interruptEnemy=objNull;
private _interruptSpawned=false;
["Transitions: contact lost","The enemy is removed. The same soldiers must hold, physically search the last sighting, rejoin and return to calm. No state is assigned by this test; yellow destinations and cyan trails show real movement.",_lastPosition] call _phase;
private _calm=[{
    private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
    private _current=_state getOrDefault ["phase","UNMANAGED"];
    if (_current != _lastPhase) then {
        _lastPhase=_current;
        _sequence pushBack _current;
        private _sample=[serverTime,_current,_units apply {[netId _x,getPosATL _x,currentCommand _x]}];
        _transitionSamples pushBack _sample;
        diag_log format ["WAIT CORTEX QA TRANSITION: %1",_sample];
        {_x setVariable ["WAIT_CortexQA_Label",format ["TRANSITION %1 | %2",_current,_forEachIndex+1],true]} forEach _units;
        ["Transitions: "+_current,"Watch the current action and actual travel. Search must approach the former contact; regroup must close the squad. A phase name alone cannot pass.",getPosATL leader _group] call _phase;
    };
    if (_current == "SEARCH") then {
        {
            private _key=netId _x;
            if !(_key in _searchStart) then {_searchStart set [_key,getPosATL _x]};
            _searchTravel=_searchTravel max (_x distance2D (_searchStart get _key));
            if (_x distance2D _lastPosition < 20) then {_searchApproach=true};
        } forEach (_state getOrDefault ["searchTeam",[]]);
        // Reacquire a real visible opponent during the first search. This must interrupt the
        // search through production sensing; no reveal, phase write or direct callback is used.
        if (!_interruptSpawned && {_searchTravel >= 5}) then {
            _interruptEnemy=_opposition createUnit ["B_Soldier_F",_lastPosition getPos [12,90],[],0,"NONE"];
            _interruptEnemy setDir (_interruptEnemy getDir leader _group);
            _interruptEnemy disableAI "PATH";
            _interruptEnemy setVariable ["acex_headless_blacklist",true,true];
            _interruptEnemy setVariable ["WAIT_CortexQA_Label","SEARCH INTERRUPTION: NATURAL CONTACT",true];
            _interruptSpawned=true;
            missionNamespace setVariable ["WAIT_CortexQA_Actors",_units+[_interruptEnemy],true];
            ["Transitions: search interrupted by contact","A real opponent has appeared while the search team is moving. Cortex must release the old search movement, return to CONTACT and later complete a fresh post-contact cycle.",getPosATL _interruptEnemy] call _phase;
        };
    };
    if (_interruptSpawned && {!_searchInterrupted} && {_current == "CONTACT"}) then {
        _searchInterrupted=true;
        _searchReleased=(_state getOrDefault ["searchTeam",[]]) isEqualTo [];
        deleteVehicle _interruptEnemy;
        _interruptEnemy=objNull;
        missionNamespace setVariable ["WAIT_CortexQA_Actors",_units,true];
    };
    _current == "CALM" && {_searchInterrupted} && {"REGROUP" in _sequence}
},180] call _wait;
private _orderedSequence=(["SECURITY","SEARCH","REGROUP","CALM"] findIf {!(_x in _sequence)}) < 0
    && {(_sequence find "SECURITY") < (_sequence find "SEARCH")}
    && {(_sequence find "SEARCH") < (_sequence find "REGROUP")}
    && {(_sequence find "REGROUP") < (_sequence find "CALM")};
["TRANS-contact-postcontact-sequence",_contactBeforeRemoval && {_orderedSequence} && {_calm},str _sequence] call _check;
private _phaseHistory=_group getVariable ["WAIT_Cortex_PhaseTransitions",[]];
private _publishedPhases=_phaseHistory apply {_x param [2,""]};
// The ledger normally contains its initial CALM entry and may contain an interrupted first search.
// Compare the first valid ordered subsequence instead of comparing every phase with the earliest
// CALM in history, which incorrectly fails a complete SECURITY -> SEARCH -> REGROUP -> CALM cycle.
private _findPublishedAfter={
    params ["_phases","_wanted","_after"];
    private _relative=(_phases select [_after+1]) find _wanted;
    if (_relative < 0) exitWith {-1};
    _after+1+_relative
};
private _publishedSecurity=_publishedPhases find "SECURITY";
private _publishedSearch=[_publishedPhases,"SEARCH",_publishedSecurity] call _findPublishedAfter;
private _publishedRegroup=[_publishedPhases,"REGROUP",_publishedSearch] call _findPublishedAfter;
private _publishedCalm=[_publishedPhases,"CALM",_publishedRegroup] call _findPublishedAfter;
private _publishedOrder=_publishedSecurity >= 0 && {_publishedSearch > _publishedSecurity}
    && {_publishedRegroup > _publishedSearch} && {_publishedCalm > _publishedRegroup};
private _latestPhase=_group getVariable ["WAIT_Cortex_PhaseTransition",[]];
["TRANS-published-phase-ledger",_calm && {_publishedOrder} && {count _phaseHistory <= 32}
    && {(_latestPhase param [2,""]) == "CALM"},str _phaseHistory] call _check;
private _searchContactTransition=_phaseHistory findIf {
    (_x param [1,""]) == "SEARCH" && {(_x param [2,""]) == "CONTACT"}
        && {(_x param [3,""]) == "VISIBLE_CONTACT"}
};
["TRANS-search-contact-interruption",_searchInterrupted && {_searchReleased}
    && {_searchContactTransition >= 0},str [_searchReleased,_phaseHistory]] call _check;
["TRANS-search-physical-approach",_searchTravel >= 15 && {_searchApproach},str [_searchTravel,_searchApproach,_transitionSamples]] call _check;
["TRANS-regroup-physical-cohesion",_calm && {_units findIf {!alive _x || {_x distance2D leader _group > 20}} < 0},str (_units apply {getPosATL _x})] call _check;
private _resumeDestination=(getPosATL leader _group) getPos [70,90];
private _resumeStart=_units apply {getPosATL _x};
private _resumeWP=_group addWaypoint [_resumeDestination,0];
_resumeWP setWaypointType "MOVE";
_resumeWP setWaypointCompletionRadius 4;
_group setCurrentWaypoint _resumeWP;
{_x setVariable ["WAIT_CortexQA_Target",_resumeDestination,true]} forEach _units;
["Transitions: fresh orders after calm","Both soldiers must now physically walk to the new waypoint. No posture, behaviour or Cortex state reset is supplied; lingering search or regroup orders must not pull them back.",_resumeDestination] call _phase;
private _resumed=[{_units findIf {!alive _x || {_x distance2D _resumeDestination > 12} || {_x distance2D (_resumeStart select (_units find _x)) < 30}} < 0},90] call _wait;
["TRANS-calm-new-orders-physical-arrival",_calm && {_resumed},str (_units apply {getPosATL _x})] call _check;
private _heldDestination=_resumed;
private _largestReturnDistance=0;
for "_sample" from 1 to 15 do {
    sleep 1;
    {
        _largestReturnDistance=_largestReturnDistance max (_x distance2D _resumeDestination);
        if (!alive _x || {_x distance2D _resumeDestination > 15}) then {_heldDestination=false};
    } forEach _units;
};
["TRANS-no-old-search-order-resurrection",_heldDestination,format ["maximumDistance=%1",_largestReturnDistance]] call _check;

// An empty static weapon is an actor-level support opportunity inside the same contact brain. The
// fixture first proves the disabled state, then enables the production gate and requires a real
// gunner-seat occupation plus real fire from the emplacement and another squad member. No moveIn,
// reveal, assigned target or audit callback is used. Removing the hostile must release the exact
// assignment without holding the rest of the squad in CONTACT.
private _staticGroup=createGroup [east,true];
private _staticOpposition=createGroup [west,true];
{
    _x setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
} forEach [_staticGroup,_staticOpposition];
_staticOpposition setVariable ["WAIT_AIPass_Exclude",true,true];
_staticGroup setCombatMode "RED";
private _staticUnits=[];
for "_i" from 0 to 3 do {
    private _unit=_staticGroup createUnit ["O_Soldier_F",[2580+(_i mod 2)*3,1360+floor (_i/2)*3,0],[],0,"NONE"];
    _unit setDir 0;
    _unit allowDamage false;
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["STATIC SUPPORT %1",_i+1],true];
    _unit setVariable ["WAIT_CortexQA_Shots",0];
    _unit addEventHandler ["FiredMan",{params ["_unit"]; _unit setVariable ["WAIT_CortexQA_Shots",(_unit getVariable ["WAIT_CortexQA_Shots",0])+1]}];
    _staticUnits pushBack _unit;
};
private _staticWeapon=createVehicle ["O_HMG_01_F",[2588,1365,0],[],0,"NONE"];
_staticWeapon allowDamage false;
_staticWeapon setDir 0;
_staticWeapon setVariable ["WAIT_CortexQA_Shots",0];
_staticWeapon addEventHandler ["Fired",{params ["_weapon"]; _weapon setVariable ["WAIT_CortexQA_Shots",(_weapon getVariable ["WAIT_CortexQA_Shots",0])+1]}];
private _staticEnemy=_staticOpposition createUnit ["B_Soldier_F",[2588,1460,0],[],0,"NONE"];
_staticEnemy allowDamage false;
_staticEnemy disableAI "PATH";
_staticEnemy setDir 180;
_staticEnemy setVariable ["acex_headless_blacklist",true,true];
_staticEnemy setVariable ["WAIT_CortexQA_Label","STATIC SUPPORT TARGET",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_staticUnits+[_staticWeapon,_staticEnemy],true];
[createHashMapFromArray [["WAIT_AIPass_StaticSupport_Enable",false]]] call WAIT_fnc_CortexTuning;
["Danger tactics: nearby static disabled","The squad must naturally contact the target but leave the nearby empty HMG unassigned while the feature is disabled.",getPosATL _staticWeapon] call _phase;
private _staticContact=[{(([_staticGroup] call WAIT_fnc_CortexKnowledge) select 0) findIf {(_x select 0) == _staticEnemy} >= 0},30] call _wait;
private _staticReady=_staticContact && {[{
    _staticGroup getVariable ["WAIT_AIPass_Managed",false]
        && {(_staticGroup getVariable ["WAIT_AIPass_PublicPhase",""]) == "CONTACT"}
},20] call _wait};
["DANGER-static-support-fixture-ready",_staticReady,str [
    _staticGroup getVariable ["WAIT_AIPass_Managed",false],
    _staticGroup getVariable ["WAIT_AIPass_PublicPhase",""],
    _staticGroup getVariable ["WAIT_AIPass_State",createHashMap]
]] call _check;
sleep 6;
private _staticDisabled=gunner _staticWeapon isEqualTo objNull
    && {(_staticGroup getVariable ["WAIT_Danger_StaticSupport",[]]) isEqualTo []};
["DANGER-static-support-disabled",_staticReady && {_staticDisabled},str [gunner _staticWeapon,_staticGroup getVariable ["WAIT_Danger_StaticSupport",[]]]] call _check;
[createHashMapFromArray [["WAIT_AIPass_StaticSupport_Enable",true]]] call WAIT_fnc_CortexTuning;
// The disabled path does not consume the contact episode's single attempt. Opening the live gate
// therefore exercises production selection during the same natural contact without assigning a
// phase, revealing a target or invoking a production callback from the audit.
private _staticOccupied=[{!isNull gunner _staticWeapon && {gunner _staticWeapon in _staticUnits}},35] call _wait;
private _staticGunner=gunner _staticWeapon;
private _staticFired=[{(_staticWeapon getVariable ["WAIT_CortexQA_Shots",0]) > 0},30] call _wait;
private _staticSquadFired=[{
    _staticUnits findIf {_x != _staticGunner && {(_x getVariable ["WAIT_CortexQA_Shots",0]) > 0}} >= 0
},30] call _wait;
["DANGER-static-support-physical-seat",_staticOccupied,str [
    _staticGunner,assignedVehicle _staticGunner,
    _staticGroup getVariable ["WAIT_Danger_StaticSupport",[]],
    _staticGroup getVariable ["WAIT_Danger_StaticAttempt",[]],
    _staticUnits apply {currentCommand _x}
]] call _check;
["DANGER-static-support-composable-fire",_staticOccupied && {_staticFired} && {_staticSquadFired},str [_staticWeapon getVariable ["WAIT_CortexQA_Shots",0],_staticUnits apply {_x getVariable ["WAIT_CortexQA_Shots",0]}]] call _check;
deleteVehicle _staticEnemy;
private _staticReleased=[{
    (_staticGroup getVariable ["WAIT_Danger_StaticSupport",[]]) isEqualTo []
        && {isNull assignedVehicle _staticGunner}
        && {vehicle _staticGunner == _staticGunner}
},75] call _wait;
["DANGER-static-support-contact-cleanup",_staticOccupied && {_staticReleased},str [vehicle _staticGunner,assignedVehicle _staticGunner,_staticGroup getVariable ["WAIT_Danger_StaticSupport",[]]]] call _check;
{deleteVehicle _x} forEach (_staticUnits+[_staticWeapon]);
deleteGroup _staticGroup;
deleteGroup _staticOpposition;

// A carried support team must use the engine's real two-bag assembly path. The fixture supplies only
// compatible backpacks and a natural hostile contact. It neither creates the resulting emplacement
// nor calls the deployment helper. Acceptance requires the expected physical weapon, the original
// primary-bag carrier in its real gunner seat, real fire and exact assignment release after contact.
private _deployGroup=createGroup [east,true];
private _deployOpposition=createGroup [west,true];
{
    _x setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
} forEach [_deployGroup,_deployOpposition];
_deployOpposition setVariable ["WAIT_AIPass_Exclude",true,true];
_deployGroup setCombatMode "RED";
private _deployUnits=[];
for "_i" from 0 to 3 do {
    private _unit=_deployGroup createUnit ["O_Soldier_F",[2740+(_i mod 2)*3,1360+floor (_i/2)*3,0],[],0,"NONE"];
    _unit setDir 0;
    _unit allowDamage false;
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["CARRIED SUPPORT %1",_i+1],true];
    _deployUnits pushBack _unit;
};
private _deployGunner=_deployUnits select 1;
private _deployAssistant=_deployUnits select 2;
removeBackpack _deployGunner;
removeBackpack _deployAssistant;
_deployGunner addBackpack "O_HMG_01_weapon_F";
_deployAssistant addBackpack "O_HMG_01_support_F";
private _deployExpected=getText (configFile >> "CfgVehicles" >> backpack _deployGunner >> "assembleInfo" >> "assembleTo");
private _deployBases=getArray (configFile >> "CfgVehicles" >> backpack _deployGunner >> "assembleInfo" >> "base");
if (_deployBases isEqualTo []) then {
    private _baseText=getText (configFile >> "CfgVehicles" >> backpack _deployGunner >> "assembleInfo" >> "base");
    if (_baseText != "") then {_deployBases=[_baseText]};
};
private _deployConfigValid=_deployExpected != "" && {backpack _deployAssistant in _deployBases};
private _deployEnemy=_deployOpposition createUnit ["B_Soldier_F",[2740,1470,0],[],0,"NONE"];
_deployEnemy allowDamage false;
_deployEnemy disableAI "PATH";
_deployEnemy setDir 180;
_deployEnemy setVariable ["acex_headless_blacklist",true,true];
_deployEnemy setVariable ["WAIT_CortexQA_Label","CARRIED SUPPORT TARGET",true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_deployUnits+[_deployEnemy],true];
[createHashMapFromArray [
    ["WAIT_AIPass_StaticSupport_Enable",true],
    ["WAIT_AIPass_StaticDeploy_Enable",true],
    ["WAIT_AIPass_PostContact_Enable",true],
    ["WAIT_AIPass_PostContact_LostSeconds",3],
    ["WAIT_AIPass_PostContact_SecuritySeconds",20]
]] call WAIT_fnc_CortexTuning;
["Danger tactics: carried static deployment","A real compatible weapon team faces a naturally detected enemy. The pair must physically assemble the weapon, the primary-bag carrier must board its gunner seat and the real emplacement must fire without holding the rest of the squad.",getPosATL _deployGunner] call _phase;
private _deployContact=[{(([_deployGroup] call WAIT_fnc_CortexKnowledge) select 0) findIf {(_x select 0) == _deployEnemy} >= 0},35] call _wait;
private _deployReady=_deployContact && {[{
    _deployGroup getVariable ["WAIT_AIPass_Managed",false]
        && {(_deployGroup getVariable ["WAIT_AIPass_PublicPhase",""]) == "CONTACT"}
},20] call _wait};
["DANGER-static-deploy-fixture-ready",_deployReady,str [
    _deployGroup getVariable ["WAIT_AIPass_Managed",false],
    _deployGroup getVariable ["WAIT_AIPass_PublicPhase",""],
    _deployGroup getVariable ["WAIT_AIPass_State",createHashMap]
]] call _check;
private _deployActive=[{
    private _record=_deployGroup getVariable ["WAIT_Danger_StaticDeployment",[]];
    count _record >= 10
        && {(_record param [1,""]) == "ACTIVE"}
        && {!isNull (_record param [7,objNull,[objNull]])}
        && {typeOf (_record select 7) == _deployExpected}
        && {gunner (_record select 7) == _deployGunner}
},55] call _wait;
private _deployRecord=_deployGroup getVariable ["WAIT_Danger_StaticDeployment",[]];
private _deployedWeapon=_deployRecord param [7,objNull,[objNull]];
if (!isNull _deployedWeapon) then {
    _deployedWeapon setVariable ["WAIT_CortexQA_Shots",0];
    _deployedWeapon addEventHandler ["Fired",{
        params ["_weapon"];
        _weapon setVariable ["WAIT_CortexQA_Shots",(_weapon getVariable ["WAIT_CortexQA_Shots",0])+1];
    }];
};
private _deployFired=[{!isNull _deployedWeapon && {(_deployedWeapon getVariable ["WAIT_CortexQA_Shots",0]) > 0}},35] call _wait;
["DANGER-static-deploy-config-prerequisite",_deployConfigValid,str [_deployExpected,_deployBases,backpack _deployAssistant]] call _check;
["DANGER-static-deploy-physical-assembly",_deployReady && {_deployActive},str [_deployGroup getVariable ["WAIT_Danger_StaticDeployment",[]],vehicle _deployGunner]] call _check;
private _deployBearing=if (isNull _deployedWeapon) then {180} else {abs (((_deployedWeapon getRelDir _deployEnemy)+180) mod 360-180)};
["DANGER-static-deploy-facing-sector",_deployActive && {_deployBearing <= 15},str [_deployedWeapon,_deployBearing]] call _check;
["DANGER-static-deploy-real-fire",_deployActive && {_deployFired},str [_deployedWeapon,_deployedWeapon getVariable ["WAIT_CortexQA_Shots",0]]] call _check;
deleteVehicle _deployEnemy;
private _deployReleased=[{
    (_deployGroup getVariable ["WAIT_Danger_StaticDeployment",[]]) isEqualTo []
        && {isNull assignedVehicle _deployGunner}
        && {vehicle _deployGunner == _deployGunner}
},75] call _wait;
["DANGER-static-deploy-contact-release",_deployActive && {_deployReleased},str [vehicle _deployGunner,assignedVehicle _deployGunner,_deployGroup getVariable ["WAIT_Danger_StaticDeployment",[]]]] call _check;
private _deployPacked=_deployReleased && {isNull _deployedWeapon}
    && {backpack _deployGunner == "O_HMG_01_weapon_F"}
    && {backpack _deployAssistant == "O_HMG_01_support_F"};
["DANGER-static-deploy-native-pack",_deployActive && {_deployPacked},str [_deployedWeapon,backpack _deployGunner,backpack _deployAssistant,_deployGroup getVariable ["WAIT_Danger_StaticDeployAttempt",[]]]] call _check;
{deleteVehicle _x} forEach (_deployUnits+[_deployedWeapon]);
deleteGroup _deployGroup;
deleteGroup _deployOpposition;

sleep 8;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach (_units+[_enemy]+_walls);
deleteGroup _group; deleteGroup _opposition;

// Real FiredNear delivery remains observation-only while Zeus owns the waypoint chain.
[createHashMapFromArray [["WAIT_AIPass_Hearing_Enable",true]]] call WAIT_fnc_CortexTuning;
private _hearingGroup=createGroup [east,true];
_hearingGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_hearingGroup setCombatMode "BLUE";
private _hearingActor=_hearingGroup createUnit ["O_Soldier_F",[2600,1700,0],[],0,"NONE"];
_hearingActor allowDamage false;
private _hearingOrigin=getPosATL _hearingActor;
private _hearingDestination=[2600,1820,0];
private _hearingWaypoint=_hearingGroup addWaypoint [_hearingDestination,0];
_hearingWaypoint setWaypointType "MOVE";
_hearingWaypoint setWaypointCombatMode "BLUE";
_hearingWaypoint setWaypointBehaviour "AWARE";
_hearingGroup setCurrentWaypoint _hearingWaypoint;
[_hearingGroup,true,_hearingWaypoint select 1] call WAIT_fnc_CortexZeusMark;
[_hearingGroup] call WAIT_fnc_CortexHearingLocal;
private _hearingEnemyGroup=createGroup [west,true];
_hearingEnemyGroup setVariable ["WAIT_AIPass_Exclude",true,true];
_hearingEnemyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
private _hearingEnemy=_hearingEnemyGroup createUnit ["B_Soldier_F",[2620,1700,0],[],0,"NONE"];
_hearingEnemy allowDamage false;
_hearingEnemy setVariable ["WAIT_CortexQA_HearingShots",0];
_hearingEnemy addEventHandler ["FiredMan",{
    params ["_actor"];
    _actor setVariable ["WAIT_CortexQA_HearingShots",(_actor getVariable ["WAIT_CortexQA_HearingShots",0])+1];
}];
_hearingEnemy disableAI "MOVE";
_hearingEnemy setDir 90;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_hearingActor,_hearingEnemy],true];
["Zeus waypoint: hearing assistance","Real nearby rifle fire must create only an uncertain SOUND report. The observer must continue toward the Zeus waypoint with BLUE fire discipline and no WAIT movement operation.",_hearingOrigin] call _phase;
private _hearingWeapon=primaryWeapon _hearingEnemy;
_hearingEnemy selectWeapon _hearingWeapon;
sleep 0.5;
private _hearingWeaponState=weaponState _hearingEnemy;
_hearingEnemy forceWeaponFire [_hearingWeaponState param [1,_hearingWeapon],_hearingWeaponState param [2,"Single"]];
private _heard=[{(_hearingGroup getVariable ["WAIT_AIPass_AreaReport",[]]) param [3,""] == "SOUND"},8] call _wait;
["ZEUS-hearing-real-shot-prerequisite",(_hearingEnemy getVariable ["WAIT_CortexQA_HearingShots",0]) > 0,str (weaponState _hearingEnemy)] call _check;
private _hearingProgress=[{_hearingActor distance2D _hearingOrigin >= 20},35] call _wait;
["ZEUS-hearing-real-sound-report",_heard,str (_hearingGroup getVariable ["WAIT_AIPass_AreaReport",[]])] call _check;
["ZEUS-hearing-authored-movement",_hearingProgress && {combatMode _hearingGroup == "BLUE"}
    && {count (_hearingGroup getVariable ["WAIT_Operation",createHashMap]) == 0},str [getPosATL _hearingActor,combatMode _hearingGroup,_hearingGroup getVariable ["WAIT_Operation",createHashMap]]] call _check;
// A direct edit supersedes the waypoint domain even inside the mark throttle interval. Keep the
// existing report as evidence and require its timestamp not to change under another real shot.
[_hearingGroup,true,_hearingWaypoint select 1] call WAIT_fnc_CortexZeusMark;
[_hearingGroup] call WAIT_fnc_CortexZeusMark;
private _directReport=+(_hearingGroup getVariable ["WAIT_AIPass_AreaReport",[]]);
private _directShots=_hearingEnemy getVariable ["WAIT_CortexQA_HearingShots",0];
sleep 11;
_hearingEnemy setPosATL ((getPosATL _hearingActor) getPos [20,90]);
_hearingEnemy forceWeaponFire [_hearingWeaponState param [1,_hearingWeapon],_hearingWeaponState param [2,"Single"]];
private _directShot=[{(_hearingEnemy getVariable ["WAIT_CortexQA_HearingShots",0]) > _directShots},3] call _wait;
sleep 1;
["ZEUS-hearing-direct-edit-yields",_directShot
    && {(_hearingGroup getVariable ["WAIT_AIPass_ZeusControlKind",""]) == "DIRECT"}
    && {(_hearingGroup getVariable ["WAIT_AIPass_AreaReport",[]]) isEqualTo _directReport},
    str [_directShot,_directReport,_hearingGroup getVariable ["WAIT_AIPass_AreaReport",[]]]] call _check;
[_hearingGroup,true] call WAIT_fnc_CortexHearingLocal;
{deleteVehicle _x} forEach [_hearingActor,_hearingEnemy];
deleteGroup _hearingGroup;
deleteGroup _hearingEnemyGroup;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];

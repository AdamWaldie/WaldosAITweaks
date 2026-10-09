/*
 * Author: WaldoTheWarfighter
 * Purpose: Preserve one useful armed vehicle after its primary gunner is lost by assigning an
 * eligible existing commander to the empty gunner role during a confirmed danger generation.
 * Locality / Authority: Runs on the current group owner. It changes only a local AI commander's
 * assigned vehicle role and asks the engine to perform an internal seat change. Zeus, player,
 * specialist, convoy and authored task ownership always win.
 * Repeat/JIP: Finite and generation-owned. The caller records every attempted generation, so a
 * rejected or accepted recovery cannot churn assignments. A new owner evaluates only later danger.
 * Arguments: 0: group <GROUP>, grpNull; 1: vehicle <OBJECT>, objNull; 2: hostile <OBJECT>, objNull;
 * 3: cause <STRING>, ""; 4: danger generation <NUMBER>, -1.
 * Return Value: Boolean - true only when a seat-change request was issued.
 * Current callers: WAIT_fnc_CortexVehicles exact-platform danger response.
 * Example: [group driver cursorObject,cursorObject,objNull,"DETECTED",4] call WAIT_fnc_CortexVehicleCrewRecover;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_vehicle",objNull,[objNull]],
    ["_hostile",objNull,[objNull]],
    ["_cause","",[""]],
    ["_generation",-1,[0]]
];
private _reject={
    params ["_reason"];
    if (!isNull _group && {local _group}) then {
        private _commander=if (isNull _vehicle) then {objNull} else {commander _vehicle};
        _group setVariable ["WAIT_Danger_CrewRecoveryDecision",[serverTime,clientOwner,_generation,_reason,_cause,
            if (isNull _vehicle) then {-1} else {speed _vehicle},
            if (isNull _commander) then {""} else {currentCommand _commander},
            if (isNull _commander || {isNull _hostile}) then {-1} else {_commander knowsAbout _hostile}]];
    };
    false
};
if (isNull _group || {!local _group} || {isNull _vehicle} || {!local _vehicle}
    || {_generation < 0} || {_cause != "DETECTED"}
    || {!alive _vehicle} || {!canMove _vehicle} || {!someAmmo _vehicle}
    || {abs speed _vehicle >= 20} || {_vehicle getVariable ["WAIT_Convoy_Active",false]}
    || {!([_group,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {[_group] call WAIT_fnc_CortexZeusHeld}) exitWith {["PLATFORM_OR_OWNERSHIP"] call _reject};
if (!isNull gunner _vehicle && {alive gunner _vehicle}) exitWith {["GUNNER_ALIVE"] call _reject};
if (isNull _hostile || {!alive _hostile}
    || {(side _group) getFriend (side _hostile) >= 0.6}) exitWith {["HOSTILE_INVALID"] call _reject};

// A dedicated commander may change seats without sacrificing steering. A driver is deliberately
// never reassigned: preserving mobility and an authored route is more valuable than recovering a
// weapon, and WAIT must not manufacture a replacement crew member.
private _candidate=commander _vehicle;
if (isNull _candidate || {!alive _candidate} || {!local _candidate} || {isPlayer _candidate}
    || {group _candidate != _group} || {_candidate == driver _vehicle}
    || {!([_candidate] call WAIT_fnc_CortexCombatEffective)}) exitWith {["COMMANDER_INELIGIBLE"] call _reject};
private _command=toUpperANSI currentCommand _candidate;
if (fleeing _candidate || {_command in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN"]}) exitWith {["NATIVE_TASK"] call _reject};
if (_candidate knowsAbout _hostile <= 0) exitWith {["NO_NATIVE_KNOWLEDGE"] call _reject};

_candidate assignAsGunner _vehicle;
_candidate action ["MoveToGunner",_vehicle];
_vehicle setVariable ["WAIT_Danger_CrewRecovery",[_generation,_candidate,_hostile,serverTime],true];
true

/*
 * Author: WaldoTheWarfighter
 * Restores recorded formation, attack permission, vehicle speed, unload settings and exact external controller
 * per-vehicle baselines; cancels only follower paths.
 * Locality/authority: server owns registration; driving commands execute only on current owners.
 * Repeat/JIP: ordered registry snapshots replace old settings; owner-local paths rebuild on migration.
 * Arguments: 0: group <GROUP>, grpNull; 1: forget baseline <BOOL>, true; 2: baseline <ARRAY>, [] reads the locally received baseline; 3: still-controlled vehicles <ARRAY>, []; 4: cancellation reason <STRING, RELEASED>.
 * Return Value: Nothing.
 * Current callers: ConvoySync and ConvoyTick.
 * Example: [convoyGroup] call WAIT_fnc_ConvoyReleaseLocal;
 */
params [["_group", grpNull, [grpNull]], ["_forget", true, [true]], ["_restore", [], [[]]], ["_keepCrew", [], [[]]], ["_reason", "RELEASED", [""]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {};
if (local _group) then {
    private _state = _group getVariable ["WAIT_Convoy_LocalState",createHashMap];
    private _generation = _state getOrDefault ["operationGeneration",-1];
    private _operation = _group getVariable ["WAIT_Operation",createHashMap];
    if (_generation >= 0 && {(_operation getOrDefault ["intent",""]) == "CONVOY"}) then {
        [_group,_generation,toUpperANSI _reason] call WAIT_fnc_OperationCancel;
    };
};
if (_restore isEqualTo []) then {_restore = _group getVariable ["WAIT_Convoy_Restore", []]};
if (_restore isNotEqualTo []) then {
    _restore params ["_formation", "_attack", "_vehicles"];
    if (local _group) then {
        if (formation _group == "COLUMN") then {_group setFormation _formation};
        _group enableAttack _attack;
    };
    {
        _x params ["_vehicle", "_speed", "_unload", ["_drivingRestore",[],[[]]]];
        if (_forget && {isServer} && {!(_vehicle in _keepCrew)} && {(_vehicle getVariable ["WAIT_Convoy_Group", grpNull]) == _group}) then {
            _vehicle setVariable ["WAIT_Convoy_Group", nil, true];
            _vehicle setVariable ["WAIT_Convoy_Active", nil, true];
        };
        {
            private _unit = _x;
            if (local _unit && {_forget} && {((_unit getVariable ["WAIT_Convoy_PassengerRevision",[]]) param [0,grpNull]) == _group}) then {
                _unit setVariable ["WAIT_Convoy_PassengerRevision",nil,true];
            };
            private _target = _unit getVariable ["WAIT_Convoy_Target", objNull];
            if (local _unit && {!isPlayer _unit} && {!isNull _target}) then {
                if (assignedTarget _unit == _target) then {_unit doTarget objNull};
                _unit setVariable ["WAIT_Convoy_Target", nil, true];
            };
        } forEach crew _vehicle;
        if !(_vehicle in _keepCrew) then {
            private _hitEH = _vehicle getVariable ["WAIT_Convoy_HitEH", -1];
            if (_hitEH >= 0) then {_vehicle removeEventHandler ["Hit", _hitEH]};
            _vehicle setVariable ["WAIT_Convoy_HitEH", nil];
            if (_forget && {isServer} && {_drivingRestore isNotEqualTo []}) then {
                (_drivingRestore select 0) params ["_hadPause","_pause"];
                (_drivingRestore select 1) params ["_hadCrew","_crew"];
                if (_hadPause) then {[_vehicle,"drivingPause",_pause,true,true] call WAIT_fnc_CompatibilityState} else {[_vehicle,"drivingPause",nil,true,true] call WAIT_fnc_CompatibilityState};
                if (_hadCrew) then {[_vehicle,"drivingCrewReturn",_crew,true,true] call WAIT_fnc_CompatibilityState} else {[_vehicle,"drivingCrewReturn",nil,true,true] call WAIT_fnc_CompatibilityState};
            };
        };
        if (local _vehicle) then {
            _vehicle forceSpeed _speed;
            if !(_vehicle in _keepCrew) then {_vehicle setUnloadInCombat _unload;};
            private _driver = driver _vehicle;
            private _externalCrew = (crew _vehicle) findIf {
                private _crewGroup = group _x;
                [_x] call WAIT_fnc_CortexExternalOwner != ""
                || {[_crewGroup] call WAIT_fnc_CompatibilityExternalControl}
                || {[_crewGroup] call WAIT_fnc_CortexZeusHeld}
                || {isPlayer _x}
                || {isPlayer leader _crewGroup}
            } >= 0;
            if (!isNull _driver && {!_externalCrew} && {local _driver} && {_driver != leader _group}) then {_driver doFollow leader _group};
        };
    } forEach _vehicles;
};
_group setVariable ["WAIT_Convoy_LocalState", nil];
if (_forget) then {_group setVariable ["WAIT_Convoy_Restore", nil]};

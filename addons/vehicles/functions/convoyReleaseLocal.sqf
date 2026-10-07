/*
 * Author: WaldoTheWarfighter
 * Restores recorded formation, attack permission, vehicle speed, unload settings and exact external controller
 * per-vehicle baselines; cancels only follower paths. A speed baseline is restored only when the
 * vehicle is leaving WAIT control, WAIT still owns the current cap and no newer controller owns it.
 * Locality/authority: server owns registration; driving commands execute only on current owners.
 * Repeat/JIP: ordered registry snapshots replace old settings; owner-local paths rebuild on migration.
 * Arguments: 0: group <GROUP>, grpNull; 1: forget baseline <BOOL>, true; 2: baseline <ARRAY>, [] reads the locally received baseline; 3: still-controlled vehicles <ARRAY>, []; 4: cancellation reason <STRING, RELEASED>.
 * Return Value: Nothing.
 * Current callers: ConvoySync and ConvoyTick.
 * Example: [convoyGroup] call WAIT_fnc_ConvoyReleaseLocal;
 */
params [["_group", grpNull, [grpNull]], ["_forget", true, [true]], ["_restore", [], [[]]], ["_keepCrew", [], [[]]], ["_reason", "RELEASED", [""]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {};
private _brain=_group getVariable ["WAIT_Convoy_Brain",createHashMap];
if (count _brain > 0 && {_forget || {toUpperANSI _reason in ["ZEUS","PLAYER","EXTERNAL","EXTERNAL_OWNER","OWNERSHIP_LOST"]}}) then {
    _brain set ["cancelled",true];
    _brain set ["cancelReason",toUpperANSI _reason];
};
if (_forget) then {
    _group setVariable ["WAIT_Convoy_Brain",nil];
    _group setVariable ["WAIT_Convoy_Brain_FSM",nil];
};
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
    // A feature shutdown must restore the column's own baseline. A route, curator,
    // player or specialist controller is different: it owns the replacement order and
    // the saved convoy formation, attack permission and follower paths are evidence only.
    private _externalTakeover = local _group && {[_group] call WAIT_fnc_CortexExternalTakeover};
    private _mayRestoreGroup=local _group && {!_externalTakeover};
    if (_mayRestoreGroup) then {
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
            private _driver = driver _vehicle;
            private _externalCrew = (crew _vehicle) findIf {
                private _crewGroup = group _x;
                // The release can run after a replacement controller claimed just one crew
                // member. Do not issue a formation recall to that vehicle unless every crew
                // group remains outside the common Zeus/player/specialist handover boundary.
                [_crewGroup] call WAIT_fnc_CortexExternalTakeover
            } >= 0;
            private _externalVehicle=!isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}
                || {[_group] call WAIT_fnc_CompatibilityExternalControl};
            private _ownedSpeed=_vehicle getVariable ["WAIT_Convoy_OwnedSpeed",[]];
            private _ownsCurrentSpeed=count _ownedSpeed == 3
                && {(_ownedSpeed select 0) isEqualTo _group}
                && {abs ((getForcedSpeed _vehicle)-(_ownedSpeed select 2)) <= 0.1};
            if !(_vehicle in _keepCrew) then {
                if (!_externalTakeover && {!_externalCrew} && {!_externalVehicle} && {_ownsCurrentSpeed}) then {
                    _vehicle forceSpeed _speed;
                };
                if (count _ownedSpeed >= 1 && {(_ownedSpeed select 0) isEqualTo _group}) then {
                    _vehicle setVariable ["WAIT_Convoy_OwnedSpeed",nil];
                };
                _vehicle setUnloadInCombat _unload;
            };
            if (_mayRestoreGroup && {!isNull _driver} && {!_externalCrew} && {local _driver} && {_driver != leader _group}) then {_driver doFollow leader _group};
        };
    } forEach _vehicles;
};
_group setVariable ["WAIT_Convoy_LocalState", nil];
if (_forget) then {_group setVariable ["WAIT_Convoy_Restore", nil]};

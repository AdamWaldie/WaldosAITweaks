/*
 * Author: WaldoTheWarfighter
 * Purpose: Applies a sparse, owner-local safety speed cap and bounded physical recovery to an
 * ordinary AI ground vehicle that is already following a native waypoint. This is the standalone
 * driving layer; registered convoys retain their separate predecessor-spacing controller.
 * Locality / Authority: Runs only where the vehicle is local. It never creates, replaces or
 * deletes a waypoint and yields to players, Zeus remote control, convoy ownership and specialist
 * driving ownership.
 * Repeat/JIP: State is stored on the vehicle and is idempotent. The next local group step resumes
 * it after a locality change; release restores only the forced speed captured by this function.
 * Arguments:
 * 0: group <GROUP> - local AI group commanding the vehicle.
 * Return Value: Nothing.
 * Current callers: WAIT_fnc_CortexGroupTick.
 * Example: [group driver truck1] call WAIT_fnc_DrivingAssistStart;
 */

params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group}) exitWith {};
private _enabled=[_group,"WAIT_AIPass_DrivingAssist_Enable",true] call WAIT_fnc_CortexFeatureEnabled;
private _vehicles=[];
{
    private _vehicle=vehicle _x;
    if (_vehicle != _x && {_vehicle isKindOf "LandVehicle"} && {!(_vehicle isKindOf "StaticWeapon")} && {!(_vehicle in _vehicles)}) then {
        _vehicles pushBack _vehicle;
    };
} forEach units _group;
// A group can leave its previous vehicle, board an aircraft or become a convoy between sparse
// scheduler steps. Release only the vehicles we previously owned; never touch another group's cap.
private _previous=_group getVariable ["WAIT_DrivingAssist_Vehicles",[]];
{
    if !(_x in _vehicles) then {[_x] call WAIT_fnc_DrivingAssistRelease};
} forEach _previous;
_group setVariable ["WAIT_DrivingAssist_Vehicles",_vehicles];
{
    private _vehicle=_x;
    private _driver=driver _vehicle;
    private _release=false;
    if (!_enabled || {!local _vehicle} || {isNull _driver} || {isPlayer _driver}
        || {!isNull (_driver getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[_group] call WAIT_fnc_CortexZeusHeld}
        || {[_group] call WAIT_fnc_CompatibilityExternalControl}
        || {_vehicle getVariable ["WAIT_Convoy_Active",false]}
        || {!isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
        || {behaviour leader _group == "CARELESS"}
        || {currentWaypoint _group >= count waypoints _group}) then {_release=true};
    if (_release) then {[_vehicle] call WAIT_fnc_DrivingAssistRelease} else {
        if (time >= (_vehicle getVariable ["WAIT_DrivingAssist_Next",-1])) then {
            // A new Zeus, mission or specialist cap may not advertise an ownership marker. The
            // last cap we applied is therefore the narrowest reliable lease check: once another
            // value replaces it, release without restoring the stale pre-WAIT value.
            private _previous=_vehicle getVariable ["WAIT_DrivingAssist_Restore",[]];
            private _state=_vehicle getVariable ["WAIT_DrivingAssist_State",[]];
            private _ownedCap=_state param [0,-1];
            if (_previous isNotEqualTo [] && {_ownedCap >= 0} && {abs ((getForcedSpeed _vehicle)-_ownedCap) > 0.1}) then {
                [_vehicle] call WAIT_fnc_DrivingAssistRelease;
            } else {
            private _origin=getPosASL _vehicle;
            private _direction=vectorDir _vehicle;
            _direction set [2,0];
            if (vectorMagnitude _direction < 0.1) then {_direction=[sin (getDir _vehicle),cos (getDir _vehicle),0]};
            _direction=vectorNormalized _direction;
            private _maximumGrade=0;
            private _last=_origin;
            {
                private _sample=_origin vectorAdd (_direction vectorMultiply _x);
                _sample set [2,getTerrainHeightASL _sample];
                private _horizontal=(_sample distance2D _last) max 1;
                _maximumGrade=_maximumGrade max (abs ((_sample select 2)-(_last select 2))/_horizontal);
                _last=_sample;
            } forEach [20,45,70];
            private _cap=70;
            if (_maximumGrade > 0.2) then {_cap=18} else {if (_maximumGrade > 0.12) then {_cap=28}};
            private _previous=_vehicle getVariable ["WAIT_DrivingAssist_Restore",[]];
            if (_previous isEqualTo []) then {
                _previous=[getForcedSpeed _vehicle];
                _vehicle setVariable ["WAIT_DrivingAssist_Restore",_previous];
            };
            private _saved=_previous param [0,-1];
            if (_saved > 0) then {_cap=_cap min _saved};
            _vehicle forceSpeed _cap;
            // Retain the owning group for diagnostics only. The lease remains the forced-speed
            // value: this reference never grants route or movement ownership to WAIT.
            // Native vehicles can abandon an otherwise valid MOVE command after a small collision
            // or navigation fault.  Recovery remains subordinate to that authored waypoint:
            // refresh it once, reverse only into a checked-clear rear area, then retry once.
            // It never adds/replaces a waypoint, changes collision or moves the vehicle directly.
            private _progressPosition=_state param [4,getPosATL _vehicle];
            private _progressAt=_state param [5,time];
            private _recoveryStage=_state param [6,0];
            private _recoveryUntil=_state param [7,-1];
            private _recoveryResult=_state param [8,"IDLE"];
            if (_vehicle distance2D _progressPosition >= 3) then {
                _progressPosition=getPosATL _vehicle;
                _progressAt=time;
                _recoveryStage=0;
                _recoveryUntil=-1;
                _recoveryResult="PROGRESS";
            };
            private _waypointIndex=currentWaypoint _group;
            private _hasRoute=_waypointIndex < count waypoints _group;
            private _inCombat=behaviour leader _group in ["COMBAT","STEALTH"] || {getSuppression _driver > 0.1};
            if (_hasRoute && {!_inCombat} && {abs speed _vehicle < 1}
                && {time-_progressAt >= 12} && {time >= _recoveryUntil}) then {
                private _waypoint=[_group,_waypointIndex];
                private _destination=waypointPosition _waypoint;
                if (waypointType _waypoint == "MOVE" && {_vehicle distance2D _destination > (waypointCompletionRadius _waypoint max 20)}) then {
                    switch (_recoveryStage) do {
                        case 0: {
                            _driver doMove _destination;
                            _recoveryStage=1;
                            _recoveryUntil=time+8;
                            _recoveryResult="ROUTE_REFRESH";
                        };
                        case 1: {
                            private _rear=_vehicle getPos [8,(getDir _vehicle)+180];
                            private _blockers=(nearestObjects [_rear,["Man","LandVehicle","StaticWeapon"],10]) select {
                                _x != _vehicle && {!(_x in crew _vehicle)} && {alive _x}
                            };
                            if (_blockers isEqualTo []) then {
                                _driver doMove _rear;
                                _recoveryResult="CAUTIOUS_REVERSE";
                            } else {
                                _recoveryResult="REAR_BLOCKED";
                            };
                            _recoveryStage=2;
                            _recoveryUntil=time+6;
                        };
                        case 2: {
                            _driver doMove _destination;
                            _recoveryStage=3;
                            _recoveryUntil=time+60;
                            _recoveryResult="FINAL_ROUTE_RETRY";
                        };
                        default {
                            _recoveryResult="EXHAUSTED";
                            _recoveryUntil=time+60;
                        };
                    };
                    _progressPosition=getPosATL _vehicle;
                    _progressAt=time;
                };
            };
            _vehicle setVariable ["WAIT_DrivingAssist_State",[_cap,_maximumGrade,time,_group,
                _progressPosition,_progressAt,_recoveryStage,_recoveryUntil,_recoveryResult]];
            _vehicle setVariable ["WAIT_DrivingAssist_Next",time+4];
            };
        };
    };
} forEach _vehicles;

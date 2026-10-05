/*
 * Author: WaldoTheWarfighter
 * Purpose: Applies a sparse, owner-local safety speed cap to an ordinary AI ground vehicle that
 * is already following a native waypoint. This is the standalone driving layer; registered
 * convoys retain their separate predecessor-spacing controller.
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
            _vehicle setVariable ["WAIT_DrivingAssist_State",[_cap,_maximumGrade,time,_group]];
            _vehicle setVariable ["WAIT_DrivingAssist_Next",time+4];
            };
        };
    };
} forEach _vehicles;

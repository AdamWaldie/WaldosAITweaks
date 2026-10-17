/*
 * Author: WaldoTheWarfighter
 * Purpose: Releases the standalone WAIT driving safety speed cap and restores the exact pre-WAIT
 * forced-speed value only while that cap remains owned by WAIT; a newer controller cap is preserved.
 * Matching pass consent retires its exact broker token before ordinary cap cleanup.
 * Matching corridor work retires through its exact command/route handback before cap cleanup.
 * Locality / Authority: Runs only where the vehicle is local; does not alter waypoints, route
 * selection, collision, damage, fuel, simulation or any external driving controller.
 * Repeat/JIP: Safe when called repeatedly or after ownership changes; only a locally stored WAIT
 * restore record can be applied. Player, remote-controlled or specialist effective commanders
 * preserve their newer cap even when an ordinary AI driver belongs to another group.
 * A newer finite WAIT movement lease also prevents restoration over its tactical speed policy.
 * Arguments:
 * 0: vehicle <OBJECT> - ground vehicle to release.
 * 1: expected group <GROUP, grpNull> - group-scoped cleanup; grpNull permits subsystem shutdown.
 * Return Value: Nothing.
 * Current callers: WAIT_fnc_DrivingAssistStart and WAIT_fnc_CortexStop.
 * Example: [truck1] call WAIT_fnc_DrivingAssistRelease;
 */

params [["_vehicle",objNull,[objNull]],["_expectedGroup",grpNull,[grpNull]]];
if (isNull _vehicle || {!local _vehicle}) exitWith {};
["CANCEL",_expectedGroup,_vehicle] call WAIT_fnc_DrivingPassAdmission;
[_vehicle,_expectedGroup] call WAIT_fnc_DrivingPassRetireInherited;
private _pass=_vehicle getVariable ["WAIT_DrivingPass_Work",createHashMap];
if (count _pass > 0 && {isNull _expectedGroup || {(_pass get "group") == _expectedGroup}}) then {
    [_vehicle,_pass get "group","DRIVING_RELEASED",true] call WAIT_fnc_DrivingPassFinish;
};
[_vehicle,_expectedGroup] call WAIT_fnc_DrivingPassAgreementRelease;
private _recovery=_vehicle getVariable ["WAIT_DrivingRecovery_Work",createHashMap];
if (count _recovery > 0 && {isNull _expectedGroup || {(_recovery get "group") == _expectedGroup}}) then {
    if ((_vehicle getVariable ["WAIT_DrivingAssist_State",[]]) isEqualTo []
        && {abs ((getForcedSpeed _vehicle)-(_recovery get "cap")) <= 0.1}) then {
        _vehicle setVariable ["WAIT_DrivingAssist_State",[_recovery get "cap",0,time,_recovery get "group"]];
        _vehicle setVariable ["WAIT_DrivingAssist_Restore",+(_recovery get "baseline")];
    };
    [_vehicle,_recovery get "group","DRIVING_RELEASED"] call WAIT_fnc_DrivingRecoveryRelease;
};
[_vehicle,_expectedGroup,["ORDINARY"],true] call WAIT_fnc_DrivingNativePathWatch;
private _corridor=_vehicle getVariable ["WAIT_DrivingCorridor_Work",createHashMap];
private _corridorGroup=_corridor getOrDefault ["group",grpNull];
if (!isNull _corridorGroup && {isNull _expectedGroup || {_expectedGroup == _corridorGroup}}
    && {((_corridor getOrDefault ["controller",["ORDINARY",-1]]) param [0,""]) == "ORDINARY"}) then {
    [_vehicle,_corridorGroup,"DRIVING_RELEASED"] call WAIT_fnc_DrivingCorridorRelease;
};
private _bypass=_vehicle getVariable ["WAIT_DrivingBypass_Work",createHashMap];
private _bypassGroup=_bypass getOrDefault ["group",grpNull];
if (!isNull _bypassGroup && {isNull _expectedGroup || {_expectedGroup == _bypassGroup}}
    && {((_bypass getOrDefault ["controller",["ORDINARY",-1]]) param [0,""]) == "ORDINARY"}) then {
    [_vehicle,_bypassGroup,"DRIVING_RELEASED"] call WAIT_fnc_DrivingBypassRelease;
};
private _restore=_vehicle getVariable ["WAIT_DrivingAssist_Restore",[]];
private _state=_vehicle getVariable ["WAIT_DrivingAssist_State",[]];
if (!isNull _expectedGroup && {(_state param [3,grpNull]) != _expectedGroup}) exitWith {};
private _ownedCap=_state param [0,-1];
private _ownerGroup=_state param [3,grpNull];
private _driver=driver _vehicle;
private _commander=effectiveCommander _vehicle;
private _commanderTaken=!isNull _commander && {
    isPlayer _commander || {!isNull remoteControlled _commander}
        || {!isNull (_commander getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[_commander] call WAIT_fnc_CortexExternalOwner != ""}
        || {[_commander] call WAIT_fnc_CompatibilityExternalControl}
};
private _externalControl=(!isNull _ownerGroup && {[_ownerGroup] call WAIT_fnc_CortexExternalTakeover})
    || {!isNull _driver && {isPlayer _driver || {!isNull remoteControlled _driver}
        || {[_driver] call WAIT_fnc_CortexExternalOwner != ""}}}
    || {_commanderTaken}
    || {!isNull _ownerGroup && {!([_ownerGroup] call WAIT_fnc_DrivingMovementAvailable)}}
    || {_vehicle getVariable ["WAIT_Convoy_Active",false]};
// Restore only the cap that this driving lease still owns. If another controller changed it,
// clear our state and leave that newer value untouched.
if (_restore isNotEqualTo [] && {_ownedCap >= 0}
    && {!_externalControl}
    && {isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
    && {abs ((getForcedSpeed _vehicle)-_ownedCap) <= 0.1}) then {
    _vehicle forceSpeed (_restore param [0,-1]);
};
_vehicle setVariable ["WAIT_DrivingAssist_Restore",nil];
_vehicle setVariable ["WAIT_DrivingAssist_Next",nil];
_vehicle setVariable ["WAIT_DrivingTrafficSeen",nil];
_vehicle setVariable ["WAIT_DrivingSolidSeen",nil];
_vehicle setVariable ["WAIT_DrivingAssist_State",nil];
_vehicle setVariable ["WAIT_DrivingAssist_Traffic",nil];

_vehicle setVariable ["WAIT_DrivingAssist_Obstacle",nil];

/*
 * Author: WaldoTheWarfighter
 * Queues a finite mission of bounded bursts on the authoritative server. This is dispatch
 * acceptance, not proof that a shell fired. The selected battery's owner executes later physical
 * fire steps through the shared scheduler.
 * Locality/authority: server-only mission validation and reservation. Requests from headless
 * clients are accepted only when that machine owns the requesting group, spotter or battery;
 * player clients must use the authenticated Zeus path.
 * Repeat/JIP: mission tokens and the battery busy key reject duplicate or stale work. Active
 * server mission state survives owner migration through normal state adoption, but is not JIP
 * replayed as a new fire request and does not survive a mission restart.
 * DANGER is reserved for one exact, owner-authenticated static mortar reacting to a live hostile
 * which its effective commander already knows. It uses the same token, safety, warning and shot
 * confirmation path as other fire missions, but does not require the optional support-artillery
 * feature. Danger, Vehicles and Vehicle Gunnery are its three live gates.
 * Arguments: 0: battery <OBJECT>, objNull selects a same-side gun for the spotter; 1: reported ATL <ARRAY>; 2: error <NUMBER>, 0; 3: mode <STRING>, HE; 4: rounds <NUMBER>, -1; 5: scoot <BOOL/NUMBER>, -1; 6: purpose <STRING>, SUPPORT; 7: spotter <OBJECT>, objNull; 8: enemy <OBJECT>, objNull; 9: retreat requester <GROUP>, grpNull (SUPPORT SMOKE only).
 * Return Value: Boolean, request queued or accepted.
 * Current callers: ArtilleryRequest, CounterBattery, Retreat and server mission scripts.
 * Example: [_gun, _reportedPosition, 40] call WAIT_fnc_CortexArtilleryFire;
 */
params [["_battery", objNull, [objNull]], ["_target", [], [[]]], ["_error", 0, [0]], ["_mode", "HE", [""]],
    ["_rounds", -1, [0]], ["_scoot", -1, [0, true]], ["_purpose", "SUPPORT", [""]], ["_spotter", objNull, [objNull]], ["_enemy", objNull, [objNull]], ["_requester", grpNull, [grpNull]]];
if (!isServer) exitWith {_this remoteExecCall ["WAIT_fnc_CortexArtilleryFire", 2]; true};
private _retreatSmoke = !isNull _requester;
private _danger = _purpose == "DANGER";
if (_retreatSmoke && {_mode != "SMOKE" || {_purpose != "SUPPORT"} || {!isNull _spotter}}) exitWith {false};
if (remoteExecutedOwner > 2) then {
    // Only AI owners may forward these internal requests. Player clients use authenticated Zeus APIs.
    private _hc = allPlayers findIf {_x isKindOf "HeadlessClient_F" && {owner _x == remoteExecutedOwner}};
    if (_hc < 0 || {if (_retreatSmoke) then {remoteExecutedOwner != groupOwner _requester} else {if (isNull _spotter) then {remoteExecutedOwner != owner _battery} else {remoteExecutedOwner != owner _spotter}}}) then {_purpose = ""};
};
if (!(_purpose in ["SUPPORT", "COUNTER", "DANGER"]) || {!(_mode in ["HE", "SMOKE"])} || {count _target < 2} || {_target findIf {!(_x isEqualType 0)} >= 0}
    || {!(missionNamespace getVariable ["WAIT_AIPass_Active", false])} || {[] call WAIT_fnc_CortexIsPaused}) exitWith {false};
if (_retreatSmoke && {isNull ([_requester] call WAIT_fnc_CortexGroupTransmitter)
    || {!([_requester] call WAIT_fnc_CortexIsEligible)}
    || {!([_requester,"WAIT_AIPass_Artillery_Enable",false] call WAIT_fnc_CortexFeatureEnabled)}
    || {!([_requester,"WAIT_AIPass_ArtillerySmoke_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}}) exitWith {false};
private _requestSide = if (_retreatSmoke) then {side _requester} else {side group _spotter};
private _counter = _purpose == "COUNTER";
private _feature = if (_danger) then {"WAIT_AIPass_VehicleGunnery_Enable"} else {["WAIT_AIPass_Artillery_Enable", "WAIT_AIPass_CounterBattery_Enable"] select _counter};
if (!isNull _spotter && {!([group _spotter,_feature,false] call WAIT_fnc_CortexFeatureEnabled)}) exitWith {false};
if (!_danger && {!(missionNamespace getVariable [["WAIT_AIPass_Artillery_Enable", "WAIT_AIPass_CounterBattery_Enable"] select _counter, false])}) exitWith {false};
if (!isNull _spotter && {!alive _spotter || {!(_spotter getVariable ["WAIT_AIPass_Spotter", false])}}) exitWith {false};
if (!isNull _spotter && {time < (_spotter getVariable ["WAIT_AIPass_NextFireRequest_" + _purpose, -1])}) exitWith {false};
if (_counter && {!isNull _enemy} && {!isNull _spotter || {!isNull _battery}}) then {
    private _sideKey = str (if (isNull _spotter) then {side group gunner _battery} else {side group _spotter});
    if (time < (_enemy getVariable ["WAIT_AIPass_CounterUntil_" + _sideKey, -1])) then {_purpose = ""};
};
if (_purpose == "") exitWith {false};
private _missions = missionNamespace getVariable ["WAIT_AIPass_FireMissions", createHashMap];
if (_danger) then {
    private _crewGroup=if (isNull _battery || {isNull gunner _battery}) then {grpNull} else {group gunner _battery};
    private _commander=if (isNull _battery) then {objNull} else {effectiveCommander _battery};
    if (isNull _battery || {isNull _crewGroup} || {isNull _commander} || {isNull _enemy}
        || {!alive _battery} || {!alive _enemy} || {!(_battery isKindOf "StaticMortar")}
        || {isPlayer _commander} || {_commander knowsAbout _enemy <= 0}
        || {(side _crewGroup) getFriend (side _enemy) >= 0.6}
        || {_target distance2D (getPosATL _enemy) > 75}
        || {time < (_battery getVariable ["WAIT_AIPass_NextDangerFire",-1])}
        || {!([_crewGroup] call WAIT_fnc_CortexIsEligible)}
        || {!([_crewGroup,"WAIT_AIPass_Danger_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
        || {!([_crewGroup,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
        || {!([_crewGroup,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}
        || {[_crewGroup] call WAIT_fnc_CortexExternalTakeover}) exitWith {_purpose=""};
    _requestSide=side _crewGroup;
};
if (_purpose == "") exitWith {false};
if (isNull _battery) then {
    private _candidates = missionNamespace getVariable ["WAIT_AIPass_AllArtillery", []];
    private _index = _candidates findIf {
        alive _x && {alive gunner _x} && {side group gunner _x == _requestSide}
        && {!((netId _x) in _missions)} && {[_x, _purpose] call WAIT_fnc_CortexArtilleryRole}
        && {[group gunner _x] call WAIT_fnc_CortexIsEligible}
        && {[group gunner _x,_feature,false] call WAIT_fnc_CortexFeatureEnabled}
        && {combatMode group gunner _x != "BLUE" && {unitCombatMode gunner _x != "BLUE"}}
        && {_target inRangeOfArtillery [[_x], [_x, _mode == "SMOKE"] call WAIT_fnc_CortexArtilleryAmmo]}
    };
    if (_index >= 0) then {_battery = _candidates select _index};
};
if (isNull _battery || {!alive gunner _battery} || {(netId _battery) in _missions}
    || {!_danger && {!([_battery, _purpose] call WAIT_fnc_CortexArtilleryRole)}}
    || {!([group gunner _battery] call WAIT_fnc_CortexIsEligible)}
    || {!([group gunner _battery,_feature,false] call WAIT_fnc_CortexFeatureEnabled)}
    || {!isNull _spotter && {side group _spotter != side group gunner _battery}}
    || {_retreatSmoke && {_requestSide != side group gunner _battery}}) exitWith {false};
private _magazine = [_battery, _mode == "SMOKE"] call WAIT_fnc_CortexArtilleryAmmo;
if (_magazine == "" || {combatMode group gunner _battery == "BLUE"} || {unitCombatMode gunner _battery == "BLUE"}) exitWith {false};
if (_danger) then {
    _rounds=1;
    _scoot=false;
    _error=(_error max 0) min 25;
} else {
    if (_rounds < 1) then {_rounds = missionNamespace getVariable [["WAIT_AIPass_Artillery_Rounds", "WAIT_AIPass_CounterBattery_Rounds"] select _counter, 3]};
    if (_scoot isEqualType 0) then {_scoot = missionNamespace getVariable [["WAIT_AIPass_Artillery_ShootAndScoot", "WAIT_AIPass_CounterBattery_ShootAndScoot"] select _counter, true]};
};
private _serial = (missionNamespace getVariable ["WAIT_AIPass_FireSerial", 0]) + 1;
missionNamespace setVariable ["WAIT_AIPass_FireSerial", _serial];
private _token = format ["%1:%2", netId _battery, _serial];
private _mission = createHashMapFromArray [
    ["battery", _battery], ["key", netId _battery], ["token", _token], ["fix", [+_target, _error max 0]], ["mode", _mode], ["purpose", _purpose],
    ["spotter", _spotter], ["enemy", _enemy], ["requester",_requester], ["remaining", (round _rounds max 1) min 10], ["fired", 0], ["burstSize", (round _rounds max 1) min 10],
    ["burstsLeft", if (_mode == "SMOKE" || {_danger}) then {1} else {(round (missionNamespace getVariable ["WAIT_AIPass_Artillery_Bursts", 3]) max 1) min 5}],
    ["burstsCompleted", 0], ["opening", !_danger], ["location", +_target],
    ["offset", if (_danger || {_mode == "SMOKE"}) then {0} else {300}], ["bearing", random 360], ["magazine", _magazine],
    ["phase", "WAIT"], ["due", time], ["deadline", time + 900], ["scoot", _scoot], ["side", side group gunner _battery]
];
if (!isNull _spotter) then {_spotter setVariable ["WAIT_AIPass_NextFireRequest_" + _purpose, time + 900]};
if (_counter && {!isNull _enemy}) then {_enemy setVariable ["WAIT_AIPass_CounterUntil_" + str (side group gunner _battery), time + 900]};
if (_danger) then {_battery setVariable ["WAIT_AIPass_NextDangerFire",time+120,true]};
_missions set [netId _battery, _mission];
missionNamespace setVariable ["WAIT_AIPass_FireMissions", _missions];
_battery setVariable ["WAIT_AIPass_FireToken", _token, true];
_battery setVariable ["WAIT_AIPass_BusyUntil", time + 900, true];
[_mission,0] call WAIT_fnc_ArtilleryMissionStart;
true

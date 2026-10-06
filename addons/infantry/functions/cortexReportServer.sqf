/*
 * Author: WaldoTheWarfighter
 * Relays up to three expiring sighting reports to eligible group owners, preserving reported positions.
 * Locality/authority: server validates shared assignments; commands run only on the current AI owner.
 * Repeat/JIP: tokens and server-time deadlines reject stale work; no historical JIP commands are replayed.
 * Arguments: 0: sender <GROUP>, grpNull; 1: reports <ARRAY>, []; 2: sent server time <NUMBER>, -1.
 * Return Value: Nothing.
 * Current callers: ContactReport.
 * Example: [_group, _reports, serverTime] remoteExecCall ["WAIT_fnc_CortexReportServer", 2];
 */
params [["_sender", grpNull, [grpNull]], ["_reports", [], [[]]], ["_sent", -1, [0]]];
if (!isServer || {isNull _sender} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != groupOwner _sender}}
    || {!(missionNamespace getVariable ["WAIT_AIPass_Enable", false])} || {[] call WAIT_fnc_CortexIsPaused}
    || {!([_sender, "WAIT_AIPass_ContactReports_Enable", true] call WAIT_fnc_CortexFeatureEnabled)}
    || {!([_sender] call WAIT_fnc_CortexIsEligible)} || {serverTime - _sent > 10} || {_sent > serverTime + 1}) exitWith {};
if (serverTime < (_sender getVariable ["WAIT_AIPass_ReportServerDue", -1])) exitWith {};
_sender setVariable ["WAIT_AIPass_ReportServerDue", serverTime + 15];
private _valid = (_reports select [0,3]) select {
    _x isEqualType [] && {count _x == 3} && {(_x select 0) isEqualType []} && {count (_x select 0) == 3}
    && {(_x select 0) findIf {!(_x isEqualType 0)} < 0} && {(_x select 1) isEqualType 0}
    && {(_x select 2) isEqualType 0} && {serverTime - (_x select 2) <= 10} && {(_x select 2) <= serverTime}
};
if (_valid isEqualTo []) exitWith {};
private _transmitter = [_sender] call WAIT_fnc_CortexGroupTransmitter;
private _range = if (!isNull _transmitter) then {missionNamespace getVariable ["WAIT_AIPass_ContactReports_Radius",500]} else {missionNamespace getVariable ["WAIT_AIPass_ContactReports_VoiceRange",35]};
private _senderPosition = getPosATL ([_transmitter, leader _sender] select isNull _transmitter);
private _receivers = allGroups select {_x != _sender && {side _x == side _sender} && {alive leader _x}
    && {leader _x distance2D _senderPosition <= _range} && {[_x] call WAIT_fnc_CortexIsEligible}};
// One bounded delivery job; do not fan out an unbounded remote-call burst.
[{
    params ["_job"];
    private _sender = _job get "sender";
    private _receivers = _job get "receivers";
    private _cursor = _job getOrDefault ["cursor",0];
    for "_i" from 1 to 8 do {
        if (_cursor >= count _receivers) exitWith {};
        private _receiver = _receivers select _cursor;
        _cursor = _cursor + 1;
        if (!isNull _receiver && {serverTime < (_job get "expiry")}) then {
            [_receiver, _sender, _job get "reports", _job get "sent"] remoteExecCall ["WAIT_fnc_CortexReportLocal", groupOwner _receiver];
        };
    };
    _job set ["cursor",_cursor];
    if (_cursor >= count _receivers || {serverTime >= (_job get "expiry")}) then {-1} else {0.5}
}, createHashMapFromArray [["sender",_sender],["receivers",_receivers],["reports",_valid],["sent",_sent],["expiry",_sent+15]],1.5] call WAIT_fnc_CortexQueueJob;

/*
 * Author: WaldoTheWarfighter
 * Shares what a squad in contact can see with nearby friendly squads, by radio or by voice.
 *
 * Up to three recent believed positions are sent through the server to current receiving owners.
 * Report confidence comes from a bounded native-knowledge sample of the whole reporting squad, so
 * a leader taking cover cannot understate a wingman's confirmed contact.
 * Receivers store an expiring area report for investigation, never reveal or track a target object.
 * Jamming restricts delivery to voice range. Sender/receiver feature gates are rechecked on delivery.
 * Locality/authority: sender owner reports; server validates and batches eight receivers per job step.
 * Repeat/JIP: sender cooldown and timestamps reject duplicate/stale work; reports expire and are not replayed.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP>
 * 2: visible <ARRAY> - enemies from WAIT_fnc_CortexKnowledge seen in the last 10 s
 *
 * Return Value:
 * Number - reports submitted; delivery is asynchronous
 *
 * Example:
 * [_group, _state, _visible] call WAIT_fnc_CortexContactReport;
 * Result: eligible neighbouring owners receive an expiring area report.
 *
 * Current caller: WAIT_fnc_CortexGroupTick.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_visible", [], [[]]]];
_state set ["lastReport", time];
if (_visible isEqualTo []) exitWith {0};
if (!local _group || {!([_group,"WAIT_AIPass_ContactReports_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) exitWith {0};
private _reporters=(units _group) select {alive _x && {local _x} && {!isPlayer _x}};
if (count _reporters > 8) then {_reporters resize 8};
private _reports = (_visible select [0,3]) apply {
    private _target=_x select 0;
    private _confidence=0;
    {_confidence=_confidence max (_x knowsAbout _target)} forEach _reporters;
    [+(_x select 1),1 min _confidence,serverTime - (_x select 2)]
};
[_group,_reports,serverTime] remoteExecCall ["WAIT_fnc_CortexReportServer",2];
count _reports

/*
 * Author: WaldoTheWarfighter
 * Purpose: Restarts one active convoy's destination-local maintenance after a confirmed group locality handoff.
 * Locality/authority: Runs only where the transferred group is now local. It never selects a headless client,
 * calls setGroupOwner, rewrites waypoints, changes vehicle position or orders a passenger into a vehicle.
 * Repeat/JIP: The provider transfer revision (when available) makes duplicate handoff events harmless. A later
 * transfer back to the same owner receives a fresh WAIT revision and queues one replacement job.
 * Arguments: 0 group <GROUP>; 1 previous owner <NUMBER>; 2 new owner <NUMBER>; 3 provider <STRING>, default "EXTERNAL".
 * Return Value: BOOL - true when one active local convoy was adopted; false when no matching active convoy exists.
 * Current callers: ConvoySync's ACE Headless and compatibility handoff adapters.
 * Example: [group cursorObject,2,clientOwner,"COMPANION"] call WAIT_fnc_ConvoyHeadlessAdoptLocal;
 */
params [
    ["_group",grpNull,[grpNull]],
    ["_previousOwner",2,[0]],
    ["_newOwner",-1,[0]],
    ["_provider","EXTERNAL",[""]]
];
if (isNull _group || {clientOwner != _newOwner} || {!local _group} || {!(_group getVariable ["WAIT_Convoy_Active",false])}) exitWith {false};

private _providerKey=toUpperANSI _provider;
private _providerRevision=[_group,_newOwner,_providerKey] call WAIT_fnc_CompatibilityHeadlessRevision;
if (_providerKey == "COMPANION" && {_providerRevision < 0}) exitWith {false};

private _entry=(missionNamespace getVariable ["WAIT_Convoy_LocalRegistry",[]]) findIf {(_x select 0) isEqualTo _group};
if (_entry < 0) exitWith {false};
private _configuration=(missionNamespace getVariable ["WAIT_Convoy_LocalRegistry",[]]) select _entry select 1;
private _revision=missionNamespace getVariable ["WAIT_Convoy_ReceivedRevision",-1];
if (_revision < 0 || {(_configuration param [0,-2]) < 0}) exitWith {false};

private _adoptionKey=format ["%1:%2:%3:%4",_previousOwner,_newOwner,_providerKey,_providerRevision];
private _last=_group getVariable ["WAIT_Convoy_LastHeadlessAdoption",[]];
if (_last isEqualTo [_adoptionKey,_newOwner] && {_providerKey == "COMPANION"}) exitWith {true};

// State and timing are local-owner caches. The registered route, spacing phase, halt reason and
// passenger task generation remain authoritative snapshot data and are deliberately left intact.
_group setVariable ["WAIT_Convoy_LocalState",nil];
_group setVariable ["WAIT_Convoy_NextTick",-1];
_group setVariable ["WAIT_Convoy_CrewDue",-1];
[_group,_configuration] call WAIT_fnc_ConvoyCrewLocal;

// Convoy jobs naturally finished on this machine while another owner drove the group. Claim one
// replacement token so a repeated provider event or an arriving registry snapshot cannot create
// competing scheduler callbacks for the same convoy.
private _jobToken=format ["%1:%2:%3:%4",_revision,_newOwner,_providerKey,_providerRevision];
_group setVariable ["WAIT_Convoy_LocalJobToken",_jobToken];
[WAIT_fnc_ConvoyJobStep,createHashMapFromArray [
    ["subsystem","CONVOY"],
    ["group",_group],
    ["configuration",_configuration],
    ["registryRevision",_revision],
    ["jobToken",_jobToken]
],0] call WAIT_fnc_CortexQueueJob;
_group setVariable ["WAIT_Convoy_LastHeadlessAdoption",[_adoptionKey,_newOwner],true];
[] call WAIT_fnc_SchedulerReconcile;

diag_log format ["[WAIT Convoy] %1 locality handoff group=%2 previousOwner=%3 owner=%4 registry=%5 providerRevision=%6.",_providerKey,_group,_previousOwner,_newOwner,_revision,_providerRevision];
true

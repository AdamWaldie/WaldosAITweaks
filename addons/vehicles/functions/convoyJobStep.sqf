/*
 * Author: WaldoTheWarfighter
 * Purpose: Runs one convoy's bounded maintenance round through WAIT's shared owner-local scheduler.
 * Locality/authority: Runs only where the convoy group is local; ConvoyTick retains vehicle-command authority checks.
 * Repeat/JIP: The registry revision invalidates stale jobs. A replacement snapshot queues one fresh round without retaining a per-convoy worker.
 * Arguments: 0 state <HASHMAP> with group, configuration, registryRevision and optional local jobToken.
 * Return Value: NUMBER - next delay in seconds, or -1 when the convoy no longer belongs to this local registry revision.
 * Current callers: ConvoySync through CortexQueueJob.
 * Example: [createHashMapFromArray [["group",_group],["configuration",_configuration],["registryRevision",_revision]],0] call WAIT_fnc_ConvoyJobStep;
 */
params [["_state",createHashMap,[createHashMap]]];
private _group=_state getOrDefault ["group",grpNull];
private _configuration=_state getOrDefault ["configuration",[]];
private _revision=_state getOrDefault ["registryRevision",-1];
private _jobToken=_state getOrDefault ["jobToken",""];
if (isNull _group || {!local _group} || {_revision != (missionNamespace getVariable ["WAIT_Convoy_ReceivedRevision",-2])}) exitWith {-1};
if (_jobToken != "" && {!(_jobToken isEqualTo (_group getVariable ["WAIT_Convoy_LocalJobToken",""]))}) exitWith {-1};
private _entry=(missionNamespace getVariable ["WAIT_Convoy_LocalRegistry",[]]) findIf {(_x select 0) isEqualTo _group && {(_x select 1) isEqualTo _configuration}};
if (_entry < 0) exitWith {-1};
[_group,_configuration] call WAIT_fnc_ConvoyTick;
1

/*
 * Author: WaldoTheWarfighter
 * Purpose: Start one matched standalone patrol benchmark after observer mission entry.
 * Locality/authority: Dedicated server owns fixtures and the observer curator.
 * Repeat/JIP: One mission run; JIP does not restart sampling. Curator assignment uses the live observer.
 * Arguments: None. Return: Nothing. Current callers: mission event script.
 * Example: Executed automatically when the standalone performance mission starts.
 */
if (!isServer) exitWith {};
call compile preprocessFileLineNumbers "auditIdentity.sqf";
diag_log "WAIT AUDIT SERVER READY";
private _deadline=time+180;
waitUntil {sleep 0.2; (allPlayers findIf {!(_x isKindOf "HeadlessClient_F")}) >= 0 || {time >= _deadline}};
private _observers=allPlayers select {!(_x isKindOf "HeadlessClient_F")};
if (count _observers != 1) exitWith {diag_log "WAIT STANDALONE PERF INVALID: observer count"};
private _observer=_observers select 0;
_observer allowDamage false;
private _logicGroup=createGroup sideLogic;
private _curator=_logicGroup createUnit ["ModuleCurator_F",[5800,5800,0],[],0,"NONE"];
_observer assignCurator _curator;
waitUntil {sleep 0.2; getAssignedCuratorLogic _observer == _curator || {time >= _deadline}};
if (getAssignedCuratorLogic _observer != _curator) exitWith {diag_log "WAIT STANDALONE PERF INVALID: observer curator"};
diag_log "WAIT AUDIT OBSERVER ZEUS READY";
[] execVM "cortexQAStandalonePerformance.sqf";

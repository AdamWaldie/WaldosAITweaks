/*
 * Author: WaldoTheWarfighter
 * Purpose: Start one matched standalone patrol benchmark after observer mission entry.
 * Locality/authority: Interface client protects its observer; server owns benchmark sampling.
 * Repeat/JIP: One mission run; JIP does not restart sampling. Curator assignment uses the live observer.
 * Arguments: None. Return: Nothing. Current callers: mission event script.
 * Example: Executed automatically when the standalone performance mission starts.
 */
if (!hasInterface) exitWith {};
waitUntil {!isNull player};
player allowDamage false;
call compile preprocessFileLineNumbers "auditIdentity.sqf";

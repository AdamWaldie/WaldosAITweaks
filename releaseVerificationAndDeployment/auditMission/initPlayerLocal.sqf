/*
 * Author: WaldoTheWarfighter
 * Purpose: Start the visible observer guide and client acceptance checks against packaged WAIT.
 * Locality/authority: Interface client only; no combat fixture state is changed.
 * Repeat/JIP: Each client logs build identity; the guide and suite guard repeated installation.
 * Arguments: None. Return: Nothing. Current callers: engine player initialization.
 * Example: Join WAIT_Audit.VR as the observer and enter Zeus.
 */
call compile preprocessFileLineNumbers "auditIdentity.sqf";
if (hasInterface) then {[] execVM "cortexQAClient.sqf"};

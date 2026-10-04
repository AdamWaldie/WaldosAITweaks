/*
 * Author: WaldoTheWarfighter
 * Resolves an owner reply without treating Arma's zero headless-client sender id as broadcast authority.
 * Locality / Authority: Server only; validates positive senders or a claimed live HeadlessClient_F owner.
 * Repeat/JIP: Read-only and safe to repeat; disconnected owners fail immediately.
 * Arguments: 0 claimed owner <NUMBER>, default -1; 1 expected owner <NUMBER>, default -1.
 * Return Value: NUMBER - resolved owner or -1; never returns zero.
 * Current callers: Cortex cross-owner acknowledgements and skill adoption reporting.
 * Example: [clientOwner, groupOwner _group] call Waldo_fnc_HeadlessResolveSender;
 */

params [["_claimed", -1, [0]], ["_expected", -1, [0]]];
if (!isServer) exitWith {-1};
private _sender = remoteExecutedOwner;
if (_sender > 0) exitWith {
    if ((_claimed > 0 && {_claimed != _sender}) || {_expected > 0 && {_expected != _sender}}) then {-1} else {_sender}
};
if (_claimed <= 2 || {_expected > 0 && {_claimed != _expected}}) exitWith {-1};
if ((entities "HeadlessClient_F") findIf {owner _x == _claimed} < 0) exitWith {-1};
_claimed

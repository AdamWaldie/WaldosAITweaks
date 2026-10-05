/*
 * Author: WaldoTheWarfighter
 * Purpose: Release one matching finite manoeuvre immediately when its FSM sees a newer Zeus order
 * or addon shutdown. This is cleanup only; it never starts a replacement movement operation.
 * Locality/authority: Current group owner only. Token and epoch must still match the active drill.
 * Repeat/JIP: A retired or replaced token is a no-op. Public ending evidence is replayable; the
 * interrupt itself is not replayed. Locality migration uses the existing adoption/release path.
 * Arguments: 0 group <GROUP, grpNull>; 1 token <STRING, empty>; 2 epoch <NUMBER, -1>;
 * 3 reason <STRING, ZEUS> - ZEUS or RELEASE only.
 * Return: BOOL - true when the matching drill was released.
 * Current callers: finite tacticalDrill.fsm interrupt transitions.
 * Example: [group soldier1,"drill-17",3,"ZEUS"] call WAIT_fnc_CortexDrillInterrupt;
 */
params [["_group",grpNull,[grpNull]],["_token","",[""]],["_epoch",-1,[0]],["_reason","ZEUS",[""]]];
if (isNull _group || {!local _group} || {_token == ""}
    || {(_group getVariable ["WAIT_AIPass_Epoch",0]) != _epoch}
    || {!(_reason in ["ZEUS","RELEASE"])}) exitWith {false};
private _state=_group getVariable ["WAIT_AIPass_State",createHashMap];
private _drill=_state getOrDefault ["drill",createHashMap];
if ((_drill getOrDefault ["token",""]) != _token) exitWith {false};
// This one-shot cleanup must not wait behind a delayed tactical job. FlankEnd restores
// only matching owned overrides; ZEUS prohibits doFollow or replacement movement.
[_group,_state,_reason] call WAIT_fnc_CortexFlankEnd;
true

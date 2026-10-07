/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Returns a group's Smart AI Pass state map, creating it on first use.
 *
 * The map lives on the group as a machine-local variable, so it is never broadcast. A new owner
 * after a locality change starts a fresh map and re-reads the situation from engine knowledge.
 * Keys: legacy implementation phase (CALM, INVESTIGATE, CONTACT, SECURITY, SEARCH, REGROUP,
 * RETREAT), morale (0-1), moraleState. The owner-local groupTactics FSM publishes the semantic
 * phase (including SUPPORT, MANOEUVRE, ASSAULT, CLEAR and WITHDRAW) separately, so extraction of
 * phase handlers does not create a second movement owner. Cooldowns and per-phase fields remain here
 * while those handlers are migrated out of WAIT_fnc_CortexGroupTick.
 * Locality and authority: machine-local.
 *
 * Arguments:
 * 0: group <GROUP>
 *
 * Return Value:
 * HashMap - the state map (the same object on every call)
 *
 * Example:
 * private _state = [_group] call WAIT_fnc_CortexGroupState;
 * Result: the group's live pass state.
 *
 * Current callers: WAIT_fnc_GroupBrainStep, WAIT_fnc_CortexGroupTick,
 * WAIT_fnc_CortexReinforce and order functions.
 */

params [["_group", grpNull, [grpNull]]];
private _state = _group getVariable ["WAIT_AIPass_State", createHashMap];
if (count _state == 0) then {
    _state = createHashMapFromArray [
        ["phase", "CALM"], ["morale", 1], ["moraleState", "STEADY"], ["cooldowns", createHashMap]
    ];
    _group setVariable ["WAIT_AIPass_State", _state];
};
_state


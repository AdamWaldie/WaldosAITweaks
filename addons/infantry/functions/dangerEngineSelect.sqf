/*
 * Author: WaldoTheWarfighter
 * Purpose: Select one live engine danger record with a bounded priority pass. Direct hits remain
 * highest, but an actor that can fire retains higher priority than casualty observation, shouting
 * or ambient fire so actionable combat is not displaced by weaker events from the same queue.
 * Locality / Authority: Pure owner-local selection. It performs no commands or state mutation.
 * Repeat/JIP: Stateless and repeat-safe; the engine supplies a fresh queue after locality changes.
 * Arguments: 0: engine danger records <ARRAY>, [].
 * Return Value: Array - selected [cause, position, expiry, source] record, or [].
 * Current callers: Engine-loaded infantry danger FSM.
 * Example: [[[2,getPosATL player,time + 1,objNull]]] call WAIT_fnc_DangerEngineSelect;
 */

params [["_records",[],[[]]]];
// Engine causes: enemy detected, fire, hit, enemy near, explosion, own-group casualty,
// other casualty, scream, can fire, bullet close, synthetic assessment.
private _priorities=[2,1,9,4,3,6,3,5,8,7,0];
private _selected=[];
private _best=-1;
private _latest=-1;
{
    if (_x isEqualType [] && {count _x >= 3}) then {
        private _cause=_x param [0,-1,[0]];
        private _expiry=_x param [2,-1,[0]];
        private _rank=if (_cause >= 0 && {_cause < count _priorities}) then {_priorities select _cause} else {-1};
        if (_expiry >= time - 0.25 && {_rank > _best || {_rank == _best && {_expiry > _latest}}}) then {
            _selected=+_x;
            _best=_rank;
            _latest=_expiry;
        };
    };
} forEach (_records select [0,12]);
_selected

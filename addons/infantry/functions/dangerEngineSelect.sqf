/*
 * Author: WaldoTheWarfighter
 * Purpose: Select one live engine danger record with a bounded priority pass.
 * Locality / Authority: Pure owner-local selection. It performs no commands or state mutation.
 * Repeat/JIP: Stateless and repeat-safe; the engine supplies a fresh queue after locality changes.
 * Arguments: 0: engine danger records <ARRAY>, [].
 * Return Value: Array - selected [cause, position, expiry, source] record, or [].
 * Current callers: Engine-loaded infantry danger FSM.
 * Example: [[[2,getPosATL player,time + 1,objNull]]] call WAIT_fnc_DangerEngineSelect;
 */

params [["_records",[],[[]]]];
private _priorities=[5,4,8,5,7,3,2,3,4,8,1];
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

/*
 * Author: WaldoTheWarfighter
 * Purpose: Select one unexpired danger event using a bounded linear priority pass.
 * Locality / Authority: owner-local; never reveals targets or sends movement commands.
 * Repeat/JIP: generation-checked, machine-local state; new owners rebuild from new observations.
 * Arguments: 0: events <ARRAY>, []; 1: local time <NUMBER>, time.
 * Return Value: Array - selected event or [] when none is valid.
 * Current callers: WAIT_fnc_DangerStep and danger acceptance fixtures.
 * Example: [[]] call WAIT_fnc_DangerSelect;
 */

params [["_events",[],[[]]],["_now",time,[0]]];
private _chosen=[];
private _best=-1;
private _latest=-1;
private _priority=createHashMapFromArray [["HIT",7],["EXPLOSION",6],["SUPPRESSED",5],["CASUALTY",4],["SCREAM",3],["DETECTED",2],["GUNFIRE",1]];
{
    if (_x isEqualType [] && {count _x == 4}) then {
        _x params ["_cause","_position","_created","_expires"];
        if (_cause isEqualType "" && {_position isEqualType []} && {count _position == 3}
            && {_created isEqualType 0} && {_expires isEqualType 0} && {_expires > _now}) then {
            private _rank=_priority getOrDefault [_cause,-1];
            if (_rank > _best || {_rank >= 0 && {_rank == _best} && {_created > _latest}}) then {
                _chosen=+_x; _best=_rank; _latest=_created;
            };
        };
    };
} forEach (_events select [0,16]);
_chosen

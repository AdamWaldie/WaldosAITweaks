/*
 * Author: WaldoTheWarfighter
 * Purpose: Select one unexpired danger event using a bounded linear priority pass.
 * Locality / Authority: owner-local; never reveals targets or sends movement commands.
 * Repeat/JIP: generation-checked, machine-local state; new owners rebuild from new observations.
 * Arguments: 0: events <ARRAY>, []; 1: local time <NUMBER>, time.
 * Return Value: Array - selected event [cause, position, created, expires, hostile source,
 * response observer, source observer] or [].
 * Current callers: WAIT_fnc_DangerStep and danger acceptance fixtures.
 * Example: [[]] call WAIT_fnc_DangerSelect;
 */

params [["_events",[],[[]]],["_now",time,[0]]];
private _chosen=[];
private _best=-1;
private _latest=-1;
// Preserve the tactical consequence ordering already used by the engine-side bounded pass. Exact
// proximity and firing-opportunity causes must survive the group handoff instead of collapsing into
// generic detection, where an unrelated explosion could otherwise displace an actionable contact.
private _priority=createHashMapFromArray [["HIT",9],["CANFIRE",8],["SUPPRESSED",7],["CASUALTY",6],["SCREAM",5],["PROXIMITY",4],["EXPLOSION",3],["BODY_FOUND",3],["DETECTED",2],["GUNFIRE",1]];
{
    if (_x isEqualType [] && {count _x in [4,5,6,7]}) then {
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

/*
 * Author: WaldoTheWarfighter
 * Purpose: Install disposable audit-only owner commands and authenticated observations for HC cases.
 * Locality/authority: Definitions on every audit machine. Only server-issued, fresh, monotonically
 * numbered requests can command a local AI. Replies are accepted only from the pending current owner.
 * Repeat/JIP: No orders replayed or handlers installed; each actor retains a local consumed serial.
 * Arguments to WAIT_CortexQA_IndoorActorOwner: actor OBJECT, mode STRING (STATUS/MOVE), serial NUMBER,
 * expected owner NUMBER, server expiry NUMBER, optional ATL destination ARRAY [].
 * Arguments to WAIT_CortexQA_IndoorActorAckServer: actor OBJECT, mode STRING, serial NUMBER, data ARRAY.
 * Return: Nothing. Acknowledgements are observations, never physical acceptance or production state.
 * Current callers: runIndoorActorsHC.sqf through remoteExecCall; audit init.sqf installs definitions.
 * Example: [soldier1,"STATUS",1,groupOwner group soldier1,serverTime+8,[]]
 * remoteExecCall ["WAIT_CortexQA_IndoorActorOwner",groupOwner group soldier1];
 */
WAIT_CortexQA_IndoorActorAckServer={
    params [["_actor",objNull,[objNull]],["_mode","",[""]],["_serial",-1,[0]],["_data",[],[[]]]];
    if (!isServer || {isNull _actor} || {count _data != 9}) exitWith {};
    private _sender=remoteExecutedOwner;
    if (_sender == 0 && {local _actor}) then {_sender=2};
    private _pending=_actor getVariable ["WAIT_CortexQA_IndoorPending",[]];
    if (count _pending != 4 || {(_pending select 0) != _serial} || {(_pending select 1) != _mode}
        || {(_pending select 2) != _sender} || {serverTime > (_pending select 3)}
        || {groupOwner group _actor != _sender} || {owner _actor != _sender}
        || {_sender > 2 && {allPlayers findIf {_x isKindOf "HeadlessClient_F" && {owner _x == _sender}} < 0}}) exitWith {};
    _actor setVariable ["WAIT_CortexQA_IndoorAck",[_serial,_mode,_sender,_data,serverTime]];
    _actor setVariable ["WAIT_CortexQA_IndoorPending",nil];
};
WAIT_CortexQA_IndoorActorOwner={
    params [["_actor",objNull,[objNull]],["_mode","",[""]],["_serial",-1,[0]],
        ["_expectedOwner",-1,[0]],["_expires",-1,[0]],["_goal",[],[[]]]];
    if (remoteExecutedOwner != 2 && {!(isServer && {remoteExecutedOwner == 0})}) exitWith {};
    if (isNull _actor || {!local _actor} || {!local group _actor} || {isPlayer _actor}
        || {clientOwner != _expectedOwner} || {groupOwner group _actor != _expectedOwner}
        || {!finite _serial} || {_serial < 1} || {_serial != floor _serial}
        || {!finite _expires} || {serverTime > _expires} || {_expires-serverTime > 12}
        || {!(_mode in ["STATUS","MOVE"])}
        || {_serial <= (_actor getVariable ["WAIT_CortexQA_IndoorConsumed",-1])}) exitWith {};
    _actor setVariable ["WAIT_CortexQA_IndoorConsumed",_serial];
    private _brain=_actor getVariable ["WAIT_IndoorActor_Brain",createHashMap];
    private _issued=false;
    if (_mode == "MOVE" && {count _goal == 3}
        && {_goal findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {count _brain == 0} && {(_actor getVariable ["WAIT_IndoorActor_Order",[]]) isEqualTo []}
        && {(_actor getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo []}
        && {isNull objectParent _actor} && {isNull remoteControlled _actor}
        && {[_actor] call WAIT_fnc_CortexCombatEffective}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}
        && {([_actor] call WAIT_fnc_CortexExternalOwner) == ""}) then {
        _actor doMove _goal; _issued=true;
    };
    private _data=[_issued,count _brain,_actor getVariable ["WAIT_Cortex_ActorMove",[]],
        _actor getVariable ["WAIT_IndoorActor_Order",[]],currentCommand _actor,
        expectedDestination _actor,getPosATL _actor,getUnitState _actor,
        _actor getVariable ["WAIT_IndoorActor_Cooldown",-1]];
    if (isServer) then {[_actor,_mode,_serial,_data] call WAIT_CortexQA_IndoorActorAckServer} else {
        [_actor,_mode,_serial,_data] remoteExecCall ["WAIT_CortexQA_IndoorActorAckServer",2];
    };
};

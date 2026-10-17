/*
 * Author: WaldoTheWarfighter
 * Purpose: Brokers finite, separately authenticated owner consent for two road-pass participants.
 * Locality/authority: Server only; BEGIN requires the passing vehicle's current owner. ACK
 * counts only its actual expected owner. Server checks live seats/epochs/authored routes;
 * owners check their own native commands/destinations before replying.
 * Repeat/JIP: Bounded private registry (32 pairs), one active pair per vehicle, fixed deadlines,
 * idempotent acknowledgements. Authenticated BEGIN prunes expired/replaced records; ACK
 * rechecks only its own pair. Registry and token sequence use private localNamespace; no recurring scan.
 * No public priority, movement, ownership transfer or JIP command. AGREED is consent only.
 * Arguments: 0 mode <STRING>, empty, BEGIN, ACK or RELEASE; 1 payload <ARRAY>, empty.
 * BEGIN: [serial, vehicles, context, handshakeDeadline, consentExpiry]; ACK: [token, accepted].
 * RELEASE: [token], accepted from either original current participant owner.
 * Return: BOOL - request/reply processed, never physical passage or movement permission.
 * Current callers: DrivingPassAgreementRequest and authenticated DrivingPassAgreementOwner replies.
 * Example: ["ACK",[_token,true]] remoteExecCall ["WAIT_fnc_DrivingPassAgreementServer",2];
 */
params [["_mode","",[""]],["_payload",[],[[]]]];
if (!isServer || {remoteExecutedOwner <= 0} || {!(_mode in ["BEGIN","ACK","RELEASE"])}) exitWith {false};
private _sender=remoteExecutedOwner;
private _registry=localNamespace getVariable ["WAIT_DrivingPass_Agreements",createHashMap];
localNamespace setVariable ["WAIT_DrivingPass_Agreements",_registry];
private _topologyCurrent={
    params ["_vehicles","_context"];
    private _live=[_vehicles] call WAIT_fnc_DrivingPassContext;
    if (_live isEqualTo [] || {count _context != 2} || {!((_context select 1) isEqualType [])}
        || {count (_context select 1) != 2}) exitWith {false};
    private _actual=_live select 1;private _expected=_context select 1;
    private _valid=true;
    for "_i" from 0 to 1 do {
        private _a=_actual select _i;private _e=_expected select _i;
        if (!(_e isEqualType []) || {count _e != 4}) exitWith {_valid=false};
        if ((_a select [0,2]) isNotEqualTo (_e select [0,2])) exitWith {_valid=false};
        {
            private _ar=_a select _x;private _er=_e select _x;
            if (!(_er isEqualType []) || {count _ar != count _er}) exitWith {_valid=false};
            if (_ar isNotEqualTo [] && {count _ar != 10 || {(_ar select [0,7]) isNotEqualTo (_er select [0,7])}
                || {(_ar select 9) isNotEqualTo (_er select 9)}}) exitWith {_valid=false};
        } forEach [2,3];
    };
    _valid
};
private _sendResult={
    params ["_record"];
    private _message=[_record get "token",_record get "vehicles",_record get "context",
        _record get "deadline",_record get "expires",_record get "serial",_record get "phase"];
    {["RESULT",_message] remoteExecCall ["WAIT_fnc_DrivingPassAgreementOwner",_x]} forEach (_record get "owners");
};
if (_mode == "BEGIN") exitWith {
    if (count _payload != 5) exitWith {false};
    _payload params ["_serial","_vehicles","_context","_deadline","_expires"];
    if (!(_serial isEqualType 0) || {!finite _serial} || {_serial < 1} || {_serial != floor _serial}
        || {!(_vehicles isEqualType [])} || {count _vehicles != 2}
        || {_vehicles findIf {!(_x isEqualType objNull) || {isNull _x}} >= 0}
        || {!(_context isEqualType [])} || {count _context != 2}
        || {!(_deadline isEqualType 0)} || {!finite _deadline} || {_deadline <= serverTime} || {_deadline > serverTime+2}
        || {!(_expires isEqualType 0)} || {!finite _expires} || {_expires <= _deadline} || {_expires > serverTime+50}
        || {(_context select 0) isNotEqualTo _sender}) exitWith {false};
    private _vehicle=_vehicles select 0;
    if (owner _vehicle != _sender || {isNull driver _vehicle} || {owner driver _vehicle != _sender}
        || {groupOwner group driver _vehicle != _sender}) exitWith {false};
    if !([_vehicles,_context] call _topologyCurrent) exitWith {false};
    // Only authenticated new-pair admission pays the bounded registry sweep.
    {
        private _record=_registry get _x;
        private _until=if ((_record get "phase") == "AGREED") then {_record get "expires"} else {_record get "deadline"};
        if (serverTime >= _until || {!([_record get "vehicles",_record get "context"] call _topologyCurrent)}) then {_registry deleteAt _x};
    } forEach keys _registry;

    private _duplicate=keys _registry findIf {
        private _old=_registry get _x;
        (_old get "serial") == _serial && {(_old get "vehicles") isEqualTo _vehicles}
            && {(_old get "context") isEqualTo _context}
    };
    if (_duplicate >= 0) exitWith {true};
    if (count _registry >= 32 || {keys _registry findIf {
        private _pair=(_registry get _x) get "vehicles";
        (_vehicles select 0) in _pair || {(_vehicles select 1) in _pair}
    } >= 0}) exitWith {false};
    private _owners=(_vehicles apply {owner _x});_owners=_owners arrayIntersect _owners;
    if (_owners findIf {_x <= 0} >= 0) exitWith {false};
    private _sequence=(localNamespace getVariable ["WAIT_DrivingPass_ServerSequence",0])+1;
    localNamespace setVariable ["WAIT_DrivingPass_ServerSequence",_sequence];
    private _token=format ["%1:%2:%3",_sender,netId _vehicle,_sequence];
    private _record=createHashMapFromArray [["token",_token],["serial",_serial],["vehicles",_vehicles],
        ["context",_context],["deadline",_deadline],["expires",_expires],["owners",_owners],["acks",[]],["phase","PENDING"]];
    _registry set [_token,_record];
    {["VERIFY",[_token,_vehicles,_context,_deadline,_expires,_serial]] remoteExecCall ["WAIT_fnc_DrivingPassAgreementOwner",_x]} forEach _owners;
    true
};
if (_mode == "RELEASE") exitWith {
    if (count _payload != 1 || {!((_payload select 0) isEqualType "")}) exitWith {false};
    private _token=_payload select 0;
    private _record=_registry getOrDefault [_token,createHashMap];
    if (count _record == 0 || {!(_sender in (_record get "owners"))}) exitWith {false};
    _record set ["phase","RELEASED"];
    [_record] call _sendResult;
    _registry deleteAt _token;
    true
};
if (_mode == "ACK") exitWith {
    if (count _payload != 2 || {!((_payload select 0) isEqualType "")} || {!((_payload select 1) isEqualType true)}) exitWith {false};
    _payload params ["_token","_accepted"];
    private _record=_registry getOrDefault [_token,createHashMap];
    if (count _record == 0 || {!(_sender in (_record get "owners"))}) exitWith {false};
    private _until=if ((_record get "phase") == "AGREED") then {_record get "expires"} else {_record get "deadline"};
    if (serverTime >= _until || {!([_record get "vehicles",_record get "context"] call _topologyCurrent)}) exitWith {
        _registry deleteAt _token;
        false
    };
    if ((_record get "phase") != "PENDING") exitWith {[_record] call _sendResult;true};
    if (!_accepted) then {_record set ["phase","REFUSED"]} else {
        private _acks=_record get "acks";_acks pushBackUnique _sender;
        if (count _acks == count (_record get "owners")) then {_record set ["phase","AGREED"]};
    };
    if ((_record get "phase") != "PENDING") then {[_record] call _sendResult};
    true
};
false
/*
 * Author: WaldoTheWarfighter
 * Purpose: Requests finite server-brokered consent for a fully prepared road-pass proposal.
 * Locality/authority: Passing vehicle owner only. Server authenticates the sender; each
 * participant owner independently checks current eligibility and its exact crew/order row.
 * Repeat/JIP: One outstanding local request per unchanged context until its original expiry.
 * No JIP command, movement, priority or collision exemption. Consent is not execution authority.
 * Arguments: 0 proposal <HASHMAP>, empty; 1 preparation work <HASHMAP>, empty.
 * Return: BOOL - request submitted, not agreement, movement or physical passing success.
 * Current callers: trusted script preflight and experimental DrivingPassAdmission.
 * Example: [_proposal,_work] call WAIT_fnc_DrivingPassAgreementRequest;
 */
params [["_proposal",createHashMap,[createHashMap]],["_work",createHashMap,[createHashMap]]];
if (isRemoteExecuted || {(_work getOrDefault ["phase",""]) != "READY_PROPOSAL"}) exitWith {false};
// Revalidate the prepared identity/deadline/consent before requesting another owner's reply.
_work=[_proposal,_work] call WAIT_fnc_DrivingPassPrepare;
if ((_work getOrDefault ["phase",""]) != "READY_PROPOSAL") exitWith {false};
private _vehicles=_work get "vehicles";private _vehicle=_vehicles select 0;
private _context=_work get "context";private _deadline=_work get "deadline";
if (!local _vehicle || {!([_vehicle] call WAIT_fnc_DrivingPassCanConsent)}) exitWith {false};
private _pending=_vehicle getVariable ["WAIT_DrivingPass_Request",[]];
if (count _pending == 3 && {(_pending select 0) isEqualTo _context} && {serverTime < (_pending select 1)}) exitWith {false};
private _serial=(_vehicle getVariable ["WAIT_DrivingPass_RequestSerial",0])+1;
_vehicle setVariable ["WAIT_DrivingPass_RequestSerial",_serial];
_vehicle setVariable ["WAIT_DrivingPass_Request",[_context,_deadline,_serial]];
private _expires=(_work get "proposalAt")+((_work get "budget") select 2);
["BEGIN",[_serial,_vehicles,_context,_deadline,_expires]] remoteExecCall ["WAIT_fnc_DrivingPassAgreementServer",2];
true
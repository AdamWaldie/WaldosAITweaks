/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires an exact refused ground-support reservation without cancelling the asset's task.
 * Locality/authority: Server only; authenticates the current group owner and exact public snapshot.
 * Repeat/JIP: A consumed or replaced snapshot is a no-op; only durable role metadata is cleared.
 * An owner refusal for missing loaded station ammunition retires the same exact reservation,
 * so unusable armament cannot keep an asset reserved until the opportunity expires.
 * After exact retirement, one bounded ground fallback may replace this slot on another asset;
 * it preserves the original reported contact and expiry and leaves movement to that asset owner.
 * Arguments: 0 group <GROUP, grpNull>; 1 opportunity <ARRAY, []>; 2 reason <STRING, REFUSED>;
 * 3 reply owner <NUMBER, -1>. No movement, target, skill or operation state is restored.
 * Return: BOOL indicating whether this exact ground reservation was retired.
 * Current callers: CortexCombinedArmsLocal admission/refusal and CortexCombinedGroundStep
 * post-cleanup capability, movement and arrival-fire failures.
 * Example: [_group,_opportunity,"NO_SAFE_ROUTE",clientOwner] remoteExecCall ["WAIT_fnc_CortexCombinedRejectServer",2];
 */
params [["_group",grpNull,[grpNull]],["_snapshot",[],[[]]],["_reason","REFUSED",[""]],["_replyOwner",-1,[0]]];
if (!isServer || {isNull _group} || {!((count _snapshot) in [7,8])}
    || {([_replyOwner,groupOwner _group] call WAIT_fnc_HeadlessResolveSender) < 0}) exitWith {false};
private _current=_group getVariable ["WAIT_Cortex_CombinedRole",[]];
if (_current isNotEqualTo _snapshot || {!((_current select 4) in ["GROUND_FIRE","GROUND_MANOEUVRE"])}
    || {!(_reason in ["NO_KNOWN_CONTACT","NO_FIRE_OPERATOR","NO_FIRE_PLATFORM","NO_STATION_AMMO","NO_TARGET_AMMO","BLOCKED_FIRE_LANE","OTHER_INTENT_ACTIVE","NO_SAFE_ROUTE","EXTERNAL_BUSY","OWNER_LOST","MOVEMENT_REJECTED","ASSET_LOST","ASSET_IMMOBILE","BLOCKED"])}) exitWith {false};
_group setVariable ["WAIT_Cortex_CombinedResult",[_current select 0,_current select 4,_reason,serverTime,_current select 2],true];
_group setVariable ["WAIT_Cortex_CombinedRole",nil,true];
_group setVariable ["WAIT_Cortex_CombinedApplied",nil,true];
[_group,_current] call WAIT_fnc_CortexCombinedGroundFallbackServer;
true
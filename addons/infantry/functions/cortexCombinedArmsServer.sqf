/*
 * Author: WaldoTheWarfighter
 * Converts a verified fresh contact into finite, independent combined-arms roles.
 * The server ranks nearby capable ground-vehicle groups and airborne assets by live loaded ordnance and proximity, then selects at most two ground groups and one airborne group. The first
 * capable ground asset supplies direct fire; a second receives a distinct, finite manoeuvre role
 * whose route is kept on one side of the support-to-target fire lane. Aircraft are
 * not rejected for a momentary low-speed sample; the finite attack controller owns acceleration,
 * progress and stuck detection after accepting an aircraft that is physically off the ground. Each
 * role is dispatched immediately; infantry never waits for acceptance and no shared assembly state exists.
 * Vehicle discovery accepts either the effective commander's or driver's group so turret ownership
 * cannot hide an otherwise valid aircraft, while passenger-only groups remain ineligible.
 * Locality/authority: server validates the sender, target, hostility, range, communications and role
 * feature gates; the current asset owner applies targeting through WAIT_fnc_CortexCombinedArmsLocal.
 * Vehicle and aircraft cooperation depends on contact communication and each asset's own feature
 * gate. It does not depend on the infantry coordinated-assault switch: disabling infantry bounds
 * must not silently disable otherwise enabled armour or aircraft support. Aircraft use their own
 * operational support radius rather than the short squad-to-squad report radius; both ends must
 * still be able to transmit, so jamming continues to prevent long-range composition.
 * Repeat/JIP: requester rate limit and expiring public role tokens replace older opportunities safely.
 * Arguments: 0: requester <GROUP>; 1: observed hostile <OBJECT>; 2: believed ATL <ARRAY>;
 * 3: observation server time <NUMBER>.
 * Return Value: Number of asset roles dispatched.
 * Current callers: WAIT_fnc_CortexCombinedArmsRequest through remote execution.
 * Example: [_group,_enemy,getPosATL _enemy,serverTime] remoteExecCall ["WAIT_fnc_CortexCombinedArmsServer",2];
 */
params [["_requester",grpNull,[grpNull]],["_target",objNull,[objNull]],["_position",[],[[]]],["_observedAt",-1,[0]]];
if (!isServer || {isNull _requester} || {isNull _target} || {!alive _target}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != groupOwner _requester}}
    || {count _position < 2} || {_position findIf {!(_x isEqualType 0)} >= 0}
    || {serverTime-_observedAt > 10} || {_target distance2D _position > 75}
    || {(side _requester) getFriend side _target >= 0.6}
    || {!([_requester] call WAIT_fnc_CortexIsEligible)}
    || {!([_requester,"WAIT_AIPass_ContactReports_Enable",true] call WAIT_fnc_CortexFeatureEnabled)}) exitWith {0};
if (serverTime < (_requester getVariable ["WAIT_Cortex_CombinedDue",0])) exitWith {0};
_requester setVariable ["WAIT_Cortex_CombinedDue",serverTime+18];
private _serial=(missionNamespace getVariable ["WAIT_Cortex_CombinedSerial",0])+1;
missionNamespace setVariable ["WAIT_Cortex_CombinedSerial",_serial];
private _token=format ["%1:%2",netId _requester,_serial];
private _expiry=serverTime+35;
private _ground=0;
private _groundAnchor=[];
private _air=0;
private _dispatched=0;
private _roleGroups=[];
private _airCandidates=[];
private _voiceRange=missionNamespace getVariable ["WAIT_AIPass_ContactReports_VoiceRange",35];
private _groundRange=missionNamespace getVariable ["WAIT_AIPass_ContactReports_Radius",500];
private _airRange=missionNamespace getVariable ["WAIT_Cortex_CombinedArms_AirRange",4000];
private _requesterTransmitter=[_requester] call WAIT_fnc_CortexGroupTransmitter;
private _requesterAnchor=if (isNull _requesterTransmitter) then {leader _requester} else {_requesterTransmitter};
private _senderRadio=!isNull _requesterTransmitter;
// Consider assets in a stable suitability order. Raw allGroups iteration could select an
// unarmed aircraft first, consume the sole air role and leave a capable local asset idle.
// The owner still performs the authoritative weapon/turret preflight before it starts a run.
private _orderedGroups=[];
{
    if (!isNull _x) then {
        private _candidateGroup=_x;
        private _candidateTransmitter=[_candidateGroup] call WAIT_fnc_CortexGroupTransmitter;
        private _candidateAnchor=if (isNull _candidateTransmitter) then {leader _candidateGroup} else {_candidateTransmitter};
        if (!isNull _candidateAnchor && {alive _candidateAnchor}) then {
        private _candidateAsset=objNull;
        {
            private _vehicle=vehicle _x;
            private _commander=effectiveCommander _vehicle;
            private _driver=driver _vehicle;
            if (_vehicle != _x && {alive _vehicle}
                && {(!isNull _commander && {group _commander == _candidateGroup})
                    || {!isNull _driver && {group _driver == _candidateGroup}}}) exitWith {_candidateAsset=_vehicle};
        } forEach units _candidateGroup;
        private _damagingMagazine=-1;
        if (!isNull _candidateAsset) then {
            _damagingMagazine=(magazinesAllTurrets _candidateAsset) findIf {
                (_x param [2,0]) > 0 && {
                    private _ammo=configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> (_x param [0,""]) >> "ammo");
                    (getNumber (_ammo >> "hit")) > 0 || {(getNumber (_ammo >> "indirectHit")) > 0}
                }
            };
        };
        // Armed aircraft rank first, then armed ground vehicles, then all other groups. Distance
        // keeps support local without inventing a fixed assembly position or formation.
        private _kind=if (!isNull _candidateAsset && {_candidateAsset isKindOf "Air"} && {_damagingMagazine >= 0}) then {0}
            else {if (!isNull _candidateAsset && {_damagingMagazine >= 0}) then {1} else {2}};
        _orderedGroups pushBack [[_kind,_candidateAnchor distance2D _requesterAnchor],_candidateGroup];
        };
    };
} forEach allGroups;
_orderedGroups sort true;
{
    private _candidate=_x select 1;
    private _candidateTransmitter=[_candidate] call WAIT_fnc_CortexGroupTransmitter;
    private _candidateAnchor=if (isNull _candidateTransmitter) then {leader _candidate} else {_candidateTransmitter};
    private _distance=_candidateAnchor distance2D _requesterAnchor;
    private _candidateRadio=!isNull _candidateTransmitter;
    if (_candidate != _requester && {side _candidate == side _requester} && {!isNull _candidateAnchor} && {alive _candidateAnchor}
        && {[_candidate] call WAIT_fnc_CortexIsEligible}
        && {_distance <= _voiceRange || {_senderRadio && {_candidateRadio}}}) then {
        private _asset=objNull;
        {
            private _vehicle=vehicle _x;
            private _commander=effectiveCommander _vehicle;
            private _driver=driver _vehicle;
            if (_vehicle != _x && {alive _vehicle}
                && {(!isNull _commander && {group _commander == _candidate})
                    || {!isNull _driver && {group _driver == _candidate}}}) exitWith {_asset=_vehicle};
        } forEach units _candidate;
        private _role="";
        // Preserve a bounded ordered fallback list. Local ownership is the only safe place to
        // verify actual pylon/weapon pairing, so an owner may still reject this candidate.
        if (!isNull _asset && {_asset isKindOf "Air"} && {_distance <= _airRange} && {!isTouchingGround _asset}
            && {combatMode _candidate in ["YELLOW","RED"]}
            && {[_candidate,"WAIT_Cortex_AirAttack_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) then {
            _airCandidates pushBack _candidate;
        };
        if (!isNull _asset && {_asset isKindOf "Air"} && {_distance <= _airRange} && {_air < 1} && {!isTouchingGround _asset}
            && {combatMode _candidate in ["YELLOW","RED"]}
            && {[_candidate,"WAIT_Cortex_AirAttack_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) then {
            _role="AIR_ATTACK"; _air=_air+1;
        } else {
            if (!isNull _asset && {_asset isKindOf "LandVehicle"} && {_distance <= _groundRange} && {!(_asset isKindOf "StaticWeapon")}
                && {_ground < 2} && {canFire _asset} && {!(_asset getVariable ["WAIT_Convoy_Active",false])}
                && {[_candidate,"WAIT_AIPass_Vehicles_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
                && {[_candidate,"WAIT_AIPass_VehicleGunnery_Enable",true] call WAIT_fnc_CortexFeatureEnabled}) then {
                _role=["GROUND_FIRE","GROUND_MANOEUVRE"] select (_ground > 0);
                if (_ground == 0) then {_groundAnchor=getPosATL _asset};
                _ground=_ground+1;
            };
        };
        if (_role != "") then {
            private _context=if (_role == "GROUND_MANOEUVRE") then {+_groundAnchor} else {[]};
            private _opportunity=[_token,_requester,_target,+_position,_role,_expiry,_context];
            _candidate setVariable ["WAIT_Cortex_CombinedRole",_opportunity,true];
            _candidate setVariable ["WAIT_Cortex_CombinedApplied",nil,true];
            _candidate setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"DISPATCHED",serverTime,_target],true];
            [_candidate,_opportunity] remoteExecCall ["WAIT_fnc_CortexCombinedArmsLocal",groupOwner _candidate];
            _roleGroups pushBack _candidate;
            _dispatched=_dispatched+1;
        };
    };
    if (_ground >= 2 && {_air >= 1}) exitWith {};
} forEach _orderedGroups;
_requester setVariable ["WAIT_Cortex_CombinedOpportunity",[_token,_target,+_position,_expiry,_dispatched],true];
// Index 1 is the second ranked air candidate: the first, if any, was dispatched above. A rejected
// local preflight advances this finite list once rather than creating another planner or delaying
// the infantry contact. The server never infers a remote airframe's live weapon compatibility.
_requester setVariable ["WAIT_Cortex_CombinedAirFallback",[_token,_target,+_position,_expiry,+_airCandidates,1],true];
[{
    params ["_requester","_token","_roleGroups"];
    if (!isNull _requester && {((_requester getVariable ["WAIT_Cortex_CombinedOpportunity",[]]) param [0,""]) == _token}) then {
        _requester setVariable ["WAIT_Cortex_CombinedOpportunity",nil,true];
        _requester setVariable ["WAIT_Cortex_CombinedAirFallback",nil,true];
    };
    {
        if (!isNull _x && {((_x getVariable ["WAIT_Cortex_CombinedRole",[]]) param [0,""]) == _token}) then {
            private _role=(_x getVariable ["WAIT_Cortex_CombinedRole",[]]) param [4,""];
            private _target=(_x getVariable ["WAIT_Cortex_CombinedRole",[]]) param [2,objNull];
            _x setVariable ["WAIT_Cortex_CombinedResult",[_token,_role,"EXPIRED",serverTime,_target],true];
            _x setVariable ["WAIT_Cortex_CombinedRole",nil,true];
            _x setVariable ["WAIT_Cortex_CombinedApplied",nil,true];
        };
    } forEach _roleGroups;
},[_requester,_token,_roleGroups],(_expiry-serverTime) max 0] call CBA_fnc_waitAndExecute;
_dispatched

/*
 * Author: WaldoTheWarfighter
 * Decides whether the Smart AI Pass may command a group. This is the single exclusion gate for
 * every behaviour, so integrations use one generic exclusion contract instead of product-specific lists.
 *
 * A group is refused when:
 * - it contains a living player, or its side is not in WAIT_AIPass_IncludedSides;
 * - the group or any living member sets WAIT_AI_Exclude (all AI Tweaks changes) or
 *   WAIT_AIPass_Exclude (this pass only);
 * - WAIT's compatibility boundary reports external ownership for the group, a member or an occupied vehicle;
 * - the group belongs to this addon's active convoy or landing controller;
 * - a member uses a UAV or UGV (for example Virtual Vehicle Depot drone crews);
 * - Zeus has priority: the group is held after a curator edited it or gave it waypoints
 *   (WAIT_fnc_CortexZeusHeld), a member is remote-controlled (vanilla and ZEN both set
 *   bis_fnc_moduleRemoteControl_owner), or a member is under a ZEN AI order (ZEN garrison or ZEN
 *   suppressive fire);
 * - a member fails the shared AI filters: WAIT_AI_IncludedFactions, WAIT_AI_ExcludedFactions or
 *   WAIT_AI_ExcludedClasses.
 * - a specialist controller owns the actor, an external melee controller owns its state, or neutral external control
 *   owns the group, actor or occupied vehicle. Addon presence alone never excludes ordinary infantry.
 * A locality pin alone is not behavioural ownership and does not exclude a group.
 *
 * Locality and authority: read-only and callable anywhere; it changes and broadcasts nothing.
 *
 * Review contract: Feature markers are checked on the group as well as members and vehicles. Zeus-held checks maintain the documented local timing cache and may clear an expired waypoint flag.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: ignore temporary Zeus hold <BOOL>, default false; explicit order preflight only.
 * 2: generic ground pass <BOOL>, default false. When true, any group with a living member aboard
 *    an aircraft is reserved for the dedicated airborne, flare and attack controllers. This keeps
 *    infantry contact, support, regroup and vehicle-ground logic from competing for its pilot.
 * 3: allow current WAIT feature ownership <BOOL>, default false. Internal continuation paths use
 *    this only to inspect their own active feature while every player, Zeus, external-controller,
 *    faction and unit safety exclusion remains enforced.
 * 4: actor-local context <OBJECT>, objNull. Native reflex callers may inspect one member;
 * group movement/coordination callers omit this and retain whole-group exclusions.
 * Repeat/JIP: read-only apart from the documented local hold cache; safe to repeat.
 *
 * Return Value:
 * Boolean - true when the pass may command the group
 *
 * Example:
 * [group _unit] call WAIT_fnc_CortexIsEligible;
 * Result: false for a player squad, a gunship crew or any group marked with WAIT_AIPass_Exclude.
 *
 * Current callers: shared eligibility gates across Cortex group, vehicle, aircraft, artillery,
 * building, support and locality controllers.
 */

params [["_group", grpNull, [grpNull]], ["_ignoreZeusHold",false,[true]], ["_groundPass",false,[true]], ["_allowFeatureOwner",false,[true]], ["_actorContext",objNull,[objNull]]];
if (isNull _group) exitWith {false};
if ([_group,_ignoreZeusHold,_actorContext] call WAIT_fnc_CortexExternalTakeover || {"ALL" in (_group getVariable ["WAIT_AIPass_DisabledFeatures", []])}) exitWith {false};
// The optional preflight exemption skips only the expiring Zeus waypoint-hold cache. It never
// bypasses direct curator remote control, player, specialist or declared external ownership.
if (_group getVariable ["WAIT_AI_Exclude", false]
    || {_group getVariable ["WAIT_AIPass_Exclude", false]}
    || {[_group] call WAIT_fnc_CompatibilityExternalControl}) exitWith {false};

private _alive = (units _group) select {alive _x};
if (_alive isEqualTo [] || {_alive findIf {isPlayer _x} >= 0}) exitWith {false};
if (!isNull _actorContext) then {_alive=_alive select {_x == _actorContext}};
if (_alive isEqualTo []) exitWith {false};
if (_groundPass && {_alive findIf {
    private _vehicle=vehicle _x;
    _vehicle != _x && {_vehicle isKindOf "Air"}
} >= 0}) exitWith {false};

if (_alive findIf {
    private _job = _x getVariable ["WAIT_Convoy_Dismount", []];
    count _job == 4 && {serverTime < (_job select 2)}
} >= 0) exitWith {false};
private _sideKey = switch (side _group) do {
    case west: {"WEST"}; case east: {"EAST"}; case independent: {"GUER"}; case civilian: {"CIV"}; default {""};
};
private _includedSides = ((missionNamespace getVariable ["WAIT_AIPass_IncludedSides", ["WEST", "EAST", "GUER"]]) select {_x isEqualType ""}) apply {toUpperANSI _x};
if !(_sideKey in _includedSides) exitWith {false};

private _includedFactions = missionNamespace getVariable ["WAIT_AI_IncludedFactions", []];
private _excludedFactions = missionNamespace getVariable ["WAIT_AI_ExcludedFactions", []];
private _excludedClasses = missionNamespace getVariable ["WAIT_AI_ExcludedClasses", []];
// Other addons and mission systems need only set the generic public compatibility flag.
private _featureMarkers = ["WAIT_Convoy_Active"];
private _isFeatureOwned = {
    params ["_object"];
    _featureMarkers findIf {
        private _value = _object getVariable _x;
        !isNil "_value" && {!(_value isEqualTo false)}
    } >= 0
};

if (!_allowFeatureOwner && {[_group] call _isFeatureOwned}) exitWith {false};

(_alive findIf {
    private _unit = _x;
    private _vehicles = [vehicle _unit, assignedVehicle _unit] select {!isNull _x && {_x != _unit}};
    (_unit getVariable ["WAIT_AI_Exclude", false])
    || {_unit getVariable ["WAIT_AIPass_Exclude", false]}
    // Retain the unit-level declaration here as an auditable complement to the group gate above:
    // a newly joined specialist actor must remain excluded even before a locality snapshot updates.
    || {[_unit] call WAIT_fnc_CortexExternalOwner != ""}
    || {_unit getVariable ["zen_ai_garrisoned", false]}
    || {_unit getVariable ["zen_ai_isSuppressing", false]}
    || {!_allowFeatureOwner && {[_unit] call _isFeatureOwned}}
    || {count _includedFactions > 0 && {!(faction _unit in _includedFactions)}}
    || {faction _unit in _excludedFactions}
    || {typeOf _unit in _excludedClasses}
    // The permanent helicopter pin prevents unstable HC transfer; it does not own flight behaviour.
    // Only an active landing correction excludes the operating crew. A separate cargo squad remains
    // eligible for an explicit airborne order throughout.
    || {_vehicles findIf {_x getVariable ["WAIT_ImprovedHelicopterLanding_Active",false] && {group driver _x == _group}} >= 0}
    || {_vehicles findIf {unitIsUAV _x || {!_allowFeatureOwner && {[_x] call _isFeatureOwned}}} >= 0}
}) < 0

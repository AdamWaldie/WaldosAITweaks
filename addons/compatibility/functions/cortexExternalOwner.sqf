/*
 * Author: WaldoTheWarfighter
 * Identifies AI whose movement, animation or combat state belongs to a supported external system.
 * WAIT uses this one read-only gate before any tactic so specialist skeletons, creatures, droids and
 * active melee actors never receive competing movement, animation or damage commands.
 * Ordinary infantry remains eligible when those addons are merely loaded.
 *
 * Locality / Authority: read-only and callable anywhere. No public state or addon variable is changed.
 * Repeat/JIP: repeat-safe; it reads current config and public runtime markers on every call.
 *
 * Arguments:
 * 0: actor <OBJECT>, default objNull
 *
 * Return Value:
 * String - empty when Cortex may proceed; otherwise the external owner identifier.
 *
 * Current callers: WAIT_fnc_CortexIsEligible and AI diagnostics.
 *
 * Example:
 * private _owner = [_unit] call WAIT_fnc_CortexExternalOwner;
 * Result: "SPECIALIST" for a specialist droid and "" for an ordinary NATO rifleman.
 */

params [["_unit",objNull,[objNull]]];
if (isNull _unit) exitWith {""};

private _config=configOf _unit;
private _class=typeOf _unit;
private _faction=getText (_config >> "faction");
private _author=toLowerANSI (getText (_config >> "author"));
private _subcategory=getText (_config >> "editorSubcategory");
private _wbkFactions=[
    "WBK_AI_ZHAMBIES","WBK_AI_StarWars_Droids","WBK_AI","WBK_AI_Melee",
    "WBK_EOO_Secession","WBK_EOO_Vamp","Empires_Of_Old_faction_Vamp",
    "WBK_EOO_FreeCompany","WBK_EOO_Empire","WBK_HL_Aliens","WBK_HL_resistance",
    "WBK_HL_Combines","OPTRE_FC_Covenant","dev_flood","dev_mutants"
];
private _wbkMarker=!(isNil {_unit getVariable "WBK_AI_ISZombie"})
    || {!(isNil {_unit getVariable "Droid_Health"})}
    || {!(isNil {_unit getVariable "WBK_Droids_VoiceType"})}
    || {!(isNil {_unit getVariable "WBK_AI_ZombieMoveSet"})};
// A non-standard movement config alone is not a specialist contract. Several ordinary content
// packs use custom movement sets, and excluding them would silently disable WAIT for unrelated AI.
// Match only the specialist's own public runtime markers, class/faction identity or declared author.
if (_wbkMarker || {_class find "WBK_" == 0} || {_faction in _wbkFactions}
    || {_subcategory == "WBK_MeleeAi_SPACE_MARINES"} || {_author find "webknight" >= 0}) exitWith {"SPECIALIST"};

// external controller only owns an actor while its melee runtime says so. Loading external controller must not exclude every rifleman.
private _animation=toLowerANSI animationState _unit;
private _meleeBackendActive=!(isNil {_unit getVariable "IMS_IsUnitInvicibleScripted"})
    || {!(isNil {_unit getVariable "IMS_ISAI"})}
    || {!(isNil {_unit getVariable "IMS_EventHandler_Hit"})}
    || {_animation find "ims_" == 0}
    || {_animation find "star_wars_fight" == 0};
if (_meleeBackendActive) exitWith {"MELEE"};

""

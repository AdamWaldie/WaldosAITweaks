/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeated stop is safe; removes tracked local handlers and restores only owned skill state. No JIP replay of stopped work.
 * Stops future automatic AI profile application and optionally restores captured skills. Captured
 * original values, custom aim coefficient and stable variance offsets are cleared publicly after restoration so a later
 * explicit restart creates a fresh baseline and one new per-unit variation.
 * Locality and authority: a direct server call requests disable through the CBA server layer.
 * CBA invokes cleanup on each owner; each machine restores only its local AI. CBA retains the
 * disabled effective value for joining owners without a second JIP initializer.
 *
 * Arguments:
 * None
 *
 * Return Value: Nothing.
 *
 * Example:
 * [] call WAIT_fnc_AIRebalanceStop;
 * Result: Stops future application, restores captured values where requested by the server,
 * and clears the previous baseline for a later explicit restart.
 *
 * Current callers: CBA setting callbacks, server scripts and the audit AI reset station.
 */

if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {};
if (isServer && {missionNamespace getVariable ["WAIT_AIRebalance_Enable", true]}) exitWith {
    [createHashMapFromArray [["WAIT_AIRebalance_Enable", false]]] call WAIT_fnc_CortexTuning;
};
missionNamespace setVariable ["WAIT_AI_RebalanceInitPending", false];
missionNamespace setVariable ["WAIT_AI_RebalanceActive", false];
if !(isNil "WAIT_Cortex_LightingPFH") then {
    [WAIT_Cortex_LightingPFH] call CBA_fnc_removePerFrameHandler;
    WAIT_Cortex_LightingPFH = nil;
};
missionNamespace setVariable ["WAIT_Cortex_LightingUnits",[]];
missionNamespace setVariable ["WAIT_Cortex_LightingCursor",0];
if (missionNamespace getVariable ["WAIT_AI_RestoreOnStop", true]) then {
    {
        if (local _x && {!isPlayer _x}) then {
            private _unit = _x;
            private _original = _unit getVariable ["WAIT_AI_OriginalSkills", createHashMap];
            {_unit setSkill [_x, _original get _x]} forEach keys _original;
            _unit setCustomAimCoef (_unit getVariable ["WAIT_AI_OriginalAimCoef", getCustomAimCoef _unit]);
            _unit setVariable ["WAIT_AI_OriginalSkills", nil, true];
            _unit setVariable ["WAIT_AI_OriginalAimCoef", nil, true];
            _unit setVariable ["WAIT_AI_SkillVarianceOffsets", nil, true];
        };
    } forEach allUnits;
};

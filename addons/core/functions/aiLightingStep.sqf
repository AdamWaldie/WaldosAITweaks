/*
 * Author: WaldoTheWarfighter
 * Refreshes lighting, sensor and crew-seat skill layers for at most ten registered local AI.
 * Locality / Authority: Runs on the unit owner through the shared budgeted scheduler. No world scan.
 * Repeat/JIP: One generation-bound job per owner; stop invalidates it. Joining owners register local AI.
 * Arguments: 0 state <HASHMAP> containing subsystem SKILLS and generation <NUMBER>.
 * Return Value: NUMBER - next delay in seconds, or -1 when disabled or superseded.
 * Current callers: WAIT_fnc_AIRebalanceInit through WAIT_fnc_CortexQueueJob.
 * Example: [createHashMapFromArray [["subsystem","SKILLS"],["generation",1]]] call WAIT_fnc_AILightingStep;
 */
params [["_state", createHashMap, [createHashMap]]];
if !(missionNamespace getVariable ["WAIT_AI_RebalanceActive", false]) exitWith {-1};
if ((_state getOrDefault ["generation", -1]) != (missionNamespace getVariable ["WAIT_AI_LightingGeneration", 0])) exitWith {-1};
private _units = missionNamespace getVariable ["WAIT_Cortex_LightingUnits",[]];
private _cursor = missionNamespace getVariable ["WAIT_Cortex_LightingCursor",0];
if (_cursor >= count _units) then {
    _units = _units select {!isNull _x && {alive _x} && {local _x} && {!isPlayer _x}};
    missionNamespace setVariable ["WAIT_Cortex_LightingUnits",_units];
    _cursor = 0;
};
private _mode = missionNamespace getVariable ["WAIT_AIRebalance_Mode","AUTO"];
private _dark = (getLighting select 1) <= (missionNamespace getVariable ["WAIT_AI_DarknessThreshold",5]);
for "_i" from _cursor to ((_cursor + 9) min ((count _units)-1)) do {
    private _unit = _units select _i;
    private _seat = assignedVehicleRole _unit;
    private _profileVehicle = vehicle _unit;
    private _profileSeat = toUpperANSI (_seat param [0,""]);
    private _precisionExcluded = [_unit] call WAIT_fnc_CompatibilityPrecisionExcluded;
    private _signature = [_mode,_dark,hmd _unit,netId _profileVehicle,_profileSeat,_precisionExcluded];
    if (local _unit && {alive _unit} && {_signature isNotEqualTo (_unit getVariable ["WAIT_Cortex_LightingSignature",[]])}) then {
        [_unit] call WAIT_fnc_AIApplyProfile;
    };
};
missionNamespace setVariable ["WAIT_Cortex_LightingCursor",_cursor+10];
1

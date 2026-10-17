/*
 * Author: WaldoTheWarfighter
 * Purpose: Install disposable owner-side audit function definitions on server, clients and HCs.
 * Locality/authority: Every audit machine; installation itself starts no sampling, AI or handlers.
 * Repeat/JIP: Definitions install once per machine; late HCs receive them before fixture requests.
 * Arguments: None. Return: Nothing. Current caller: engine mission init.
 * Example: Run the checked-in staged audit mission; no production addon calls this script.
 */
if !(missionNamespace getVariable ["WAIT_CortexQA_OwnerHelpersInstalled",false]) then {
    call compile preprocessFileLineNumbers "cortexQAPerformanceOwner.sqf";
    call compile preprocessFileLineNumbers "cortexQAIndoorActorOwner.sqf";
    private _installed=!isNil "WAIT_CortexQA_PerformanceSampleOwner"
        && {!isNil "WAIT_CortexQA_PerformanceDeleteGroup"} && {!isNil "WAIT_CortexQA_PerformanceStartGroup"}
        && {!isNil "WAIT_CortexQA_IndoorActorOwner"} && {!isNil "WAIT_CortexQA_IndoorActorAckServer"};
    missionNamespace setVariable ["WAIT_CortexQA_OwnerHelpersInstalled",_installed];
    if (!_installed) then {diag_log "WAIT AUDIT ERROR: owner helper bootstrap incomplete"};
};

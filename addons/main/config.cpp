#include "script_component.hpp"

class CfgPatches {
    class WAIT_AI_Tweaks_Main {
        name = "Waldos AI Tweaks";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"cba_main", "cba_xeh", "A3_Modules_F", "WAIT_core", "WAIT_infantry", "WAIT_vehicles", "WAIT_aircraft", "WAIT_support", "WAIT_compatibility"};
        units[] = {"WAIT_ModuleConvoyStart", "WAIT_ModuleConvoyHold", "WAIT_ModuleConvoyRelease"};
        weapons[] = {};
        version = "0.1.0";
        versionStr = "0.1.0";
        versionAr[] = {0, 1, 0};
    };
};

class Extended_PreInit_EventHandlers {
    class WAIT_AI_Tweaks_Main {
        init = "call compile preprocessFileLineNumbers '\z\waldo_ai_tweaks\addons\main\XEH_preInit.sqf'";
    };
};

class Extended_PostInit_EventHandlers {
    class WAIT_AI_Tweaks_Main {
        init = "call compile preprocessFileLineNumbers '\z\waldo_ai_tweaks\addons\main\XEH_postInit.sqf'";
    };
};

#include "CfgFunctions.hpp"

// Native curator orders are available without an optional dialog provider.
class CfgFactionClasses {
    class WAIT_CuratorOrders {
        displayName = "Waldos AI Tweaks";
        priority = 2;
        side = 7;
    };
};
class CfgVehicles {
    class Module_F;
    class WAIT_ModuleConvoyStart: Module_F {
        scope = 1;
        scopeCurator = 2;
        displayName = "Convoy: start / resume";
        category = "WAIT_CuratorOrders";
        function = "WAIT_fnc_ModuleConvoy";
        isGlobal = 1;
        isTriggerActivated = 0;
        isDisposable = 1;
        curatorCanAttach = 1;
        WAIT_operation = "START";
    };
    class WAIT_ModuleConvoyHold: WAIT_ModuleConvoyStart {
        displayName = "Convoy: hold and unload passengers";
        WAIT_operation = "STOP";
    };
    class WAIT_ModuleConvoyRelease: WAIT_ModuleConvoyStart {
        displayName = "Convoy: release control";
        WAIT_operation = "RELEASE";
    };
};
class Extended_DisplayLoad_EventHandlers {
    class RscDisplayCurator {
        WAIT_AI_Tweaks = "call (missionNamespace getVariable ['WAIT_AIPass_ZeusInstallLocal', {}])";
    };
};

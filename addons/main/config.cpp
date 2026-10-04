#include "script_component.hpp"

class CfgPatches {
    class Waldo_AI_Tweaks_Main {
        name = "Waldos AI Tweaks";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"cba_main", "cba_xeh", "zen_main"};
        units[] = {};
        weapons[] = {};
        version = "0.1.0";
        versionStr = "0.1.0";
        versionAr[] = {0, 1, 0};
    };
};

class Extended_PreInit_EventHandlers {
    class Waldo_AI_Tweaks_Main {
        init = "call compile preprocessFileLineNumbers '\z\waldo_ai_tweaks\addons\main\XEH_preInit.sqf'";
    };
};

class Extended_PostInit_EventHandlers {
    class Waldo_AI_Tweaks_Main {
        init = "call compile preprocessFileLineNumbers '\z\waldo_ai_tweaks\addons\main\XEH_postInit.sqf'";
    };
};

#include "CfgFunctions.hpp"

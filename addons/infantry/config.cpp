class CfgPatches {
    class WAIT_infantry {
        name = "Waldos AI Tweaks - Infantry";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"cba_main", "A3_Characters_F"};
        units[] = {};
        weapons[] = {};
    };
};

class CfgVehicles {
    class CAManBase;
    class SoldierWB: CAManBase {
        fsmDanger = "\z\waldo_ai_tweaks\addons\infantry\fsm\danger.fsm";
    };
    class SoldierEB: CAManBase {
        fsmDanger = "\z\waldo_ai_tweaks\addons\infantry\fsm\danger.fsm";
    };
    class SoldierGB: CAManBase {
        fsmDanger = "\z\waldo_ai_tweaks\addons\infantry\fsm\danger.fsm";
    };
};

class CfgPatches {
    class WAIT_danger {
        name = "Waldos AI Tweaks - Danger Brain";
        author = "WaldoTheWarfighter";
        requiredVersion = 2.18;
        requiredAddons[] = {"A3_Characters_F"};
        units[] = {};
        weapons[] = {};
    };
};

class CfgVehicles {
    class CAManBase;
    class SoldierWB: CAManBase {
        fsmDanger = "z\wait\danger\danger.fsm";
    };
    class SoldierEB: CAManBase {
        fsmDanger = "z\wait\danger\danger.fsm";
    };
    class SoldierGB: CAManBase {
        fsmDanger = "z\wait\danger\danger.fsm";
    };
};

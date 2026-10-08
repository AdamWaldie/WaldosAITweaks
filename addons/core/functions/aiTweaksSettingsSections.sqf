/*
 * Author: WaldoTheWarfighter
 * Purpose: Defines ordered CBA pages and use-case sections for the shared settings specification.
 * Locality/authority: Read-only on every machine. Presentation metadata never changes settings values.
 * Repeat/JIP: Stateless and repeat-safe; clients use the same addon catalogue on joining.
 * Arguments: None. Return Value: ARRAY of [section key <STRING>, page <STRING>, heading <STRING>].
 * Current callers: AITweaksRegisterSettings; parity checker reads these literals for generated guides.
 * Example: private _sections = [] call WAIT_fnc_AITweaksSettingsSections;
 */
[
    ["GENERAL", "01 General", "01 Participation and ownership"],
    ["PROFILE", "01 General", "02 Tactical profile"],
    ["PERFORMANCE", "01 General", "03 Performance"],
    ["SKILLS", "02 Skills", "01 Profiles and visibility"],
    ["PRECISION", "02 Skills", "02 Weapon precision"],
    ["CONTACT", "03 Infantry", "01 Awareness and contact"],
    ["FIRE", "03 Infantry", "02 Fire and immediate reactions"],
    ["MOVEMENT", "03 Infantry", "03 Manoeuvre"],
    ["COVER", "03 Infantry", "04 Cover and stance"],
    ["MORALE", "03 Infantry", "05 Morale and withdrawal"],
    ["RECOVERY", "03 Infantry", "06 Survivor recovery"],
    ["BUILDINGS", "03 Infantry", "07 Buildings and CQB"],
    ["COMMS", "04 Coordination", "01 Communication"],
    ["COORD", "04 Coordination", "02 Support and assault"],
    ["RESUPPLY", "04 Coordination", "03 Resupply"],
    ["DRIVING", "05 Vehicles", "01 General driving and route safety"],
    ["VEHICLES", "05 Vehicles", "02 Combat and withdrawal"],
    ["PASSENGERS", "05 Vehicles", "03 Passengers"],
    ["CONVOY_TRAVEL", "06 Convoys", "01 Travel and spacing"],
    ["CONVOY_DRIVING", "06 Convoys", "02 Driving and route safety"],
    ["CONVOY_CONTACT", "06 Convoys", "03 Contact and passengers"],
    ["AIR_ATTACK", "07 Aircraft", "01 Combat"],
    ["AIR_DEFENCE", "07 Aircraft", "02 Countermeasures"],
    ["LANDING", "07 Aircraft", "03 Landing"],
    ["BRAKING", "07 Aircraft", "04 Braking"],
    ["AIRBORNE", "07 Aircraft", "05 Airborne delivery"],
    ["ARTILLERY", "08 Support and civilians", "01 Artillery"],
    ["COUNTER", "08 Support and civilians", "02 Counter-battery"],
    ["NAVAL", "08 Support and civilians", "03 Naval delivery"],
    ["CIVILIAN", "08 Support and civilians", "04 Civilian reactions"]
]

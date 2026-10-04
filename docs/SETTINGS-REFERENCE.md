# Settings reference

Generated from `CortexTuningSpec`; edit that source and regenerate this page. These global options are available through CBA Addon Options. CBA owns persistence and JIP synchronization. The variable keys remain the script API. Custom tactical and skill profiles extend the listed built-in choices at runtime. Server validation clamps slider input and rejects unsupported selections.

Defaults describe configuration, not confirmed behavioural acceptance. See [current inventory](CURRENT-INVENTORY.md) and [operations](MODDING-AND-OPERATIONS.md) for validation limits.

| Variable | Label | Type | Default | Range / choices | Purpose |
| --- | --- | --- | --- | --- | --- |
| `WAIT_AIRebalance_Enable` | Apply WAIT skill profiles | CHECKBOX | true | [] | Master control for WAIT skill adjustment. When enabled, the selected skill profile is applied by the machine that owns each AI unit. |
| `WAIT_ImprovedHelicopterLanding_Enable` | Improved helicopter landing | CHECKBOX | true | [] | Uses terrain-aware approach, flare, touchdown and go-around assistance for eligible local AI helicopter pilots. |
| `WAIT_HelicopterDeceleration_Enable` | Helicopter deceleration correction | CHECKBOX | false | [] | Suppresses excessive climb during aggressive AI braking while retaining terrain clearance. Disabled by default pending airframe validation. |
| `WAIT_AIPass_TickBudgetMs` | AI work budget (ms) | SLIDER | 1 | [0.2, 5, 1] | Soft owner-local budget for due AI jobs. A running job is never interrupted; lower values spread work across more frames. |
| `WAIT_AIPass_LowFpsThreshold` | Low-FPS backoff threshold | SLIDER | 25 | [10, 50, 0] | Below this owner-machine FPS, non-urgent behaviour jobs are rescheduled less often. |
| `WAIT_AI_InfantryDispersion` | Infantry weapon dispersion | SLIDER | 1.35 | [1, 3, 2] | Owner-local aim coefficient for dismounted AI and vehicle cargo. Higher values reduce precision without changing reaction or movement skill. |
| `WAIT_AI_VehicleCrewAimMultiplier` | Vehicle crew precision | SLIDER | 0.6 | [0.25, 1, 2] | Final multiplier for operating vehicle and aircraft crew aiming skills. Cargo keeps the normal infantry profile. |
| `WAIT_AI_VehicleCrewDispersion` | Ground vehicle dispersion | SLIDER | 3.5 | [1, 6, 2] | Owner-local aim coefficient for ground-vehicle operators. WAIT skips this layer when an external turret dispersion provider is loaded to avoid double stacking. |
| `WAIT_AI_AirCrewDispersion` | Aircraft weapon dispersion | SLIDER | 4.25 | [1, 7, 2] | Owner-local aim coefficient for aircraft operators. Precision-excluded aircraft remain exempt; external turret dispersion prevents double stacking. |
| `WAIT_AIPass_Enable` | Enable Cortex automatic tactics | CHECKBOX | true | [] | Master control for Cortex actions and reactions. The purpose switches below choose which tactics Cortex may use; convoy control remains independent. |
| `WAIT_AIPass_Regroup_Enable` | Survivor regroup | CHECKBOX | true | [] | Survivors of a destroyed squad walk to and join a nearby friendly squad. |
| `WAIT_AIPass_Contact_Enable` | Contact handling | CHECKBOX | true | [] | Squads switch to combat on contact and return to their previous behaviour and waypoints afterwards. Needed by every combat option below. |
| `WAIT_AIPass_PostContact_Enable` | Post-contact search | CHECKBOX | true | [] | After contact is lost: hold, send two soldiers to check the last known position, regroup. |
| `WAIT_AIPass_PostContact_LostSeconds` | Contact lost delay (s) | SLIDER | 30 | [3, 120, 0] | Seconds without a sighting before Cortex leaves contact. Active manoeuvres finish or abort before this handover. |
| `WAIT_AIPass_PostContact_SecuritySeconds` | Security hold (s) | SLIDER | 10 | [0, 60, 0] | Seconds spent securing the last contact before a search team moves. |
| `WAIT_AIPass_PostContact_SearchSeconds` | Search limit (s) | SLIDER | 45 | [10, 180, 0] | Maximum time for the two-soldier search of the last known enemy position. |
| `WAIT_AIPass_PostContact_RegroupSeconds` | Regroup limit (s) | SLIDER | 30 | [10, 120, 0] | Maximum time for surviving squad members to close up before Cortex releases control. |
| `WAIT_AIPass_Flank_Enable` | Flanking | CHECKBOX | true | [] | Half the squad flanks in covered bounds while the rest suppresses. |
| `WAIT_AIPass_StreetCrossing_Enable` | Street crossing | CHECKBOX | true | [] | Flanking squads stop at roads, throw smoke and cross in one bound. |
| `WAIT_AIPass_FireControl_Enable` | Fire control | CHECKBOX | true | [] | Close threats first, spread fire across visible enemies, and alternate suppression inside each squad. A short random delay keeps separate squads from firing in lockstep; every ordered burst checks for friendlies. |
| `WAIT_AIPass_FireControl_MaxShootersPerTarget` | Shooters per target | SLIDER | 2 | [1, 12, 0] | Extra shooters prefer another visible enemy once this many soldiers are assigned to one target. Immediate close threats still take priority. |
| `WAIT_AIPass_Morale_Enable` | Morale and retreat | CHECKBOX | true | [] | Squads under heavy losses and fire break and fall back under smoke. |
| `WAIT_AIPass_Surrender_Enable` | Surrender | CHECKBOX | true | [] | One or two broken survivors surrender only when an enemy is within 60 m and no friendly squad is within 300 m (ACE Captives when loaded). |
| `WAIT_AIPass_GrenadeEvasion_Enable` | Grenade evasion | CHECKBOX | true | [] | AI move away from a live grenade they can see. Test before live use. |
| `WAIT_AIPass_AntiArmour_Enable` | Anti-armour | CHECKBOX | true | [] | The best anti-tank gunner engages known armour, clear of backblast. |
| `WAIT_AIPass_Vehicles_Enable` | Enable Cortex vehicle tactics | CHECKBOX | true | [] | Parent control for Cortex passenger dismount, remount and damaged-vehicle withdrawal. Convoy route control remains independent. |
| `WAIT_AIPass_NavalAssault_Enable` | Naval infantry landing | CHECKBOX | true | [] | AI boat crews make one finite shallow-water approach and deliver embarked infantry onto dry ground. An installed external naval provider takes priority. |
| `WAIT_AIPass_ContactReports_Enable` | Contact reports | CHECKBOX | true | [] | Squads share sighted enemies by radio (blocked by jamming) or by voice. |
| `WAIT_AIPass_Reinforce_Enable` | Reinforcement | CHECKBOX | true | [] | Idle nearby squads move up behind a squad in contact. |
| `WAIT_AIPass_Artillery_Enable` | Enable spotter artillery support | CHECKBOX | false | [] | Parent control for spotter-requested support and retreat smoke missions. Explicitly assign a spotter and configure a friendly battery first. |
| `WAIT_AIPass_CounterBattery_Enable` | Counter-battery | CHECKBOX | false | [] | AI artillery answers enemy artillery whose position is known. |
| `WAIT_AIPass_Airborne_Enable` | Airborne insertion | CHECKBOX | false | [] | AI squads riding in AI-flown helicopters or planes parachute out when their aircraft nears a known enemy. |
| `WAIT_Cortex_AttackRunFlares_Enable` | Proactive attack-run countermeasures | CHECKBOX | true | [] | AI aircraft expend countermeasures while approaching and leaving an assigned hostile target. This is based on attack-run geometry, not a detected missile. |
| `WAIT_Cortex_AirAttack_Enable` | Adaptive aircraft attack patterns | CHECKBOX | true | [] | Eligible planes choose finite strafe, offset, hook or standoff runs. Helicopters also use hover-capable standoff and lateral gun runs. Observed AA and live weapons influence the choice; Zeus orders immediately take priority. |
| `WAIT_AIPass_AircraftFlares_Enable` | Missile-threat countermeasures | CHECKBOX | true | [] | Eligible AI aircraft expend a staggered countermeasure sequence after an incoming missile is detected. |
| `WAIT_AIPass_Investigate_Enable` | Investigation | CHECKBOX | true | [] | Squads send two riflemen to check enemies they know about but have not seen. |
| `WAIT_AIPass_Assault_Enable` | Final assault | CHECKBOX | true | [] | A flank can finish with a grenade and a rush on the enemy position. |
| `WAIT_AIPass_Advance_Enable` | Bounding advance | CHECKBOX | true | [] | Squads in a long firefight push a fire team towards their waypoint in covered bounds. |
| `WAIT_AIPass_Advance_MinContactSeconds` | Advance contact delay | SLIDER | 5 | [0, 300, 0] | Seconds of confirmed contact before a bounding advance may begin. The default reacts quickly enough to take ownership before native waypoint travel consumes the manoeuvre; other movement, knowledge and eligibility checks still apply. |
| `WAIT_AIPass_Advance_Cooldown` | Advance repeat delay | SLIDER | 20 | [0, 180, 0] | Seconds after an advance ends before the same squad may start another. This is shorter than the flank delay so a squad can continue progressing in successive tactical bounds without immediately restarting a finished drill. |
| `WAIT_AIPass_CoordinatedAssault_Enable` | Coordinated assault | CHECKBOX | true | [] | Reinforcing squads assault from both sides while the squad in contact fires. |
| `WAIT_AIPass_Stance_Enable` | Stance from cover | CHECKBOX | true | [] | Soldiers stand, kneel or go prone to match the cover in front of them. |
| `WAIT_AIPass_AmmoShare_Enable` | Ammo sharing | CHECKBOX | true | [] | Soldiers down to their last magazine get one from a nearby squad-mate. |
| `WAIT_AIPass_VehicleGunnery_Enable` | Vehicle gunnery | CHECKBOX | true | [] | Gunners engage AT soldiers first, then armour; armour backs away from AT teams. |
| `WAIT_AIPass_ArtillerySmoke_Enable` | Retreat artillery smoke mission | CHECKBOX | true | [] | Allows a retreating squad to request a non-lethal smoke screen. Requires Enable spotter artillery support and an eligible battery. |
| `WAIT_AIPass_AircraftBreak_Enable` | Aircraft break-away | CHECKBOX | true | [] | Eligible AI aircraft preserve forward energy while jinking away from missile launches. Test addon aircraft first. |
| `WAIT_AIRebalance_Mode` | Lighting | COMBO | "AUTO" | [["AUTO", "DAY", "NIGHT"], ["Automatic visibility", "Daylight override", "Low light (legacy)"]] | Automatic follows ambient darkness and equipped night vision. Day disables the extra penalty; Low light retains the legacy night profile. |
| `WAIT_AIRebalance_Profile` | Selected WAIT skill profile | COMBO | "LINE" | [["LEGACY", "MILITIA", "LINE", "VETERAN", "ELITE"], ["LEGACY", "MILITIA", "LINE", "VETERAN", "ELITE"]] | Skill values used when Apply WAIT skill profiles is enabled. This is independent of the tactical behaviour profile. |
| `WAIT_AIPass_InfantryOwnership` | Infantry controller ownership | COMBO | "SPLIT" | [["SPLIT", "WAIT"], ["Shared ownership (recommended)", "WAIT only"]] | Shared ownership keeps the base danger FSM active. A finite WAIT manoeuvre reserves only its responder and restores prior ownership afterwards. WAIT only gives this addon full group control. The building-task backend remains active in either mode; independent weapon configuration is preserved. |
| `WAIT_AIPass_CivilianReaction_Enable` | Civilian danger reactions | CHECKBOX | true | [] | Unarmed civilians flee nearby gunfire or a hit using event handlers and one finite move. WAIT yields completely when an external civilian controller owns the actor. |
| `WAIT_AIPass_CivilianReaction_Radius` | Civilian gunfire radius (m) | SLIDER | 45 | [10, 150, 0] | FiredNear events inside this distance may trigger an escape response. |
| `WAIT_AIPass_CivilianReaction_Distance` | Civilian escape distance (m) | SLIDER | 180 | [50, 500, 0] | Approximate length of the safe escape leg away from the threat. |
| `WAIT_AIPass_CivilianReaction_Cooldown` | Civilian reaction cooldown (s) | SLIDER | 20 | [2, 120, 0] | Minimum delay before another danger event can replace the current escape order. |
| `WAIT_AIPass_VehicleDismount_Enable` | Contact: dismount passengers | CHECKBOX | true | [] | Under Enable Cortex vehicle tactics, unloads capable passengers only when safely stopped on dry ground. |
| `WAIT_AIPass_VehicleRemount_Enable` | Contact: remount released passengers | CHECKBOX | true | [] | Under Enable Cortex vehicle tactics, allows safe conscious passengers to reboard after contact. A newer Zeus order cancels remount intent. |
| `WAIT_AIPass_VehicleWithdraw_Enable` | Damage: withdraw mobile vehicle | CHECKBOX | true | [] | Under Enable Cortex vehicle tactics, allows a damaged mobile vehicle to withdraw and use existing smoke. |
| `WAIT_AIPass_CoverValidation_Enable` | Additional cover checks | CHECKBOX | true | [] | Adds bounded slope and body clearance checks to shared cover selection. |
| `WAIT_Convoy_MountedFire_Enable` | Convoy mounted targeting | CHECKBOX | true | [] | WMP assigns targets to weapon crew under existing ROE. Disable to leave targeting to another AI mod. |
| `WAIT_Convoy_Cover_Enable` | Convoy dismount movement | CHECKBOX | true | [] | Moves dismounted passengers clear of vehicles; seeks cover during contact. |
| `WAIT_Convoy_AvoidInfantry_Enable` | Convoy infantry avoidance | CHECKBOX | false | [] | Optional short-range friendly infantry corridor checks before driving. |
| `WAIT_Convoy_DrivingAssist_Enable` | Convoy driving assist | CHECKBOX | true | [] | Uses low-frequency road look-ahead and damped speed changes for smoother curves, junctions and grades. It does not bypass obstacles or replace authored routes. |
| `WAIT_Convoy_RouteRecovery_Enable` | Convoy route recovery | CHECKBOX | true | [] | Re-selects the same unchanged final MOVE waypoint when the engine completes it more than 75 m early. It never creates a route, teleports, repairs or defeats an obstruction. |
| `WAIT_Convoy_ContactHalt_Enable` | Convoy contact halts | CHECKBOX | true | [] | Automatic ambush halt using push-through and pinned rules. Route arrival and explicit stop remain available. |
| `WAIT_Convoy_Unload_Enable` | Convoy cargo unloading | CHECKBOX | true | [] | Allows WMP passenger unloading on halt. Operating crews remain aboard. |
| `WAIT_AIPass_Hearing_Enable` | Nearby gunfire investigation | CHECKBOX | true | [] | Hostile FiredNear events create a throttled, approximate 50 m area for investigation, never a target reveal. |
| `WAIT_AIPass_BehaviourProfile` | Behaviour profile | COMBO | "" | [["", "MILITIA", "LINE", "VETERAN", "ELITE"], ["Follow the AI Rebalance profile", "Militia", "Line", "Veteran", "Elite"]] | Tactics profile for every squad without a group or faction profile of its own. Skill values are not changed. |
| `WAIT_AIPass_Aggression` | Aggression | SLIDER | 1.2 | [0, 2, 2] | Scales flank/advance preference, optional grenade preparation, investigation and coordinated-assault participation. Positive local preferences choose which viable manoeuvre starts instead of deciding whether the squad acts. Default 1.2 adds initiative; 1 is the profile value and 0 excludes proactive tactics. |
| `WAIT_AIPass_Cohesion` | Cohesion | SLIDER | 1 | [0.5, 2, 2] | How much punishment squads take before morale breaks. Above 1 they hold longer, below 1 they break sooner. |
| `WAIT_AIPass_ReactionSpeed` | Reaction speed | SLIDER | 1 | [0.5, 2, 2] | How often squads re-assess. Above 1 they react faster and use more server time; below 1 slower. |
| `WAIT_AIPass_EngageRange` | Engagement range (m) | SLIDER | 800 | [200, 1500, 0] | Known enemies within this range of a squad leader are acted on. |
| `WAIT_AIPass_Flank_MaxRange` | Flank range (m) | SLIDER | 400 | [100, 800, 0] | Enemies farther than this are not flanked. |
| `WAIT_AIPass_Morale_RetreatDistance` | Retreat distance (m) | SLIDER | 200 | [50, 500, 0] | How far a broken squad falls back. |
| `WAIT_AIPass_ZeusHoldSeconds` | Zeus hold (s) | SLIDER | 120 | [0, 600, 0] | How long Cortex leaves a squad alone after Zeus edits it or opens its attributes. Selecting a squad for inspection does not interrupt it. |
| `WAIT_AIPass_ContactReports_Radius` | Radio report range (m) | SLIDER | 500 | [0, 1500, 0] | How far squads pass sightings by radio. |
| `WAIT_Cortex_CombinedArms_AirRange` | Aircraft support range (m) | SLIDER | 4000 | [500, 10000, 0] | How far a radio-linked aircraft may accept a fresh combined-arms opportunity. This is independent of the shorter squad report radius. |
| `WAIT_AIPass_Reinforce_Radius` | Reinforcement radius (m) | SLIDER | 600 | [100, 2000, 0] | How far away idle squads may be sent to help. |
| `WAIT_AIPass_Reinforce_MaxResponders` | Reinforcing squads | SLIDER | 2 | [0, 5, 0] | Squads sent to help one squad in contact. |
| `WAIT_AIPass_Artillery_Bursts` | Burst limit | SLIDER | 3 | [1, 5, 0] | Maximum HE bursts per mission; smoke uses one burst. |
| `WAIT_AIPass_Artillery_RoundInterval` | Within-burst interval (s) | SLIDER | 2 | [1, 15, 0] | Minimum seconds between confirmed rounds inside one burst. |
| `WAIT_AIPass_Artillery_LocationResetDistance` | New location distance (m) | SLIDER | 150 | [50, 500, 0] | Reported movement in metres that resets opening offset and safety checks. |
| `WAIT_AIPass_CounterBattery_RadarDelay` | Counter-battery: radar delay (s) | SLIDER | 20 | [1, 120, 0] | Counter-battery acquisition seconds with radar coverage; capped by the normal delay. |
| `WAIT_AIPass_Artillery_Rounds` | Support: rounds per burst | SLIDER | 3 | [1, 10, 0] | Rounds in each support burst. The burst limit caps the mission. |
| `WAIT_AIPass_Artillery_MaxError` | Support: accuracy needed (m) | SLIDER | 50 | [10, 200, 0] | Largest target position error a squad may call fire on. Lower means fewer, more accurate missions. |
| `WAIT_AIPass_Artillery_Cooldown` | Support: cooldown (s) | SLIDER | 120 | [30, 600, 0] | Cooldown after a finite support mission ends. |
| `WAIT_AIPass_Artillery_MinFriendlyDistance` | Support: safety distance (m) | SLIDER | 200 | [50, 500, 0] | No mission lands this close to friendlies or civilians. |
| `WAIT_AIPass_Artillery_ShootAndScoot` | Support: shoot and scoot | CHECKBOX | true | [] | Mobile guns move after a support mission. |
| `WAIT_AIPass_Artillery_DefaultRole` | Default battery role | COMBO | "BOTH" | [["BOTH", "SUPPORT", "COUNTER"], ["Support and counter-battery", "Support only", "Counter-battery only"]] | Missions taken by guns without a role of their own. |
| `WAIT_AIPass_Artillery_OpeningSafeDistance` | Opening safety distance (m) | SLIDER | 200 | [100, 500, 0] | Minimum commanded opening aim distance from the reported target and living players. Player positions are rejection-only. |
| `WAIT_AIPass_Artillery_OpeningBuffer` | Opening extra buffer (m) | SLIDER | 100 | [50, 300, 0] | Additional room for ballistic spread and player movement. Live shells are not a guarantee of harmless impacts. |
| `WAIT_AIPass_Artillery_WarningInterval` | Ranging warning interval (s) | SLIDER | 20 | [10, 60, 0] | Minimum pause after estimated impact before the next burst. |
| `WAIT_AIPass_CounterBattery_Rounds` | Counter-battery: rounds per burst | SLIDER | 4 | [1, 10, 0] | Rounds in each counter-battery burst; ranging changes between bursts. |
| `WAIT_AIPass_CounterBattery_Delay` | Counter-battery: delay (s) | SLIDER | 60 | [1, 120, 0] | Acquisition delay without radar. Radar can shorten it. |
| `WAIT_AIPass_CounterBattery_Interval` | Counter-battery: interval (s) | SLIDER | 60 | [10, 600, 0] | Cooldown after the finite response ends; a new firing event is needed. |
| `WAIT_AIPass_CounterBattery_MinFriendlyDistance` | Counter-battery: safety distance (m) | SLIDER | 200 | [50, 500, 0] | No fire back when friendlies or civilians are this close to the enemy gun. |
| `WAIT_AIPass_CounterBattery_ShootAndScoot` | Counter-battery: shoot and scoot | CHECKBOX | true | [] | Mobile guns move after a counter-battery mission. |
| `WAIT_AIPass_Airborne_DeployDistance` | Airborne: jump distance (m) | SLIDER | 700 | [200, 2000, 0] | AI passengers jump when their aircraft is this close to a known enemy. |
| `WAIT_AIPass_Airborne_Altitude` | Airborne: jump altitude (m) | SLIDER | 250 | [150, 600, 0] | Height the aircraft climbs to for the drop. |
| `WAIT_AIPass_Airborne_MinAltitude` | Airborne: lowest jump (m) | SLIDER | 120 | [80, 300, 0] | Never jump lower than this. |

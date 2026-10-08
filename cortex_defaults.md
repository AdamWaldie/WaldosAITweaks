# Cortex and AI configuration defaults

Verified against addons/main/settings/aiConfig.sqf and the shared CBA control specification on 7 October 2026. These are shipped configuration defaults, before mission or Zeus overrides. Audit scenarios temporarily change values and restore them afterwards.

Cortex automatic tactics are enabled by default. AI skill profiles and improved helicopter landings are independently enabled. Convoy options apply when a convoy is explicitly started. Enabled subfeatures still require their parent feature and applicable setup.

The deliberately opt-in features are artillery support, counter-battery, airborne insertion, helicopter deceleration, Dynamic AO garrison integration, and convoy friendly-infantry avoidance. Each can move or dismount assets, depend on another system, or add a short-range vehicle scan. Missile-threat countermeasures and the bounded break-away reaction are enabled because they are defensive extensions of ordinary AI flight and immediately yield to Zeus or eligibility loss.

Existing WAIT_AIPass_* setting keys remain for mission compatibility; the public AI functions use WAIT_fnc_Cortex*.

Counter-battery defaults to disabled, 60 seconds acquisition without radar or 20 seconds with radar within 8,000 m. Each mission allows up to three bursts of four rounds. The minimum round interval is two seconds; reload time can extend it. The next burst waits until estimated impact plus 20 seconds. The same enemy gun has a 60-second repeat-fire cooldown. A new firing event is required for a later automatic response.

The opening aim exclusion is 200 m plus a 100 m buffer around living players. This controls aim points, not guaranteed impact positions. The shared ranging algorithm starts with a 300 m deliberate offset, reduces it by a factor of 0.55 after a valid correction, and retains a 40 m minimum offset. A reported location change of 150 m resets ranging. These three ranging constants are implementation values, not editable settings.

CounterBattery_Mode is a legacy compatibility value; automatic acquisition does not depend on selecting a mode. ContactReports_RequireRadio is also a legacy value; AI inventory radio items are not required.

| Setting key | Default | Purpose / units |
|---|---|---|
| `WAIT_AIPass_AmmoCapabilityOverrides` | `createHashMap` | MAP: magazine class to ["AT"] / ["AA"] / ["AT","AA"] role overrides. |
| `WAIT_AIRebalance_Enable` | `true` | BOOL: true applies WAIT skill profiles to eligible AI. |
| `WAIT_AIRebalance_Profile` | `"LINE"` | STRING: MILITIA, LINE, VETERAN or ELITE. |
| `WAIT_AIRebalance_Mode` | `"AUTO"` | Ambient-darkness and NVG-aware; DAY disables the extra penalty; NIGHT retains legacy night tiers. |
| `WAIT_AI_ApplyMode` | `"BOTH"` | STRING: EXISTING, NEW or BOTH AI populations. |
| `WAIT_AI_RestoreOnStop` | `true` | ADVANCED: restore captured vanilla/mission skills on stop. |
| `WAIT_AI_SkillVariance` | `0` | ADVANCED: one stable per-AI offset; 0 disables variation. |
| `WAIT_AI_InfantryDispersion` | `1.35` | Owner-local aim coefficient for dismounted AI and vehicle cargo. |
| `WAIT_AI_VehicleCrewAimMultiplier` | `0.6` | Final aiming-skill multiplier for ordinary operating vehicle and aircraft crew. Named Dynamic AA crews are exempt. |
| `WAIT_AI_VehicleCrewDispersion` | `3.5` | Owner-local aim coefficient for ground-vehicle operators when no external precision provider is active. |
| `WAIT_AI_AirCrewDispersion` | `4.25` | Wider owner-local aim coefficient for aircraft operators. Named Dynamic AA crews remain exempt. |
| `WAIT_AI_IncludedSides` | `[]` | ARRAY of WEST/EAST/GUER/CIV strings; [] permits every side. |
| `WAIT_AI_IncludedFactions` | `[]` | ARRAY of CfgFactionClasses names; [] permits every faction. |
| `WAIT_AI_ExcludedFactions` | `[]` | ARRAY of faction names removed after the include filter. |
| `WAIT_AI_ExcludedClasses` | `[]` | ARRAY of exact CfgVehicles unit classnames never changed. |
| `WAIT_ImprovedHelicopterLanding_Enable` | `true` | BOOL: watches eligible landing waypoints for local AI pilots. |
| `WAIT_ImprovedHelicopterLanding_MinimumActivationDistance` | `50` | METRES: waypoint must start at least this far away. |
| `WAIT_ImprovedHelicopterLanding_TriggerDistance` | `500` | METRES: controller takes over inside this distance. |
| `WAIT_ImprovedHelicopterLanding_TriggerSpeedFactor` | `4.2` | MULTIPLIER: approach-speed trigger scaling. |
| `WAIT_ImprovedHelicopterLanding_MinimumApproachSpeed` | `55` | KM/H: minimum speed when scripted approach control begins. |
| `WAIT_ImprovedHelicopterLanding_TransitAltitude` | `30` | METRES AGL: clear-terrain approach height. |
| `WAIT_ImprovedHelicopterLanding_GlideSlopeRatio` | `4` | RATIO: horizontal distance per metre of descent. |
| `WAIT_ImprovedHelicopterLanding_TreeScanRadius` | `25` | METRES: vegetation search around touchdown. |
| `WAIT_ImprovedHelicopterLanding_TreeSafetyBuffer` | `5` | METRES: clearance added above detected canopy. |
| `WAIT_ImprovedHelicopterLanding_MaximumTreeHoverHeight` | `40` | METRES: canopy correction ceiling. |
| `WAIT_ImprovedHelicopterLanding_GoAroundTriggerDistance` | `200` | METRES: assess excessive height inside this range. |
| `WAIT_ImprovedHelicopterLanding_GoAroundHeight` | `150` | METRES AGL: climb target during a go-around. |
| `WAIT_ImprovedHelicopterLanding_GoAroundExitDistance` | `250` | METRES: distance flown clear before re-approach. |
| `WAIT_ImprovedHelicopterLanding_GoAroundSpeed` | `70` | KM/H: commanded go-around speed. |
| `WAIT_ImprovedHelicopterLanding_MaximumGoArounds` | `1` | COUNT: maximum automatic retries for one landing order. |
| `WAIT_ImprovedHelicopterLanding_MaximumClimbRate` | `8` | METRES/SECOND: vertical command clamp. |
| `WAIT_ImprovedHelicopterLanding_MaximumDescentRate` | `10` | METRES/SECOND: descent command clamp. |
| `WAIT_ImprovedHelicopterLanding_TouchdownRadius` | `5` | METRES: accepted horizontal error. Larger is easier but less exact. |
| `WAIT_ImprovedHelicopterLanding_FinalCommitDistance` | `75` | METRES: begin the final flare/landing phase. |
| `WAIT_ImprovedHelicopterLanding_ControlInterval` | `0.05` | SECONDS: local control-loop interval; performance-sensitive. |
| `WAIT_ImprovedHelicopterLanding_TouchdownHoldSeconds` | `20` | SECONDS: keep the AI landed before releasing controls; prevents immediate takeoff. |
| `WAIT_HelicopterDeceleration_Enable` | `false` | BOOL: suppress AI zoom-climb while braking; test airframes before enabling. |
| `WAIT_HelicopterDeceleration_IncludeVTOL` | `false` | BOOL: include VTOL_Base_F aircraft; false is the conservative default. |
| `WAIT_HelicopterDeceleration_MinimumSpeed` | `80` | KM/H: detection is ignored below this airspeed. |
| `WAIT_HelicopterDeceleration_MinimumAltitude` | `25` | METRES AGL: never correct close to terrain. |
| `WAIT_HelicopterDeceleration_MinimumSpeedLoss` | `4` | KM/H PER SAMPLE: braking threshold. |
| `WAIT_HelicopterDeceleration_MinimumAltitudeGain` | `0.5` | METRES PER SAMPLE: unwanted climb threshold. |
| `WAIT_HelicopterDeceleration_MinimumNoseUp` | `0.02` | VECTOR DIR Z: positive nose-up threshold. |
| `WAIT_HelicopterDeceleration_TerrainClearance` | `25` | METRES: required clearance over terrain 100/300/500 m ahead. |
| `WAIT_HelicopterDeceleration_MaximumCorrectionAcceleration` | `2.5` | M/S^2: downward world-force cap. |
| `WAIT_HelicopterDeceleration_MaximumClimbRate` | `0.5` | M/S: release once vertical climb falls to this value. |
| `WAIT_HelicopterDeceleration_SampleInterval` | `0.5` | SECONDS: local detection cadence. |
| `WAIT_HelicopterDeceleration_ControlInterval` | `0.02` | SECONDS: active correction cadence. |
| `WAIT_HelicopterDeceleration_MaximumCorrectionSeconds` | `4` | SECONDS: hard cap per correction event. |
| `WAIT_HelicopterDeceleration_Debug` | `false` | BOOL: detailed RPT acquire/release logging. |
| `WAIT_AIPass_Enable` | `true` | BOOL: master switch for Cortex automatic tactics (server and headless clients only). |
| `WAIT_AIPass_IncludedSides` | `["WEST", "EAST", "GUER"]` | ARRAY of WEST/EAST/GUER/CIV strings the pass may command. |
| `WAIT_AIPass_TickBudgetMs` | `1` | MILLISECONDS: work allowed per 0.25 s scheduler tick; at least one job always runs. |
| `WAIT_AIPass_LowFpsThreshold` | `25` | FPS: below this, behaviour steps are rescheduled half as often. |
| `WAIT_AIPass_Regroup_Enable` | `true` | BOOL: survivors of a destroyed squad regroup with a nearby friendly squad. |
| `WAIT_AIPass_MedicalAssist_Enable` | `true` | BOOL: one local medic uses native treatment during CALM or SECURITY; yields to active medical ownership, Zeus and combat. |
| `WAIT_AIPass_MedicalAssist_Range` | `80` | METRES: maximum local medic-to-casualty selection distance. |
| `WAIT_AIPass_MedicalAssist_DamageThreshold` | `0.35` | DAMAGE: minimum engine damage considered for one finite treatment attempt. |
| `WAIT_AIPass_MedicalAssist_Timeout` | `45` | SECONDS: finite native treatment limit; WAIT releases without changing health. |
| `WAIT_AIPass_Regroup_MaxRemnantSize` | `2` | COUNT: living members at or below this make a remnant. |
| `WAIT_AIPass_Regroup_MinimumPeakSize` | `3` | COUNT: smaller deliberate teams are never merged. |
| `WAIT_AIPass_Regroup_SearchRadius` | `400` | METRES: host squad search radius. |
| `WAIT_AIPass_Regroup_MaxGroupSize` | `12` | COUNT: host size limit after the merge. |
| `WAIT_AIPass_Regroup_JoinDistance` | `30` | METRES: survivors join the host inside this distance. |
| `WAIT_AIPass_Regroup_StuckSeconds` | `20` | SECONDS: without progress, survivors join where they stand. |
| `WAIT_AIPass_Regroup_TimeoutSeconds` | `120` | SECONDS: limit for finding a host and for walking to it. |
| `WAIT_AIPass_Regroup_SettleSeconds` | `5` | SECONDS: delay after a kill before the remnant is assessed. |
| `WAIT_AIPass_BehaviourProfile` | `""` | STRING: "" follows the AI Rebalance profile; MILITIA, LINE, VETERAN or ELITE sets squad tactics for every squad without its own. |
| `WAIT_AIPass_Aggression` | `1.2` | 0-2: scales how often squads flank, assault, advance, investigate and coordinate. |
| `WAIT_AIPass_Cohesion` | `1` | 0.5-2: above 1 squads take more before morale breaks, below 1 they break sooner. |
| `WAIT_AIPass_ReactionSpeed` | `1` | 0.5-2: above 1 squads re-assess more often (more server time), below 1 less often. |
| `WAIT_AIPass_InfantryOwnership` | `"SPLIT"` | STRING: SPLIT (COMPAT keeps in-contact unit tactics) or WAIT (COMPAT group AI off for managed squads). |
| `WAIT_AIPass_CivilianReaction_Enable` | `true` | BOOL: event-driven flight for unarmed civilians; external civilian controller takes priority. |
| `WAIT_AIPass_CivilianReaction_Radius` | `45` | METRES: nearby gunfire trigger range. |
| `WAIT_AIPass_CivilianReaction_Distance` | `180` | METRES: approximate one-shot escape leg. |
| `WAIT_AIPass_CivilianReaction_Cooldown` | `20` | SECONDS: minimum delay before replacing a civilian escape order. |
| `WAIT_AIPass_Debug` | `false` | BOOL: extra [WAIT] RPT lines for contact, flanks, morale and retreats. |
| `WAIT_AIPass_EngageRange` | `800` | METRES: enemies the leader knows about within this range are considered. |
| `WAIT_AIPass_NearRange` | `1000` | METRES: squads this close to a player run at the near cadence. |
| `WAIT_AIPass_FarRange` | `2500` | METRES: beyond this only the state ladder and morale run. |
| `WAIT_AIPass_TickContact` | `2` | SECONDS: step interval for a squad in contact near players. |
| `WAIT_AIPass_TickNear` | `4` | SECONDS: step interval within NearRange. |
| `WAIT_AIPass_TickMid` | `8` | SECONDS: step interval within FarRange. |
| `WAIT_AIPass_TickFar` | `20` | SECONDS: step interval beyond FarRange. |
| `WAIT_AIPass_DiscoveryInterval` | `10` | SECONDS: how often each machine looks for newly local AI groups. |
| `WAIT_AIPass_Contact_Enable` | `true` | BOOL: contact state ladder; needed by every combat behaviour. |
| `WAIT_AIPass_PostContact_Enable` | `true` | BOOL: hold, search the last known position, regroup after contact. |
| `WAIT_AIPass_PostContact_LostSeconds` | `30` | SECONDS: without a sighting before contact counts as lost. |
| `WAIT_AIPass_PostContact_SecuritySeconds` | `10` | SECONDS: security hold before searching. |
| `WAIT_AIPass_PostContact_SearchSeconds` | `45` | SECONDS: search time limit. |
| `WAIT_AIPass_PostContact_RegroupSeconds` | `30` | SECONDS: regroup time limit. |
| `WAIT_AIPass_Flank_Enable` | `true` | BOOL: base of fire plus a flanking element in covered bounds. |
| `WAIT_AIPass_Flank_MinGroupSize` | `6` | COUNT: soldiers on foot needed to flank. |
| `WAIT_AIPass_Flank_MinRange` | `60` | METRES: nearer enemies are fought, not flanked. |
| `WAIT_AIPass_Flank_MaxRange` | `400` | METRES: farther enemies are not flanked. |
| `WAIT_AIPass_Flank_BoundDistance` | `55` | METRES: length of one bound (minimum 15). |
| `WAIT_AIPass_Flank_BoundPause` | `0` | SECONDS: optional deliberate overwatch after physical arrival; zero keeps movement continuous. |
| `WAIT_AIPass_Flank_BoundTimeout` | `25` | SECONDS without physical progress before a bound fails; the absolute limit is four times this value. |
| `WAIT_AIPass_Flank_Cooldown` | `90` | SECONDS: before the same squad flanks again. |
| `WAIT_AIPass_StreetCrossing_Enable` | `true` | BOOL: flanks stop at roads, smoke, and cross in one bound. |
| `WAIT_AIPass_FireControl_Enable` | `true` | BOOL: close threats, fire distribution, disciplined suppression. |
| `WAIT_AIPass_FireControl_MaxSuppressors` | `2` | COUNT: soldiers suppressing at once. |
| `WAIT_AIPass_FireControl_MaxShootersPerTarget` | `2` | COUNT: shooters per visible enemy before others switch. |
| `WAIT_AIPass_Morale_Enable` | `true` | BOOL: weighted morale; broken squads retreat under smoke. |
| `WAIT_AIPass_Morale_RetreatDistance` | `200` | METRES: how far a broken squad falls back. |
| `WAIT_AIPass_Surrender_Enable` | `true` | BOOL: last survivors of a broken, isolated squad surrender. |
| `WAIT_AIPass_GrenadeEvasion_Enable` | `true` | BOOL: move away from seen grenades. |
| `WAIT_AIPass_AntiArmour_Enable` | `true` | BOOL: best AT gunner engages known armour, clear of backblast. |
| `WAIT_AIPass_VehicleDismount_Enable` | `true` | Unloads capable passengers only when safely stopped on dry ground. |
| `WAIT_AIPass_VehicleRemount_Enable` | `true` | Allows safe conscious passengers to reboard after Smart AI contact. Convoy resume stays explicit. |
| `WAIT_AIPass_VehicleWithdraw_Enable` | `true` | Allows damaged vehicles to withdraw and use existing smoke. |
| `WAIT_AIPass_VehicleJink_Enable` | `true` | Allows one short terrain-checked escape by an eligible intact fighting vehicle under close or severe danger. |
| `WAIT_AIPass_DrivingAssist_Enable` | `true` | Applies a sparse terrain-grade speed cap to ordinary AI ground vehicles while preserving their native waypoint and route. Convoys use separate driving controls. |
| `WAIT_AIPass_CoverValidation_Enable` | `true` | Adds bounded slope and body clearance checks to shared cover selection. |
| `WAIT_Convoy_MountedFire_Enable` | `true` | WAIT assigns targets to weapon crew under existing ROE. Disable to leave targeting to another AI mod. |
| `WAIT_Convoy_Cover_Enable` | `true` | Moves dismounted passengers clear of vehicles; seeks cover during contact. |
| `WAIT_Convoy_AvoidInfantry_Enable` | `false` | Optional short-range friendly infantry corridor checks before driving. |
| `WAIT_Convoy_DrivingAssist_Enable` | `true` | Low-frequency road look-ahead and damped speed changes for smoother curves, junctions and grades without replacing authored routes or bypassing obstacles. |
| `WAIT_Convoy_RouteRecovery_Enable` | `true` | Re-select the same unchanged final MOVE waypoint when the engine completes it prematurely while the convoy remains well outside its completion radius. Never creates a route, teleports, repairs or bypasses an obstruction. |
| `WAIT_Convoy_ContactHalt_Enable` | `true` | Automatic ambush halt using push-through and pinned rules. Route arrival and explicit stop remain available. |
| `WAIT_Convoy_Unload_Enable` | `true` | Allows WAIT passenger unloading on halt. Operating crews remain aboard. |
| `WAIT_AIPass_Danger_Enable` | `true` | Leader danger observations wake the existing squad decision job through one finite FSM; no target reveal or competing movement owner. Native danger remains active. |
| `WAIT_AIPass_DangerSmoke_Enable` | `true` | One available soldier may throw carried smoke during severe finite danger. The current operation continues without waiting for it. |
| `WAIT_AIPass_StaticSupport_Enable` | `true` | During confirmed contact, one uncommitted nonleader may physically occupy a nearby empty friendly static weapon. The squad does not wait for the mount. |
| `WAIT_AIPass_Hearing_Enable` | `true` | Nearby gunfire creates throttled approximate investigation reports, never target reveals. |
| `WAIT_AIPass_Vehicles_Enable` | `true` | BOOL: dismount under fire; damaged vehicles smoke and withdraw. |
| `WAIT_AIPass_NavalAssault_Enable` | `true` | BOOL: finite coastal boat approach and infantry landing; yields to external naval controller. |
| `WAIT_AIPass_ContactReports_Enable` | `true` | BOOL: share sightings by radio (jammable) or voice. |
| `WAIT_AIPass_ContactReports_Radius` | `500` | METRES: radio report range. |
| `WAIT_AIPass_ContactReports_VoiceRange` | `35` | METRES: report range when AI transmission is blocked. |
| `WAIT_Cortex_CombinedArms_AirRange` | `4000` | METRES: radio-linked aircraft support opportunity radius, independent of squad report range. |
| `WAIT_AIPass_ContactReports_RequireRadio` | `false` | Legacy compatibility only: AI inventory radios are no longer checked. |
| `WAIT_AIPass_Reinforce_Enable` | `true` | BOOL: idle nearby squads move up behind a squad in contact. |
| `WAIT_AIPass_Reinforce_Radius` | `600` | METRES: how far away responders may be. |
| `WAIT_AIPass_Reinforce_MaxResponders` | `2` | COUNT: responding squads per squad in contact. |
| `WAIT_AIPass_Artillery_Enable` | `false` | BOOL: squads call fire from friendly AI artillery on well-located enemies. |
| `WAIT_AIPass_Artillery_OpeningSafeDistance` | `200` | Advanced artillery ranging control. |
| `WAIT_AIPass_Artillery_OpeningBuffer` | `100` | Advanced artillery ranging control. |
| `WAIT_AIPass_Artillery_WarningInterval` | `20` | Advanced artillery ranging control. |
| `WAIT_AIPass_Artillery_Bursts` | `3` | Maximum HE bursts per mission; smoke uses one burst. |
| `WAIT_AIPass_Artillery_RoundInterval` | `2` | Minimum seconds between confirmed rounds inside one burst. |
| `WAIT_AIPass_Artillery_LocationResetDistance` | `150` | Reported movement in metres that resets opening offset and safety checks. |
| `WAIT_AIPass_CounterBattery_RadarDelay` | `20` | Counter-battery acquisition seconds with radar coverage; capped by the normal delay. |
| `WAIT_AIPass_Artillery_Rounds` | `3` | COUNT: rounds per support burst. |
| `WAIT_AIPass_Artillery_MinFriendlyDistance` | `200` | METRES: no mission near friendlies or civilians. |
| `WAIT_AIPass_Artillery_MaxError` | `50` | METRES: largest target position error accepted. |
| `WAIT_AIPass_Artillery_Cooldown` | `120` | SECONDS: between missions called by one squad. |
| `WAIT_AIPass_Artillery_ShootAndScoot` | `true` | BOOL: mobile batteries relocate after a support mission. |
| `WAIT_AIPass_Artillery_DefaultRole` | `"BOTH"` | STRING: SUPPORT, COUNTER or BOTH for guns with no role of their own. |
| `WAIT_AIPass_CounterBattery_Enable` | `false` | BOOL: AI artillery answers enemy artillery whose position is known. |
| `WAIT_AIPass_CounterBattery_Mode` | `"AUTO"` | Legacy compatibility: detection is always automatic. |
| `WAIT_AIPass_CounterBattery_RadarRange` | `8000` | METRES: radar detection range. |
| `WAIT_AIPass_CounterBattery_Delay` | `60` | SECONDS: before counter-battery fire. |
| `WAIT_AIPass_CounterBattery_Rounds` | `4` | COUNT: rounds per counter-battery burst. |
| `WAIT_AIPass_CounterBattery_MaxError` | `100` | Metres: maximum accepted spotter correction error. Automatic firing-event acquisition uses a 30 m report error. |
| `WAIT_AIPass_CounterBattery_MinFriendlyDistance` | `200` | METRES: no fire near friendlies or civilians. |
| `WAIT_AIPass_CounterBattery_Interval` | `60` | SECONDS: before the same enemy gun is answered again. |
| `WAIT_AIPass_CounterBattery_ShootAndScoot` | `true` | BOOL: mobile batteries relocate after counter-battery. |
| `WAIT_AIPass_Airborne_Enable` | `false` | BOOL: AI passengers parachute out near known enemies. |
| `WAIT_AIPass_Airborne_ApproachDistance` | `2000` | METRES: climb to jump altitude inside this range. |
| `WAIT_AIPass_Airborne_DeployDistance` | `700` | METRES: jump inside this range of a known enemy. |
| `WAIT_AIPass_Airborne_Altitude` | `250` | METRES: jump altitude above ground. |
| `WAIT_AIPass_Airborne_MinAltitude` | `120` | METRES: never jump lower than this. |
| `WAIT_AIPass_Airborne_JumpInterval` | `1` | SECONDS: between jumpers. |
| `WAIT_AIPass_Garrison_DynamicAO` | `false` | BOOL: WAIT garrison handling for Dynamic AO garrisons. |
| `WAIT_AIPass_Garrison_BreakFraction` | `0.5` | 0-1: a garrison breaks at this share of its strength. |
| `WAIT_Cortex_AttackRunFlares_Enable` | `true` | BOOL: finite countermeasure requests while eligible AI aircraft approach and leave assigned attack targets. |
| `WAIT_Cortex_AirAttack_Enable` | `true` | BOOL: finite threat-aware strafe, offset, hook, capability-gated lateral and aimed standoff attack patterns. |
| `WAIT_AIPass_AircraftFlares_Enable` | `true` | BOOL: eligible AI aircraft make a staggered countermeasure sequence after a missile warning. |
| `WAIT_AIPass_FactionProfiles` | `createHashMap` | MAP: CfgFactionClasses name to behaviour profile, for example OPF_F to ELITE. |
| `WAIT_AIPass_ZeusHoldSeconds` | `120` | SECONDS: the pass leaves a group alone this long after Zeus selects or edits it. |
| `WAIT_AIPass_Investigate_Enable` | `true` | BOOL: squads check out enemies they know about but have not seen. |
| `WAIT_AIPass_Investigate_Range` | `300` | METRES: how far away a known enemy may be to be investigated. |
| `WAIT_AIPass_Investigate_Seconds` | `60` | SECONDS: investigation time limit. |
| `WAIT_AIPass_Assault_Enable` | `true` | BOOL: paired-element clear-through after manoeuvre or directly against a fresh close threat. |
| `WAIT_AIPass_BuildingCombat_Enable` | `true` | BOOL: a capable squad may enter a usable building containing a recent native-known hostile. |
| `WAIT_AIPass_BuildingCombat_Range` | `100` | METRES: maximum range for natural hostile-building entry; explicit clearance orders are unaffected. |
| `WAIT_AIPass_Assault_Range` | `80` | METRES: maximum transition range for a final assault; fresh known contacts inside 60 m may enter the same paired-element assault directly. |
| `WAIT_AIPass_Advance_Enable` | `true` | BOOL: pinned squads with somewhere to go push a team forward in bounds. |
| `WAIT_AIPass_Advance_MinContactSeconds` | `0` | SECONDS: optional confirmed-contact delay before an advance is considered. |
| `WAIT_AIPass_Advance_Cooldown` | `20` | SECONDS: after an advance ends before the squad may start another. |
| `WAIT_AIPass_CoordinatedAssault_Enable` | `true` | BOOL: reinforcing squads assault together while the first squad fires. |
| `WAIT_AIPass_Stance_Enable` | `true` | BOOL: stance chosen from the height of the cover in front. |
| `WAIT_AIPass_AmmoShare_Enable` | `true` | BOOL: soldiers low on magazines get one from a squad-mate. |
| `WAIT_AIPass_AmmoShare_Distance` | `10` | METRES: how close the squad-mate must be. |
| `WAIT_AIPass_VehicleGunnery_Enable` | `true` | BOOL: gunners prioritise AT soldiers; armour keeps away from them. |
| `WAIT_AIPass_Vehicles_StandoffDistance` | `250` | METRES: distance armour keeps from known AT soldiers. |
| `WAIT_AIPass_ArtillerySmoke_Enable` | `true` | BOOL: a retreating squad gets an artillery smoke screen (needs Artillery). |
| `WAIT_AIPass_AircraftBreak_Enable` | `true` | BOOL: eligible AI aircraft preserve forward energy while making a bounded break from missile launches. |


## Behaviour profile map

WAIT_AIPass_ProfileBehaviour has these defaults. Preference values are weighted by aggression and eligibility. A zero value opts out. A positive investigation preference scales accepted search range without randomly withholding an otherwise viable search; assault preference controls optional grenade preparation.

```sqf
            ["MILITIA", createHashMapFromArray [["flankChance", 0.3], ["assaultChance", 0.2], ["advanceChance", 0.7], ["investigateChance", 0.4], ["coordinatedChance", 0.2], ["moraleShaken", 0.65], ["moraleBroken", 0.4], ["retreatScale", 1.5], ["surrenderSurvivors", 3]]],
            ["LINE", createHashMapFromArray [["flankChance", 0.5], ["assaultChance", 0.4], ["advanceChance", 0.6], ["investigateChance", 0.6], ["coordinatedChance", 0.4], ["moraleShaken", 0.55], ["moraleBroken", 0.3], ["retreatScale", 1], ["surrenderSurvivors", 2]]],
            ["LEGACY", createHashMapFromArray [["flankChance", 0.5], ["assaultChance", 0.4], ["advanceChance", 0.6], ["investigateChance", 0.6], ["coordinatedChance", 0.4], ["moraleShaken", 0.55], ["moraleBroken", 0.3], ["retreatScale", 1], ["surrenderSurvivors", 2]]],
            ["VETERAN", createHashMapFromArray [["flankChance", 0.7], ["assaultChance", 0.55], ["advanceChance", 0.5], ["investigateChance", 0.75], ["coordinatedChance", 0.5], ["moraleShaken", 0.45], ["moraleBroken", 0.22], ["retreatScale", 0.8], ["surrenderSurvivors", 1]]],
            ["ELITE", createHashMapFromArray [["flankChance", 0.9], ["assaultChance", 0.7], ["advanceChance", 0.4], ["investigateChance", 0.85], ["coordinatedChance", 0.6], ["moraleShaken", 0.4], ["moraleBroken", 0.18], ["retreatScale", 0.7], ["surrenderSurvivors", 1]]]
```

WAIT_AI_ProfileDisplayNames: LEGACY = Existing Mission Balance; MILITIA = WAIT Militia; LINE = WAIT Line; VETERAN = WAIT Veteran; ELITE = WAIT Elite.

The table includes all single-line shared settings. The two multiline maps are documented above.

| `WAIT_Convoy_DefaultSpeed` | `30` | Maximum km/h for new native Zeus convoy orders; existing registrations retain their speed. |
| `WAIT_Convoy_DefaultSeparation` | `30` | Centre separation in metres for new native orders; vehicle length may increase the minimum. |
| `WAIT_Convoy_DefaultPushThrough` | `true` | New convoy contact policy; existing registrations retain their selected policy. |

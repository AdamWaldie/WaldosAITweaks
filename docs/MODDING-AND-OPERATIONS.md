# Mod build, testing and architecture

WAIT requires Arma 3 2.18+ and CBA; ZEN is optional. Other controllers are optional. WAIT configures a
bounded engine danger FSM for base soldier classes; packaged physical and compatibility acceptance remains pending.

## Change validation and local deployment

Use Python 3.11+ and HEMTT **1.22.0**. The modern project definition is `.hemtt/project.toml`.
The checked-in `build_mod.ps1` runs the regression suite, SQF validation, feature wiring check and
HEMTT package build sequentially, then writes `wait-build.json` inside the output folder.

```powershell
./releaseVerificationAndDeployment/build_mod.ps1 -Hemtt C:/Tools/hemtt.exe -Python python
./releaseVerificationAndDeployment/launch_mod_audit.ps1 -Focus airskills -StageOnly
./releaseVerificationAndDeployment/launch_mod_audit.ps1 -Focus supportflows
python releaseVerificationAndDeployment/report_cortex_audit.py .qa/runtime-YYYYMMDD-HHMMSS-fff
```

The default output is `.hemttout/build`. The addon currently contains scripts, config and an FSM;
`--no-bin` keeps builds portable while HEMTT still rapifies the addon config. Add model, animation
or terrain assets only with the corresponding binarization step restored and verified.

Each audit receives its own `@WaldosAITweaks` folder, mission, profiles, manifest and RPT directory.
The launcher verifies every packaged file before staging. It uses a dedicated server, an interface
client, two optional headless clients, `-noBattlEye`, no file patching and a 3840x2160 client profile.
Dependencies default to the installed CBA folder; `-WithZen` adds the optional dialog provider; `-Mods` accepts an explicit
array for compatibility batches. `-Package` also accepts a signed release candidate folder.
An existing Arma session prevents another launch. Processes are left available for inspection.

Join the observer slot and press OK. Confirm VR mission entry, WAIT initialization and matching
package fingerprints in the server/client RPTs. Server readiness or a lobby alone does not establish
successful entry. The observer is protected; combat actors retain each suite's authored setup.
The retained movement diagnostics and live-battle suites have separate purposes. A diagnostic with
invulnerable actors cannot establish casualty handling or combat effectiveness.

The launcher stages every retained suite. `terrain` requires real relief and fails its fixture
prerequisite in VR; use a terrain-specific mission before accepting terrain coverage. The current
standalone mission does not certify JIP, HC disconnect or every optional dependency combination.
Those variants remain explicitly pending in `cortexQA/coverage.json`.

## Change and release pipelines

| Pipeline | Trigger | Output and gate |
| --- | --- | --- |
| `testing.yml` | Push or PR | Regression, SQF, feature wiring and HEMTT checks; installable PBO artifact with build manifest |
| `candidate.yml` | Manual dispatch on the intended release commit | Signed PBOs, public key and manifest in `wait-candidate.zip` |
| Local packaged audit | One requested batch | RPT evidence, physical outcomes and `cortex-results.json` |
| `deploy.yml` | GitHub release published | Promotes the exact tested candidate after complete passing evidence, accepted feature coverage, fingerprint, clean commit, version and cryptographic signature checks |

Download the signed candidate, extract it locally, and pass that folder through `-Package`. Do not
rebuild between acceptance and publication: signatures are part of the package fingerprint. Attach
`wait-candidate.zip` and the matching `cortex-results.json` to the draft GitHub release, then publish
the release with tag `vMAJOR.MINOR.PATCH`. The workflow uploads the installable versioned archive.
GitHub runners provide packaging checks; they do not run licensed Arma clients or establish combat
acceptance. Steam Workshop publication remains a separate operator action.
Every feature remains marked `implemented_partial` today, so the public release gate intentionally
remains closed until the recorded acceptance work is completed.

Use HEMTT `utils verify` on each PBO and its candidate public key when inspecting a signed candidate.
Preserve keys and signatures for server signature verification. Never distribute private keys.

## Execution method assessment

FSM performance depends on its trigger cadence and state costs. Engine danger FSM integration lets
reaction work follow engine danger causes. Scripted FSM state code can execute unscheduled, so
expensive work there can evade the shared budget. WAIT's finite tactical FSM queues its existing
step through the budgeted scheduler and observes completion/locality. It never runs route scans
directly from a per-frame condition. This change needs a live A/B measurement.

### Engine feasibility boundary

The design is viable, but WAIT must cooperate with Arma's planners instead of continuously replacing
their work. The engine supports a configured soldier danger FSM, finite scripted FSMs, owner-local
movement, suppression, building positions, land-vehicle paths, artillery orders and vehicle weapon
release. Those are sufficient for event-driven danger response and finite operations.

The engine also defines strict boundaries which WAIT treats as acceptance rules:

- A danger FSM interrupts the formation FSM. It must finish regularly and cannot become a second
  persistent movement brain.
- `setDestination` forces a replan. A healthy operation therefore issues one committed movement
  command and retries only after measured physical no-progress.
- Disabling `PATH` or `MOVE` stops navigation and has locality-sensitive effects. WAIT uses no such
  lease for ordinary manoeuvre; a terminal garrison hold may use exact-owned `PATH` state and must
  release it on interruption or ownership change.
- `setDriveOnPath` applies only to compatible land vehicles and any other move command or `doStop`
  cancels it. Convoy phases must have one movement owner and aircraft cannot use this controller.
- Building positions are destinations, not a supplied room-connectivity graph. Clearance must prove
  physical visits, retry another entrance or actor, and report unreachable rooms as `INCOMPLETE`.
- Vehicle fire commands do not supply aiming by themselves. Aircraft and turret operations must first
  prove a compatible loaded weapon, native target/aim solution and valid release geometry; elapsed
  time or an issued fire command is not a hit.
- Path calculation is advisory, segmented and may report duplicate callbacks. It can score a bounded
  route candidate but cannot be treated as proof that an actor will traverse it.

This makes perfect navigation and guaranteed weapon impact invalid product promises. WAIT's contract
is prompt finite intent, bounded recovery, clean handover and measured physical outcomes. Native
failure remains visible rather than being hidden by teleportation, forced projectiles or fabricated
completion.

| Domain | Preferred method | Conversion and acceptance decision |
| --- | --- | --- |
| Immediate danger and contact | Engine danger FSM with small owner-local decisions | Bounded intake is configured for base soldiers; promote behaviour only after movement, disable, locality, external-owner and Zeus handover tests |
| Squad tactics and combined arms | Event-fed shared opportunity registry, budgeted decisions, finite leases | Keep communication opportunistic; no compulsory rally or assembly barrier; casualty replacements update roles without restarting the whole attack |
| CQB and garrison | Cached building topology and engine navigation; finite team movement | Native WAIT task implementation remains the standalone path. Validate rooms, floors, doorway traversal and exit across different buildings before replacing the fallback |
| Turret and launcher policy | Config where supported, owner-local skills for runtime settings | Config cannot be reversed by a CBA toggle. Any new config component must document that distinction and avoid stacking installed external AI controller companion changes |
| Vehicle driving | Native route commands plus sparse progress/obstruction events | Use sparse route-memory and obstruction sampling; preserve intentional roadblocks, crew ownership and Zeus orders; recovery cannot teleport, repair or remove obstacles |
| Air combat | Native flight, weapon-config capabilities and sparse finite attack intent | Match weapon, envelope and terrain clearance; aircraft own aiming and actual ordnance. Avoid fixed-angle projectile creation or repeated short steering points |
| Civilians and specialist actors | Local danger events and explicit external ownership | Externally owned animations and combat retain their actors; WAIT yields instead of layering a competing tactical controller |
| Skills, lighting and dispersion | CBA settings plus equipment/locality events and cached profiles | Avoid rescanning every unit every frame; preserve WAIT authored skill values where ownership is delegated |

Retain feature gates, intent, locality, cancellation, casualty continuation and diagnostics through
every conversion. Measure native AI, WAIT fallback, and relevant external-mod handover separately.
The agreed initial budget is <=5% added median and <=10% added p95 frame time, starting with 50
mixed groups. Protect the observer throughout measurement and record server and client separately.
An isolated fast showcase is insufficient evidence for scale.

## Source references

- [Bohemia: creating an addon](https://community.bohemia.net/wiki/Arma_3%3A_Creating_an_Addon): mod folders, PBOs, config, keys and addon tools.
- [Bohemia: FSM](https://community.bohemia.net/wiki/FSM) and [execFSM](https://community.bohemia.net/wiki/execFSM): state execution and scripted lifecycle semantics.
- [Bohemia: doMove](https://community.bohemia.net/wiki/doMove), [expectedDestination](https://community.bohemia.net/wiki/expectedDestination) and [disableAI](https://community.bohemia.net/wiki/disableAI): native movement planning, forced replans and movement-feature ownership.
- [Bohemia: setDriveOnPath](https://community.bohemia.net/wiki/setDriveOnPath) and [AI car steering](https://community.bohemia.net/wiki/Arma_3%3A_AICarSteeringComponent): compatible land-vehicle path control and cancellation semantics.
- [Bohemia: buildingPos](https://community.bohemia.net/wiki/buildingPos) and [calculatePath](https://community.bohemia.net/wiki/calculatePath): building destinations and advisory path calculation limits.
- [Bohemia: fireAtTarget](https://community.bohemia.net/wiki/fireAtTarget), [forceWeaponFire](https://community.bohemia.net/wiki/forceWeaponFire) and [targeting configuration](https://community.bohemia.net/wiki/A3_Targeting_config_reference): weapon ownership, aiming and release constraints.
- [HEMTT configuration](https://hemtt.dev/configuration/index.html), [version](https://hemtt.dev/configuration/version.html), [build](https://hemtt.dev/commands/build.html) and [release](https://hemtt.dev/commands/release.html): project layout, package outputs and signing.
- [CBA settings implementation](https://github.com/CBATeam/CBA_A3/blob/master/addons/settings/fnc_addSetting.sqf): global settings and callback contract.
- WAIT local `releaseVerificationAndDeployment/launch_pr_review_audit.ps1`, `testing.yml` and `deploy.yml`: fresh staging, readiness, dedicated/client operation and published-release flow examined for this pipeline.

These references guide original implementation. Existing compatibility detection does not mean a
Workshop feature has been recreated or that its physical behaviour passes WAIT acceptance.

## Source and documentation gates

The local build and both build/candidate workflows enforce SQF validation for production and audit helpers, config structure, opening source-header contracts, local documentation/image links, shared CBA/Zeus/script setting parity and recurring performance risks. HEMTT compiles and lints addon SQF/config; its warnings remain visible for review. The static performance scanner rejects new high-severity patterns and starts with no accepted exceptions. It does not measure frame time.

See [contribution requirements](../CONTRIBUTING.md) for feature guides, PR evidence and multiplayer acceptance. [The settings reference](SETTINGS-REFERENCE.md) is generated from the live tuning specification. Run `python releaseVerificationAndDeployment/zeus_script_parity_checker.py --write-reference` after editing that specification. CI rejects a stale reference, duplicate keys, invalid defaults or missing function exports.

The GitHub wiki is generated from `docs/` by `releaseVerificationAndDeployment/wiki_sync.py`. Each guide becomes a page of the same name, the README becomes **Overview**, and [`docs/wiki/Home.md`](wiki/Home.md) is the custom wiki home page. Local links are rewritten to wiki pages, or to repository files the wiki does not carry. The build gates run `wiki_sync.py check`, which fails on a broken wiki-internal link and warns about absolute wiki links to pages that do not exist. After a push to `main` that changes the docs, the **Publish wiki** workflow replaces the wiki contents, so direct wiki edits are overwritten. Add a new guide to the sidebar sections in `wiki_sync.py`; until then it is listed under **More guides**.

After approval to close a batch, use `stop_mod_audit.ps1 -Runtime <runtime folder>`. It validates every recorded process against the selected batch, force-terminates matching client/server/HC processes, waits for exit and writes `shutdown.json` only after no matching process remains. Do not treat closing a window or a completed report as process termination. The launcher already refuses a new live batch while any Arma process is running.

### Clearance release and replacement actor movement

Explicit clearance release restores formation only when an actor has no live MOVE or its destination still matches the clearance job receipt within 0.25 m. A newer individual MOVE is preserved; unchanged clearance speed and posture leases can still be released. If the job receipt is missing, a live MOVE is not presumed owned. This guard has static validation only; dedicated normal and headless-client handover retests remain pending while audits are paused.

### Combined ground-fire operator readiness

Direct ground-fire support and the ground maneuver arrival firing branch require a combat-effective local gunner, in addition to combat-mode, player/external ownership and clear-fire-lane checks. An incapacitated gunner returns `NO_FIRE_OPERATOR` through the existing provider rejection path. This change requires a live casualty/provider-fallback retest; audits remain paused.

### Passenger cover reservation scope

Passenger dismount cover selection excludes destinations only from the matching convoy group and configuration revision while their deadline is live. Historical destinations cannot consume current cover slots. Existing and newly selected current destinations remain excluded within the bounded two-search step. Concurrent-owner selection and physical spacing still require live validation.

### Passenger-owner post-exit continuation

The finite remote passenger-owner HALT job retains on-foot actors with the matching convoy/revision unload receipt. This lets cover steps continue after physical exit instead of filtering the actor out as soon as boarding ends. New vehicle assignments and external orders remain protected. Separate-HC exit/cover and concurrent-owner spacing retests remain pending.

### Sliced passenger cover exclusions

Separate passenger-owner retries process a bounded actor slice but pass the full cargo roster separately for read-only destination exclusions. Existing live reservations outside the current slice remain visible. This does not serialize simultaneous selection across owners; that race remains unverified and requires a separate design and live audit.

### Passenger cover cleanup ownership

Passenger cover cleanup recalls an eligible MOVE/STOP only when the expected destination matches the recorded cover destination within 0.25 m in 3D. A newer nearby destination is not owned merely because it lies within two horizontal metres of the former cover point. Live nearby-order handover validation remains pending.

### CQB reserve staging search budget

A building step starts at most one pending reserve stage selection per callback. Other reserves do not consume their attempt until processed; all existing stages retain arrival checks and casualty promotion remains independent. Staging search direction and screening use the building horizontal bounds centre, avoiding assumptions about model origins. The fixed fan is replaced by bounded nearby cover selection with shared destinations of other currently eligible reserves, exterior bounds and at least three metres of primary-entry clearance plus proximity exclusion around every configured same-floor exit. This is not proof of clear route traffic. Rejected candidates retain an explicit current-position hold; rejected selection retries after five seconds with at most three searches per reserve and previously selected candidates excluded. A still-owned native approach retires after sixty seconds without arrival and may select an alternate within the same three-search cap. Exhausted approaches retain a safe hold; local path recovery beyond alternate selection remains unfinished. Physical staging and runtime performance are unvalidated.

### Reserve stage evidence

Owner-local reserve stage receipts distinguish `REJECTED` current-position holds from `APPROACH` and physically verified `ARRIVED`. The hold flag alone is not stage success. This diagnostic distinction does not add a network polling loop or establish tactical security; stage recovery and live acceptance remain pending.

### Reserve search budget replay

A bounded public array journal preserves reserve search consumption and tried candidates across a true clearance resume. It is keyed to the target building, original hard deadline and transform; explicit new clearance clears it. Journal publication occurs only when content changes under current movement authority. An exhausted budget cannot start another search after adoption. Active reserve approaches adopt bookkeeping only when the recorded episode/transform and exact live MOVE destination still match. No movement request is reissued. Retry and approach deadlines use serverTime and survive adoption. Held reserve stages additionally require a live STOP with the exact recorded destination and current 3D/floor proximity before bookkeeping adoption. This preserves rejected retry delays and exhausted status without replaying movement. Interior worker reconstruction and physical HC validation remain incomplete.

### Terminal reserve evidence

Clearance terminal route evidence includes clearing/security actors, capped at sixteen, and appends up to sixteen reserve stage records with consumed search counts. Existing result/reason indices remain unchanged. This preserves rejected/approaching/arrived/exhausted distinctions alongside actual actor positions before cleanup, without adding geometry work or recurring logging. These records support diagnosis and do not prove tactical security.

### Reserve route reachability

Stage endpoints require dry usable slope, standing-space geometry and exterior/exit clearance. A straight observer-to-endpoint ray is not a route prerequisite: native pathfinding may go around an obstacle. The finite owned approach and physical arrival receipt determine success; timeout can select a bounded alternate. No endpoint check claims native route feasibility. Corner-routing behavior still needs live acceptance.

### Grenade release orientation evidence

The one-shot native grenade release trace appends actor position, body/view bearings and target errors, view availability, stance and animation state at FiredMan release. Existing launch/contact fields retain their indices. Command-time alignment and actual release orientation can now be compared; no actor direction or projectile velocity is changed. The reported opposite-contact throws still require live provenance-matched investigation.

### Controlled smoke direction audit

The `grenades` focus stages twelve fresh server-owned smoke cases: standing/crouched/prone and four cardinal target bearings. Each case requires stance, a queued real helper request and an actual nonzero projectile launch vector within thirty degrees of the requested bearing. Missing release/direction fails. Cases use separate origins and delete observed projectiles only after recording launch evidence, limiting cross-case smoke contamination. Flight/impact and smoke delivery are outside this launch-only fixture. This isolated fixture has no hostile actors; it does not validate contact selection, fragmentation, native controls or HC migration. It is unrun while audits are paused.

### Aircraft pilot readiness

Aircraft attack planning, command admission and airborne checks require the shared combat-effective pilot predicate. Alive unconscious, incapacitated or captive pilots cannot start new attack work. Native aircraft command boundaries also re-read aircraft survival, current pilot effectiveness, active/pause state and flight-lease validity. Existing locality, player/Zeus and external ownership gates remain in force. Pilot incapacitation/recovery and cleanup across airborne ownership changes still require physical acceptance.

Active clearance arrests native formation fallback once per committed actor request when the command is empty. Both `DoNotPlanFormation` and `FORMATION PLANNED` are recognized. Current generation, owner and order checks remain in force; explicit FOLLOW, newer MOVE and specialist tasks are preserved. This hold neither grants a room visit nor resets retry budgets. The existing finite room recovery supplies subsequent movement. A normal live audit exposed the previously missed planned formation state; physical validation of this correction and HC validation remain pending.

Clearance egress assigns distinct exterior destinations rather than one shared endpoint per exit. Each actor considers at most twelve nearby slots, separated by at least three metres, requiring dry ground, usable slope and standing clearance. Arrival requires one metre horizontal proximity on the destination floor. Missing slots retain an incomplete result. This removes the shared-endpoint cause of the reported post-CQB pile; physical separation, obstacle routing and HC acceptance remain pending.

Normal-owner repeatability acceptance now repeats clearance with the same two- and six-person squads after ordinary waypoint movement. No cleanup, teleport or actor reset precedes the second episode. A new generation, fresh independently observed room visits by every member and COMPLETE settlement are required. This case is added but unrun; sustained multi-building flow, live combat and separate HC repeatability remain outstanding.

Alternate entrance recovery checks the assigned actor's own physical entry receipt instead of the pair-wide entry flag. An exterior mover can therefore try remaining native entrances even after its buddy entered. During that approach, already-entered partners retain their interior movement/hold; recovery never rallies them outside. Existing entrance history, finite retries and episode deadline remain. The six-person repeat exposed this admission gap; physical validation of the correction is pending.

Room handoff preserves an exact matching active native movement request: if the actor's current MOVE still matches its owned destination and that destination is unchanged, the next pair room claim does not resend it. This especially protects a partner still approaching the same entry point while its lead advances. A changed target and the existing finite no-progress recovery still issue normally. No visit is inferred from planning or movement; physical validation remains pending.

The one-time formation fallback hold does not wait for unitReady: a live trace showed an entered actor already following a FORMATION PLANNED route out of the house with an empty command while still busy. The exact owned generation/order checks and per-request hold limit remain. Explicit FOLLOW and MOVE are excluded. Physical validation of this refinement is pending.

A compact terminal CQB diagnostic records entry/egress failure flags, bounded per-actor visit counts and exit receipts before cleanup. It disambiguates an INCOMPLETE result with full shared room coverage without relying on truncated route traces. Diagnostics cannot grant or modify acceptance.

Exit-slot selection rejects destinations already claimed by another worker, wet ground and unusable slopes before standing-clearance geometry. It retains the twelve-candidate cap and identical acceptance constraints, avoiding repeated rays for slots that cannot be selected. This is a source-level cost reduction; the full median/p95 performance budget still needs measured acceptance.

A modded building's reported interior position may lack a native accessible route. Finite lane/entrance retries retain room-specific failedBy/unreachable evidence and unresolved coverage remains INCOMPLETE. Common CLEAR recovery therefore expires a failed destination observation without quarantining the otherwise capable soldier: it can attempt another room through normal bounded commands. Its generation-wide recovery budget is not renewed. Casualty and external-owner exclusions remain active. No model blacklist, teleport, invented point or inaccessible-room success is introduced; physical invalid-node and mixed reachable/unreachable building acceptance remain pending.

Interior follow-through can retire a failed native room target after its measured no-progress recovery window and try another reported room point. Each actor retains failed target indices and may retire at most three; candidate ranking is capped at twenty-four. Real visits and the common generation-wide recovery budget are preserved. Exhausted alternatives or the immutable episode deadline retain INCOMPLETE; changing targets cannot manufacture progression. Physical inaccessible-point and repeat-clearance validation remain pending.

A room handoff that changes the mover to an already-entered buddy cancels the pair's pending entrance staging leg. The successor continues interior progression instead of inheriting an exterior actor's approach. Only a prior physical room receipt permits this cancellation; entrance proximity grants no entry. Physical handoff and locality replay acceptance remain pending.

Failed follow-through target limits survive true ownership resume in a compact public journal updated only on target retirement or exhaustion. Replay requires the same building, transform and original hard deadline, accepts at most sixty-four actor rows with up to three valid room indices, and restores only failure bookkeeping for the same actor IDs. It grants no visits and issues no movement. New clearance, explicit release and terminal cleanup discard the journal. Separate two-HC physical replay acceptance remains pending.

Physically visited destination-floor access takes priority over cached geometry-only floor connectors. The connector fallback no longer replaces an established access checkpoint with an exterior current-floor detour. This uses existing bounded room coverage, introduces no extra geometry scans or movement writer, and preserves finite retries, unresolved-point INCOMPLETE results and immediate newer-order cancellation. Physical multi-storey retest remains pending.

When bounded recovery exhausts an interior access checkpoint, CLEAR retires that checkpoint once and attempts the assigned room directly before recording a pair failure for that room. A claim-scoped tombstone prevents rebuilding the failed leg. Durable retry counts, recovery budgets and hard deadlines remain unchanged; no visit is inferred. This addresses observed room classification while the actual failed request was a different access node. Physical retest remains pending.

Floor connector source selection now ranks up to twenty-four physically visited current-floor room points ahead of thirty-two raw transit candidates. Source-specific cache keys prevent reusing an exterior source after interior access is established. The eight-record geometry budget remains unchanged; this selection runs only when constructing a changed room approach. Destination-floor access already physically visited still has priority. A proven source does not prove the floor connection, and all arrival, finite recovery and incomplete-result gates remain. Physical retest pending.

CLEAR records its first entry-failure cause once per operation: stranded worker, exhausted follow-through or missing sweep participation. The record includes the actor or bounded sixteen-actor physical participation snapshot at the decision boundary and is appended to terminal diagnostics. It adds no geometry query or recurring log and does not clear failure history or alter completion. This is needed to diagnose an observed repeated six-person INCOMPLETE result despite later full coverage, participation and egress. Fresh physical diagnostic replay pending.

Partner entry recovery no longer requires a previously cached support-entry target. It initializes a missing target from the lane anchor before tracking the unentered partner. This removes a gate that could leave an exterior partner without any recovery receipt when entrance handling preceded support selection. Existing owner/service guards, measured no-progress window, one-shot recovery and shared deadline remain. Fresh physical replay is pending; the observed missing receipts do not alone prove this was the only entry failure cause.

When a single casualty replacement is still outside and its surviving buddy has physically entered, the survivor retains the mover role. The replacement joins through existing bounded partner-entry recovery rather than inheriting the removed actor's current interior leg. Whole-pair exterior reset, shared room coverage, retry counts, hard deadlines and newer-order authority remain unchanged. Selection uses the existing pair roster only. Repeated single-replacement entry failures motivated this correction; fresh physical validation remains pending.

The single-replacement role rule also covers casualties before entry: if neither actor has entered, a healthy original buddy retains the mover role while the reserve follows partner entry. Entered survivors remain preferred. A wholly replaced lane has no original survivor and keeps its exterior reset. This extends the earlier entered-survivor correction to the actual early-casualty audit trigger; fresh physical acceptance remains pending.

CONTACT continuation now includes the matching live owner/generation CLEAR operation and uncancelled building brain. Loss of sight therefore cannot advance contact cleanup over clearance's movement and autonomous-attack lease. CLEAR still ends through its existing finite deadlines, physical result or immediate replacement/Zeus cancellation; contact cleanup resumes after that owner is gone. This closes a source-level continuation gap found while diagnosing native ATTACK diversion. Physical causality and repair remain pending.

An exterior partner whose one-shot entry recovery has made no approach progress for twenty-four seconds may select one different physically visited current-floor point before full shared room coverage. Selection examines at most twenty-four proven points within thirty metres and stores one public building/hard-deadline/transform receipt per actor, including failed selection, so locality replay cannot replenish this alternative. The same guarded owner-local clearance callback records the shared pair target before issuing movement, including when that pair's room queue has ended. Later pair steps preserve the matching active path; no independent movement worker is added. Changing the target resets its distance baseline but does not renew the progress timestamp, deadline or common recovery budget. No visit is inferred. This addresses partners waiting outside while one unrelated room blocks the later full-coverage follow-through stage; fresh physical validation is pending.

### Friendly infantry around moving vehicles

Ordinary driving assistance now applies the shared friendly-pedestrian speed observer under `WAIT_AIPass_DrivingAssist_Enable`. Registered convoys retain their separate, default-off `WAIT_Convoy_AvoidInfantry_Enable` option. The existing owner-local operation applies the result after other lower speed caps; no additional movement controller is started. Pedestrian constraints use the existing traffic phase and suppress stuck recovery. Player, Zeus and external-controller handovers retain the driving operation's authority checks.

The observer projects pedestrian hull corners into the vehicle frame, checks lateral and vertical overlap, and measures clearance from the front or rear hull according to actual travel direction. A continuous braking envelope includes a provisional four-second response allowance and mass-adjusted deceleration. Occupied near-hull space requests zero immediately; there is no minimum crawl or small-change filter that can discard a stop. Each observation evaluates at most 32 pedestrian hulls within a speed-dependent radius capped at 250 metres; denser sets request a stop. It retains no clearance cache, handlers or JIP side effects.

This is not crossing prediction, a steering avoidance manoeuvre or proof of collision prevention. Native braking, fast lateral crossings, turning swept hulls, reversing from rest, slopes/bridges, crowd response, repeated restart and locality migration require physical validation. Audits are currently held; performance acceptance remains unmeasured.

Ordinary forward traffic observation also admits occupied vehicle hulls at any heading, including sideways parked vehicles and destroyed vehicle entities. Only aligned, non-reversing predecessors receive a measured forward-speed allowance. Other hulls overlapping the forward lane and vertical corridor are treated as stationary occupied space for the speed ceiling; a centre behind the bumper does not hide a protruding hull. Existing candidate limits, traffic wait/recovery suppression and ownership cleanup remain. This does not predict a crossing before it enters the lane, choose right-of-way, route around wrecks, or guarantee stopping against an approaching vehicle. Those behaviours and physical angled-obstacle tests remain outstanding.

Convoy driving assist now applies the same forward-lane hull observer to the lead and every follower on the existing one-second convoy tick. The exact registered predecessor retains the configured size-aware convoy pacing only while alive, aligned within 25 degrees and not reversing along the follower's forward axis. Its hull is still observed: contact-range bumper room below two metres stops the follower; a turned, reversing or destroyed predecessor receives ordinary occupied-hull constraints. Crossing predictions still apply. Other vehicles and wrecks remain obstacles. This adds at most one predecessor hull evaluation within the existing 64-candidate limit, with no new query or scheduler. Physical cornering, mixed-hull braking and stopping-distance acceptance remain unverified. These caps apply after acceleration/spacing smoothing and before the existing speed writer. Observed traffic and zero-speed holds refresh progress timers and suppress stuck recovery, preventing an immediate stale retry when the road clears. Disabling `WAIT_Convoy_DrivingAssist_Enable` removes this observation along with its road/path assistance; convoy spacing and the separate opt-in pedestrian check retain their own scope.

Cost is at most one area query and 64 eight-corner hull projections per convoy vehicle per tick, with a 250 m query-radius cap and a maximum 20 registered vehicles. This bounded cost has not been measured against the frame-time budget. Physical tests must cover unrelated parked and angled obstacles, wrecks, release/restart, configured short gaps, mixed tracked/wheeled braking, bends where other convoy hulls intersect, and HC migration. No crossing priority, passing or timeout-based permission to drive through the blockage is introduced.

Convoy unload policy now has its own exact lease: controlling group, accepted revision, previous policy, applied policy and machine owner. Startup and five-second crew upkeep call the same owner-local helper. Unchanged leases are adopted across revisions and migration without repeating the engine write. If a script changes the current policy, WAIT retires its lease and blocks reacquisition for that convoy group until explicit release; HALT/resume does not override the change. Release restores the locally captured previous policy only when the lease still belongs to that group, its applied value remains current and no player/Zeus/external controller owns the handover. A missing lease does not authorize restoration from the older server snapshot. Successor-retained vehicles keep their lease. No settings, handlers or new recurring jobs are added. Live script mutation, release/re-register, successor retention and HC migration still require physical verification.

A physically arrived clearance reserve installs its exit watch only in the callback where its actual eye-to-watch VIEW ray succeeds. A staging-point proposal ray, arrival flag or earlier owner's watch receipt cannot substitute for that check. The existing oldest-due rotation and one-ray-per-callback budget remain; newly arrived or adopted observers wait for their turn. Persistent blocked views retain the existing finite search/reposition budget, and no watch creates room-clearance credit. Physical outside-security, occlusion, casualty and HC validation remain pending while audits are held.

Casualty promotion recognizes physically settled early-exit clearing workers as potential substitutes for an established reserve's doorway watch. Both kinds of substitute must still hold the same exit with current generation/owner watch receipts, remain physically at their post, be available and pass a fresh actual-eye VIEW check. An approaching, diverted or unavailable worker cannot supply cover. A rotated observer roster avoids repeatedly spending the shared one-ray budget on the same blocked first post; at most sixteen reserves and eight early-exit records are considered. This adds no movement writer, ray budget or deadline renewal. If no real substitute exists, the established watch remains protected. Physical casualty flow, blocked views and separate HC validation remain pending.

Natural contact clearance opts into `continueRoute`: only a COMPLETE result with successful participation and egress may return settled actors to their unchanged plain authored MOVE after the common clearance operation releases. Explicit clearance defaults to settlement; scripts may request the typed BOOL option `continueRoute` (default false). The choice persists through room-progress publication and owner resume; older receipts default false. The owner rechecks generation, current brain, unchanged authored metadata, no successor operation, task availability and each actor's actual STOP before handback. The leader must qualify before followers rejoin it. New individual movement, scripted/timed/synchronized/attached routes, missing routes and incomplete results retain their current orders/holds. No waypoint or behaviour/ROE is rewritten, and room visitation does not prove hostiles eliminated. Physical route continuation, combat response, repeat clearance and separate HC cases remain unverified while audits are held.

The building audit retains the original no-route natural-entry case and adds a separate `BUILD-CONTINUE` controller-flow case. One plain patrol waypoint is established before contact. Native knowledge must trigger clearance and independent physical entry before the posted defender becomes vulnerable to real gunfire. A pass additionally requires independently observed visits to all roofed fixture room targets, a real squad-caused casualty, COMPLETE clearance, every living on-foot member travelling at least 25 metres with at least 20 metres of progress toward the unchanged waypoint, and retained authored route identity. No later test-side movement, route replacement or completion assignment assists the handback. Protected attackers mean this does not validate combat effectiveness. The case is prepared but unrun; normal and HC acceptance remain separate.

Terminal clearance clears an observation command only when the actor carries the matching public and local exit-watch receipt for that clearance generation and owner epoch. Interior workers without that receipt are no longer sent a blanket `doWatch objNull`. Existing movement diversion, native-task and external-owner guards still apply; stale watch metadata retires separately. An external script changing an identical watch without replacing an ownership receipt remains indistinguishable to this lease protocol. Physical newer-watch and owner-transition validation remain pending.

Ordinary-driving assistance includes finite static-obstacle bypass and navigation-area passage while retaining the authored waypoint. This does not implement moving-vehicle overtaking or cooperative jam clearance: stopped peers remain occupied hulls, and existing finite native-route retries do not authorize another group to back up. A future cooperative manoeuvre must be admitted by each current owner, preserve route/seat/command receipts, retain fresh physical clearance, and end on expiry or a newer order. Public peer requests alone cannot grant movement authority. These gaps remain unaccepted while physical audits are held.

Prepared normal-convoy corner acceptance now requires a measured turning/closing predecessor encounter, physical speed reduction of at least 1 m/s within eight seconds of the first such event, sampled hull separation without new damage, and all vehicles physically reaching the outgoing leg. A route that never produces the encounter fails the prerequisite instead of passing the braking check. No added fixture movement or direct production callback supplies these results. The observer uses two eight-corner projections at 5 Hz for at most 150 seconds and is not a performance measurement arm. Sampling can miss contacts; zero damage alone does not prove collision freedom. This case is unrun; headless acceptance remains separate.

Finite danger-cover movement now binds its owner epoch, operation generation and full authored native waypoint receipt. A same-index condition, script, attachment or synchronization edit invalidates continuation and return-to-formation cleanup; legacy leases lacking that proof retire metadata only. A new nearby danger observation can retain an unchanged screened route without extending its deadline. The final new move and failed-approach return recheck the order context. This adds authored-route metadata reads on existing cover callbacks, not a new timer or world scan; route enumeration cost still depends on mission waypoint count. Physical route edits, actor interruption and locality handover remain unrun while audits are held.

Shared direct/suppressive-fire protection now queries the complete target corridor instead of a shooter-centred search truncated at 600 metres. A single rectangular area includes live people inside vehicles, then the existing ASL cone projection checks friendly, civilian and protected-captive positions. The shooter's own platform and occupants are excluded. Non-finite/malformed targets, spans above 6000 metres and more than 64 native query candidates refuse fire rather than ignore part of the corridor. No recurring scan or weapon/movement writer is added; native area-query cost remains engine-dependent. This position-based veto does not establish blast, hull, penetration or future-motion safety, and does not authorize destructive building fire. Long-range, mounted-protected-person, steep-terrain and dense-scene physical acceptance remain unrun while audits are held.

Alternate driving-path admission now requires both driver and effective commander to be idle or executing a native MOVE to the current authored destination. Native STOP, FOLLOW, ATTACK and unowned WAIT cannot start a static bypass or navigation-corridor approach. Bypass PLAN rechecks this before fixed steering; corridor APPROACH rejects a new STOP or other non-movement task before CROSS. The owned FOLLOW/CROSS phases retain their intentional two-seat `doStop` contract, so this is not a blanket STOP veto. A later external STOP indistinguishable from that owned STOP remains unresolved. Separate-commander native destination propagation, real path acquisition, interruption and handback require physical testing. No timer, query or movement writer was added.

Native driving-path curvature hints now refuse multiple disconnected path stretches within the current three-metre/floor proximity band. At self-crossings or close parallel returns, the observer cannot infer which later stretch belongs to the current approach. It returns no hint and the existing travelled-motion curvature fallback remains in use. Equal-distance ties within one contiguous stretch retain the first segment. Duplicate zero-length nodes do not split a stretch. The existing 64-node/63-segment bound, subscriptions, expiry and route/seat receipts remain unchanged, with no new query, timer or path command. This is ambiguity rejection, not path selection or clearance proof; physical intersection/loop/overpass behaviour remains unrun while audits are held.

Convoy mounted-fire upkeep now uses the shared full-corridor protected-position veto before explicit target/fire requests. Each eligible operating crew member must be combat-effective, visible and simulation-enabled along with its platform. A blocked lane or unavailable operator retires the convoy target only while the current assigned target still matches its recorded assignment. Cargo, ROE, external ownership and the existing five-second cadence remain authoritative. This is not continuous fire cessation, blast safety or proof that a previously ordered burst has stopped. Actual rounds, blocked-lane interruption and resumed mounted fire remain physically unrun.

The current convoy path has no source-specific external driving pause/restore adapter. Generic declared ownership can make WAIT yield, but cannot suspend an undeclared external controller. Earlier coverage wording claiming otherwise is withdrawn. Required dependency-loaded controller handovers remain unfinished; compatibility expansion stays deferred behind behaviour foundations.

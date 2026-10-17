# WAIT agent handover

Snapshot verified on 16 October 2026. Resume from the current checkout and revalidate remote state before changing Git. WAIT remains incomplete. All 65 feature families are partial and none has full acceptance. The full production goal remains active.

## Goal and user decisions

Deliver WAIT as a production-ready Arma 3 AI addon using owner-local danger and operation FSMs. Complete tactical infantry, CQB, coordination, combined arms, driving, convoys, aircraft and support. Required external controllers need real execution handovers. Preserve Zeus and multiplayer authority. Physical acceptance and measured overhead within 5% median / 10% p95 are required. Source presence, detection, packaging and static tests cannot establish these outcomes.

Audits are paused by the latest direct user instruction. Do not launch Arma until the user resumes them. Permission to close and restart identified audit processes is already granted for authorised runs. Verify the identified processes have exited. Keep normal/server-owned cases separate from real-provider headless-client batches. No audit or build process was left running at this handover.

Priorities and constraints:

- Reliable individual building blocks, driving controllers, FSM execution and the entirety of HBQ precede higher-level composition. Whole-mod review includes helper branches and callers. Avoid selected-file parity claims.
- CQB must work dynamically and repeatedly through terrain, editor-placed, Zeus-placed and usable modded buildings. Account for inaccessible internal points. Preserve failures. No teleport recovery or test-forced clearance.
- The user reported lead-first entry, stragglers, idle exterior soldiers, wedge formation and identical egress destinations. Implement useful isolation, casualty replacement, pairs, coherent entry and consolidation. Historical improvements do not establish current acceptance.
- CBA owns settings. Zeus/ZEN modules issue behaviour tasks. Consolidate modules with shared intent. Explicit Garrison teleport placement is allowed as a labelled task option. This exception does not extend to natural routing or CQB.
- IKMS, WBK Droids and WBK Zombies are compatibility-only. Compatibility expansion is last. Keep existing specialist ownership protections.
- Workshop IDs 3623550024 and 3798063749 were requested for evaluation across the entire addon. ID 3819636004 was added with Advanced Rappelling and CBA dependency requirements. Consult the implementation register and local sources before claiming coverage.
- Batch coherent pushes. Draft PRs use local validation. Do not trigger CI for every small change, remove checks, mark ready just to trigger CI, merge, publish a GitHub Release or upload to Steam.
- No subagents are authorised. Do not change saved memories unless the user explicitly requests it.

## Repository and review state

WAIT root: `C:/Users/AdamW/AppData/Local/Temp/WaldosAITweaks`

Remote: `https://github.com/AdamWaldie/WaldosAITweaks.git`

Branch: `Adam/owner-local-fsm-signing-20261016`

Latest committed implementation at refresh: `48a77bb9db94d8a7496c1aabdfec5dcc3ad13d11`. Later evidence-only handover commits may follow; resolve HEAD before editing. The exact signed candidate below is tied to this source, never a later metadata commit.

[PR 16](https://github.com/AdamWaldie/WaldosAITweaks/pull/16) is open and draft. The verified remote head is `d37db04d1013756338bc537263963eedbfdc92ef` after one coherent checkpoint push; later local handover commits may be unpushed. Revalidate the live head and inspect `git log origin/Adam/owner-local-fsm-signing-20261016..HEAD` for outstanding commits. This handover is tracked with the driving review checkpoint and excluded from player packages. Preserve any unrelated dirty files.

The chat is attached to WMP at `C:/Users/AdamW/OneDrive/Documents/GitHub/WaldosMissionPack`. That checkout has unrelated work. Do not put WAIT changes there. The execution sandbox may require escalation for writes, Git and builds in WAIT. Elevated GitHub CLI works. A non-elevated authentication failure can be misleading.

Before each Git mutation, verify root, remote, branch, staged files and the intended open PR. Stage exact files. Preserve other changes. Use author `WaldoTheWarfighter` with `adamwaldie@users.noreply.github.com`. Never reset, force-push or rewrite preserved branches.

Preserved history includes `Adam/driving-fsm-foundations`, its old draft PR 14, and `Adam/pre-consolidation-20261016`. PRs 12 and 13 were merged previously. Continued work belongs to PR 16 unless live state changes.

Read `AGENTS.md` and `CONTRIBUTING.md`. Every changed SQF file needs its required useful header. Keep operations finite, owner-local, interruptible and generation-bound. A newer mission task or Zeus order must survive cleanup.

## Latest validation and signed package

Current clean signed review source: `48a77bb9db94d8a7496c1aabdfec5dcc3ad13d11`.

- Complete Release: 1,089 tests and all offline gates passed; no physical acceptance added.
- Artifact: `releases/review-cqb-driving-48a77bb/wait-candidate.zip`.
- Reports: `releases/review-cqb-driving-48a77bb/signing-verification.json` and `archive-verification.json`.
- ZIP SHA-256: `9478f257d077589658558d1859492c005be254564a068e0144ee984cfd58108d`.
- Signed package fingerprint: `362ee48362d6bf37d0ace6a5ae7b8aac9495288d08e12fde1dbaeb9fbd4a5f18`.
- Existing pinned signer/key used. Independent HEMTT accepted nine signatures and rejected nine damaged controls, both before and after ZIP extraction. Sealed hashes and public-only key inventory verified; temporary extraction removed.
- Logs: `.qa/workshop-evaluation-20261016/cqb-driving-48a77bb-release.log` and `cqb-driving-48a77bb-signing.log`.
- Includes CQB request cadence/progress-clock and replacement-entry cache fixes; crew actor reservations across ordinary recovery/bypass/corridors; trigger-linked route protection; failed chute boarding cleanup; HBQ recovery review and low-credit handover policy.
- Audits remain paused. CQB flow, fixed-path takeover, native reverse/queues, airborne damage overlap/migration and performance remain unaccepted. No release/Steam publication.

Previous checkpoint details below are historical, not the latest candidate.

Latest local implementation validation:

- Suppression readiness is bound to a loaded selected primary bullet muzzle and nonempty unloaded reserves for that muzzle. Launcher magazines cannot qualify rifle reserves.
- Garrison posture yields to active movement/native tasks, preserves already-prone actors, restores the immediate prior posture only under the original ownership/assignment and rechecks the live building transform.
- Fire fixtures now release individual never-fire orders correctly and require real rifle projectiles during suppression commands. Individual hold-fire and reserve-starvation cases are prepared.
- Garrison real-fire fixture now prepares ordinary recovery, a distinct second burst and newer stance preservation. These are unrun fixtures, not physical results.
- Latest completed Build: 1,067 tests, all sequential offline gates, nine PBOs, 310 production SQF sources, FSM inspections and sealing, exit 0.
- Log: `.qa/workshop-evaluation-20261016/garrison-posture-repeat-fixture-build.log`.
- Unsigned build fingerprint: `075837148d77b379f543820df868228de13fd2fdff92be4a551bf67ae5127597`.
- A clean Release build and permanent-key signed local review candidate now exist for `32729c202f1528b29756ada9aa6ecdd083db9c51`; all 1,067 tests and offline gates passed.
- Artifact: `releases/review-suppression-garrison-32729c2/wait-candidate.zip`.
- Report: `releases/review-suppression-garrison-32729c2/signing-verification.json`.
- ZIP SHA-256: `c87b8a2bd1cb7bf0a65543c16e0c2f3ee390647881bde3192b28e794f546d594`.
- Signed package fingerprint: `63f2d027e67bbb2a9d0fc47292ea39d8859176cb489260020f0052762586a75f`.
- Native pinned signer plus independent HEMTT: nine valid signatures and nine damaged signatures rejected; repeated verification after ZIP extraction also passed. Inventory: 42 files, nine PBOs, nine bisigns, one public key, no private key material. Signing scratch uses external temporary directories and cleanup.
- Release log: `.qa/workshop-evaluation-20261016/suppression-garrison-checkpoint-release.log`. No audit, GitHub Release or Steam upload. All behavioural/performance acceptance remains outstanding.
- Current source-only reference addition: `releaseVerificationAndDeployment/referenceReviews/pinned-down-combat-suppression-3820871877.json`, AI only. The source FSM matches the preserved earlier version; source review is incomplete and earns no parity/acceptance credit.

Historical signed review candidate verified at its capture:

- Clean source: `71e4d45af4f6139fbdc1a2d7808c926465162b64`.
- Artifact: `releases/review-checkpoint-71e4d45/wait-candidate.zip`.
- Report: `releases/review-checkpoint-71e4d45/signing-verification.json`.
- Archive SHA-256: `23edee770d5363689d23224b16f7d76f99e45d9f504f0623cf7c023d3b39b97d`.
- Package fingerprint: `649f890b7630b245e3488a0ca4cce21ffff4a88514ce48bd3c376c81a8de1c1a`.
- Complete Release pipeline passed 1,052 tests. Native signing produced nine signatures. Independent HEMTT verification accepted all nine and rejected all nine damaged-signature controls. Extracting the ZIP and repeating verification also passed.
- Inventory: 42 files, including nine PBOs, nine signatures and one pinned public key. No private key material.
- Release log: `.qa/workshop-comparison-20261014/combined-checkpoint-release.log`.
- Draft validation run 38924876669 completed as skipped, as intended. No release was published.

The driving checkpoint updates `docs/COMPLETION-STATUS.md` to the 1,057-test evidence boundary. PR/artifact reports retain their exact source identities. Do not silently relabel an older signed ZIP as containing later code.

Permanent signing identity:

- Existing pair lives at `C:/Users/AdamW/OneDrive/Documents/Arma3ModsBikey`.
- Filenames: `WaldoTheWarfighter.biprivatekey` and `WaldoTheWarfighter.bikey`.
- Public-key SHA-256: `297f847320561498d0c04e8db2e0570f60b770f1f932adcdcc20c45c2275c889`.
- Never regenerate, rename or overwrite this pair. Never print private bytes or encoded secrets. Never include them in Git, logs or packages.
- Repository secret `WALDO_SIGNING_KEYPAIR` is already configured. It holds JSON fields `privateKey` and `publicKey` as base64 values, configured through stdin. Do not reset it unnecessarily.
- `releaseVerificationAndDeployment/signing-identity.json` pins the authority, public fingerprint and signer. The retained armake2 patch handles file ordering and compiled SQF.
- Local signing uses the pinned native tool at `C:/Program Files (x86)/Steam/steamapps/common/Arma 3 Tools/DSSignFile/DSSignFile.exe`. The signing script validates its hash and uses temporary key files outside the checkout, removing them afterward.
- The supplemental native checker previously accepted a damaged control. Its result is inconclusive and receives no verification credit. Independent HEMTT positive/negative checks provide the credited evidence.

## Current investigation and next action

The mixed-convoy investigation found that detailed control capture existed but the normal matrix never enabled it. Commit `4b88ab6` wires it into WAIT cases and adds lead constraint/write observations. Engine baselines leave capture disabled. No convoy gains changed. Retained stop/restart results do not distinguish speed-policy effects from native path-planning pauses.

Subsequent scoped source comparisons produced two driving observation repairs: approaching-traffic discovery and density-independent native bend hints. The latest sensing repair preserves downward underside hits. Physical acceptance remains open.
Start with `addons/vehicles/functions/convoyTick.sqf`:

- Around lines 247-252, cached specs contain configured maximum speed and physical length.
- Around 365-380, column cruise uses the minimum of the requested speed and 80% of each configured maximum. Desired gaps account for vehicle length. This does not measure actual tracked step-off or braking response.
- Around 465-535, spacing uses longitudinal projection for nearby aligned pairs. Lead pacing reserves some cruise speed for gap closure. Only substantially stretched gaps use actual follower forward speed.
- Around 632-715, follower speed starts from predecessor forward speed plus proportional gap error. Outer-band catch-up is nonlinear. Body clearance and a mass-based closing cap constrain motion. Smoothing cannot override closing, reverse, obstacle or pedestrian limits.
- Later path writers retain predecessor trails, native/fixed-path ownership, grade/path caps and exact command receipts. Do not create a second steering or speed writer.

Next: trace the whole lead/follower control and trail commitment paths with the refreshed source comparison. Identify a concrete cause before tuning constants. Consider attainable column pace and delayed tracked launch, while retaining physical closing and braking safety. A configured top speed is not observed capability. Avoid feeding transient acceleration lag back through every follower until the column ratchets down to walking speed. Preserve deliberate roadblocks and native authored waits.

Useful source locations:

- HBQ: `.qa/source-refresh-20261011/inventory/3812620045/hbq_advanced_driving_ai/functions/fn_driveAssist.sqf`.
- Convoy reference: `.qa/source-refresh-20261011/inventory/3778948165/saai_vehicles/functions/fn_convoyTick.sqf`.
- Comparison: `.qa/workshop-comparison-20261014/WORKSHOP-COMPARISON.md`.
- Branch-review index: `.qa/workshop-comparison-20261014/HBQ-SEMANTIC-REVIEWS.json`. Verify each indexed file hash before relying on its detailed review.
- The index explicitly leaves whole-HBQ review, cooperative passing, queue cascade, moving overtaking, corner manoeuvring, physical outcomes and performance incomplete.
- Convoy startup observation was extended to include the initial 20 seconds because later warm-up sampling missed step-off. Prepared normal-only bypass/passing cases remain unrun.

No live test should be launched under the current pause. Prepare a focused case only after the implementation and its failure hypothesis are concrete.

## Recent implementation details to preserve

### Combined ground and fire ownership

`cortexCombinedArmsLocal.sqf` admits exact server-published opportunities with original contact age and expiry. Local application identity includes the complete opportunity, owner and epoch. Duplicate delivery repairs replay metadata without repeating reveal, fire or route acquisition.

`cortexCombinedGroundStep.sqf` uses a common finite COMBINED_GROUND operation. A public ten-field journal retains opportunity, asset, spent stall count, progress time, last position, destination, original native-order receipt, driver, operator and ACTIVE/COMPLETE/FAILED state. Owner replay preserves these values. Malformed matching journals refuse safely. Recovery spends its one retry before issuing the new route. Terminal work does not restart after migration.

Exact route metadata and issued waypoint receipts protect native edits and cleanup. Arrival completes movement into the firing area. Fire effects remain unproven. Ground support checks current group gunner authority and target-suitable loaded station ammunition before movement, every four seconds during travel, and at arrival. Dormancy defers without renewing expiry. Definite failures clean up owned movement, authenticate exact retirement on the server and may spend one bounded retained fallback slot.

`cortexActorFireTaskAvailable.sqf` protects native service tasks and actor movement reservations. `cortexGroundFireReady.sqf` checks actual loaded gunner-station ammunition and configured target suitability. Keep authority policy separate from ammunition capability.

Routine vehicle targeting and danger suppression yield scripted ground fire to a live group-level combined-ground reservation. Smoke, passenger safety and natural engagement remain available. Routine gunnery checks gunner group, health, simulation, remote/specialist ownership, protected task, ammunition and firing lane.

Commit `a16cc75` adds bounded target fallback: rank known threats, consider at most eight, select the first compatible safe lane and stop. It retains the successful-fire hold. Worst-case query cost and actual engagement remain unverified.

Infantry `cortexFireControl.sqf` now uses `CortexActorMoveReserved`, so malformed/unknown reservations remain protected. Reserved movers retain natural engine aiming/fire and receive no injected target/fire/suppression command from this layer.

The prepared combined-arms fixture uses local gunner FiredMan projectile origin/course plus the admitted operator/token. It can observe directed shots when run. It cannot establish hits, suppression, destruction or HC observation coverage. Normal and HC fixtures must stay separate.

Open investigation: combined-ground direct fire and arrival targeting still need a complete finite command-ownership/retirement review. Clearing an assigned target solely because it equals an old target can overwrite an observationally identical newer command. Do not claim this cleanup is solved.

### Driving and CQB boundaries

Driving uses the existing owner-local FSM, shared scheduler and speed writer. Recent work includes stationary empty/wreck bypass, full 3D destination and seat-command receipts, finite recovery and default-off experimental passing. Passing checks owner consent, original expiry, oriented hull separation and measured traffic courses. Discovery is capped at 1,250 m and 64 actors, using a nominal 35 m/s approach allowance. Faster modded traffic and query cost remain limitations. Cooperative head-on jam clearance is unfinished.

CQB source includes pair replacement, actor-local indoor work, finite entry/egress, reserve admission and task-owned exterior settlement. The latest retained narrow physical evidence is older candidate `f9c3d7d`: two- and six-person covered visits completed, twelve-person clearance remained incomplete, and the batch retained 13 findings. These results do not validate current code. Terrain versus placed-building behaviour, dynamic routing, full participation, casualty flow, isolation, repeated use and consolidation remain acceptance work.

Preserved Pinned Down archive: `C:/Users/AdamW/Documents/AI-Reference-Archives/PinnedDown/20261013-013708`. Earlier checks verified 320 manifest entries, while eight installed original PBOs were missing. Revalidate the archive manifest before using it. Keep raw sources/assets out of published packages. No whole-Workshop parity percentage is justified.

## Validation and continuation procedure

Use the bundled Python runtime:

`C:/Users/AdamW/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`

From the WAIT root, the required full local pipeline is:

```powershell
$env:TEMP = [IO.Path]::GetTempPath()
$env:TMP = $env:TEMP
./releaseVerificationAndDeployment/build_mod.ps1 -Mode Build `
  -Python 'C:/Users/AdamW/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' `
  -Hemtt './.tmp/hemtt/bin/hemtt.exe' *> .qa/your-focused-build.log
```

Use Release mode for a new signed candidate. Wait for the same process handle to exit 0. Nine PBOs in the log is not terminal completion. Run sequentially. Do not modify source or start another builder while a build is active. Keep progress updates within about a minute and avoid repeated short polls.

The pipeline covers unit tests, SQF/config/header/link checks, wiki, CBA/script parity, static performance, feature coverage, HEMTT and FSM inspection. New sources need CfgFunctions registration and semantic coverage. Regenerate the feature report with `check_cortex_coverage.py --write-report releaseVerificationAndDeployment/cortexQA/FEATURE_STATUS.md`. New settings also require the settings reference/parity update.

Useful canonical records:

- `docs/COMPLETION-STATUS.md`: evidence boundary and remaining acceptance.
- `releaseVerificationAndDeployment/cortexQA/FEATURE_STATUS.md` and `coverage.json`: 65-family wiring and evidence.
- `docs/Smart-AI-Pass.md`: behaviour/authority guide.
- `releaseVerificationAndDeployment/cortexQA/PERFORMANCE.md`: runtime measurement requirements.
- `.qa/workshop-comparison-20261014/`: local review details and build logs. These ignored files are available on this machine and may be absent from a fresh clone.

Keep the goal active. When audits resume, rebuild a fresh exact candidate, verify mission entry/RPT and observe real physical outcomes and measured performance. Retain failed checks. Mark completion only when the entire stated goal is proven.

## Driving changes since the earlier signed source

- `a16cc75`: routine gunnery considers up to eight ranked known contacts, stopping at the first usable station/lane. Physical engagement and query overhead remain unverified.
- `4b88ab6`: normal matrix timing records actual lead/follower cap chains and write flags. Use this to diagnose mixed-column stops when audits resume.
- `4c15e3f`: scoped queue/jam source review records forced-velocity execution and timestamp-only back-up requests. A native authenticated queue-cascade executor remains missing. See `releaseVerificationAndDeployment/referenceReviews/hbq-jam-cascade-20261016.json`.
- `8ac3b95`: FollowingCap discovery includes own six-second travel plus nominal 35 m/s approaching travel and 20 m margin. It refuses envelopes above 500 m and candidate sets over 64. One query remains. Faster approaches, large modded hulls, physical braking and query overhead remain unaccepted. See `hbq-traffic-prediction-20261016.json` in the same engineering directory.
- `b058168`: native path hints walk six metres along retained path distance and interpolate sparse segments. They preserve the 64-node bound, exact fresh context, floor/forward limits and disconnected-stretch rejection. No movement command or new world query is added.
- `2f57b2a`: DrivingGeometryCap excludes upward support using signed surface-normal Z. Sampled downward underside hits retain solid constraints. Ray count, cadence and writers are unchanged. The source-derived predicate regression covers support, walls and sloping/horizontal undersides.

The curved-helper/Sense comparison is `releaseVerificationAndDeployment/referenceReviews/hbq-curved-observation-20261016.json`. Engineering attribution stays outside product guides. Whole-source parity and all physical/performance requirements remain open.

The retained mixed-column evidence is under `.qa/workshop-evaluation-20261012/`: `mixed-convoy-startup-control-review.json`, `mixed-convoy-control-review-20261013.json` and `convoy-historical-stop-start-baseline-20261013.json`. Read it before tuning gains. The source comparison still needs grade/deck observation, native queue execution and remaining helper/caller dispositions. No audit ran during these changes.

## Newly registered AI reference (2026-10-16)

Workshop item 3820871877, Pinned Down Combat Suppression, is registered for AI-only evaluation in releaseVerificationAndDeployment/referenceReviews/pinned-down-combat-suppression-3820871877.json. Player effects are explicitly out of scope. Local package hashes are recorded; source review and implementation remain pending. The wider goal and audits remain paused.

Continuation update: the goal tool confirms ACTIVE after user continuation; physical audits remain paused. The new suppression reference now has an initial AI source comparison, source hashes, explicit audio exclusion and outstanding deep-review dispositions. No production implementation or physical acceptance is claimed. Read the register JSON for current findings rather than the initial registration status above.

Suppression follow-up: CortexFireControl now requires the selected primary bullet muzzle to be loaded before deliberate suppression. A carried rifle reserve cannot qualify a pistol, underbarrel launcher or empty selected muzzle. Complete Build passed 1058 tests and all offline gates (log .qa/workshop-evaluation-20261016/suppression-muzzle-build.log). Physical empty-rifle, launcher-selected and loaded-rifle cases remain unverified; no audit launched.

Final suppression checkpoint: reserve accounting now uses selected-muzzle compatibility and nonempty unloaded magazines, preventing underbarrel reserves and loaded duplicates from qualifying rifle suppression. Full Build completed with 1058 passing tests and all offline gates; .qa/workshop-evaluation-20261016/suppression-reserve-build.log, fingerprint 2871d90f5e59aac24b085dcdb08f43d6890c6215678d9d62d77a8506c8cafd4f. PR16 remains open/draft on the same branch. No push, signing or audit. Live ammo-switch/reload cases and overall physical acceptance remain outstanding.

Fire audit prerequisite fixed: both the visible-fire and multi-squad suppression phases now release individual BLUE orders when their groups switch RED, and assert actual unitCombatMode before measuring shots. Prior physical failures remain recorded; this fixture correction does not retroactively certify them. Full Build exit 0, 1059 tests; .qa/workshop-evaluation-20261016/fire-audit-unit-modes-build.log. The planned selected-muzzle/reserve physical case is still to be added and run only after audits resume.

Fire audit evidence follow-up: each FiredMan record now retains shot time, weapon/muzzle/ammo/magazine, contemporaneous WAIT order time and engine command (bounded to 200 records). Positive suppression requires a primary bullet during SUPPRESS within eight seconds of the production order; both squads need a correlated projectile before early completion. This is temporal/command correlation, not proof of suppression effect or unique command ownership. Complete Build exit 0, 1060 tests; .qa/workshop-evaluation-20261016/fire-audit-shot-provenance-build.log. Not executed in Arma. Selected-muzzle negative fixtures remain pending.

Individual fire authority fixture added: the visible-target case leaves shooter four on explicit BLUE while the group and three peers are RED. It requires peers to physically hit both targets and separately checks held-unit shot count, retained BLUE mode and absence of WAIT target/suppression receipts. Weapons remain functional. Complete Build exit 0, 1061 tests; .qa/workshop-evaluation-20261016/fire-individual-hold-build.log, fingerprint d53edab09cf50b77efd28821d09fdb5aff6d49799c14b3ed3cb4a1afe8ca1cd7. No audit ran; current fixture changes are not yet committed.

Reserve negative case now prepared in existing multi-squad suppression fixture: third rifleman in each group has a loaded Katiba GL, one nonempty rifle spare and four GL grenades. Actual inventory/load checks must pass; adequate peers must still rotate and fire. The two starved actors must receive no WAIT suppression timestamp; native fire/reload is allowed. No direct fire-control call or fabricated knowledge. Complete Build exit 0, 1062 tests, all offline gates; .qa/workshop-evaluation-20261016/fire-reserve-rejection-build.log. Individual hold and reserve fixtures remain physically unrun. Empty-muzzle and selected-launcher negative variants still pending. This checkpoint supersedes the earlier uncommitted note.

Driving grade/deck source review: expanded hbq-curved-observation-20261016.json after verifying its source SHA. HBQ replaces endpoint altitude with a fixed terrain-relative low row; WAIT projects rigid body rows at current pitch. Neither proves future support/deck clearance across grade changes. Recorded mathematical sensitivity and required flat/grade/crest/deck/underside comparison cases. No production projection change or physical acceptance; do not apply a terrain-only flattening shortcut.

Garrison suppression fix: duck expiry restores the immediate pre-duck stance, guarded by original group, local group, generation, owner epoch, full assignment and unchanged applied duck stance. Already-prone soldiers receive no stance-raising duck command. Complete final Build exit 0, 1063 tests/all gates; .qa/workshop-evaluation-20261016/garrison-duck-final-build.log, fingerprint f9b3cca673f1ba5aa537cfd8675632b1bd500935f66587128b3e3e22a8db4d35. Earlier first build failed an old test parser and was corrected without dropping safety assertions. Live suppression, replacement order, stance takeover and HC migration cases remain unrun; audits paused.

Garrison duck authority follow-up: both immediate and delayed posture writes now yield to actor movement reservations, mounted state, remote control and native medical/boarding/service/assembly tasks. Epoch default is zero at capture and callback, matching garrison movement receipts and allowing explicit pre-Cortex garrisons to restore posture. Complete Build exit 0, 1064 tests/all gates; .qa/workshop-evaluation-20261016/garrison-duck-task-final-build.log, fingerprint efb574bf6ccd6fef2730402fe98c01fce0303d9a6ffaa62020000797c6ba4bd8. First run exposed an outdated exact-count test; updated count without weakening reservation assertions. No physical audit or acceptance; live task takeover and migration still pending.

Garrison moving-posture follow-up: hard duck events and their delayed recovery now yield to native MOVE/FOLLOW. Stationary defenders retain the reaction; native/general danger handling remains available on approach. Lifecycle guide updated for the combined posture fixes. Final documented Build exit 0, 1064 tests/all gates; .qa/workshop-evaluation-20261016/garrison-posture-documented-build.log, fingerprint 4075222dbe7486e1dbea5bc7f9bd7e271624eead10ecb2bcbf50747a837621ea. No live movement/suppression or HC acceptance; audits paused.

Garrison transform posture fence: immediate duck and delayed recovery now revalidate the assigned building's live position/direction/up-vector receipt, matching movement invalidation. Stored assignment equality alone no longer permits posture changes after Zeus movement, rotation or deletion. Complete Build exit 0, 1065 tests/all gates; .qa/workshop-evaluation-20261016/garrison-posture-transform-build.log. Physical incoming-fire and mid-duck transform/deletion tests remain absent and unrun; audits remain paused. Changes currently uncommitted.

Garrison live fixture prepared in normal-owner surplus case: requires a physically occupied non-prone exterior actor, spawns an excluded hostile rifleman, records real FiredMan shots and waits for production duck metadata. Deletes hostile before issuing explicit replacement UP, then checks it survives the old deadline. Damage policies are temporarily saved/restored for this diagnostic; no handler calls, synthetic suppression, actor teleport or completion writes. Prerequisite/missing reactions fail instead of passing unused cases. Full Build exit 0, 1066 tests/all gates; .qa/workshop-evaluation-20261016/garrison-posture-live-fixture-build.log, fingerprint 4a6099ef56ee91421f74c6eadf71b89cea7e1e2ac307cdd22c62397cd59918dd. This prepares replacement-stance acceptance only; unmodified pre-duck recovery, mid-duck building transform and HC migration still need live cases. No audit launched. Combined transform guard/fixture checkpoint supersedes prior uncommitted note.

Garrison live repeat fixture extended: first hostile burst is stopped using actual group/unit BLUE and cleared attacker target; no defender recovery values are written. Audit observes return to immediate pre-duck posture, then requires new attacker shots and a strictly later live duck deadline before the explicit replacement UP test. First recovery failure stays recorded even if the later case succeeds. Complete Build exit 0, 1067 tests/all gates; .qa/workshop-evaluation-20261016/garrison-posture-repeat-fixture-build.log, fingerprint 075837148d77b379f543820df868228de13fd2fdff92be4a551bf67ae5127597. Physical ordinary recovery/repeat cases are now prepared but unrun. Mid-duck transform/deletion and HC migration fixtures remain pending. Local changes not yet committed; no audit launched.

Native reverse capability fixture expanded: normal-only excluded tracked APC, wheeled MRAP and truck each test LEFT/RIGHT with separate physical result IDs. Requires actual backward velocity, displacement, heading change, measured yaw sign and bounded rear observer execution. No forced velocity or teleport. Complete Build exit0, 1068 tests/all gates; .qa/workshop-evaluation-20261016/native-reverse-families-build.log. Queue cascade remains unimplemented and convoy reverse capability unproven. Audits paused; no case run. Source review/index updated; current changes local/uncommitted. PR16 remote checkpoint was verified at844a82c, draft validation skipped (run38947635357); signed source remains32729c2.

HBQ follower/order/cadence review recorded in releaseVerificationAndDeployment/referenceReviews/hbq-follower-order-20261016.json with hashes and scoped ranges. Preserves follower/player-led and authored-wait intent while rejecting waypoint resurrection, blanket MOVE/PATH resets, flattened handback and old-owner shared flag cleanup. WAIT full route/epoch receipts remain; no new queue executor or parity acceptance. Twenty focused planning/reverse/reference tests pass. Pending native-reverse fixture batch still has complete Build evidence (1068 tests). Review index hash updated locally.

Morale suppression sentinel fixed after checking official native API documentation: getSuppression -1 means unavailable/disabled and must not become negative pressure. CortexMorale now clamps local samples0..1 before averaging; existing20% weight unchanged. Source effect review records cached skill-baseline ownership risk and source config-scale normalization as an engine-measurement question. Full Build exit0,1069 tests/all gates; .qa/workshop-evaluation-20261016/morale-suppression-sentinel-build.log, fingerprint a8bccb6891e9487f46f7dc50f02ebbfed8b2047725659f0200b62c5279835dab. No physical run; current changes local/uncommitted.

Suppression arithmetic sweep complete for additive/ranking/probability uses: morale, AT gunner cost, grenade-evasion probability and smoke ranking clamp native samples0..1. Unavailable-1 cannot grant a numeric readiness/probability bonus. Simple hazard thresholds remain unchanged. Smoke admission now delegates to strict CortexActorMoveReserved; malformed/unknown leases cannot expire through the weaker local adapter. Complete Build exit0,1070 tests/all gates; .qa/workshop-evaluation-20261016/suppression-arithmetic-reservations-build.log, fingerprint b5100ab90510a2cdcc8037d4f6970b4fe17b872ee4138935c237c6060e317590. Live sentinel/morale, selection/evasion and concurrent reservation behaviour remain unrun. Signed32729c2 candidate predates these fixes; audits paused.

Queued danger-smoke release now uses strict CortexActorMoveReserved on every aiming retry before doWatch/forceWeaponFire, matching selection and cancelling ACTOR_RESERVED for unknown/malformed/new leases. FRAG/non-danger contracts unchanged. Full Build exit0,1071 tests/all gates; .qa/workshop-evaluation-20261016/queued-smoke-reservation-build.log, fingerprint 4b39ea0139eab4db35ddd0246693261237365f925ef0a0e339314fb20a968bcd. Live next-frame takeover unverified; audits paused. Initial automatic review rejection incorrectly applied the older whole-goal pause; fresh get_goal confirmed ACTIVE and the identical action was approved on resubmission with user continuation evidence. No files changed on rejected attempt.

Drill casualty refill now uses CortexActorMoveReserved before fire-team roster mutation, preventing unknown/malformed/nonlocal actor reservations from being treated as expired. Existing native/specialist exclusions retained. Complete Build exit0,1072 tests/all gates; .qa/workshop-evaluation-20261016/drill-refill-reservation-validated-build.log, fingerprint ceb963a1927dae8e645588b4bd5956df869c42495322cea77a74f389f8dedccd. Initial two runs exposed old assertions requiring the weak adapter; replaced with strict predicate and adapter rejection assertions. Concurrent casualty/task takeover remains physically unverified; audits paused.

Coordinated support owner boundaries now use strict CortexActorMoveReserved before allocating moving teams and before doStop on covering actors. Unknown/malformed leases remain protected. Server provisional eligibility is unchanged because its actors can be nonlocal; it needs a separate cross-owner review rather than the local predicate. Full Build exit0,1073 tests/all gates; .qa/workshop-evaluation-20261016/support-owner-reservations-final-build.log. Old direct-read/weak-expiry assertions updated to strict helper and adapter rejection. Live concurrent takeover, coordination and performance remain unverified; audits paused. Next related weak admission found in CortexGrenadeCheck; evaluate emergency priority and cleanup before changing it.

Grenade evasion admission now preserves unknown/malformed reservations via CortexActorMoveReserved; delayed regroup matches the exact issued GRENADE_EVASION destination/deadline lease, rather than treating a changed point within1m as its own. Existing native route, epoch/generation, specialist, drill and locality guards retained. Full Build exit0,1074 tests/all gates; .qa/workshop-evaluation-20261016/grenade-evasion-ownership-final-build.log. Initial run exposed a separate native-handover assertion for the old deadline comparison; updated to require full lease equality. Physical grenade reaction/replacement and migration unrun; audits paused.

Complete HBQ vehicleUnstuck helper comparison recorded in releaseVerificationAndDeployment/referenceReviews/hbq-unstuck-helper-20261016.json with actual source hash/181lines. Header capability claims exceed implementation (no refuel/recreation branch); driver-seat callback lacks replacement order/locality receipts, PATH reset and forced nudge/teleport rejected for natural recovery. Useful destination-index, conscious replacement and collision/reservation intent retained for redesign. Compared WAIT finite ordinary recovery/handback; native rear doMove remains physically unproven, not native-reverse credit. JSON/index verified; no production change or build rerun warranted. Next: trace WAIT crew replacement and delayed ownership, then whole-source remaining branches. Audits remain paused; 1074-test production build remains latest.

WAIT driver casualty controller traced after complete HBQ helper review. DrivingCrewStep already has finite route/seat/native-command receipts, but lacked candidate ActorMove arbitration. Added strict reservation check to candidate selection, live availability and atomic command boundary, covering Eject/MoveToDriver. A new reservation cancels without clearing newer task state. Full Build exit0,1075 tests/all gates; .qa/workshop-evaluation-20261016/driving-crew-reservation-build.log. No physical crew/recovery acceptance; audits paused. Remaining native ACTION ambiguity and multi-owner convoy jam-room work are not solved by this change.

Combat commander-to-gunner path now rejects actor reservations, direct remote control (including module owner), Cortex external ownership and specialist control before assignAsGunner/MoveToGunner. Does not clear newer tasks or move the driver. Complete Build exit0,1076 tests/all gates; .qa/workshop-evaluation-20261016/combat-crew-ownership-build.log. Existing physical fixture kills the gunner and checks actual commander seat occupancy; remains unrun, and corpse/vacancy/native switch behaviour must not be assumed successful. No finite combat seat retry or empty-seat assignment arbitration was added. Audits paused; no push.

HBQ performance/precision/proximity complete helper review saved in referenceReviews/hbq-performance-precision-20261016.json (under releaseVerificationAndDeployment), with source hashes and driving cadence ranges. Scheduler wake lateness/ray counts/FPS are not median/p95 overhead proof; monitor lacks separate HC owner reporting. Distance precision and body-direction visibility heuristics cannot justify hidden recovery or diminished tactical outcomes. WAIT standalone frame-time benchmark is patrol-only despite matched50group provenance. No runtime modification, no full build rerun; review/index JSON verified. Existing1076-test production build remains latest. Whole-addon5/10percent budget unmeasured/unaccepted; audits paused.

Complete HBQ unflip/protectBriefly/teleportVehicleFree review recorded in releaseVerificationAndDeployment/referenceReviews/hbq-unflip-protection-relocation-20261016.json; source hashes/linecounts and private index verified. Covers stale crew recall/forced seating, overlapping damage restore, local-only relocation reservations and differing road/ground geometry checks. No production copy/change; no build rerun needed. Related WAIT source risk found: CortexParachuteJump restores original allowDamage via raw remote callback without exit token/overlap journal. Next trace AirborneDropStep repeat/locality and design owner-local cleanup before fixing; false value alone cannot prove permission ownership against an indistinguishable mission false write. No live failure inferred. Latest production build1076; audits paused.

Airborne caller trace found aircraft control only checked at admission. DROP now rechecks pilot/effective-commander player/direct remote/external takeover before each exit; pending selection skips reserved/unconscious/external actors so one refused first passenger cannot starve eligible jumpers. CortexParachuteJump independently checks actor reservation and direct/specialist ownership before mutation. Existing partial-drop landing deadline remains: survivors aboard cannot pass full landing. Full final Build exit0,1078 tests/all gates; .qa/workshop-evaluation-20261016/airborne-live-control-final-build.log. Damage-protection overlap, mid-exit migration/freefall continuation and shared aircraft DropUntil ownership remain unresolved; do not imply those repaired. No live audit; audits paused.

Airborne insertion episode guard added: monotonic group serial plus owner epoch stored on queued job/group/aircraft. DropStep rejects missing/stale group episode or epoch before work; aircraft episode replacement retires only original group state. Cleanup requires exact aircraft episode before clearing DropUntil. Full Build exit0,1079 tests/all gates; .qa/workshop-evaluation-20261016/airborne-episode-build.log. This does not supply cross-owner shared-aircraft admission arbitration, migration continuation or parachute damage restoration ownership. Physical replacement/migration still unrun; audits paused.

Prepared held-first passenger case in existing normal-owner base runAirborne fixture (not HC or invalid-chute variant). Public drop task with4s interval; exact AUDIT_HELD_PASSENGER reservation on first actor must remain, second must physically be in ParachuteBase, then fixture releases only its exact lease and existing both-land/backpack/ground-movement checks continue. Restores interval. No production step/direct jump calls, fabricated completion or midflight teleport. Full Build exit0,1080 tests/all gates; .qa/workshop-evaluation-20261016/airborne-held-passenger-fixture-build.log. Unrun; pilot takeover and stale-episode physical fixtures still pending. Audits paused.

CQB visit trace confirmed production requires1.5m3D/.75mheight/bounds/target-house overhead/clear segment. Independent runBuildingComparison observer was weaker: no overhead requirement and ignored non-target-house blockers. Added independent nearest overhead house match and empty geometry segment requirement; no production receipt/function consulted. Full Build exit0,1081 tests/all gates; .qa/workshop-evaluation-20261016/cqb-independent-visit-geometry-build.log. Navigation visit remains distinct from hostile room safety; porch/geometry limitations and actual entry/flow remain physical acceptance gaps. No audit run or retrospective removal of prior failures. Audits paused.

Current LAMBS CQB entry comparison recorded in releaseVerificationAndDeployment/referenceReviews/lambs-cqb-entry-flow-20261016.json. Reads active doAssault separately from unproven-incoming legacy doAssaultCQB/tacticsCQB, verifies RND macro5percent random advancement, rejects pseudo-clearance and stale attack restore. Prior20261015 missing contact-belief data path finding is stale: current selector/check/clear validates and persists fresh bounded belief and seeds matching floor. Partner still uses geometry-connected native nodes; no native-path proof from clear line. Existing12s proven-anchor retry is mitigation, not physical acceptance. Next capture bounded per-actor entry decision/progress/native command receipts rather than blind spacing/timing changes. JSON/hashes verified; no production change/build rerun. Latest1081test build; audits paused.

Added opt-in WAIT_Cortex_ClearCaptureEntry entry diagnostics to BuildingOperationStep, enabled only on fresh-clear audit groups. Per-job max256 logs,16actor keys,2s/actor; native command/destination, intended point, physical ASL pose, speed, lane/mover/entered plus generation/epoch. No new geometry/proximity queries, movement/public state writes or permanent observer; disabled default. Full Build exit0,1082 tests/all gates; .qa/workshop-evaluation-20261016/cqb-entry-capture-build.log. Purpose: distinguish partner destination, native command and progress at entry without blind route changes. Not path-success proof; captured cases are not performance evidence. No live run; audits paused.

CQB unchanged-target writer used activeOwnMove (false when unitReady) as its no-reissue guard, allowing an exact owned MOVE to be resent every callback when ready. Now uses ownsCurrentMove (current MOVE plus exact expected destination receipt), leaving unitReady/activeOwnMove in physical handoff logic and finite4/12s retry loop in control of refresh. Entry samples append native readiness. Full Build exit0,1083 tests/all gates; .qa/workshop-evaluation-20261016/cqb-owned-ready-move-build.log. This is source-proven reissue-path removal, not confirmed cause/fix of observed stragglers. Native empty-command churn, actual path access and clearance quality remain unresolved; audits paused.

Batched remote checkpoint verified: PR16 open/draft at d37db04d1013756338bc537263963eedbfdc92ef. Existing PR scope retained, current signed655728a evidence added, previous checkpoint labelled historical. Validation run38958000332 completed SKIPPED per draft policy; no manual CI dispatch. One push only. This post-push handover commit is local; do not push merely to update bookkeeping. Audits paused; no merge/publication.

CQB duplicate request coalescing extended to ended native command only when retained native destination and WAIT committed target both still match within.25m. This removes initial-writer per-callback reissue before existing4s ended-command retry; it does not change ownsCurrentMove, physical handoff or native task authority. Changed destinations remain new requests. Full Build exit0,1083 tests/all gates; .qa/workshop-evaluation-20261016/cqb-ended-command-cadence-build.log. Physical effect on entry stalls unverified; audits paused. Signed655728a candidate predates this source change and remains historical exact-source evidence. Keep local until next coherent checkpoint; no new push.

CQB support separation set _issue=true and the common post-writer block treated that as a new room request, resetting _lastProgress and mover baselines. Added independent _roomRequestChanged flag: support issue semantics preserved but only genuine new room request resets that clock. Measured mover best-distance logic unchanged. Full Build exit0,1084 tests/all gates; .qa/workshop-evaluation-20261016/cqb-buddy-progress-clock-build.log. Source fixes a stall-masking path; physical effects on congestion/stragglers unverified. Audits paused; no push. Signed655728a candidate predates this and635a53c; keep exact identities.

17 October 2026: user requested automatic safe commit plus successor prompt when credits become very low. Default threshold20 credits is recorded in AGENTS.md; check live usage at substantial work checkpoints, not claimed continuous monitoring. AGENT-CONTINUATION-PROMPT.md contains the complete goal, current code/evidence boundary, private ledger/mod list, registers, local source/archive locations and next work. Verify all current state on resume. Goal remains active and audits remain paused.

HBQ debug helper review completed in releaseVerificationAndDeployment/referenceReviews/hbq-debug-lifecycle-20261017.json. Three complete helpers plus selected publisher/cleanup branches hash-recorded; source cache collision, stale display timing, unbounded lists and local sphere loop costs are dispositions only. Review/index JSON verified. No production change or build rerun; latest production validation remains1084 tests. No audit/process left running by this batch.

## 2026-10-17 HBQ unstuck loop review

Completed the full source loop comparison in `releaseVerificationAndDeployment/referenceReviews/hbq-unstuck-loop-20261017.json`; source hash and private semantic index updated. RouteLost bypasses intentional-wait/loading/PATH admission and normal give-up thresholds. Ordinary step-three logs/counters do not establish successful relocation; visible repeated repair/nudge has no finite attempt limit. WAIT already retains plain authored MOVE admission and a durable exhausted stage, so no unsafe fast path was imported. Native reverse versus U-turn, multi-owner jam room and physical/performance acceptance remain open. Source-only change; audits remain paused.

## 2026-10-17 Failed parachute boarding cleanup

Parachute exit now applies inherited chute velocity only after actual seat occupancy. A failed boarding deletes only the just-created chute when local and empty, preserving occupied/transferred objects. Damage restoration remains scheduled; overlapping damage protection and mid-exit locality continuation are still unresolved. Full Build passed, exit 0; log: .qa/workshop-evaluation-20261016/parachute-failed-boarding-build.log. No physical audit run. Latest signed candidate remains 655728a and predates this change.

## 2026-10-17 Ordinary recovery seat reservations

DrivingAssistStart now includes the strict actor reservation predicate in its shared native-task boundary for both driver and effective commander; this covers initial release and each later cap/recovery write. DrivingRecoveryRelease checks the same predicate before doStop/doFollow/doMove handback, without clearing the actor lease. Unknown/nonlocal leases refuse admission, valid expired leases use existing semantics. Full Build passed: 1086 tests, exit 0; `.qa/workshop-evaluation-20261016/driving-seat-reservation-build.log`. No physical takeover or recovery acceptance; audits remain paused. Signed source remains 655728a and predates these changes.

## 2026-10-17 Alternate driving seat reservations

Bypass and navigation-corridor shared seat guards now refuse strict actor reservations in ordinary and convoy-lead execution, including approach/fixed-path issue. Both release helpers check reservations before movement cleanup and never clear actor leases. Full Build passed: 1087 tests, exit 0; `.qa/workshop-evaluation-20261016/driving-alternate-seat-reservation-build.log`. No live acceptance: preserving new task authority does not prove termination of an already-running native fixed path. Prepared future takeover tests must distinguish command refusal from actual vehicle cessation/handover. Audits remain paused.

## 2026-10-17 Recovery trigger admission consistency

Exact reread confirmed synchronized waypoints were already rejected; do not report that as a new gap. The actual inconsistency was activated synchronized triggers: ordinary recovery admission allowed them while handback refused any trigger links. Admission now requires no synchronized triggers, matching handback and preserving repeating trigger authority. Native route travel/safety observation remains available. Updated the old regression assertion from triggerActivated presence to explicit empty-link protection and added admission/handback parity coverage. Initial full build failed only that superseded assertion (retained log driving-trigger-admission-build.log); complete rerun passed 1088 tests and all gates, exit 0, `.qa/workshop-evaluation-20261016/driving-trigger-admission-build-recheck.log`. No physical acceptance; audits remain paused.

## 2026-10-17 CQB replacement entry proposal

Lane casualty replacement now deletes only its pairEntryTargets lane key before survivor/replacement handoff. Previously the lane-number cache survived roster changes, letting a replacement inherit the removed buddy's target without fresh occupancy selection. The normal planner rebuilds it; room coverage, survivor entry, lane route and hard deadline remain intact. Full Build passed: 1089 tests and all gates, exit 0; `.qa/workshop-evaluation-20261016/cqb-replacement-entry-cache-build.log`. No physical reinforcement/flow acceptance; audits remain paused.

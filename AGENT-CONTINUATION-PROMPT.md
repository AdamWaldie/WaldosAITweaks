# Continue WAIT development

Continue the active WAIT goal in `C:/Users/AdamW/AppData/Local/Temp/WaldosAITweaks`. This chat may be attached to WaldosMissionPack. Do not edit or commit WAIT changes there.

## Goal

Deliver WAIT as a production-ready Arma 3 AI addon built on owner-local danger and operation FSMs. Complete and physically validate tactical infantry, CQB, coordination, combined arms, driving, convoys, aircraft and support behaviour; implement real handovers for required external controllers; preserve Zeus and multiplayer authority; and remain within the 5% median/10% p95 performance budget. Detection, packaging and static tests do not count as completed behaviour.

## Start here

1. Read `AGENTS.md`, `CONTRIBUTING.md` and `AGENT-HANDOVER.md`. Revalidate the goal status, Git root, remote, branch, working tree and open PR before acting.
2. Use branch `Adam/owner-local-fsm-signing-20261016`, remote `https://github.com/AdamWaldie/WaldosAITweaks.git`, draft PR16. Last verified remote head: `d37db04d1013756338bc537263963eedbfdc92ef`. Later local commits are intentional. Do not reset them or repeat their changes.
3. Read the latest dated notes at the end of `AGENT-HANDOVER.md`. Earlier sections and reviews can describe superseded code. Confirm every proposed gap against current source.
4. Check account usage before starting a long batch. At 20 credits remaining or less, make a safe checkpoint and refresh this prompt instead of starting another batch. Never redeem a reset or purchase credits without explicit approval.

## Authority and scope

Audits are paused by the user's latest direct instruction. Do not launch Arma until the user resumes them. Permission to stop/restart identified audit processes already exists for authorised runs. Verify that those processes exit. Normal and actual-provider HC cases use separate batches.

Prioritise working individual building blocks, owner-local FSM execution and the entirety of HBQ before larger compositions. CQB must work dynamically through terrain, editor/Zeus placement and usable modded buildings, with inaccessible points recorded as failures. Preserve casualty replacement, buddy flow, exterior isolation, interruption and post-clear continuation. CBA owns settings. Zeus/ZEN modules issue behaviour tasks. Explicit instant Garrison placement is an allowed labelled option. IKMS, WBK Droids and WBK Zombies are compatibility-only. Expansion is last.

Keep the full goal active. All 65 families remain partial, with zero full acceptance. Do not invent a completion percentage. No merge, GitHub Release or Steam upload. Batch pushes to the existing draft PR. Do not trigger CI for every commit. No subagents are authorised.

## Registers and source material

Paths below are relative to the WAIT root unless absolute. Private local material is not included in a Git clone. If it is missing on another machine, get the archive/inventory before claiming a source comparison.

- `docs/COMPLETION-STATUS.md`: current acceptance boundary.
- `releaseVerificationAndDeployment/cortexQA/FEATURE_STATUS.md` and `coverage.json`: 65-family feature/fixture register.
- `LOCAL_IMPLEMENTATION_LEDGER.md`: private local mod list, source classifications and intent. It is deliberately excluded from Git. Never force-add it.
- `.qa/workshop-comparison-20261014/WORKSHOP-COMPARISON.md`: historical baseline comparison, with dated caveats.
- `.qa/workshop-comparison-20261014/source-code-index.json`, `wait-code-index.json`, `HBQ-CONTROLLER-BRANCH-INDEX.json` and `HBQ-SEMANTIC-REVIEWS.json`: source locations and scoped review evidence. Counts are inventory only.
- `.qa/source-refresh-20261011/code-inventory.json` and `inventory/<WorkshopID>/`: private extracted sources. HBQ is `3812620045`. LAMBS is `1858075458`.
- `releaseVerificationAndDeployment/referenceReviews/`: tracked engineering comparisons, including current HBQ, LAMBS and AI-only suppression item `3820871877`. Keep raw source/assets out of product packages and respect licence restrictions.
- `C:/Users/AdamW/Documents/AI-Reference-Archives/PinnedDown/20261013-013708`: preserved Pinned Down material. Verify its manifest. Some missing original PBOs were recovered only as extracted snapshots.
- Workshop `3623550024` and `3798063749`: evaluate across their whole AI scope. `3819636004`: Advanced Rappelling and CBA dependencies. Consult the ledger/register for the remaining IDs.

## Current checkpoint and next work

Latest implementation checkpoint before this handover: `48a77bb`. Its complete Release passed 1,089 tests and all offline gates. Logs are under `.qa/workshop-evaluation-20261016/`. Audits have not run for these changes.

CQB now preserves unchanged owned MOVE requests through readiness changes. An ended command with the same retained destination waits for timed retries. Buddy separation no longer resets the room mover's progress clock. Casualty replacement invalidates only the changed lane's cached buddy-entry proposal for fresh occupancy selection. Driving recovery/bypass/corridors preserve seat actor reservations; trigger-linked routes remain under authored control. Failed chute boarding cleans only the created empty local chute.

Bounded entry diagnostics capture intended/native destinations, physical pose, command, speed and readiness. Fresh-clearance fixtures enable them. These source repairs do not establish that the reported stalls or stragglers are fixed. Trace actual failure evidence when audits resume. Avoid speculative spacing/timing edits.

Other open work includes physical native reverse/queue recovery, shared-aircraft arbitration, parachute damage-protection overlap and mid-exit migration. The HBQ debug-helper review is recorded in `releaseVerificationAndDeployment/referenceReviews/hbq-debug-lifecycle-20261017.json`. It records cache collisions, stale display and lifecycle/cost limits, with no production implementation claim.

Latest signed candidate is source `48a77bb9db94d8a7496c1aabdfec5dcc3ad13d11`, under `releases/review-cqb-driving-48a77bb/`. All nine signatures verified and all nine damaged controls were rejected again after extraction. Later handover commits are absent from that ZIP. Never relabel it as current HEAD. Permanent-key rules and fingerprints are in `AGENT-HANDOVER.md` and `releaseVerificationAndDeployment/signing-identity.json`. Never print or commit private keys or encoded secrets.

Use `releaseVerificationAndDeployment/build_mod.ps1` for required sequential gates. Run one build at a time and poll its actual live handle to completion. Static checks, signed packages and prepared fixtures are not physical acceptance. Preserve unrelated files, stage exact paths and update the handover with changed behaviour, validation, remaining failures and the next concrete action.

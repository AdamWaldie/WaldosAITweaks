# Contribution guidance

- Every SQF file must begin with a useful documentation block naming `WaldoTheWarfighter` as author and documenting purpose, locality, repeat/JIP behaviour, arguments, return value, callers and an example.
- AI operations must be finite, locality-aware and immediately interruptible by Zeus or a newer mission order.
- Preserve feature gates and public intent. Do not add global per-frame scans or permanent movement controllers.
- Static tests are regression gates. Arma behavior requires the checked-in dedicated-server/client audit and fresh runtime evidence.
- Optional AI addons receive explicit ownership; never run two movement controllers over the same group.

- Follow CONTRIBUTING.md for source, feature-guide and PR documentation requirements.
- Run the complete build_mod.ps1 gates, including config, documentation/link checks, CBA/Zeus/script parity and static performance regression checks. HEMTT compilation/lint and FSM validation are mandatory.
- Never blanket-accept performance findings or claim static/package success as live tactical acceptance. Preserve the exact packaged candidate for audit and release.

## Standing user scope and priorities

These are established user requirements, not new discoveries. Carry them into every follow-up and handoff. The latest direct user instruction overrides a stale status note.

- IKMS (the melee reference), WBK Droids and WBK Zombies are **compatibility-only**. Review their ownership, animation and handover requirements, but do not count them as general tactical implementations, behaviour parity or feature-completion progress. Compatibility expansion is last. Existing specialist takeover safeguards remain required throughout.
- Prioritise FSM decision/execution ownership and the **entire HBQ driving source**. Every source function and every major branch needs a recorded disposition, including startup/locality, settings, terrain/navigation areas, predictive obstacles, gates, traffic, jams, recovery, crew policy, damage policy, diagnostics and performance. A selected-function review is not a whole-mod review. Methods that violate physical recovery or mission authority must be redesigned or explicitly rejected, not silently omitted or copied.
- Build reliable individual behaviours before composing pairs, squads, multi-squad coordination and combined arms. Preserve the dynamic intent and the real execution path of source methods. Filename association earns no implementation credit.
- CBA settings own addon configuration, feature enablement and tuning. Native Zeus/ZEN modules issue **behaviour tasks**, not settings or diagnostics panels. Follow the source task pattern: explicit group, destination/area or behaviour-specific world target, scoped task parameters, authenticated server dispatch and current-owner executor. Do not recreate ordinary-driving enable/release/inspect modules. HBQ navigation corridors and LAMBS CQB/garrison/defend task modules are reference examples; copy intent, not unsafe implementation shortcuts. A task's radius or destination parameter is not a global addon setting. Trace registration, labelled controls, payload, authoritative validation, owner execution, acknowledgement, interruption, cleanup and repeat/JIP behaviour. Never present an unavailable behaviour as working.
- No implementation-completion percentage is justified by source inventory, setting coverage, registered tests or file-review counts. Distinguish implemented source, offline validation, narrow physical evidence, retained failures and complete acceptance.
- Current audits are held by user request. Do not launch until the user resumes them. Audit stop/restart permission is already granted when runs are authorised. Stop only the identified audit processes and verify that they actually exit. Normal and headless-client cases use separate batches.
- The chat may be attached to a different repository. WAIT is currently at `C:/Users/AdamW/AppData/Local/Temp/WaldosAITweaks`, remote `https://github.com/AdamWaldie/WaldosAITweaks.git`. Before every Git mutation, verify the actual repository root, remote, branch and intended PR. Do not commit WAIT work to another checkout. PRs 12 and 13 were merged. Continued work starts from merged main on a new branch and belongs in a new PR. Verify the live PR state before updating it.

Current local source comparison: `.qa/workshop-comparison-20261014/WORKSHOP-COMPARISON.md`. Its deep-review items remain open. The source index is structural evidence only. Preserved Pinned Down sources are under `C:/Users/AdamW/Documents/AI-Reference-Archives/PinnedDown/20261013-013708`; verify its manifest before relying on it. Keep raw sources and assets out of published product content.
- Explicit Garrison task teleport placement is permitted as an operator-selected, clearly labelled option (user clarification 2026-10-14). Keep walking garrison as a distinct mode. This exception does not authorise teleport recovery, natural building routing, CQB clearance, physical-audit completion. Other module shortcuts may be exposed as explicit task options when their production executor supports them; do not silently choose a fallback target or safety policy. Do not treat source shortcuts as universally forbidden or permitted: record each task's purpose and the user's scoped decision.

- Consolidate source modules with the same behaviour intent into one WAIT task surface. Garrison combines useful source methods through labelled per-task options, not duplicate source-branded modules. Keep walking/instant placement distinct; assess height preference, patrol, exit conditions, static-weapon use and casualty refill against real executor support. Use selectors for mutually exclusive modes and toggles for independent choices. Defence lines, object defence and physical clearance remain separate intents. Never add a cosmetic option without authoritative parsing, owner execution and cleanup.

## GitHub Actions usage

- Batch related implementation work locally; do not push every small commit or every goal continuation. Push a coherent review checkpoint after local validation, or when the user requests it. Avoid repeated remote reruns without diagnosing the failure first.
- Validation runs automatically for main and ready pull requests. Draft PRs use local gates; a remote draft check requires deliberate workflow_dispatch. Do not mark a PR ready merely to cause a build. Ready-for-review must trigger the complete validation pipeline.
- Keep validation concurrency scoped to the workflow and PR/ref, cancel superseded validation runs, and preserve full release/signed-candidate checks. Do not use skip-ci messages or remove tests to conceal failures.
- Pass the read-only GitHub token to the HEMTT installer to avoid unauthenticated release API rate limits; never print it.

## Continuation handover

Read `AGENT-HANDOVER.md` for the current review checkpoint, local evidence paths and outstanding work. Revalidate live Git/PR and process state before relying on its snapshot. The handover and engineering reference reviews are not player-facing package content.

## Low-credit checkpoint and handover

User standing instruction: at very low remaining credits, commit safe work and provide another agent with a continuation prompt containing the full goal, current context and source/register references. Use 20 remaining credits as the default threshold unless the user changes it.

Check the live account usage tool before a long work batch and when resuming after a substantial break. Do not claim continuous monitoring between turns. Missing usage data is unknown, not zero. At or below the threshold, finish the current bounded operation safely, inspect any live tool/process handle, and avoid starting another large batch. Preserve unrelated changes; verify the repository/PR boundary and commit only the intended work. Record unfinished work and failed checks rather than claiming completion.

Refresh AGENT-HANDOVER.md and AGENT-CONTINUATION-PROMPT.md with the unchanged full objective, current branch/commit/PR, local versus remote state, exact artifacts, validation limits, active processes, pending approvals, audit authorisation and next action. Include the private ledger/mod list, source inventory, review registers and archive locations. Verify referenced files and provide the commit plus prompt link to the user. Do not push solely for bookkeeping, mark the goal complete, change audit permission, expose secrets, or redeem usage resets without the required user instruction.

# Audit error ledger

Every batch keeps its original RPT files and generated report. Repeated trace lines are not separate root causes. A fix is closed only after an exact packaged candidate completes the relevant retest without recurrence; static checks alone leave it pending.

## Batch runtime-20261010-214346-432

Candidate: clean `89812ab`. Full batch remains active. Snapshot checked 2026-10-10; counts may grow until completion.

| ID | Evidence | Cause and action | Retest status |
| --- | --- | --- | --- |
| E1 | Client RPT lines 759-764, 765-770 777-782 and 789-794; 22:14:46, 22:18:20, 22:24:19 and 22:26:56 | Four notification incidents: body string passed into a numeric text-size parameter. Corrected title/body line arrays in `acc9b93`. | Static/package gates passed; fresh packaged live retest pending. Original batch retains old payload. |
| E2 | Server RPT line 670; startup `a3_characters_f` dependency warning | Root cause unresolved. Previously observed in both addon-present and addon-absent candidates. Do not suppress or infer a missing installed base addon from this warning alone. | Runtime integrity and strict performance acceptance remain blocked. |
| F1 | Building-contact cases and user screenshot/intervention report | Obstructed sightline and inherited disabled Contact gate. User moved the hostile to permit visibility. Fixture repaired in `fba8d86`; current cases are manually assisted. | Unassisted contact/entry retest pending; old recorded results remain intact. |
| F2 | Two-/six-person clearance outcome sampled while RUNNING; terminal INCOMPLETE followed one second later | Audit terminal-settlement race repaired in `f16e084`. | Retest pending. Physical room-visit failures remain separate unresolved behaviour failures. |

Other failed assertions remain in the batch report for individual review. Object-not-found network messages are retained as observations; no proven cause or harmless classification is assigned here.

## Earlier batches

| Batch / candidate | Recorded runtime evidence | Outstanding follow-up |
| --- | --- | --- |
| runtime-20261010-123843-079 / 20fd9d7 | Completed; 755 checks, 62 server findings, no matched SQF/fatal errors, one loader warning | Behaviour failures and loader warning remain unresolved or awaiting repaired-candidate retest. |
| runtime-20261010-143646-413 / c9f6657 | Incomplete; 171 checks, 19 failures, no matched SQF/fatal errors, one loader warning | Missing completion evidence; no acceptance inferred. |
| runtime-20261010-151701-617 / 62d86bd | Completed; 300 checks, native HC registration prerequisite failed, no matched SQF/fatal errors, one loader warning | Native registration diagnostics queued; transfers/adoption not accepted. |

See [completion status](COMPLETION-STATUS.md) for category progress and [performance validation](PERFORMANCE-VALIDATION.md) for strict comparison requirements.

The reporter also rejects standalone parameter/type/generic/arithmetic error lines when an expression/position prefix is absent. Raw trace-line counts are not incident or root-cause counts.

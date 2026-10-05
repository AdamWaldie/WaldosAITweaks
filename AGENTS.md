# Contribution guidance

- Every SQF file must begin with a useful documentation block naming `WaldoTheWarfighter` as author and documenting purpose, locality, repeat/JIP behaviour, arguments, return value, callers and an example.
- AI operations must be finite, locality-aware and immediately interruptible by Zeus or a newer mission order.
- Preserve feature gates and public intent. Do not add global per-frame scans or permanent movement controllers.
- Static tests are regression gates. Arma behavior requires the checked-in dedicated-server/client audit and fresh runtime evidence.
- Optional AI addons receive explicit ownership; never run two movement controllers over the same group.

- Follow CONTRIBUTING.md for source, feature-guide and PR documentation requirements.
- Run the complete build_mod.ps1 gates, including config, documentation/link checks, CBA/Zeus/script parity and static performance regression checks. HEMTT compilation/lint and FSM validation are mandatory.
- Never blanket-accept performance findings or claim static/package success as live tactical acceptance. Preserve the exact packaged candidate for audit and release.

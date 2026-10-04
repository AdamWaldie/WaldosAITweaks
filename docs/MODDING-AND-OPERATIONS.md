# Mod build, testing and architecture

WAIT requires Arma 3 2.18+, CBA and ZEN. ACE, COMPAT, external controller and specialist unit mods remain optional.
The production addon is `addons/main`, with the virtual path `z\waldo_ai_tweaks\addons\main`.
Missions load the packaged mod. CBA XEH runs initialization and CBA Settings exposes the existing
feature names. Dynamic AA/AO and WMP mission systems remain outside this repository.

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
Dependencies default to installed CBA and Zeus Enhanced Workshop folders; `-Mods` accepts an explicit
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

| Domain | Preferred method | Conversion and acceptance decision |
| --- | --- | --- |
| Immediate danger and contact | Engine danger events/FSM with small owner-local decisions | Examine COMPAT danger causes and interrupts; introduce an original fallback only after native movement and Zeus handover tests |
| Squad tactics and combined arms | Event-fed shared opportunity registry, budgeted decisions, finite leases | Keep communication opportunistic; no compulsory rally or assembly barrier; casualty replacements update roles without restarting the whole attack |
| CQB and garrison | Cached building topology and engine navigation; finite team movement | COMPAT task integration remains preferred when loaded. Validate rooms, floors, doorway traversal and exit across different buildings before replacing the fallback |
| Turret and launcher policy | Config where supported, owner-local skills for runtime settings | Config cannot be reversed by a CBA toggle. Any new config component must document that distinction and avoid stacking installed COMPAT companion changes |
| Vehicle driving | Native route commands plus sparse progress/obstruction events | Use external controller route-memory ideas; preserve intentional roadblocks, crew ownership and Zeus orders; recovery cannot teleport, repair or remove obstacles |
| Air combat | Native flight, weapon-config capabilities and sparse finite attack intent | Match weapon, envelope and terrain clearance; aircraft own aiming and actual ordnance. Avoid fixed-angle projectile creation or repeated short steering points |
| Civilians and specialist actors | Local danger events and explicit external ownership | external controller/external controller animations and combat own their actors; WAIT yields instead of layering a competing tactical controller |
| Skills, lighting and dispersion | CBA settings plus equipment/locality events and cached profiles | Avoid rescanning every unit every frame; preserve WMP authored skill values where ownership is delegated |

Retain feature gates, intent, locality, cancellation, casualty continuation and diagnostics through
every conversion. Measure native AI, WAIT fallback, and relevant external-mod handover separately.
The agreed initial budget is <=5% added median and <=10% added p95 frame time, starting with 50
mixed groups. Protect the observer throughout measurement and record server and client separately.
An isolated fast showcase is insufficient evidence for scale.

## Source references

- [Bohemia: creating an addon](https://community.bohemia.net/wiki/Arma_3%3A_Creating_an_Addon): mod folders, PBOs, config, keys and addon tools.
- [Bohemia: FSM](https://community.bohemia.net/wiki/FSM) and [execFSM](https://community.bohemia.net/wiki/execFSM): state execution and scripted lifecycle semantics.
- [HEMTT configuration](https://hemtt.dev/configuration/index.html), [version](https://hemtt.dev/configuration/version.html), [build](https://hemtt.dev/commands/build.html) and [release](https://hemtt.dev/commands/release.html): project layout, package outputs and signing.
- [CBA settings implementation](https://github.com/CBATeam/CBA_A3/blob/master/addons/settings/fnc_addSetting.sqf): global settings and callback contract.
- [COMPAT danger integration](https://github.com/nk3nny/external controllerDanger/blob/master/addons/danger/CfgVehicles.hpp): engine `fsmDanger` replacement on soldier and civilian bases.
- [COMPAT source](https://github.com/nk3nny/external controllerDanger): inspect ownership, tasks and licensing before implementation or adaptation.
- WMP local `releaseVerificationAndDeployment/launch_pr_review_audit.ps1`, `testing.yml` and `deploy.yml`: fresh staging, readiness, dedicated/client operation and published-release flow examined for this pipeline.

These references guide original implementation. Existing compatibility detection does not mean a
Workshop feature has been recreated or that its physical behaviour passes WAIT acceptance.

## Source and documentation gates

The local build and both build/candidate workflows enforce SQF validation for production and audit helpers, config structure, opening source-header contracts, local documentation/image links, shared CBA/Zeus/script setting parity and recurring performance risks. HEMTT compiles and lints addon SQF/config; its warnings remain visible for review. The static performance scanner rejects new high-severity patterns and starts with no accepted exceptions. It does not measure frame time.

See [contribution requirements](../CONTRIBUTING.md) for feature guides, PR evidence and multiplayer acceptance. [The settings reference](SETTINGS-REFERENCE.md) is generated from the live tuning specification. Run `python releaseVerificationAndDeployment/zeus_script_parity_checker.py --write-reference` after editing that specification. CI rejects a stale reference, duplicate keys, invalid defaults or missing function exports.

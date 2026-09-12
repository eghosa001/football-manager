# Football Dynasty

A deterministic, simulation-first football-management game built with Godot 4.7.2.

## Current implementation

The original Phase 0–14 source plan is implemented and covered by automated acceptance at RC3. Release hardening now adds clean hosted platform execution, production performance/save contracts, global UI readability/touch-target enforcement and installable Android debug artifacts. Physical-device signing, assistive-technology review and representative end-user hardware acceptance remain human release evidence rather than missing game systems. See `docs/RC3_SOURCE_COMPLETION.md`, `docs/RELEASE_GATES.md` and `docs/REMEDIATION_72_MATRIX.md`.

The current build can:

- deterministically generate countries, clubs, players, staff, contracts, competitions and league fixtures;
- simulate canonical event-driven football matches and reproduce them exactly from seeds;
- run calendar-driven seasons, league tables, promotion/relegation and historical records;
- save/reload exact typed state through atomic file and Godot-SQLite persistence adapters;
- model player attributes, training, development, aging, injuries, youth intake, retirement and staff conversion;
- process contracts, free agents, transfers and loans through balanced ledger accounting;
- maintain AI squad depth and positional viability;
- model sponsorship, commercial/ticket income, prize money, wages, operating costs, debt, budgets, stadiums, facilities, boards and supporters;
- assign manager tactical identities, formations, roles, duties, mentality, tempo, pressing and familiarity;
- run detailed spatial matches with normalized 2D coordinates, pressure, passing lanes, goalkeeper positioning and set pieces while preserving the canonical event schema;
- expose career dashboard, squad, tactics, medical, schedule, competitions, transfers, staff, finances, world search, 2D viewer and match analysis;
- evolve bounded morale, confidence and reputation; create relationships, title-race rivalries, manager career/trophy histories, awards, legends and causal news records;
- load and author whitelisted JSON data mods without allowing arbitrary save/economy mutation;
- provide a graphical Database & Mod Editor for entity patches/additions, name pools, graphics overrides, validation and import/export;
- persist accessibility/settings options and provide English, French and Portuguese top-level UI localization;
- enforce readable UI defaults, keyboard focus, wrapped long labels and production-sized desktop/mobile interaction targets;
- migrate legacy saves through the current schema migration path and recover from a corrupt primary save through the atomic backup;
- keep expensive continuous/detailed simulation as a viewed-match tier while unattended seasons use cheaper event/abstract/aggregate tiers;
- build Windows x86_64 and Linux/X11 x86_64 release candidates from committed export presets;
- execute the packaged Linux build on GitHub-hosted Linux and the Windows installer on a clean GitHub-hosted Windows runner;
- build and retain an installable Android debug APK for mobile-relevant pull requests and main changes;
- run release smoke, save-safety, mobile, readability, performance and regression validation in CI;
- validate original Phases 12–14 with a dedicated living-world/modding/polish completion gate;
- expose isolated 100-season, 100,000-match continuous and cross-tier release gates.

Expanded-world mode is regression-tested at 20 countries, 756 clubs and 21,168 players with continental competitions and exact save/reload continuation.

## Release candidate

The project version is `1.0.0-rc3`. Windows, Android, iOS and macOS version metadata in `export_presets.cfg` and the Windows Inno Setup installer are aligned to RC3.

`.github/workflows/ci.yml` is the authoritative self-hosted Windows validation workflow. It starts from a clean checkout, runs the complete automated regression pack, verifies a freshly downloaded pinned Godot-SQLite dependency by SHA-256, builds both desktop release targets, smoke-tests the Windows package and can run the heavy release gates through workflow-dispatch inputs.

`.github/workflows/hosted-validation.yml` runs on GitHub-hosted Ubuntu, includes export templates, builds the Linux package, executes the packaged binary on Linux with normal and offline environments, records hashes/logs and uploads the Linux RC evidence.

`.github/workflows/fresh-windows-release.yml` builds the Windows release on a clean GitHub-hosted Windows environment, creates the Inno Setup installer, performs a silent installation smoke test and uploads checksummed release evidence.

`.github/workflows/debug-apk.yml` validates the Android/mobile contracts, builds a real debug APK on GitHub-hosted Linux and uploads the APK plus SHA-256 for device acceptance. `.github/workflows/mobile.yml` remains the lightweight preset/configuration validation path.

`.github/workflows/rc3-heavy-gates.yml` isolates the expensive 100,000-match distribution, cross-tier equivalence and 100-season career/economy gates from ordinary commits. The historical RC3 heavy run passed all three plus source-cleanliness verification on commit `83d1debacac5ac896a41e646dd0aa8031df21ae5`; material simulation changes after that commit require the heavy workflow to be rerun on the final RC commit before promotion.

A successful automated export still does not replace physical-device signing, screen-reader review or representative consumer-hardware acceptance. Those final evidence gates are listed in `docs/RELEASE_GATES.md`.

## Run

Install Godot 4.7.2 and open `project.godot`, or run:

```bash
godot --path .
```

The main scene opens the career menu. Create a career to choose a club from the launch database; Continue advances the calendar and simulates scheduled matches. Completed seasons roll over automatically at July 1. The application does not require a network service to boot or use local saves.

## Persistence

`SaveRepository` is the storage boundary. `SaveStore` provides atomic typed local saves with last-known-good backup recovery and schema migration. `SqliteSaveStore` supports Godot-SQLite v4.9 when its addon is present at `res://addons/godot-sqlite/`; authoritative CI removes any stale addon, downloads the pinned release and verifies its SHA-256 before the live SQLite round-trip test. The third-party binary is not committed to this repository.

## Modding

`ModLoader` accepts JSON patches only for explicit whitelisted world fields and clamps gameplay values to safe ranges. `ModEditor` creates, validates, exports and re-imports compatible mod files. The career-menu Database & Mod Editor provides a graphical authoring path. Unsupported fields such as club cash are rejected before mutation.

## Tests

Fast/core regression suites:

```bash
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/phase3_test_runner.gd
godot --headless --path . --script res://tests/phase45_test_runner.gd
godot --headless --path . --script res://tests/phase67_test_runner.gd
godot --headless --path . --script res://tests/phase89_test_runner.gd
godot --headless --path . --script res://tests/phase1011_test_runner.gd
godot --headless --path . --script res://tests/phase1214_completion_test.gd
godot --headless --path . --script res://tests/ui_readability_test.gd
godot --headless --path . --script res://tests/performance_baseline_test.gd
godot --headless --path . --script res://tests/long_save_growth_test.gd
godot --headless --path . --script res://tests/production_readiness_contract_test.gd
```

SQLite integration, with the Godot-SQLite addon installed:

```bash
godot --headless --path . --script res://tests/sqlite_integration_test.gd
```

Heavy release validation:

```bash
godot --headless --path . --script res://tests/continuous_distribution_gate.gd
godot --headless --path . --script res://tests/cross_tier_regression.gd
godot --headless --path . --script res://tests/full_career_soak.gd
```

The continuous distribution gate is the 100,000-match detailed-engine release calibration. Cross-tier regression compares the detailed/event/abstract/aggregate populations. The full career soak exercises 100 seasons through the canonical career lifecycle. These gates are intentionally separated from ordinary per-commit validation because they are expensive.

## Architecture

Simulation code has no dependency on scenes, rendering or persistence adapters. Application services coordinate season/career progression and expose read-only queries to the UI. Living-world updates consume completed domain state and emit structured causal records; news is a consumer of those records rather than a simulation trigger. `MatchEngineRouter` is the stable tier boundary: detailed viewed matches use the continuous engine while background workloads use cheaper event/abstract/aggregate tiers and preserve the same logical result contract. Career-cycle and player-lifecycle production entry points likewise use stable facades rather than importing version-numbered implementation files directly.

See `docs/AUDIT_AND_ROADMAP.md` for the architecture audit and `docs/RC3_SOURCE_COMPLETION.md` for the RC3 completion matrix.

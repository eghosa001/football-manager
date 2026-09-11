# Football Dynasty

A deterministic, simulation-first football-management game built with Godot 4.7.2.

## Current implementation

The original Phase 0–14 source plan is implemented and covered by automated acceptance at RC3. The remaining release work is platform evidence rather than missing game-system phases: clean-machine installation, actual Linux runtime/offline/save validation, interactive accessibility review, representative minimum-hardware profiling, and real mobile/signing checks if mobile is promoted to a release target. See `docs/RC3_SOURCE_COMPLETION.md`, `docs/RELEASE_GATES.md` and `docs/REMEDIATION_72_MATRIX.md` for the evidence and remaining external gates.

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
- migrate legacy saves through the current schema migration path;
- keep expensive continuous/detailed simulation as a viewed-match tier while unattended seasons use cheaper event/abstract/aggregate tiers;
- build Windows x86_64 and Linux/X11 x86_64 release candidates from committed export presets;
- run release smoke, save-safety, mobile-preset and regression validation in CI;
- validate original Phases 12–14 with a dedicated living-world/modding/polish completion gate;
- expose isolated 100-season, 100,000-match continuous and cross-tier release gates.

Expanded-world mode is regression-tested at 20 countries, 756 clubs and 21,168 players with continental competitions and exact save/reload continuation.

## Release candidate

The project version is `1.0.0-rc2-dev`. `export_presets.cfg` defines Windows Desktop and Linux/X11 x86_64 release exports.

`.github/workflows/ci.yml` is the authoritative self-hosted Windows validation workflow and builds both desktop release targets, smoke-tests the Windows package, validates SQLite and can run the heavy release gates through workflow-dispatch inputs. `.github/workflows/hosted-validation.yml` supplies fast GitHub-hosted Linux regression coverage using the same Godot 4.7.2 engine version. `.github/workflows/mobile.yml` validates mobile export configuration when mobile/export/UI-related files change.

`.github/workflows/rc3-heavy-gates.yml` isolates the expensive 100,000-match distribution, cross-tier equivalence and 100-season career/economy gates from ordinary commits. The RC3 heavy run passed all three plus source-cleanliness verification on commit `83d1debacac5ac896a41e646dd0aa8031df21ae5`.

A successful export is not the same as target-platform acceptance. Linux runtime execution, clean-machine Windows installation, real mobile-device testing and platform signing remain explicit release gates in `docs/RELEASE_GATES.md`.

## Run

Install Godot 4.7.2 and open `project.godot`, or run:

```bash
godot --path .
```

The main scene opens the career menu. Create a career to choose a club from the launch database; Continue advances the calendar and simulates scheduled matches. Completed seasons roll over automatically at July 1. The application does not require a network service to boot or use local saves.

## Persistence

`SaveRepository` is the storage boundary. `SaveStore` provides atomic typed local saves with last-known-good backup recovery and schema migration. `SqliteSaveStore` supports Godot-SQLite v4.9 when its addon is present at `res://addons/godot-sqlite/`; CI downloads the pinned release and verifies its SHA-256 before the live SQLite round-trip test. The third-party binary is not committed to this repository.

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

# Football Dynasty

A deterministic, simulation-first football-management game built with Godot 4.7.2.

## Current implementation

The project is a playable release-candidate prototype, not a completed implementation of the original phases 0–14. Core career and simulation services exist, with remaining work concentrated in continuous-match validation/convergence, content scale, graphical mod authoring, full localization, accessibility, presentation and target-device release acceptance. See `docs/PRODUCTION_PROGRESS.md` and `docs/REMEDIATION_72_MATRIX.md` for verified changes and remaining gates.

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
- persist accessibility/settings options and provide English, French and Portuguese top-level UI localization;
- migrate legacy saves through the current schema migration path;
- keep expensive continuous/detailed simulation as a viewed-match tier while unattended seasons use cheaper event/abstract/aggregate tiers;
- build Windows x86_64 and Linux/X11 x86_64 release candidates from committed export presets;
- run release smoke, destructive-save, mobile-preset and regression validation in CI;
- expose explicit 100-season, 100,000-match continuous and cross-tier release gates.

## Release candidate

The project version is `1.0.0-rc2-dev`. `export_presets.cfg` defines Windows Desktop and Linux/X11 x86_64 release exports.

`.github/workflows/ci.yml` is the authoritative self-hosted Windows validation workflow and builds both desktop release targets, smoke-tests the Windows package, validates SQLite and can run the heavy release gates through workflow-dispatch inputs. `.github/workflows/hosted-validation.yml` supplies GitHub-hosted Linux regression coverage using the same Godot 4.7.2 engine version. `.github/workflows/mobile.yml` validates the mobile export configuration.

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

`ModLoader` accepts JSON patches only for explicit whitelisted world fields and clamps gameplay values to safe ranges. `ModEditor` creates, validates, exports and re-imports compatible mod files. Unsupported fields such as club cash are rejected before mutation.

## Tests

Fast/core regression suites:

```bash
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/phase3_test_runner.gd
godot --headless --path . --script res://tests/phase45_test_runner.gd
godot --headless --path . --script res://tests/phase67_test_runner.gd
godot --headless --path . --script res://tests/phase89_test_runner.gd
godot --headless --path . --script res://tests/phase1011_test_runner.gd
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

Simulation code has no dependency on scenes, rendering or persistence adapters. Application services coordinate season/career progression and expose read-only queries to the UI. Living-world updates consume completed domain state and emit structured causal records; news is a consumer of those records rather than a simulation trigger. `MatchEngineRouter` is the stable tier boundary: detailed viewed matches use the continuous engine while background workloads use cheaper event/abstract/aggregate tiers and preserve the same logical result contract.

See `docs/AUDIT_AND_ROADMAP.md` for the architecture audit and extended development roadmap.

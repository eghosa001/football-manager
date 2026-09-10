# Football Dynasty

A deterministic, simulation-first football-management game built with Godot 4.7.2.

## Current implementation

The project is a playable release-candidate prototype, not a completed implementation of the original phases 0–14. Core career and simulation services exist, with remaining work in continuous match simulation, content scale, graphical mod authoring, full localization and presentation. See docs/PRODUCTION_PROGRESS.md for verified changes and remaining gates.

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
- migrate schema-v1 saves to the Phase 10 schema-v2 living-world collections;
- keep expensive spatial simulation as a detailed-match tier while unattended seasons use the cheaper tactical tier;
- build Windows x86_64 and Linux x86_64 release candidates from committed export presets;
- smoke-test the Linux release offline and expose an explicit offline release contract;
- run a 100-season release soak and the 100,000-match statistical release gate.

## Release candidate

The project version is `1.0.0-rc2-dev`. `export_presets.cfg` defines Windows Desktop and Linux/X11 x86_64 release exports. `.github/workflows/release-candidate.yml` provides a manual packaging workflow that builds both platforms, smoke-tests Linux offline, generates SHA-256 integrity files and uploads build artifacts.

The normal Phase 10/11 branch validation also builds both release targets so export configuration regressions are caught before merge.

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

Full match validation:

```bash
godot --headless --path . --script res://tests/test_runner.gd -- --full-match-validation
```

The standard match suite samples 2,000 abstract matches and 250 detailed spatial matches. The full release gate runs 100,000 abstract matches. Phase 10/11 also runs a 100-season integrated career/save soak.

## Architecture

Simulation code has no dependency on scenes, rendering or persistence adapters. Application services coordinate season/career progression and expose read-only queries to the UI. Living-world updates consume completed domain state and emit structured causal records; news is a consumer of those records rather than a simulation trigger. Background fixtures use the tactical engine while detailed viewed matches can use the spatial engine, both preserving the same logical event contract.

See `docs/AUDIT_AND_ROADMAP.md` for the architecture audit and extended development roadmap.

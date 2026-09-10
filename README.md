# Football Dynasty

A deterministic, simulation-first football-management game built with Godot 4.7.2.

## Current implementation

Phases 1–9 are implemented: Deterministic World Model, Abstract Match Engine, Season & Persistence Core, Player Lifecycle, Squad Building/Contracts/Transfer Market, Club Economy & Institutions, Tactics & Manager AI, Spatial Match Simulation, and Career UI/2D Viewer/Analysis.

The current vertical slice can:

- deterministically generate countries, clubs, players, staff, contracts, competitions and league fixtures;
- simulate canonical event-driven football matches and reproduce them exactly from seeds;
- run calendar-driven seasons, league tables, promotion/relegation and historical records;
- save/reload exact typed state through atomic file and Godot-SQLite persistence adapters;
- model player attributes, training, development, aging, injuries, youth intake, retirement and staff conversion;
- process contracts, free agents, transfers and loans through balanced ledger accounting;
- maintain AI squad depth and positional viability;
- model sponsorship, commercial and ticket income, prize money, wages, operating costs, debt, budgets, stadiums, facilities, boards and supporters;
- assign manager tactical identities, formations, roles, duties, mentality, tempo, pressing and familiarity;
- select role-aware lineups and produce tactically distinct match styles and ratings;
- run detailed spatial matches with normalized 2D player coordinates, pressure, passing lanes, goalkeeper positioning and set pieces while preserving the canonical event schema;
- expose a thin career UI for dashboard, squad, tactics, medical, schedule, competitions, transfers, staff, finances and world search;
- render detailed-match spatial frames in a 2D pitch viewer and expose post-match shots, set pieces and spatial analysis;
- keep expensive spatial simulation as a detailed-match tier while unattended seasons use the cheaper tactical tier;
- pass persistence, population, squad/budget, economy, tactical-style and spatial acceptance tests;
- optionally run the full 100,000-match validation through GitHub Actions.

## Run

Install Godot 4.7.2 and open `project.godot`, or run:

```bash
godot --path .
```

The current main scene opens the Phase 9 career shell and generates a deterministic sample career world plus a detailed spatial match for the analysis viewer.

## Persistence

`SaveRepository` is the storage boundary. `SaveStore` provides the dependency-free atomic binary save implementation used by default. `SqliteSaveStore` supports Godot-SQLite v4.9 when its addon is present at `res://addons/godot-sqlite/`; CI downloads that release and verifies its SHA-256 before running the live SQLite round-trip test. The third-party binary is not committed to this repository.

## Tests

```bash
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/phase3_test_runner.gd
godot --headless --path . --script res://tests/phase45_test_runner.gd
godot --headless --path . --script res://tests/phase67_test_runner.gd
godot --headless --path . --script res://tests/phase89_test_runner.gd
```

SQLite integration, with the Godot-SQLite addon installed:

```bash
godot --headless --path . --script res://tests/sqlite_integration_test.gd
```

Full Phase 2 statistical acceptance harness:

```bash
godot --headless --path . --script res://tests/test_runner.gd -- --full-match-validation
```

The normal test suite samples 2,000 abstract matches and 250 detailed spatial matches to keep pull-request CI practical. The full flag runs 100,000 abstract matches. CI imports the project headlessly before tests so parser/import failures are caught first.

## Architecture

Simulation code has no dependency on scenes, rendering or persistence adapters. Application services coordinate season/career progression and expose read-only queries to the UI. Background fixtures use the tactical engine; detailed viewed matches can use the spatial engine. Both preserve the canonical logical event contract consumed by statistics and analysis.

See `docs/AUDIT_AND_ROADMAP.md` for the design audit, corrected sequencing and development roadmap.

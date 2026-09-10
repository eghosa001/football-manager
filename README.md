# Football Dynasty

A deterministic, simulation-first football-management game built with Godot 4.7.2.

## Current implementation

Phases 1–3 are implemented: Deterministic World Model, Abstract Match Engine, and Season & Persistence Core.

The current vertical slice can:

- deterministically generate 4 countries, 80 clubs, 2,000 players, 400 staff, contracts, competitions and 1,520 league fixtures;
- validate entity references and deterministic IDs;
- build double round-robin league schedules and league tables;
- select lineups and simulate possession sequences, passes, shots, goals, cards and substitutions;
- derive match statistics and player ratings from the canonical event stream;
- reproduce worlds and matches exactly from their seeds;
- assign calendar matchdays and advance the world by fixture date;
- complete leagues and entire seasons, record champions and final tables, and roll into the next season;
- apply configurable promotion/relegation between adjacent competition tiers;
- save and reload exact Godot Variant state through a persistence repository abstraction;
- perform atomic file saves with validated temporary files and last-known-good backup recovery;
- persist the same typed payload through the Godot-SQLite adapter;
- retain multi-season historical records;
- pass a 10-season unattended save/reload/rollover soak test;
- run headless tests and a broad statistical match-validation harness;
- optionally run the full 100,000-match validation through GitHub Actions.

## Run

Install Godot 4.7.2 and open `project.godot`, or run:

```bash
godot --path .
```

The current UI is intentionally only a smoke-test screen. It generates the world and displays one deterministic sample match.

## Persistence

`SaveRepository` is the storage boundary. `SaveStore` provides the dependency-free atomic binary save implementation used by default. `SqliteSaveStore` supports Godot-SQLite v4.9 when its addon is present at `res://addons/godot-sqlite/`; CI downloads that release and verifies its SHA-256 before running the live SQLite round-trip test. The third-party binary is not committed to this repository.

## Tests

Core Phase 1/2 tests:

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

Phase 3 season/persistence acceptance tests:

```bash
godot --headless --path . --script res://tests/phase3_test_runner.gd
```

SQLite integration, with the Godot-SQLite addon installed:

```bash
godot --headless --path . --script res://tests/sqlite_integration_test.gd
```

Full Phase 2 statistical acceptance harness:

```bash
godot --headless --path . --script res://tests/test_runner.gd -- --full-match-validation
```

The normal test suite samples 2,000 matches to keep pull-request CI practical. The full flag runs 100,000 matches. CI imports the project headlessly first so parser/import failures are caught before simulation tests run.

## Architecture

Simulation code has no dependency on scenes, rendering or persistence adapters. Application services coordinate season progression; persistence implementations conform to a repository boundary. All simulation randomness flows through `SeededRng`, making generated worlds, match outcomes and save/reload continuation reproducible from seeds.

See `docs/AUDIT_AND_ROADMAP.md` for the design audit, corrected sequencing and development roadmap.

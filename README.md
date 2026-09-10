# Football Dynasty

A deterministic, simulation-first football-management game built with Godot 4.7.2.

## Current implementation

Phase 1 (World Model) and Phase 2 (Abstract Match Engine) are implemented on the `phase-1-2-world-match-engine` branch.

The current vertical slice can:

- deterministically generate 4 countries, 80 clubs, 2,000 players, 400 staff, contracts, competitions and 1,520 league fixtures;
- validate entity references and deterministic IDs;
- build double round-robin league schedules and league tables;
- select lineups and simulate possession sequences, passes, shots, goals, cards and substitutions;
- derive match statistics and player ratings from the event stream;
- reproduce a match exactly from its seed;
- run headless tests and a broad statistical match-validation harness;
- optionally run the full 100,000-match validation through GitHub Actions.

## Run

Install Godot 4.7.2 and open `project.godot`, or run:

```bash
godot --path .
```

The current UI is intentionally only a smoke-test screen. It generates the world and displays one deterministic sample match.

## Tests

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

Full Phase 2 statistical acceptance harness:

```bash
godot --headless --path . --script res://tests/test_runner.gd -- --full-match-validation
```

The normal test suite samples 2,000 matches to keep pull-request CI practical. The full flag runs 100,000 matches.

## Architecture

Simulation code has no dependency on scenes or rendering. UI reads simulation outputs only. All randomness flows through `SeededRng`, making generated worlds and matches reproducible from seeds.

See `docs/AUDIT_AND_ROADMAP.md` for the design audit, corrected sequencing and development roadmap.

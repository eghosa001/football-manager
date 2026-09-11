# Production progress — 11 September 2026

The original `implementation` document defines Phases 0–14. RC3 now treats those phases as source-complete: the planned systems exist and are covered by automated contracts. Remaining release work is external/platform acceptance or future depth/content iteration, not an unimplemented original phase. See `RC3_SOURCE_COMPLETION.md` for the phase-by-phase matrix.

## RC3 completion work

- Hosted validation and self-hosted tooling are aligned on Godot 4.7.2.
- Pull requests use a fast focused gate instead of repeatedly running every historical suite. Full regression remains authoritative on `main`, and the self-hosted workflow accepts an optional isolated `tests/*.gd` script for failure reproduction.
- A one-shot `RC3 Heavy Acceptance` workflow isolates the expensive release tests from normal commits.
- Production match routing uses a stable event-engine boundary, and career/session code uses stable career-cycle and player-lifecycle boundaries rather than direct versioned imports.
- Career tab composition is registry-driven through a thin scene shell, removing the large application's hardcoded 14-tab composition while preserving existing screen behavior.
- Dense matchday lookup work was reduced by indexing club/player/competition data and registered players rather than repeatedly scanning the full launch-world arrays for each fixture.
- The original Phase 12–14 acceptance gate now exercises manager careers/living-world evolution, mod dependency/conflict/integrity rules, accessibility/settings bounds, localization coverage, career-screen composition, performance baselines and release/offline contracts.

## Implemented game scope

- Deterministic world generation, contracts, competitions, fixtures, league tables, calendar progression and save migration.
- Abstract/event and continuous spatial match simulation with deterministic seeds, persistent 2D state, tactical causality, statistics, substitutions, discipline and match analysis/viewer integration.
- Multi-season competition progression, cups, promotion/relegation, international/continental competition services and historical records.
- Training/development, medical/injuries, youth, retirement, staff conversion and long-run population behavior.
- Scouting, AI squad planning, valuation, bids, negotiation, contracts, loans/free agents and registration.
- Club ledger/economy, budgets, wages, tickets, sponsors/prize flows, debt, boards/supporters, facilities and stadium projects.
- Formations, tactical roles/instructions, familiarity and AI tactical choices.
- Management UI for the planned career surfaces, plus settings, autosave, help/tutorial and world search.
- Morale/happiness, relationships, manager market/careers, reputation, awards, legends, records and causal news/event consumption.
- Mod/database loading and validation, dependency/conflict/integrity contracts, graphics overrides, name pools, and a graphical Database & Mod Editor with import/export.
- English/French/Portuguese top-level localization and source-level accessibility controls for UI scale, font scale, contrast, reduced motion and screen-reader labels.

## Launch/content evidence

The standard eight-country launch world contains 324 clubs and 8,100 players. Expanded-world regression requires exactly 20 countries, 756 clubs and 21,168 players, with continental competitions, no same-club double-booking on a date, successful day progression and exact save/reload continuation.

The expanded configuration therefore meets the original v1.0 scale band for countries, clubs and players. It intentionally remains fictional and does not claim licensed real-world databases or exact licensed competition rules.

## Automated acceptance evidence

The repository includes the historical phase suites, remediation/polish/release-hardening suites, architecture convergence, save/registration/SQLite/mobile validation and the Phase 12–14 completion gate.

The isolated RC3 heavy workflow passed on commit `83d1debacac5ac896a41e646dd0aa8031df21ae5` under `4.7.2.stable.official.ed1daf0bf` on the self-hosted Windows x86_64 runner:

- continuous 100,000-match distribution gate — PASS;
- seeded cross-tier detailed/event/abstract/aggregate regression — PASS;
- full 100-season career/economy soak — PASS;
- tracked-source cleanliness after all heavy gates — PASS.

Later RC3 changes are architecture facades, acceptance tests and documentation unless otherwise stated. A change that materially alters match simulation or long-run career/economy behavior must explicitly retrigger the heavy workflow.

## Performance evidence

Recorded full-world profiling on the user's Windows machine found world creation at 7,369 ms, ordinary days at 119–138 ms, weekly processing at 3,456 ms and the 162-fixture opening matchday at 15,400 ms while other work was running. These are observations, not minimum-hardware guarantees.

RC3 additionally removes repeated full-world registered-player scans from dense matchdays. Representative minimum-spec profiling remains an external release gate because CI hardware is not a substitute for the declared customer hardware target.

## Remaining release acceptance — not source phases

1. Clean-machine Windows install, upgrade/uninstall and packaged offline new-career/save/reload session.
2. Actual Linux runtime, offline use and save round-trip on Linux hardware or a representative VM.
3. Keyboard-only navigation/focus-order review and real screen-reader testing, plus contrast/large-text visual inspection.
4. Representative minimum-hardware long-career and detailed-match profiling.
5. Real Android/iOS touch/performance and signing/notarization/TestFlight evidence only if those platforms are promoted to release targets.
6. Any product decision to replace the current serialized save payload with a fully normalized relational/event store. The current persistence boundary and migration path are implemented and tested; normalization is an architectural enhancement, not required for the original gameplay phases to function.

These items must remain visible until physically tested. Automated source completion must not be used to claim evidence that requires another operating system, installer environment, assistive technology or real device.

# Football Dynasty — Architecture Audit and Revised Roadmap

## Executive assessment

The design document has a strong simulation-first philosophy, good dependency direction, deterministic simulation requirements, and unusually strong long-save testing goals. Its largest weakness is sequencing: several systems are specified before the contracts/interfaces they depend on, while some acceptance gates are much heavier than the implementation stage they belong to.

This roadmap preserves the design goals but reduces rewrite risk.

## Section-by-section audit

### Sections 1–4: Vision, rules and architecture

**Keep.** The living-world vision and `UI -> Application -> Domain -> Data` dependency direction are the correct foundation.

**Change:** treat the repository structure as a target, not a requirement to create every empty folder immediately. Create folders when a real subsystem arrives.

### Sections 5–19: Entities, players, development and relationships

**Keep:** stable IDs, hidden attributes, player state separate from ability, continuous development, position familiarity and relationship graph.

**Change:** avoid a single giant `Player` persistence row. Keep identity/core player data separate from mutable condition, attributes, contract and historical statistics so save migrations remain manageable.

**Risk:** personality labels should remain presentation-derived exactly as specified; never persist labels as gameplay truth.

### Sections 20–48: Match simulation

**Keep:** events produce outcomes and statistics, not the reverse; deterministic seeds; xG based on situation before finishing execution; distinct pass failure vs receiver-control failure.

**Change:** Phase 2 should define a stable event schema early. The later spatial engine must be able to emit the same logical event types so analytics and history do not depend on which simulation tier produced a match.

**Contradiction:** role-aware player ratings are required in Section 46, but roles are not implemented until the original Phase 7. Phase 2 therefore uses neutral ratings only. Role-specific rating policies should plug in once roles exist.

**Performance:** 10–20 movement ticks per second is acceptable only for detailed matches. Background tiers must never inherit that cost.

### Sections 49–51: Competitions and scheduling

**Keep:** rules-driven competitions and configurable tie-breakers.

**Change:** model schedule generation separately from schedule constraints. The first generator only needs deterministic double round-robin support; rest windows, venue conflicts, continental dates and rescheduling belong in a later constraint solver.

### Sections 52–64: Transfers, contracts and finance

**Keep:** squad-need-driven transfer AI, imperfect knowledge and explicit financial accounts.

**Contradiction:** contracts exist in original Phase 1 and transfers in Phase 5, but the financial ledger arrives in Phase 6. Any money-changing contract or transfer operation implemented before the ledger would create a rewrite. Therefore early contracts are descriptive records only; financial execution begins only through a ledger interface.

### Sections 65–87: Reputation, youth, staff, boards, supporters, facilities, training, morale, news and history

**Keep:** these are the systems that will make long saves distinct.

**Change:** all slow-moving world metrics need bounded update rates and explicit decay/growth curves. Without caps and regression tests, 50–100 year saves will drift into extreme values.

**Change:** news must remain a consumer of domain events, never a trigger for simulation logic.

### Sections 88–95: Saves, migrations, simulation tiers, threading and scale

**Keep:** immutable starting database, mutable save state, atomic autosaves, simulation tiers, worker isolation and profile-before-native-optimization.

**Blocking decision:** the design specifies SQLite but does not name or vendor a Godot 4.7-compatible SQLite integration. Do not allow persistence code to leak into simulation entities while this dependency remains undecided. Repositories should be interfaces/adapters.

**Change:** architecture target and launch scale should be treated as benchmarks, not default loaded-world sizes during development.

### Sections 96–105: UI, analytics, search and modding

**Keep:** management UI should be thin over application/domain services.

**Change:** do not wait until the original Phase 10 for all UI. Add small developer inspection screens early, but keep the full career UX until systems are stable.

**Change:** analytics should consume the canonical event schema rather than querying match-engine internals.

### Sections 106–124: Testing, CI, logging and coding rules

**Keep almost unchanged.** This is one of the strongest parts of the document.

**Change:** split tests into fast PR gates and expensive validation. A 100,000-match distribution test and a 100-year soak should be manual/nightly/release gates, not mandatory on every commit.

**Change:** performance thresholds should use baselines and tolerances appropriate to CI hardware; absolute timings alone will be noisy.

### Sections 125–139: Original development phases

The order is broadly correct but too fragmented in some places and too late in others.

- Original Phase 0 is a real prerequisite and should remain a foundation stream.
- Original Phase 1 and 2 are good first playable-simulation milestones.
- Tactics interfaces must be designed before the spatial engine, but full tactics do not need to block the abstract engine.
- Economy ledger foundations must precede money-changing transfers.
- Developer inspection UI should appear early even though management UI remains later.

### Sections 140–154: Version targets, differentiators and first epic

**Keep:** African football as a first-class ecosystem is a meaningful product differentiator; 100-season stability is a powerful technical differentiator.

**Change:** version numbers should describe verified capabilities rather than calendar milestones.

**Change:** EPIC-001 currently overlaps Phase 0 and Phase 1. Treat it as the foundation + deterministic world acceptance epic rather than a separate parallel plan.

### Section 155: Causal consistency

**Keep as the primary design principle.** Every major simulation decision should eventually expose structured reasons suitable for debugging and UI explanation.

---

# Revised 10-phase roadmap

## Phase 1 — Deterministic World Model

Deliver countries, clubs, players, staff, competitions, contracts, calendar, fixtures, tables, stable UUIDs and reference validation.

**Acceptance:** seed `12345` generates 4 countries, 80 clubs and 2,000 players deterministically; fixtures contain no broken references; each 20-team league produces 380 fixtures.

**Status:** implemented.

## Phase 2 — Abstract Match Engine

Deliver lineups, possession sequences, passes, shots, goals, cards, substitutions, event-derived statistics, neutral player ratings and deterministic match seeds.

**Acceptance:** identical seed reproduces identical match; goals/statistics derive from events; broad distribution harness passes; full 100,000-match validation is available as an explicit CI/manual gate.

**Status:** implemented; statistical calibration still requires running the full 100k gate on CI/hardware.

## Phase 3 — Season and Persistence Core

Add SQLite adapter, migrations, repository layer, atomic saves, calendar-driven fixture execution, league completion, promotion/relegation and historical season records.

**Acceptance:** save/reload/continue matches uninterrupted deterministic simulation; 10 unattended seasons complete without corruption.

## Phase 4 — Player Lifecycle

Add attributes, training, development, aging, injuries, youth intake, retirement and staff conversion.

**Acceptance:** 50-year population health test stays within defined ranges.

## Phase 5 — Squad Building, Contracts and Transfer Market

Add scouting knowledge, valuation, squad-need AI, contract negotiation, transfer negotiation, loans and free agents. Introduce financial ledger before any money-changing transaction.

**Acceptance:** AI clubs maintain viable positional depth and budget compliance for 20 seasons.

## Phase 6 — Club Economy and Institutional Systems

Add income/expense ledger, budgets, sponsorship, tickets, prize money, facilities, stadiums, boards and supporters.

**Acceptance:** 100-year economic test shows no runaway inflation, universal bankruptcy or unexplained cash movement.

## Phase 7 — Tactics and Manager AI

Add formations, roles, duties, tactical instructions, familiarity, lineup policy and manager identities. Replace neutral Phase 2 rating policy with role-aware evaluation.

**Acceptance:** controlled tactical experiments create statistically distinct styles without universal best tactic.

## Phase 8 — Spatial Match Simulation

Add pitch coordinates, movement, pressure, marking, passing lanes, goalkeeper positioning and set pieces while preserving the canonical event schema.

**Acceptance:** spatial engine satisfies existing abstract invariants and produces believable distributions.

## Phase 9 — Career UI, 2D Viewer and Analysis

Add dashboard, inbox, squad, tactics, medical, schedule, competitions, transfers, staff, finances, world search, 2D match viewer and post-match analytics.

**Acceptance:** the UI issues commands/queries only; simulation remains headless-testable.

## Phase 10 — Living World, Modding and Release Hardening

Add relationships, morale, dynamic rivalries, manager careers, reputation movement, awards, legends, mod database/editor, localization, accessibility, performance and migration hardening.

**Acceptance:** release gates: 100-year soak, 100k-match validation, save migration, competition completion, viable AI squads, stable economy/population, Windows build and offline play.

---

# Phase 1/2 implementation boundaries

The current code intentionally does **not** pretend later systems are complete.

- Player ability is currently represented by compact `current_ability`/`potential` values; the 1–100 attribute matrix belongs to Phase 4.
- Contracts are descriptive records only; no money moves until the ledger exists.
- Match ratings are neutral rather than role-aware until tactics/roles exist.
- The abstract match engine emits canonical logical events so the later spatial engine can preserve downstream statistics/history contracts.
- The current UI is a smoke-test inspector, not the management interface.
- SQLite remains a Phase 3 adapter decision; simulation code contains no database dependency.

This keeps the two implemented phases useful without lying about systems that have not yet been built.

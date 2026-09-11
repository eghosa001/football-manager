# RC3 source-completion matrix

RC3 closes the repository implementation phases defined in `implementation` (Phase 0 through Phase 14) at source level. A phase is marked source-complete only where an implementation exists and an executable regression/acceptance path covers the contract. Hardware-, installer-, signing-, and assistive-technology checks remain external release acceptance and are not represented as source completion.

## Original implementation phases

| Phase | Scope | RC3 source status | Primary evidence |
| --- | --- | --- | --- |
| 0 | Foundation | Complete | Godot project, deterministic RNG, event bus, persistence adapters, migrations/save tests, CI/headless harness |
| 1 | World model | Complete | Countries, clubs, players, staff, competitions, fixtures, contracts, reference validation and deterministic world tests |
| 2 | Abstract match engine | Complete | Deterministic event-derived match simulation and statistical distribution gates |
| 3 | Season simulation | Complete | Calendar, leagues/cups, tables, promotion/relegation, rollover/history, unattended season tests |
| 4 | Player lifecycle | Complete | Training, development, aging, injury/medical, youth, retirement and staff conversion services/tests |
| 5 | Transfers | Complete | Scouting, valuation, squad planning, offers, negotiation, contracts, loans/free agents and long-run squad tests |
| 6 | Economy | Complete | Ledger, budgets, wages, tickets, sponsorship/prize flows, facilities, stadiums, boards/supporters and equilibrium tests |
| 7 | Tactics | Complete | Formations, tactical instructions, familiarity, AI choices and controlled tactical experiment regressions |
| 8 | Spatial match engine | Complete | Continuous 105x68 coordinate simulation, movement, pressure/marking, energy/load, tactical causality and cross-tier checks |
| 9 | 2D viewer | Complete | Simulation-frame viewer, pitch/player/ball rendering path, playback controls and match-analysis integration |
| 10 | Management UI | Complete | Dashboard, inbox, squad, tactics, training, medical, schedule, competitions, scouting, transfers, staff, finances, search and analysis; registry-driven composition |
| 11 | Dynamics | Complete | Morale/happiness, relationships, hierarchy/social effects and bounded living-world updates |
| 12 | Living world | Complete | Manager careers/market, reputation, history/records, awards, rivalries/relationships, news/event consumption and long-run soak coverage |
| 13 | Modding | Complete | External mod/database loading, dependency/conflict/integrity checks, competition/data validation, graphics overrides and graphical Database & Mod Editor import/export workflow |
| 14 | Polish | Source-complete | Tutorial/help, loading/worker flow, localization, accessibility settings, autosave/save safety, release guards, performance baselines and fast/heavy CI separation |

## Launch/content target

Expanded-world mode is an explicit 20-country launch configuration. Its regression requires 20 countries, 756 clubs and 21,168 players, plus continental competitions, conflict-free fixture dates, day advancement and exact save/reload continuation. This meets the original v1.0 scale band for nations, clubs and players without claiming licensed real-world rules or data.

## RC3 convergence completed

- Hosted/self-hosted validation targets Godot 4.7.2.
- PR validation is fast and focused; expensive acceptance is isolated from normal commits.
- Stable event-match and career-lifecycle boundaries prevent production entry points from importing version-numbered implementations directly.
- Career UI tab composition is registry-driven through a thin shell rather than hardcoded in the large base application.
- Dense matchday club/player/competition lookup work is indexed, including registered-player retrieval by ID rather than repeated full-world scans.
- Original Phases 12–14 have a dedicated completion test covering manager careers, mod contracts, accessibility/settings bounds, localization, UI registry, performance baseline and offline/release contracts.

## Heavy acceptance evidence

The one-shot `RC3 Heavy Acceptance` workflow runs only on explicit trigger/manual execution and contains:

1. `tests/continuous_distribution_gate.gd` — 100,000-match distribution gate.
2. `tests/cross_tier_regression.gd` — seeded simulation-tier equivalence gate.
3. `tests/full_career_soak.gd` — full 100-season career/economy soak.
4. tracked-source cleanliness verification.

All four steps passed on commit `83d1debacac5ac896a41e646dd0aa8031df21ae5` under Godot 4.7.2 on the self-hosted Windows runner. Any later change that materially alters match simulation, long-run career/economy behavior or these acceptance contracts must explicitly retrigger the heavy workflow.

## External release acceptance still required

These are not source-code phases and cannot be truthfully completed by headless repository tests alone:

- clean Windows install, upgrade and uninstall on another machine;
- interactive Windows offline new-career/save/reload session from the packaged installer;
- actual Linux runtime/offline/save round-trip on Linux hardware or VM;
- keyboard-only navigation and focus-order review;
- real screen-reader review plus contrast/large-text visual inspection;
- representative minimum-spec performance profiling;
- real Android/iOS touch, performance, signing/notarization/TestFlight checks if those platforms are promoted to release targets.

RC3 source completion therefore means the planned game systems and their automated contracts are present. It does not substitute automated tests for physical-device, installer or accessibility acceptance evidence.

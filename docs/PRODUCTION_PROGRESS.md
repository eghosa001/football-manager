# Production progress — 10 September 2026

This implementation follows the original `implementation` document, which has phases 0–14. The later phase labels used in tests are not a declaration that the original commercial specification is complete.

## Implemented in this increment

- Daily Continue crosses July 1 into the next completed season exactly once. Incomplete schedules return an explanation rather than silently skipping fixtures. Two consecutive years, promotion/relegation, registration and save/reload at both boundaries are covered by regression tests.
- Detailed matches apply substitutions before subsequent possessions and remove dismissed players from active lineups. Substitute appearances are included in player history. A 40-seed event-order test reconstructs valid participants through substitutions and dismissals.
- Corrected hidden-attribute initialization so an existing value of 50 survives reload and annual development deterministically.
- Added competition views and registration controls, contract renewal, ticket pricing, facility upgrades, board budget requests, and staff hiring/release. Contract and staff affordability checks reject unaffordable commitments; staff actions require confirmation.
- Career creation and daily simulation run on a worker with visible progress. Save overwrite/deletion requires confirmation; corrupt slots remain visible and load/delete errors are reported. Common malformed career payloads are rejected before replacing the active world.
- High contrast now changes the theme; large text uses scrollable layout. Added French/Portuguese career phrases and a six-step first-season guide. Dynamic news, some controls and detailed data remain incompletely translated.
- Added fictional European and African continental knockout cups, qualified from top domestic leagues. Later qualification uses completed league standings. Scheduling avoids a club playing twice on one date; cup completion, byes, qualification and scheduling have dedicated tests.
- SQLite shares the current save migration path. Its optional pinned addon was installed and its integration test passed locally. It still stores a serialized world, not a normalized relational database.
- CI uses bounded test execution, explicit PASS checks and error-log detection. Superseded validation runs are cancelled per workflow/ref; RC2 now runs on main and production branches.
- Windows export explicitly includes runtime JSON and a release-safe smoke mode (`-- --release-smoke`) validates career creation, translation, one day and save/reload. Release assertions are explicit because debug assertions are disabled in release builds.

## Local evidence

Godot: `4.7.2.stable.official.ed1daf0bf`, Windows x86_64. The eight-country launch world contains 324 clubs and 8,100 players. With continental cups it contains 27 competitions.

Passed: original phase 1/2, 3, 4/5, 6/7, 8/9 and 10/11 suites; career session and RC2 integration; player statistics; registration/save safety; UI; player/scouting; match v2; tooling; two-year rollover; match participation; continental competitions; staff recruitment safety; SQLite; source and packaged release smoke. Phase 10/11 includes the repository's 100-year synthetic-world soak. This is not a 100-year interactive career at full launch scale.

Full-world profiling on the user's machine, with other work running: creation 7,369 ms; ordinary days 119–138 ms; weekly processing 3,456 ms; opening matchday with 162 fixtures 15,400 ms. These are observations, not performance guarantees on minimum hardware.

The 100,000-match abstract-engine statistical gate passed: 3.14 goals, 22.35 shots and 2.34 cards per match, home-win rate 0.394; 831 total assertions in that suite. The smaller 2,000-match run passed with 3.16 goals, 22.28 shots and 2.36 cards per match, and a 0.410 home-win rate.

Windows export and packaged smoke passed. A clean-machine installation and interactive accessibility review remain separate release gates. Linux packaging is configured in CI but was not executed on this Windows host.

## Remaining original-plan work

1. Replace possession snapshots with continuous spatial simulation, including complete fatigue/injury, movement and tactical causality; improve match presentation and verify its statistics independently of the abstract engine.
2. Expand and curate the launch world toward the original country/club/player targets, cities/regions and varied identities. The current continental cups use a simplified fictional qualification model, not licensed real-world rules.
3. Complete tactical, training, negotiation, loan and recruitment controls; add deeper competition rules, economic models and long interactive-career acceptance checks at full scale.
4. Provide a graphical mod authoring/import workflow beyond the existing helper API, with compatibility and content validation.
5. Complete dynamic localization, screen-reader behavior, keyboard/large-text visual review, tutorial presentation and audio.
6. Decide and implement the planned normalized storage/event architecture if it remains a release requirement; conduct clean-install and cross-platform acceptance and resolve any hosted-runner availability issues.

These remaining items are not marked complete by the existence of services or passing component tests.

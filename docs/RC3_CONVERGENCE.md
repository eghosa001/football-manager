# RC3 convergence workstream

RC3 is a convergence and acceptance milestone, not a feature-count milestone.

## Completed in this branch

- Hosted validation is aligned with the project engine version: Godot 4.7.2.
- Stale release-candidate and missing-test workflow references were removed.
- PR validation was split into fast focused checks; full regression and expensive acceptance no longer run on every commit.
- Self-hosted validation supports an isolated `test_script` so a single failure can be reproduced without rerunning the entire suite.
- Stable `EventMatchEngine`, career-cycle and player-lifecycle boundaries prevent production entry points from depending directly on version-numbered implementation filenames.
- Architecture convergence regressions guard the match router, lifecycle entry points and registry-driven career scene.
- Career screen/tab composition is registry-driven through a thin shell rather than hardcoded in the large base application.
- Dense matchday club/player/competition lookups are indexed; registration retrieval no longer scans the entire player world for every fixture squad.
- A dedicated original Phase 12–14 completion gate covers living-world manager careers, mod dependency/conflict/integrity contracts, settings/accessibility bounds, localization coverage, career-screen registry, performance baseline and offline/release contracts.
- Expanded-world acceptance already covers the original content-scale target: 20 countries, 756 clubs and 21,168 players with save/reload continuity.

## Heavy acceptance — passed

The isolated `RC3 Heavy Acceptance` workflow was introduced so expensive validation only runs on explicit trigger/manual execution. On commit `83d1debacac5ac896a41e646dd0aa8031df21ae5`, under Godot 4.7.2 on the self-hosted Windows runner, all of these passed:

1. `tests/continuous_distribution_gate.gd` — 100,000-match distribution gate.
2. `tests/cross_tier_regression.gd` — seeded cross-tier equivalence gate.
3. `tests/full_career_soak.gd` — full 100-season career/economy soak.
4. tracked-source cleanliness verification.

The legacy/versioned implementation files may remain as compatibility layers where existing tests or save-safe code paths still use them. Production entry points are now hidden behind stable names. Physical file deletion is not itself a release requirement and should only be performed when it reduces complexity without breaking compatibility.

## Original phase completion

See `docs/RC3_SOURCE_COMPLETION.md` for the Phase 0–14 source-completion matrix and the distinction between implemented source contracts and external platform acceptance.

## External release acceptance

These cannot be truthfully closed by source code alone:

- actual Linux runtime/offline/save round-trip;
- clean Windows install/upgrade/uninstall and packaged offline session;
- keyboard/screen-reader/contrast/large-text review;
- representative minimum-hardware detailed-match and long-career profiling;
- real Android/iOS touch/performance and signing/notarization/TestFlight where those platforms are promoted to release targets.

See `docs/RELEASE_GATES.md`, `docs/REMEDIATION_72_MATRIX.md` and `docs/RC3_SOURCE_COMPLETION.md` for the acceptance inventory.

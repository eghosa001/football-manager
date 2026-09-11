# RC3 convergence workstream

RC3 is a convergence and acceptance milestone, not a feature-count milestone.

## Implemented in this branch

- Hosted validation aligned with the project engine version: Godot 4.7.2.
- Stale release-candidate workflow references removed from primary documentation.
- Release acceptance gates rewritten around the current CI and explicit target-platform evidence.
- Stable `EventMatchEngine` facade added so production routing no longer depends directly on a versioned event-engine filename.
- Architecture convergence regression added to hosted and self-hosted CI.
- Dense matchday club/player/competition lookups indexed once per played date instead of repeatedly scanning launch-world arrays.
- The RC3 branch is included in authoritative self-hosted CI.

## Gates that must pass before deleting legacy engine generations

1. `tests/continuous_distribution_gate.gd`
2. `tests/cross_tier_regression.gd`
3. `tests/full_career_soak.gd`

The legacy match-engine implementations are intentionally retained until these executable gates pass. Physical flattening/deletion before parity evidence would increase regression risk.

## Next source work after those gates

- Flatten the continuous spatial inheritance chain behind its stable production facade.
- Replace remaining direct `*_v2`/`*_v3`/`*_v4` production imports with stable interfaces.
- Apply the same boundary to the canonical career lifecycle and living-world services before removing superseded implementations.
- Continue matchday profiling and index/cache only demonstrated hot paths.
- Split large career UI/controller files along `CareerScreenRegistry` boundaries without moving simulation logic into scenes.

## Non-source release acceptance

These cannot be truthfully closed by code alone:

- actual Linux runtime/offline/save round-trip;
- clean Windows install/upgrade/uninstall;
- keyboard/screen-reader/contrast/large-text review;
- real Android/iOS performance and touch testing;
- Apple signing/notarization/TestFlight where applicable;
- representative minimum-hardware detailed-match and long-career profiling.

See `docs/RELEASE_GATES.md` and `docs/REMEDIATION_72_MATRIX.md` for the authoritative acceptance inventory.

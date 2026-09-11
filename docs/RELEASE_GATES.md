# Release gates — RC3 acceptance

Repository source and CI can prepare these gates, but target-platform acceptance is only closed by an executed result on the named environment.

## Heavy simulation gates

Run these from the authoritative Godot 4.7.2 environment before promoting a release candidate:

```bash
godot --headless --path . --script res://tests/continuous_distribution_gate.gd
godot --headless --path . --script res://tests/cross_tier_regression.gd
godot --headless --path . --script res://tests/full_career_soak.gd
```

The same gates are available from `.github/workflows/ci.yml` through the `full_match_validation`, `cross_tier_validation`, and `full_career_soak` workflow-dispatch inputs.

Acceptance:
- continuous 100,000-match distribution gate passes;
- seeded cross-tier detailed/event/abstract/aggregate comparison passes;
- 100-season canonical career/economy soak passes without corruption or invariant drift.

## Linux runtime

`ci.yml` produces a Linux/X11 export on the self-hosted Windows runner, but export existence is not Linux runtime validation.

Required before release:
- run the exported `FootballDynasty.x86_64 --headless -- --release-smoke` on an actual Linux runner/machine;
- verify filesystem/save round-trip and offline launch;
- verify packaged artifact integrity/hash.

## Clean-machine Windows install

Use a fresh Windows VM/machine with no Godot installation:
- install the packaged build;
- launch and create a career;
- save, quit, reopen and load;
- play a match and return to career UI;
- upgrade over an existing installation and confirm saves remain available;
- uninstall and record expected preservation/removal behaviour.

## Installer / update path

`tools/windows/FootballDynasty.iss` and `tools/windows/installer-smoke.ps1` provide the installer/update test path. Before release verify:
- install directory and version metadata;
- Start menu/desktop integration as configured;
- uninstall behaviour;
- save-location policy across upgrades;
- release log/crash-log policy.

## Accessibility and presentation

Automated UI audits are necessary but not sufficient. Perform real acceptance for:
- keyboard-only navigation and visible focus;
- high contrast and large text;
- screen-reader semantics where supported;
- dynamic localization review in English, French and Portuguese;
- match-view readability and low-end quality mode;
- audio categories, mute and reduced-sudden-sound behaviour.

## Performance

Profile representative launch-world careers on minimum/target hardware. Record:
- career creation;
- ordinary day and weekly processing;
- dense matchday processing;
- detailed 90-minute match runtime/FPS;
- memory growth and save-file growth over long careers.

Performance acceptance should use documented baselines/tolerances rather than silently weakening tests for slower hardware.

## Mobile

See `docs/MOBILE_EXPORT.md`.
- Android: Play AAB + sideload APK on real device; validate career creation, save/load, touch navigation, 2D viewer, memory, battery and thermal behaviour.
- iOS: Xcode archive + TestFlight/device validation.
- macOS: Developer ID sign + notarize + staple; ad-hoc builds are local-only.

## Promotion rule

Do not call the build 1.0 final until the required heavy simulation, clean-install, target-runtime, accessibility/presentation and target-device gates for the shipping platforms have executed successfully.

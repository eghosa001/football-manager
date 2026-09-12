# Release gates — RC3 acceptance

Repository source now provides executable automation for every code-controlled release gate. A gate is only accepted for promotion when it has passed on the exact release-candidate commit. Physical-device, assistive-technology and representative consumer-hardware evidence still requires the named real environment and must not be inferred from source tests.

## Heavy simulation gates

Run `.github/workflows/rc3-heavy-gates.yml` on the exact RC ref. The workflow records the commit SHA and uploads a certification manifest after all gates pass:

```bash
godot --headless --path . --script res://tests/continuous_distribution_gate.gd
godot --headless --path . --script res://tests/cross_tier_regression.gd
godot --headless --path . --script res://tests/full_career_soak.gd
godot --headless --path . --script res://tests/long_session_memory_test.gd
godot --headless --path . --script res://tests/long_save_growth_test.gd
```

Acceptance:
- continuous 100,000-match distribution gate passes;
- seeded cross-tier detailed/event/abstract/aggregate comparison passes;
- 100-season canonical career/economy soak passes without corruption or invariant drift;
- 180-day long-session memory growth stays inside the production limit;
- save-file growth/recovery remains bounded and backup recovery succeeds;
- tracked source remains unchanged by acceptance.

## Linux runtime

`.github/workflows/hosted-validation.yml` now builds the Linux/X11 release on GitHub-hosted Ubuntu and executes the packaged `FootballDynasty.x86_64` on Linux. It runs normal and proxy-free/offline release smoke, computes SHA-256 and uploads the binary plus logs as evidence.

Required before release:
- the hosted Linux workflow passes on the exact RC commit;
- the uploaded binary hash matches the promoted artifact;
- if Linux is a supported public platform, perform one interactive desktop session covering career creation, save/reload and match return in addition to the headless package smoke.

## Clean-machine Windows install

`.github/workflows/fresh-windows-release.yml` runs on a fresh GitHub-hosted Windows VM. It imports with Godot 4.7.2, builds the release executable, builds the Inno Setup installer, smoke-tests the unpackaged binary, silently installs the installer and executes the installed game. Checksums and artifacts are retained.

Before final public Windows promotion also perform one interactive clean-machine session:
- install the exact checksummed installer;
- launch and create a career;
- save, quit, reopen and load;
- play a match and return to career UI;
- upgrade over an existing RC installation and confirm saves remain available;
- uninstall and confirm the documented save-preservation policy.

## Installer / update path

`tools/windows/FootballDynasty.iss` and `tools/windows/installer-smoke.ps1` provide the installer/update test path. RC3 version metadata is aligned across Godot, export presets and the installer.

Verify for final promotion:
- install directory and version metadata;
- Start menu/desktop integration as configured;
- uninstall behaviour;
- save-location policy across upgrades;
- release log/crash-log policy.

## Accessibility and presentation

Automated enforcement now includes readable defaults, 38 px desktop interaction targets, 48 px mobile interaction targets, keyboard focus, wrapping of long labels, compact mobile career navigation, high-contrast settings and localization coverage. `tests/ui_readability_test.gd`, `tests/navigation_responsive_test.gd`, `tests/polish_completion_test.gd` and the career UI suite cover these source contracts.

Human acceptance is still required for:
- keyboard-only navigation and visible focus order;
- high contrast and large text at supported scaling extremes;
- screen-reader semantics where the target OS/Godot combination supports them;
- dynamic localization/overflow review in English, French and Portuguese;
- match-view readability and low-end quality mode;
- audio categories, mute and reduced-sudden-sound behaviour.

## Performance

`tests/performance_baseline_test.gd` now measures full career creation, ordinary-day processing, seven-day processing, dense opening matchday processing and a detailed 90-minute match against documented baseline/tolerance values. Heavy acceptance adds 180-day memory-growth and save-growth/recovery gates.

On the intended minimum-spec device, record the same workloads and compare against the checked-in production baselines instead of weakening thresholds for slow hardware.

## Mobile

See `docs/MOBILE_EXPORT.md`.

`.github/workflows/debug-apk.yml` now runs on every mobile-relevant PR/main change, validates the mobile export and readability contracts, builds a real installable debug APK and uploads its SHA-256. This creates a repeatable device-test artifact instead of only checking preset text.

- Android final: build/sign Play AAB and sideload the exact APK/AAB-derived build on real devices; validate career creation, save/load, compact navigation, 2D viewer, memory, battery and thermal behaviour.
- iOS final: Xcode archive + signing + TestFlight/device validation.
- macOS final: Developer ID sign + notarize + staple; ad-hoc builds are local-only.

## Promotion rule

Do not call the build `1.0.0` final until all automated gates have passed on the exact frozen RC commit and the required interactive/device/accessibility/minimum-hardware evidence for every advertised shipping platform is recorded. A green source test on a different commit is not valid release evidence.

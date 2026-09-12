# RC3 release-hardening completion scope

This branch closes the code-controlled gaps identified before final production acceptance. It deliberately does not claim that physical-device or human accessibility evidence can be manufactured by source tests.

## Implemented

- RC3 version alignment across Godot, desktop metadata, Android, iOS, macOS and Windows installer.
- Android target API 36 and signed AAB pipeline for current Play submission requirements.
- Clean self-hosted checkout and fresh checksum-verified Godot-SQLite installation.
- GitHub-hosted Linux package build, packaged runtime/offline smoke, checksum and retained evidence.
- GitHub-hosted Windows release + Inno Setup build, silent clean-install smoke, checksums and retained evidence.
- Mobile-relevant PR/main changes now produce an installable debug APK and hash.
- Global readability/touch-target runtime with 38 px desktop and 48 px mobile interaction floors.
- Mobile career navigation collapses the wide desktop sidebar to a single selector.
- Increased readable default font scaling while retaining user scaling controls.
- Expanded performance contracts for world creation, daily/weekly processing, matchday and detailed match runtime.
- Long-session memory and save-growth/backup-recovery release gates.
- Heavy acceptance now certifies the exact selected commit rather than a hard-coded historical branch.
- Heavy acceptance emits a machine-readable certification manifest.
- Final human/device acceptance template records hashes, hardware, platform and promotion decision.
- GitHub Actions dependency updates are tracked with Dependabot.

## Added/expanded regression coverage

- `tests/ui_readability_test.gd`
- `tests/navigation_responsive_test.gd`
- `tests/performance_baseline_test.gd`
- `tests/long_session_memory_test.gd`
- `tests/long_save_growth_test.gd`
- `tests/production_readiness_contract_test.gd`
- `tests/mobile_export_test.gd` now enforces API 36 and RC3 Android metadata.

## Evidence still requiring real environments

These are final acceptance activities, not missing source implementations:

- interactive Windows install/upgrade/uninstall session;
- interactive Linux desktop career/save/match session;
- keyboard, focus, screen-reader and visual accessibility review;
- minimum-spec consumer-hardware measurements;
- physical Android device battery/thermal/touch/save acceptance if Android ships;
- iOS signing/TestFlight and macOS signing/notarization only if those targets are promoted.

Use `docs/RELEASE_ACCEPTANCE_TEMPLATE.md` for those records. Promotion to `1.0.0` is blocked until the advertised-platform evidence is complete on the exact frozen RC commit.

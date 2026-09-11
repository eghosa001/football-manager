# Release gates — Linux runtime, clean install, installer

## Linux runtime (audit 21)
`release-candidate.yml` and `ci.yml` run on `[self-hosted, Windows, X64]`.
Linux export existence is not runtime validation. Required before release:
- Linux runner (hosted or self-hosted), launch `FootballDynasty.x86_64 --headless -- --release-smoke`
- filesystem/save round-trip, offline test, artifact hash validation

## Clean-machine Windows install (audit 22)
- Fresh VM, no Godot: launch export, create career, save, quit, reopen, load, play match
- Record uninstall/update behaviour

## Installer / update path (audit 23)
Exporting `.exe` is not shipping. Needed:
- Windows installer (install dir, Start menu, version metadata, icons, uninstall)
- Save-location policy preserving saves across upgrades
- Optional crash logs

## Mobile (companion to docs/MOBILE_EXPORT.md)
- Android: Play AAB + sideload APK device test (career, save, 2D viewer)
- iOS: Xcode archive, TestFlight
- macOS: Developer ID sign + notarize + staple; ad-hoc builds local-only

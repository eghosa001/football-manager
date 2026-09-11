# Mobile + Apple export — Football Dynasty

`export_presets.cfg` now defines five runnable targets:

- `Windows Desktop` → `build/windows/FootballDynasty.exe`
- `Linux/X11` → `build/linux/FootballDynasty.x86_64`
- `Android` → `build/android/FootballDynasty.aab` (Play store bundle, `arm64-v8a`, min SDK 24, target SDK 34)
- `iOS` → `build/ios/FootballDynasty.xcodeproj` (Xcode project, min iOS 15, iPhone+iPad)
- `macOS` → `build/macos/FootballDynasty.app` (universal Apple Silicon + Intel)

Bundle IDs default to `com.footballdynasty.game`. Change them in the Export dialog
before store submission if you own a different reverse-DNS namespace.

`project.godot` sets the mobile baseline: `canvas_items/expand` stretch,
landscape orientation, resizable window, HiDPI allowed, and touch emulation so the
1280×720 management UI scales to phones/tablets.

## Fast validation (no SDK required)

```bash
godot --headless --path . --script res://tests/mobile_export_test.gd
# or
bash tools/test-headless.sh tests/mobile_export_test.gd
```

This checks preset presence, Android `.aab` + package + `arm64-v8a`, iOS
`.xcodeproj` + bundle ID, macOS `.app`, and stretch/orientation settings.

## Android full build

1. Install JDK 17, Android Studio/SDK Platform 34, build-tools, and Godot 4.7.2
   export templates (`Editor → Manage Export Templates`).
2. In Godot: `Editor → Editor Settings → Export → Android` — set `Android Sdk Path`,
   `Debug Keystore`, and (for release) your keystore. Never commit
   `*.keystore`, passwords, or `.godot/export_credentials.cfg`.
3. For a local APK (sideload/test): duplicate the `Android` preset or set
   `gradle_build/export_format=0` and export to `build/android/FootballDynasty.apk`.
   For Play submission keep `export_format=1` (AAB).
4. Install to device via `adb install`, create career, advance a day, save/reload,
   view a match in the 2D viewer. Background sim must stay on the tactical tier —
   do not run the detailed spatial engine per-fixture on mobile.

## iOS full build

1. Export from Godot on any OS to generate `build/ios/FootballDynasty.xcodeproj`.
2. Open the project in Xcode 15+ on macOS, select your Team, bundle ID, and
   provisioning profiles (Debug + Release). Build to simulator/device.
3. Archive for TestFlight/App Store. Privacy manifests default to no tracking;
   update `privacy/*` preset options if you add analytics.

## macOS full build

1. Export `macOS` preset from Godot 4.7.2 with templates installed.
2. On macOS: codesign with your Developer ID (`codesign/identity`, `apple_team_id`
   in the preset — leave blank for ad-hoc local builds), then notarize:
   `xcrun notarytool submit ... --wait`, then `xcrun stapler staple`.
3. Without signing, Gatekeeper will block the app on other machines. Ad-hoc builds
   are for local testing only.

## Performance contract (mobile)

Observed desktop full-world cost: ~7.4 s creation, ~120–140 ms ordinary days,
~3.5 s weekly, ~15.4 s for a 162-fixture matchday. Mobile must use the cheap
tactical engine for background fixtures; the spatial engine is a viewed-match-only
tier. If matchday time regresses on device, profile fixture grouping, world
indexes, save serialization, and UI refreshes before growing the world.

## CI

`.github/workflows/mobile.yml` runs `mobile_export_test.gd` on every push/PR and,
when Android SDK + templates are present, attempts a debug Android export to catch
preset/SDK drift. iOS/macOS binary signing remains a maintainer-side Xcode step.

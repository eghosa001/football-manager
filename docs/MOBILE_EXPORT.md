# Mobile + Apple export — Football Dynasty

`export_presets.cfg` defines five runnable targets:

- `Windows Desktop` → `build/windows/FootballDynasty.exe`
- `Linux/X11` → `build/linux/FootballDynasty.x86_64`
- `Android` → `build/android/FootballDynasty.aab` (Play bundle, `arm64-v8a`, min SDK 24, target SDK 36)
- `iOS` → `build/ios/FootballDynasty.xcodeproj` (Xcode project, min iOS 15, iPhone+iPad)
- `macOS` → `build/macos/FootballDynasty.app` (universal Apple Silicon + Intel)

Bundle IDs default to `com.footballdynasty.game`. Change them before store submission if the project will use a different owned reverse-DNS namespace.

`project.godot` sets the mobile baseline: `canvas_items/expand` stretch, landscape orientation, resizable window, HiDPI, touch/mouse emulation and the global UI-readability runtime. Mobile career navigation collapses the desktop sidebar into a single 48 px-high selector so the management surface keeps the full screen width.

## Fast validation

```bash
godot --headless --path . --script res://tests/mobile_export_test.gd
godot --headless --path . --script res://tests/ui_readability_test.gd
godot --headless --path . --script res://tests/navigation_responsive_test.gd
```

The export contract verifies preset presence, Android AAB + package + ARM64 + API 36 + RC3 versioning, iOS Xcode project/bundle ID, macOS app bundle and the required stretch/orientation settings.

## Android device-test APK

`.github/workflows/debug-apk.yml` runs for mobile-relevant pull requests and main changes. It installs Godot 4.7.2 export templates, validates the mobile/readability contracts, builds a real debug APK and uploads both the APK and SHA-256. Use that exact artifact for sideload/device acceptance so testers are not validating a different local build.

## Android signed Play AAB

`.github/workflows/android-release.yml` is the release-signing path. Configure these GitHub Actions secrets:

- `ANDROID_RELEASE_KEYSTORE_BASE64` — base64 of the release keystore file;
- `ANDROID_RELEASE_KEYSTORE_USER` — key alias;
- `ANDROID_RELEASE_KEYSTORE_PASSWORD` — keystore/key password.

The workflow materializes the keystore only in the ephemeral runner, supplies Godot's Android release-keystore environment variables, installs the Gradle build template, exports the signed `FootballDynasty.aab`, records SHA-256 and deletes the temporary keystore in an `always()` cleanup step. Never commit keystores, passwords or `.godot/export_credentials.cfg`.

The Android target SDK is API 36. Keep this gate current with Google Play policy before promotion; `tests/mobile_export_test.gd` intentionally fails if the configured target falls below 36.

## Local Android build

1. Install JDK 17, the current Android SDK/platform required by the preset, and Godot 4.7.2 export templates.
2. For AAB/Gradle builds run `godot --headless --editor --path . --install-android-build-template --quit` once in the project checkout.
3. Configure the release keystore through Godot or the documented `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables; do not store credentials in source.
4. Export the `Android` preset for Play AAB. For a local sideload APK use the debug workflow/artifact or a duplicated APK-format preset.
5. On device validate career creation, compact navigation, day progression, save/reload, process termination/relaunch and the 2D viewer.

## iOS full build

1. Export from Godot to generate `build/ios/FootballDynasty.xcodeproj`.
2. Open the project in Xcode on macOS, select your Team, bundle ID and provisioning profiles. Build to device/TestFlight.
3. Privacy settings default to no tracking; update the export privacy options if analytics or tracking are later added.

## macOS full build

1. Export the `macOS` preset from Godot 4.7.2 with templates installed.
2. On macOS sign with Developer ID, notarize with `notarytool`, then staple the ticket.
3. Ad-hoc unsigned builds are local-test artifacts only and are not release candidates.

## Performance contract (mobile)

Background fixtures must remain on cheaper simulation tiers; the continuous spatial engine is a viewed-match tier. `tests/performance_baseline_test.gd` protects career creation/day/week/matchday/detailed-match budgets, while the final device record in `docs/RELEASE_ACCEPTANCE_TEMPLATE.md` captures actual phone memory, battery, thermal and long-session behavior.

## CI summary

- `.github/workflows/mobile.yml` — lightweight preset/config regression.
- `.github/workflows/debug-apk.yml` — installable APK and SHA-256 on relevant code changes.
- `.github/workflows/android-release.yml` — signed Play AAB and SHA-256 when release secrets are configured.

Physical Android device acceptance remains mandatory before advertising Android as supported; iOS/macOS remain non-promoted targets until their signing/device/notarization evidence is completed.

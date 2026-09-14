# Football Dynasty 1.1.0 — Google Play Monetization Setup

This document covers the account-side settings that cannot be safely invented in source control. The game code expects these settings exactly.

## 1. Google Play one-time product

In Google Play Console, create a one-time in-app product for the existing application package:

- Package: `com.footballdynasty.game`
- Product ID: `football_dynasty_premium`
- Product type: non-consumable / one-time product
- Suggested display name: `Football Dynasty Premium`
- Suggested base price: approximately USD 4.99, then review Play's localized regional prices.

Do not create Premium as a consumable. The game acknowledges the purchase and treats confirmed ownership as permanent.

The product must be active and available to the test track used for billing acceptance.

## 2. Billing test acceptance

Use a Google Play Internal Testing or Closed Testing build and a Play billing tester/test account. Validate all of the following:

1. Localized price appears in the Premium screen.
2. Buy Premium opens the real Google Play purchase sheet.
3. Cancelling does not unlock Premium.
4. A pending purchase does not unlock Premium early.
5. A completed purchase unlocks Premium.
6. The completed purchase is acknowledged.
7. Restarting the game keeps Premium active.
8. Reinstalling and choosing Restore Purchase restores ownership.
9. The entitlement remains usable offline after Google Play previously confirmed it.
10. A user without the purchase cannot obtain Premium merely by editing a career save; monetization state is stored separately from career files.

## 3. AdMob application

Create an Android app in AdMob for package `com.footballdynasty.game` and create exactly one rewarded ad unit for the initial release.

Production requires two account values that are intentionally not committed as fake placeholders:

- `ADMOB_ANDROID_APP_ID`
- rewarded ad unit ID

Development/CI uses Google's official test application/ad configuration only. Never publish a production build while the generated smoke/test AdMob configuration is active.

## 4. Reward design

The only rewarded gameplay integration in 1.1.0 is **Analyst Report credits**:

- One successfully completed rewarded ad grants one credit.
- Maximum stored credits: 3.
- Credits persist separately from career saves.
- A credit is consumed only when an Analyst Dossier is successfully requested from the Scouting screen.
- Premium users have unlimited Analyst Dossiers and therefore do not need rewarded ads for this feature.
- The dossier uses Football Dynasty's existing scouting-analysis system.
- It exposes decision-support information only.
- It must never mutate player current ability, potential, fitness, finances, transfer acceptance, tactics, or match outcomes.

This is intentionally not a pay-to-win mechanic.

## 5. Advertising consent

The runtime gates rewarded-ad loading behind the AdMob plugin's UMP consent flow:

1. AdMob initializes.
2. The game requests updated consent information.
3. If a consent form is available, it is loaded and shown.
4. Rewarded ads are not loaded until the consent step resolves.
5. If consent update/form handling fails, rewarded ads fail closed and remain unavailable; core gameplay and Premium billing are unaffected.

Before release, configure AdMob/UMP privacy messaging for every geography where it is required and ensure the app's target-audience settings match the treatment used by the SDK.

Do not mark the app as child-directed or not child-directed merely to improve ad fill. The configuration must reflect the Play Console target audience and actual intended audience.

## 6. Play Console declarations affected by 1.1.0

The 1.1.0 monetized release is materially different from the offline 1.0.0 release. Re-review at least:

- Data Safety
- Ads declaration
- Privacy policy URL
- Target audience and content
- Content rating if monetization disclosures affect answers
- App access (normally no login required)
- Store listing text mentioning optional in-app purchases/ads where appropriate

The committed privacy policy is source content; Google Play still requires a publicly accessible privacy-policy URL.

## 7. Android release version

Monetization is versioned separately from the offline release:

- Version name: `1.1.0`
- Version code: `10005`
- Target SDK: API 36
- Architecture: ARM64
- Delivery: Android App Bundle (AAB)
- Internet permission: enabled for billing and optional rewarded ads

## 8. CI and build safety

Three levels of validation exist:

- Main CI: game correctness plus monetization contract tests.
- Android Monetization Smoke: downloads pinned billing and AdMob plugins, verifies archive checksums, enables them in a disposable workspace, uses Google test ads, imports the Godot project, runs mobile/monetization contracts, and attempts an Android debug AAB export.
- Signed Android Release: requires the developer's existing keystore secrets. Production AdMob IDs and Play product configuration must be verified before using a monetized signed artifact for release.

A debug smoke AAB is evidence that the integration compiles. It is not a revenue-ready Play artifact.

## 9. Do not ship until all are true

- Android Monetization Smoke passes.
- Main CI passes.
- Existing game regression suites pass.
- Real AdMob app/rewarded unit IDs are configured for release.
- UMP consent is tested on a real Android device.
- `football_dynasty_premium` is active in Play Console.
- Purchase, pending, cancel, acknowledge and restore flows are tested from a Play-distributed build.
- Reward is granted exactly once per successful rewarded-ad completion.
- Closing/failing an ad without the reward callback grants no credit.
- Premium users receive no forced ad prompt.
- No ad appears during matches, tactics, transfers, save/load, or Continue processing.
- Public privacy policy and Data Safety answers match the final SDK configuration.

# Football Dynasty Monetization Integration

## Model

Football Dynasty uses a player-friendly monetization model:

- Free download.
- Core football-management career remains playable without payment.
- One permanent Google Play product: `football_dynasty_premium`.
- Premium removes rewarded-ad friction and acts as the durable supporter entitlement.
- Only optional rewarded ads are supported by the game-side monetization manager.
- No forced interstitial ads, app-open ads, energy timers, pay-to-win boosts, loot boxes, or match-result purchases.

## Runtime architecture

`game/monetization/monetization_manager.gd` is the single source of truth for monetization state. It is autoloaded as `/root/Monetization`.

Responsibilities:

1. Connect to the first-party GodotGooglePlayBilling plugin on Android.
2. Query `football_dynasty_premium` product details and localized Google Play pricing.
3. Launch the one-time purchase flow.
4. Distinguish purchased, pending, cancelled, and error states.
5. Acknowledge completed non-consumable purchases.
6. Restore owned purchases using Google Play's purchase query.
7. Cache confirmed Premium ownership locally for offline continuity.
8. Initialize AdMob only when the plugin exists.
9. Load/show rewarded ads only after the player explicitly requests one.
10. Emit a reward only after the SDK reports `rewarded_ad_user_earned_reward`.
11. Never call interstitial or app-open ad APIs.

`game/monetization/monetization_ui_runtime.gd` adds a `PREMIUM` button to the designed landing screen and provides Buy Premium, Restore Purchase, Premium status, localized price, optional rewarded-ad action, and clear error/pending messaging.

## Google Play Billing plugin

Pinned integration: GodotGooglePlayBilling `3.3.0`, which uses Google Play Billing Library 9.1.0.

Install with:

```bash
bash tools/install-monetization-plugins.sh
```

The installer verifies the release archive SHA-256 before copying the add-on into `addons/`.

Google Play Console must contain an active one-time product with the exact ID:

```text
football_dynasty_premium
```

Recommended launch pricing is approximately USD $4.99 with Google Play's localized regional pricing, but the game never hardcodes a currency value; it displays the localized price returned by Google Play.

Billing must be tested from a Play-distributed Internal or Closed Testing build. Local APK sideloading is not sufficient evidence that billing works.

## Rewarded ads

Pinned Android integration: Godot SDK Integrations AdMob plugin `v7.0`, which supports Godot 4.7.

Only the Rewarded format is used by Football Dynasty. The manager explicitly does not invoke interstitial, rewarded-interstitial, banner, native, or app-open ad display paths.

During development, Google's rewarded test unit may be used through the plugin's debug configuration. Before production, the developer must create a real AdMob app/application ID and rewarded ad unit, configure those values in the plugin, and verify consent behavior on real devices.

Do not substitute a production ad-unit ID with Google's test ID when publishing.

## Privacy and Data Safety

Monetization changes the Android privacy profile:

- Android Internet permission is enabled.
- Google Play Billing is used for the Premium transaction.
- Google Mobile Ads may process advertising/device/consent/diagnostic data when a rewarded ad is requested.
- The in-game notice and `docs/PRIVACY_POLICY.md` have been updated accordingly.
- Play Console Data Safety answers must be based on the exact release SDK/configuration, not copied blindly from documentation.
- Target-audience, child-directed treatment, under-age-of-consent and ad-personalization configuration must be consistent.

## Release gate

Run:

```bash
bash tools/test-headless.sh tests/monetization_contract_test.gd 120
```

The contract test rejects regressions such as missing purchase restore, missing acknowledgement handling, missing privacy disclosure, disabled Android Internet access, or accidental interstitial/app-open ad paths.

Before merging a monetized production build, additionally verify on a Play test track:

1. Product price loads.
2. Successful purchase unlocks Premium.
3. Pending purchase does not unlock early.
4. Cancelling purchase does not unlock Premium.
5. Purchase is acknowledged.
6. Reinstall + Restore Purchase restores Premium.
7. Offline launch after a previously verified purchase retains Premium.
8. Rewarded ad is initiated only by the player.
9. Closing an ad without earning a reward grants nothing.
10. Completing a rewarded ad grants exactly one reward event.
11. Premium users never need to watch a rewarded ad for the same convenience reward.
12. No ads appear during match play, tactics, transfers, saves, loading, or Continue processing.

## Expansion products

Future paid expansion packs should be added as separate non-consumable product IDs and entitlements. They should add genuine simulation/content depth rather than selling competitive outcomes. Do not reuse the Premium product as a consumable and do not add subscriptions unless the game later provides ongoing server-backed value that justifies recurring billing.

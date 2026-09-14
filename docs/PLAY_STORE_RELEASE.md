# Football Dynasty — Google Play Release Checklist

Last reviewed: 14 September 2026

## Repository-side release state

- App name: Football Dynasty
- Package name: `com.footballdynasty.game`
- Public version: `1.0.0`
- Android version code: `10004`
- Android target SDK: 36
- Android minimum SDK: 24
- Delivery format: Android App Bundle (`.aab`)
- CPU architecture: ARM64
- Orientation: landscape
- Internet permission: disabled
- Notifications permission: disabled
- Android backup: disabled
- Signed release workflow: `.github/workflows/android-release.yml`
- In-game privacy policy surface: `game/polish/privacy_runtime.gd`
- Public policy source: `docs/PRIVACY_POLICY.md`

## Recommended Play Console declarations for this release

These answers are based on the current offline build and must be reviewed again if the binary or dependencies change.

### App access

No restricted app access. The game does not require login credentials or a membership to reach normal gameplay.

### Ads

Declare **No** if the submitted build contains no advertising SDK or ad placements.

### Data safety

For the current build, declare that the app does not collect or share user data only after verifying the final uploaded AAB contains no third-party SDK that performs collection. The source release is configured without Internet permission and does not include analytics, advertising, cloud-save, account, or telemetry functionality.

### Privacy policy

Publish the contents of `docs/PRIVACY_POLICY.md` at a stable public HTTPS URL and enter that URL in Play Console. The same policy is available in-app from the landing screen.

### Content rating

Complete the IARC questionnaire using the actual game content. Football Dynasty contains a football-management simulation and should not be left unrated.

### Target audience

Choose the actual intended audience based on the final content and marketing. Do not select a child-directed audience unless the product, store listing, ads/data practices, and design intentionally satisfy the additional Families requirements.

## Store listing draft

### App name

Football Dynasty

### Short description

Build your club, shape careers, master tactics and create a football dynasty.

### Full description

Football Dynasty is a deep offline football management simulation built around long-term decision-making.

Take control of a club, manage your squad, develop players, recruit staff, scout talent, negotiate transfers, shape tactics, navigate competitions and build a legacy across seasons.

Features include:

- Long-term club and manager career simulation
- League, cup, continental and international competition systems
- Tactical formations, roles and match preparation
- Player development, training, injuries, morale and relationships
- Transfers, contracts, scouting and squad planning
- Club finances, budgets, facilities and stadium development
- Match simulation, statistics and analysis
- Youth development, staff careers, records, awards and historical progression
- Local saves and offline play
- Fictional clubs and players designed for an original football universe

Every season becomes part of your story. Build intelligently, adapt constantly and define an era.

## Required store assets

Before production submission, prepare and upload:

- 512 × 512 Play Store icon
- 1024 × 500 feature graphic
- Phone screenshots captured from the actual Android build
- Optional tablet screenshots if tablet support is promoted
- Support email
- Privacy policy public HTTPS URL
- Developer website URL if available

Recommended screenshots: landing screen, dashboard, squad, tactics, transfers/scouting, competitions/table, and live match/match analysis.

## Release validation sequence

1. Run repository tests and Android release contracts.
2. Build the signed production AAB through `Android Signed Release`.
3. Upload the exact AAB to Play Console internal testing.
4. Install the app from Google Play on real Android hardware rather than sideloading only.
5. Test touch navigation, Android back behavior, background/resume, force-stop/reopen, save/reload, long career simulation, matchday performance, small-screen readability, thermal behavior, memory pressure and low-storage behavior.
6. Review Play Console native-library compatibility, including 16 KB page-size reporting.
7. Resolve all repeatable crashes, ANRs and serious pre-launch report findings.
8. Complete required closed testing if the developer account is subject to Google's personal-account production-access rule.
9. Complete Data safety, content rating, target audience, ads, app access, privacy policy and store listing sections.
10. Promote the tested bundle to production only after the tested build and production build are the same artifact/version.

## External evidence still required

The repository cannot prove the following without access to external systems or hardware:

- Presence and correctness of GitHub Android signing secrets
- Successful Play App Signing enrollment
- Successful signed AAB generation with the developer's real keystore
- Google Play pre-launch report results
- Real-device performance, touch, lifecycle and thermal behavior
- Play Console Data safety/content-rating/target-audience submission
- Closed-test tester participation and production-access approval where applicable

Do not mark those items complete merely because source-level tests pass.

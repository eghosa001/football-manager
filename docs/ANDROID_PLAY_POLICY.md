# Android Play target policy

RC3 targets Android 16 / API level 36 in `export_presets.cfg`.

As of the RC3 hardening date (September 2026), new Google Play apps and app updates must target API level 36 or newer. `tests/mobile_export_test.gd` and `tests/production_readiness_contract_test.gd` enforce that floor so a future preset regression cannot silently produce a non-submittable Play build.

Store policies change independently of the game source. Re-check the current Google Play target API requirement immediately before final store submission and raise the tested target floor if Google changes it again.

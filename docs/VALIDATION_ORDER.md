# Integrated validation order

1. Hosted PR regression + packaged Linux runtime.
2. Fresh hosted Windows installer acceptance.
3. Android debug APK build and mobile UI contracts.
4. Fix all failures before merge.
5. Merge/freeze the RC commit.
6. Run RC3 Heavy Acceptance on that exact frozen commit.
7. Run signed Android AAB workflow if Android is a shipping target.
8. Complete `RELEASE_ACCEPTANCE_TEMPLATE.md` on physical/minimum-spec environments.
9. Promote to `1.0.0` only if every advertised-platform gate is complete.

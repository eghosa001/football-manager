# RC3 final acceptance record

Use one copy of this document for the exact commit proposed for promotion. Do not reuse evidence from an older commit after simulation, UI, persistence, packaging or export changes.

## Candidate identity

- Commit SHA:
- Version: `1.0.0-rc3`
- Windows installer SHA-256:
- Linux binary SHA-256:
- Android APK/AAB SHA-256 (if Android ships):
- Heavy acceptance workflow run:
- Hosted Linux workflow run:
- Fresh Windows workflow run:
- Android build workflow run (if Android ships):

## Windows interactive clean-install

- [ ] Installed checksummed installer on a machine/VM without the project checkout.
- [ ] First launch succeeds.
- [ ] New career succeeds.
- [ ] Save, quit, restart and reload succeed.
- [ ] Managed match completes and returns to career UI.
- [ ] Upgrade over the previous RC preserves saves.
- [ ] Uninstall leaves/removes data according to the documented policy.

Device/OS/CPU/RAM/GPU and notes:

## Linux interactive runtime

- [ ] Checksummed packaged binary launches on supported distro.
- [ ] Offline launch succeeds.
- [ ] New career and save/reload succeed.
- [ ] Managed match completes and returns to career UI.
- [ ] No case-sensitive path/resource failures observed.

Distro/desktop/CPU/RAM/GPU and notes:

## Accessibility/presentation

- [ ] Keyboard-only navigation can reach every primary action and visible focus is clear.
- [ ] 100%, large-text and maximum supported UI/font scale are readable without clipped critical controls.
- [ ] High-contrast mode remains readable.
- [ ] English, French and Portuguese dynamic screens were inspected for overflow/truncation.
- [ ] Screen-reader behavior was checked on a supported target environment and limitations recorded.
- [ ] Reduced-motion and reduced-sudden-sound settings were checked.
- [ ] 2D match view remains readable in low-end quality mode.

Environment and notes:

## Minimum-spec performance

Record actual wall-clock values instead of subjective labels.

- Career creation:
- Ordinary day:
- Seven-day processing:
- Dense matchday:
- Detailed 90-minute match runtime / average FPS:
- RAM at career start:
- RAM after long session:
- Initial save size:
- Long-career save size:

Hardware and notes:

## Android physical device (only if Android ships)

For each representative phone/tablet:

- [ ] Install exact APK/AAB-derived build.
- [ ] Career creation succeeds.
- [ ] Compact navigation is usable without horizontal crowding.
- [ ] Touch targets and text are readable.
- [ ] Save/reload survives process termination and relaunch.
- [ ] 2D viewer is usable.
- [ ] Back/navigation behavior is consistent.
- [ ] 30+ minute session has acceptable memory, battery and thermal behavior.
- [ ] Rotation/orientation remains locked to the intended landscape experience.

Device/Android version/RAM/SoC and notes:

## Promotion decision

- [ ] All advertised-platform automated gates passed on this exact commit.
- [ ] All advertised-platform interactive gates above passed.
- [ ] No open release-blocking defects remain.
- [ ] Version metadata, hashes and release notes refer to the same commit/artifacts.

Decision: **PROMOTE / HOLD**

Reviewer/date/notes:

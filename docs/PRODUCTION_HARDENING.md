# Production hardening audit — 10 September 2026

## Baseline

This pass starts from `prod/rc2-integration` commit `680839f`, not `main` (`baf701d`). RC2 contains the daily career flow, launch database, registration, transfers and match viewing. The branch is under active development; the README's earlier phase-completion claims are not proof of production readiness.

## Implemented locally

- Correct Godot 4.7.2 compilation failures in tactics, scouting, recruitment, detailed match simulation and match rendering.
- Reserve a free save slot for each new career. An unreadable save or backup still reserves its slot. If all slots are occupied, require an explicit Save As selection.
- Clear a previous career's save path when starting a new career; retain the active slot when a Save As operation fails; display autosave failures.
- Validate save envelope types before migration and retain a valid backup when replacing a corrupt primary save.
- Resume an in-memory career from the main menu.
- Index players during registration, reject duplicate registrations, and exclude transferred or retired players from registered squads.
- Resolve physio quality once per club per day instead of scanning all staff for each player.
- Aggregate events through current-match player/statistic lookups instead of searching the entire saved match history for every event.
- Provide isolated Windows test execution, log checks, PASS markers, timeouts and focused save, registration and UI regression tests.
- Cancel superseded validation workflow runs per workflow/ref, and cover persistence, tactics, registration and career UI changes in RC2 checks.

## Remaining release work

1. Complete the full regression and long-season soak on this integrated branch, including year rollover and promoted/relegated squads. Earlier green results on main do not validate RC2.
2. Profile full eight-country creation, weekly training and matchday progression on target hardware. World generation and day advancement still run synchronously from UI callbacks; provide progress and responsive input before scaling the database further.
3. Finish accessibility and localization in the career UI. The current high-contrast handler sets the same modulation in both branches, and most career labels remain literal English text. Validate large text and scale settings visually.
4. Add deliberate overwrite/delete confirmation and clearer load-failure feedback. The new protections prevent implicit reuse of an occupied save slot; explicit Save As overwrite and deletion remain immediate.
5. Validate Windows release exports, pinned SQLite integration and installation on a clean machine. The dependency-free local-save path alone is insufficient release evidence.
6. Reconcile README/version claims with tested RC2 behavior and resolve the hosted runner queue before merging. Concurrency changes reduce future duplicate work but do not diagnose account/runner capacity or remove the existing queue until applied remotely.

See `LOCAL_VALIDATION.md` for repeatable local tests. This is a first hardening increment, not a declaration that every roadmap feature is complete.

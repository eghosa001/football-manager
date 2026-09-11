# Remaining polish + housekeeping (audit P3, items 28-33)

## Tutorial/onboarding (31)
Six-step first-season guide exists. Remaining: contextual first-transfer,
first-tactic, registration, scouting, finances, matchday tips; dismiss/restart.
Implement as `CareerTutorial` triggers bound to existing command services —
no new sim required.

## Audio (32)
Explicit release gap. Planned buses: UI, crowd ambience, whistle, goals,
subs. Include volume categories + mute + accessibility cues. No binary assets
committed yet; add `.ogg` under `assets/audio/` with `AudioStreamPlayer` hooks
in `MatchViewer` and career scenes.

## World history (33)
Awards/legends/manager history/rivalries exist. For long saves add: records,
competition histories, all-time apps/goals, transfer records, club honours,
biographies, timelines, league-position histories, hall of fame. Consume
existing causal records; do not re-simulate.

## Housekeeping
- PR #8 (`prod/database-competitions`): superseded by RC2/main. Close as
  superseded — do not merge. Requires maintainer click or `gh pr close 8`.
- Old phase branches (`phase-1-2-*`, `phase-3-*`, ...): delete once unique work
  confirmed on `main`. Keep `main`, active `phase-12-*`, one release tag.
- CI duplication: `tools/release-smoke.ps1` now shared by `ci.yml` +
  `release-candidate.yml`. Extend to any new workflow instead of copying
  PowerShell blocks.

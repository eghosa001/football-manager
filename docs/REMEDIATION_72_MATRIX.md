# 72-gap remediation matrix

This document is the authoritative status matrix for the September 2026 production-readiness audit. It supersedes older progress notes where they disagree with current code.

Status meanings:

- **Implemented** — production-path source change exists on `fix/72-gap-remediation` and is covered by a deterministic regression or an existing integration path.
- **Integrated / validation pending** — source path is integrated but the current PR still needs runner execution/statistical or soak validation.
- **Partial** — material progress exists, but additional depth/presentation integration remains.
- **Acceptance gate** — cannot truthfully be completed by source code alone; requires the named OS/device/signing/long-run execution.

| # | Audit gap | Status | Current remediation / gate |
|---:|---|---|---|
| 1 | Fouls/refereeing | Integrated / validation pending | `football_laws_engine.gd`: causal foul probability, dangerous play, denial, advantage, cards, penalties. |
| 2 | Offside | Integrated / validation pending | Laws engine produces offside decisions and indirect-free-kick restarts; continuous spatial calibration still needs runner validation. |
| 3 | Set pieces | Partial | Canonical corner/free-kick/penalty restarts now exist. Full routine/taker/marking animation depth remains presentation/simulation follow-up. |
| 4 | Suspensions | Implemented | `discipline_service.gd` implements competition-aware accumulation, red bans, service and carry-over. |
| 5 | Passing depth | Integrated / validation pending | Passing now incorporates quality, pressure, weak foot and weather; continuous-engine distribution still pending. |
| 6 | First touch | Integrated / validation pending | Independent receiver-control failure can cause turnover. |
| 7 | Action vocabulary | Partial | Canonical action classification includes pass, one-two, through ball, cross, recycle and clear; specialised movement signatures still need calibration. |
| 8 | Weather | Integrated / validation pending | Clear/rain/heavy-rain/hot profiles affect passing, touch, shooting and injury context. |
| 9 | Ball/player physical state | Partial | Existing continuous spatial state retained; remediation adds contextual loads/injuries but does not yet replace all target-following physics. |
| 10 | Goalkeeping | Partial | Existing keeper save quality retained; full aerial/sweeper/rebound/distribution behavioural state remains future depth. |
| 11 | Substitution AI | Integrated / validation pending | Fixed-minute substitutions replaced in full continuous wrapper with fitness/card/match-state decisions and injury-forced changes. |
| 12 | In-match tactical AI | Integrated / validation pending | Managers react to score, minute and discipline with mentality/tempo/press/regroup changes. |
| 13 | Tactical instruction causality | Partial | More instructions now flow into match context; not every instruction yet has a unique low-level behaviour. |
| 14 | Roles/duties | Partial | Existing role catalogue preserved; unique movement signatures for every role remain a depth item. |
| 15 | Tactical familiarity | Implemented | Weekly training now tracks formation, role, tempo, pressing, defensive shape, passing style and set-piece familiarity separately. |
| 16 | Continuous statistical realism | Acceptance gate | Requires dedicated large continuous-engine distribution run after PR compiles. Do not reuse abstract-engine 100k result. |
| 17 | Tier equivalence | Acceptance gate | Existing tier policy is retained; cross-tier regression must be executed on equivalent populations. |
| 18 | Match-engine generations | Partial | Full-match production wrapper is moving to one laws/continuous path; legacy engines remain until parity validation permits safe removal. |
| 19 | Player development | Implemented | Weekly progression is continuous and attribute/session specific rather than relying only on annual CA deltas. |
| 20 | Dynamic potential | Implemented | Players now have base potential, mutable development ceiling, trajectory and momentum affected by environment, playing time, mentality and injuries. |
| 21 | Injury consolidation | Partial | Match/training injury causality improved; legacy lifecycle injury rolls still require consolidation after regression parity. |
| 22 | Match injury immediacy | Implemented | Injuries occur at event minute, affect the correct team, force substitutions, or leave team short-handed when subs are exhausted. |
| 23 | Youth generation depth | Partial | Existing generator remains; geography service now supplies origin primitives. Rich identity/intake variation still needs further generator integration. |
| 24 | Relationships | Partial | Existing rivalry/legend world depth remains; richer person-to-person friendship/dislike/mentoring/family/agent relationships are not yet fully unified. |
| 25 | Human manager career/jobs | Implemented | `manager_career_service.gd`: unemployment, application, interview, contract, appointment, resignation, sack, approaches and national-team field. UI wiring still needs playtest. |
| 26 | AI manager careers | Implemented | Manager reputation, history and tactical-identity evolution added to career service. |
| 27 | International football | Implemented | Eligibility/dual nationality commitment, balanced selection, call-up/release, caps/goals/minutes, fatigue/injuries, managers, calendar and finals lifecycle. |
| 28 | Fixture constraint solver | Implemented | Rest windows, date blocks, international dates, venue blackouts/shared venues and postponement/rescheduling. |
| 29 | Competition rules | Implemented | Configurable tie-breaks, ET/pens/replays, draw restrictions, byes, registration, discipline and qualification cascades. |
| 30 | Transfer negotiation split | Implemented | Structured `NegotiationDepth` evaluation is now authoritative in `TransferNegotiation`. |
| 31 | Contract clauses | Implemented | Appearance/goal/clean-sheet bonuses, release clause, extensions, promotion/relegation wage changes and squad status are normalized as real terms. |
| 32 | Agents | Implemented | Persistent multi-client registry, acquisition/loss, relationships, reputation, preferences, conflicts and history. |
| 33 | Transfer AI planning | Partial | Negotiation depth improved; complete multi-year succession/registration/resale opportunity-cost planner remains to be consolidated. |
| 34 | Scouting ecosystem | Implemented | Networks, country/language knowledge, workload, budgets, travel factor, decay, hidden-trait discovery and analyst reports. |
| 35 | Staff depth | Partial | Existing staff market/development retained; workload/specialism/course depth still needs broader career/UI integration. |
| 36 | Finance | Implemented / validation pending | Economic indices, sponsor/broadcast valuation, financing costs, debt/wage controls and insolvency-watch logic added; must be season-loop validated. |
| 37 | 100-year economy | Acceptance gate | Requires a full long-run economy soak using the new indices/controls. |
| 38 | Facilities | Partial | Existing facility categories retained; full construction-project lifecycle remains less mature than stadium projects. |
| 39 | Boards/supporters | Partial | Existing board evaluation retained; ownership transitions/negotiated objectives/supporter groups remain deeper simulation work. |
| 40 | Awards | Partial | History infrastructure exists; all awards still need canonical-stat driven selection audit. |
| 41 | News architecture | Partial | Domain-event path exists; direct legacy annual-news manufacturing remains until migration/parity tests. |
| 42 | Causal explanations | Implemented / expanding | New transfer, manager, competition, finance and mod decisions expose structured reason codes; legacy decisions are being migrated incrementally. |
| 43 | Starting-world identity | Partial | Canonical generator still needs richer curated country/city/name distribution; geography primitives added. |
| 44 | Regions/cities | Implemented | `geography_service.gd`: persistent regions/cities, origins, distances, travel, local rivalries and scouting affinity. |
| 45 | Relational SQLite | Integrated / validation pending | Core countries/clubs/players/competitions/contracts/fixtures now have typed tables, keys, FKs, constraints and indexes; auxiliary generic payload rows remain for compatibility. |
| 46 | Save migrations | Implemented | Schema v3 supports v0→v1→v2→v3 and rejects unsupported future versions. |
| 47 | Save integrity | Implemented | Binary saves include payload checksum while remaining backward compatible with the legacy header. |
| 48 | Mod dependencies/conflicts | Implemented | Manifest service adds API compatibility, dependencies, conflicts, load order, write conflicts, integrity and safe removal checks. |
| 49 | Editor usability | Partial | Existing graphical editor retained; complex competition-stage authoring still needs form-level UX work. |
| 50 | Monolithic career UI | Partial | Not safe to split large UI scripts before current regression branch is green; decomposition remains a maintainability task. |
| 51 | Accessibility | Acceptance gate | Keyboard-only, focus order, screen-reader, contrast and large-text layout require visual/device testing. |
| 52 | Localization | Partial | Existing translations retained; generated/dynamic strings still require full catalogue audit. |
| 53 | Audio | Partial | Existing procedural cues retained; commercial soundscape/device lifecycle remains polish work. |
| 54 | Match viewer | Partial | Existing viewer/analytics retained; smoothing, camera, overlays, readability and low-end performance require playtesting. |
| 55 | Analytics | Partial | New canonical foul/offside/turnover/action events improve future analytics, but xA/xT/progressive actions still need complete event coverage. |
| 56 | Performance engineering | Acceptance gate | Benchmark baselines, memory/save-growth curves and minimum-hardware budgets require executed profiling. |
| 57 | Continuous-engine profiling | Acceptance gate | Requires 90-minute continuous profiling on target hardware after source validation. |
| 58 | Mobile performance | Acceptance gate | Battery/thermal/memory/touch/save/runtime must be tested on real Android/iOS devices. |
| 59 | Main green validation | Acceptance gate | PR #15 is not mergeable until current head CI executes successfully; self-hosted jobs are presently queued. |
| 60 | Full 100-season career | Acceptance gate | Must be executed at launch-scale world size; synthetic soak is insufficient. |
| 61 | Continuous 100k distribution | Acceptance gate | Must run against continuous engine after build is green. |
| 62 | Cross-tier regression | Acceptance gate | Must execute identical seeded populations across detailed/event/abstract/aggregate tiers. |
| 63 | Fuzz/destructive tests | Partial | Schema/mod/save hardening added; broader malformed-save/rule/economy/squad property fuzz suite remains execution work. |
| 64 | Linux runtime acceptance | Acceptance gate | Must launch exported build on Linux, verify offline/save round-trip and hashes. |
| 65 | Clean Windows install | Acceptance gate | Must test installer on a machine without Godot: career→save→quit→reopen→load→match. |
| 66 | Windows installer/update | Partial / acceptance gate | Existing release exports/smoke retained; installer/uninstaller/update/save-preservation lifecycle needs packaging and clean-machine execution. |
| 67 | macOS/iOS signing | Acceptance gate | Requires Apple certificates, notarization/stapling/Xcode archive/TestFlight. |
| 68 | Android store/device | Acceptance gate | Requires real-device APK plus Play AAB acceptance flow. |
| 69 | CI fragmentation | Partial | Authoritative CI now includes remediation + release-hardening regressions; duplicate historical workflows remain until green parity proves they can be retired safely. |
| 70 | Dictionary-heavy state | Implemented / incremental | `DomainValidator` adds required types/ranges/references; typed SQLite enforces core persistence constraints. Full conversion to typed Resources/classes is intentionally incremental. |
| 71 | v2/v3/v4 layers | Partial | Production wrapper is converging; removal/flattening is intentionally deferred until parity and long-run validation. |
| 72 | Stale documentation | Implemented | This matrix is the current authoritative audit status and explicitly separates implemented source work from unexecuted acceptance gates. |

## Release rule

No item marked **Acceptance gate** is considered complete until the named test has actually run and evidence is retained. In particular, PR source code alone cannot close clean-machine installation, Linux/macOS/iOS/Android device acceptance, accessibility playtesting, continuous 100k distributions or full 100-season careers.

## Current integration branch

- Branch: `fix/72-gap-remediation`
- Pull request: #15
- Merge policy: do not merge until the authoritative regression workflow has executed successfully and blocking findings are corrected.

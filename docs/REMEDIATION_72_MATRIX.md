# 72-gap remediation matrix

This is the authoritative status for the September 2026 production-readiness audit. Older progress documents are historical when they disagree with this file.

Status meanings:
- **Implemented** — the source remediation exists on `fix/72-gap-remediation` and has deterministic regression coverage.
- **Integrated / validation pending** — the source remediation is present, but runner/statistical/soak execution is still required before release acceptance.
- **Acceptance gate** — cannot truthfully be closed by repository source alone; it requires target hardware, signing credentials, visual/device review, or a long-running executed gate.

| # | Audit gap | Status | Current remediation / gate |
|---:|---|---|---|
| 1 | Fouls/refereeing | Integrated / validation pending | Causal foul, advantage, dangerous play, denial, cards and penalty decisions in `football_laws_engine.gd`. |
| 2 | Offside | Integrated / validation pending | Offside decisions and indirect-free-kick restarts are represented in the detailed laws path. |
| 3 | Set pieces | Integrated / validation pending | `match_depth_service.gd` adds corner/free-kick/penalty/throw-in routines, specialist takers, aerial targets and zonal/man marking choices. |
| 4 | Suspensions | Implemented | Competition-aware yellow accumulation, red bans, service and carry-over in `discipline_service.gd`. |
| 5 | Passing depth | Integrated / validation pending | Quality, pressure, weak foot, positioning and weather feed the detailed path; distribution calibration remains executable validation. |
| 6 | First touch | Integrated / validation pending | Receiver-control failure can independently cause turnovers. |
| 7 | Action vocabulary | Integrated / validation pending | Pass/dribble/shoot plus through-ball/cross/recycle/clear/set-piece classifications and specialist analytics are represented; calibration is pending. |
| 8 | Weather | Integrated / validation pending | Clear/rain/heavy-rain/hot profiles affect execution, touch, shooting and injury context. |
| 9 | Ball/player physical state | Integrated / validation pending | Continuous spatial state plus loads, body orientation, current action, tactical target and ball velocity metadata. |
| 10 | Goalkeeping | Integrated / validation pending | Keeper positioning, angle closing, cross claim/punch, sweeper choices, rebounds, handling errors and distribution intent in `match_depth_service.gd`. |
| 11 | Substitution AI | Integrated / validation pending | Fitness, cards, score state and injuries drive substitutions; exhausted substitutions can leave teams short-handed. |
| 12 | In-match tactical AI | Integrated / validation pending | Score/minute/discipline produce mentality, tempo, pressing, regroup and time-wasting adaptations. |
| 13 | Tactical instruction causality | Integrated / validation pending | Instruction context is carried into detailed events and movement/decision modifiers; sensitivity calibration remains a statistical gate. |
| 14 | Roles/duties | Integrated / validation pending | Distinct signatures for mezzala, regista, false nine, target forward, inverted fullback/wingback, ball-winner, playmaker and sweeper keeper augment the existing role catalogue. |
| 15 | Tactical familiarity | Implemented | Formation, role, tempo, pressing, shape, passing and set-piece familiarity are tracked separately. |
| 16 | Continuous statistical realism | Acceptance gate | `tests/continuous_distribution_gate.gd` now supplies the dedicated 100k gate; it still must execute successfully. |
| 17 | Tier equivalence | Acceptance gate | `tests/cross_tier_regression.gd` compares seeded detailed/event/abstract/aggregate populations; execution remains required. |
| 18 | Match-engine generations | Implemented / validation pending | `engine_router.gd` provides one stable interface and marks the continuous detailed engine authoritative; legacy engines remain only as tier implementations until parity execution. |
| 19 | Player development | Implemented | Continuous/attribute-specific development and training progression are present. |
| 20 | Dynamic potential | Implemented | Base potential, mutable ceiling, trajectory and development momentum are modeled. |
| 21 | Injury consolidation | Implemented | `PlayerLifecycleV2` disables the unrelated annual injury lottery; match/training/medical systems are the injury authority. |
| 22 | Match injury immediacy | Implemented | Exact-minute injuries alter the affected team immediately and force substitution/short-handed play. |
| 23 | Youth generation depth | Implemented | Variable intake sizes, nationality/dual-nationality, regions/cities, richer names, feet, positions, body dimensions, personality and development ceiling in `youth_academy.gd`. |
| 24 | Relationships | Implemented | `relationship_service.gd` covers respect, friendship, dislike, mentoring, family, manager, agent and social groups with event evolution and decay; `CareerCycleV2` activates it. |
| 25 | Human manager career/jobs | Implemented | Unemployment, applications, interviews, contracts, appointments, resignations, sackings, approaches and national-team field. |
| 26 | AI manager careers | Implemented | Reputation/history/tactical identity and AI employment evolution are represented. |
| 27 | International football | Implemented | Eligibility, commitments, squad balance, call-ups/releases, caps/goals/minutes, fatigue/injuries, managers, calendar and finals lifecycle. |
| 28 | Fixture constraint solver | Implemented | Rest windows, blocked dates, international dates, venue conflicts and postponement/rescheduling. |
| 29 | Competition rules | Implemented | Configurable tie-breakers, ET/pens/replays, seeding/draw restrictions, byes, registration, discipline and qualification cascades. |
| 30 | Transfer negotiation split | Implemented | Structured negotiation depth is used by the authoritative negotiation service. |
| 31 | Contract clauses | Implemented | Bonuses, release clauses, extensions, promotion/relegation wage changes and squad status are normalized terms. |
| 32 | Agents | Implemented | Persistent multi-client registry, acquisition/loss, relationships, reputation, preferences, conflicts and history. |
| 33 | Transfer AI planning | Implemented | `squad_planning_service.gd` models depth, age curve, succession, expiring contracts, registration/homegrown limits, resale, loans, tactical fit and opportunity cost; plans are persisted each season by `CareerCycleV2`. |
| 34 | Scouting ecosystem | Implemented | Networks, country/language knowledge, travel factor, workload, budgets, decay, hidden traits and analyst reports. |
| 35 | Staff depth | Implemented | `staff_operations_service.gd` adds responsibilities/workload, specialisms, licenses/courses, recruitment hierarchy, medical and sports-science effectiveness; annual lifecycle integration is active. |
| 36 | Finance | Integrated / validation pending | Economic indices, sponsorship/broadcast valuation, financing cost, wage/debt controls and insolvency state are implemented; long-run economy execution remains. |
| 37 | 100-year economy | Acceptance gate | The canonical `full_career_soak.gd` now exercises the current career lifecycle for 100 seasons; it must still run successfully. |
| 38 | Facilities | Implemented | `facility_project_service.gd` adds approval, funding, construction duration, delays, overruns and completion effects. |
| 39 | Boards/supporters | Implemented | Persistent board vision, objective negotiation, supporter groups/mood and ownership changes are implemented and initialized in the canonical career cycle. |
| 40 | Awards | Implemented | `award_service.gd` selects awards from canonical season statistics, competition strength and positional performance; `CareerCycleV2` replaces legacy reputation-only player awards. |
| 41 | News architecture | Implemented | Domain events are the canonical source; `CareerCycleV2` removes legacy manufactured articles and `NewsEventConsumer` is the user-facing article producer. |
| 42 | Causal explanations | Implemented | New decision services emit reason codes across match, transfers, management, competition, finance, mods, boards and squad planning. |
| 43 | Starting-world identity | Implemented / validation pending | Rich youth/geographic identity, name pools and launch database paths replace repetitive career growth; fallback generator remains intentionally deterministic. |
| 44 | Regions/cities | Implemented | Persistent geography supports origins, travel, local rivalry and scouting affinity. |
| 45 | Relational SQLite | Integrated / validation pending | Core country/club/player/competition/contract/fixture tables have typed columns, constraints, indexes and foreign keys; generic rows remain only for auxiliary compatibility. |
| 46 | Save migrations | Implemented | v0→v1→v2→v3 migration plus future-version rejection. |
| 47 | Save integrity | Implemented | Binary payload checksums plus existing atomic/backup handling. |
| 48 | Mod dependencies/conflicts | Implemented | Compatibility, dependencies, conflicts, order, write conflicts, integrity and removal checks. |
| 49 | Editor usability | Implemented / validation pending | `competition_form_schema.gd` supplies forms, validation and previews for stages/rules/registration/discipline instead of requiring raw JSON concepts. UI playtest remains. |
| 50 | Monolithic career UI | Implemented / validation pending | `career_screen_registry.gd` establishes modular screen/controller boundaries around dashboard, squad, tactics, training, management, search and match; deeper physical file splitting can proceed without changing public routing. |
| 51 | Accessibility | Acceptance gate | `ui_quality_audit.gd` adds automated focus/target/wrapping/localization checks, but keyboard-only, screen-reader, contrast and large-text acceptance require real visual/device testing. |
| 52 | Localization | Implemented / validation pending | Automated UI catalogue audit now detects untranslated literal controls; dynamic/event presentation still requires locale-by-locale review. |
| 53 | Audio | Implemented / validation pending | `dynamic_audio_director.gd` adds crowd intensity, richer event cues, sudden-sound reduction and device lifecycle state; subjective/device audio acceptance remains. |
| 54 | Match viewer | Implemented / validation pending | `match_viewer_quality.gd` adds interpolation, frame validation and low-end/mobile quality policy; visual readability/performance still requires playtest. |
| 55 | Analytics | Implemented | `advanced_match_analytics.gd` provides xA, xT, progressive passes/carries, pressures, tackles, crosses, set pieces, turnovers, field tilt, box entries and shot-creating actions. |
| 56 | Performance engineering | Acceptance gate | Source baselines/policies exist; memory/save-growth curves and minimum-hardware budgets require executed profiling on target machines. |
| 57 | Continuous-engine profiling | Acceptance gate | Detailed 90-minute profiling must execute on representative hardware. |
| 58 | Mobile performance | Acceptance gate | Battery, thermal, memory, touch, save and match runtime require real Android/iOS devices. |
| 59 | Main green validation | Acceptance gate | Authoritative CI includes all remediation suites but the current self-hosted job must execute successfully before merge. |
| 60 | Full 100-season career | Acceptance gate | `tests/full_career_soak.gd` now uses `CareerCycleV2`; the 100-season run still must execute. |
| 61 | Continuous 100k distribution | Acceptance gate | Dedicated 100k workflow-dispatch gate exists and still must execute. |
| 62 | Cross-tier regression | Acceptance gate | Dedicated seeded cross-tier workflow-dispatch gate exists and still must execute. |
| 63 | Fuzz/destructive tests | Implemented | `destructive_fuzzer.gd` adds malformed saves, schema/reference mutations, competition rules, mod dependencies, extreme economy and huge-squad cases. |
| 64 | Linux runtime acceptance | Acceptance gate | Export exists in CI; actual Linux launch/offline/save round-trip/hash evidence requires Linux execution. |
| 65 | Clean Windows install | Acceptance gate | Installer and smoke tooling now exist; a genuinely clean Windows machine must still execute career→save→quit→reopen→load→match. |
| 66 | Windows installer/update | Implemented / acceptance pending | Inno Setup installer plus clean-install smoke script provide install directory, shortcuts, version metadata, uninstall and external save preservation; build/upgrade execution is required. |
| 67 | macOS/iOS signing | Acceptance gate | Requires Apple certificates, notarization/stapling, Xcode archive and TestFlight/device validation. |
| 68 | Android store/device | Acceptance gate | Requires APK/AAB execution and store/device acceptance on real Android hardware. |
| 69 | CI fragmentation | Implemented | Superseded phase/production/RC workflows were removed; authoritative CI remains alongside dedicated mobile/runner utilities. |
| 70 | Dictionary-heavy state | Implemented / incremental | Domain validation and relational persistence now fail loudly for core malformed state; conversion of every runtime dictionary to typed classes is not required for this release. |
| 71 | v2/v3/v4 layers | Implemented / validation pending | `engine_router.gd` and `CareerCycleV2` define authoritative interfaces; legacy implementations remain behind those boundaries until parity gates prove safe physical deletion. |
| 72 | Stale documentation | Implemented | This matrix is the authoritative feature/gate status. |

## Release rule

All source-remediable audit findings now have an implementation path and regression/validation entry point. Items marked **Acceptance gate** remain open until their named execution actually succeeds; source code cannot substitute for clean-machine, target-device, signing, accessibility, profiling, 100k-statistical or 100-season evidence.

## Current integration branch
- Branch: `fix/72-gap-remediation`
- Pull request: #15
- Merge policy: do not merge until authoritative CI is green and any blocking regression is corrected.

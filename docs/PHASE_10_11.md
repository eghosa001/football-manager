# Phase 10 and Phase 11

## Phase 10 — Living World, Modding and Release Hardening

**Status:** implemented.

Phase 10 completes the original revised roadmap. The living-world layer adds deterministic, bounded yearly evolution for player morale, confidence and happiness; player, club and manager reputation; same-club relationships with decay; title-race rivalries; manager season/trophy histories; competition awards; retired-player legends; and causal news records. News consumes structured simulation reasons and never drives domain state.

Modding is intentionally data-only. `ModLoader` accepts JSON patches for whitelisted club, player, country and competition fields, rejects unsupported mutation fields, and clamps numeric values. `ModEditor` creates, validates, exports and re-imports the same format.

Release hardening includes save schema v2 with migration from schema v1, bounded news/history collections, continued detailed/background simulation tiers, persistent accessibility settings, localization foundations, and an integrated 100-season career/save soak.

**Acceptance:** deterministic living-world replay; bounded morale/reputation/relationships/news; historical awards and manager careers; safe mod rejection without partial mutation; schema migration; 100-season competition/economy/population/save health; 100,000-match statistical validation; release export validation.

## Phase 11 — Release Candidate and Platform Delivery

**Status:** implemented as the post-roadmap release-candidate phase.

Phase 11 formalizes delivery of the Windows-first offline game. The project is versioned `1.0.0-rc1` and includes committed Godot export presets for Windows Desktop x86_64 and Linux/X11 x86_64. CI builds both exports, verifies non-empty artifacts, and boots the Linux release executable headlessly without a network dependency. A separate manual release-candidate workflow generates SHA-256 integrity manifests and uploads platform artifacts.

User settings persist locally and include language, UI/font scaling, high contrast, reduced motion, screen-reader labels and autosave behavior. Top-level career navigation is localized in English, French and Portuguese with catalog-coverage tests.

`ReleaseGuard` defines release metadata, validates required world collections and globally unique IDs, checks required packaged resources, and makes the offline contract explicit.

**Acceptance:** all Phase 1–10 regressions pass; Phase 10/11 acceptance suite passes; Windows and Linux x86_64 release exports build; Linux export boots offline; save/settings round trips pass; localization coverage is complete for shipped keys; release integrity validation passes; SQLite remains compatible.

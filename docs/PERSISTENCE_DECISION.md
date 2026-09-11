# Persistence architecture decision — serialized world (Option A)

Status: adopted. SQLite remains a serialized-world container, not a normalized
relational database (audit item 16).

Rationale:
- Deterministic typed saves already work through `SaveStore` (atomic + backup)
  and `SqliteSaveStore` (same migration path).
- Normalized tables (players/clubs/contracts/fixtures/results/...) would be
  substantial work with high migration risk after users have real saves.
- Mobile + desktop release needs incremental saves and corruption recovery more
  than SQL queryability.

Consequences:
- Document this file as the permanent save architecture.
- Invest in incremental saves, migration fixtures, fuzz/corruption tests, and
  serialization performance — not schema normalization.
- Revisit only if external tooling genuinely needs SQL access.

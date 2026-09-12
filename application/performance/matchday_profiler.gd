class_name MatchdayProfiler
extends RefCounted

# Production performance contract. Baselines are intentionally conservative and
# evaluated with tolerance so CI catches regressions without pretending all
# machines have identical throughput.
const BASELINE := {
	"world_creation_ms": 8000.0,
	"ordinary_day_ms": 350.0,
	"weekly_advance_ms": 2500.0,
	"matchday_162_ms": 22000.0,
	"detailed_match_ms": 4000.0,
	"save_roundtrip_ms": 2500.0,
}
const TOLERANCE := 1.6
const MAX_LONG_SESSION_MEMORY_GROWTH_MB := 192.0
const MAX_SAVE_GROWTH_RATIO := 4.0

static func check(observed_ms: float, key: String) -> Dictionary:
	var base := float(BASELINE.get(key, observed_ms))
	var ratio := observed_ms / maxf(base, 1.0)
	return {"key": key, "observed_ms": observed_ms, "baseline_ms": base, "ratio": ratio, "pass": ratio <= TOLERANCE}

static func check_memory_growth(start_bytes: int, end_bytes: int) -> Dictionary:
	var growth_mb := float(maxi(0, end_bytes - start_bytes)) / 1048576.0
	return {"growth_mb": growth_mb, "limit_mb": MAX_LONG_SESSION_MEMORY_GROWTH_MB, "pass": growth_mb <= MAX_LONG_SESSION_MEMORY_GROWTH_MB}

static func check_save_growth(initial_bytes: int, later_bytes: int) -> Dictionary:
	var ratio := float(maxi(1, later_bytes)) / float(maxi(1, initial_bytes))
	return {"ratio": ratio, "limit": MAX_SAVE_GROWTH_RATIO, "pass": ratio <= MAX_SAVE_GROWTH_RATIO}

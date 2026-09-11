class_name MatchdayProfiler
extends RefCounted

# Baseline-based performance gate (audit items 15, 26).
# Absolute thresholds are hardware-fragile; store baseline + tolerance.

const BASELINE := {"world_creation_ms": 8000.0, "ordinary_day_ms": 250.0, "matchday_162_ms": 22000.0}
const TOLERANCE := 1.6

static func check(observed_ms: float, key: String) -> Dictionary:
	var base := float(BASELINE.get(key, observed_ms))
	var ratio := observed_ms / maxf(base, 1.0)
	return {"key": key, "observed_ms": observed_ms, "baseline_ms": base, "ratio": ratio, "pass": ratio <= TOLERANCE}

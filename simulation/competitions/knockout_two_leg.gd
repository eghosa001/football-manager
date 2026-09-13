class_name KnockoutTwoLeg
extends RefCounted

# Modern two-legged ties: aggregate score, then extra time and penalties.
# The away-goals rule is disabled by default and should only be enabled by an
# explicitly configured legacy/mod competition.

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func seeded_draw(club_ids: Array, seed: int, coefficients: Dictionary = {}) -> Array:
	var entrants: Array = club_ids.duplicate()
	entrants.sort()
	if not coefficients.is_empty():
		entrants.sort_custom(func(a, b): return float(coefficients.get(a, 0.0)) > float(coefficients.get(b, 0.0)))
		var seeded: Array = entrants.slice(0, maxi(1, entrants.size() / 2))
		var unseeded: Array = entrants.slice(maxi(1, entrants.size() / 2))
		_shuffle_with(seeded, seed)
		_shuffle_with(unseeded, seed + 7)
		var pairs: Array = []
		for i in range(maxi(seeded.size(), unseeded.size())):
			pairs.append({"home": String(seeded[i % seeded.size()]), "away": String(unseeded[i % unseeded.size()])})
		return pairs
	_shuffle_with(entrants, seed)
	var pairs: Array = []
	for i in range(0, entrants.size(), 2):
		pairs.append({"home": String(entrants[i]), "away": String(entrants[i + 1]) if i + 1 < entrants.size() else ""})
	return pairs

func resolve_tie(home: String, away: String, first_leg: Dictionary, second_leg: Dictionary, away_goals_rule: bool = false) -> Dictionary:
	var home_agg: int = int(first_leg.get("home_goals", 0)) + int(second_leg.get("away_goals", 0))
	var away_agg: int = int(first_leg.get("away_goals", 0)) + int(second_leg.get("home_goals", 0))
	if home_agg != away_agg:
		return {"winner": home if home_agg > away_agg else away, "decided": "aggregate", "home_agg": home_agg, "away_agg": away_agg}

	# Kept only for explicitly configured legacy/mod competitions.
	if away_goals_rule:
		var home_away_goals: int = int(second_leg.get("away_goals", 0))
		var away_away_goals: int = int(first_leg.get("away_goals", 0))
		if home_away_goals != away_away_goals:
			return {"winner": home if home_away_goals > away_away_goals else away, "decided": "away_goals", "home_agg": home_agg, "away_agg": away_agg}

	# Extra time is played at the second-leg venue. `home` is the club that was
	# at home in leg one, so it is the away side in leg two.
	var et_home_original: int = int(second_leg.get("extra_time_away_goals", 0))
	var et_away_original: int = int(second_leg.get("extra_time_home_goals", 0))
	if et_home_original != et_away_original:
		return {
			"winner": home if et_home_original > et_away_original else away,
			"decided": "extra_time",
			"home_agg": home_agg + et_home_original,
			"away_agg": away_agg + et_away_original,
			"extra_time": true
		}

	var shootout_winner: String = String(second_leg.get("shootout_winner", ""))
	if shootout_winner in [home, away]:
		return {"winner": shootout_winner, "decided": "penalties", "home_agg": home_agg, "away_agg": away_agg, "extra_time": true}

	return {
		"winner": "",
		"decided": "level_after_90",
		"home_agg": home_agg,
		"away_agg": away_agg,
		"needs_extra_time": true,
		"needs_shootout": false
	}

func _shuffle_with(values: Array, seed: int) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j: int = SeededRngClass.value_for(seed, 77000 + i) % (i + 1)
		var tmp = values[i]
		values[i] = values[j]
		values[j] = tmp

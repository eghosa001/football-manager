class_name CompetitionRules
extends RefCounted

func normalize(raw: Dictionary) -> Dictionary:
	return {
		"type": String(raw.get("type", "league")),
		"teams": maxi(2, int(raw.get("teams", 20))),
		"rounds": maxi(1, int(raw.get("rounds", 2))),
		"legs": clampi(int(raw.get("legs", 1)), 1, 2),
		"points_win": int(raw.get("points_win", 3)),
		"points_draw": int(raw.get("points_draw", 1)),
		"extra_time": bool(raw.get("extra_time", false)),
		"penalties": bool(raw.get("penalties", false)),
		"away_goals": bool(raw.get("away_goals", false)),
		"registration_max": int(raw.get("registration_max", 25)),
		"homegrown_min": int(raw.get("homegrown_min", 0)),
		"foreign_max": int(raw.get("foreign_max", -1)),
		"promotion_places": maxi(0, int(raw.get("promotion_places", 0))),
		"relegation_places": maxi(0, int(raw.get("relegation_places", 0))),
		"tie_breakers": raw.get("tie_breakers", ["points","goal_difference","goals_scored","wins"]).duplicate()
	}

func validate(rules: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var normalized := normalize(rules)
	if String(normalized.type) not in ["league","knockout","group_knockout"]:
		errors.append("unsupported competition type")
	if int(normalized.registration_max) < 11:
		errors.append("registration_max must be at least 11")
	if int(normalized.homegrown_min) > int(normalized.registration_max):
		errors.append("homegrown minimum exceeds registration maximum")
	if int(normalized.foreign_max) > int(normalized.registration_max):
		errors.append("foreign maximum exceeds registration maximum")
	return errors

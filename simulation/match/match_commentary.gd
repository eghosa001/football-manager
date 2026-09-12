class_name MatchCommentary
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func lines_for(result: Dictionary, home_name: String, away_name: String, seed: int) -> Array:
	var lines: Array = []
	lines.append("Kickoff: %s vs %s." % [home_name, away_name])
	var weather: Dictionary = result.get("weather", {})
	if not weather.is_empty():
		lines.append("Conditions: %s." % String(weather.get("kind", "clear")).replace("_", " ").capitalize())
	var events: Array = result.get("events", [])
	var index := 0
	for event in events:
		var minute := int(event.get("minute", 0))
		var kind := String(event.get("type", ""))
		var side := String(event.get("side", "home"))
		var team := home_name if side == "home" else away_name
		var actor := String(event.get("player_id", "No. %d" % (index % 11 + 1))).left(12)
		match kind:
			"goal", "shot":
				if String(event.get("outcome", "")) == "goal" or bool(event.get("success", false)):
					lines.append("%d: GOAL! %s score through %s (xG %.2f)." % [minute, team, actor, float(event.get("xg", 0.0))])
				elif String(event.get("outcome", "")) == "saved":
					lines.append("%d: %s threaten — %s forces a save." % [minute, team, actor])
				elif kind == "shot":
					lines.append("%d: %s effort from %s misses." % [minute, team, actor])
			"through_ball":
				lines.append("%d: %s slide a through ball via %s." % [minute, team, actor] if bool(event.get("success", false)) else "%d: %s through ball cut out." % [minute, team])
			"cross":
				lines.append("%d: Cross from %s (%s)." % [minute, actor, team] if bool(event.get("success", false)) else "%d: %s cross cleared." % [minute, team])
			"corner", "free_kick", "penalty", "throw_in":
				lines.append("%d: %s — %s (%s routine)." % [minute, String(kind).capitalize(), team, String(event.get("routine", event.get("zone", "standard"))).replace("_", " ")])
			"clearance":
				lines.append("%d: %s clear their lines." % [minute, team])
			"card":
				lines.append("%d: %s shown for %s." % [String(event.get("card", "yellow")).capitalize(), actor, team])
			"foul":
				lines.append("%d: Foul by %s%s." % [minute, team, " inside the box" if bool(event.get("penalty", false)) else ""])
			"offside":
				lines.append("%d: Flag up — %s offside." % [minute, team])
			"substitution":
				lines.append("%d: Change for %s — %s on for %s." % [minute, team, String(event.get("player_in", "")).left(12), String(event.get("player_out", "")).left(12)])
			"goalkeeper_action":
				lines.append("%d: Keeper %s (%s)." % [minute, actor, String(event.get("action", "holds")).replace("_", " ")])
		index += 1
		if lines.size() > 220:
			break
	var stats: Dictionary = result.get("stats", {})
	lines.append("Full time: %s %d - %d %s." % [home_name, int(result.get("home_goals", 0)), int(result.get("away_goals", 0)), away_name])
	return lines

func highlight_level(event: Dictionary) -> String:
	match String(event.get("type", "")):
		"shot":
			return "goal" if String(event.get("outcome", "")) == "goal" else ("key" if String(event.get("outcome", "")) == "saved" else "extended")
		"through_ball", "cross", "penalty", "card":
			return "key"
		"corner", "free_kick", "goalkeeper_action":
			return "extended"
	return "goals_only" if String(event.get("type", "")) in ["goal"] else "full"

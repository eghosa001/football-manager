class_name MatchRatingService
extends RefCounted

func ratings(result: Dictionary) -> Array:
	var rows := {}
	var participants: Dictionary = result.get("participants", result.get("lineups", {}))
	for side in ["home", "away"]:
		for id in participants.get(side, []):
			rows[String(id)] = {"player_id":String(id),"side":side,"rating":6.0,"goals":0,"shots":0,"passes":0,"passes_completed":0,"key_actions":0,"cards":0}
	for event in result.get("events", []):
		var id := String(event.get("player_id", ""))
		if id == "" or not rows.has(id): continue
		var row: Dictionary = rows[id]
		match String(event.get("type", "")):
			"shot":
				row.shots = int(row.shots) + 1
				var xg := float(event.get("xg", 0.0))
				if String(event.get("outcome", "")) == "goal":
					row.goals = int(row.goals) + 1
					row.rating = float(row.rating) + 1.15 + clampf(0.25 - xg * 0.25, 0.0, 0.25)
				elif String(event.get("outcome", "")) == "saved": row.rating = float(row.rating) + 0.08
				else: row.rating = float(row.rating) - 0.04
			"goal":
				row.goals = int(row.goals) + 1; row.rating = float(row.rating) + 1.25
			"pass":
				row.passes = int(row.passes) + 1
				if bool(event.get("success", false)):
					row.passes_completed = int(row.passes_completed) + 1; row.rating = float(row.rating) + 0.012
				else: row.rating = float(row.rating) - 0.018
			"dribble":
				row.rating = float(row.rating) + (0.05 if bool(event.get("success", false)) else -0.03)
			"interception":
				row.key_actions = int(row.key_actions) + 1; row.rating = float(row.rating) + 0.08
			"corner", "free_kick":
				if bool(event.get("success", false)): row.rating = float(row.rating) + 0.03
			"card":
				row.cards = int(row.cards) + 1
				row.rating = float(row.rating) - (1.0 if String(event.get("card", "yellow")) == "red" else 0.25)
			"substitution": pass
	# Team outcome contributes slightly without overwhelming individual actions.
	var hg := int(result.get("home_goals", 0)); var ag := int(result.get("away_goals", 0))
	for row in rows.values():
		var win := (String(row.side) == "home" and hg > ag) or (String(row.side) == "away" and ag > hg)
		var loss := (String(row.side) == "home" and hg < ag) or (String(row.side) == "away" and ag < hg)
		if win: row.rating = float(row.rating) + 0.18
		elif loss: row.rating = float(row.rating) - 0.12
		row.rating = snappedf(clampf(float(row.rating), 1.0, 10.0), 0.1)
	var out: Array = rows.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary):
		if is_equal_approx(float(a.rating), float(b.rating)): return String(a.player_id) < String(b.player_id)
		return float(a.rating) > float(b.rating)
	)
	return out

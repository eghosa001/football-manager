class_name MatchRatingService
extends RefCounted

func ratings(result: Dictionary, lineups: Dictionary = {}) -> Array:
	var rows := {}
	var participants: Dictionary = result.get("participants", result.get("lineups", {}))
	for side in ["home", "away"]:
		for id in participants.get(side, []):
			rows[String(id)] = {"player_id": String(id), "side": side, "rating": 6.5, "goals": 0, "shots": 0, "passes": 0, "passes_completed": 0, "key_actions": 0, "cards": 0, "tackles": 0, "interceptions": 0, "saves": 0, "role": _role_for(side, String(id), result, lineups)}
	for event in result.get("events", []):
		var id := String(event.get("player_id", ""))
		if id == "" or not rows.has(id):
			continue
		var row: Dictionary = rows[id]
		_apply_event(row, event)
	# Role-aware evaluation: defenders earn ratings through duels and
	# positioning, creators through chances, keepers through shot-stopping.
	for row in rows.values():
		_apply_role_adjustment(row, result)
	# Team outcome contributes slightly without overwhelming individual actions.
	var hg := int(result.get("home_goals", 0)); var ag := int(result.get("away_goals", 0))
	for row in rows.values():
		var win := (String(row.side) == "home" and hg > ag) or (String(row.side) == "away" and ag > hg)
		var loss := (String(row.side) == "home" and hg < ag) or (String(row.side) == "away" and ag < hg)
		if win:
			row.rating = float(row.rating) + 0.18
		elif loss:
			row.rating = float(row.rating) - 0.12
		row.rating = snappedf(clampf(float(row.rating), 1.0, 10.0), 0.1)
		row["rating_policy"] = "role_aware"
	var out: Array = rows.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary):
		if is_equal_approx(float(a.rating), float(b.rating)):
			return String(a.player_id) < String(b.player_id)
		return float(a.rating) > float(b.rating)
	)
	return out

func _apply_event(row: Dictionary, event: Dictionary) -> void:
	match String(event.get("type", "")):
		"shot":
			row.shots = int(row.shots) + 1
			var xg := float(event.get("xg", 0.0))
			if String(event.get("outcome", "")) == "goal":
				row.goals = int(row.goals) + 1
				row.rating = float(row.rating) + 1.15 + clampf(0.25 - xg * 0.25, 0.0, 0.25)
			elif String(event.get("outcome", "")) == "saved":
				row.rating = float(row.rating) + 0.08
			else:
				row.rating = float(row.rating) - 0.04
		"goal":
			row.goals = int(row.goals) + 1; row.rating = float(row.rating) + 1.25
		"pass", "through_ball", "cross":
			row.passes = int(row.passes) + 1
			if bool(event.get("success", false)):
				row.passes_completed = int(row.passes_completed) + 1; row.rating = float(row.rating) + (0.02 if String(event.get("type", "")) != "pass" else 0.012)
				if String(event.get("type", "")) in ["through_ball", "cross"]:
					row.key_actions = int(row.key_actions) + 1
			else:
				row.rating = float(row.rating) - 0.018
		"dribble":
			row.rating = float(row.rating) + (0.05 if bool(event.get("success", false)) else -0.03)
		"tackle":
			row.tackles = int(row.tackles) + 1; row.key_actions = int(row.key_actions) + 1; row.rating = float(row.rating) + (0.09 if bool(event.get("success", true)) else -0.02)
		"interception":
			row.interceptions = int(row.interceptions) + 1; row.key_actions = int(row.key_actions) + 1; row.rating = float(row.rating) + 0.08
		"clearance":
			row.key_actions = int(row.key_actions) + 1; row.rating = float(row.rating) + 0.05
		"corner", "free_kick", "throw_in", "penalty":
			if bool(event.get("success", false)):
				row.rating = float(row.rating) + 0.03
		"goalkeeper_action":
			if String(event.get("handling", "clean")) == "rebound":
				row.rating = float(row.rating) - 0.05
			elif bool(event.get("success", true)):
				row.saves = int(row.saves) + 1; row.rating = float(row.rating) + 0.12
		"card":
			row.cards = int(row.cards) + 1
			row.rating = float(row.rating) - (1.0 if String(event.get("card", "yellow")) == "red" else 0.25)
		"substitution":
			pass

func _apply_role_adjustment(row: Dictionary, result: Dictionary) -> void:
	var role := String(row.get("role", "support"))
	var stats: Dictionary = result.get("stats", {}).get(String(row.side), {})
	if role in ["central_defender", "full_back", "ball_winner", "anchor", "cover_defender", "stopper"]:
		row.rating = float(row.rating) + float(row.get("tackles", 0)) * 0.03 + float(row.get("interceptions", 0)) * 0.03
		if int(stats.get("goals", 99)) == 0:
			row.rating = float(row.rating) + 0.25
	elif role in ["playmaker", "advanced_playmaker", "wide_playmaker", "deep_lying_playmaker"]:
		row.rating = float(row.rating) + float(row.get("key_actions", 0)) * 0.04
	elif role in ["advanced_forward", "poacher", "pressing_forward", "complete_forward"]:
		if int(row.get("shots", 0)) == 0:
			row.rating = float(row.rating) - 0.15
	elif role in ["goalkeeper", "sweeper_keeper"]:
		row.rating = float(row.rating) + float(row.get("saves", 0)) * 0.10

func _role_for(side: String, player_id: String, result: Dictionary, lineups: Dictionary) -> String:
	var tactics: Dictionary = result.get("tactics", {})
	var tactic: Dictionary = tactics.get(side, {})
	var roles: Dictionary = tactic.get("roles", {})
	for key in roles.keys():
		if String(key).begins_with(player_id):
			return String(roles[key])
	if not lineups.is_empty():
		for player in lineups.get(side, []):
			if String(player.get("id", "")) == player_id:
				return String(player.get("role", player.get("match_role", "support")))
	return "support"

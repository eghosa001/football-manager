class_name OppositionReport
extends RefCounted

# Pre-match opposition scouting reports: formation and mentality, key
# threats, defensive weaknesses, set-piece danger, form and a suggested
# game-plan focus. Deterministic from (opponent squad, tactic, form, seed).

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")

func build(world: Dictionary, requester_club_id: String, opponent_club_id: String, seed: int) -> Dictionary:
	var opponent := _club(world.get("clubs", []), opponent_club_id)
	if opponent.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	var squad := _squad(world.get("players", []), opponent_club_id)
	if squad.size() < 11:
		return {"error": ERR_UNAVAILABLE, "reason": "insufficient_data"}
	var tactic: Dictionary = opponent.get("tactic", {"formation": "4-3-3", "mentality": "balanced", "tempo": "standard", "pressing": "standard", "familiarity": 50.0})
	var attack := _unit_rating(squad, ["ST", "AMR", "AML", "AMC"])
	var midfield := _unit_rating(squad, ["DM", "MC", "MR", "ML"])
	var defense := _unit_rating(squad, ["DR", "DC", "DL", "WBR", "WBL", "GK"])
	var form := _recent_form(world, opponent_club_id)
	var threats := _top_threats(squad, 3)
	var weaknesses := _weaknesses(attack, midfield, defense, tactic)
	var plan := _suggested_plan(attack, midfield, defense, tactic, form, seed)
	var report := {
		"requester_club_id": requester_club_id,
		"opponent_club_id": opponent_club_id,
		"opponent_name": String(opponent.get("name", opponent_club_id)),
		"formation": String(tactic.get("formation", "4-3-3")),
		"mentality": String(tactic.get("mentality", "balanced")),
		"pressing": String(tactic.get("pressing", "standard")),
		"attack_rating": snappedf(attack, 0.1),
		"midfield_rating": snappedf(midfield, 0.1),
		"defense_rating": snappedf(defense, 0.1),
		"recent_form": form,
		"key_threats": threats,
		"weaknesses": weaknesses,
		"suggested_plan": plan,
		"set_piece_threat": _set_piece_threat(squad),
	}
	_store(world, report)
	_notify(world, requester_club_id, report)
	return report

func _unit_rating(squad: Array, positions: Array) -> float:
	var total := 0.0
	var count := 0
	for player in squad:
		if String(player.get("position", "")) in positions:
			total += float(player.get("current_ability", 50))
			count += 1
	if count == 0:
		return 45.0
	return total / float(count)

func _top_threats(squad: Array, count: int) -> Array:
	var sorted: Array = squad.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary):
		var score_a := float(a.get("current_ability", 0)) + (5.0 if String(a.get("position", "")) in ["ST", "AMR", "AML", "AMC"] else 0.0)
		var score_b := float(b.get("current_ability", 0)) + (5.0 if String(b.get("position", "")) in ["ST", "AMR", "AML", "AMC"] else 0.0)
		if is_equal_approx(score_a, score_b):
			return String(a.get("id", "")) < String(b.get("id", ""))
		return score_a > score_b
	)
	var threats: Array = []
	for i in range(mini(count, sorted.size())):
		var player: Dictionary = sorted[i]
		threats.append({"player_id": String(player.get("id", "")), "name": _player_name(player), "position": String(player.get("position", "")), "ability": int(player.get("current_ability", 0))})
	return threats

func _weaknesses(attack: float, midfield: float, defense: float, tactic: Dictionary) -> Array:
	var weaknesses: Array = []
	if defense < 58.0:
		weaknesses.append("fragile_back_line")
	if midfield < 58.0:
		weaknesses.append("overrun_in_midfield")
	if String(tactic.get("mentality", "balanced")) == "attacking":
		weaknesses.append("space_in_behind")
	if String(tactic.get("pressing", "standard")) in ["low"]:
		weaknesses.append("time_on_the_ball")
	if float(tactic.get("familiarity", 50.0)) < 45.0:
		weaknesses.append("unsettled_system")
	if weaknesses.is_empty():
		weaknesses.append("few_obvious_weaknesses")
	return weaknesses

func _suggested_plan(attack: float, midfield: float, defense: float, tactic: Dictionary, form: String, seed: int) -> String:
	if defense < 58.0 and attack >= 60.0:
		return "attack_through_flanks"
	if midfield >= 64.0:
		return "control_possession"
	if String(tactic.get("mentality", "")) == "attacking":
		return "counter_attack"
	if form.begins_with("LL"):
		return "press_high_early"
	return "balanced_with_overlap" if int(SeededRngClass.value_for(seed, 55000) % 2) == 0 else "patient_build_up"

func _recent_form(world: Dictionary, club_id: String) -> String:
	var marks := ""
	for fixture in world.get("fixtures", []):
		if not bool(fixture.get("played", false)):
			continue
		var home := String(fixture.get("home_club_id", "")) == club_id
		var away := String(fixture.get("away_club_id", "")) == club_id
		if not home and not away:
			continue
		var gf := int(fixture.get("home_goals", 0)) if home else int(fixture.get("away_goals", 0))
		var ga := int(fixture.get("away_goals", 0)) if home else int(fixture.get("home_goals", 0))
		marks += "W" if gf > ga else ("D" if gf == ga else "L")
	return marks.right(5) if marks.length() >= 5 else marks

func _set_piece_threat(squad: Array) -> String:
	var best_heading := 0
	for player in squad:
		best_heading = maxi(best_heading, int(player.get("attributes", {}).get("heading", int(player.get("current_ability", 50)) / 2)))
	if best_heading >= 70:
		return "severe"
	if best_heading >= 58:
		return "moderate"
	return "limited"

func _store(world: Dictionary, report: Dictionary) -> void:
	world["scouting_reports"] = world.get("scouting_reports", [])
	world.scouting_reports.append(report)

func _notify(world: Dictionary, requester_club_id: String, report: Dictionary) -> void:
	if requester_club_id == String(world.get("human_manager", {}).get("club_id", "")):
		InboxServiceClass.new().add_message(world, "scouting", "Opposition report: %s" % String(report.get("opponent_name", "")), "%s (%s, %s). Threats: %s. Weaknesses: %s. Plan: %s." % [String(report.get("opponent_name", "")), String(report.get("formation", "")), String(report.get("mentality", "")), ", ".join(report.get("key_threats", []).map(func(t: Dictionary): return String(t.get("name", "")))), ", ".join(report.get("weaknesses", [])), String(report.get("suggested_plan", ""))])

func _squad(players: Array, club_id: String) -> Array:
	var result: Array = []
	for player in players:
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			result.append(player)
	return result

func _club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _player_name(player: Dictionary) -> String:
	return String(player.get("name", (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()))

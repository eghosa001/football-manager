class_name TrainingSystem
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const SESSIONS := ["recovery", "technical", "tactical", "physical", "set_pieces", "match_prep", "rest"]
const INDIVIDUAL_FOCUSES := ["none", "technique", "passing", "finishing", "pace", "stamina", "strength", "positioning", "tackling", "crossing"]

func ensure_club(club: Dictionary) -> void:
	club["training_schedule"] = club.get("training_schedule", ["recovery","technical","tactical","physical","set_pieces","match_prep","rest"])
	club["training_intensity"] = float(club.get("training_intensity", 0.65))

func ensure_player(player: Dictionary) -> void:
	player["individual_training_focus"] = String(player.get("individual_training_focus", "none"))
	if String(player.individual_training_focus) not in INDIVIDUAL_FOCUSES:
		player.individual_training_focus = "none"

func set_individual_focus(player: Dictionary, focus: String) -> Error:
	if focus not in INDIVIDUAL_FOCUSES:
		return ERR_INVALID_PARAMETER
	ensure_player(player)
	player.individual_training_focus = focus
	return OK

func run_week(world: Dictionary, club_id: String, seed: int) -> Dictionary:
	var club := _club(world.get("clubs", []), club_id)
	if club.is_empty():
		return {"error":ERR_DOES_NOT_EXIST}
	ensure_club(club)
	var improved := 0
	var focus_improvements := 0
	var fatigue_added := 0
	var injuries := 0
	var coaching := _coaching_quality(world.get("staff", []), club_id)
	var facilities := float(club.get("training_facilities", 50))
	var work_days := 0
	var recovery_days := 0
	for session in club.training_schedule:
		if session in ["rest", "recovery"]: recovery_days += 1
		else: work_days += 1
	for player in world.get("players", []):
		if String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
			continue
		ensure_player(player)
		if int(player.get("injured_days", 0)) > 0: continue
		var intensity := float(club.training_intensity)
		var professionalism := float(player.get("hidden_attributes", {}).get("professionalism", 50))
		var potential_gap := maxi(0, int(player.get("potential", 50)) - int(player.get("current_ability", 50)))
		var age := int(player.get("age", 25))
		var age_factor := 1.0 if age <= 21 else (0.75 if age <= 25 else (0.35 if age <= 29 else 0.12))
		var development_score := potential_gap * 0.02 * age_factor * (0.6 + coaching / 125.0) * (0.7 + facilities / 170.0) * (0.7 + professionalism / 170.0) * intensity
		var gain := clampi(int(floor(development_score * float(work_days) / 5.0 / 3.0)), 0, 2)
		if gain > 0:
			player.current_ability = mini(int(player.get("potential", 100)), int(player.get("current_ability", 50)) + gain)
			improved += 1
		if _apply_individual_focus(player, coaching, facilities, intensity, work_days, seed):
			focus_improvements += 1
		var fatigue := maxi(0, int(round(intensity * float(work_days) * 2.0)) - recovery_days)
		if work_days == 0: player.fitness = mini(100, int(player.get("fitness", 100)) + recovery_days * 2)
		player.fitness = clampi(int(player.get("fitness", 100)) - fatigue, 45, 100)
		fatigue_added += fatigue
		var injury_proneness := int(player.get("hidden_attributes", {}).get("injury_proneness", 50))
		var injury_risk := clampf(0.004 + intensity * 0.012 + injury_proneness / 10000.0 - facilities / 20000.0, 0.002, 0.04)
		var key := _stable_key(String(player.get("id", "")))
		if work_days > 0 and SeededRngClass.unit_for(seed, key) < injury_risk * float(work_days) / 5.0:
			player.injured_days = maxi(int(player.get("injured_days", 0)), 5 + int(SeededRngClass.value_for(seed, key + 7) % 24))
			injuries += 1
	return {"players_improved":improved,"focus_improvements":focus_improvements,"fatigue_added":fatigue_added,"training_injuries":injuries,"coaching_quality":coaching}

func set_schedule(club: Dictionary, sessions: Array, intensity: float) -> Error:
	if sessions.size() != 7:
		return ERR_INVALID_PARAMETER
	if not is_finite(intensity): return ERR_INVALID_PARAMETER
	for session in sessions:
		if session not in SESSIONS: return ERR_INVALID_PARAMETER
	club["training_schedule"] = sessions.duplicate()
	club["training_intensity"] = clampf(intensity, 0.15, 1.0)
	return OK

func _apply_individual_focus(player: Dictionary, coaching: float, facilities: float, intensity: float, work_days: int, seed: int) -> bool:
	var focus := String(player.get("individual_training_focus", "none"))
	if focus == "none" or work_days <= 0:
		return false
	var attributes: Dictionary = player.get("attributes", {})
	if attributes.is_empty():
		return false
	var target := focus
	if focus == "positioning" and not attributes.has(target):
		target = "off_the_ball" if String(player.get("position", "")) in ["ST","AMC","AMR","AML"] else "marking"
	if not attributes.has(target):
		attributes[target] = int(player.get("current_ability", 50))
	var age := int(player.get("age", 25))
	var age_factor := 1.0 if age <= 22 else (0.7 if age <= 27 else 0.35)
	var professionalism := float(player.get("hidden_attributes", {}).get("professionalism", 50))
	var chance := clampf(0.06 + coaching / 700.0 + facilities / 900.0 + professionalism / 1200.0, 0.08, 0.42)
	chance *= age_factor * intensity * float(work_days) / 5.0
	var key := _stable_key(String(player.get("id", "")) + ":" + focus)
	if SeededRngClass.unit_for(seed, key + 5000) >= chance:
		return false
	attributes[target] = clampi(int(attributes.get(target, 50)) + 1, 1, 100)
	player["attributes"] = attributes
	return true

func _coaching_quality(staff: Array, club_id: String) -> float:
	var total := 0.0
	var count := 0
	for member in staff:
		if String(member.get("club_id", "")) == club_id and String(member.get("role", "")) in ["coach","assistant_manager","manager"]:
			total += float(member.get("ability", 50))
			count += 1
	return total / maxf(float(count), 1.0)

func _club(clubs: Array, id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == id: return club
	return {}

func _stable_key(text: String) -> int:
	var value := 47
	for character in text.to_utf8_buffer():
		value = posmod(value * 151 + int(character), 2_147_483_647)
	return value

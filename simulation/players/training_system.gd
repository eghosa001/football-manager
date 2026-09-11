class_name TrainingSystem
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const SESSIONS := ["recovery", "technical", "tactical", "physical", "set_pieces", "match_prep", "rest"]

func ensure_club(club: Dictionary) -> void:
	club["training_schedule"] = club.get("training_schedule", ["recovery","technical","tactical","physical","set_pieces","match_prep","rest"])
	club["training_intensity"] = float(club.get("training_intensity", 0.65))

func run_week(world: Dictionary, club_id: String, seed: int) -> Dictionary:
	var club := _club(world.get("clubs", []), club_id)
	if club.is_empty():
		return {"error":ERR_DOES_NOT_EXIST}
	ensure_club(club)
	var improved := 0
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
	return {"players_improved":improved,"fatigue_added":fatigue_added,"training_injuries":injuries,"coaching_quality":coaching}

func set_schedule(club: Dictionary, sessions: Array, intensity: float) -> Error:
	if sessions.size() != 7:
		return ERR_INVALID_PARAMETER
	if not is_finite(intensity): return ERR_INVALID_PARAMETER
	for session in sessions:
		if session not in SESSIONS: return ERR_INVALID_PARAMETER
	club["training_schedule"] = sessions.duplicate()
	club["training_intensity"] = clampf(intensity, 0.15, 1.0)
	return OK

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

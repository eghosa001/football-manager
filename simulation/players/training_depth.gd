class_name TrainingDepth
extends RefCounted

const SeededRng = preload("res://core/rng/seeded_rng.gd")

# Richer training control: individual focus, position/role training,
# mentoring, rest/recovery, match prep, injury-risk feedback, familiarity.

const FOCUS_AREAS := ["finishing", "passing", "dribbling", "tackling", "pace", "strength", "vision", "goalkeeping"]
const POSITIONS := ["GK","DL","DC","DR","WBL","WBR","DM","ML","MC","MR","AML","AMC","AMR","ST"]
const TRAITS := ["cuts_inside","stays_wide","tries_long_shots","likes_to_round_keeper","plays_one_twos","dictates_tempo","switches_ball","dives_into_tackles","avoids_weak_foot","runs_with_ball","arrives_late_box","drops_deep","beats_offside_trap"]

func ensure_player(player: Dictionary) -> void:
	player["training_focus"] = String(player.get("training_focus", "passing"))
	player["training_focus_intensity"] = clampf(float(player.get("training_focus_intensity", 0.65)), 0.0, 1.0)
	player["role_training"] = String(player.get("role_training", ""))
	player["position_training"] = String(player.get("position_training", ""))
	player["trait_training"] = String(player.get("trait_training", ""))
	player["role_familiarity"] = player.get("role_familiarity", {})
	player["position_familiarity"] = player.get("position_familiarity", {})
	player["trait_training_progress"] = player.get("trait_training_progress", {})
	player["traits"] = player.get("traits", [])

func set_individual_focus(player: Dictionary, focus: String, intensity: float) -> Error:
	ensure_player(player)
	if focus not in FOCUS_AREAS:
		return ERR_INVALID_PARAMETER
	player["training_focus"] = focus
	player["training_focus_intensity"] = clampf(intensity, 0.0, 1.0)
	return OK

func set_role_training(player: Dictionary, role: String) -> Error:
	ensure_player(player)
	if role.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	player["role_training"] = role.strip_edges()
	return OK

func set_position_training(player: Dictionary, position: String) -> Error:
	ensure_player(player)
	if position not in POSITIONS:
		return ERR_INVALID_PARAMETER
	player["position_training"] = position
	return OK

func set_trait_development(player: Dictionary, trait_name: String) -> Error:
	ensure_player(player)
	if trait_name not in TRAITS:
		return ERR_INVALID_PARAMETER
	if trait_name in player.traits:
		return ERR_ALREADY_EXISTS
	player["trait_training"] = trait_name
	return OK

func train_role(player: Dictionary, role: String, sessions: int) -> Dictionary:
	ensure_player(player)
	var familiarity: Dictionary = player.get("role_familiarity", {})
	familiarity[role] = clampf(float(familiarity.get(role, 20.0)) + float(sessions) * 2.0, 0.0, 100.0)
	player["role_familiarity"] = familiarity
	return player

func apply_week(player: Dictionary, sessions: int, coaching_quality: float, facilities: float, seed: int) -> Dictionary:
	ensure_player(player)
	var effective_sessions := maxi(0, sessions)
	var professionalism := float(player.get("hidden_attributes", {}).get("professionalism", 50))
	var training_factor := (0.55 + coaching_quality / 180.0) * (0.65 + facilities / 200.0) * (0.65 + professionalism / 190.0) * float(player.training_focus_intensity)
	var focus_gain := 0
	var focus := String(player.get("training_focus", ""))
	var attributes: Dictionary = player.get("attributes", {})
	if effective_sessions > 0 and focus in FOCUS_AREAS and attributes.has(focus):
		var chance := clampf(float(effective_sessions) * training_factor / 11.0, 0.0, 0.85)
		if SeededRng.unit_for(seed, _stable_key(String(player.get("id", ""))) + 101) < chance:
			attributes[focus] = clampi(int(attributes[focus]) + 1, 1, 100)
			focus_gain = 1
	player["attributes"] = attributes

	var role_gain := 0.0
	var role := String(player.get("role_training", ""))
	if role != "" and effective_sessions > 0:
		var before := float(player.role_familiarity.get(role, 20.0))
		var after := clampf(before + float(effective_sessions) * (0.55 + training_factor * 0.45), 0.0, 100.0)
		player.role_familiarity[role] = after
		role_gain = after - before

	var position_gain := 0.0
	var position := String(player.get("position_training", ""))
	if position in POSITIONS and effective_sessions > 0:
		var before_pos := float(player.position_familiarity.get(position, 20.0 if position != String(player.get("position", "")) else 100.0))
		var after_pos := clampf(before_pos + float(effective_sessions) * (0.40 + training_factor * 0.35), 0.0, 100.0)
		player.position_familiarity[position] = after_pos
		position_gain = after_pos - before_pos

	var learned_trait := ""
	var trait_name := String(player.get("trait_training", ""))
	if trait_name in TRAITS and trait_name not in player.traits and effective_sessions > 0:
		var progress := float(player.trait_training_progress.get(trait_name, 0.0))
		progress += float(effective_sessions) * (2.0 + training_factor * 2.5)
		player.trait_training_progress[trait_name] = clampf(progress, 0.0, 100.0)
		if progress >= 100.0:
			player.traits.append(trait_name)
			player.trait_training_progress.erase(trait_name)
			player.trait_training = ""
			learned_trait = trait_name
	return {"focus_gain":focus_gain,"role_gain":role_gain,"position_gain":position_gain,"learned_trait":learned_trait}

func mentor(mentor_player: Dictionary, youth: Dictionary, sessions: int) -> Dictionary:
	var professionalism := float(mentor_player.get("hidden_attributes", {}).get("professionalism", 50))
	var gain := clampf(float(sessions) * (0.4 + professionalism / 200.0), 0.0, 6.0)
	youth["mentoring_gain"] = float(youth.get("mentoring_gain", 0.0)) + gain
	return youth

func injury_risk_feedback(player: Dictionary, workload: float) -> Dictionary:
	var proneness := float(player.get("hidden_attributes", {}).get("injury_proneness", 50))
	var fitness := float(player.get("fitness", 90))
	var risk := clampf(0.004 + workload * 0.02 + proneness / 12000.0 + (100.0 - fitness) / 4000.0, 0.002, 0.08)
	var band := "low" if risk < 0.015 else ("moderate" if risk < 0.035 else "high")
	return {"risk": risk, "band": band, "recommend_rest": band == "high"}

func _stable_key(text: String) -> int:
	var value := 113
	for character in text.to_utf8_buffer():
		value = posmod(value * 197 + int(character), 2_147_483_647)
	return value

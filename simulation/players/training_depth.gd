class_name TrainingDepth
extends RefCounted

# Richer training control: individual focus, position/role training,
# mentoring, rest/recovery, match prep, injury-risk feedback, familiarity.

const FOCUS_AREAS := ["finishing", "passing", "dribbling", "tackling", "pace", "strength", "vision", "goalkeeping"]

func set_individual_focus(player: Dictionary, focus: String, intensity: float) -> Error:
	if focus not in FOCUS_AREAS:
		return ERR_INVALID_PARAMETER
	player["training_focus"] = focus
	player["training_focus_intensity"] = clampf(intensity, 0.0, 1.0)
	return OK

func train_role(player: Dictionary, role: String, sessions: int) -> Dictionary:
	var familiarity: Dictionary = player.get("role_familiarity", {})
	familiarity[role] = clampf(float(familiarity.get(role, 20.0)) + float(sessions) * 2.0, 0.0, 100.0)
	player["role_familiarity"] = familiarity
	return player

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

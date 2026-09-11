class_name RecruitmentWorkflow
extends RefCounted

# Career-level scouting: assignments, workload, region knowledge,
# duration, progressive uncertainty, shortlists, comparisons.

func create_assignment(scout_id: String, region: String, weeks: int, focus: String = "balanced") -> Dictionary:
	return {
		"id": "assign-%s-%s" % [scout_id, region],
		"scout_id": scout_id,
		"region": region,
		"weeks_left": maxi(1, weeks),
		"weeks_total": maxi(1, weeks),
		"focus": focus,
		"knowledge": 0.0,
		"reports": [],
	}

func progress_assignment(assignment: Dictionary, scout_ability: float) -> Dictionary:
	assignment["weeks_left"] = maxi(0, int(assignment.get("weeks_left", 1)) - 1)
	var gain := clampf(float(scout_ability) / 130.0, 0.15, 0.85)
	assignment["knowledge"] = clampf(float(assignment.get("knowledge", 0.0)) + gain / float(maxi(1, int(assignment.get("weeks_total", 1)))), 0.0, 1.0)
	return assignment

func revealed_ability(true_ability: float, knowledge: float, seed: int, player_id: String) -> Dictionary:
	var uncertainty := (1.0 - clampf(knowledge, 0.0, 1.0)) * 22.0
	var noise := (float(abs(hash(player_id + str(seed))) % 1000) / 1000.0 - 0.5) * 2.0 * uncertainty
	return {"estimate": clampf(true_ability + noise, 1.0, 100.0), "uncertainty": uncertainty, "confidence": clampf(knowledge, 0.0, 1.0)}

func shortlist_add(shortlist: Array, player_id: String, note: String = "") -> Array:
	for entry in shortlist:
		if String(entry.get("player_id", "")) == player_id:
			return shortlist
	shortlist.append({"player_id": player_id, "note": note})
	return shortlist

func compare(a_estimate: Dictionary, b_estimate: Dictionary) -> Dictionary:
	return {
		"delta": float(a_estimate.get("estimate", 50.0)) - float(b_estimate.get("estimate", 50.0)),
		"confidence": minf(float(a_estimate.get("confidence", 0.0)), float(b_estimate.get("confidence", 0.0))),
	}

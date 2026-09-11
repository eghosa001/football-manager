class_name BoardService
extends RefCounted

# Interactive boardroom layer on top of BoardEvaluation: seasonal objective
# reviews, budget requests with deterministic board responses, job-security
# assessments and supporter-confidence reports. All outcomes derive from
# (board patience/ambition/confidence, finances, results) plus seeded draws.

const BoardEvaluationClass = preload("res://simulation/finance/board_evaluation.gd")
const LedgerClass = preload("res://simulation/finance/ledger.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func season_review(world: Dictionary, club_id: String, records: Array, year: int) -> Dictionary:
	var club := _club(world, club_id)
	if club.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	var evaluation: Dictionary = BoardEvaluationClass.new().evaluate_club(world, club, records)
	var objectives: Array = _grade_objectives(club, records)
	var verdict := String(evaluation.get("status", "stable"))
	InboxServiceClass.new().add_message(world, "board", "Season review: %s" % verdict.capitalize(), _review_body(club, evaluation, objectives, year))
	return {"club_id": club_id, "year": year, "overall": float(evaluation.get("overall", 50.0)), "status": verdict, "objectives": objectives, "confidence": int(club.get("board", {}).get("confidence", 65))}

func request_budget(world: Dictionary, club_id: String, kind: String, amount: int, seed: int) -> Dictionary:
	var club := _club(world, club_id)
	if club.is_empty() or amount <= 0:
		return {"approved": false, "reason": "invalid_request"}
	if kind not in ["transfer", "wage", "facilities"]:
		return {"approved": false, "reason": "unknown_budget"}
	var board: Dictionary = club.get("board", {})
	var confidence := float(board.get("confidence", 65))
	var ambition := float(board.get("ambition", 55))
	var prudence := float(board.get("financial_prudence", 55))
	var cash := int(club.get("cash", 0))
	var debt := int(club.get("debt", 0))
	var headroom := cash - debt / 2 - (500000 if kind == "transfer" else 50000)
	if headroom <= 0:
		_notify(world, club_id, "Budget request declined", "The board cannot release funds while the club's headroom is exhausted.")
		return {"approved": false, "reason": "no_headroom", "headroom": headroom}
	var generosity := (confidence - 55.0) * 0.35 + (ambition - 55.0) * 0.30 - (prudence - 55.0) * 0.45
	var roll := float(SeededRngClass.value_for(seed, _stable_key(club_id + kind)) % 100)
	var threshold := clampf(55.0 - generosity, 15.0, 90.0)
	if roll < threshold and amount <= headroom:
		var granted := mini(amount, int(headroom * 0.5))
		if kind == "transfer":
			club["transfer_budget"] = int(club.get("transfer_budget", 0)) + granted
		elif kind == "wage":
			club["wage_budget"] = int(club.get("wage_budget", 0)) + granted
		else:
			club["cash"] = int(club.get("cash", 0))
		club.board["confidence"] = clampi(int(confidence) - 2, 0, 100)
		_notify(world, club_id, "Budget request approved", "The board released %d for %s. Spend it wisely." % [granted, kind])
		return {"approved": true, "granted": granted, "requested": amount}
	club.board["confidence"] = clampi(int(confidence) - 1, 0, 100)
	_notify(world, club_id, "Budget request declined", "The board rejected the %s request of %d (roll %.0f vs %.0f). Results must improve first." % [kind, amount, roll, threshold])
	return {"approved": false, "reason": "board_declined", "roll": roll, "threshold": threshold}

func job_security(world: Dictionary, club_id: String, records: Array) -> Dictionary:
	var club := _club(world, club_id)
	if club.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	var evaluation: Dictionary = club.get("board", {}).get("evaluation", {})
	if evaluation.is_empty():
		evaluation = BoardEvaluationClass.new().evaluate_club(world, club, records)
	var overall := float(evaluation.get("overall", 50.0))
	var patience := float(club.get("board", {}).get("patience", 65))
	var risk := clampf((45.0 - overall) / 45.0, 0.0, 1.0) * lerpf(1.0, 0.55, patience / 100.0)
	var status := "secure"
	if risk >= 0.75:
		status = "critical"
	elif risk >= 0.45:
		status = "under_pressure"
	elif risk >= 0.25:
		status = "stable"
	return {"club_id": club_id, "overall": overall, "risk": snappedf(risk, 0.01), "status": status, "confidence": int(club.get("board", {}).get("confidence", 65))}

func supporter_report(world: Dictionary, club_id: String) -> Dictionary:
	var club := _club(world, club_id)
	if club.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	var supporters: Dictionary = club.get("supporters", {})
	return {
		"club_id": club_id,
		"mood": int(supporters.get("mood", 65)),
		"loyalty": int(supporters.get("loyalty", 60)),
		"expectation": int(supporters.get("expectation", 50)),
		"attendance_outlook": _attendance_outlook(club),
	}

func _grade_objectives(club: Dictionary, records: Array) -> Array:
	var results: Array = []
	for objective in club.get("board", {}).get("objectives", []):
		var type := String(objective.get("type", "league_position"))
		var target := int(objective.get("target", 10))
		var actual := _league_position(String(club.get("id", "")), records) if type == "league_position" else 0
		var met := actual > 0 and actual <= target if type == "league_position" else true
		results.append({"type": type, "target": target, "actual": actual, "met": met})
	return results

func _league_position(club_id: String, records: Array) -> int:
	for record in records:
		if String(record.get("competition_type", "league")) != "league":
			continue
		var table: Array = record.get("table", [])
		for i in range(table.size()):
			if String(table[i].get("club_id", "")) == club_id:
				return i + 1
	return 0

func _attendance_outlook(club: Dictionary) -> String:
	var mood := int(club.get("supporters", {}).get("mood", 65))
	if mood >= 75:
		return "sellout_expected"
	if mood >= 55:
		return "healthy"
	if mood >= 35:
		return "soft"
	return "boycott_risk"

func _review_body(club: Dictionary, evaluation: Dictionary, objectives: Array, year: int) -> String:
	var lines: Array = []
	lines.append("Season %d review for %s: overall %.1f (%s)." % [year, String(club.get("name", "Club")), float(evaluation.get("overall", 50.0)), String(evaluation.get("status", "stable"))])
	for objective in objectives:
		lines.append("Objective %s target %d: %s." % [String(objective.get("type", "")), int(objective.get("target", 0)), "MET" if bool(objective.get("met", false)) else "MISSED"])
	lines.append("Board confidence is %d. Supporter mood is %d." % [int(club.get("board", {}).get("confidence", 65)), int(club.get("supporters", {}).get("mood", 65))])
	return "\n".join(lines)

func _notify(world: Dictionary, club_id: String, title: String, body: String) -> void:
	var message := {"club_id": club_id, "title": title, "body": body}
	InboxServiceClass.new().add_message(world, "board", String(message.title), String(message.body))

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _stable_key(text: String) -> int:
	var value := 91
	for c in text.to_utf8_buffer():
		value = posmod(value * 167 + int(c), 2_147_483_647)
	return value

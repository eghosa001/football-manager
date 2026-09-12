class_name PressService
extends RefCounted

# Pre-match and post-match press conferences. Journalists ask deterministic
# question decks; the manager's answer tone (confident / respectful / fiery /
# evasive) moves squad morale, pressure handling, board confidence and the
# manager's media reputation. Manual-only via career commands.

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")

const ANSWER_TONES := ["confident", "respectful", "fiery", "evasive"]
const PRE_MATCH_QUESTIONS := ["title_race", "opponent_threat", "team_news", "transfer_rumours", "fan_expectations"]
const POST_MATCH_QUESTIONS := ["result_verdict", "key_performer", "controversial_call", "injury_update", "next_match"]

func hold_press_conference(world: Dictionary, club_id: String, kind: String, answers: Dictionary = {}, seed: int = 1) -> Dictionary:
	if kind != "pre_match" and kind != "post_match":
		return {"error": ERR_INVALID_PARAMETER}
	var club: Dictionary = _club(world.get("clubs", []), club_id)
	if club.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	_ensure_journalists(world, seed)
	var questions: Array = PRE_MATCH_QUESTIONS.duplicate() if kind == "pre_match" else POST_MATCH_QUESTIONS.duplicate()
	var context := _press_context(world, club_id, kind)
	var outcomes: Array = []
	var morale_shift := 0
	var pressure_shift := 0
	for i in range(questions.size()):
		var question := String(questions[i])
		var journalist := _journalist_for(world, seed + i * 701)
		var tone := String(answers.get(question, "respectful"))
		if tone not in ANSWER_TONES:
			tone = "respectful"
		var outcome := _answer_outcome(world, club, question, tone, context, journalist, seed + i * 101)
		outcomes.append(outcome)
		morale_shift += int(outcome.get("morale_shift", 0))
		pressure_shift += int(outcome.get("pressure_shift", 0))
	_update_journalist_relationships(world, club_id, outcomes)
	_apply_squad_effects(world, club_id, morale_shift, pressure_shift)
	_apply_board_effect(world, club, outcomes, seed)
	_inbox(world, club, kind, outcomes)
	return {"club_id": club_id, "kind": kind, "questions": outcomes, "morale_shift": morale_shift, "pressure_shift": pressure_shift}

func journalists(world: Dictionary) -> Array:
	return world.get("journalists", [])

func _ensure_journalists(world: Dictionary, seed: int) -> void:
	if world.has("journalists") and (world.journalists as Array).size() >= 6:
		return
	var first := ["Maya", "Tomas", "Aisha", "Rui", "Chidi", "Lena", "Marco", "Sofia"]
	var last := ["Okoro", "Silva", "Bianchi", "Costa", "Adeyemi", "Lund", "Rossi", "Pereira"]
	var outlets := ["Daily Ledger", "Football Herald", "Continental Post", "Matchday FM", "The Touchline", "Goal Gazette"]
	var clubs: Array = world.get("clubs", [])
	world["journalists"] = []
	for i in range(6):
		var club_pref := ""
		if not clubs.is_empty():
			club_pref = String(clubs[int(SeededRngClass.value_for(seed, 500 + i * 37) % clubs.size())].get("id", ""))
		world.journalists.append({
			"id": "journalist-%d" % (i + 1),
			"name": "%s %s" % [first[i % first.size()], last[int(SeededRngClass.value_for(seed, 600 + i * 53) % last.size())]],
			"outlet": outlets[i % outlets.size()],
			"reputation": 40 + int(SeededRngClass.value_for(seed, 700 + i * 29) % 51),
			"sensationalism": 20 + int(SeededRngClass.value_for(seed, 800 + i * 41) % 71),
			"club_preference": club_pref,
			"manager_relationships": {},
		})

func _journalist_for(world: Dictionary, seed: int) -> Dictionary:
	var reporters: Array = world.get("journalists", [])
	if reporters.is_empty():
		return {"id": "wire", "name": "Press Association", "outlet": "Wire", "reputation": 50, "sensationalism": 40, "club_preference": "", "manager_relationships": {}}
	return reporters[int(SeededRngClass.value_for(seed, 900) % reporters.size())]

func _update_journalist_relationships(world: Dictionary, club_id: String, outcomes: Array) -> void:
	for outcome in outcomes:
		var journalist_id := String(outcome.get("journalist_id", ""))
		for reporter in world.get("journalists", []):
			if String(reporter.get("id", "")) != journalist_id:
				continue
			var rels: Dictionary = reporter.get("manager_relationships", {})
			var delta := int(outcome.get("morale_shift", 0))
			rels[club_id] = clampi(int(rels.get(club_id, 50)) + delta * 2, 0, 100)
			reporter["manager_relationships"] = rels

func _answer_outcome(world: Dictionary, club: Dictionary, question: String, tone: String, context: Dictionary, journalist: Dictionary, seed: int) -> Dictionary:
	var roll := int(SeededRngClass.value_for(seed, _stable_key(String(club.get("id", "")) + question + tone)) % 100)
	var sensational := float(journalist.get("sensationalism", 40)) / 100.0
	var favoured := String(journalist.get("club_preference", "")) == String(club.get("id", ""))
	var morale_shift := 0
	var pressure_shift := 0
	var headline := ""
	match tone:
		"confident":
			morale_shift = 1 if roll < 75 else -1
			pressure_shift = 1 if bool(context.get("favourites", false)) else 0
			headline = "Manager guarantees %s" % String(club.get("name", "victory"))
		"respectful":
			morale_shift = 1
			pressure_shift = -1
			headline = "Manager keeps feet on the ground"
		"fiery":
			if roll < 55:
				morale_shift = 2
				pressure_shift = 1
				headline = "Mind games! Manager fires warning"
			else:
				morale_shift = -2
				pressure_shift = 2
				headline = "Outburst backfires in press room"
		"evasive":
			morale_shift = 0
			pressure_shift = 1
			headline = "Manager bats away %s question" % String(question).replace("_", " ")
	if sensational > 0.62 and morale_shift <= 0:
		headline = "PRESSURE MOUNTS: " + headline
		pressure_shift += 1
	if favoured:
		morale_shift += 1
	return {"question": question, "tone": tone, "headline": headline, "morale_shift": morale_shift, "pressure_shift": pressure_shift, "journalist_id": String(journalist.get("id", "wire")), "journalist": String(journalist.get("name", "Wire")), "outlet": String(journalist.get("outlet", "Wire"))}

func _press_context(world: Dictionary, club_id: String, kind: String) -> Dictionary:
	var club: Dictionary = _club(world.get("clubs", []), club_id)
	var next := _next_opponent(world, club_id)
	var favourites := false
	if not next.is_empty():
		favourites = int(club.get("reputation", 50)) >= int(next.get("reputation", 50))
	return {"kind": kind, "favourites": favourites, "opponent": String(next.get("name", "opponents"))}

func _apply_squad_effects(world: Dictionary, club_id: String, morale_shift: int, pressure_shift: int) -> void:
	for player in world.get("players", []):
		if String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
			continue
		player["morale"] = clampi(int(player.get("morale", 60)) + morale_shift, 1, 100)
		var hidden: Dictionary = player.get("hidden_attributes", {})
		hidden["pressure"] = clampi(int(hidden.get("pressure", 50)) + pressure_shift, 1, 99)

func _apply_board_effect(world: Dictionary, club: Dictionary, outcomes: Array, seed: int) -> void:
	var backfires := 0
	for outcome in outcomes:
		if int(outcome.get("morale_shift", 0)) < 0:
			backfires += 1
	if backfires >= 3:
		club.board["confidence"] = clampi(int(club.get("board", {}).get("confidence", 65)) - 2, 0, 100)

func _next_opponent(world: Dictionary, club_id: String) -> Dictionary:
	var today := String(world.get("date", "2026-07-01"))
	var best_date := ""
	var opponent_id := ""
	for fixture in world.get("fixtures", []):
		if bool(fixture.get("played", false)):
			continue
		var home := String(fixture.get("home_club_id", "")) == club_id
		var away := String(fixture.get("away_club_id", "")) == club_id
		if not home and not away:
			continue
		var date := String(fixture.get("date", ""))
		if date >= today and (best_date == "" or date < best_date):
			best_date = date
			opponent_id = String(fixture.get("away_club_id", "")) if home else String(fixture.get("home_club_id", ""))
	return _club(world.get("clubs", []), opponent_id)

func _inbox(world: Dictionary, club: Dictionary, kind: String, outcomes: Array) -> void:
	var lines: Array = []
	for outcome in outcomes:
		lines.append("%s: %s." % [String(outcome.get("question", "")).replace("_", " ").capitalize(), String(outcome.get("headline", ""))])
	InboxServiceClass.new().add_message(world, "media", "%s press conference" % String(kind).replace("_", " ").capitalize(), "\n".join(lines))

func _club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _stable_key(text: String) -> int:
	var value := 167
	for character in text.to_utf8_buffer():
		value = posmod(value * 179 + int(character), 2_147_483_647)
	return value

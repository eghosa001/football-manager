extends SceneTree

# Manager-depth gate: team talks, touchline shouts, press conferences,
# loan buy-option settlement and opposition reports. All deterministic.

func _init() -> void:
	_test_team_talks()
	_test_press()
	_test_loan_settlement()
	_test_opposition_reports()
	print("[TEST] MANAGER DEPTH PASS")
	quit(0)

func _test_team_talks() -> void:
	var session = preload("res://application/career/career_session.gd").new()
	session.new_career("Talk Test", "eng-t1-c01", 7070, 1, [], false)
	var w: Dictionary = session.world
	var command = preload("res://application/career/career_command_service.gd").new()
	var result: Dictionary = command.deliver_team_talk(w, session.managed_club_id, "passionate", "pre_match", {}, 11)
	assert(not result.has("error"))
	assert(int(result.get("players_addressed", 0)) >= 15)
	assert(result.get("reactions", []).size() == int(result.get("players_addressed", 0)))
	# Deterministic twin: identical morale deltas.
	var session_b = preload("res://application/career/career_session.gd").new()
	session_b.new_career("Talk Test", "eng-t1-c01", 7070, 1, [], false)
	var twin: Dictionary = command.deliver_team_talk(session_b.world, session_b.managed_club_id, "passionate", "pre_match", {}, 11)
	assert(str(result.get("reactions", [])) == str(twin.get("reactions", [])))
	# Invalid tone rejected, morale stays bounded.
	var bad: Dictionary = command.deliver_team_talk(w, session.managed_club_id, "spicy", "pre_match", {}, 11)
	assert(bad.has("error"))
	var shout: Dictionary = command.touchline_shout(w, session.managed_club_id, "encourage", {"minute": 80, "goal_difference": -1}, 13)
	assert(not shout.has("error"))
	assert(shout.get("effects", []).size() >= 15)
	for player in w.get("players", []):
		if String(player.get("club_id", "")) == session.managed_club_id:
			assert(int(player.get("morale", 0)) >= 1 and int(player.get("morale", 0)) <= 100)
			assert(int(player.get("motivation", 60)) >= 1 and int(player.get("motivation", 60)) <= 100)

func _test_press() -> void:
	var session = preload("res://application/career/career_session.gd").new()
	session.new_career("Press Test", "eng-t1-c01", 8080, 1, [], false)
	var command = preload("res://application/career/career_command_service.gd").new()
	var result: Dictionary = command.hold_press_conference(session.world, session.managed_club_id, "pre_match", {"title_race": "confident", "opponent_threat": "respectful"}, 21)
	assert(not result.has("error"))
	assert(result.get("questions", []).size() == 5)
	var session_b = preload("res://application/career/career_session.gd").new()
	session_b.new_career("Press Test", "eng-t1-c01", 8080, 1, [], false)
	var twin: Dictionary = command.hold_press_conference(session_b.world, session_b.managed_club_id, "pre_match", {"title_race": "confident", "opponent_threat": "respectful"}, 21)
	assert(str(result.get("questions", [])) == str(twin.get("questions", [])))
	var bad: Dictionary = command.hold_press_conference(session.world, session.managed_club_id, "half_time", {}, 21)
	assert(bad.has("error"))

func _test_loan_settlement() -> void:
	var world: Dictionary = preload("res://data/launch_world_builder.gd").new().build(9090, 1)
	var market = preload("res://simulation/transfers/transfer_market.gd").new()
	var borrower := _club(world, "eng-t1-c01")
	var seller := _club(world, "eng-t1-c02")
	borrower["transfer_budget"] = 30000000
	borrower["wage_budget"] = 900000
	borrower["cash"] = 40000000
	var loanee := _outfield_player(world, "eng-t1-c02")
	var cash_before: int = _league_cash(world)
	assert(market.execute_loan(world, String(loanee.get("id", "")), "eng-t1-c01", 100000, 2026, {"buy_option": 500000, "buy_obligation": true}) == OK)
	assert(int(loanee.get("loan_buy_option", 0)) == 500000)
	assert(bool(loanee.get("loan_buy_obligation", false)))
	# Simulate a full loan season of appearances.
	loanee["career_appearances"] = int(loanee.get("career_appearances", 0)) + 30
	var settled: Dictionary = market.settle_loan_terms(world, 2027, 31)
	assert(settled.get("bought", []).size() == 1)
	assert(String(loanee.get("club_id", "")) == "eng-t1-c01")
	assert(not loanee.has("loan_parent_club_id"))
	assert(_league_cash(world) == cash_before)
	# Optional clause lapses without appearances.
	var loanee_b := _outfield_player(world, "eng-t1-c02")
	assert(market.execute_loan(world, String(loanee_b.get("id", "")), "eng-t1-c01", 50000, 2027, {"buy_option": 9000000}) == OK)
	var settled_b: Dictionary = market.settle_loan_terms(world, 2028, 33)
	assert(settled_b.get("bought", []).is_empty())
	assert(market.return_expired_loans(world, 2028) >= 1)
	assert(String(loanee_b.get("club_id", "")) == "eng-t1-c02")

func _test_opposition_reports() -> void:
	var session = preload("res://application/career/career_session.gd").new()
	session.new_career("Scout Test", "eng-t1-c01", 9091, 1, [], false)
	var command = preload("res://application/career/career_command_service.gd").new()
	var report: Dictionary = command.request_opposition_report(session.world, session.managed_club_id, "eng-t1-c02", 51)
	assert(not report.has("error"))
	assert(String(report.get("formation", "")) != "")
	assert(report.get("key_threats", []).size() == 3)
	assert(not report.get("weaknesses", []).is_empty())
	assert(String(report.get("suggested_plan", "")) != "")
	var twin: Dictionary = command.request_opposition_report(session.world, session.managed_club_id, "eng-t1-c02", 51)
	assert(str(report) == str(twin))
	var missing: Dictionary = command.request_opposition_report(session.world, session.managed_club_id, "nope-fc", 51)
	assert(missing.has("error"))

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _outfield_player(world: Dictionary, club_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and String(player.get("position", "")) == "ST" and not bool(player.get("retired", false)):
			return player
	return {}

func _league_cash(world: Dictionary) -> int:
	var total := 0
	for club in world.get("clubs", []):
		total += int(club.get("cash", 0))
	return total

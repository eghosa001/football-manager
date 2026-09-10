extends SceneTree

const CareerSessionClass = preload("res://application/career/career_session.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const CommandClass = preload("res://application/career/career_command_service.gd")
const InboxClass = preload("res://application/career/inbox_service.gd")
const RegistrationClass = preload("res://simulation/competitions/registration_service.gd")
const YouthAcademyClass = preload("res://simulation/players/youth_academy.gd")

func _init() -> void:
	var session = CareerSessionClass.new()
	var snap: Dictionary = session.new_career("RC2 Manager", "", 919191)
	assert(not session.world.is_empty())
	assert(String(snap.club_id) != "")
	assert(int(snap.database_schema) == 1)
	assert(session.world.get("countries", []).size() == 8)
	assert(session.world.get("competitions", []).size() > 8)
	assert(session.world.get("registrations", {}).size() > 0)
	var command = CommandClass.new()
	var club_id := String(session.managed_club_id)

	assert(command.set_tactic(session.world, club_id, "4-2-3-1", "positive", "high", "standard") == OK)
	var club := _club(session.world, club_id)
	assert(String(club.tactic.formation) == "4-2-3-1")
	assert(command.set_tactical_instruction(session.world, club_id, "transition", "counter_press", true) == OK)
	assert(bool(club.tactic.instructions.transition.counter_press))
	assert(command.set_training(session.world, club_id, ["recovery","technical","tactical","physical","set_pieces","match_prep","rest"], 0.7) == OK)

	var own_player := _own_player(session.world, club_id)
	assert(not own_player.is_empty())
	var promise: Dictionary = command.make_player_promise(session.world, club_id, String(own_player.id), "morale", 0, 1)
	assert(not promise.has("error"))
	var room: Dictionary = command.hold_team_meeting(session.world, club_id, "encourage")
	assert(not room.has("error"))
	assert(float(room.get("atmosphere", 0.0)) > 0.0)

	var competition := _competition_for_club(session.world, club_id)
	assert(not competition.is_empty())
	var auto_key := "%s:%s:%d" % [club_id, String(competition.id), int(session.world.season_year)]
	assert(session.world.registrations.has(auto_key))
	assert(bool(session.world.registrations[auto_key].valid))
	competition["registration_rules"] = {"max_squad":25,"min_homegrown":0,"max_foreign":25,"min_goalkeepers":2,"min_age":15}
	var ids: Array = []
	for player in session.world.players:
		if String(player.get("club_id", "")) == club_id and ids.size() < 25: ids.append(String(player.id))
	var registration: Dictionary = RegistrationClass.new().register_squad(session.world, club_id, competition, ids, int(session.world.season_year))
	assert(bool(registration.valid))
	assert(registration.registered.size() > 0)
	assert(int(registration.goalkeepers) >= 2)
	assert(RegistrationClass.new().is_registered(session.world, club_id, String(competition.id), int(session.world.season_year), String(registration.registered[0])))

	var preview: Array = YouthAcademyClass.new().intake_preview(session.world, club_id, 99119, 6)
	assert(preview.size() == 6)
	for prospect in preview: assert(int(prospect.potential) >= int(prospect.ability))

	var target := _external_player(session.world, club_id)
	assert(not target.is_empty())
	var target_id := String(target.id)
	var assignment: Dictionary = command.assign_scout(session.world, club_id, target_id)
	assert(not assignment.has("error"))
	club.cash = 2_000_000_000
	club.transfer_budget = 1_500_000_000
	club.wage_budget = 2_000_000
	var offer: Dictionary = command.submit_transfer_offer(session.world, club_id, target_id, 1_000_000_000, {"sell_on_percentage":10,"appearance_bonus":5000}, 7001)
	assert(not offer.has("error"))
	assert(String(offer.status) == "accepted")
	var demand: Dictionary = command.contract_demand(session.world, club_id, target_id, 7002)
	assert(not demand.has("error"))
	var completed: Dictionary = command.complete_transfer(session.world, String(offer.id), int(demand.weekly_wage) + 10_000, int(demand.signing_bonus) + 10_000, int(demand.years_preferred), 7002)
	assert(int(completed.get("error", -1)) == OK)
	assert(String(target.club_id) == club_id)
	assert(String(offer.status) == "completed")
	assert(completed.contract.has("clauses"))
	assert(int(completed.contract.clauses.sell_on_percentage) == 10)
	var transfer_entries := 0
	for entry in session.world.get("ledger", []):
		if String(entry.get("category", "")) in ["transfer_fee","signing_bonus","agent_fee"]: transfer_entries += 1
	assert(transfer_entries >= 3)

	for day in range(8):
		var result: Dictionary = DayRunnerClass.new().advance_day(session.world, session.history, 99000 + day)
		assert(not result.has("error"))
		assert(result.has("services"))
	assert(int(session.world.get("day_index", 0)) == 8)
	assert(session.world.has("scout_assignments"))
	assert(InboxClass.new().unread(session.world).size() > 0)
	assert(String(promise.status) in ["fulfilled","broken"])

	session.world.date = "2026-07-31"
	var matchday: Dictionary = DayRunnerClass.new().advance_day(session.world, session.history, 123456)
	assert(not matchday.has("error"))
	assert(int(matchday.fixtures_played) > 0)
	var detailed_count := 0
	var background_count := 0
	for row in matchday.results:
		var fixture: Dictionary = row.fixture
		for side in ["home", "away"]:
			var side_club := String(fixture.home_club_id) if side == "home" else String(fixture.away_club_id)
			for player_id in row.result.get("lineups", {}).get(side, []):
				assert(RegistrationClass.new().is_registered(session.world, side_club, String(fixture.competition_id), int(session.world.season_year), String(player_id)))
		if bool(row.get("detailed", false)):
			detailed_count += 1
			assert(row.result.has("spatial"))
			assert(String(row.result.spatial.model) == "causal_2d_v2")
			assert(row.result.spatial.frames.size() > 0)
		else:
			background_count += 1
	assert(detailed_count == 1)
	assert(background_count > 0)
	assert(session.world.has("last_managed_match"))
	assert(String(session.world.last_managed_match.result.spatial.model) == "causal_2d_v2")

	var path := "user://rc2_integration.fdn"
	assert(session.save_career(path) == OK)
	var loaded = CareerSessionClass.new()
	assert(loaded.load_career(path) == OK)
	assert(String(loaded.manager.name) == "RC2 Manager")
	assert(String(loaded.managed_club_id) == club_id)
	assert(int(loaded.world.get("day_index", 0)) == 9)
	assert(loaded.world.has("last_managed_match"))
	var loaded_club := _club(loaded.world, club_id)
	assert(bool(loaded_club.tactic.instructions.transition.counter_press))
	var loaded_target := _player(loaded.world, target_id)
	assert(String(loaded_target.club_id) == club_id)
	assert(loaded.world.get("registrations", {}).size() > 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	print("[TEST] RC2 INTEGRATION PASS")
	quit(0)

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.clubs:
		if String(club.id) == club_id: return club
	return {}

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.players:
		if String(player.id) == player_id: return player
	return {}

func _own_player(world: Dictionary, club_id: String) -> Dictionary:
	for player in world.players:
		if String(player.club_id) == club_id and not bool(player.get("retired", false)): return player
	return {}

func _external_player(world: Dictionary, club_id: String) -> Dictionary:
	for player in world.players:
		if String(player.club_id) != club_id and not bool(player.get("retired", false)): return player
	return {}

func _competition_for_club(world: Dictionary, club_id: String) -> Dictionary:
	for competition in world.competitions:
		if String(competition.get("competition_type", "league")) == "league" and club_id in competition.get("club_ids", []): return competition
	return {}

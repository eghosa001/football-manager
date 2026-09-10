extends SceneTree

const CareerSessionClass = preload("res://application/career/career_session.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const CommandClass = preload("res://application/career/career_command_service.gd")
const InboxClass = preload("res://application/career/inbox_service.gd")

func _init() -> void:
	var session = CareerSessionClass.new()
	var snap: Dictionary = session.new_career("RC2 Manager", "", 919191)
	assert(not session.world.is_empty())
	assert(String(snap.club_id) != "")
	var command = CommandClass.new()
	var club_id := String(session.managed_club_id)

	assert(command.set_tactic(session.world, club_id, "4-2-3-1", "positive", "high", "standard") == OK)
	var club := _club(session.world, club_id)
	assert(String(club.tactic.formation) == "4-2-3-1")
	assert(command.set_training(session.world, club_id, ["recovery","technical","tactical","physical","set_pieces","match_prep","rest"], 0.7) == OK)

	var target := _external_player(session.world, club_id)
	assert(not target.is_empty())
	var assignment: Dictionary = command.assign_scout(session.world, club_id, String(target.id))
	assert(not assignment.has("error"))
	var offer: Dictionary = command.submit_transfer_offer(session.world, club_id, String(target.id), 1_000_000_000, {"sell_on_percentage":10}, 7001)
	assert(not offer.has("error"))
	assert(String(offer.status) in ["accepted","rejected"])

	for day in range(8):
		var result: Dictionary = DayRunnerClass.new().advance_day(session.world, session.history, 99000 + day)
		assert(not result.has("error"))
		assert(result.has("services"))
	assert(int(session.world.get("day_index", 0)) == 8)
	assert(session.world.has("scout_assignments"))
	assert(InboxClass.new().unread(session.world).size() > 0)

	# Force the next advance onto the first scheduled matchday and verify the
	# human club is routed through the detailed causal engine while background
	# fixtures remain lightweight.
	session.world.date = "2026-07-31"
	var matchday: Dictionary = DayRunnerClass.new().advance_day(session.world, session.history, 123456)
	assert(not matchday.has("error"))
	assert(int(matchday.fixtures_played) > 0)
	var detailed_count := 0
	var background_count := 0
	for row in matchday.results:
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	print("[TEST] RC2 INTEGRATION PASS")
	quit(0)

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.clubs:
		if String(club.id) == club_id:
			return club
	return {}

func _external_player(world: Dictionary, club_id: String) -> Dictionary:
	for player in world.players:
		if String(player.club_id) != club_id and not bool(player.get("retired", false)):
			return player
	return {}

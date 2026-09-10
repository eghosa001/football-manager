extends SceneTree

const Session = preload("res://application/career/career_session.gd")
const Days = preload("res://application/career/day_runner.gd")

func _init() -> void:
	var session = Session.new()
	session.world = preload("res://simulation/world/world_generator.gd").new().create_world(31337, 1, 4, 25)
	var upper: Dictionary = session.world.competitions[0]
	var lower: Dictionary = upper.duplicate(true)
	upper.club_ids = upper.club_ids.slice(0, 2)
	upper.tier = 1; upper.relegation_places = 1
	lower.id = "lower"; lower.name = "Second Division"; lower.tier = 2; lower.promotion_places = 1
	lower.club_ids = lower.club_ids.slice(2, 4)
	session.world.competitions.append(lower)
	preload("res://application/season/league_system.gd").new().rollover(session.world, 2026)
	session.seed = 31337
	session.managed_club_id = String(upper.club_ids[0])
	session.manager = {"id":"human-manager","name":"Rollover Test","club_id":session.managed_club_id}
	session.world.human_manager = session.manager.duplicate(true)
	session._initialize_world(true)
	var days = Days.new()
	for year in range(2026, 2028):
		while String(session.world.date) < "%d-06-30" % (year + 1):
			var result: Dictionary = days.advance_day(session.world, session.history, 31337 + int(session.world.get("day_index", 0)))
			assert(not result.has("error"))
		assert(session.save_career("user://boundary.fdn") == OK)
		var loaded = Session.new()
		assert(loaded.load_career("user://boundary.fdn") == OK)
		var result: Dictionary = days.advance_day(session.world, session.history, 1234)
		var reloaded: Dictionary = days.advance_day(loaded.world, loaded.history, 1234)
		assert(not result.has("error") and not result.rollover.is_empty())
		assert(result == reloaded)
		assert(session.world == loaded.world and session.history == loaded.history)
		assert(int(session.world.season_year) == year + 1)
		assert(session.history.size() == (year - 2025) * 2)
		assert(result.rollover.season.movements.size() > 0)
		assert(session.world.registrations.size() > 0)
		var history_count: int = session.history.size()
		days.advance_day(session.world, session.history, 1235)
		assert(session.history.size() == history_count)
		print("[TEST] Career rollover %d passed" % (year + 1))
	print("[TEST] CAREER ROLLOVER PASS")
	quit(0)

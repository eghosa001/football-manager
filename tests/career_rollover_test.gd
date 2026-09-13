extends SceneTree

const Session = preload("res://application/career/career_session.gd")
const Days = preload("res://application/career/day_runner.gd")

func _init() -> void:
	var session = Session.new()
	session.world = preload("res://simulation/world/world_generator.gd").new().create_world(31337, 1, 4, 25)
	var upper: Dictionary = session.world.competitions[0]
	var lower: Dictionary = upper.duplicate(true)
	upper.club_ids = upper.club_ids.slice(0, 2)
	upper.tier = 1
	upper.relegation_places = 1
	lower.id = "lower"
	lower.name = "Second Division"
	lower.tier = 2
	lower.promotion_places = 1
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
		assert(int(session.world.get("season_year", 0)) == year)
		_complete_season_state(session.world)
		session.world["date"] = "%d-06-30" % (year + 1)

		var boundary_path := "user://boundary.fdn"
		assert(session.save_career(boundary_path) == OK)
		var loaded = Session.new()
		assert(loaded.load_career(boundary_path) == OK)

		var history_before := session.history.size()
		var result: Dictionary = days.advance_day(session.world, session.history, 1234 + year)
		var reloaded: Dictionary = days.advance_day(loaded.world, loaded.history, 1234 + year)
		assert(not result.has("error") and not result.rollover.is_empty())
		assert(result == reloaded)
		assert(session.world == loaded.world and session.history == loaded.history)
		assert(int(session.world.season_year) == year + 1)
		assert(session.history.size() > history_before)
		assert(result.rollover.season.movements.size() > 0)
		assert(session.world.registrations.size() > 0)

		var history_count := session.history.size()
		var next_day: Dictionary = days.advance_day(session.world, session.history, 2234 + year)
		assert(not next_day.has("error"))
		assert(session.history.size() == history_count)
		print("[TEST] Career rollover %d passed" % (year + 1))

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://boundary.fdn"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://boundary.fdn.bak"))
	print("[TEST] CAREER ROLLOVER PASS")
	quit(0)

func _complete_season_state(world: Dictionary) -> void:
	# This regression validates the rollover boundary itself. Long-horizon daily
	# simulation belongs to the dedicated soak tests, so mark the current season
	# complete deterministically before crossing July 1.
	for i in range(world.get("fixtures", []).size()):
		var fixture: Dictionary = world.fixtures[i]
		fixture["played"] = true
		fixture["home_goals"] = i % 3
		fixture["away_goals"] = (i + 1) % 2
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "league")) == "knockout":
			var bracket: Dictionary = competition.get("knockout_bracket", {})
			bracket["complete"] = true
			competition["knockout_bracket"] = bracket

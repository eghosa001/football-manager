extends SceneTree

const CareerSessionClass = preload("res://application/career/career_session.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const QueryClass = preload("res://application/career/career_query.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var session = CareerSessionClass.new()
	var started := Time.get_ticks_msec()
	var created: Dictionary = session.new_career("Speed Audit", "", 424242, 1)
	var career_ms := Time.get_ticks_msec() - started
	assert(not created.has("error"))
	print("[SPEED] one_country_career_ms=%d players=%d clubs=%d fixtures=%d" % [career_ms, session.world.get("players", []).size(), session.world.get("clubs", []).size(), session.world.get("fixtures", []).size()])

	var query = QueryClass.new()
	started = Time.get_ticks_msec()
	var dashboard: Dictionary = query.dashboard(session.world, session.managed_club_id)
	var dashboard_ms := Time.get_ticks_msec() - started
	assert(not dashboard.is_empty())
	print("[SPEED] dashboard_query_ms=%d" % dashboard_ms)

	var runner = DayRunnerClass.new()
	started = Time.get_ticks_msec()
	var ordinary: Dictionary = runner.advance_day(session.world, session.history, 424243)
	var ordinary_ms := Time.get_ticks_msec() - started
	assert(not ordinary.has("error"))
	print("[SPEED] ordinary_continue_ms=%d" % ordinary_ms)

	# Reach the first weekly service boundary without invoking a managed match.
	while int(session.world.get("day_index", 0)) < 6:
		var result: Dictionary = runner.advance_day(session.world, session.history, 424243 + int(session.world.get("day_index", 0)))
		assert(not result.has("error"))
	started = Time.get_ticks_msec()
	var weekly: Dictionary = runner.advance_day(session.world, session.history, 424299)
	var weekly_ms := Time.get_ticks_msec() - started
	assert(not weekly.has("error"))
	print("[SPEED] weekly_boundary_ms=%d" % weekly_ms)

	# Keep these broad enough for shared CI runners while still catching severe
	# regressions. The stricter performance_baseline_test owns release thresholds.
	assert(career_ms < 30000, "One-country career creation is pathologically slow")
	assert(dashboard_ms < 1500, "Dashboard query should never copy large world/replay payloads")
	assert(ordinary_ms < 5000, "Ordinary Continue is pathologically slow")
	assert(weekly_ms < 12000, "Weekly boundary is pathologically slow")

	print("[TEST] APP SPEED BREAKDOWN PASS")
	quit(0)

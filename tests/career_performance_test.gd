extends SceneTree

func _init() -> void:
	var session = preload("res://application/career/career_session.gd").new()
	var started := Time.get_ticks_msec()
	session.new_career("Performance", "", 99123)
	print("[PERFORMANCE] full launch world: %d ms; %d countries, %d clubs, %d players" % [Time.get_ticks_msec() - started, session.world.countries.size(), session.world.clubs.size(), session.world.players.size()])
	var days = preload("res://application/career/day_runner.gd").new()
	for index in range(7):
		started = Time.get_ticks_msec()
		var result: Dictionary = days.advance_day(session.world, session.history, 99124 + index)
		assert(not result.has("error"))
		print("[PERFORMANCE] day %d: %d ms" % [index + 1, Time.get_ticks_msec() - started])
	session.world.date = "2026-07-31"
	started = Time.get_ticks_msec()
	var matchday: Dictionary = days.advance_day(session.world, session.history, 99140)
	assert(not matchday.has("error"))
	assert(int(matchday.fixtures_played) > 0)
	print("[PERFORMANCE] opening matchday: %d ms; %d fixtures" % [Time.get_ticks_msec() - started, int(matchday.fixtures_played)])
	print("[TEST] CAREER PERFORMANCE PASS")
	quit(0)

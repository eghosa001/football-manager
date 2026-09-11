extends SceneTree

func _init() -> void:
	var started := Time.get_ticks_msec()
	var session = preload("res://application/career/career_session.gd").new()
	session.new_career("Expanded", "jpn-t1-c01", 92828, 0, [], true)
	assert(session.world.countries.size() == 24)
	assert(session.world.clubs.size() == 908)
	assert(session.world.players.size() == 25424)
	var catalog: Dictionary = preload("res://data/launch_catalog.gd").new().build(0, true)
	for i in range(catalog.clubs.size()): assert(catalog.clubs[i].name == session.world.clubs[i].name)
	var cups := 0
	for competition in session.world.competitions:
		if bool(competition.get("continental", false)): cups += 1
	assert(cups == 16)
	var dates := {}
	for fixture in session.world.fixtures:
		for club in [fixture.home_club_id, fixture.away_club_id]:
			var key := "%s:%s" % [club, fixture.date]
			assert(not dates.has(key))
			dates[key] = true
	var day: Dictionary = preload("res://application/career/day_runner.gd").new().advance_day(session.world, session.history, 92829)
	assert(not day.has("error"))
	assert(session.save_career("user://expanded-test.save") == OK)
	var loaded = preload("res://application/career/career_session.gd").new()
	assert(loaded.load_career("user://expanded-test.save") == OK)
	assert(loaded.world == session.world)
	print("[TEST] EXPANDED WORLD PASS (%d ms)" % (Time.get_ticks_msec() - started))
	quit(0)

extends SceneTree

func _init() -> void:
	var service = preload("res://application/career/player_stats_service.gd").new()
	var world := {"season_year":2026,"players":[{"id":"p1"},{"id":"p2"}]}
	var fixture := {"id":"f1","competition_id":"league","home_club_id":"a","away_club_id":"b"}
	var result := {"lineups":{"home":["p1"],"away":["p2"]},"events":[{"player_id":"p1","type":"shot","outcome":"goal","xg":0.25},{"player_id":"p2","type":"pass","success":true}]}
	service.record_match(world, fixture, result)
	var first_match: Array = world.player_match_stats.duplicate(true)
	fixture.id = "f2"
	service.record_match(world, fixture, result)
	assert(world.player_match_stats.slice(0, 2) == first_match)
	assert(world.player_match_stats.size() == 4)
	var totals: Dictionary = service.season_totals(world, "p1")
	assert(totals.appearances == 2 and totals.goals == 2 and totals.shots == 2)
	assert(is_equal_approx(totals.xg, 0.5))
	assert(service.season_totals(world, "p2").passes_completed == 2)
	assert(world.player_history[0].goals == 2)
	assert(world.players[0].career_appearances == 2)
	print("[TEST] PLAYER STATS PASS")
	quit(0)

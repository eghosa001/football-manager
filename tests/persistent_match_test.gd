extends SceneTree

func _init() -> void:
	var world: Dictionary = preload("res://simulation/world/world_generator.gd").new().create_world(211, 1, 2, 25)
	var home: Array = world.players.slice(0, 11)
	var away: Array = world.players.slice(25, 36)
	var spatial = preload("res://simulation/match/spatial_match_engine_v2.gd").new()
	var state: Dictionary = spatial._initial_state(home, away, "home")
	state.home_positions[String(home[6].id)] = {"x":37.25,"y":29.5}
	state.ball = state.home_positions[String(home[6].id)].duplicate()
	var segment: Dictionary = spatial.simulate_possession(home, away, 76, 1, "away", state)
	assert(segment.initial_state == state)
	assert(segment.frames.size() == 1)
	var continuation: Dictionary = spatial.simulate_possession(home, away, 77, 1, "away", segment.state)
	if not String(segment.state.ball_owner_id).is_empty(): assert(continuation.initial_state == segment.state)
	var before: Array = world.players.duplicate(true)
	var full = preload("res://simulation/match/full_match_engine_v2.gd").new()
	var goals := 0
	var shots := 0
	for seed in range(200):
		var result: Dictionary = full.simulate_match(world.clubs[0], world.clubs[1], world.players, seed + 411)
		assert(not result.has("error"))
		goals += int(result.home_goals) + int(result.away_goals)
		shots += int(result.stats.home.shots) + int(result.stats.away.shots)
		var previous_time := -1.0
		for frame in result.spatial.frames:
			assert(float(frame.minute) >= previous_time)
			previous_time = float(frame.minute)
	assert(world.players == before, "Simulation must not mutate player fitness outside the match")
	print("[DETAILED VALIDATION] 200 matches, goals %.2f, shots %.2f" % [float(goals)/200.0, float(shots)/200.0])
	assert(float(goals)/200.0 >= 1.0 and float(goals)/200.0 <= 5.0)
	assert(float(shots)/200.0 >= 6.0 and float(shots)/200.0 <= 35.0)
	print("[TEST] PERSISTENT MATCH PASS")
	quit(0)

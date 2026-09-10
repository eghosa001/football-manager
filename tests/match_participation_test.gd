extends SceneTree

func _init() -> void:
	var world: Dictionary = preload("res://simulation/world/world_generator.gd").new().create_world(1234, 1, 2, 25)
	var engine = preload("res://simulation/match/full_match_engine_v2.gd").new()
	var red_count := 0
	for seed in range(40):
		var result: Dictionary = engine.simulate_match(world.clubs[0], world.clubs[1], world.players, seed)
		assert(not result.has("error"))
		var active: Dictionary = result.lineups.duplicate(true)
		for event in result.events:
			var side := String(event.get("side", "home"))
			if String(event.type) == "substitution":
				assert(String(event.player_out) in active[side])
				assert(String(event.player_in) not in active[side])
				active[side].erase(String(event.player_out))
				active[side].append(String(event.player_in))
			elif event.has("player_id"):
				assert(String(event.player_id) in active[side])
				if String(event.type) == "card" and String(event.card) == "red":
					active[side].erase(String(event.player_id))
					red_count += 1
		for side in ["home", "away"]:
			var expected: Array = active[side].duplicate(); expected.sort()
			var actual: Array = result.final_lineups[side].duplicate(); actual.sort()
			assert(expected == actual)
		assert(result.substitutions.size() > 0)
	assert(red_count > 0)
	print("[TEST] MATCH PARTICIPATION PASS")
	quit(0)

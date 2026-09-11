extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const PlayerLifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const ContinuousSpatialClass = preload("res://simulation/match/continuous_spatial_engine.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")

func _init() -> void:
	_run.call_deferred()

func _lineups(world: Dictionary) -> Array:
	var lifecycle = PlayerLifecycleClass.new()
	for player in world.players:
		lifecycle.ensure_player_state(player, 777001)
	var home: Array = []
	var away: Array = []
	for player in world.players:
		if String(player.club_id) == String(world.clubs[0].id) and home.size() < 11:
			home.append(player)
		elif String(player.club_id) == String(world.clubs[1].id) and away.size() < 11:
			away.append(player)
	return [home, away]

func _run() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(777001)
	var sides: Array = _lineups(world)
	var home: Array = sides[0]
	var away: Array = sides[1]
	var engine = ContinuousSpatialClass.new()
	var tactics = TacticsManagerClass.new()
	var balanced_home := tactics.create_tactic("4-3-3", "balanced", "standard", "standard")
	var balanced_away := tactics.create_tactic("4-4-2", "balanced", "standard", "standard")

	# Determinism.
	var first: Dictionary = engine.simulate_continuous(home, away, 424242, balanced_home, balanced_away, 300)
	var second: Dictionary = engine.simulate_continuous(home, away, 424242, balanced_home, balanced_away, 300)
	assert(var_to_str(first.summary) == var_to_str(second.summary))
	assert(first.frames.size() == 300)

	# Bounds + energy + loads.
	var moved := false
	var first_frame: Dictionary = first.frames[0]
	for frame in first.frames:
		assert(float(frame.ball.x) >= 0.0 and float(frame.ball.x) <= 105.0)
		assert(float(frame.ball.y) >= 0.0 and float(frame.ball.y) <= 68.0)
		for side in ["home", "away"]:
			for id in (frame[side] as Dictionary).keys():
				var p: Dictionary = (frame[side] as Dictionary)[id]
				assert(float(p.x) >= 0.0 and float(p.x) <= 105.0)
				assert(float(p.y) >= 0.0 and float(p.y) <= 68.0)
				var load: Dictionary = ((frame.loads as Dictionary)[side] as Dictionary)[id]
				assert(float(load.energy) >= 0.35 and float(load.energy) <= 1.0)
				assert(float(load.distance) >= 0.0)
	# Movement actually happens.
	var last: Dictionary = first.frames[first.frames.size() - 1]
	for id in (first_frame.home as Dictionary).keys():
		var a: Dictionary = (first_frame.home as Dictionary)[id]
		var b: Dictionary = (last.home as Dictionary)[id]
		if absf(float(a.x) - float(b.x)) > 0.5 or absf(float(a.y) - float(b.y)) > 0.5:
			moved = true
	assert(moved)

	# Tactical causality: wide vs narrow changes occupation first.
	var wide := tactics.create_tactic("4-3-3", "positive", "standard", "standard")
	wide.instructions.in_possession.width = "wide"
	var narrow := tactics.create_tactic("4-3-3", "positive", "standard", "standard")
	narrow.instructions.in_possession.width = "narrow"
	var wide_run: Dictionary = engine.simulate_continuous(home, away, 999111, wide, balanced_away, 240)
	var narrow_run: Dictionary = engine.simulate_continuous(home, away, 999111, narrow, balanced_away, 240)
	var wide_spread := _avg_width(wide_run.frames[120].home)
	var narrow_spread := _avg_width(narrow_run.frames[120].home)
	assert(wide_spread > narrow_spread + 1.0)

	# High press creates more interceptions/pressing load than low block.
	var press := tactics.create_tactic("4-3-3", "balanced", "standard", "very_high")
	var block := tactics.create_tactic("4-3-3", "balanced", "standard", "low")
	var press_run: Dictionary = engine.simulate_continuous(home, away, 555321, press, balanced_away, 300)
	var block_run: Dictionary = engine.simulate_continuous(home, away, 555321, block, balanced_away, 300)
	assert(int(press_run.summary.interceptions) >= int(block_run.summary.interceptions))

	print("[TEST] PHASE 12 EXTENDED PASS: ticks=%d shots=%d goals=%d interceptions=%d wide=%.1f narrow=%.1f" % [int(first.summary.ticks), int(first.summary.shots), int(first.summary.goals), int(first.summary.interceptions), wide_spread, narrow_spread])
	quit(0)

func _avg_width(positions: Dictionary) -> float:
	var min_y := 999.0
	var max_y := -999.0
	for id in positions.keys():
		var y := float((positions[id] as Dictionary).y)
		min_y = minf(min_y, y)
		max_y = maxf(max_y, y)
	return max_y - min_y

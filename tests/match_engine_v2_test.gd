extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const PlayerLifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const MatchV2Class = preload("res://simulation/match/spatial_match_engine_v2.gd")
const FullMatchV2Class = preload("res://simulation/match/full_match_engine_v2.gd")

func _init() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(60606)
	var lifecycle = PlayerLifecycleClass.new()
	for player in world.players: lifecycle.ensure_player_state(player, 60606)
	var home: Array = []
	var away: Array = []
	for player in world.players:
		if String(player.club_id) == String(world.clubs[0].id) and home.size() < 11: home.append(player)
		elif String(player.club_id) == String(world.clubs[1].id) and away.size() < 11: away.append(player)
	var engine = MatchV2Class.new()
	var a: Dictionary = engine.simulate_possession(home, away, 999, 24)
	var b: Dictionary = engine.simulate_possession(home, away, 999, 24)
	assert(var_to_bytes(a) == var_to_bytes(b))
	assert(a.events.size() > 0)
	for event in a.events:
		for key in ["position","from","to"]:
			if event.has(key):
				assert(float(event[key].x) >= 0.0 and float(event[key].x) <= 105.0)
				assert(float(event[key].y) >= 0.0 and float(event[key].y) <= 68.0)

	var full = FullMatchV2Class.new()
	var first: Dictionary = full.simulate_match(world.clubs[0], world.clubs[1], world.players, 20260910)
	var second: Dictionary = full.simulate_match(world.clubs[0], world.clubs[1], world.players, 20260910)
	assert(not first.has("error"))
	assert(var_to_bytes(first) == var_to_bytes(second))
	assert(first.events.size() > 20)
	assert(int(first.stats.home.goals) == int(first.home_goals))
	assert(int(first.stats.away.goals) == int(first.away_goals))
	assert(is_equal_approx(float(first.stats.home.possession) + float(first.stats.away.possession), 100.0))
	assert(first.spatial.frames.size() == 54)
	for frame in first.spatial.frames:
		assert(float(frame.ball.x) >= 0.0 and float(frame.ball.x) <= 105.0)
		assert(float(frame.ball.y) >= 0.0 and float(frame.ball.y) <= 68.0)
	print("[TEST] MATCH ENGINE V2 PASS")
	quit(0)

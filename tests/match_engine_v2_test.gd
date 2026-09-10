extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const PlayerLifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const MatchV2Class = preload("res://simulation/match/spatial_match_engine_v2.gd")

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
	assert(a == b)
	assert(a.events.size() > 0)
	for event in a.events:
		if event.has("position"):
			assert(float(event.position.x) >= 0.0 and float(event.position.x) <= 105.0)
			assert(float(event.position.y) >= 0.0 and float(event.position.y) <= 68.0)
	print("[TEST] MATCH ENGINE V2 PASS")
	quit(0)

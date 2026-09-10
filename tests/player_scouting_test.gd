extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const PlayerProfileClass = preload("res://simulation/players/player_profile.gd")
const ScoutingClass = preload("res://simulation/scouting/scouting_service.gd")

func _init() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(50505)
	var player: Dictionary = world.players[0]
	var profile = PlayerProfileClass.new()
	profile.ensure(player)
	assert(player.attributes.size() >= 40)
	assert(player.hidden_attributes.size() >= 12)
	var scouting = ScoutingClass.new()
	scouting.ensure_world(world)
	var report: Dictionary = scouting.player_report(world, player, 35, 42)
	assert(report.knowledge < 0.95)
	var any_range := false
	for value in report.attributes.values():
		if int(value.max) > int(value.min): any_range = true
	assert(any_range)
	world.scouting_knowledge[String(player.id)] = 1.0
	report = scouting.player_report(world, player, 100, 42)
	for value in report.attributes.values(): assert(value.exact != null)
	print("[TEST] PLAYER/SCOUTING PASS")
	quit(0)

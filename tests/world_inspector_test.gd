extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const InspectorClass = preload("res://tools/world_inspector/world_inspector.gd")

func _init() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(70707)
	var inspector = InspectorClass.new()
	var summary: Dictionary = inspector.summarize(world)
	assert(int(summary.clubs) == world.clubs.size())
	assert(int(summary.players_active) > 0)
	assert(inspector.validate(world).is_empty())
	print("[TEST] WORLD INSPECTOR PASS")
	quit(0)

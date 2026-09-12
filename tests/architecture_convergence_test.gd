extends SceneTree

const RouterClass = preload("res://simulation/match/engine_router.gd")
const CareerScreenRegistryClass = preload("res://game/career/career_screen_registry.gd")
const CareerCycleServiceClass = preload("res://application/career/career_cycle_service.gd")
const PlayerLifecycleServiceClass = preload("res://simulation/players/player_lifecycle_service.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_match_engine_boundary()
	_test_career_navigation_boundary()
	_test_career_scene_boundary()
	_test_lifecycle_facades()
	print("[TEST] ARCHITECTURE CONVERGENCE PASS")
	quit(0)

func _test_match_engine_boundary() -> void:
	var router = RouterClass.new()
	assert(router.authoritative_engine() == RouterClass.DETAILED)
	assert(router.supported_tiers() == [RouterClass.DETAILED, RouterClass.EVENT, RouterClass.ABSTRACT, RouterClass.AGGREGATE])
	assert(router._engines.has(RouterClass.DETAILED))
	assert(router._engines.has(RouterClass.EVENT))
	assert(router._engines.has(RouterClass.ABSTRACT))
	assert(router._engines.has(RouterClass.AGGREGATE))
	var event_script: Script = router._engines[RouterClass.EVENT].get_script()
	assert(event_script.resource_path == "res://simulation/match/event_match_engine.gd")

func _test_career_navigation_boundary() -> void:
	var registry = CareerScreenRegistryClass.new()
	var validation: Dictionary = registry.validate_registry()
	assert(bool(validation.get("ok", false)))
	assert(int(validation.get("tab_count", 0)) == 15)
	var plan: Array = registry.tab_plan()
	var expected_ids := ["dashboard", "squad", "training", "tactics", "medical", "scouting", "transfers", "schedule", "competitions", "inbox", "staff", "youth", "finances", "search", "match_analysis"]
	var actual_ids: Array = []
	for row in plan:
		actual_ids.append(String(row.get("id", "")))
	assert(actual_ids == expected_ids)
	assert(String(plan[9].get("owner", "")) == "app")
	assert(String(plan[9].get("builder", "")) == "_add_inbox_tab")
	assert(String(plan[11].get("builder", "")) == "add_youth")
	assert(String(plan[14].get("builder", "")) == "add_match_analysis")

func _test_career_scene_boundary() -> void:
	var packed: PackedScene = load("res://game/scenes/career_app.tscn")
	assert(packed != null)
	var instance = packed.instantiate()
	assert(instance != null)
	var script: Script = instance.get_script()
	assert(script != null)
	assert(script.resource_path == "res://game/career/registry_career_app.gd")
	instance.free()

func _test_lifecycle_facades() -> void:
	var cycle = CareerCycleServiceClass.new()
	var lifecycle = PlayerLifecycleServiceClass.new()
	assert(cycle.get_script().resource_path == "res://application/career/career_cycle_service.gd")
	assert(lifecycle.get_script().resource_path == "res://simulation/players/player_lifecycle_service.gd")

	var session_source := FileAccess.get_file_as_string("res://application/career/career_session.gd")
	assert("career_cycle_service.gd" in session_source)
	assert("career_cycle_v2.gd" not in session_source)
	var cycle_facade_source := FileAccess.get_file_as_string("res://application/career/career_cycle_service.gd")
	assert("career_cycle_v2.gd" in cycle_facade_source)

	var living_source := FileAccess.get_file_as_string("res://simulation/world/living_world.gd")
	assert("player_lifecycle_v2.gd" not in living_source)
	var lifecycle_facade_source := FileAccess.get_file_as_string("res://simulation/players/player_lifecycle_service.gd")
	assert("player_lifecycle_v2.gd" in lifecycle_facade_source)

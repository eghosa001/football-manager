extends SceneTree

const RouterClass = preload("res://simulation/match/engine_router.gd")
const CareerScreenRegistryClass = preload("res://game/career/career_screen_registry.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_match_engine_boundary()
	_test_career_navigation_boundary()
	_test_career_scene_boundary()
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
	assert(int(validation.get("tab_count", 0)) == 14)
	var plan: Array = registry.tab_plan()
	var expected_ids := ["dashboard", "squad", "training", "tactics", "medical", "scouting", "transfers", "schedule", "competitions", "inbox", "staff", "finances", "search", "match_analysis"]
	var actual_ids: Array = []
	for row in plan:
		actual_ids.append(String(row.get("id", "")))
	assert(actual_ids == expected_ids)
	assert(String(plan[9].get("owner", "")) == "app")
	assert(String(plan[9].get("builder", "")) == "_add_inbox_tab")
	assert(String(plan[13].get("builder", "")) == "add_match_analysis")

func _test_career_scene_boundary() -> void:
	var packed: PackedScene = load("res://game/scenes/career_app.tscn")
	assert(packed != null)
	var instance = packed.instantiate()
	assert(instance != null)
	var script: Script = instance.get_script()
	assert(script != null)
	assert(script.resource_path == "res://game/career/registry_career_app.gd")
	instance.free()

extends SceneTree

const RouterClass = preload("res://simulation/match/engine_router.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var router = RouterClass.new()
	assert(router.authoritative_engine() == RouterClass.DETAILED)
	assert(router.supported_tiers() == [RouterClass.DETAILED, RouterClass.EVENT, RouterClass.ABSTRACT, RouterClass.AGGREGATE])
	assert(router._engines.has(RouterClass.DETAILED))
	assert(router._engines.has(RouterClass.EVENT))
	assert(router._engines.has(RouterClass.ABSTRACT))
	assert(router._engines.has(RouterClass.AGGREGATE))
	var event_script: Script = router._engines[RouterClass.EVENT].get_script()
	assert(event_script.resource_path == "res://simulation/match/event_match_engine.gd")
	print("[TEST] ARCHITECTURE CONVERGENCE PASS")
	quit(0)

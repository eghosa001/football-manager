extends SceneTree

const Session = preload("res://simulation/match/managed_match_session.gd")

func _init() -> void:
	assert(Session.new() != null)
	var coordinator_script = load("res://application/career/managed_matchday_coordinator.gd")
	assert(coordinator_script != null)
	var coordinator = coordinator_script.new()
	assert(coordinator != null)
	print("[TEST] MANAGED MATCHDAY COMPILE PASS")
	quit(0)

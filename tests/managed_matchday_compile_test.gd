extends SceneTree

const Session = preload("res://simulation/match/managed_match_session.gd")
const Coordinator = preload("res://application/career/managed_matchday_coordinator.gd")

func _init() -> void:
	assert(Session.new() != null)
	assert(Coordinator.new() != null)
	print("[TEST] MANAGED MATCHDAY COMPILE PASS")
	quit(0)

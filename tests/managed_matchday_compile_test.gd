extends SceneTree

const Session = preload("res://simulation/match/managed_match_session.gd")

func _init() -> void:
	assert(Session.new() != null)
	var coordinator_script = load("res://application/career/managed_matchday_coordinator.gd")
	assert(coordinator_script != null)
	assert(coordinator_script.new() != null)
	var committer_script = load("res://application/career/managed_matchday_committer.gd")
	assert(committer_script != null)
	assert(committer_script.new() != null)
	print("[TEST] MANAGED MATCHDAY COMPILE PASS")
	quit(0)

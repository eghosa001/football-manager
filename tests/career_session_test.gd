extends SceneTree

const CareerSessionClass = preload("res://application/career/career_session.gd")

func _init() -> void:
	var session = CareerSessionClass.new()
	var snap: Dictionary = session.new_career("Test Manager", "", 424242)
	assert(String(snap.manager.name) == "Test Manager")
	assert(String(snap.club_id) != "")
	var path := "user://career_session_test.fdn"
	assert(session.save_career(path) == OK)
	var loaded = CareerSessionClass.new()
	assert(loaded.load_career(path) == OK)
	assert(loaded.snapshot() == snap)
	var result: Dictionary = loaded.continue_season()
	assert(not result.is_empty())
	assert(int(loaded.snapshot().season_year) == int(snap.season_year) + 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	print("[TEST] CAREER SESSION PASS")
	quit(0)

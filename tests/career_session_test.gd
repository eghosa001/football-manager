extends SceneTree

const CareerSessionClass = preload("res://application/career/career_session.gd")
const SaveSlotsClass = preload("res://application/career/save_slots.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")

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

	var inbox = InboxServiceClass.new()
	var msg: Dictionary = inbox.add_message(loaded.world, "board", "Choose response", "Test decision", true, [{"id":"accept"},{"id":"reject"}])
	assert(inbox.resolve(loaded.world, int(msg.id), "accept") == OK)
	assert(bool(msg.resolved))
	assert(String(msg.selected_action) == "accept")

	var day_before := String(loaded.world.date)
	var day_result: Dictionary = DayRunnerClass.new().advance_day(loaded.world, loaded.history, 424242)
	assert(not day_result.has("error"))
	assert(String(loaded.world.date) != day_before)

	var slots = SaveSlotsClass.new()
	assert(slots.save_slot(1, loaded.world, loaded.history, loaded.manager) == OK)
	var meta: Dictionary = slots.metadata(1)
	assert(bool(meta.exists))
	assert(String(meta.manager) == "Test Manager")
	assert(slots.load_slot(1).has("world"))
	assert(slots.delete_slot(1) == OK)

	var result: Dictionary = loaded.continue_season()
	assert(not result.is_empty())
	assert(int(loaded.snapshot().season_year) == int(snap.season_year) + 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	print("[TEST] CAREER SESSION PASS")
	quit(0)

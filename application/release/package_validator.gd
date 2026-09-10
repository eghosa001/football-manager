extends RefCounted

# Explicit checks also run in exported release builds, where assert is disabled.
func run() -> int:
	var session = preload("res://application/career/career_session.gd").new()
	var snapshot: Dictionary = session.new_career("Release Smoke", "", 24680, 1)
	if snapshot.is_empty() or int(snapshot.get("database_schema", 0)) != 1:
		fail("Launch database is missing from the package"); return 1
	if session.world.countries.size() != 1:
		fail("Unexpected world size"); return 1
	preload("res://game/localization/localization_service.gd").new().install("fr")
	if TranslationServer.translate("New Career") != "Nouvelle carrière":
		fail("Career translation data is missing from the package"); return 1
	var day: Dictionary = preload("res://application/career/day_runner.gd").new().advance_day(session.world, session.history, 24681)
	if day.has("error") or String(session.world.date) != "2026-07-02":
		fail("Day advancement failed"); return 1
	var path := "user://release-smoke.save"
	if session.save_career(path) != OK:
		fail("Save failed"); return 1
	var restored = preload("res://application/career/career_session.gd").new()
	if restored.load_career(path) != OK or restored.world != session.world:
		fail("Save round-trip changed the world"); return 1
	DirAccess.remove_absolute(path)
	print("[TEST] RELEASE SMOKE PASS")
	return 0

func fail(message: String) -> void:
	push_error(message)
	pass

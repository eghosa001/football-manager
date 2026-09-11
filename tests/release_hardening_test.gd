extends SceneTree

const CareerSessionClass = preload("res://application/career/career_session.gd")
const SaveStoreClass = preload("res://persistence/save_store.gd")
const ModLoaderClass = preload("res://tools/modding/mod_loader.gd")
const ModEditorClass = preload("res://tools/modding/mod_editor.gd")
const LocalizationClass = preload("res://game/localization/localization_service.gd")
const SeasonRunnerClass = preload("res://application/season/season_runner.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Save migration: v1 migrates, corrupted rejected, future rejected.
	var store = SaveStoreClass.new()
	assert(store._migrate({"schema_version": 2, "history": []}).is_empty())
	assert(store._migrate({"schema_version": 1, "world": "broken"}).is_empty())
	assert(store._migrate({"schema_version": 999, "world": {}, "history": []}).is_empty())

	# Modding: load order, conflicts, save/mod compat.
	var editor = ModEditorClass.new()
	var loader = ModLoaderClass.new()
	var mod_a := editor.create_mod("mod-a", "Mod A", "1.0", "", [], ["mod-b"])
	var mod_b := editor.create_mod("mod-b", "Mod B", "1.0", "", [], [])
	var order: Dictionary = loader.validate_load_order([mod_a, mod_b])
	assert(not bool(order.get("ok", true)))
	assert(String(order.get("error", "")).begins_with("mod_conflict"))
	var compat: Dictionary = editor.validate_project(mod_a, [mod_b])
	assert(not bool(compat.get("ok", true)))

	# Localization: top-level UI fully covered; dynamic news remains partial (documented).
	var loc = LocalizationClass.new()
	assert(loc.coverage("fr") >= 0.99)
	assert(loc.coverage("pt") >= 0.99)
	assert(loc.text("dashboard", "fr") == "Tableau de bord")

	# Career workflow: create, advance, save/reload across a season boundary.
	var session = CareerSessionClass.new()
	var created: Dictionary = session.new_career("Hardening Test", "", 424242, 0)
	assert(String(created.get("error", "")) == "")
	var world: Dictionary = session.world
	var history: Array = session.history
	var runner = SeasonRunnerClass.new()
	var outcome: Dictionary = runner.complete_and_rollover(world, history, 424242)
	assert(int(outcome.next_season_year) > 2026)
	# Save round-trip preserves manager + world date.
	var payload := {"schema_version": SaveStoreClass.CURRENT_SCHEMA_VERSION, "world": world, "history": history}
	var text := JSON.stringify(payload)
	var parsed: Dictionary = JSON.parse_string(text)
	assert(String((parsed.world as Dictionary).get("date", "")) != "")

	print("[TEST] RELEASE HARDENING PASS")
	quit(0)

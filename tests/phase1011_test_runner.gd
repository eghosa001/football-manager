extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const LivingWorldClass = preload("res://simulation/world/living_world.gd")
const CareerCycleClass = preload("res://application/career/career_cycle.gd")
const ModLoaderClass = preload("res://tools/modding/mod_loader.gd")
const ModEditorClass = preload("res://tools/modding/mod_editor.gd")
const SettingsStoreClass = preload("res://application/settings/settings_store.gd")
const LocalizationClass = preload("res://game/localization/localization_service.gd")
const ReleaseGuardClass = preload("res://application/release/release_guard.gd")
const SaveStoreClass = preload("res://persistence/save_store.gd")

var failures := 0
var checks := 0

func _init() -> void:
	print("[TEST] Football Dynasty Phase 10/11")
	_test_living_world_determinism_and_bounds()
	_test_modding_safety_and_authoring()
	_test_settings_localization_and_release_contract()
	_test_save_schema_migration()
	_test_hundred_year_release_soak()
	if failures == 0:
		print("[TEST] PHASE 10/11 PASS — %d checks" % checks)
		quit(0)
	else:
		push_error("[TEST] PHASE 10/11 FAIL — %d failures across %d checks" % [failures, checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TEST] " + message)

func _test_living_world_determinism_and_bounds() -> void:
	var generator = WorldGeneratorClass.new()
	var base: Dictionary = generator.create_world(101001, 1, 4, 20)
	var a: Dictionary = base.duplicate(true)
	var b: Dictionary = base.duplicate(true)
	var records := _sample_records(a)
	var living_a = LivingWorldClass.new()
	var living_b = LivingWorldClass.new()
	living_a.ensure_world(a)
	living_b.ensure_world(b)
	var result_a: Dictionary = living_a.advance_year(a, records, 919191)
	var result_b: Dictionary = living_b.advance_year(b, records, 919191)
	_expect(a == b, "Identical world/seed living-world ticks must replay exactly")
	_expect(result_a == result_b, "Living-world result summaries must be deterministic")
	_expect(a.manager_careers.size() == a.clubs.size(), "Every generated manager needs a career record")
	_expect(a.awards.size() >= 2, "Completed competition must create champion/player awards")
	_expect(a.rivalries.size() >= 1, "A title race must be capable of creating a rivalry")
	_expect(a.news.size() > 0, "Domain reasons must feed news records")
	for player in a.players:
		_expect(int(player.morale) >= 0 and int(player.morale) <= 100, "Morale must remain bounded")
		_expect(int(player.confidence) >= 0 and int(player.confidence) <= 100, "Confidence must remain bounded")
		_expect(int(player.reputation) >= 1 and int(player.reputation) <= 100, "Player reputation must remain bounded")
	for club in a.clubs:
		_expect(int(club.reputation) >= 10 and int(club.reputation) <= 95, "Club reputation must remain bounded")

func _test_modding_safety_and_authoring() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(102001, 1, 4, 20)
	var loader = ModLoaderClass.new()
	var editor = ModEditorClass.new()
	var club_id: String = String(world.clubs[0].id)
	var good := {"metadata": {"id": "test-mod", "version": "1.0"}, "patches": {"clubs": [{"id": club_id, "name": "Dynasty Test Club", "reputation": 999}]}}
	var result: Dictionary = loader.apply_mod(world, good)
	_expect(result.ok and result.applied == 1, "Whitelisted mod patch must apply")
	_expect(String(world.clubs[0].name) == "Dynasty Test Club", "Mod loader must update allowed string fields")
	_expect(int(world.clubs[0].reputation) == 100, "Mod numeric fields must be range-clamped")
	_expect(world.get("active_mods", []).size() == 1, "Applied mod metadata must be recorded")
	var before: Dictionary = world.duplicate(true)
	var bad := {"patches": {"clubs": [{"id": club_id, "cash": 999999999}]}}
	var rejected: Dictionary = loader.apply_mod(world, bad)
	_expect(not rejected.ok, "Unsafe mod field must be rejected")
	_expect(world == before, "Rejected mods must not partially mutate world state")
	var authored: Dictionary = editor.create_mod("author-test", "Author Test", "1.0")
	var patch_result: Dictionary = editor.add_patch(authored, "clubs", club_id, {"name": "Author Club", "reputation": 74})
	_expect(patch_result.ok, "Mod editor must author a whitelisted patch")
	var mod_path := "user://phase10_author_mod.json"
	_expect(editor.export_mod(mod_path, patch_result.mod) == OK, "Mod editor must export validated JSON")
	var imported: Dictionary = editor.import_mod(mod_path)
	_expect(imported.ok and imported.patches.has("clubs"), "Exported mod must round-trip through loader")
	var invalid_patch: Dictionary = editor.add_patch(authored, "clubs", club_id, {"cash": 10})
	_expect(not invalid_patch.ok, "Mod editor must reject unsafe authored fields before export")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mod_path))

func _test_settings_localization_and_release_contract() -> void:
	var settings_store = SettingsStoreClass.new()
	var path := "user://phase11_settings.json"
	var error: Error = settings_store.save(path, {"language": "fr", "ui_scale": 9.0, "font_scale": 1.4, "high_contrast": true, "autosave_interval_days": 0})
	_expect(error == OK, "Settings must persist offline")
	var settings: Dictionary = settings_store.load(path)
	_expect(String(settings.language) == "fr", "Language preference must round-trip")
	_expect(float(settings.ui_scale) == 2.0, "UI scale must be accessibility-clamped")
	_expect(int(settings.autosave_interval_days) == 1, "Autosave interval must be bounded")
	var loc = LocalizationClass.new()
	_expect(loc.coverage("en") == 1.0 and loc.coverage("fr") == 1.0 and loc.coverage("pt") == 1.0, "Shipped UI localization catalogs need complete key coverage")
	_expect(loc.text("dashboard", "fr") != "Dashboard", "French localization must not silently fall back for known keys")
	var guard = ReleaseGuardClass.new()
	var world: Dictionary = WorldGeneratorClass.new().create_world(103001, 1, 4, 20)
	_expect(guard.validate_world(world).is_empty(), "Fresh world must pass release integrity validation")
	_expect(bool(guard.offline_contract().requires_network) == false, "v1 release must remain playable without network")
	_expect(guard.validate_release_files().is_empty(), "Required release files must exist")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_save_schema_migration() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(104001, 1, 4, 20)
	var old_payload := {"schema_version": 1, "world": world, "history": []}
	var migrated: Dictionary = SaveStoreClass.new()._migrate(old_payload)
	_expect(int(migrated.get("schema_version", 0)) == 2, "Schema v1 saves must migrate to Phase 10 schema v2")
	for key in ["relationships", "rivalries", "awards", "legends", "news", "manager_careers", "active_mods"]:
		_expect(migrated.world.has(key), "Migration must initialize %s" % key)

func _test_hundred_year_release_soak() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(105001, 1, 4, 20)
	var history: Array = []
	var career = CareerCycleClass.new()
	var guard = ReleaseGuardClass.new()
	var save_store = SaveStoreClass.new()
	var path := "user://phase11_release_soak.fdn"
	for year_offset in range(100):
		var result: Dictionary = career.complete_year(world, history, 105001 + year_offset * 97, 1)
		_expect(int(result.season_year) == 2027 + year_offset, "Career year must advance exactly once")
		_expect(guard.validate_world(world).is_empty(), "Release soak world references must remain valid")
		_expect(result.season.records.size() == world.competitions.size(), "Every competition must complete each release-soak season")
		for player in world.players:
			if not bool(player.get("retired", false)):
				_expect(int(player.get("morale", 50)) >= 0 and int(player.get("morale", 50)) <= 100, "Long-save morale must stay bounded")
		for club in world.clubs:
			_expect(int(club.get("cash", 0)) >= 0, "Long-save club cash must not be negative")
			_expect(int(club.get("reputation", 50)) >= 10 and int(club.get("reputation", 50)) <= 95, "Long-save club reputation must stay bounded")
		if (year_offset + 1) % 10 == 0:
			_expect(save_store.save_atomic(path, world, history) == OK, "Release soak autosave must succeed")
			var loaded: Dictionary = save_store.load_save(path)
			_expect(not loaded.is_empty(), "Release soak autosave must reload")
			world = loaded.world
			history = loaded.history
	_expect(history.size() == 100 * world.competitions.size(), "100-season history must retain every completed competition season")
	_expect(world.get("manager_careers", []).size() >= world.clubs.size(), "Manager career history must survive 100 years")
	_expect(world.get("awards", []).size() >= 100, "100-year world must accumulate historical awards")
	_expect(world.get("news", []).size() <= 500, "News archive must remain bounded")
	_expect(world.get("relationships", []).size() < 10000, "Relationship graph must remain bounded for compact launch world")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))

func _sample_records(world: Dictionary) -> Array:
	var competition: Dictionary = world.competitions[0]
	var table: Array = []
	for i in range(competition.club_ids.size()):
		table.append({"club_id": competition.club_ids[i], "points": 20 - i})
	return [{"competition_id": competition.id, "competition_name": competition.name, "champion_club_id": competition.club_ids[0], "table": table, "complete": true}]

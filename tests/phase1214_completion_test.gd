extends SceneTree

const ManagerCareerServiceClass = preload("res://simulation/staff/manager_career_service.gd")
const ModManifestServiceClass = preload("res://mods/mod_manifest_service.gd")
const SettingsStoreClass = preload("res://application/settings/settings_store.gd")
const LocalizationServiceClass = preload("res://game/localization/localization_service.gd")
const CareerScreenRegistryClass = preload("res://game/career/career_screen_registry.gd")
const MatchdayProfilerClass = preload("res://application/performance/matchday_profiler.gd")
const ReleaseGuardClass = preload("res://application/release/release_guard.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_living_world_manager_careers()
	_test_modding_contracts()
	_test_polish_and_release_contracts()
	print("[TEST] PHASE 12-14 COMPLETION PASS")
	quit(0)

func _test_living_world_manager_careers() -> void:
	var service = ManagerCareerServiceClass.new()
	var world := {"season_year": 2026}
	var manager: Dictionary = service.create_manager(world, "manager-1", "Ada Manager", false, "")
	var job: Dictionary = service.advertise_job(world, "club-1", "club", 55.0)
	var applied: Dictionary = service.apply_for_job(world, manager, job)
	assert(String(applied.get("status", "")) == "applied")
	var interview: Dictionary = service.interview(manager, job, {"philosophy_fit":1.0,"wage_fit":1.0,"confidence":1.0}, 42)
	assert(interview.has("score"))
	var contract: Dictionary = service.offer_contract(world, manager, job, 2500, 3)
	var accepted: Dictionary = service.accept_job(manager, job, contract)
	assert(String(accepted.get("status", "")) == "accepted")
	assert(String(manager.get("club_id", "")) == "club-1")
	service.evolve_ai_manager(manager, {"performance":0.8,"trophies":1})
	assert(float(manager.get("reputation", 0.0)) > 50.0)
	var sacked: Dictionary = service.sack(manager, "club-1", ["poor_results"])
	assert(String(sacked.get("status", "")) == "sacked")
	assert(String(manager.get("employment", "")) == "unemployed")

func _test_modding_contracts() -> void:
	var service = ModManifestServiceClass.new()
	var manifests := [
		{"id":"base-ext","name":"Base Extension","version":"1.0.0","safe_remove":true,"writes":["clubs/base-ext"]},
		{"id":"rules-ext","name":"Rules Extension","version":"1.0.0","dependencies":["base-ext"],"load_after":["base-ext"],"writes":["competitions/rules-ext"]}
	]
	var valid: Dictionary = service.validate_manifests(manifests)
	assert(bool(valid.get("ok", false)))
	assert(valid.get("load_order", []) == ["base-ext", "rules-ext"])
	var blocked: Dictionary = service.can_remove_from_career(manifests, "base-ext")
	assert(not bool(blocked.get("ok", true)))
	assert("required_by_other_mods" in blocked.get("reason_codes", []))
	var conflict: Dictionary = service.validate_manifests([
		{"id":"a","writes":["clubs/1"]},
		{"id":"b","writes":["clubs/1"]}
	])
	assert(not bool(conflict.get("ok", true)))
	var integrity: Dictionary = service.verify_integrity({"id":"hash-test","integrity_hash":"ABC123"}, "abc123")
	assert(bool(integrity.get("ok", false)))

func _test_polish_and_release_contracts() -> void:
	var settings = SettingsStoreClass.new().sanitize({
		"language":"xx",
		"ui_scale":5.0,
		"font_scale":0.1,
		"autosave":false,
		"autosave_mode":"invalid",
		"autosave_interval_days":999,
		"autosave_rolling_count":5
	})
	assert(float(settings.ui_scale) == 2.0)
	assert(float(settings.font_scale) == 0.9)
	assert(String(settings.autosave_mode) == "manual")
	assert(int(settings.autosave_interval_days) == 30)
	assert(int(settings.autosave_rolling_count) == 5)

	var localization = LocalizationServiceClass.new()
	assert(localization.language("xx") == "en")
	assert(localization.coverage("fr") >= 1.0)
	assert(localization.coverage("pt") >= 1.0)

	var registry = CareerScreenRegistryClass.new()
	var registry_result: Dictionary = registry.validate_registry()
	assert(bool(registry_result.get("ok", false)))
	assert(int(registry_result.get("tab_count", 0)) == 15)
	var tab_ids: Array = registry.tab_plan().map(func(row): return String(row.get("id", "")))
	assert("youth" in tab_ids)

	var performance: Dictionary = MatchdayProfilerClass.check(MatchdayProfilerClass.BASELINE.matchday_162_ms, "matchday_162_ms")
	assert(bool(performance.get("pass", false)))
	assert(absf(float(performance.get("ratio", 0.0)) - 1.0) < 0.001)

	var release = ReleaseGuardClass.new()
	var manifest: Dictionary = release.manifest()
	assert(String(manifest.get("engine", "")) == "4.7.2")
	assert(bool(manifest.get("offline_required", false)))
	assert(release.validate_release_files().is_empty())
	var offline: Dictionary = release.offline_contract()
	assert(not bool(offline.get("requires_network", true)))
	assert(not bool(offline.get("external_service_required", true)))

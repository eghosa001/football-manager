extends SceneTree

const LaunchWorldBuilder = preload("res://data/launch_world_builder.gd")
const WorldGenerator = preload("res://simulation/world/world_generator.gd")
const ModLoader = preload("res://tools/modding/mod_loader.gd")
const ModEditor = preload("res://tools/modding/mod_editor.gd")
const LineupAssignments = preload("res://application/career/lineup_assignment_service.gd")
const TacticsManager = preload("res://simulation/tactics/tactics_manager.gd")
const SimulationTierPolicy = preload("res://application/performance/simulation_tier_policy.gd")
const AggregateEngine = preload("res://simulation/match/background_aggregate_engine.gd")
const SettingsStore = preload("res://application/settings/settings_store.gd")
const SaveSlots = preload("res://application/career/save_slots.gd")

var checks := 0
var failures := 0

func _init() -> void:
	print("[TEST] Football Dynasty completion features")
	_test_mod_v3()
	_test_lineup_assignments()
	_test_simulation_tiers()
	_test_autosave_policy_and_save_package()
	_test_expanded_launch_scale()
	if failures == 0:
		print("[TEST] COMPLETION FEATURES PASS — %d checks" % checks)
		quit(0)
	else:
		push_error("[TEST] COMPLETION FEATURES FAIL — %d failures across %d checks" % [failures, checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TEST] " + message)

func _test_mod_v3() -> void:
	var world := WorldGenerator.new().create_world(71001, 1, 4, 20)
	var country_id := String(world.countries[0].id)
	var club_id := "custom-club"
	var player_id := "custom-player"
	var competition_id := "custom-league"
	var mod := {
		"metadata": {"id":"completion-mod","name":"Completion Mod","version":"1.0","author":"Tests","api_version":3},
		"patches": {},
		"additions": {
			"clubs": [{"id":club_id,"name":"Custom Club","country_id":country_id,"reputation":64}],
			"players": [{"id":player_id,"club_id":club_id,"first_name":"Ada","last_name":"Okafor","position":"ST","current_ability":61,"potential":78}],
			"competitions": [{"id":competition_id,"name":"Custom League","country_id":country_id,"competition_type":"league","club_ids":[String(world.clubs[0].id),String(world.clubs[1].id),String(world.clubs[2].id),club_id]}]
		},
		"graphics": {club_id:{"logo":"graphics/custom-club.png","kit_home":"graphics/custom-home.png"}},
		"names": {country_id:{"first_names":["Ada","Tayo"],"last_names":["Okafor","Mensah"]}}
	}
	var validation := ModLoader.new().validate_mod(mod)
	_expect(bool(validation.get("ok", false)), "Mod v3 additions/graphics/names must validate")
	var applied := ModLoader.new().apply_mod(world, mod)
	_expect(bool(applied.get("ok", false)), "Validated mod v3 package must apply")
	_expect(_has_id(world.clubs, club_id) and _has_id(world.players, player_id) and _has_id(world.competitions, competition_id), "Mod additions must enter the world")
	_expect(world.get("graphics_overrides", {}).has(club_id), "Graphic overrides must be retained in the world")
	_expect(world.get("name_pools", {}).has(country_id), "Country name pools must be retained in the world")
	var editor = ModEditor.new()
	var path := "user://completion_mod_v3.json"
	_expect(editor.export_mod(path, mod) == OK, "Mod editor must export v3 package")
	var imported := editor.import_mod(path)
	_expect(bool(imported.get("ok", false)) and imported.get("additions", {}).has("clubs") and imported.get("graphics", {}).has(club_id) and imported.get("names", {}).has(country_id), "Mod v3 sections must round-trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_lineup_assignments() -> void:
	var world: Dictionary = WorldGenerator.new().create_world(72001, 1, 4, 20)
	var club: Dictionary = world.clubs[0]
	var manager = TacticsManager.new()
	club["tactic"] = manager.create_tactic("4-3-3")
	var service = LineupAssignments.new()
	var slot_keys: Array = preload("res://application/career/tactics_actions.gd").new().slot_keys(club.tactic)
	var assigned_player: Dictionary = {}
	for player in world.players:
		if String(player.club_id) == String(club.id) and String(player.position) != "GK":
			assigned_player = player
			break
	_expect(not assigned_player.is_empty(), "Fixture world must contain an assignable player")
	var slot := String(slot_keys[1])
	_expect(service.assign_player(world, String(club.id), slot, String(assigned_player.id)) == OK, "Starter can be assigned to a tactical slot")
	_expect(service.set_instruction(world, String(club.id), slot, "shooting", "shoot_more") == OK, "Individual instruction can be stored")
	var lineup: Array = service.resolve(world.players, String(club.id), club.tactic)
	_expect(lineup.size() == 11, "Resolved assigned lineup must contain eleven starters")
	var found := false
	for player in lineup:
		if String(player.id) == String(assigned_player.id):
			found = true
			_expect(String(player.get("match_slot", "")) == slot, "Assigned player must resolve into requested slot")
			_expect(String(player.get("match_instruction", {}).get("shooting", "")) == "shoot_more", "Resolved starter must carry individual instruction")
	_expect(found, "Explicit assigned starter must be present in resolved lineup")

func _test_simulation_tiers() -> void:
	var world: Dictionary = WorldGenerator.new().create_world(73001, 2, 4, 20)
	var managed: Dictionary = world.clubs[0]
	var same_country_opponent: Dictionary = world.clubs[1]
	var distant: Dictionary = {}
	for club in world.clubs:
		if String(club.country_id) != String(managed.country_id):
			distant = club
			break
	var policy = SimulationTierPolicy.new()
	var managed_comp: Dictionary = _competition_for_club(world, String(managed.id))
	_expect(policy.tier_for_fixture(world, managed, same_country_opponent, String(managed.id), String(managed_comp.id)) == SimulationTierPolicy.USER_LEAGUE, "Managed fixture must use tier 1")
	var same_comp: Dictionary = _competition_for_club(world, String(same_country_opponent.id))
	var other_same: Dictionary = {}
	for candidate in world.clubs:
		if String(candidate.country_id) == String(same_country_opponent.country_id) and String(candidate.id) != String(same_country_opponent.id) and String(candidate.id) != String(managed.id):
			other_same = candidate
			break
	_expect(policy.tier_for_fixture(world, same_country_opponent, other_same, String(managed.id), String(same_comp.id)) == SimulationTierPolicy.DETAILED_LEAGUE, "Unmanaged fixture in managed country must use tier 2")
	var distant_comp: Dictionary = _competition_for_club(world, String(distant.id))
	var distant_other: Dictionary = _other_club(world, String(distant.country_id), String(distant.id))
	_expect(policy.tier_for_fixture(world, distant, distant_other, String(managed.id), String(distant_comp.id)) == SimulationTierPolicy.BACKGROUND_LEAGUE, "Distant active fixture must use tier 3")
	distant_comp["active"] = false
	_expect(policy.tier_for_fixture(world, distant, distant_other, String(managed.id), String(distant_comp.id)) == SimulationTierPolicy.INACTIVE_WORLD, "Inactive competition must use tier 4")
	var aggregate = AggregateEngine.new()
	var a := aggregate.simulate_match(distant, distant_other, [], 99001)
	var b := aggregate.simulate_match(distant, distant_other, [], 99001)
	_expect(a == b, "Aggregate tier must be deterministic for identical seeds")
	_expect(int(a.home_goals) >= 0 and int(a.away_goals) >= 0, "Aggregate tier must return legal non-negative score")

func _test_autosave_policy_and_save_package() -> void:
	var store = SettingsStore.new()
	for mode in SettingsStore.AUTOSAVE_MODES:
		var value := store.sanitize({"autosave":true,"autosave_mode":mode,"autosave_rolling_count":5})
		_expect(String(value.autosave_mode) == String(mode), "Autosave mode %s must sanitize without loss" % String(mode))
		_expect(int(value.autosave_rolling_count) == 5, "Rolling five policy must be retained")
	var disabled := store.sanitize({"autosave":false,"autosave_mode":"after_match"})
	_expect(String(disabled.autosave_mode) == "manual", "Disabled autosave must sanitize to manual mode")
	var slots = SaveSlots.new()
	var slot := 20
	slots.delete_slot(slot)
	var world := WorldGenerator.new().create_world(74001, 1, 4, 20)
	world["launch_database_schema"] = 1
	world["playtime_seconds"] = 123
	var manager := {"id":"human-manager","name":"Autosave Test","club_id":String(world.clubs[0].id)}
	_expect(slots.save_slot(slot, world, [], manager) == OK, "Manual save must write compatibility save and career package")
	_expect(FileAccess.file_exists(slots.slot_path(slot)), "Compatibility .fdn save must remain available")
	_expect(FileAccess.file_exists(slots.package_world_path(slot)), "Career package must contain world.db")
	_expect(FileAccess.file_exists(slots.package_metadata_path(slot)), "Career package must contain metadata.json")
	_expect(FileAccess.file_exists(slots.package_thumbnail_path(slot)), "Career package must contain thumbnail.png")
	var metadata_file := FileAccess.open(slots.package_metadata_path(slot), FileAccess.READ)
	var package_metadata = JSON.parse_string(metadata_file.get_as_text()) if metadata_file != null else {}
	if metadata_file != null:
		metadata_file.close()
	_expect(typeof(package_metadata) == TYPE_DICTIONARY and String(package_metadata.get("version", "")) == "1.0.0" and int(package_metadata.get("playtime", 0)) == 123, "Career package metadata must contain version and playtime")
	for generation in range(4):
		world["day_index"] = generation + 1
		world["date"] = "2026-07-%02d" % (generation + 2)
		_expect(slots.autosave_slot(slot, world, [], manager, 3) == OK, "Rolling autosave write %d must succeed" % generation)
	var rows := slots.list_autosaves(slot, 5)
	_expect(rows.size() == 3, "Rolling three policy must retain exactly three autosaves after four writes")
	_expect(String(rows[0].get("date", "")) == "2026-07-05", "Newest rolling autosave must be generation one")
	slots.delete_slot(slot)

func _test_expanded_launch_scale() -> void:
	var world := LaunchWorldBuilder.new().build(75001, 0, 28, true)
	_expect(world.countries.size() == 20, "Expanded launch world must ship twenty countries")
	_expect(world.clubs.size() >= 500 and world.clubs.size() <= 800, "Expanded launch world club count must stay inside v1 target")
	_expect(world.players.size() >= 20000 and world.players.size() <= 30000, "Expanded launch world player count must stay inside v1 target")
	_expect(world.staff.size() >= 3000, "Expanded launch world must include at least three thousand staff")
	_expect(world.competitions.size() >= 60 and world.competitions.size() <= 100, "Expanded launch world domestic competition count must stay inside v1 target")

func _has_id(values: Array, id: String) -> bool:
	for value in values:
		if String(value.get("id", "")) == id:
			return true
	return false

func _competition_for_club(world: Dictionary, club_id: String) -> Dictionary:
	for competition in world.competitions:
		if club_id in competition.get("club_ids", []):
			return competition
	return {}

func _other_club(world: Dictionary, country_id: String, excluded_id: String) -> Dictionary:
	for club in world.clubs:
		if String(club.country_id) == country_id and String(club.id) != excluded_id:
			return club
	return {}

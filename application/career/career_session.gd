class_name CareerSession
extends RefCounted

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const LaunchWorldBuilderClass = preload("res://data/launch_world_builder.gd")
const CareerCycleClass = preload("res://application/career/career_cycle_service.gd")
const SaveStoreClass = preload("res://persistence/save_store.gd")
const PlayerLifecycleClass = preload("res://simulation/players/player_lifecycle_service.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")
const ClubEconomyClass = preload("res://simulation/finance/club_economy.gd")
const StaffContractsClass = preload("res://simulation/staff/staff_contracts.gd")
const InternationalFootballClass = preload("res://simulation/competitions/international_football.gd")
const KnockoutSeasonClass = preload("res://application/season/knockout_season.gd")
const RegistrationServiceClass = preload("res://simulation/competitions/registration_service.gd")
const ModIntegrationClass = preload("res://application/career/mod_integration.gd")
const NamePoolServiceClass = preload("res://application/career/name_pool_service.gd")

var world: Dictionary = {}
var history: Array = []
var manager: Dictionary = {}
var managed_club_id := ""
var save_path := ""
var seed := 12345

func new_career(manager_name: String, club_id: String = "", world_seed: int = 12345, launch_countries: int = 0, mods: Array = [], expanded: bool = false) -> Dictionary:
	var candidate: Dictionary = LaunchWorldBuilderClass.new().build(world_seed, launch_countries, 28 if expanded else 25, expanded)
	if candidate.is_empty(): candidate = WorldGeneratorClass.new().create_world(world_seed)
	if not mods.is_empty():
		var applied: Dictionary = preload("res://tools/modding/mod_loader.gd").new().apply_mods(candidate, mods)
		if not bool(applied.ok): return {"error":ERR_INVALID_DATA,"message":String(applied.error)}
		NamePoolServiceClass.new().apply_mod_names(candidate, mods)
		ModIntegrationClass.new().finalize(candidate)
	save_path = ""
	seed = world_seed
	world = candidate
	_initialize_world(true)
	if world.get("clubs", []).is_empty(): return {}
	managed_club_id = club_id if club_id != "" and _club_exists(club_id) else String(world.clubs[0].id)
	manager = {"id":"human-manager","name":manager_name.strip_edges() if manager_name.strip_edges() != "" else "Manager","club_id":managed_club_id,"reputation":35,"created_year":int(world.get("season_year",2026)),"career_history":[]}
	world["human_manager"] = manager.duplicate(true)
	world["day_index"] = int(world.get("day_index",0))
	history = []
	return snapshot()

func load_career(path: String) -> Error:
	var payload: Dictionary = SaveStoreClass.new().load_save(path)
	if payload.is_empty(): return ERR_FILE_CORRUPT
	var candidate: Dictionary = payload.world
	for field in ["clubs", "players", "staff", "competitions", "contracts", "fixtures"]:
		if not candidate.get(field) is Array: return ERR_FILE_CORRUPT
		for item in candidate[field]:
			if not item is Dictionary: return ERR_FILE_CORRUPT
	if not candidate.get("human_manager") is Dictionary: return ERR_FILE_CORRUPT
	var club_found := false
	for club in candidate.clubs:
		if String(club.get("id", "")) == String(candidate.human_manager.get("club_id", "")): club_found = true
	if not club_found: return ERR_FILE_CORRUPT
	world = payload.world; history = payload.get("history", []); manager = world.get("human_manager", {})
	managed_club_id = String(manager.get("club_id", "")); seed = int(world.get("seed", seed)); save_path = path
	_initialize_world(false)
	return OK

func save_career(path: String = "") -> Error:
	var target := path if path != "" else save_path
	if target == "": return ERR_INVALID_PARAMETER
	save_path = target; world["human_manager"] = manager.duplicate(true); world["seed"] = seed
	return SaveStoreClass.new().save_atomic(target, world, history)

func continue_season() -> Dictionary:
	if world.is_empty(): return {}
	var result: Dictionary = CareerCycleClass.new().complete_year(world, history, seed + int(world.get("season_year",2026)) * 97, 1)
	manager = world.get("human_manager", manager)
	return result

func choose_club(club_id: String) -> Error:
	if not _club_exists(club_id): return ERR_DOES_NOT_EXIST
	var previous := managed_club_id; managed_club_id = club_id; manager["club_id"] = club_id
	if not manager.has("career_history"): manager["career_history"] = []
	manager.career_history.append({"season_year":int(world.get("season_year",2026)),"date":String(world.get("date","")),"from_club_id":previous,"to_club_id":club_id})
	world["human_manager"] = manager.duplicate(true)
	return OK

func snapshot() -> Dictionary:
	return {"manager":manager.duplicate(true),"club_id":managed_club_id,"season_year":int(world.get("season_year",2026)),"date":String(world.get("date","")),"history_count":history.size(),"seed":seed,"day_index":int(world.get("day_index",0)),"database_schema":int(world.get("launch_database_schema",0))}

func _initialize_world(is_new: bool) -> void:
	var lifecycle = PlayerLifecycleClass.new()
	var attributes = preload("res://simulation/players/player_attributes.gd").new()
	for player in world.get("players", []):
		lifecycle.ensure_player_state(player, seed)
		attributes.ensure(player, seed)
	TacticsManagerClass.new().ensure_world(world, seed)
	ClubEconomyClass.new().ensure_world(world)
	StaffContractsClass.new().ensure_world(world)
	InternationalFootballClass.new().ensure_world(world)
	_ensure_match_factor_fields()
	var season_year := int(world.get("season_year", 2026))
	if is_new:
		preload("res://application/season/continental_competitions.gd").new().prepare(world)
		KnockoutSeasonClass.new().initialize_all(world, season_year)
	else:
		for competition in world.get("competitions", []):
			if String(competition.get("competition_type", "league")) == "knockout" and not competition.has("knockout_bracket"):
				KnockoutSeasonClass.new().initialize_competition(world, competition, season_year)
		# Refresh continental tiers + Club World Cup entrants on load so old
		# saves gain the three-tier structure without a new career.
		preload("res://application/season/continental_competitions.gd").new().prepare(world)
	var registration = RegistrationServiceClass.new()
	registration.ensure_world(world)
	if is_new or world.get("registrations", {}).is_empty(): registration.auto_register_world(world, season_year)
	world["seed"] = seed

func _ensure_match_factor_fields() -> void:
	var manager_ability := {}
	for staff_member in world.get("staff", []):
		if String(staff_member.get("role", "")) == "manager":
			manager_ability[String(staff_member.get("club_id", ""))] = int(staff_member.get("ability", 50))
	for club in world.get("clubs", []):
		if not club.has("recent_results") or not club.get("recent_results") is Array:
			club["recent_results"] = []
		if not club.has("form_points"):
			club["form_points"] = 7.5
		if not club.has("manager_ability"):
			club["manager_ability"] = int(manager_ability.get(String(club.get("id", "")), 50))
		if not club.has("injured_count"):
			club["injured_count"] = 0
	if not world.has("default_country_id") or String(world.get("default_country_id", "")) == "":
		world["default_country_id"] = "eng"
	if not world.has("featured_country_ids") or not world.get("featured_country_ids") is Array:
		world["featured_country_ids"] = ["eng", "esp"]

func _club_exists(club_id: String) -> bool:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return true
	return false

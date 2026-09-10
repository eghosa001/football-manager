class_name CareerSession
extends RefCounted

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const CareerCycleClass = preload("res://application/career/career_cycle.gd")
const SaveStoreClass = preload("res://persistence/save_store.gd")
const PlayerLifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")
const ClubEconomyClass = preload("res://simulation/finance/club_economy.gd")
const StaffContractsClass = preload("res://simulation/staff/staff_contracts.gd")

var world: Dictionary = {}
var history: Array = []
var manager: Dictionary = {}
var managed_club_id := ""
var save_path := ""
var seed := 12345

func new_career(manager_name: String, club_id: String = "", world_seed: int = 12345) -> Dictionary:
	seed = world_seed
	world = WorldGeneratorClass.new().create_world(seed)
	_initialize_world()
	managed_club_id = club_id if club_id != "" and _club_exists(club_id) else String(world.clubs[0].id)
	manager = {"id":"human-manager","name":manager_name.strip_edges() if manager_name.strip_edges() != "" else "Manager","club_id":managed_club_id,"reputation":35,"created_year":int(world.get("season_year",2026)),"career_history":[]}
	world["human_manager"] = manager.duplicate(true)
	world["day_index"] = int(world.get("day_index", 0))
	history = []
	return snapshot()

func load_career(path: String) -> Error:
	var payload: Dictionary = SaveStoreClass.new().load_save(path)
	if payload.is_empty(): return ERR_FILE_CORRUPT
	world = payload.world
	history = payload.get("history", [])
	manager = world.get("human_manager", {})
	managed_club_id = String(manager.get("club_id", ""))
	seed = int(world.get("seed", seed))
	save_path = path
	_initialize_loaded_world()
	return OK

func save_career(path: String = "") -> Error:
	var target := path if path != "" else save_path
	if target == "": return ERR_INVALID_PARAMETER
	save_path = target
	world["human_manager"] = manager.duplicate(true)
	world["seed"] = seed
	return SaveStoreClass.new().save_atomic(target, world, history)

func continue_season() -> Dictionary:
	if world.is_empty(): return {}
	var season_year: int = int(world.get("season_year", 2026))
	var result: Dictionary = CareerCycleClass.new().complete_year(world, history, seed + season_year * 97, 1)
	manager = world.get("human_manager", manager)
	return result

func choose_club(club_id: String) -> Error:
	if not _club_exists(club_id): return ERR_DOES_NOT_EXIST
	var previous := managed_club_id
	managed_club_id = club_id
	manager["club_id"] = club_id
	if not manager.has("career_history"): manager["career_history"] = []
	manager.career_history.append({"season_year":int(world.get("season_year",2026)),"date":String(world.get("date","")),"from_club_id":previous,"to_club_id":club_id})
	world["human_manager"] = manager.duplicate(true)
	return OK

func snapshot() -> Dictionary:
	return {"manager":manager.duplicate(true),"club_id":managed_club_id,"season_year":int(world.get("season_year",2026)),"date":String(world.get("date","")),"history_count":history.size(),"seed":seed,"day_index":int(world.get("day_index",0))}

func _initialize_world() -> void:
	var lifecycle = PlayerLifecycleClass.new()
	for player in world.get("players", []): lifecycle.ensure_player_state(player, seed)
	TacticsManagerClass.new().ensure_world(world, seed)
	ClubEconomyClass.new().ensure_world(world)
	StaffContractsClass.new().ensure_world(world)
	world["seed"] = seed

func _initialize_loaded_world() -> void:
	var lifecycle = PlayerLifecycleClass.new()
	for player in world.get("players", []): lifecycle.ensure_player_state(player, seed)
	TacticsManagerClass.new().ensure_world(world, seed)
	ClubEconomyClass.new().ensure_world(world)
	StaffContractsClass.new().ensure_world(world)

func _club_exists(club_id: String) -> bool:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return true
	return false

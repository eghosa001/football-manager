class_name CareerSession
extends RefCounted

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const CareerCycleClass = preload("res://application/career/career_cycle.gd")
const SaveStoreClass = preload("res://persistence/save_store.gd")

var world: Dictionary = {}
var history: Array = []
var manager: Dictionary = {}
var managed_club_id := ""
var save_path := ""
var seed := 12345

func new_career(manager_name: String, club_id: String = "", world_seed: int = 12345) -> Dictionary:
	seed = world_seed
	world = WorldGeneratorClass.new().create_world(seed)
	managed_club_id = club_id if club_id != "" else String(world.clubs[0].id)
	manager = {"id": "human-manager", "name": manager_name.strip_edges(), "club_id": managed_club_id, "reputation": 35, "created_year": int(world.get("season_year", 2026))}
	world["human_manager"] = manager.duplicate(true)
	history = []
	return snapshot()

func load_career(path: String) -> Error:
	var payload: Dictionary = SaveStoreClass.new().load_save(path)
	if payload.is_empty():
		return ERR_FILE_CORRUPT
	world = payload.world
	history = payload.get("history", [])
	manager = world.get("human_manager", {})
	managed_club_id = String(manager.get("club_id", ""))
	save_path = path
	return OK

func save_career(path: String = "") -> Error:
	var target := path if path != "" else save_path
	if target == "":
		return ERR_INVALID_PARAMETER
	save_path = target
	world["human_manager"] = manager.duplicate(true)
	return SaveStoreClass.new().save_atomic(target, world, history)

func continue_season() -> Dictionary:
	if world.is_empty():
		return {}
	var season_year: int = int(world.get("season_year", 2026))
	var result: Dictionary = CareerCycleClass.new().complete_year(world, history, seed + season_year * 97, 1)
	manager = world.get("human_manager", manager)
	return result

func choose_club(club_id: String) -> Error:
	if not _club_exists(club_id):
		return ERR_DOES_NOT_EXIST
	managed_club_id = club_id
	manager["club_id"] = club_id
	world["human_manager"] = manager.duplicate(true)
	return OK

func snapshot() -> Dictionary:
	return {"manager": manager.duplicate(true), "club_id": managed_club_id, "season_year": int(world.get("season_year", 2026)), "date": String(world.get("date", "")), "history_count": history.size()}

func _club_exists(club_id: String) -> bool:
	for club in world.get("clubs", []):
		if String(club.id) == club_id:
			return true
	return false

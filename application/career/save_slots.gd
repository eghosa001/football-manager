class_name SaveSlots
extends RefCounted

const SaveStoreClass = preload("res://persistence/save_store.gd")

func first_available_slot(max_slots: int = 10) -> int:
	for slot in range(1, max_slots + 1):
		var path := slot_path(slot)
		if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
			return slot
	return 0

func slot_path(slot: int) -> String:
	return "user://saves/career_%02d.fdn" % clampi(slot, 1, 20)

func save_slot(slot: int, world: Dictionary, history: Array, manager: Dictionary) -> Error:
	var directory := DirAccess.open("user://")
	if directory != null and not directory.dir_exists("saves"):
		directory.make_dir("saves")
	world["human_manager"] = manager.duplicate(true)
	return SaveStoreClass.new().save_atomic(slot_path(slot), world, history)

func load_slot(slot: int) -> Dictionary:
	return SaveStoreClass.new().load_save(slot_path(slot))

func metadata(slot: int) -> Dictionary:
	var payload: Dictionary = load_slot(slot)
	if payload.is_empty():
		return {"slot":slot,"exists":false}
	var world: Dictionary = payload.world
	var manager: Dictionary = world.get("human_manager", {})
	var club_name := ""
	var club_id := String(manager.get("club_id", ""))
	for club in world.get("clubs", []):
		if String(club.id) == club_id:
			club_name = String(club.name)
			break
	return {"slot":slot,"exists":true,"manager":String(manager.get("name", "Manager")),"club":club_name,"season_year":int(world.get("season_year", 0)),"date":String(world.get("date", "")),"history_count":payload.get("history", []).size()}

func list_slots(max_slots: int = 10) -> Array:
	var result: Array = []
	for slot in range(1, max_slots + 1):
		result.append(metadata(slot))
	return result

func delete_slot(slot: int) -> Error:
	var path := slot_path(slot)
	var absolute := ProjectSettings.globalize_path(path)
	var backup := ProjectSettings.globalize_path(path + ".bak")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(backup)
	return OK

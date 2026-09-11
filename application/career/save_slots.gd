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

func autosave_path(slot: int, generation: int) -> String:
	return "user://saves/career_%02d.autosave_%d.fdn" % [clampi(slot, 1, 20), maxi(1, generation)]

func save_slot(slot: int, world: Dictionary, history: Array, manager: Dictionary) -> Error:
	_ensure_directory()
	world["human_manager"] = manager.duplicate(true)
	return SaveStoreClass.new().save_atomic(slot_path(slot), world, history)

func autosave_slot(slot: int, world: Dictionary, history: Array, manager: Dictionary, rolling_count: int = 3) -> Error:
	_ensure_directory()
	var count := 5 if rolling_count >= 5 else 3
	# Rotate oldest first. SaveStore still performs atomic temp/backup handling
	# inside each destination, while this preserves multiple independent points.
	for generation in range(count, 1, -1):
		var older := autosave_path(slot, generation - 1)
		var newer := autosave_path(slot, generation)
		if FileAccess.file_exists(newer):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(newer))
		if FileAccess.file_exists(newer + ".bak"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(newer + ".bak"))
		if FileAccess.file_exists(older):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(older), ProjectSettings.globalize_path(newer))
		if FileAccess.file_exists(older + ".bak"):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(older + ".bak"), ProjectSettings.globalize_path(newer + ".bak"))
	var snapshot_world := world.duplicate(true)
	snapshot_world["human_manager"] = manager.duplicate(true)
	return SaveStoreClass.new().save_atomic(autosave_path(slot, 1), snapshot_world, history)

func list_autosaves(slot: int, max_count: int = 5) -> Array:
	var rows: Array = []
	for generation in range(1, clampi(max_count, 1, 5) + 1):
		var path := autosave_path(slot, generation)
		if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
			continue
		var payload := SaveStoreClass.new().load_save(path)
		if payload.is_empty():
			rows.append({"generation":generation,"path":path,"corrupt":true})
			continue
		var world: Dictionary = payload.get("world", {})
		rows.append({"generation":generation,"path":path,"corrupt":false,"date":String(world.get("date","")),"season_year":int(world.get("season_year",0))})
	return rows

func load_slot(slot: int) -> Dictionary:
	return SaveStoreClass.new().load_save(slot_path(slot))

func metadata(slot: int) -> Dictionary:
	var payload: Dictionary = load_slot(slot)
	if payload.is_empty():
		var exists := FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")
		return {"slot":slot,"exists":exists,"corrupt":exists,"manager":"Unreadable save","club":"","date":""}
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
		var err := DirAccess.remove_absolute(absolute)
		if err != OK:
			return err
	if FileAccess.file_exists(path + ".bak"):
		var err := DirAccess.remove_absolute(backup)
		if err != OK:
			return err
	for generation in range(1, 6):
		for candidate in [autosave_path(slot, generation), autosave_path(slot, generation) + ".bak"]:
			if FileAccess.file_exists(candidate):
				var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
				if err != OK:
					return err
	return OK

func _ensure_directory() -> void:
	var directory := DirAccess.open("user://")
	if directory != null and not directory.dir_exists("saves"):
		directory.make_dir("saves")

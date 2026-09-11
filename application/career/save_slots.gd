class_name SaveSlots
extends RefCounted

const SaveStoreClass = preload("res://persistence/save_store.gd")
const PACKAGE_VERSION := "1.0.0"

var _root_path: String = "user://saves"

func _init(root_path: String = "user://saves") -> void:
	_root_path = root_path.trim_suffix("/")

func first_available_slot(max_slots: int = 10) -> int:
	for slot in range(1, max_slots + 1):
		var path := slot_path(slot)
		if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(package_world_path(slot)):
			return slot
	return 0

func slot_path(slot: int) -> String:
	return _root_path + "/career_%02d.fdn" % clampi(slot, 1, 20)

func package_path(slot: int) -> String:
	return _root_path + "/career_%02d" % clampi(slot, 1, 20)

func package_world_path(slot: int) -> String:
	return package_path(slot) + "/world.db"

func package_metadata_path(slot: int) -> String:
	return package_path(slot) + "/metadata.json"

func package_thumbnail_path(slot: int) -> String:
	return package_path(slot) + "/thumbnail.png"

func autosave_path(slot: int, generation: int) -> String:
	return _root_path + "/career_%02d.autosave_%d.fdn" % [clampi(slot, 1, 20), maxi(1, generation)]

func save_slot(slot: int, world: Dictionary, history: Array, manager: Dictionary) -> Error:
	_ensure_directory()
	var snapshot_world := world.duplicate(true)
	snapshot_world["human_manager"] = manager.duplicate(true)
	var error := SaveStoreClass.new().save_atomic(slot_path(slot), snapshot_world, history)
	if error != OK:
		return error
	var package_error := _write_package(slot, snapshot_world, history, manager)
	return package_error if package_error != OK else OK

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
	var payload := SaveStoreClass.new().load_save(slot_path(slot))
	if not payload.is_empty():
		return payload
	# Career packages are a second, explicit recovery surface. Keeping the
	# compatibility .fdn primary means existing installs can upgrade safely.
	return SaveStoreClass.new().load_save(package_world_path(slot))

func metadata(slot: int) -> Dictionary:
	var payload: Dictionary = load_slot(slot)
	if payload.is_empty():
		var exists := FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak") or FileAccess.file_exists(package_world_path(slot))
		return {"slot":slot,"exists":exists,"corrupt":exists,"manager":"Unreadable save","club":"","date":""}
	var world: Dictionary = payload.world
	var manager: Dictionary = world.get("human_manager", {})
	var club_name := ""
	var club_id := String(manager.get("club_id", ""))
	for club in world.get("clubs", []):
		if String(club.id) == club_id:
			club_name = String(club.name)
			break
	return {"slot":slot,"exists":true,"manager":String(manager.get("name", "Manager")),"club":club_name,"season_year":int(world.get("season_year", 0)),"date":String(world.get("date", "")),"history_count":payload.get("history", []).size(),"package":FileAccess.file_exists(package_metadata_path(slot))}

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
	var package_files := [package_world_path(slot), package_world_path(slot) + ".bak", package_metadata_path(slot), package_thumbnail_path(slot)]
	for candidate in package_files:
		if FileAccess.file_exists(candidate):
			var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
			if err != OK:
				return err
	var package_global := ProjectSettings.globalize_path(package_path(slot))
	if DirAccess.dir_exists_absolute(package_global):
		var err := DirAccess.remove_absolute(package_global)
		if err != OK:
			return err
	return OK

func _write_package(slot: int, world: Dictionary, history: Array, manager: Dictionary) -> Error:
	var directory := package_path(slot)
	var directory_global := ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(directory_global):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(directory_global)
		if mkdir_error != OK:
			return mkdir_error
	var world_error := SaveStoreClass.new().save_atomic(package_world_path(slot), world, history)
	if world_error != OK:
		return world_error
	var club_name := ""
	var club_id := String(manager.get("club_id", ""))
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			club_name = String(club.get("name", ""))
			break
	var metadata := {
		"version": PACKAGE_VERSION,
		"manager": String(manager.get("name", "Manager")),
		"club": club_name,
		"club_id": club_id,
		"date": String(world.get("date", "")),
		"playtime": int(world.get("playtime_seconds", 0)),
		"database_version": int(world.get("launch_database_schema", 0)),
		"save_schema_version": SaveStoreClass.CURRENT_SCHEMA_VERSION,
		"season_year": int(world.get("season_year", 0)),
	}
	var file := FileAccess.open(package_metadata_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(metadata, "\t"))
	file.flush()
	file.close()
	return _write_thumbnail(slot, club_id)

func _write_thumbnail(slot: int, club_id: String) -> Error:
	var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	var seed := _stable_key(club_id)
	var primary := Color(0.08 + float(seed % 60) / 300.0, 0.14 + float((seed / 7) % 90) / 300.0, 0.28 + float((seed / 19) % 100) / 300.0, 1.0)
	image.fill(primary)
	# A deterministic simple band gives each club package a recognizable visual
	# thumbnail without depending on external or licensed graphic assets.
	var accent := Color(minf(1.0, primary.r + 0.32), minf(1.0, primary.g + 0.28), minf(1.0, primary.b + 0.22), 1.0)
	for y in range(70, 110):
		for x in range(320):
			image.set_pixel(x, y, accent)
	return image.save_png(package_thumbnail_path(slot))

func _stable_key(text: String) -> int:
	var value := 97
	for character in text.to_utf8_buffer():
		value = posmod(value * 181 + int(character), 2_147_483_647)
	return value

func _ensure_directory() -> void:
	var global_root := ProjectSettings.globalize_path(_root_path)
	if not DirAccess.dir_exists_absolute(global_root):
		DirAccess.make_dir_recursive_absolute(global_root)

class_name SaveFuzzer
extends RefCounted

const SaveStoreClass = preload("res://persistence/save_store.gd")

func round_trip(path: String, world: Dictionary, history: Array) -> Dictionary:
	var store = SaveStoreClass.new()
	var err := store.save_atomic(path, world, history)
	if err != OK:
		return {"ok":false,"error":err}
	var loaded: Dictionary = store.load_save(path)
	return {"ok":not loaded.is_empty(),"same_world":var_to_bytes(loaded.get("world", {})) == var_to_bytes(world),"same_history":var_to_bytes(loaded.get("history", [])) == var_to_bytes(history)}

func corrupt_and_recover(path: String) -> Dictionary:
	var backup := path + ".bak"
	if not FileAccess.file_exists(path):
		return {"ok":false,"reason":"missing_primary"}
	if not FileAccess.file_exists(backup):
		var copy_err := DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
		if copy_err != OK: return {"ok":false,"reason":"backup_failed","error":copy_err}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"ok":false,"reason":"open_failed"}
	file.store_string("corrupt")
	file.close()
	var recovered: Dictionary = SaveStoreClass.new().load_save(path)
	return {"ok":not recovered.is_empty(),"used_backup":not recovered.is_empty()}

func malformed_payloads() -> Array[PackedByteArray]:
	return [PackedByteArray(), "garbage".to_utf8_buffer(), PackedByteArray([1,2,3,4,5,6,7]), PackedByteArray([70,68,78,49,255,255,255,255])]

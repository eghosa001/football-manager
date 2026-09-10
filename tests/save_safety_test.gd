extends SceneTree

const Store = preload("res://persistence/save_store.gd")
const Slots = preload("res://application/career/save_slots.gd")

func _init() -> void:
	var store = Store.new()
	assert(store._migrate({"schema_version":2,"history":[]}).is_empty())
	assert(store._migrate({"schema_version":1,"world":"broken"}).is_empty())
	assert(store._migrate({"schema_version":2,"world":{},"history":42}).is_empty())
	assert(store._migrate({"schema_version":"bad","world":{}}).is_empty())
	var slots = Slots.new()
	assert(slots.first_available_slot() == 1)
	assert(slots.save_slot(1, {"clubs":[]}, [], {"name":"Existing manager"}) == OK)
	assert(slots.first_available_slot() == 2)
	# An unreadable primary still occupies its slot and must never be overwritten implicitly.
	var file := FileAccess.open(slots.slot_path(2), FileAccess.WRITE)
	file.store_string("damaged save"); file.close()
	assert(slots.first_available_slot(2) == 0)
	assert(slots.first_available_slot() == 3)
	# Backup-only saves are also reserved and recoverable.
	assert(DirAccess.rename_absolute(ProjectSettings.globalize_path(slots.slot_path(1)), ProjectSettings.globalize_path(slots.slot_path(1) + ".bak")) == OK)
	assert(slots.first_available_slot() == 3)
	assert(slots.load_slot(1).world.human_manager.name == "Existing manager")
	file = FileAccess.open(slots.slot_path(1), FileAccess.WRITE)
	file.store_string("corrupt primary"); file.close()
	assert(slots.save_slot(1, {"clubs":[]}, [], {"name":"Recovered manager"}) == OK)
	assert(store._load_path(slots.slot_path(1) + ".bak").world.human_manager.name == "Existing manager")
	assert(slots.load_slot(1).world.human_manager.name == "Recovered manager")
	print("[TEST] SAVE SAFETY PASS")
	quit(0)

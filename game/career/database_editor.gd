extends RefCounted

const Editor = preload("res://tools/modding/mod_editor.gd")
const Catalog = preload("res://data/launch_catalog.gd")

const COLLECTIONS := ["clubs", "countries", "players"]

var app: Control
var mod: Dictionary
var database: Dictionary
var collection_selector: OptionButton
var entity_selector: OptionButton
var fields_box: VBoxContainer
var notice: Label
var editors := {}

func _init(owner_app: Control, current: Dictionary = {}) -> void:
	app = owner_app
	mod = current.duplicate(true) if not current.is_empty() else Editor.new().create_mod("custom-database", "Custom database")
	database = Catalog.new().build(0, bool(app.get("expanded_world")))

func show() -> void:
	var box: VBoxContainer = app.call("_clear")
	app.call("_add_heading", box, tr("Database editor"), 28)
	var intro := Label.new()
	intro.text = tr("Create safe database overrides for clubs, countries and players. Changes apply only to new careers.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	collection_selector = OptionButton.new()
	for collection in COLLECTIONS:
		collection_selector.add_item(tr(String(collection).capitalize()))
	box.add_child(app.call("_labeled", tr("Entity type"), collection_selector))
	entity_selector = OptionButton.new()
	box.add_child(app.call("_labeled", tr("Entity"), entity_selector))
	fields_box = VBoxContainer.new()
	fields_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(fields_box)
	collection_selector.item_selected.connect(func(_index): _rebuild_entities())
	entity_selector.item_selected.connect(func(_index): _render_fields())
	notice = Label.new(); notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(notice)
	app.call("_add_button", box, tr("Add or update change"), _save_change)
	app.call("_add_button", box, tr("Remove change for selected entity"), _remove_change)
	app.call("_add_button", box, tr("Import database mod"), _file_dialog.bind(false))
	app.call("_add_button", box, tr("Export database mod"), _file_dialog.bind(true))
	app.call("_add_button", box, tr("Use for new careers"), func():
		var validation := Editor.new().validate_project(mod)
		if not bool(validation.get("ok", false)):
			notice.text = tr("Database validation failed: %s") % String(validation.get("error", "invalid")); return
		app.set("custom_database", mod.duplicate(true))
		app.call("_show_main_menu")
	)
	app.call("_add_button", box, tr("Back"), app.call.bind("_show_main_menu"))
	_rebuild_entities()
	_update_notice()

func _collection() -> String:
	return COLLECTIONS[clampi(collection_selector.selected, 0, COLLECTIONS.size() - 1)]

func _entities() -> Array:
	return database.get(_collection(), [])

func _rebuild_entities() -> void:
	entity_selector.clear()
	for entity in _entities():
		entity_selector.add_item(_display_name(entity))
	if entity_selector.item_count > 0:
		entity_selector.select(0)
	_render_fields()

func _render_fields() -> void:
	for child in fields_box.get_children(): child.queue_free()
	editors.clear()
	var entities := _entities()
	if entities.is_empty(): return
	var entity: Dictionary = entities[clampi(entity_selector.selected, 0, entities.size()-1)]
	var patch := _patch_for(_collection(), String(entity.get("id", "")))
	match _collection():
		"clubs":
			_add_text_field("name", tr("Club name"), String(patch.get("name", entity.get("name", ""))))
			_add_number_field("reputation", tr("Reputation"), int(patch.get("reputation", entity.get("reputation", 50))), 1, 100)
			_add_number_field("ticket_price", tr("Ticket price"), int(patch.get("ticket_price", entity.get("ticket_price", 20))), 1, 1000)
			_add_number_field("training_facilities", tr("Training facilities"), int(patch.get("training_facilities", entity.get("training_facilities", 50))), 1, 100)
		"countries":
			_add_text_field("name", tr("Country name"), String(patch.get("name", entity.get("name", ""))))
			_add_text_field("code", tr("Country code"), String(patch.get("code", entity.get("code", ""))))
			_add_number_field("youth_rating", tr("Youth rating"), int(patch.get("youth_rating", entity.get("youth_rating", 50))), 1, 100)
		"players":
			_add_text_field("first_name", tr("First name"), String(patch.get("first_name", entity.get("first_name", ""))))
			_add_text_field("last_name", tr("Last name"), String(patch.get("last_name", entity.get("last_name", ""))))
			_add_number_field("current_ability", tr("Current ability"), int(patch.get("current_ability", entity.get("current_ability", 50))), 1, 100)
			_add_number_field("potential", tr("Potential"), int(patch.get("potential", entity.get("potential", 50))), 1, 100)
			_add_text_field("position", tr("Position"), String(patch.get("position", entity.get("position", "MC"))))

func _add_text_field(key: String, label: String, value: String) -> void:
	var input := LineEdit.new()
	input.text = value
	input.custom_minimum_size.y = app.call("_touch_height")
	fields_box.add_child(app.call("_labeled", label, input))
	editors[key] = input

func _add_number_field(key: String, label: String, value: int, minimum: int, maximum: int) -> void:
	var input := SpinBox.new()
	input.min_value = minimum; input.max_value = maximum; input.step = 1; input.value = value
	input.custom_minimum_size.y = app.call("_touch_height")
	fields_box.add_child(app.call("_labeled", label, input))
	editors[key] = input

func _save_change() -> void:
	var entities := _entities()
	if entities.is_empty(): return
	var entity: Dictionary = entities[clampi(entity_selector.selected, 0, entities.size()-1)]
	var id := String(entity.get("id", ""))
	var values := {}
	for key in editors.keys():
		var control = editors[key]
		if control is LineEdit:
			var text := String(control.text).strip_edges()
			if text.is_empty():
				notice.text = tr("Text fields cannot be empty."); return
			values[key] = text
		elif control is SpinBox:
			values[key] = int(control.value)
	var editor = Editor.new()
	var removed: Dictionary = editor.remove_patch(mod, _collection(), id)
	var result: Dictionary = editor.add_patch(removed.mod, _collection(), id, values)
	if not bool(result.get("ok", false)):
		notice.text = tr("Change rejected: %s") % String(result.get("error", "invalid")); return
	mod = result.mod
	_update_notice()

func _remove_change() -> void:
	var entities := _entities()
	if entities.is_empty(): return
	var id := String(entities[clampi(entity_selector.selected,0,entities.size()-1)].get("id", ""))
	mod = Editor.new().remove_patch(mod, _collection(), id).mod
	_render_fields()
	_update_notice()

func _patch_for(collection: String, id: String) -> Dictionary:
	for patch in mod.get("patches", {}).get(collection, []):
		if String(patch.get("id", "")) == id: return patch
	return {}

func _display_name(entity: Dictionary) -> String:
	if _collection() == "players":
		return (String(entity.get("first_name", "")) + " " + String(entity.get("last_name", ""))).strip_edges()
	return String(entity.get("name", entity.get("id", "Entity")))

func _update_notice() -> void:
	var count := 0
	for rows in mod.get("patches", {}).values(): count += rows.size()
	notice.text = tr("%d database changes. Changes apply only to newly created careers.") % count

func _file_dialog(saving: bool) -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; Football Dynasty database mod"])
	dialog.current_file = "custom-database.json" if saving else ""
	app.add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		if saving:
			var err: Error = Editor.new().export_mod(path, mod)
			notice.text = tr("Database exported.") if err == OK else tr("Database export failed.")
		else:
			var imported: Dictionary = Editor.new().import_mod(path)
			if bool(imported.get("ok", false)) and _editable(imported):
				mod = {"metadata":imported.metadata,"patches":imported.patches}
				_render_fields(); _update_notice()
			else:
				notice.text = tr("This file is not a compatible editable database mod.")
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.85 if DisplayServer.is_touchscreen_available() else 0.75)

func _editable(data: Dictionary) -> bool:
	var allowed := {"clubs":true,"countries":true,"players":true}
	var valid_ids := {}
	for collection in COLLECTIONS:
		valid_ids[collection] = {}
		for entity in database.get(collection, []): valid_ids[collection][String(entity.get("id", ""))] = true
	for collection in data.patches:
		if not allowed.has(String(collection)): return false
		for patch in data.patches[collection]:
			if not valid_ids[String(collection)].has(String(patch.id)): return false
	return true

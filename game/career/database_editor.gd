extends RefCounted

const Editor = preload("res://tools/modding/mod_editor.gd")
const Loader = preload("res://tools/modding/mod_loader.gd")
const Catalog = preload("res://data/launch_catalog.gd")
const LaunchWorldBuilder = preload("res://data/launch_world_builder.gd")

var app: Control
var mod: Dictionary
var collection_selector: OptionButton
var entity_selector: OptionButton
var field_selector: OptionButton
var value_input: LineEdit
var notice: Label
var _catalog: Dictionary = {}
var _full_world: Dictionary = {}
var _collections := ["clubs", "countries", "players", "staff", "competitions"]

func _init(owner_app: Control, current: Dictionary = {}) -> void:
	app = owner_app
	mod = current.duplicate(true) if not current.is_empty() else Editor.new().create_mod("custom-database", "Custom database")
	_catalog = Catalog.new().build(0, bool(app.get("expanded_world")))

func show() -> void:
	var box: VBoxContainer = app.call("_clear")
	app.call("_add_heading", box, tr("Database & mod editor"), 28)
	var intro := Label.new()
	intro.text = tr("Edit supported clubs, countries, players, staff and competition rules. Every change is validated and applies only to newly created careers.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)

	collection_selector = OptionButton.new()
	for collection in _collections: collection_selector.add_item(collection.capitalize())
	box.add_child(app.call("_labeled", tr("Collection"), collection_selector))

	entity_selector = OptionButton.new()
	box.add_child(app.call("_labeled", tr("Entity"), entity_selector))
	field_selector = OptionButton.new()
	box.add_child(app.call("_labeled", tr("Field"), field_selector))
	value_input = LineEdit.new()
	value_input.placeholder_text = tr("Value; JSON is accepted for arrays and dictionaries")
	box.add_child(app.call("_labeled", tr("Value"), value_input))

	collection_selector.item_selected.connect(_select_collection)
	entity_selector.item_selected.connect(_select_entity)
	field_selector.item_selected.connect(_select_field)

	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(notice)

	var actions := HBoxContainer.new(); box.add_child(actions)
	app.call("_add_button", actions, tr("Apply field change"), _apply_change)
	app.call("_add_button", actions, tr("Remove entity patch"), _remove_patch)
	app.call("_add_button", actions, tr("Validate mod"), _validate)

	var files := HBoxContainer.new(); box.add_child(files)
	app.call("_add_button", files, tr("Import database/mod"), _file_dialog.bind(false))
	app.call("_add_button", files, tr("Export database/mod"), _file_dialog.bind(true))
	app.call("_add_button", files, tr("Use for new careers"), _use_mod)
	app.call("_add_button", box, tr("Back"), app.call.bind("_show_main_menu"))
	_select_collection(0)
	_update_notice()

func _select_collection(index: int) -> void:
	if collection_selector == null: return
	collection_selector.select(clampi(index, 0, _collections.size() - 1))
	entity_selector.clear()
	var collection := _collection_name()
	var values := _entities(collection)
	for entity in values:
		entity_selector.add_item(_display_name(entity))
	field_selector.clear()
	for field in Loader.ALLOWED_PATCH_KEYS.get(collection, []): field_selector.add_item(String(field))
	if entity_selector.item_count > 0: _select_entity(0)
	elif value_input != null: value_input.text = ""
	_update_notice()

func _select_entity(index: int) -> void:
	if entity_selector.item_count == 0: return
	entity_selector.select(clampi(index, 0, entity_selector.item_count - 1))
	_select_field(field_selector.selected if field_selector.selected >= 0 else 0)

func _select_field(index: int) -> void:
	if field_selector.item_count == 0 or entity_selector.item_count == 0: return
	field_selector.select(clampi(index, 0, field_selector.item_count - 1))
	var entity := _selected_entity()
	var field := field_selector.get_item_text(field_selector.selected)
	var value = entity.get(field, "")
	var patch := _current_patch(_collection_name(), String(entity.get("id", "")))
	if patch.has(field): value = patch[field]
	value_input.text = _format_value(value)

func _apply_change() -> void:
	var entity := _selected_entity()
	if entity.is_empty(): notice.text = tr("Select an entity first."); return
	var collection := _collection_name()
	var field := field_selector.get_item_text(field_selector.selected) if field_selector.item_count > 0 else ""
	if field == "": notice.text = tr("Select a field first."); return
	var parsed := _parse_value(value_input.text, entity.get(field, null))
	if not bool(parsed.ok): notice.text = tr("Invalid value for %s.") % field; return
	var id := String(entity.get("id", ""))
	var previous := _current_patch(collection, id).duplicate(true)
	previous.erase("id")
	previous[field] = parsed.value
	var editor = Editor.new()
	var removed: Dictionary = editor.remove_patch(mod, collection, id)
	var result: Dictionary = editor.add_patch(removed.mod, collection, id, previous)
	if not bool(result.ok): notice.text = tr("Change rejected: %s") % String(result.error); return
	mod = result.mod
	_update_notice()

func _remove_patch() -> void:
	var entity := _selected_entity()
	if entity.is_empty(): return
	var result := Editor.new().remove_patch(mod, _collection_name(), String(entity.get("id", "")))
	if bool(result.ok): mod = result.mod
	_select_field(field_selector.selected)
	_update_notice()

func _validate() -> void:
	var result := Editor.new().validate_project(mod)
	notice.text = tr("Mod validation passed.") if bool(result.get("ok", false)) else tr("Validation failed: %s") % String(result.get("error", "unknown"))

func _use_mod() -> void:
	var validation := Editor.new().validate_project(mod)
	if not bool(validation.get("ok", false)):
		notice.text = tr("Cannot use this mod: %s") % String(validation.get("error", "invalid")); return
	app.set("custom_database", mod.duplicate(true))
	app.call("_show_main_menu")

func _update_notice() -> void:
	if notice == null: return
	var counts: Array[String] = []
	var total := 0
	for collection in _collections:
		var count := mod.get("patches", {}).get(collection, []).size()
		if count > 0: counts.append("%s: %d" % [collection, count]); total += count
	notice.text = tr("%d patched entities") % total
	if not counts.is_empty(): notice.text += " • " + " • ".join(counts)

func _file_dialog(saving: bool) -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; Football Dynasty mod/database"])
	dialog.current_file = "custom-database.json" if saving else ""
	app.add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		if saving:
			var err: Error = Editor.new().export_mod(path, mod)
			notice.text = tr("Database/mod exported.") if err == OK else tr("Export failed (%d).") % err
		else:
			var imported: Dictionary = Editor.new().import_mod(path)
			if bool(imported.get("ok", false)) and _editable(imported):
				mod = {"metadata":imported.metadata,"patches":imported.patches}
				_select_collection(collection_selector.selected)
				_update_notice()
			else:
				notice.text = tr("This file is not a compatible Football Dynasty mod.")
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.75)

func _editable(data: Dictionary) -> bool:
	var patches: Dictionary = data.get("patches", {})
	for collection in patches.keys():
		var name := String(collection)
		if name not in _collections: return false
		var valid_ids := {}
		for entity in _entities(name): valid_ids[String(entity.get("id", ""))] = true
		for patch in patches[collection]:
			if not valid_ids.has(String(patch.get("id", ""))): return false
	return bool(Loader.new().validate_mod(data).get("ok", false))

func _collection_name() -> String:
	return _collections[clampi(collection_selector.selected, 0, _collections.size() - 1)]

func _entities(collection: String) -> Array:
	if collection in ["clubs", "countries"]:
		return _catalog.get(collection, [])
	if _full_world.is_empty():
		_full_world = LaunchWorldBuilder.new().build(12345, 0, 25, bool(app.get("expanded_world")))
	return _full_world.get(collection, [])

func _selected_entity() -> Dictionary:
	var values := _entities(_collection_name())
	if values.is_empty() or entity_selector.selected < 0 or entity_selector.selected >= values.size(): return {}
	return values[entity_selector.selected]

func _current_patch(collection: String, id: String) -> Dictionary:
	for patch in mod.get("patches", {}).get(collection, []):
		if String(patch.get("id", "")) == id: return patch
	return {}

func _display_name(entity: Dictionary) -> String:
	var name := String(entity.get("name", "")).strip_edges()
	if name == "": name = (String(entity.get("first_name", "")) + " " + String(entity.get("last_name", ""))).strip_edges()
	if name == "": name = String(entity.get("id", "Entity"))
	var suffix := String(entity.get("position", entity.get("role", "")))
	return name + (" — " + suffix if suffix != "" else "")

func _format_value(value) -> String:
	if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]: return JSON.stringify(value)
	if typeof(value) == TYPE_BOOL: return "true" if value else "false"
	return String(value)

func _parse_value(text: String, current) -> Dictionary:
	var clean := text.strip_edges()
	if typeof(current) in [TYPE_DICTIONARY, TYPE_ARRAY] or clean.begins_with("{") or clean.begins_with("["):
		var parsed = JSON.parse_string(clean)
		if parsed == null or typeof(parsed) not in [TYPE_DICTIONARY, TYPE_ARRAY]: return {"ok":false}
		return {"ok":true,"value":parsed}
	if typeof(current) == TYPE_BOOL:
		if clean.to_lower() not in ["true", "false"]: return {"ok":false}
		return {"ok":true,"value":clean.to_lower() == "true"}
	if typeof(current) in [TYPE_INT, TYPE_FLOAT]:
		if not clean.is_valid_float(): return {"ok":false}
		return {"ok":true,"value":float(clean) if typeof(current) == TYPE_FLOAT else int(float(clean))}
	# Unknown fields are interpreted conservatively: valid numeric text becomes a number,
	# otherwise it remains text. Loader validation is still the final authority.
	if clean.is_valid_float(): return {"ok":true,"value":float(clean)}
	return {"ok":true,"value":clean}

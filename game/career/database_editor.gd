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
var _collections := ["clubs", "countries", "players", "staff", "competitions", "stadiums", "name_pools"]

func _init(owner_app: Control, current: Dictionary = {}) -> void:
	app = owner_app
	mod = current.duplicate(true) if not current.is_empty() else Editor.new().create_mod("custom-database", "Custom database")
	mod["additions"] = mod.get("additions", {})
	mod["graphics"] = mod.get("graphics", {})
	mod["names"] = mod.get("names", {})
	_catalog = Catalog.new().build(0, bool(app.get("expanded_world")))

func show() -> void:
	var box: VBoxContainer = app.call("_clear")
	app.call("_add_heading", box, tr("Database & mod editor"), 28)
	var intro := Label.new()
	intro.text = tr("Edit or create clubs, countries, players, staff and competitions. Mods may also provide names, logos, kits and backgrounds. All data is validated before use.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)

	collection_selector = OptionButton.new()
	for collection in _collections:
		collection_selector.add_item(collection.capitalize())
	box.add_child(app.call("_labeled", tr("Collection"), collection_selector))
	entity_selector = OptionButton.new()
	box.add_child(app.call("_labeled", tr("Existing entity"), entity_selector))
	field_selector = OptionButton.new()
	box.add_child(app.call("_labeled", tr("Field"), field_selector))
	value_input = LineEdit.new()
	value_input.placeholder_text = tr("Value; JSON is accepted for arrays and dictionaries")
	box.add_child(app.call("_labeled", tr("Value"), value_input))
	collection_selector.item_selected.connect(_select_collection)
	entity_selector.item_selected.connect(_select_entity)
	field_selector.item_selected.connect(_select_field)

	var edit_actions := HBoxContainer.new()
	box.add_child(edit_actions)
	app.call("_add_button", edit_actions, tr("Apply field change"), _apply_change)
	app.call("_add_button", edit_actions, tr("Remove entity patch"), _remove_patch)

	app.call("_add_heading", box, tr("Create entity"), 20)
	var create_help := Label.new()
	create_help.text = tr("Enter one complete JSON object. Required references must already exist in the base database or an earlier addition in this mod.")
	create_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(create_help)
	var addition_input := LineEdit.new()
	addition_input.placeholder_text = tr('{"id":"custom-id","name":"Example",...}')
	box.add_child(addition_input)
	var create_row := HBoxContainer.new()
	box.add_child(create_row)
	app.call("_add_button", create_row, tr("Add new entity"), _add_entity.bind(addition_input))
	app.call("_add_button", create_row, tr("Remove addition by ID"), _remove_addition_prompt.bind(addition_input))

	app.call("_add_heading", box, tr("Name pools"), 20)
	var name_country := LineEdit.new()
	name_country.placeholder_text = tr("Country ID or default")
	box.add_child(name_country)
	var first_names := LineEdit.new()
	first_names.placeholder_text = tr("First names, comma-separated")
	box.add_child(first_names)
	var last_names := LineEdit.new()
	last_names.placeholder_text = tr("Last names, comma-separated")
	box.add_child(last_names)
	var name_row := HBoxContainer.new()
	box.add_child(name_row)
	app.call("_add_button", name_row, tr("Set name pool"), _set_name_pool.bind(name_country, first_names, last_names))
	app.call("_add_button", name_row, tr("Remove name pool"), _remove_name_pool.bind(name_country))

	app.call("_add_heading", box, tr("Graphics override"), 20)
	var graphic_entity := LineEdit.new()
	graphic_entity.placeholder_text = tr("Entity ID")
	box.add_child(graphic_entity)
	var graphic_key := OptionButton.new()
	for key in Loader.GRAPHIC_KEYS:
		graphic_key.add_item(String(key))
	box.add_child(graphic_key)
	var graphic_path := LineEdit.new()
	graphic_path.placeholder_text = tr("Relative PNG/JPG/WebP/SVG path inside the mod package")
	box.add_child(graphic_path)
	var graphic_row := HBoxContainer.new()
	box.add_child(graphic_row)
	app.call("_add_button", graphic_row, tr("Set graphic override"), _set_graphic.bind(graphic_entity, graphic_key, graphic_path, null))
	app.call("_add_button", graphic_row, tr("Clear entity graphics"), _clear_graphics.bind(graphic_entity))
	app.call("_add_button", graphic_row, tr("Preview graphic"), _preview_graphic.bind(graphic_path, null))

	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(notice)
	var validation_row := HBoxContainer.new()
	box.add_child(validation_row)
	app.call("_add_button", validation_row, tr("Validate mod"), _validate)
	app.call("_add_button", validation_row, tr("Import database/mod"), _file_dialog.bind(false))
	app.call("_add_button", validation_row, tr("Export database/mod"), _file_dialog.bind(true))
	app.call("_add_button", validation_row, tr("Use for new careers"), _use_mod)
	app.call("_add_button", box, tr("Back"), app.call.bind("_show_main_menu"))
	_select_collection(0)
	_update_notice()

func _select_collection(index: int) -> void:
	if collection_selector == null:
		return
	collection_selector.select(clampi(index, 0, _collections.size() - 1))
	entity_selector.clear()
	var collection := _collection_name()
	var values := _entities(collection)
	for entity in values:
		entity_selector.add_item(_display_name(entity))
	field_selector.clear()
	for field in Loader.ALLOWED_PATCH_KEYS.get(collection, []):
		field_selector.add_item(String(field))
	if entity_selector.item_count > 0:
		_select_entity(0)
	elif value_input != null:
		value_input.text = ""
	_update_notice()

func _select_entity(index: int) -> void:
	if entity_selector.item_count == 0:
		return
	entity_selector.select(clampi(index, 0, entity_selector.item_count - 1))
	_select_field(field_selector.selected if field_selector.selected >= 0 else 0)

func _select_field(index: int) -> void:
	if field_selector.item_count == 0 or entity_selector.item_count == 0:
		return
	field_selector.select(clampi(index, 0, field_selector.item_count - 1))
	var entity := _selected_entity()
	var field := field_selector.get_item_text(field_selector.selected)
	var value = entity.get(field, "")
	var patch := _current_patch(_collection_name(), String(entity.get("id", "")))
	if patch.has(field):
		value = patch[field]
	value_input.text = _format_value(value)

func _apply_change() -> void:
	var entity := _selected_entity()
	if entity.is_empty():
		notice.text = tr("Select an entity first.")
		return
	var collection := _collection_name()
	var field := field_selector.get_item_text(field_selector.selected) if field_selector.item_count > 0 else ""
	if field == "":
		notice.text = tr("Select a field first.")
		return
	var parsed := _parse_value(value_input.text, entity.get(field, null))
	if not bool(parsed.ok):
		notice.text = tr("Invalid value for %s.") % field
		return
	var id := String(entity.get("id", ""))
	var previous := _current_patch(collection, id).duplicate(true)
	previous.erase("id")
	previous[field] = parsed.value
	var editor = Editor.new()
	var removed: Dictionary = editor.remove_patch(mod, collection, id)
	var result: Dictionary = editor.add_patch(removed.mod, collection, id, previous)
	if not bool(result.ok):
		notice.text = tr("Change rejected: %s") % String(result.error)
		return
	mod = result.mod
	mod["additions"] = mod.get("additions", {})
	mod["graphics"] = mod.get("graphics", {})
	mod["names"] = mod.get("names", {})
	_update_notice()

func _remove_patch() -> void:
	var entity := _selected_entity()
	if entity.is_empty():
		return
	var result := Editor.new().remove_patch(mod, _collection_name(), String(entity.get("id", "")))
	if bool(result.ok):
		mod = result.mod
	_select_field(field_selector.selected)
	_update_notice()

func _add_entity(input: LineEdit) -> void:
	var parsed = JSON.parse_string(input.text)
	if typeof(parsed) != TYPE_DICTIONARY:
		notice.text = tr("New entity must be a valid JSON object.")
		return
	var collection := _collection_name()
	var candidate := mod.duplicate(true)
	candidate["additions"] = candidate.get("additions", {})
	if not candidate.additions.has(collection):
		candidate.additions[collection] = []
	candidate.additions[collection].append(parsed)
	var validation := Editor.new().validate_project(candidate)
	if not bool(validation.get("ok", false)):
		notice.text = tr("Entity rejected: %s") % String(validation.get("error", "invalid"))
		return
	mod = candidate
	input.text = ""
	_update_notice()

func _remove_addition_prompt(input: LineEdit) -> void:
	var id := input.text.strip_edges()
	if id.begins_with("{"):
		var parsed = JSON.parse_string(id)
		if typeof(parsed) == TYPE_DICTIONARY:
			id = String(parsed.get("id", ""))
	if id == "":
		notice.text = tr("Enter the addition ID to remove.")
		return
	var rows: Array = mod.get("additions", {}).get(_collection_name(), [])
	for i in range(rows.size() - 1, -1, -1):
		if String(rows[i].get("id", "")) == id:
			rows.remove_at(i)
	input.text = ""
	_update_notice()

func _set_name_pool(country: LineEdit, first: LineEdit, last: LineEdit) -> void:
	var country_id := country.text.strip_edges()
	if country_id.is_empty():
		notice.text = tr("Enter a country ID or default.")
		return
	var first_values := _comma_values(first.text)
	var last_values := _comma_values(last.text)
	if first_values.is_empty() and last_values.is_empty():
		notice.text = tr("Enter at least one first name or surname.")
		return
	var candidate := mod.duplicate(true)
	candidate["names"] = candidate.get("names", {})
	candidate.names[country_id] = {"first": first_values, "last": last_values}
	var validation := Editor.new().validate_project(candidate)
	if not bool(validation.get("ok", false)):
		notice.text = tr("Name pool rejected: %s") % String(validation.get("error", "invalid"))
		return
	mod = candidate
	first.text = ""
	last.text = ""
	_update_notice()

func _remove_name_pool(country: LineEdit) -> void:
	var country_id := country.text.strip_edges()
	if country_id.is_empty():
		return
	mod.get("names", {}).erase(country_id)
	_update_notice()

func _set_graphic(entity: LineEdit, key: OptionButton, path: LineEdit, _preview: Variant = null) -> void:
	var id := entity.text.strip_edges()
	var value := path.text.strip_edges()
	if id == "" or value == "":
		notice.text = tr("Entity ID and graphic path are required.")
		return
	var candidate := mod.duplicate(true)
	candidate["graphics"] = candidate.get("graphics", {})
	if not candidate.graphics.has(id):
		candidate.graphics[id] = {}
	candidate.graphics[id][key.get_item_text(key.selected)] = value
	var validation := Editor.new().validate_project(candidate)
	if not bool(validation.get("ok", false)):
		notice.text = tr("Graphic rejected: %s") % String(validation.get("error", "invalid"))
		return
	mod = candidate
	path.text = ""
	_update_notice()

func _preview_graphic(path: LineEdit, _unused: Variant = null) -> void:
	var value := path.text.strip_edges()
	if value == "":
		notice.text = tr("Enter a graphic path to preview.")
		return
	if value.contains("..") or value.begins_with("/") or value.contains(":\\"):
		notice.text = tr("Preview rejected: unsafe path.")
		return
	if not ResourceLoader.exists(value):
		notice.text = tr("Preview: file not found in project — pack it inside the mod package.")
		return
	var texture = load(value)
	if texture is Texture2D:
		notice.text = tr("Preview loaded: %s (%dx%d)") % [value, int(texture.get_width()), int(texture.get_height())]
	else:
		notice.text = tr("Preview rejected: not a readable image.")

func _clear_graphics(entity: LineEdit) -> void:
	var id := entity.text.strip_edges()
	if id != "":
		mod.get("graphics", {}).erase(id)
	_update_notice()

func _validate() -> void:
	var result := Editor.new().validate_project(mod)
	notice.text = tr("Mod validation passed.") if bool(result.get("ok", false)) else tr("Validation failed: %s") % String(result.get("error", "unknown"))

func _use_mod() -> void:
	var validation := Editor.new().validate_project(mod)
	if not bool(validation.get("ok", false)):
		notice.text = tr("Cannot use this mod: %s") % String(validation.get("error", "invalid"))
		return
	app.set("custom_database", mod.duplicate(true))
	app.call("_show_main_menu")

func _update_notice() -> void:
	if notice == null:
		return
	var patched := 0
	var added := 0
	for collection in _collections:
		patched += mod.get("patches", {}).get(collection, []).size()
		added += mod.get("additions", {}).get(collection, []).size()
	var meta: Dictionary = mod.get("metadata", {})
	var deps: Array = meta.get("dependencies", [])
	var conflicts: Array = meta.get("conflicts", [])
	notice.text = tr("%d patched • %d added • %d name pools • %d graphic override sets") % [patched, added, mod.get("names", {}).size(), mod.get("graphics", {}).size()]
	if not deps.is_empty() or not conflicts.is_empty():
		notice.text += "\n" + tr("Depends: %s   Conflicts: %s") % [", ".join(deps) if not deps.is_empty() else "-", ", ".join(conflicts) if not conflicts.is_empty() else "-"]

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
				mod = {
					"metadata": imported.metadata,
					"patches": imported.get("patches", {}),
					"additions": imported.get("additions", {}),
					"graphics": imported.get("graphics", {}),
					"names": imported.get("names", {})
				}
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
		if name not in _collections:
			return false
		var valid_ids := {}
		for entity in _entities(name):
			valid_ids[String(entity.get("id", ""))] = true
		for patch in patches[collection]:
			if not valid_ids.has(String(patch.get("id", ""))):
				return false
	return bool(Editor.new().validate_project(data).get("ok", false))

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
	if values.is_empty() or entity_selector.selected < 0 or entity_selector.selected >= values.size():
		return {}
	return values[entity_selector.selected]

func _current_patch(collection: String, id: String) -> Dictionary:
	for patch in mod.get("patches", {}).get(collection, []):
		if String(patch.get("id", "")) == id:
			return patch
	return {}

func _display_name(entity: Dictionary) -> String:
	var name := String(entity.get("name", "")).strip_edges()
	if name == "":
		name = (String(entity.get("first_name", "")) + " " + String(entity.get("last_name", ""))).strip_edges()
	if name == "":
		name = String(entity.get("id", "Entity"))
	var suffix := String(entity.get("position", entity.get("role", "")))
	return name + (" — " + suffix if suffix != "" else "")

func _format_value(value) -> String:
	if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		return JSON.stringify(value)
	if typeof(value) == TYPE_BOOL:
		return "true" if value else "false"
	return String(value)

func _parse_value(text: String, current) -> Dictionary:
	var clean := text.strip_edges()
	if typeof(current) in [TYPE_DICTIONARY, TYPE_ARRAY] or clean.begins_with("{") or clean.begins_with("["):
		var parsed = JSON.parse_string(clean)
		if parsed == null or typeof(parsed) not in [TYPE_DICTIONARY, TYPE_ARRAY]:
			return {"ok": false}
		return {"ok": true, "value": parsed}
	if typeof(current) == TYPE_BOOL:
		if clean.to_lower() not in ["true", "false"]:
			return {"ok": false}
		return {"ok": true, "value": clean.to_lower() == "true"}
	if typeof(current) in [TYPE_INT, TYPE_FLOAT]:
		if not clean.is_valid_float():
			return {"ok": false}
		return {"ok": true, "value": float(clean) if typeof(current) == TYPE_FLOAT else int(float(clean))}
	if clean.is_valid_float():
		return {"ok": true, "value": float(clean)}
	return {"ok": true, "value": clean}

func _comma_values(text: String) -> Array:
	var values: Array = []
	for raw in text.split(",", false):
		var value := String(raw).strip_edges()
		if not value.is_empty():
			values.append(value)
	return values

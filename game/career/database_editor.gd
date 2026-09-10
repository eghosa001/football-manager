extends RefCounted

const Editor = preload("res://tools/modding/mod_editor.gd")
const Catalog = preload("res://data/launch_catalog.gd")
var app: Control
var mod: Dictionary
var clubs: Array
var selector: OptionButton
var club_name: LineEdit
var reputation: SpinBox
var notice: Label

func _init(owner_app: Control, current: Dictionary = {}) -> void:
	app = owner_app
	mod = current.duplicate(true) if not current.is_empty() else Editor.new().create_mod("custom-clubs", "Custom clubs")
	clubs = Catalog.new().build(0, bool(app.get("expanded_world"))).clubs

func show() -> void:
	var box: VBoxContainer = app.call("_clear")
	app.call("_add_heading", box, tr("Club database editor"), 28)
	selector = OptionButton.new()
	for club in clubs: selector.add_item(String(club.name))
	box.add_child(selector)
	club_name = LineEdit.new()
	box.add_child(app.call("_labeled", tr("Club name"), club_name))
	reputation = SpinBox.new(); reputation.min_value = 1; reputation.max_value = 100; reputation.value = 50
	box.add_child(app.call("_labeled", tr("Reputation"), reputation))
	selector.item_selected.connect(_select)
	_select(0)
	notice = Label.new(); notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(notice)
	app.call("_add_button", box, tr("Add club change"), _add_change)
	app.call("_add_button", box, tr("Import database"), _file_dialog.bind(false))
	app.call("_add_button", box, tr("Export database"), _file_dialog.bind(true))
	app.call("_add_button", box, tr("Use for new careers"), func():
		app.set("custom_database", mod.duplicate(true))
		app.call("_show_main_menu")
	)
	app.call("_add_button", box, tr("Back"), app.call.bind("_show_main_menu"))
	_update_notice()

func _select(index: int) -> void:
	club_name.text = String(clubs[index].name)
	reputation.value = 50
	for patch in mod.get("patches", {}).get("clubs", []):
		if String(patch.id) == String(clubs[index].id):
			club_name.text = String(patch.get("name", club_name.text))
			reputation.value = int(patch.get("reputation", 50))

func _add_change() -> void:
	if club_name.text.strip_edges().is_empty():
		notice.text = tr("Enter a club name."); return
	var id := String(clubs[selector.selected].id)
	var editor = Editor.new()
	var removed: Dictionary = editor.remove_patch(mod, "clubs", id)
	var result: Dictionary = editor.add_patch(removed.mod, "clubs", id, {"name":club_name.text.strip_edges(),"reputation":int(reputation.value)})
	if not bool(result.ok): notice.text = String(result.error); return
	mod = result.mod
	_update_notice()

func _update_notice() -> void:
	notice.text = tr("%d club changes. Changes apply only to newly created careers.") % mod.get("patches", {}).get("clubs", []).size()

func _file_dialog(saving: bool) -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; Club database"])
	dialog.current_file = "custom-clubs.json" if saving else ""
	app.add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		if saving:
			var err: Error = Editor.new().export_mod(path, mod)
			notice.text = tr("Database exported.") if err == OK else tr("Database export failed.")
		else:
			var imported: Dictionary = Editor.new().import_mod(path)
			if bool(imported.get("ok", false)) and _editable(imported):
				mod = {"metadata":imported.metadata,"patches":imported.patches}
				_select(selector.selected); _update_notice()
			else: notice.text = tr("This file is not a compatible club database.")
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.75)

func _editable(data: Dictionary) -> bool:
	var valid_ids := {}
	for club in clubs: valid_ids[String(club.id)] = true
	for collection in data.patches:
		if String(collection) != "clubs": return false
		for patch in data.patches[collection]:
			if not valid_ids.has(String(patch.id)): return false
			for key in patch:
				if String(key) not in ["id", "name", "reputation"]: return false
	return true

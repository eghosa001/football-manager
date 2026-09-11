extends Node

const SaveSlots = preload("res://application/career/save_slots.gd")
const SettingsStore = preload("res://application/settings/settings_store.gd")

const SETTINGS_PATH := "user://settings.json"

var _slots = SaveSlots.new()
var _settings_store = SettingsStore.new()
var _next_scan_msec := 0
var _last_trigger_key := ""

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan_msec:
		return
	_next_scan_msec = now + 700
	_scan()

func _scan() -> void:
	var app = _career_app()
	if app == null:
		return
	var session = app.get("session")
	if session == null or session.world.is_empty():
		return
	var tabs := _career_tabs(app)
	if tabs != null and not tabs.has_meta("save_policy_added"):
		_add_save_policy_tab(tabs, app, session)
	_maybe_autosave(app, session)

func _maybe_autosave(app: Node, session) -> void:
	var active_slot := int(app.get("active_slot"))
	if active_slot <= 0:
		return
	var settings: Dictionary = app.get("settings")
	if not bool(settings.get("autosave", true)):
		return
	var mode := String(settings.get("autosave_mode", "weekly"))
	if mode == "manual":
		return
	var key := _trigger_key(session.world, mode)
	if key == "" or key == _last_trigger_key:
		return
	_last_trigger_key = key
	var err := _slots.autosave_slot(active_slot, session.world, session.history, session.manager, int(settings.get("autosave_rolling_count", 3)))
	var status = app.get("status")
	if status != null:
		if err == OK:
			status.text = tr("Autosaved • %s • rolling %d") % [mode.replace("_", " ").capitalize(), int(settings.get("autosave_rolling_count", 3))]
		else:
			status.text = tr("Autosave failed (%d). Manual save is still available.") % err

func _trigger_key(world: Dictionary, mode: String) -> String:
	var date := String(world.get("date", ""))
	var day_index := int(world.get("day_index", 0))
	match mode:
		"weekly":
			if day_index <= 0 or day_index % 7 != 0:
				return ""
			return "weekly:%d:%s" % [day_index, date]
		"monthly":
			var parts := date.split("-")
			if parts.size() != 3 or String(parts[2]) != "01":
				return ""
			return "monthly:%s" % date
		"after_match":
			var row: Dictionary = world.get("last_managed_match", {})
			if row.is_empty() or String(row.get("date", "")) != date:
				return ""
			var fixture: Dictionary = row.get("fixture", {})
			return "match:%s:%s" % [date, String(fixture.get("id", "managed"))]
		_:
			return ""

func _add_save_policy_tab(tabs: TabContainer, app: Node, session) -> void:
	tabs.set_meta("save_policy_added", true)
	var scroll := ScrollContainer.new()
	scroll.name = "Save Policy"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(900, 480)
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	var heading := Label.new()
	heading.text = tr("SAVE POLICY & RECOVERY")
	heading.add_theme_font_size_override("font_size", 22)
	box.add_child(heading)
	var help := Label.new()
	help.text = tr("Manual saves remain separate. Autosaves rotate through independent recovery points and are written through the same atomic save store.")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)

	var current: Dictionary = app.get("settings")
	var enabled := CheckBox.new()
	enabled.text = tr("Enable autosave")
	enabled.button_pressed = bool(current.get("autosave", true))
	box.add_child(enabled)

	var mode := OptionButton.new()
	for value in SettingsStore.AUTOSAVE_MODES:
		mode.add_item(tr(String(value).replace("_", " ").capitalize()))
	mode.select(maxi(0, SettingsStore.AUTOSAVE_MODES.find(String(current.get("autosave_mode", "weekly")))))
	_add_labeled(box, tr("Autosave trigger"), mode)

	var rolling := OptionButton.new()
	rolling.add_item(tr("Keep 3 rolling autosaves"))
	rolling.add_item(tr("Keep 5 rolling autosaves"))
	rolling.select(1 if int(current.get("autosave_rolling_count", 3)) >= 5 else 0)
	_add_labeled(box, tr("Recovery history"), rolling)

	var apply := Button.new()
	apply.text = tr("Apply save policy")
	apply.pressed.connect(func():
		var value: Dictionary = app.get("settings").duplicate(true)
		value["autosave"] = enabled.button_pressed
		value["autosave_mode"] = String(SettingsStore.AUTOSAVE_MODES[mode.selected]) if enabled.button_pressed else "manual"
		value["autosave_rolling_count"] = 5 if rolling.selected == 1 else 3
		value = _settings_store.sanitize(value)
		app.set("settings", value)
		_settings_store.save(SETTINGS_PATH, value)
		_refresh_recovery(box, app, session)
	)
	box.add_child(apply)

	var manual := Button.new()
	manual.text = tr("Create recovery autosave now")
	manual.pressed.connect(func():
		var slot := int(app.get("active_slot"))
		if slot <= 0:
			return
		var settings: Dictionary = app.get("settings")
		_slots.autosave_slot(slot, session.world, session.history, session.manager, int(settings.get("autosave_rolling_count", 3)))
		_refresh_recovery(box, app, session)
	)
	box.add_child(manual)

	var marker := VBoxContainer.new()
	marker.name = "RecoveryRows"
	box.add_child(marker)
	_refresh_recovery(box, app, session)
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tr("Save Policy"))

func _refresh_recovery(box: VBoxContainer, app: Node, session) -> void:
	var rows: VBoxContainer = box.get_node_or_null("RecoveryRows")
	if rows == null:
		return
	for child in rows.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = tr("Rolling recovery points")
	title.add_theme_font_size_override("font_size", 18)
	rows.add_child(title)
	var slot := int(app.get("active_slot"))
	if slot <= 0:
		var no_slot := Label.new()
		no_slot.text = tr("Choose a manual save slot before autosaves can be created.")
		rows.add_child(no_slot)
		return
	var found := _slots.list_autosaves(slot, 5)
	if found.is_empty():
		var empty := Label.new()
		empty.text = tr("No autosave recovery points yet.")
		rows.add_child(empty)
		return
	for row in found:
		var line := HBoxContainer.new()
		rows.add_child(line)
		var label := Label.new()
		label.text = tr("Autosave %d • %s%s") % [int(row.get("generation", 0)), String(row.get("date", "Unreadable")), " • corrupt" if bool(row.get("corrupt", false)) else ""]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		if not bool(row.get("corrupt", false)):
			var restore := Button.new()
			restore.text = tr("Restore")
			restore.pressed.connect(_restore.bind(app, session, String(row.path), slot))
			line.add_child(restore)

func _restore(app: Node, session, path: String, slot: int) -> void:
	if session.load_career(path) != OK:
		return
	app.set("active_slot", slot)
	_last_trigger_key = ""
	app.call("_show_career")

func _add_labeled(parent: VBoxContainer, title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 220
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)

func _career_app():
	return _find_career_app(get_tree().root)

func _find_career_app(node: Node):
	var script = node.get_script()
	if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
		return node
	for child in node.get_children():
		var found = _find_career_app(child)
		if found != null:
			return found
	return null

func _career_tabs(app: Node):
	for child in app.get_children():
		var tabs := _find_tabs(child)
		if tabs != null:
			return tabs
	return null

func _find_tabs(node: Node):
	if node is TabContainer:
		var names: Array[String] = []
		for child in node.get_children():
			names.append(String(child.name))
		if "Dashboard" in names and "Squad" in names:
			return node
	for child in node.get_children():
		var found = _find_tabs(child)
		if found != null:
			return found
	return null

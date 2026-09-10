extends Control

const CareerSessionClass = preload("res://application/career/career_session.gd")
const SaveSlotsClass = preload("res://application/career/save_slots.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const CareerQueryClass = preload("res://application/career/career_query.gd")
const CareerViewsClass = preload("res://game/career/career_views.gd")
const LaunchWorldBuilderClass = preload("res://data/launch_world_builder.gd")
const SettingsStoreClass = preload("res://application/settings/settings_store.gd")
const LocalizationServiceClass = preload("res://game/localization/localization_service.gd")

const SETTINGS_PATH := "user://settings.json"

var session = CareerSessionClass.new()
var slots = SaveSlotsClass.new()
var query = CareerQueryClass.new()
var settings_store = SettingsStoreClass.new()
var localization = LocalizationServiceClass.new()
var settings: Dictionary = {}
var active_slot := 1
var content: VBoxContainer
var status: Label
var _manager_name_input: LineEdit
var _club_selector: OptionButton
var _wizard_clubs: Array = []

func _ready() -> void:
	settings = settings_store.load(SETTINGS_PATH)
	_apply_runtime_settings()
	_show_main_menu()

func _clear() -> VBoxContainer:
	for child in get_children(): child.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(28 * float(settings.get("ui_scale", 1.0))))
	margin.add_theme_constant_override("margin_top", int(22 * float(settings.get("ui_scale", 1.0))))
	margin.add_theme_constant_override("margin_right", int(28 * float(settings.get("ui_scale", 1.0))))
	margin.add_theme_constant_override("margin_bottom", int(22 * float(settings.get("ui_scale", 1.0))))
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", int(10 * float(settings.get("ui_scale", 1.0))))
	margin.add_child(content)
	return content

func _show_main_menu() -> void:
	var root := _clear()
	_add_heading(root, "FOOTBALL DYNASTY", 36)
	var subtitle := Label.new(); subtitle.text = "Build a dynasty. Shape a football world."; root.add_child(subtitle)
	_add_button(root, "New Career", _show_new_career)
	_add_button(root, "Load Career", _show_load_menu)
	_add_button(root, "Settings", _show_settings)
	_add_button(root, "Quit", func(): get_tree().quit())

func _show_settings() -> void:
	var root := _clear()
	_add_heading(root, "Settings", 28)
	var language := OptionButton.new()
	for code in LocalizationServiceClass.SUPPORTED: language.add_item(String(code).to_upper())
	language.select(maxi(0, LocalizationServiceClass.SUPPORTED.find(String(settings.get("language", "en")))))
	root.add_child(_labeled("Language", language))
	var ui_scale := HSlider.new(); ui_scale.min_value = 0.75; ui_scale.max_value = 2.0; ui_scale.step = 0.05; ui_scale.value = float(settings.get("ui_scale",1.0)); root.add_child(_labeled("UI scale", ui_scale))
	var font_scale := HSlider.new(); font_scale.min_value = 0.8; font_scale.max_value = 2.0; font_scale.step = 0.05; font_scale.value = float(settings.get("font_scale",1.0)); root.add_child(_labeled("Font scale", font_scale))
	var contrast := CheckBox.new(); contrast.text = "High contrast"; contrast.button_pressed = bool(settings.get("high_contrast",false)); root.add_child(contrast)
	var motion := CheckBox.new(); motion.text = "Reduce motion"; motion.button_pressed = bool(settings.get("reduce_motion",false)); root.add_child(motion)
	var reader := CheckBox.new(); reader.text = "Screen-reader labels"; reader.button_pressed = bool(settings.get("screen_reader_labels",true)); root.add_child(reader)
	var autosave := CheckBox.new(); autosave.text = "Autosave"; autosave.button_pressed = bool(settings.get("autosave",true)); root.add_child(autosave)
	var interval := SpinBox.new(); interval.min_value = 1; interval.max_value = 30; interval.value = int(settings.get("autosave_interval_days",7)); root.add_child(_labeled("Autosave interval (days)", interval))
	var row := HBoxContainer.new(); root.add_child(row)
	_add_button(row, "Apply", func():
		settings.language = LocalizationServiceClass.SUPPORTED[language.selected]
		settings.ui_scale = ui_scale.value
		settings.font_scale = font_scale.value
		settings.high_contrast = contrast.button_pressed
		settings.reduce_motion = motion.button_pressed
		settings.screen_reader_labels = reader.button_pressed
		settings.autosave = autosave.button_pressed
		settings.autosave_interval_days = int(interval.value)
		settings = settings_store.sanitize(settings)
		settings_store.save(SETTINGS_PATH, settings)
		_apply_runtime_settings()
		_show_main_menu()
	)
	_add_button(row, "Reset", func(): settings = settings_store.defaults(); settings_store.save(SETTINGS_PATH, settings); _apply_runtime_settings(); _show_settings())
	_add_button(row, "Back", _show_main_menu)

func _show_new_career() -> void:
	var root := _clear()
	_add_heading(root, "New Career", 28)
	var name_label := Label.new(); name_label.text = "Manager name"; root.add_child(name_label)
	_manager_name_input = LineEdit.new(); _manager_name_input.text = "Manager"; _manager_name_input.placeholder_text = "Enter manager name"; root.add_child(_manager_name_input)
	var club_label := Label.new(); club_label.text = "Choose club — launch database"; root.add_child(club_label)
	_club_selector = OptionButton.new()
	var preview: Dictionary = LaunchWorldBuilderClass.new().build(12345, 0, 25)
	_wizard_clubs = preview.get("clubs", [])
	for club in _wizard_clubs:
		var country_name := _country_name(preview.get("countries", []), String(club.get("country_id", "")))
		var tier := int(club.get("tier", 1))
		_club_selector.add_item("%s — %s T%d" % [String(club.get("name", "Club")), country_name, tier])
	root.add_child(_club_selector)
	var database_info := Label.new(); database_info.text = "%d countries • %d clubs • multi-tier leagues and domestic cups" % [preview.get("countries", []).size(), _wizard_clubs.size()]; root.add_child(database_info)
	var buttons := HBoxContainer.new(); root.add_child(buttons)
	_add_button(buttons, "Create Career", _create_career_from_wizard)
	_add_button(buttons, "Back", _show_main_menu)

func _create_career_from_wizard() -> void:
	var manager_name := _manager_name_input.text.strip_edges()
	if manager_name == "": manager_name = "Manager"
	var selected := clampi(_club_selector.selected, 0, maxi(0, _wizard_clubs.size()-1))
	var club_id := String(_wizard_clubs[selected].id) if not _wizard_clubs.is_empty() else ""
	var snap: Dictionary = session.new_career(manager_name, club_id, 12345, 0)
	if snap.is_empty():
		_show_main_menu(); return
	InboxServiceClass.new().add_message(session.world, "board", "Welcome to the club", "Your first season is ready. Review the squad, tactics, training and recruitment before the opening fixture.")
	_show_career()

func _show_load_menu() -> void:
	var root := _clear()
	_add_heading(root, "Load Career", 28)
	var any := false
	for meta in slots.list_slots(10):
		if not bool(meta.get("exists", false)): continue
		any = true
		var line := HBoxContainer.new(); root.add_child(line)
		var label := "Slot %d — %s / %s / %s" % [int(meta.slot), String(meta.manager), String(meta.club), String(meta.date)]
		_add_button(line, label, _load_slot.bind(int(meta.slot)))
		_add_button(line, "Delete", _delete_slot.bind(int(meta.slot)))
	if not any:
		var empty := Label.new(); empty.text = "No saved careers yet."; root.add_child(empty)
	_add_button(root, "Back", _show_main_menu)

func _delete_slot(slot: int) -> void:
	slots.delete_slot(slot)
	_show_load_menu()

func _load_slot(slot: int) -> void:
	var path := slots.slot_path(slot)
	if session.load_career(path) != OK:
		_show_main_menu(); return
	active_slot = slot
	_show_career()

func _show_career() -> void:
	var root := _clear()
	var snap: Dictionary = session.snapshot()
	var dashboard: Dictionary = query.dashboard(session.world, session.managed_club_id)
	var club: Dictionary = dashboard.get("club", {})
	_add_heading(root, "%s — %s" % [String(club.get("name", "Club")), String(snap.date)], 26)
	var buttons := HBoxContainer.new(); root.add_child(buttons)
	_add_button(buttons, "Continue", _advance_day)
	_add_button(buttons, "Save Slot %d" % active_slot, _save)
	_add_button(buttons, "Save As", _show_save_as)
	_add_button(buttons, "Settings", _show_settings)
	_add_button(buttons, "Main Menu", _show_main_menu)
	status = Label.new(); status.text = "Manager: %s  •  Season %d  •  Inbox %d" % [String(session.manager.get("name", "Manager")), int(snap.season_year), int(dashboard.get("unread_messages",0))]; root.add_child(status)
	var tabs := TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(tabs)
	var views = CareerViewsClass.new(self, session)
	views.add_dashboard(tabs)
	views.add_squad(tabs)
	views.add_training(tabs)
	views.add_tactics(tabs)
	views.add_medical(tabs)
	views.add_scouting(tabs)
	views.add_transfers(tabs)
	views.add_schedule(tabs)
	_add_inbox_tab(tabs)
	views.add_staff(tabs)
	views.add_finances(tabs)
	views.add_search(tabs)
	views.add_match_analysis(tabs)

func _show_save_as() -> void:
	var root := _clear()
	_add_heading(root, "Save Career As", 28)
	for slot in range(1, 11):
		var meta: Dictionary = slots.metadata(slot)
		var label := "Slot %d" % slot
		if bool(meta.get("exists",false)): label += " — overwrite %s / %s" % [String(meta.get("manager","")),String(meta.get("date",""))]
		_add_button(root, label, _save_to_slot.bind(slot))
	_add_button(root, "Back", _show_career)

func _save_to_slot(slot: int) -> void:
	active_slot = slot
	var err := slots.save_slot(slot, session.world, session.history, session.manager)
	_show_career()
	if status != null: status.text = "Saved to slot %d" % slot if err == OK else "Save failed (%d)" % err

func _add_inbox_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new(); scroll.name = "Inbox"
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(920, 480); scroll.add_child(box)
	var messages: Array = InboxServiceClass.new().unread(session.world)
	if messages.is_empty():
		var empty := Label.new(); empty.text = "Inbox clear."; box.add_child(empty)
	for message in messages:
		var title := Label.new(); title.text = "%s — %s" % [String(message.get("category", "info")).to_upper(), String(message.get("title", "Message"))]; box.add_child(title)
		var body := Label.new(); body.text = String(message.get("body", "")); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(body)
		var row := HBoxContainer.new(); box.add_child(row)
		if not bool(message.get("read",false)): _add_button(row, "Mark read", _mark_message_read.bind(int(message.id)))
		if bool(message.get("requires_action", false)) and not bool(message.get("resolved", false)):
			for action in message.get("actions", []):
				var action_id := String(action.get("id", "action"))
				_add_button(row, String(action.get("label", action_id.capitalize())), _resolve_message.bind(int(message.id), action_id))
	tabs.add_child(scroll)

func _mark_message_read(message_id: int) -> void:
	InboxServiceClass.new().mark_read(session.world, message_id)
	_show_career()

func _resolve_message(message_id: int, action_id: String) -> void:
	InboxServiceClass.new().resolve(session.world, message_id, action_id)
	_show_career()

func _advance_day() -> void:
	var result: Dictionary = DayRunnerClass.new().advance_day(session.world, session.history, session.seed + int(session.world.get("day_index",0))*17 + int(session.world.get("season_year",2026))*101)
	if result.has("error"):
		status.text = "Unable to advance day"; return
	if bool(settings.get("autosave", true)) and int(session.world.get("day_index", 0)) % int(settings.get("autosave_interval_days", 7)) == 0:
		slots.save_slot(active_slot, session.world, session.history, session.manager)
	_show_career()

func _save() -> void:
	var err := slots.save_slot(active_slot, session.world, session.history, session.manager)
	status.text = "Saved to slot %d" % active_slot if err == OK else "Save failed (%d)" % err

func _apply_runtime_settings() -> void:
	var scale := float(settings.get("ui_scale", 1.0))
	self.scale = Vector2.ONE * scale
	if bool(settings.get("high_contrast", false)): modulate = Color(1.0, 1.0, 1.0, 1.0)
	else: modulate = Color.WHITE

func _country_name(countries: Array, country_id: String) -> String:
	for country in countries:
		if String(country.get("id", "")) == country_id: return String(country.get("name", country_id))
	return country_id

func _labeled(text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new(); label.text = text; label.custom_minimum_size.x = 220; row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _add_heading(parent: Control, text: String, size: int) -> void:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", int(size * float(settings.get("font_scale", 1.0)))); parent.add_child(label)

func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new(); button.text = text; button.pressed.connect(callback); parent.add_child(button)

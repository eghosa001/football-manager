extends Control

const CareerSessionClass = preload("res://application/career/career_session.gd")
const SaveSlotsClass = preload("res://application/career/save_slots.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const CareerQueryClass = preload("res://application/career/career_query.gd")
const CareerViewsClass = preload("res://game/career/career_views.gd")
const LaunchCatalogClass = preload("res://data/launch_catalog.gd")
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
var _country_selector: OptionButton
var _wizard_clubs: Array = []
var _wizard_countries: Array = []
var _wizard_preview: Dictionary = {}
var _wizard_country_id := "eng"
var _worker: Thread
var _busy := false
var custom_database: Dictionary = {}
var expanded_world := false

func _ready() -> void:
	if "--release-smoke" in OS.get_cmdline_user_args():
		get_tree().quit(preload("res://application/release/package_validator.gd").new().run())
		return
	settings = settings_store.load(SETTINGS_PATH)
	_apply_runtime_settings()
	_show_main_menu()

func _clear() -> VBoxContainer:
	for child in get_children(): child.queue_free()
	var background := ColorRect.new()
	background.color = Color.BLACK if bool(settings.get("high_contrast", false)) else Color(0.035, 0.055, 0.09)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(28 * float(settings.get("ui_scale", 1.0))))
	margin.add_theme_constant_override("margin_top", int(22 * float(settings.get("ui_scale", 1.0))))
	margin.add_theme_constant_override("margin_right", int(28 * float(settings.get("ui_scale", 1.0))))
	margin.add_theme_constant_override("margin_bottom", int(22 * float(settings.get("ui_scale", 1.0))))
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", int(10 * float(settings.get("ui_scale", 1.0))))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content

func _show_main_menu() -> void:
	var root := _clear()
	_add_heading(root, tr("FOOTBALL DYNASTY"), 36)
	var subtitle := Label.new(); subtitle.text = tr("Build a dynasty. Shape a football world."); root.add_child(subtitle)
	if not session.world.is_empty(): _add_button(root, tr("Resume Career"), _show_career)
	_add_button(root, tr("New Career"), _show_new_career)
	_add_button(root, tr("Load Career"), _show_load_menu)
	_add_button(root, tr("Settings"), _show_settings)
	_add_button(root, tr("How to play"), _show_help)
	_add_button(root, tr("Club database editor"), func(): preload("res://game/career/database_editor.gd").new(self, custom_database).show())
	_add_button(root, tr("Quit"), func(): get_tree().quit())

func _show_help() -> void:
	var box := _clear()
	_add_heading(box, tr("Your first season"), 28)
	for tip in [
		"1. Create a career, enter your manager name and choose a club.",
		"2. Review Squad, Medical and Tactics before the first fixture. Set your training intensity.",
		"3. Use Scouting and player profiles to find recruits. Check your transfer and wage budgets before making an offer.",
		"4. Register your squad under Competitions. Continue advances one day; matches are simulated when their date arrives.",
		"5. Read your Inbox and use Match Analysis to review your most recent match. League tables appear under Competitions.",
		"6. Save regularly. At the July boundary, a completed season rolls forward with new fixtures, finances and player development."]:
		var label := Label.new()
		label.text = tr(tip)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	_add_button(box, tr("Back"), _show_main_menu)

func _show_settings() -> void:
	var root := _clear()
	_add_heading(root, tr("Settings"), 28)
	var language := OptionButton.new()
	for code in LocalizationServiceClass.SUPPORTED: language.add_item(String(code).to_upper())
	language.select(maxi(0, LocalizationServiceClass.SUPPORTED.find(String(settings.get("language", "en")))))
	root.add_child(_labeled("Language", language))
	var ui_scale := HSlider.new(); ui_scale.min_value = 0.75; ui_scale.max_value = 2.0; ui_scale.step = 0.05; ui_scale.value = float(settings.get("ui_scale",1.0)); root.add_child(_labeled("UI scale", ui_scale))
	var font_scale := HSlider.new(); font_scale.min_value = 0.8; font_scale.max_value = 2.0; font_scale.step = 0.05; font_scale.value = float(settings.get("font_scale",1.0)); root.add_child(_labeled("Font scale", font_scale))
	var contrast := CheckBox.new(); contrast.text = tr("High contrast"); contrast.button_pressed = bool(settings.get("high_contrast",false)); root.add_child(contrast)
	var motion := CheckBox.new(); motion.text = tr("Reduce motion"); motion.button_pressed = bool(settings.get("reduce_motion",false)); root.add_child(motion)
	var reader := CheckBox.new(); reader.text = tr("Screen-reader labels"); reader.button_pressed = bool(settings.get("screen_reader_labels",true)); root.add_child(reader)
	var autosave := CheckBox.new(); autosave.text = tr("Autosave"); autosave.button_pressed = bool(settings.get("autosave",true)); root.add_child(autosave)
	var interval := SpinBox.new(); interval.min_value = 1; interval.max_value = 30; interval.value = int(settings.get("autosave_interval_days",7)); root.add_child(_labeled("Autosave interval (days)", interval))
	var row := HBoxContainer.new(); root.add_child(row)
	_add_button(row, tr("Apply"), func():
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
	_add_button(row, tr("Reset"), func(): settings = settings_store.defaults(); settings_store.save(SETTINGS_PATH, settings); _apply_runtime_settings(); _show_settings())
	_add_button(row, tr("Back"), _show_main_menu)

func _show_new_career() -> void:
	var root := _clear()
	_add_heading(root, tr("New Career"), 28)
	var expanded := CheckBox.new()
	var expanded_count := 24 if expanded_world else 12
	expanded.text = tr("Expanded world: %d countries (longer processing)") % expanded_count
	expanded.button_pressed = expanded_world
	root.add_child(expanded)
	expanded.toggled.connect(func(enabled: bool): expanded_world = enabled; _show_new_career())
	var name_label := Label.new(); name_label.text = tr("Manager name"); root.add_child(name_label)
	_manager_name_input = LineEdit.new(); _manager_name_input.text = tr("Manager"); _manager_name_input.placeholder_text = "Enter manager name"; _manager_name_input.custom_minimum_size = Vector2(640, 0); root.add_child(_manager_name_input)
	# Loading state while the launch database is assembled.
	var loading := Label.new(); loading.text = tr("Loading database…"); root.add_child(loading)
	await get_tree().process_frame
	var preview: Dictionary = LaunchCatalogClass.new().build(0, expanded_world)
	loading.queue_free()
	if preview.get("clubs", []).is_empty():
		var empty := Label.new(); empty.text = tr("No clubs available. The launch database failed to load."); empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(empty)
		_add_button(root, tr("Back"), _show_main_menu)
		return
	if not custom_database.is_empty():
		preload("res://tools/modding/mod_loader.gd").new().apply_mod(preview, custom_database)
		_add_button(root, tr("Clear custom database"), func(): custom_database = {}; _show_new_career())
	_wizard_preview = preview
	_wizard_countries = preview.get("countries", [])
	var default_country := String(preview.get("default_country_id", "eng"))
	if _wizard_country_id == "" or _country_name(_wizard_countries, _wizard_country_id) == _wizard_country_id:
		# Keep the previous selection when possible; otherwise default to England.
		var known := false
		for country in _wizard_countries:
			if String(country.get("id", "")) == _wizard_country_id: known = true
		if not known: _wizard_country_id = default_country if default_country != "" else String(_wizard_countries[0].get("id", ""))
	var country_label := Label.new(); country_label.text = tr("Nation (default: England, featured: Spain)"); root.add_child(country_label)
	_country_selector = OptionButton.new(); _country_selector.custom_minimum_size = Vector2(640, 0)
	var selected_country := 0
	for i in range(_wizard_countries.size()):
		var country: Dictionary = _wizard_countries[i]
		var marker := ""
		if String(country.get("id", "")) == default_country: marker = " ★"
		elif String(country.get("id", "")) in preview.get("featured_country_ids", []): marker = " ◆"
		_country_selector.add_item("%s%s" % [String(country.get("name", "")), marker])
		if String(country.get("id", "")) == _wizard_country_id: selected_country = i
	_country_selector.select(selected_country)
	root.add_child(_country_selector)
	_country_selector.item_selected.connect(func(index: int): _wizard_country_id = String(_wizard_countries[index].get("id", "")); _refresh_wizard_clubs())
	var club_label := Label.new(); club_label.text = tr("Choose club — filtered by nation"); root.add_child(club_label)
	_club_selector = OptionButton.new(); _club_selector.custom_minimum_size = Vector2(640, 0)
	root.add_child(_club_selector)
	_refresh_wizard_clubs()
	var database_info := Label.new()
	database_info.text = tr("%d countries • %d clubs • multi-tier leagues, domestic cups, continental tiers, Club World Cup and international pathways") % [preview.get("countries", []).size(), preview.get("clubs", []).size()]
	database_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(database_info)
	var hint := Label.new()
	hint.text = tr("Tip: England is the default nation; Spain is the featured alternative. Continental qualification follows league position after year one.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)
	var buttons := HBoxContainer.new(); root.add_child(buttons)
	_add_button(buttons, tr("Create Career"), _create_career_from_wizard)
	_add_button(buttons, tr("Back"), _show_main_menu)

func _refresh_wizard_clubs() -> void:
	if _club_selector == null: return
	_club_selector.clear()
	_wizard_clubs = LaunchCatalogClass.new().clubs_for_country(_wizard_preview, _wizard_country_id)
	if _wizard_clubs.is_empty():
		_club_selector.add_item(tr("No clubs in this nation"))
		_club_selector.disabled = true
		return
	_club_selector.disabled = false
	for club in _wizard_clubs:
		_club_selector.add_item("%s — %s" % [String(club.get("name", "Club")), String(club.get("competition_name", "Division"))])
	_club_selector.select(0)

func _create_career_from_wizard() -> void:
	if _wizard_clubs.is_empty() or (_club_selector != null and _club_selector.disabled):
		_show_error("No club is selected. Choose a nation with clubs first.")
		return
	active_slot = slots.first_available_slot()
	var manager_name := _manager_name_input.text.strip_edges() if _manager_name_input != null else "Manager"
	if manager_name == "": manager_name = "Manager"
	var selected := clampi(_club_selector.selected, 0, maxi(0, _wizard_clubs.size() - 1))
	var club_id := String(_wizard_clubs[selected].get("id", "")) if not _wizard_clubs.is_empty() else ""
	var mods: Array = [] if custom_database.is_empty() else [custom_database.duplicate(true)]
	var snap: Dictionary = await _run_job(session.new_career.bind(manager_name, club_id, 12345, 0, mods, expanded_world), "Creating your football world")
	if snap.is_empty() or snap.has("error"):
		_show_main_menu()
		_show_error("The career could not be created. Please try again.")
		return
	InboxServiceClass.new().add_message(session.world, "board", "Welcome to the club", "Your first season is ready. Review the squad, tactics, training and recruitment before the opening fixture.")
	_show_career()

func _show_load_menu() -> void:
	var root := _clear()
	_add_heading(root, tr("Load Career"), 28)
	var any := false
	for meta in slots.list_slots(10):
		if not bool(meta.get("exists", false)): continue
		any = true
		var line := HBoxContainer.new(); root.add_child(line)
		var label := "Slot %d — %s / %s / %s" % [int(meta.slot), String(meta.manager), String(meta.club), String(meta.date)]
		_add_button(line, label, _load_slot.bind(int(meta.slot)))
		_add_button(line, tr("Delete"), _delete_slot.bind(int(meta.slot)))
	if not any:
		var empty := Label.new(); empty.text = tr("No saved careers yet."); root.add_child(empty)
	_add_button(root, tr("Back"), _show_main_menu)

func _delete_slot(slot: int) -> void:
	_confirm("Delete career in slot %d and its backup? This cannot be undone." % slot, func():
		var err: Error = slots.delete_slot(slot)
		if err == OK and active_slot == slot: active_slot = 0
		_show_load_menu()
		if err != OK: _show_error("Could not delete the career (%d)." % err)
	)

func _load_slot(slot: int) -> void:
	var path := slots.slot_path(slot)
	if session.load_career(path) != OK:
		_show_error("This career could not be loaded. Its save and backup may be damaged. Your current career has not been replaced."); return
	active_slot = slot
	_show_career()

func _show_career() -> void:
	var root := _clear()
	var snap: Dictionary = session.snapshot()
	var dashboard: Dictionary = query.dashboard(session.world, session.managed_club_id)
	var club: Dictionary = dashboard.get("club", {})
	_add_heading(root, tr("%s — %s") % [String(club.get("name", "Club")), String(snap.date)], 26)
	var buttons := HBoxContainer.new(); root.add_child(buttons)
	_add_button(buttons, tr("Continue"), _advance_day)
	_add_button(buttons, tr("Save Slot %d") % active_slot if active_slot > 0 else "Save Career", _save)
	_add_button(buttons, tr("Save As"), _show_save_as)
	_add_button(buttons, tr("Settings"), _show_settings)
	_add_button(buttons, tr("Main Menu"), _show_main_menu)
	status = Label.new(); status.text = tr("Manager: %s  •  Season %d  •  Inbox %d") % [String(session.manager.get("name", "Manager")), int(snap.season_year), int(dashboard.get("unread_messages",0))]; root.add_child(status)
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
	views.add_competitions(tabs)
	_add_inbox_tab(tabs)
	views.add_staff(tabs)
	views.add_finances(tabs)
	views.add_search(tabs)
	views.add_match_analysis(tabs)

func _show_save_as() -> void:
	var root := _clear()
	_add_heading(root, tr("Save Career As"), 28)
	for slot in range(1, 11):
		var meta: Dictionary = slots.metadata(slot)
		var label := "Slot %d" % slot
		if bool(meta.get("exists",false)): label += " — overwrite %s / %s" % [String(meta.get("manager","")),String(meta.get("date",""))]
		_add_button(root, label, _request_save_to_slot.bind(slot))
	_add_button(root, tr("Back"), _show_career)

func _save_to_slot(slot: int) -> void:
	var err := slots.save_slot(slot, session.world, session.history, session.manager)
	if err == OK: active_slot = slot
	_show_career()
	if status != null: status.text = tr("Saved to slot %d") % slot if err == OK else "Save failed (%d)" % err

func _request_save_to_slot(slot: int) -> void:
	if FileAccess.file_exists(slots.slot_path(slot)) or FileAccess.file_exists(slots.slot_path(slot) + ".bak"):
		_confirm("Overwrite the career in slot %d?" % slot, _save_to_slot.bind(slot))
	else:
		_save_to_slot(slot)

func _confirm(message: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(func(): action.call(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(480, 180))

func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Career notice"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(520, 180))

func _run_job(job: Callable, message: String) -> Dictionary:
	if _busy: return {"error":ERR_BUSY}
	_busy = true
	var box := _clear()
	_add_heading(box, message, 28)
	var progress := Label.new()
	progress.text = tr("Please wait. Your career is being processed.")
	box.add_child(progress)
	_worker = Thread.new()
	var err := _worker.start(job)
	if err != OK:
		_busy = false
		_worker = null
		return {"error":err,"message":"Unable to start the simulation worker."}
	while _worker.is_alive():
		await get_tree().process_frame
		progress.text = tr("Processing") + ".".repeat(1 + int(Time.get_ticks_msec() / 500) % 3)
	var result: Dictionary = _worker.wait_to_finish()
	_worker = null
	_busy = false
	return result

func _exit_tree() -> void:
	if _worker != null and _worker.is_started(): _worker.wait_to_finish()

func _add_inbox_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new(); scroll.name = "Inbox"
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(920, 480); scroll.add_child(box)
	var messages: Array = InboxServiceClass.new().unread(session.world)
	if messages.is_empty():
		var empty := Label.new(); empty.text = tr("Inbox clear."); box.add_child(empty)
	for message in messages:
		var title := Label.new(); title.text = tr("%s — %s") % [String(message.get("category", "info")).to_upper(), String(message.get("title", "Message"))]; box.add_child(title)
		var body := Label.new(); body.text = String(message.get("body", "")); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(body)
		var row := HBoxContainer.new(); box.add_child(row)
		if not bool(message.get("read",false)): _add_button(row, tr("Mark read"), _mark_message_read.bind(int(message.id)))
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
	var result: Dictionary = await _run_job(DayRunnerClass.new().advance_day.bind(session.world, session.history, session.seed + int(session.world.get("day_index",0))*17 + int(session.world.get("season_year",2026))*101), "Advancing your career")
	if result.has("error"):
		_show_career()
		_show_error(String(result.get("message", "Unable to advance day"))); return
	var save_error: Error = OK
	if active_slot > 0 and bool(settings.get("autosave", true)) and int(session.world.get("day_index", 0)) % maxi(1, int(settings.get("autosave_interval_days", 7))) == 0:
		save_error = slots.save_slot(active_slot, session.world, session.history, session.manager)
	_show_career()
	if save_error != OK: status.text = tr("Autosave failed (%d). Please save your career manually.") % save_error
	elif active_slot == 0: status.text = tr("All save slots are occupied. Use Save As to choose a slot.")

func _save() -> void:
	if active_slot == 0:
		_show_save_as()
		return
	var err := slots.save_slot(active_slot, session.world, session.history, session.manager)
	status.text = tr("Saved to slot %d") % active_slot if err == OK else "Save failed (%d)" % err

func _apply_runtime_settings() -> void:
	localization.install(String(settings.get("language", "en")))
	self.scale = Vector2.ONE
	var new_theme := Theme.new()
	new_theme.default_font_size = int(16 * float(settings.get("font_scale", 1.0)) * float(settings.get("ui_scale", 1.0)))
	if bool(settings.get("high_contrast", false)):
		for control_type in ["Label", "Button", "CheckBox", "LineEdit", "OptionButton"]:
			new_theme.set_color("font_color", control_type, Color.WHITE)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color.BLACK
		normal.border_color = Color.WHITE
		normal.set_border_width_all(2)
		for state in ["normal", "hover", "pressed"]: new_theme.set_stylebox(state, "Button", normal)
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color.YELLOW
		focus.set_border_width_all(3)
		new_theme.set_stylebox("focus", "Button", focus)
	theme = new_theme

func _country_name(countries: Array, country_id: String) -> String:
	for country in countries:
		if String(country.get("id", "")) == country_id: return String(country.get("name", country_id))
	return country_id

func _labeled(text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new(); label.text = tr(text); label.custom_minimum_size.x = 220; row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _add_heading(parent: Control, text: String, size: int) -> void:
	var label := Label.new(); label.text = tr(text); label.add_theme_font_size_override("font_size", int(size * float(settings.get("font_scale", 1.0)))); parent.add_child(label)

func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new(); button.text = tr(text); button.pressed.connect(callback); parent.add_child(button)

extends "res://game/career/career_app.gd"

const RegistryClass = preload("res://game/career/career_screen_registry.gd")
const RegistryCareerViewsClass = preload("res://game/career/career_views.gd")

var _screen_registry = RegistryClass.new()

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
	_manager_name_input.focus_entered.connect(func() -> void:
		if _manager_name_input.text == tr("Manager"):
			_manager_name_input.select_all()
	)
	var loading := Label.new(); loading.text = tr("Loading database…"); root.add_child(loading)
	await get_tree().process_frame
	var preview: Dictionary = LaunchCatalogClass.new().build(0, expanded_world)
	if not is_instance_valid(root) or root != content or root.is_queued_for_deletion():
		return
	if is_instance_valid(loading) and not loading.is_queued_for_deletion():
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

func _show_settings() -> void:
	var root := _clear()
	_add_heading(root, tr("Settings"), 28)
	var language := OptionButton.new()
	for code in LocalizationServiceClass.SUPPORTED: language.add_item(String(code).to_upper())
	language.select(maxi(0, LocalizationServiceClass.SUPPORTED.find(String(settings.get("language", "en")))))
	root.add_child(_labeled("Language", language))
	var ui_scale := HSlider.new(); ui_scale.name = "UIScaleSetting"; ui_scale.min_value = 0.85; ui_scale.max_value = 2.0; ui_scale.step = 0.05; ui_scale.value = float(settings.get("ui_scale",1.0)); root.add_child(_labeled("UI scale", ui_scale))
	var font_scale := HSlider.new(); font_scale.name = "FontScaleSetting"; font_scale.min_value = 0.9; font_scale.max_value = 2.0; font_scale.step = 0.05; font_scale.value = float(settings.get("font_scale",1.0)); root.add_child(_labeled("Font scale", font_scale))
	var contrast := CheckBox.new(); contrast.name = "HighContrastSetting"; contrast.text = tr("High contrast"); contrast.button_pressed = bool(settings.get("high_contrast",false)); root.add_child(contrast)
	var motion := CheckBox.new(); motion.name = "ReduceMotionSetting"; motion.text = tr("Reduce motion"); motion.button_pressed = bool(settings.get("reduce_motion",false)); root.add_child(motion)
	var reader := CheckBox.new(); reader.name = "ScreenReaderSetting"; reader.text = tr("Screen-reader labels"); reader.button_pressed = bool(settings.get("screen_reader_labels",true)); root.add_child(reader)
	var autosave := CheckBox.new(); autosave.name = "AutosaveSetting"; autosave.text = tr("Autosave"); autosave.button_pressed = bool(settings.get("autosave",true)); root.add_child(autosave)
	var interval := SpinBox.new(); interval.name = "AutosaveIntervalSetting"; interval.min_value = 1; interval.max_value = 30; interval.value = int(settings.get("autosave_interval_days",7)); root.add_child(_labeled("Autosave interval (days)", interval))
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

func _show_career() -> void:
	var root := _clear()
	var snap: Dictionary = session.snapshot()
	var dashboard: Dictionary = query.dashboard(session.world, session.managed_club_id)
	var club: Dictionary = dashboard.get("club", {})
	_add_heading(root, tr("%s — %s") % [String(club.get("name", "Club")), String(snap.date)], 26)
	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	var legacy_continue := Button.new()
	legacy_continue.name = "LegacyCareerContinue"
	legacy_continue.text = tr("Continue")
	legacy_continue.pressed.connect(_advance_day)
	buttons.add_child(legacy_continue)
	_add_button(buttons, tr("Save Slot %d") % active_slot if active_slot > 0 else "Save Career", _save)
	_add_button(buttons, tr("Save As"), _show_save_as)
	_add_button(buttons, tr("Settings"), _show_settings)
	_add_button(buttons, tr("Main Menu"), _show_main_menu)
	status = Label.new()
	status.text = tr("Manager: %s  •  Season %d  •  Inbox %d") % [String(session.manager.get("name", "Manager")), int(snap.season_year), int(dashboard.get("unread_messages", 0))]
	root.add_child(status)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	var views = RegistryCareerViewsClass.new(self, session)
	for descriptor in _screen_registry.tab_plan():
		var builder := String(descriptor.get("builder", ""))
		var owner := String(descriptor.get("owner", "views"))
		if owner == "app":
			if has_method(builder):
				call(builder, tabs)
			else:
				push_error("Career tab builder missing on app: %s" % builder)
		elif views.has_method(builder):
			views.call(builder, tabs)
		else:
			push_error("Career tab builder missing on views: %s" % builder)

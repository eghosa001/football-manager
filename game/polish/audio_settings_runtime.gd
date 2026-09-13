extends Node

var _next_scan: int = 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 500
	_scan()

func _scan() -> void:
	var app: Node = _find_app(get_tree().root)
	if app == null:
		return
	var content = app.get("content")
	if not content is VBoxContainer:
		return
	var box: VBoxContainer = content as VBoxContainer
	if box.has_meta("audio_settings_added"):
		return
	if not _is_settings_screen(box):
		return
	box.set_meta("audio_settings_added", true)
	var settings: Dictionary = app.get("settings")
	var heading := Label.new()
	heading.text = "Audio"
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)
	var mute := CheckBox.new()
	mute.text = "Mute all audio"
	mute.button_pressed = bool(settings.get("mute_audio", false))
	mute.toggled.connect(_mute_changed.bind(settings))
	box.add_child(mute)
	_add_slider(box, settings, "master_volume", "Master volume", 1.0)
	_add_slider(box, settings, "music_volume", "Music", 0.75)
	_add_slider(box, settings, "effects_volume", "Effects", 0.85)
	_add_slider(box, settings, "crowd_volume", "Crowd", 0.8)
	_add_slider(box, settings, "interface_volume", "Interface", 0.8)
	_apply_audio(settings)

func _add_slider(parent: VBoxContainer, settings: Dictionary, key: String, title: String, default_value: float) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 220
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(settings.get(key, default_value))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_volume_changed.bind(settings, key))
	row.add_child(slider)
	parent.add_child(row)

func _mute_changed(value: bool, settings: Dictionary) -> void:
	settings["mute_audio"] = value
	_apply_audio(settings)

func _volume_changed(value: float, settings: Dictionary, key: String) -> void:
	settings[key] = value
	_apply_audio(settings)

func _apply_audio(settings: Dictionary) -> void:
	var master: int = AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, bool(settings.get("mute_audio", false)))
		AudioServer.set_bus_volume_db(master, linear_to_db(maxf(0.0001, float(settings.get("master_volume", 1.0)))))
	_apply_bus("Music", float(settings.get("music_volume", 0.75)))
	_apply_bus("SFX", float(settings.get("effects_volume", 0.85)))
	_apply_bus("Crowd", float(settings.get("crowd_volume", 0.8)))
	_apply_bus("UI", float(settings.get("interface_volume", 0.8)))

func _apply_bus(bus_name: String, value: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, value)))

func _is_settings_screen(box: VBoxContainer) -> bool:
	for child in box.get_children():
		if child is Label and (child as Label).text.strip_edges().to_lower() == "settings":
			return true
	return false

func _find_app(node: Node) -> Node:
	var script = node.get_script()
	if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
		return node
	for child in node.get_children():
		var found: Node = _find_app(child)
		if found != null:
			return found
	return null

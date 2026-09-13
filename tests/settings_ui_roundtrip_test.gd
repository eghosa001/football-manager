extends SceneTree

const SettingsStore = preload("res://application/settings/settings_store.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings_path := "user://settings.json"
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	var scene = load("res://game/scenes/career_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._show_settings()
	await process_frame
	var ui_scale := scene.find_child("UIScaleSetting", true, false) as HSlider
	var font_scale := scene.find_child("FontScaleSetting", true, false) as HSlider
	var contrast := scene.find_child("HighContrastSetting", true, false) as CheckBox
	var motion := scene.find_child("ReduceMotionSetting", true, false) as CheckBox
	var autosave := scene.find_child("AutosaveSetting", true, false) as CheckBox
	var interval := scene.find_child("AutosaveIntervalSetting", true, false) as SpinBox
	assert(ui_scale != null and font_scale != null and contrast != null and motion != null and autosave != null and interval != null)
	assert(is_equal_approx(ui_scale.min_value, 0.85))
	assert(is_equal_approx(font_scale.min_value, 0.9))
	ui_scale.value = 1.25
	font_scale.value = 1.35
	contrast.button_pressed = true
	motion.button_pressed = true
	autosave.button_pressed = true
	interval.value = 11
	var apply := _find_button(scene, "Apply")
	assert(apply != null)
	apply.pressed.emit()
	await process_frame
	var loaded := SettingsStore.new().load(settings_path)
	assert(is_equal_approx(float(loaded.ui_scale), 1.25))
	assert(is_equal_approx(float(loaded.font_scale), 1.35))
	assert(bool(loaded.high_contrast))
	assert(bool(loaded.reduce_motion))
	assert(bool(loaded.autosave))
	assert(int(loaded.autosave_interval_days) == 11)
	scene.queue_free()
	await process_frame
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	print("[TEST] SETTINGS UI ROUNDTRIP PASS")
	quit(0)

func _find_button(node: Node, text: String) -> Button:
	if node is Button and String((node as Button).text) == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

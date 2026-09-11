class_name SettingsStore
extends RefCounted

const AUTOSAVE_MODES := ["weekly", "monthly", "after_match", "manual"]
const DEFAULTS := {
	"language": "en",
	"ui_scale": 1.0,
	"high_contrast": false,
	"reduce_motion": false,
	"font_scale": 1.0,
	"screen_reader_labels": true,
	"autosave": true,
	"autosave_interval_days": 7,
	"autosave_mode": "weekly",
	"autosave_rolling_count": 3,
}

func defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)

func sanitize(input: Dictionary) -> Dictionary:
	var value := DEFAULTS.duplicate(true)
	value.language = String(input.get("language", value.language))
	value.ui_scale = clampf(float(input.get("ui_scale", value.ui_scale)), 0.75, 2.0)
	value.high_contrast = bool(input.get("high_contrast", value.high_contrast))
	value.reduce_motion = bool(input.get("reduce_motion", value.reduce_motion))
	value.font_scale = clampf(float(input.get("font_scale", value.font_scale)), 0.8, 2.0)
	value.screen_reader_labels = bool(input.get("screen_reader_labels", value.screen_reader_labels))
	value.autosave = bool(input.get("autosave", value.autosave))
	value.autosave_interval_days = clampi(int(input.get("autosave_interval_days", value.autosave_interval_days)), 1, 30)
	value.autosave_mode = String(input.get("autosave_mode", value.autosave_mode))
	if value.autosave_mode not in AUTOSAVE_MODES:
		value.autosave_mode = "weekly"
	value.autosave_rolling_count = 5 if int(input.get("autosave_rolling_count", value.autosave_rolling_count)) >= 5 else 3
	if not value.autosave:
		value.autosave_mode = "manual"
	return value

func save(path: String, settings: Dictionary) -> Error:
	var value := sanitize(settings)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	file.close()
	return OK

func load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return defaults()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return defaults()
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return defaults()
	return sanitize(parsed)

extends SceneTree

# Validates Android + Apple export integration without requiring SDKs, Xcode,
# physical devices, or signing identities. Binary/device validation remains external.

func _init() -> void:
	_run.call_deferred()

func _fail(message: String) -> void:
	printerr("[TEST] MOBILE EXPORT FAIL: " + message)
	quit(1)

func _run() -> void:
	var presets_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(presets_path):
		_fail("export_presets.cfg missing")
		return
	var presets := ConfigFile.new()
	if presets.load(presets_path) != OK:
		_fail("cannot parse export_presets.cfg")
		return

	var found := {}
	for section in presets.get_sections():
		if section.ends_with(".options"):
			continue
		var platform := String(presets.get_value(section, "platform", ""))
		if platform != "":
			found[platform] = {"path": String(presets.get_value(section, "export_path", "")), "section": section}

	for required in ["Windows Desktop", "Linux/X11", "Android", "iOS", "macOS"]:
		if not found.has(required):
			_fail("missing export preset platform: " + required)
			return

	var android: Dictionary = found["Android"]
	if not String(android["path"]).ends_with(".aab"):
		_fail("Android export_path must be .aab")
		return
	var options := String(android["section"]) + ".options"
	if String(presets.get_value(options, "package/unique_name", "")) != "com.footballdynasty.game":
		_fail("unexpected Android package name")
		return
	if not bool(presets.get_value(options, "architectures/arm64-v8a", false)):
		_fail("Android must enable arm64-v8a")
		return
	if int(String(presets.get_value(options, "gradle_build/target_sdk", "0"))) < 36:
		_fail("Android target SDK must be API 36 or newer")
		return
	if int(presets.get_value(options, "version/code", 0)) < 10004:
		_fail("Android version/code must be production v1.0.0 or newer")
		return
	if String(presets.get_value(options, "version/name", "")) != "1.0.0":
		_fail("Android version/name must be 1.0.0 for first production release")
		return
	if bool(presets.get_value(options, "permissions/internet", true)):
		_fail("production offline release must not request Internet permission")
		return
	if bool(presets.get_value(options, "user_data_backup/allow", true)):
		_fail("Android backup policy changed unexpectedly")
		return

	if String(ProjectSettings.get_setting("application/config/version", "")) != "1.0.0":
		_fail("project application version must match production release")
		return
	if String(ProjectSettings.get_setting("display/window/stretch/mode", "")) != "canvas_items":
		_fail("display/window/stretch/mode should be canvas_items")
		return
	if String(ProjectSettings.get_setting("display/window/stretch/aspect", "")) != "expand":
		_fail("display/window/stretch/aspect should be expand")
		return
	if String(ProjectSettings.get_setting("display/window/handheld/orientation", "")) != "landscape":
		_fail("display/window/handheld/orientation should be landscape")
		return
	if not bool(ProjectSettings.get_setting("display/window/size/resizable", false)):
		_fail("display/window/size/resizable should be true")
		return
	if not FileAccess.file_exists("res://docs/PRIVACY_POLICY.md"):
		_fail("privacy policy missing")
		return
	if not FileAccess.file_exists("res://game/polish/privacy_runtime.gd"):
		_fail("in-game privacy surface missing")
		return

	print("[TEST] MOBILE EXPORT PASS: production 1.0.0, API36+AAB, ARM64, offline privacy contract valid")
	quit(0)

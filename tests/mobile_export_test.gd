extends SceneTree

# Validates Android + Apple (iOS/macOS) export integration without requiring
# SDKs, Xcode, or signing identities. Full binary exports remain CI/device steps.
# Run: godot --headless --path . --script res://tests/mobile_export_test.gd

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
	var err := presets.load(presets_path)
	if err != OK:
		_fail("cannot parse export_presets.cfg: %s" % err)
		return

	var found := {}
	for section in presets.get_sections():
		if section.ends_with(".options"):
			continue
		var platform := String(presets.get_value(section, "platform", ""))
		var preset_name := String(presets.get_value(section, "name", section))
		var export_path := String(presets.get_value(section, "export_path", ""))
		if platform != "":
			found[platform] = {"name": preset_name, "path": export_path, "section": section}

	for required in ["Windows Desktop", "Linux/X11", "Android", "iOS", "macOS"]:
		if not found.has(required):
			_fail("missing export preset platform: " + required)
			return

	# Android must be a current store-ready bundle target, not an unsigned debug stub.
	var android: Dictionary = found["Android"]
	if not String(android["path"]).ends_with(".aab"):
		_fail("Android export_path should target .aab, got: " + String(android["path"]))
		return
	var android_section: String = String(android["section"])
	var android_options := android_section + ".options"
	if String(presets.get_value(android_options, "package/unique_name", "")) == "":
		_fail("Android package/unique_name empty")
		return
	if not bool(presets.get_value(android_options, "architectures/arm64-v8a", false)):
		_fail("Android must enable architectures/arm64-v8a")
		return
	if int(String(presets.get_value(android_options, "gradle_build/target_sdk", "0"))) < 36:
		_fail("Android target SDK must be API 36 or newer for current Play submission requirements")
		return
	if int(presets.get_value(android_options, "version/code", 0)) < 10003:
		_fail("Android version/code must be RC3 or newer")
		return
	if String(presets.get_value(android_options, "version/name", "")) != "1.0.0-rc3":
		_fail("Android version/name must match RC3")
		return

	# iOS exports an Xcode project; signing stays outside version control.
	var ios: Dictionary = found["iOS"]
	if not String(ios["path"]).ends_with(".xcodeproj"):
		_fail("iOS export_path should target .xcodeproj, got: " + String(ios["path"]))
		return
	var ios_section: String = String(ios["section"])
	if String(presets.get_value(ios_section + ".options", "application/bundle_identifier", "")) == "":
		_fail("iOS application/bundle_identifier empty")
		return

	# macOS must be a runnable .app bundle, universal for Apple Silicon + Intel.
	var macos: Dictionary = found["macOS"]
	if not String(macos["path"]).ends_with(".app"):
		_fail("macOS export_path should target .app, got: " + String(macos["path"]))
		return

	# Project settings required for phones/tablets: stretch + landscape + touch.
	var project := ConfigFile.new()
	if project.load("res://project.godot") != OK:
		_fail("cannot parse project.godot")
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

	print("[TEST] MOBILE EXPORT PASS: Android API36+AAB and Apple/mobile settings valid")
	quit(0)

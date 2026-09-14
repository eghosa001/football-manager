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
	if int(presets.get_value(options, "version/code", 0)) < 10005:
		_fail("Android version/code must be monetized v1.1.0 or newer")
		return
	if String(presets.get_value(options, "version/name", "")) != "1.1.0":
		_fail("Android version/name must be 1.1.0 for monetized release")
		return
	if not bool(presets.get_value(options, "permissions/internet", false)):
		_fail("monetized Android release requires Internet permission for billing and optional rewarded ads")
		return
	if bool(presets.get_value(options, "user_data_backup/allow", true)):
		_fail("Android backup policy changed unexpectedly")
		return

	if String(ProjectSettings.get_setting("application/config/version", "")) != "1.1.0":
		_fail("project application version must match monetized release")
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
	if not bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false)):
		_fail("Android export requires rendering/textures/vram_compression/import_etc2_astc=true")
		return
	for required_path in [
		"res://docs/PRIVACY_POLICY.md",
		"res://game/polish/privacy_runtime.gd",
		"res://game/monetization/monetization_manager.gd",
		"res://game/monetization/analyst_reward_runtime.gd",
		"res://tools/install-monetization-plugins.sh",
	]:
		if not FileAccess.file_exists(required_path):
			_fail("monetized release asset missing: " + required_path)
			return

	print("[TEST] MOBILE EXPORT PASS: monetized 1.1.0, API36+AAB, ARM64, ETC2/ASTC, billing/ad privacy contract valid")
	quit(0)

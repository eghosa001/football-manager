extends SceneTree

var failures := 0

func _initialize() -> void:
	_check(ProjectSettings.get_setting("display/window/stretch/mode", "") == "canvas_items", "responsive canvas stretch is enabled")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect", "") == "expand", "responsive aspect expansion is enabled")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "") == "gl_compatibility", "mobile compatibility renderer is configured")
	var file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	_check(file != null, "export presets are readable")
	if file != null:
		var presets := file.get_as_text()
		_check(presets.contains("name=\"Android\""), "Android export preset exists")
		_check(presets.contains("platform=\"Android\""), "Android platform is configured")
		_check(presets.contains("architectures/arm64-v8a=true"), "Android ARM64 export is enabled")
		_check(presets.contains("name=\"iOS\""), "iOS export preset exists")
		_check(presets.contains("platform=\"iOS\""), "iOS platform is configured")
		_check(presets.contains("application/bundle_identifier=\"com.eghosa001.footballdynasty\""), "iOS bundle identifier is stable")
	if failures == 0:
		print("[TEST] MOBILE PLATFORM CONTRACT PASS")
		quit(0)
	else:
		push_error("Mobile platform contract failed with %d assertion(s)." % failures)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		failures += 1
		push_error("[FAIL] %s" % label)

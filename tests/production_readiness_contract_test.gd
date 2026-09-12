extends SceneTree

func _init() -> void:
	var project := ConfigFile.new()
	assert(project.load("res://project.godot") == OK)
	assert(String(project.get_value("application", "config/version", "")) == "1.0.0-rc3")
	assert(String(project.get_value("autoload", "UIReadabilityRuntime", "")) != "")
	assert(String(project.get_value("display", "window/stretch/mode", "")) == "canvas_items")
	assert(String(project.get_value("display", "window/stretch/aspect", "")) == "expand")

	var required := [
		"res://.github/workflows/ci.yml",
		"res://.github/workflows/hosted-validation.yml",
		"res://.github/workflows/debug-apk.yml",
		"res://.github/workflows/fresh-windows-release.yml",
		"res://tests/ui_readability_test.gd",
		"res://tests/performance_baseline_test.gd",
		"res://tests/long_save_growth_test.gd",
		"res://tools/release-smoke.sh",
		"res://tools/release-smoke.ps1",
	]
	for path in required:
		assert(FileAccess.file_exists(path), "required production asset missing: %s" % path)

	var ci := FileAccess.get_file_as_string("res://.github/workflows/ci.yml")
	assert("clean: true" in ci)
	assert("tests/ui_readability_test.gd" in ci)
	assert("tests/performance_baseline_test.gd" in ci)

	var hosted := FileAccess.get_file_as_string("res://.github/workflows/hosted-validation.yml")
	assert("--export-release 'Linux/X11'" in hosted or "--export-release \"Linux/X11\"" in hosted)
	assert("release-smoke.sh" in hosted)

	var android := FileAccess.get_file_as_string("res://.github/workflows/debug-apk.yml")
	assert("game/**" in android)
	assert("export_presets.cfg" in android)

	print("[TEST] PRODUCTION READINESS CONTRACT PASS")
	quit(0)

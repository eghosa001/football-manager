extends SceneTree

func _init() -> void:
	var project := ConfigFile.new()
	assert(project.load("res://project.godot") == OK)
	assert(String(project.get_value("application", "config/version", "")) == "1.0.0-rc3")
	assert(String(project.get_value("autoload", "UIReadabilityRuntime", "")) != "")
	assert(String(project.get_value("autoload", "NavigationRuntime", "")) != "")
	assert(String(project.get_value("display", "window/stretch/mode", "")) == "canvas_items")
	assert(String(project.get_value("display", "window/stretch/aspect", "")) == "expand")

	var required := [
		"res://.github/workflows/ci.yml",
		"res://.github/workflows/hosted-validation.yml",
		"res://.github/workflows/debug-apk.yml",
		"res://.github/workflows/fresh-windows-release.yml",
		"res://.github/workflows/rc3-heavy-gates.yml",
		"res://tests/ui_readability_test.gd",
		"res://tests/navigation_responsive_test.gd",
		"res://tests/performance_baseline_test.gd",
		"res://tests/long_session_memory_test.gd",
		"res://tests/long_save_growth_test.gd",
		"res://tools/release-smoke.sh",
		"res://tools/release-smoke.ps1",
	]
	for path in required:
		assert(FileAccess.file_exists(path), "required production asset missing: %s" % path)

	var presets := ConfigFile.new()
	assert(presets.load("res://export_presets.cfg") == OK)
	assert(String(presets.get_value("preset.0.options", "application/file_version", "")) == "1.0.0.3")
	assert(int(presets.get_value("preset.2.options", "version/code", 0)) == 10003)
	assert(String(presets.get_value("preset.2.options", "version/name", "")) == "1.0.0-rc3")
	assert(String(presets.get_value("preset.3.options", "application/version", "")) == "1.0.0-rc3")
	assert(String(presets.get_value("preset.4.options", "application/version", "")) == "1.0.0-rc3")

	var ci := FileAccess.get_file_as_string("res://.github/workflows/ci.yml")
	assert("clean: true" in ci)
	assert("tests/ui_readability_test.gd" in ci)
	assert("tests/performance_baseline_test.gd" in ci)
	assert("Install pinned Godot-SQLite v4.9" in ci)

	var hosted := FileAccess.get_file_as_string("res://.github/workflows/hosted-validation.yml")
	assert("tests/navigation_responsive_test.gd" in hosted)
	assert("--export-release \"Linux/X11\"" in hosted)
	assert("release-smoke.sh" in hosted)
	assert("FootballDynasty.x86_64.sha256" in hosted)

	var android := FileAccess.get_file_as_string("res://.github/workflows/debug-apk.yml")
	assert("game/**" in android)
	assert("export_presets.cfg" in android)
	assert("FootballDynasty-debug.apk.sha256" in android)

	var heavy := FileAccess.get_file_as_string("res://.github/workflows/rc3-heavy-gates.yml")
	assert("ref: release/rc3-convergence" not in heavy)
	assert("tests/long_session_memory_test.gd" in heavy)
	assert("CERTIFIED_SHA" in heavy)

	print("[TEST] PRODUCTION READINESS CONTRACT PASS")
	quit(0)

extends SceneTree

func _init() -> void:
	var project := ConfigFile.new()
	assert(project.load("res://project.godot") == OK)
	assert(String(project.get_value("application", "config/version", "")) == "1.1.0")
	assert(String(project.get_value("autoload", "UIReadabilityRuntime", "")) != "")
	assert(String(project.get_value("autoload", "NavigationRuntime", "")) != "")
	assert(String(project.get_value("autoload", "Monetization", "")) != "")
	assert(String(project.get_value("autoload", "AnalystRewardRuntime", "")) != "")
	assert(String(project.get_value("display", "window/stretch/mode", "")) == "canvas_items")
	assert(String(project.get_value("display", "window/stretch/aspect", "")) == "expand")

	var required := [
		"res://.github/workflows/ci.yml",
		"res://.github/workflows/android-release.yml",
		"res://.github/workflows/fresh-windows-release.yml",
		"res://docs/RELEASE_ACCEPTANCE_TEMPLATE.md",
		"res://docs/MONETIZATION_INTEGRATION.md",
		"res://tests/ui_readability_test.gd",
		"res://tests/navigation_responsive_test.gd",
		"res://tests/performance_baseline_test.gd",
		"res://tests/long_session_memory_test.gd",
		"res://tests/long_save_growth_test.gd",
		"res://tests/monetization_contract_test.gd",
		"res://tools/release-smoke.sh",
		"res://tools/release-smoke.ps1",
		"res://tools/install-monetization-plugins.sh",
	]
	for path in required:
		assert(FileAccess.file_exists(path), "required production asset missing: %s" % path)

	var presets := ConfigFile.new()
	assert(presets.load("res://export_presets.cfg") == OK)
	assert(String(presets.get_value("preset.0.options", "application/file_version", "")) == "1.1.0.5")
	assert(String(presets.get_value("preset.0.options", "application/product_version", "")) == "1.1.0")
	assert(int(String(presets.get_value("preset.2.options", "gradle_build/target_sdk", "0"))) >= 36)
	assert(int(presets.get_value("preset.2.options", "version/code", 0)) == 10005)
	assert(String(presets.get_value("preset.2.options", "version/name", "")) == "1.1.0")
	assert(bool(presets.get_value("preset.2.options", "permissions/internet", false)))
	assert(String(presets.get_value("preset.3.options", "application/version", "")) == "1.1.0")
	assert(String(presets.get_value("preset.4.options", "application/version", "")) == "1.1.0")

	var ci := FileAccess.get_file_as_string("res://.github/workflows/ci.yml")
	assert("clean: true" in ci)
	assert("tests/architecture_convergence_test.gd" in ci)
	assert("tests/codebase_robustness_regression_test.gd" in ci)
	assert("tests/monetization_contract_test.gd" in ci)
	assert("tests/production_readiness_contract_test.gd" in ci)

	var android_release := FileAccess.get_file_as_string("res://.github/workflows/android-release.yml")
	assert("GODOT_ANDROID_KEYSTORE_RELEASE_PATH" in android_release)
	assert("--install-android-build-template" in android_release)
	assert("FootballDynasty.aab.sha256" in android_release)
	assert("tests/mobile_export_test.gd" in android_release)
	assert("tests/navigation_responsive_test.gd" in android_release)

	var windows_release := FileAccess.get_file_as_string("res://.github/workflows/fresh-windows-release.yml")
	assert("include-templates: true" in windows_release)
	assert("--export-release 'Windows Desktop'" in windows_release)
	assert("installer-smoke.ps1" in windows_release)

	print("[TEST] PRODUCTION READINESS CONTRACT PASS: 1.1.0 monetized release metadata and gates aligned")
	quit(0)

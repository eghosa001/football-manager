extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _fail(message: String) -> void:
	printerr("[TEST] MONETIZATION CONTRACT FAIL: " + message)
	quit(1)

func _run() -> void:
	var project_text := FileAccess.get_file_as_string("res://project.godot")
	for required in [
		'Monetization="*res://game/monetization/monetization_manager.gd"',
		'MonetizationUIRuntime="*res://game/monetization/monetization_ui_runtime.gd"',
		'AnalystRewardRuntime="*res://game/monetization/analyst_reward_runtime.gd"',
	]:
		if not project_text.contains(required):
			_fail("monetization autoload missing: " + required)
			return

	var manager_text := FileAccess.get_file_as_string("res://game/monetization/monetization_manager.gd")
	for required in [
		'PREMIUM_PRODUCT_ID := "football_dynasty_premium"',
		'acknowledge_purchase',
		'query_purchases',
		'purchase_pending',
		'rewarded_ad_user_earned_reward',
		'MAX_ANALYST_CREDITS := 3',
		'analyst_credits',
		'consume_analyst_report',
		'reward_granted.emit',
	]:
		if not manager_text.contains(required):
			_fail("missing monetization safety contract: " + required)
			return
	if manager_text.contains("show_interstitial_ad") or manager_text.contains("show_app_open_ad"):
		_fail("forced/interstitial/app-open ad path must not exist in monetization manager")
		return

	var ui_text := FileAccess.get_file_as_string("res://game/monetization/monetization_ui_runtime.gd")
	for required in ["BUY PREMIUM", "RESTORE PURCHASE", "WATCH REWARDED AD", "analyst_credit", "Ads are never forced", "never changes attributes"]:
		if not ui_text.contains(required):
			_fail("store UI missing required user-facing contract: " + required)
			return

	var analyst_text := FileAccess.get_file_as_string("res://game/monetization/analyst_reward_runtime.gd")
	for required in ["GENERATE INSTANT ANALYST DOSSIER", "ScoutingServiceClass.new().analyst_report", "consume_analyst_report", "does not change the player or any match outcome"]:
		if not analyst_text.contains(required):
			_fail("analyst reward integration missing: " + required)
			return
	for forbidden in ["current_ability =", "potential =", "cash =", "fitness =", "execute_transfer", "simulate_match"]:
		if analyst_text.contains(forbidden):
			_fail("analyst reward must not mutate competitive state: " + forbidden)
			return

	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		_fail("cannot parse export_presets.cfg")
		return
	if not bool(presets.get_value("preset.2.options", "permissions/internet", false)):
		_fail("Android Internet permission is required for billing/rewarded ads")
		return
	if not bool(presets.get_value("preset.2.options", "gradle_build/use_gradle_build", false)):
		_fail("Android Gradle build must remain enabled for monetization plugins")
		return

	var privacy_text := FileAccess.get_file_as_string("res://game/polish/privacy_runtime.gd")
	for required in ["Google Play Billing", "rewarded advertising", "optional", "Data Safety"]:
		if not privacy_text.contains(required):
			_fail("privacy disclosure missing: " + required)
			return

	print("[TEST] MONETIZATION CONTRACT PASS: Premium + restore + rewarded Analyst Reports + no pay-to-win enforced")
	quit(0)

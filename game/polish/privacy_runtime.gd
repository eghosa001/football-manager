extends Node

const POLICY_TITLE := "Privacy Policy"
const POLICY_TEXT := "Football Dynasty keeps career saves, settings, and custom database data locally on your device. The core football-management simulation does not require an account and remains playable without purchasing Premium.\n\nThe Android Google Play build may use an Internet connection for Google Play Billing and optional rewarded advertising. Google Play may process purchase, device, diagnostic, and account-related information required to complete or restore purchases. If you voluntarily request a rewarded ad, the Google Mobile Ads SDK may process device identifiers, advertising/consent information, approximate location derived by the advertising platform, ad interaction data, and diagnostics according to Google policies and your consent choices.\n\nRewarded ads are optional and are never required to continue a career, play a match, use tactics, save, or advance time. Premium is a one-time entitlement. The game stores a local Premium entitlement flag after Google Play confirms ownership so the entitlement can continue to work offline.\n\nFootball Dynasty does not sell your career data. Uninstalling the app may remove locally stored game data because Android backup is disabled for this build. Advertising and billing disclosures in the public privacy policy and Google Play Data Safety form must match the SDK configuration used in the release."

var _next_scan_ms := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan_ms:
		return
	_next_scan_ms = now + 500
	_scan()

func _scan() -> void:
	var root := get_tree().root
	if root == null:
		return
	var landing := root.find_child("FDLandingScreen", true, false)
	if landing is Control:
		_install_privacy_button(landing as Control)

func _install_privacy_button(landing: Control) -> void:
	if landing.has_node("PrivacyButton"):
		return
	var button := Button.new()
	button.name = "PrivacyButton"
	button.text = "PRIVACY"
	button.tooltip_text = "Privacy Policy"
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(88, 32)
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = Vector2(-104, -44)
	button.pressed.connect(_show_policy.bind(landing))
	landing.add_child(button)

func _show_policy(parent: Control) -> void:
	if parent.has_node("PrivacyDialog"):
		var existing := parent.get_node("PrivacyDialog") as Control
		existing.visible = true
		existing.grab_focus()
		return

	var overlay := ColorRect.new()
	overlay.name = "PrivacyDialog"
	overlay.color = Color(0.01, 0.02, 0.04, 0.92)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-400, -255)
	panel.size = Vector2(800, 510)
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = POLICY_TITLE
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var body := Label.new()
	body.text = POLICY_TEXT
	body.custom_minimum_size.x = 710
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 15)
	scroll.add_child(body)

	var close := Button.new()
	close.text = "CLOSE"
	close.focus_mode = Control.FOCUS_ALL
	close.custom_minimum_size = Vector2(160, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func() -> void:
		overlay.visible = false
	)
	column.add_child(close)
	close.grab_focus()

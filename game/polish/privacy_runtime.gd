extends Node

const POLICY_TITLE := "Privacy Policy"
const POLICY_TEXT := "Football Dynasty is designed to work offline. This release does not require an account, does not request Internet access, and does not send gameplay or personal information to the developer. Career saves, settings, and custom database data are stored locally on your device.\n\nIf a future version adds online services, analytics, advertising, cloud saves, purchases, or other data collection, this notice and the public privacy policy must be updated before release.\n\nFor the current Google Play release, uninstalling the app may remove locally stored game data because Android backup is disabled for this build."

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
	panel.position = Vector2(-380, -240)
	panel.size = Vector2(760, 480)
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

	var body := Label.new()
	body.text = POLICY_TEXT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 15)
	column.add_child(body)

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

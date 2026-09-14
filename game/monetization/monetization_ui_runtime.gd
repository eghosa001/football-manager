extends Node

var _next_scan_ms := 0
var _dialog: Control
var _status_label: Label
var _price_label: Label
var _buy_button: Button
var _reward_button: Button

func _ready() -> void:
	set_process(true)
	call_deferred("_wire_manager")
	call_deferred("_scan")

func _wire_manager() -> void:
	if not has_node("/root/Monetization"):
		return
	var m := get_node("/root/Monetization")
	m.status_changed.connect(_on_status_changed)
	m.premium_changed.connect(_on_premium_changed)
	m.product_details_changed.connect(func(_details): _refresh())
	m.purchase_pending.connect(func(_id): _set_message("Purchase is pending in Google Play. Premium will unlock after payment completes."))
	m.purchase_failed.connect(_set_message)
	m.rewarded_ready_changed.connect(func(_ready): _refresh())
	m.reward_granted.connect(_on_reward_granted)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan_ms:
		return
	_next_scan_ms = now + 500
	_scan()

func _scan() -> void:
	var landing := get_tree().root.find_child("FDLandingScreen", true, false)
	if landing is Control:
		_install_store_button(landing as Control)

func _install_store_button(landing: Control) -> void:
	if landing.has_node("PremiumStoreButton"):
		return
	var button := Button.new()
	button.name = "PremiumStoreButton"
	button.text = "PREMIUM"
	button.tooltip_text = "Football Dynasty Premium"
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(112, 34)
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = Vector2(-228, -44)
	button.pressed.connect(_open_store.bind(landing))
	landing.add_child(button)

func _open_store(parent: Control) -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.visible = true
		_refresh()
		return

	var overlay := ColorRect.new()
	overlay.name = "PremiumStoreDialog"
	overlay.color = Color(0.01, 0.02, 0.04, 0.94)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	_dialog = overlay

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-410, -275)
	panel.size = Vector2(820, 550)
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "FOOTBALL DYNASTY PREMIUM"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var intro := Label.new()
	intro.text = "Support Football Dynasty with one permanent purchase. Core football management remains fully playable for free."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 15)
	column.add_child(intro)

	var benefits := Label.new()
	benefits.text = "PREMIUM INCLUDES\n• No rewarded-ad prompts — eligible convenience rewards become instant\n• Premium supporter status across careers\n• Premium-ready entitlement for advanced cosmetic/customisation packs\n• Restore ownership automatically through Google Play"
	benefits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	benefits.add_theme_font_size_override("font_size", 15)
	column.add_child(benefits)

	_price_label = Label.new()
	_price_label.add_theme_font_size_override("font_size", 20)
	column.add_child(_price_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(220, 48)
	_buy_button.pressed.connect(func(): get_node("/root/Monetization").buy_premium())
	row.add_child(_buy_button)

	var restore := Button.new()
	restore.text = "RESTORE PURCHASE"
	restore.custom_minimum_size = Vector2(190, 48)
	restore.pressed.connect(func(): get_node("/root/Monetization").restore_purchases())
	row.add_child(restore)

	var separator := HSeparator.new()
	column.add_child(separator)

	var reward_title := Label.new()
	reward_title.text = "OPTIONAL REWARDED AD"
	reward_title.add_theme_font_size_override("font_size", 17)
	column.add_child(reward_title)

	var reward_copy := Label.new()
	reward_copy.text = "Free players may voluntarily watch a rewarded ad for a convenience reward. Ads are never forced between matches, transfers, tactics, saves, or Continue actions."
	reward_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(reward_copy)

	_reward_button = Button.new()
	_reward_button.custom_minimum_size = Vector2(360, 44)
	_reward_button.pressed.connect(func(): get_node("/root/Monetization").request_rewarded_ad("supporter_convenience"))
	column.add_child(_reward_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(150, 42)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func(): overlay.visible = false)
	column.add_child(close)

	_refresh()
	_buy_button.grab_focus()

func _refresh() -> void:
	if _dialog == null or not is_instance_valid(_dialog) or not has_node("/root/Monetization"):
		return
	var m := get_node("/root/Monetization")
	if _price_label != null:
		_price_label.text = "Permanent Premium • %s" % m.premium_price_text()
	if _buy_button != null:
		_buy_button.text = "PREMIUM ACTIVE" if m.is_premium else "BUY PREMIUM"
		_buy_button.disabled = m.is_premium
	if _reward_button != null:
		if m.is_premium:
			_reward_button.text = "CLAIM CONVENIENCE REWARD"
			_reward_button.disabled = false
		else:
			_reward_button.text = "WATCH REWARDED AD" if m.rewarded_available else "REWARDED AD LOADING"
			_reward_button.disabled = not m.rewarded_available
	if _status_label != null:
		_status_label.text = _friendly_status(m.status)

func _on_status_changed(_status: String) -> void:
	_refresh()

func _on_premium_changed(active: bool) -> void:
	_set_message("Premium is active on this device." if active else "Premium is not active.")
	_refresh()

func _on_reward_granted(reward_id: String) -> void:
	if reward_id == "supporter_convenience":
		_set_message("Reward earned. The game confirmed the rewarded-ad completion event.")
	else:
		_set_message("Reward earned: %s" % reward_id)

func _set_message(message: String) -> void:
	if _status_label != null and is_instance_valid(_status_label):
		_status_label.text = message

func _friendly_status(value: String) -> String:
	match value:
		"premium_active": return "Premium active. Thank you for supporting Football Dynasty."
		"billing_ready": return "Google Play is connected and purchases can be restored or completed."
		"billing_connecting": return "Connecting securely to Google Play…"
		"billing_plugin_missing": return "Billing plugin is not installed in this build. Purchases are disabled safely."
		"purchase_pending": return "Purchase pending. Google Play will unlock Premium when payment completes."
		"purchase_cancelled": return "Purchase cancelled. Nothing was charged by the game."
		"rewarded_ready": return "Optional rewarded ad ready."
		"rewarded_unavailable": return "No rewarded ad is available right now. Core gameplay is unaffected."
		"offline": return "Store services are available only in the Android Google Play build."
		_: return value.replace("_", " ").capitalize()

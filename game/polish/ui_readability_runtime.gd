class_name UIReadabilityRuntime
extends Node

const DESKTOP_TARGET_HEIGHT := 38.0
const MOBILE_TARGET_HEIGHT := 48.0
const DESKTOP_MIN_FONT := 16
const MOBILE_MIN_FONT := 18

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_polish_existing")

func _polish_existing() -> void:
	if get_tree().current_scene != null:
		_apply_recursive(get_tree().current_scene)

func _on_node_added(node: Node) -> void:
	if node is Control:
		call_deferred("apply_control", node)

func _apply_recursive(node: Node) -> void:
	if node is Control:
		apply_control(node as Control)
	for child in node.get_children():
		_apply_recursive(child)

func apply_control(control: Control, mobile_override: Variant = null) -> void:
	if control == null:
		return
	var mobile := OS.has_feature("mobile") if mobile_override == null else bool(mobile_override)
	var target_height := MOBILE_TARGET_HEIGHT if mobile else DESKTOP_TARGET_HEIGHT
	var min_font := MOBILE_MIN_FONT if mobile else DESKTOP_MIN_FONT

	if control is BaseButton or control is LineEdit or control is OptionButton or control is SpinBox:
		control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, target_height)
		control.focus_mode = Control.FOCUS_ALL

	if control is Label:
		var label := control as Label
		if label.text.length() >= 56 and label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if control is TabContainer:
		var tabs := control as TabContainer
		var bar := tabs.get_tab_bar()
		if bar != null:
			bar.scrolling_enabled = true
			bar.focus_mode = Control.FOCUS_ALL
			bar.custom_minimum_size.y = maxf(bar.custom_minimum_size.y, target_height)

	# Never force text smaller than the production readability floor. Explicit
	# larger overrides remain untouched.
	if control is Label or control is BaseButton or control is LineEdit or control is OptionButton or control is SpinBox:
		var current := control.get_theme_font_size("font_size")
		if current > 0 and current < min_font:
			control.add_theme_font_size_override("font_size", min_font)
